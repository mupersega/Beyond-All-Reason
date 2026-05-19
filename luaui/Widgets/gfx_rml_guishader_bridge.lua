if not RmlUi then
	return
end

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name    = "RML GUIShader Bridge",
		desc    = "Bridges RML widget elements to the world-blur (guishader) layer, so the 3D game blurs behind glass RML panels.",
		author  = "mupersega",
		date    = "2026",
		license = "GNU GPL, v2 or later",
		-- Init-order contract: consumers call register() from their own
		-- Initialize, so WG['rml_guishader'] must exist before any consumer
		-- inits. Widgets init in ascending layer order, so this sits just
		-- above rml_context_manager (-100000) and below every RML consumer
		-- (changelog is the lowest at -99990). A future consumer with a
		-- layer below this must register from a later call-in instead.
		-- (Standard BAR service-provider pattern — guishader itself uses
		-- layer -990000 for the same reason.)
		layer   = -99991,
		enabled = true,
	}
end

-- =============================================================================
-- Why this widget exists
--
-- RmlUi's `backdrop-filter: blur()` only samples other elements *in the same
-- RmlUi context*. The 3D game world is rendered on a separate engine layer the
-- RmlUi context cannot see, so backdrop-filter never blurs the game behind a
-- panel — it only blurs other RML widgets behind it.
--
-- The traditional GL widgets get world-blur from `gfx_guishader.lua`
-- (`WG['guishader']`), which blurs the world inside registered screen rects
-- *before* the UI is drawn. This widget is the bridge: an RML widget hands us
-- an element, and we keep a guishader world-blur rect synced to that element's
-- on-screen box. The result is glass-over-game wherever the panel uses an
-- alpha background.
--
-- Performance contract (this is a 60+ FPS game UI):
--   * guishader re-renders its full-screen stencil texture on EVERY InsertRect
--     call. So we must NOT call InsertRect every frame — only when the
--     element's integer-rounded screen rect actually changes.
--   * Reading element geometry every frame is the unavoidable bit: RmlUi's Lua
--     binding has no "layout changed" callback, and RML panels here are
--     draggable (no Lua signal on drag), so we must sample geometry to follow
--     them. The reads are a handful of cheap field accesses per registered
--     panel (typically 1–3 visible) — the expensive part (stencil re-render)
--     stays gated behind the change check. A stationary panel costs ~nothing;
--     an active drag costs one stencil re-render per moved frame, which is
--     exactly the cost of having the blur track the panel live.
-- =============================================================================

local spGetViewGeometry = Spring.GetViewGeometry
local mathFloor = math.floor
local mathMax = math.max
local mathMin = math.min

-- name -> {
--   element   = Element,   tracked element (often the widget body)
--   isVisible = fn|nil,    optional predicate; false => remove the rect
--   inset     = number,    px shrink per side (rounded-corner overhang trim)
--   pushed    = bool,      is a rect currently registered with guishader
--   l,b,r,t   = number,    last pushed Spring-screen rect (integer px)
-- }
local tracked = {}

local vsx, vsy = spGetViewGeometry()

-- Global master switch (user-facing, RML-scoped). Persisted in Spring config
-- under "rml_world_blur" so it survives restarts; the gui_options_rml
-- "world blur" interface setting is just a front-end onto setEnabled/isEnabled.
-- This governs ONLY the RML widgets registered here — the engine-wide
-- WG['guishader'] that traditional widgets use is entirely unaffected.
local CONFIG_KEY = "rml_world_blur"
local enabled = true

-- ── Geometry ────────────────────────────────────────────────────────────────

-- Absolute box of an element in RmlUi context pixels, top-left origin.
-- Walk the offset_parent chain summing offsets; subtract scrolled-ancestor
-- scroll so a panel nested inside a scroll container still tracks correctly.
-- For a top-level absolutely-positioned widget body this is a 0–1 hop walk.
local function getAbsoluteBox(el)
	local x, y = 0, 0
	local node = el
	while node do
		x = x + (node.offset_left or 0)
		y = y + (node.offset_top or 0)
		local parent = node.offset_parent
		if parent then
			x = x - (parent.scroll_left or 0)
			y = y - (parent.scroll_top or 0)
		end
		node = parent
	end
	return x, y, (el.offset_width or 0), (el.offset_height or 0)
end

-- Convert an RmlUi context-px box (top-left origin) to a Spring screen-px rect
-- (bottom-left origin), the coordinate space WG['guishader'] expects.
--
-- ASSUMPTION: RmlUi context pixels == Spring screen pixels, i.e. the context's
-- dimensions equal the view geometry. This is consistent with how
-- rml_tooltip_layer round-trips the cursor (spring px / dp_ratio -> dp, engine
-- multiplies dp by context.dp_ratio back to screen px to place the slot under
-- the cursor). It is NOT independently verified here.
--
-- IN-GAME VALIDATION: if the blur rect is offset or wrongly scaled relative to
-- the panel, the fix is localised to this function — multiply x/y/w/h by
-- utils.getDpRatio() (offsets would then be in dp, not screen px). No other
-- code changes needed.
local function contextBoxToSpringRect(x, y, w, h, inset)
	local left   = x + inset
	local right  = x + w - inset
	local topY   = y + inset            -- top edge, top-left origin
	local botY   = y + h - inset        -- bottom edge, top-left origin

	-- Flip Y to Spring's bottom-left origin.
	local springTop    = vsy - topY     -- larger Y
	local springBottom = vsy - botY     -- smaller Y

	-- Clamp to the viewport so a partially off-screen / dragged-out panel
	-- never feeds guishader a degenerate or out-of-range stencil rect.
	left         = mathMax(0, mathMin(vsx, left))
	right        = mathMax(0, mathMin(vsx, right))
	springBottom = mathMax(0, mathMin(vsy, springBottom))
	springTop    = mathMax(0, mathMin(vsy, springTop))

	return mathFloor(left + 0.5), mathFloor(springBottom + 0.5),
	       mathFloor(right + 0.5), mathFloor(springTop + 0.5)
end

-- ── Sync ────────────────────────────────────────────────────────────────────

local function removeRect(name, entry, guishader)
	if entry.pushed then
		if guishader then
			guishader.RemoveRect(name)
		end
		entry.pushed = false
		entry.l, entry.b, entry.r, entry.t = nil, nil, nil, nil
	end
end

local function syncEntry(name, entry, guishader)
	local el = entry.element

	-- Visibility gate: explicit predicate first, then a zero-size fallback
	-- (a hidden RML document yields a zero-width box). Either => no blur.
	local visible = true
	if entry.isVisible then
		visible = entry.isVisible() and true or false
	end

	if not visible then
		removeRect(name, entry, guishader)
		return
	end

	local x, y, w, h = getAbsoluteBox(el)
	if w <= 0 or h <= 0 then
		removeRect(name, entry, guishader)
		return
	end

	local l, b, r, t = contextBoxToSpringRect(x, y, w, h, entry.inset)
	if r - l < 1 or t - b < 1 then
		removeRect(name, entry, guishader)
		return
	end

	-- Change gate: only touch guishader (full stencil re-render) when the
	-- integer-rounded rect actually moved/resized since the last push.
	if entry.pushed
		and entry.l == l and entry.b == b
		and entry.r == r and entry.t == t then
		return
	end

	guishader.InsertRect(l, b, r, t, name)
	entry.pushed = true
	entry.l, entry.b, entry.r, entry.t = l, b, r, t
end

-- ── Public API: WG['rml_guishader'] ─────────────────────────────────────────

local function apiRegister(name, element, opts)
	if type(name) ~= "string" or name == "" or not element then
		Spring.Echo("rml_guishader: register() needs (name, element[, opts])")
		return false
	end
	opts = opts or {}
	tracked[name] = {
		element   = element,
		isVisible = opts.isVisible,
		inset     = tonumber(opts.inset) or 0,
		pushed    = false,
	}
	return true
end

local function apiUnregister(name)
	local entry = tracked[name]
	if not entry then
		return false
	end
	-- Resolve guishader fresh: it can be reloaded independently of us.
	local guishader = WG["guishader"]
	removeRect(name, entry, guishader)
	tracked[name] = nil
	return true
end

local function apiIsEnabled()
	return enabled
end

local function apiSetEnabled(v)
	v = v and true or false
	if v == enabled then
		return
	end
	enabled = v
	Spring.SetConfigInt(CONFIG_KEY, v and 1 or 0)
	if not enabled then
		-- Drop every rect immediately so the blur disappears the instant the
		-- setting is toggled off, rather than next frame. Re-enabling lets
		-- widget:Update re-push each tracked entry.
		local guishader = WG["guishader"]
		for name, entry in pairs(tracked) do
			removeRect(name, entry, guishader)
		end
	end
end

-- ── Lifecycle ───────────────────────────────────────────────────────────────

function widget:Initialize()
	vsx, vsy = spGetViewGeometry()
	enabled = (Spring.GetConfigInt(CONFIG_KEY, 1) == 1)
	WG["rml_guishader"] = {
		register    = apiRegister,
		unregister  = apiUnregister,
		setEnabled  = apiSetEnabled,
		isEnabled   = apiIsEnabled,
		isAvailable = function()
			return WG["guishader"] ~= nil
		end,
	}
end

function widget:Shutdown()
	local guishader = WG["guishader"]
	for name, entry in pairs(tracked) do
		removeRect(name, entry, guishader)
	end
	tracked = {}
	WG["rml_guishader"] = nil
end

function widget:ViewResize()
	vsx, vsy = spGetViewGeometry()
	-- Cached rects are in the old screen space. Clearing them makes the
	-- change gate fail equality next Update so the rect re-pushes with the
	-- new geometry. (guishader handles its own ViewResize separately.)
	for _, entry in pairs(tracked) do
		entry.l, entry.b, entry.r, entry.t = nil, nil, nil, nil
	end
end

function widget:Update()
	if not enabled then
		return
	end
	if not next(tracked) then
		return
	end

	-- Resolve guishader fresh every frame: it is a separate widget that can
	-- be toggled/reloaded. When it is gone we can't push or remove — just
	-- drop our "pushed" bookkeeping so rects re-insert if it comes back.
	local guishader = WG["guishader"]
	if not guishader then
		for _, entry in pairs(tracked) do
			entry.pushed = false
			entry.l, entry.b, entry.r, entry.t = nil, nil, nil, nil
		end
		return
	end

	for name, entry in pairs(tracked) do
		syncEntry(name, entry, guishader)
	end
end
