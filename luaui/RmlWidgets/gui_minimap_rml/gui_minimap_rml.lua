-- gui_minimap_rml — RML chrome for the minimap (map-view-mode toggle tab)
--
-- THE MODEL IS KING. The view changes by mutating dm_handle fields and letting
-- data binding update it. No GetElementById / SetClass / .inner_rml. See
-- luaui/RmlWidgets/CLAUDE.md — "The model is king".
--
-- ── SCOPE ───────────────────────────────────────────────────────────────────
-- A lightweight RML *companion* to the minimap, NOT a port of the engine map
-- surface. It adds a map-view-mode toggle tab (the inverted build-grid "tab"
-- motif: a bg-dark wedge with the toggles left-justified on it) docked beneath
-- the minimap — Metal / Height / Traverse / LOS — and owns nothing the
-- engine/legacy widget owns.
--
-- The actual map pixels stay with the engine (`gl.DrawMiniMap` in
-- gui_minimap.lua), which also keeps owning WG['minimap']. We only READ the live
-- minimap rect to anchor ourselves, and CALL engine view-mode actions. The heavy
-- "RML frames the GL surface" bridge (spec-minimap rank 4) stays out of scope.
--
-- Coexistence: gui_minimap.lua stays enabled and unmodified. This widget is
-- additive + opt-in (enabled = false) and publishes no shared WG state.
--
-- VIEW MODES: switched via engine console actions (no Lua setter exists), read
-- back via Spring.GetMapDrawMode(). Each action TOGGLES its mode against
-- 'normal', so clicking the active button returns to normal. The highlight
-- updates OPTIMISTICALLY on click (predicted result) for instant feedback; a
-- throttled poll then reconciles to engine truth and catches F-key changes made
-- outside the widget (there's no map-draw-mode callin to bind instead).
--
-- DECORATION: the tab wedge geometry is blind-tuned starting values; expect the
-- owner to fine-tune angle/offset in-game (see the .rcss TUNABLES comments).

if not RmlUi then
	return
end

local widget = widget ---@type Widget
local utils = VFS.Include("luaui/Include/rml_utilities/utils.lua")

local WIDGET_ID = "gui_minimap_rml"
local MODEL_NAME = "gui_minimap_rml_model"
local RML_PATH = "luaui/RmlWidgets/gui_minimap_rml/gui_minimap_rml.rml"

local document
local dm_handle

-- Map view modes. `mode` is what Spring.GetMapDrawMode() returns when active;
-- `action` is the engine console action that toggles it. 3-letter labels keep
-- the buttons compact. (Localised labels deferred — preview widget.)
local MODES = {
	{ id = "metal",  label = "MTL", mode = "metal",             action = "showmetalmap" },
	{ id = "height", label = "HGT", mode = "height",            action = "showelevation" },
	{ id = "path",   label = "TRV", mode = "pathTraversability", action = "showpathtraversability" },
	{ id = "los",    label = "LOS", mode = "los",               action = "togglelos" },
}

-- id -> mode entry, for the click handler's optimistic highlight + action lookup.
local MODE_BY_ID = {}
for i = 1, #MODES do MODE_BY_ID[MODES[i].id] = MODES[i] end

local spGetMapDrawMode = Spring.GetMapDrawMode
local spGetMiniMapGeometry = Spring.GetMiniMapGeometry
local spGetViewGeometry = Spring.GetViewGeometry
local spSendCommands = Spring.SendCommands

-- Geometry/mode can change without a callin (topbar resize, rotation, minimize,
-- F-key mode change), so poll. Cheap: a couple of scalars written on change only.
local POLL_INTERVAL = 0.2
local sincePoll = POLL_INTERVAL  -- force a compute on the first Update

-- Last values written to the model — only push on change to avoid needless
-- data-model churn (never read these back off the proxy).
local lastTop, lastWidth, lastShown, lastMode

-- Minimap frame box in dp (top-left origin), derived from the live engine
-- geometry. The frame sits flush top-left: height = bar's top offset AND the
-- accent's height; width = bar/accent width. Returns top(dp), width(dp), shown.
-- Returns the framed-panel top(dp) + width(dp) + shown, anchored to WHICHEVER
-- minimap is active. Both gui_minimap (standard) and gui_pip_minimap (PiP) sit
-- top-left, so left stays 0; only the height/width and bottom edge differ.
local function recalcGeometry()
	local ratio = utils.getDpRatio()
	if ratio <= 0 then ratio = 1 end

	-- PiP minimap mode renders its OWN view and slaves the engine minimap (so
	-- Spring.GetMiniMapGeometry is stale). It publishes its real screen rect, so
	-- read that instead. Prefer it whenever it's present.
	local pip = WG.pip_minimap
	if pip and pip.GetScreenBounds then
		local l, r, b = pip.GetScreenBounds()   -- Spring px, bottom-left origin
		local _, vsy = spGetViewGeometry()
		local frameW = (r or 0) - (l or 0)
		local frameH = vsy - (b or 0)            -- screen top → minimap bottom edge
		local minimized = pip.IsMinimized and pip.IsMinimized()
		local ready = frameW > 0 and frameH > 0
		return frameH / ratio, frameW / ratio, ready and not minimized
	end

	-- Standard engine minimap (gui_minimap positions it top-left). Self-contained:
	-- read the engine rect directly, NOT WG['minimap'], so a legacy reset can't
	-- null our anchor. Framed panel = minimap rect + one elementPadding.
	local _, _, mmW, mmH, minimized, maximized = spGetMiniMapGeometry()
	local pad = (WG.FlowUI and WG.FlowUI.elementPadding) or 0
	local frameH = (mmH or 0) + pad
	local frameW = (mmW or 0) + pad
	-- minimized/maximized come back as 0/1 ints. In Lua 0 is TRUTHY, so a plain
	-- `not (minimized or maximized)` is always false → the bar would never show.
	-- Test against 0 explicitly (also tolerates a boolean/nil engine return).
	local collapsed = (minimized and minimized ~= 0) or (maximized and maximized ~= 0)
	-- A not-yet-ready minimap reads 0×0; treat as not-shown so we don't park a
	-- zero-size bar at the top-left until real geometry arrives.
	local ready = frameW > pad and frameH > pad
	return frameH / ratio, frameW / ratio, ready and not collapsed
end

local function updateLayout()
	if not dm_handle then return end
	local topDp, widthDp, shown = recalcGeometry()
	if topDp ~= lastTop then lastTop = topDp; dm_handle.frameH = topDp end
	if widthDp ~= lastWidth then lastWidth = widthDp; dm_handle.frameW = widthDp end
	if shown ~= lastShown then lastShown = shown; dm_handle.shown = shown end
end

-- Active highlight follows engine truth. activeMode is a scalar compared per-row
-- in data-attr-class (m.mode == activeMode) — no array reassignment on change.
local function updateActiveMode()
	if not dm_handle then return end
	local mode = spGetMapDrawMode() or "normal"
	if mode ~= lastMode then lastMode = mode; dm_handle.activeMode = mode end
end

-----------------------------------------------------------------------
-- Data model
-----------------------------------------------------------------------

local function buildModes()
	local list = {}
	for i = 1, #MODES do
		local m = MODES[i]
		-- Homogeneous rows (see rmlui_datafor_homogeneous).
		list[i] = { id = m.id, label = m.label, mode = m.mode, action = m.action }
	end
	return list
end

local function initModel()
	return {
		modes = buildModes(),
		activeMode = "normal",  -- scalar, polled

		-- Anchoring (dp numbers; concatenated to 'dp' in data-style bindings).
		frameH = 0,
		frameW = 0,
		shown = false,

		-- Toggle a view mode. Wired via data-event-click="setMode(m.id)"; Event is
		-- the implicit first arg (unused). The engine action toggles the mode
		-- against normal, so a second click on the active mode clears it.
		-- OPTIMISTIC: predict the resulting mode and update the highlight here so
		-- the active button flips on click instead of waiting up to one poll
		-- interval (that latency was the perceived "lag"). updateActiveMode's poll
		-- then reconciles to engine truth and catches F-key changes from outside.
		setMode = function(_, id)
			local m = MODE_BY_ID[id]
			if not m then return end
			local predicted = (lastMode == m.mode) and "normal" or m.mode
			lastMode = predicted
			if dm_handle then dm_handle.activeMode = predicted end
			spSendCommands(m.action)
		end,

		my = {
			-- Flat utility-class buttons. We deliberately do NOT use ccg.button:
			-- its bg-gradient is lit at the top edge, which read as a pale band on
			-- these thin buttons. idle/active swapped via data-attr-class.
			btn = "text-xs font-bold text-center cursor-pointer mm-mode-btn",
			idle = "bg-darkest hover-brighten text-light",
			active = "bg-primary hover-brighten text-darkest",
		},
	}
end

-----------------------------------------------------------------------
-- Lifecycle
-----------------------------------------------------------------------

function widget:GetInfo()
	return {
		name = "Minimap RML",
		desc = "RML companion to the minimap: map-view-mode toggle bar + theme accent. Opt-in; coexists with the legacy Minimap widget.",
		author = "mupersega",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = -99980,
		enabled = false,
	}
end

function widget:Initialize()
	local result = utils.initializeRmlWidget(self, {
		widgetId = WIDGET_ID,
		modelName = MODEL_NAME,
		rmlPath = RML_PATH,
		initModel = initModel(),
		useCommonClassGroups = true,
	})
	if not result then
		return false
	end
	document = result.document
	dm_handle = result.dm_handle
	sincePoll = POLL_INTERVAL
	lastTop, lastWidth, lastShown, lastMode = nil, nil, nil, nil
	return true
end

function widget:ViewResize()
	updateLayout()
end

function widget:Update(dt)
	if not dm_handle then return end
	sincePoll = sincePoll + (dt or 0)
	if sincePoll < POLL_INTERVAL then return end
	sincePoll = 0
	updateLayout()
	updateActiveMode()
end

function widget:Shutdown()
	utils.shutdownRmlWidget(self, {
		widgetId = WIDGET_ID,
		modelName = MODEL_NAME,
	}, document, dm_handle)
	document = nil
	dm_handle = nil
end
