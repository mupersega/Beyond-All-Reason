if not RmlUi then
	return
end

local widget = widget ---@type Widget
local utils = VFS.Include("luaui/Include/rml_utilities/utils.lua")
local ccg = VFS.Include("luaui/Include/rml_utilities/common_class_groups.lua")

function widget:GetInfo()
	return {
		name = "Options RML",
		desc = "RML-based options panel: tabbed, searchable, data-driven from options_config. Opt-in (disabled by default).",
		author = "Mupersega",
		date = "2025",
		license = "GNU GPL, v2 or later",
		layer = -1000,
		enabled = false,
		handler = true,
	}
end

-- Constants
local WIDGET_ID = "gui_options_rml"
local MODEL_NAME = "gui_options_rml_model"
local RML_PATH = "luaui/RmlWidgets/gui_options_rml/gui_options_rml.rml"

-- Widget state
local document
local dm_handle
local show = false

-- Search feature state
local searchIndex = {}          -- flat list built at content-init, source of truth for search
local pathLabels = {}           -- ["gfx/display"] -> "Graphics > Display" (localized)
local lastSearchValue           -- guard: only re-filter when the input text actually changed

-- Forward declaration: performSearch / clearSearch (defined below, before
-- initModel) call populateActiveTabData (defined much later). Declared here so
-- every closure captures the same upvalue; the definition uses
-- `function populateActiveTabData` (no `local`) to assign into it.
local populateActiveTabData

local MIN_SEARCH_CHARS = 3
-- Must be >= the RCSS `transition: transform 0.25s` on #gui_options_rml-widget.
-- We defer document:Hide() this long after a close so the slide-out is fully
-- visible before the document drops out of the context's active set.
local SLIDE_OUT_SEC = 0.3

-- Draw-frame of the most recent (re)populate. RmlUi raises a spurious
-- `onchange` on every <select>/<input> that data-for recreates when the
-- section arrays are reassigned (in populateActiveTabData); at that instant
-- the element reports its first/default option, not the bound value.
-- OnSelect/OnSlider ignore changes within CONTROL_SETTLE_FRAMES of this so
-- that spurious fire can't apply a wrong value (the bug: opening the
-- Interface tab silently reset rml_theme to "base"). Real user input never
-- lands this fast after a repopulate — the panel is still sliding in.
-- MUST be declared here, before OnSlider/OnSelect reference it (Lua locals
-- are only in scope textually after their declaration).
local CONTROL_SETTLE_FRAMES = 4
local controlSettleFrame = -1000

-- Toggle panel visibility. nil = flip; true/false = set explicitly.
--
-- Text-input state management: BAR has three legacy widgets that directly
-- flip the global `Spring.SDLStartTextInput()` / `SDLStopTextInput()` state
-- and grab/release `widgetHandler.textOwner` (the gate in barwidgets.lua
-- TextInput routing that funnels all character keys to a single widget) —
-- `gui_options.lua`, `widget_selector.lua`, `gui_chat.lua`. The topbar
-- settings button (gui_top_bar.lua:2126) dual-dispatches `'options'` +
-- `'options_rml'` during the migration, so every open/close cycle races
-- our RML widget against the legacy widget's SDL/textOwner bookkeeping —
-- leaving SDL text input OFF and characters dead-ended (backspace survives
-- because it's a KeyPress, not a TextInput event, and goes through a
-- different engine pipeline). We defensively re-assert both on every show
-- and release both on every hide so no other widget's stale state can
-- silently kill character input into our search box.
local bodyElement       -- cached #gui_options_rml-widget element; populated in Initialize
local pendingOpenClass = false  -- set by toggleShow(open); widget:Update adds
                                -- .drawer-open the NEXT frame so the slide-in
                                -- has a laid-out 'from' state and animates
local hideTimer = nil   -- Spring.GetTimer ref while sliding out; widget:Update
                        -- fires document:Hide() once SLIDE_OUT_SEC has elapsed

local function toggleShow(newState)
	if newState == nil then
		newState = not show
	end
	-- CRITICAL ordering: hideWindows() must run BEFORE `show = newState`.
	-- It calls back into closeWindow('options_rml') -> isvisible() (== our
	-- `show`); if `show` were already flipped to true, opening would
	-- recursively close us mid-open (flag ends up false, slide-in still
	-- fires → no content populate + broken toggle). Guarded by `newState`
	-- so it only runs on open, exactly like the pre-refactor code.
	--
	-- No "already in this state" early-return on purpose: the SDL text-input
	-- re-assert below is defensive (see the block comment above) and must run
	-- on every call. The document Show/Hide/timer ops are idempotent, so a
	-- redundant call is harmless (a redundant open just re-raises to front).
	if newState and WG['topbar'] then
		WG['topbar'].hideWindows()
	end
	show = newState

	if show then
		-- Re-opened before a previous slide-out finished: cancel the pending
		-- Hide so the still-live document just slides back in.
		hideTimer = nil
		-- Show() makes the document live AND pulls it to the front of the
		-- shared context + gives it focus — no manual PullToFront needed.
		-- Its default style is translateX(-100%), so it comes up off-screen;
		-- the .drawer-open class is added one frame later (widget:Update) so
		-- the transform transition animates instead of snapping open.
		if document then
			document:Show()
		end
		pendingOpenClass = true
		Spring.SDLStartTextInput()
		widgetHandler.textOwner = nil
	else
		-- Drop the class now so it slides back out; defer document:Hide()
		-- until the transition has finished (widget:Update + hideTimer) so
		-- the slide-out is visible and only then does the document leave
		-- the context's active set.
		pendingOpenClass = false
		if bodyElement then
			bodyElement:SetClass('drawer-open', false)
		end
		hideTimer = Spring.GetTimer()
		Spring.SDLStopTextInput()
		if widgetHandler.textOwner == widget then
			widgetHandler.textOwner = nil
		end
	end
end

-----------------------------------------------------------------------
-- Config helper closures (shared across all sub-tab configs)
-----------------------------------------------------------------------

local function getWidgetToggleValue(widgetName)
	if not widgetHandler.orderList then return false end
	local order = widgetHandler.orderList[widgetName]
	if not order or order == 0 then return false end
	if widgetHandler.knownWidgets and widgetHandler.knownWidgets[widgetName] then
		return widgetHandler.knownWidgets[widgetName].active == true
	end
	return false
end

-- saveOptionValue — matches luaui/Widgets/gui_options.lua:1449-1476 behavior.
-- configVar is a table of keys forming a nested path; intermediate sub-tables
-- are created as needed. The 6th arg widgetApiFunctionParam overrides what
-- gets passed to the widget API function (for widgets whose setters take a
-- different shape than the raw value, e.g. setMetricEnabled expects {key, v}).
local function saveOptionValue(widgetName, wgKey, setterName, configVar, value, widgetApiFunctionParam)
	if widgetHandler.configData[widgetName] == nil then
		widgetHandler.configData[widgetName] = {}
	end
	local cfg = widgetHandler.configData[widgetName]
	for i = 1, #configVar - 1 do
		if type(cfg[configVar[i]]) ~= "table" then
			cfg[configVar[i]] = {}
		end
		cfg = cfg[configVar[i]]
	end
	cfg[configVar[#configVar]] = value

	if wgKey and WG[wgKey] and WG[wgKey][setterName] then
		if widgetApiFunctionParam ~= nil then
			WG[wgKey][setterName](widgetApiFunctionParam)
		else
			WG[wgKey][setterName](value)
		end
	end
end

-- loadWidgetData — accepts either a flat string key (backward compat) or a
-- table of keys forming a nested path.
local function loadWidgetData(widgetName, configVar, default)
	local cfg = widgetHandler.configData[widgetName]
	if cfg == nil then return default end

	if type(configVar) == "table" then
		local val = cfg
		for _, key in ipairs(configVar) do
			if type(val) ~= "table" then return default end
			val = val[key]
			if val == nil then return default end
		end
		return val
	else
		return cfg[configVar] ~= nil and cfg[configVar] or default
	end
end

-----------------------------------------------------------------------
-- Start script (needed for Spring.Restart)
-----------------------------------------------------------------------

local startScript = VFS.LoadFile("_script.txt")
if not startScript then
	local modoptions = ''
	for key, value in pairs(Spring.GetModOptionsCopy()) do
		local v = value
		if type(v) == 'boolean' then
			v = (v and '1' or '0')
		end
		modoptions = modoptions .. key .. '=' .. v .. ';'
	end
	startScript = [[[game]
	{
		[allyteam1]
		{
			numallies=0;
		}
		[team1]
		{
			teamleader=0;
			allyteam=1;
		}
		[ai0]
		{
			shortname=Null AI;
			name=AI: Null AI;
			team=1;
			host=0;
		}
		[modoptions]
		{
			]]..modoptions..[[ }
		[mapoptions]
		{
		}
	}]]
end

local function restartEngine()
	Spring.Restart("", startScript)
end

-----------------------------------------------------------------------
-- Config loading — all sub-tabs loaded from options_config.lua.
-- Every sub-tab is a flat array with inline type="heading" entries.
-----------------------------------------------------------------------

local buildOptionsConfig = VFS.Include("luaui/Include/rml_utilities/options_config.lua")
local allConfig = buildOptionsConfig({
	saveOptionValue = saveOptionValue,
	loadWidgetData = loadWidgetData,
	getWidgetToggleValue = getWidgetToggleValue,
	restartEngine = restartEngine,
})

-- O(1) lookup from element ID → config entry. Works on flat arrays.
local optionById = {}
for _, subTabConfig in pairs(allConfig) do
	for _, entry in ipairs(subTabConfig) do
		if entry.id then
			optionById[entry.id] = entry
		end
	end
end

-----------------------------------------------------------------------
-- Flat → sectioned + grouped structure for data-for rendering.
-- Input: flat array where type="heading" entries mark section boundaries.
-- Output: array of sections, each with { heading, groups }.
-- Each group has { parent, children, hasChildren, parentOff }.
-----------------------------------------------------------------------

local function buildSections(flat)
	local sections = {}
	local childrenByParent = {}

	for _, entry in ipairs(flat) do
		if entry.parentId then
			childrenByParent[entry.parentId] = childrenByParent[entry.parentId] or {}
			table.insert(childrenByParent[entry.parentId], entry)
		end
	end

	local currentSection = nil
	for _, entry in ipairs(flat) do
		if entry.type == "heading" then
			currentSection = { heading = entry.name, groups = {} }
			table.insert(sections, currentSection)
		elseif not entry.parentId then
			if not currentSection then
				-- First entry isn't a heading — start an untitled section.
				currentSection = { heading = "", groups = {} }
				table.insert(sections, currentSection)
			end
			local children = childrenByParent[entry.id] or {}
			table.insert(currentSection.groups, {
				parent = entry,
				children = children,
				hasChildren = #children > 0,
				parentOff = entry.type == "bool" and not entry.value,
			})
		end
	end

	return sections
end

-----------------------------------------------------------------------
-- Search feature helpers
--
-- buildSearchIndex walks allConfig and produces a flat list of searchable
-- entries tagged with their tab + sub-tab location. TAB_KEY_MAP maps the
-- allConfig key (e.g. "gfx_display") to (tab, subTab, subTabKey); the
-- subTabKey is the dm_handle field that controls that tab's sub-tab
-- selector (nil for flat tabs like audio/control/game/dev).
-----------------------------------------------------------------------

local TAB_KEY_MAP = {
	gfx_display         = { tab = "gfx",       subTab = "display",     subTabKey = "gfxSubTab" },
	gfx_rendering       = { tab = "gfx",       subTab = "rendering",   subTabKey = "gfxSubTab" },
	gfx_environment     = { tab = "gfx",       subTab = "environment", subTabKey = "gfxSubTab" },
	audio               = { tab = "audio" },
	interface_general   = { tab = "interface", subTab = "general",     subTabKey = "interfaceSubTab" },
	interface_widgets   = { tab = "interface", subTab = "widgets",     subTabKey = "interfaceSubTab" },
	interface_visuals   = { tab = "interface", subTab = "visuals",     subTabKey = "interfaceSubTab" },
	interface_info      = { tab = "interface", subTab = "info",        subTabKey = "interfaceSubTab" },
	interface_spectator = { tab = "interface", subTab = "spectator",   subTabKey = "interfaceSubTab" },
	control             = { tab = "control" },
	game                = { tab = "game" },
	dev                 = { tab = "dev" },
	notifications       = { tab = "notifications" },
	accessibility       = { tab = "accessibility" },
}

-- Display order for search-result section headings (one per sub-tab location).
-- Matches the tab-rail order so grouped results read top-to-bottom the same way
-- the tabs do, instead of the unordered pairs() order of the config map.
local SUBTAB_ORDER = {
	"gfx_display", "gfx_rendering", "gfx_environment",
	"audio",
	"interface_general", "interface_widgets", "interface_visuals", "interface_info", "interface_spectator",
	"control", "game", "notifications", "accessibility", "dev",
}
local subTabOrderIndex = {}
for i, k in ipairs(SUBTAB_ORDER) do subTabOrderIndex[k] = i end

-- Build a lookup of already-localized path labels for the breadcrumb shown
-- in the search results dropdown. Called from initModel() where we still
-- have direct access to the tab arrays before they go through the proxy.
local function buildPathLabelLookup(tabs, gfxSubTabs, interfaceSubTabs)
	pathLabels = {}
	local tabLabels = {}
	for _, t in ipairs(tabs) do tabLabels[t.id] = t.label end

	for _, s in ipairs(gfxSubTabs) do
		pathLabels["gfx/" .. s.id] = (tabLabels.gfx or "Graphics") .. " > " .. s.label
	end
	for _, s in ipairs(interfaceSubTabs) do
		pathLabels["interface/" .. s.id] = (tabLabels.interface or "Interface") .. " > " .. s.label
	end

	pathLabels["audio/"]         = tabLabels.audio         or "Audio"
	pathLabels["control/"]       = tabLabels.control       or "Control"
	pathLabels["game/"]          = tabLabels.game          or "Game"
	pathLabels["dev/"]           = tabLabels.dev           or "Dev"
	pathLabels["notifications/"] = tabLabels.notifications or "Notifications"
	pathLabels["accessibility/"] = tabLabels.accessibility or "Accessibility"
end

local function getPathLabel(tab, subTab)
	return pathLabels[tab .. "/" .. (subTab or "")] or tab
end

local function buildSearchIndex(cfg)
	local index = {}
	for subTabKey, subTabConfig in pairs(cfg) do
		local loc = TAB_KEY_MAP[subTabKey]
		if loc then
			-- First pass: index parent names by id so children can look them up.
			local parentNames = {}
			for _, entry in ipairs(subTabConfig) do
				if entry.id and entry.name and not entry.parentId then
					parentNames[entry.id] = entry.name
				end
			end

			for _, entry in ipairs(subTabConfig) do
				if entry.id and entry.type ~= "heading" and entry.name then
					local name = entry.name or ""
					local desc = entry.desc or ""
					index[#index + 1] = {
						id = entry.id,
						name = name,
						nameLower = name:lower(),
						desc = desc,
						descLower = desc:lower(),
						tab = loc.tab,
						subTab = loc.subTab,
						subTabKey = loc.subTabKey,
						-- locKey is the config/cache key (e.g. "gfx_display"); used
						-- to bucket + order search results by sub-category. pathLabel
						-- is the localized "Tab > SubTab" heading for that bucket.
						locKey = subTabKey,
						pathLabel = getPathLabel(loc.tab, loc.subTab),
						parentName = entry.parentId and parentNames[entry.parentId] or nil,
					}
				end
			end
		end
	end
	return index
end

-----------------------------------------------------------------------
-- Toggle state: separate from config entries, never touches proxy
-----------------------------------------------------------------------

local toggleState = {}

-----------------------------------------------------------------------
-- Format slider value to match step precision (strip float noise)
-----------------------------------------------------------------------

local function formatValue(value, step)
	step = step or 1
	if step >= 1 then
		return tostring(math.floor(value + 0.5))
	end
	local stepStr = tostring(step)
	local dot = stepStr:find("%.")
	local decimals = dot and (#stepStr - dot) or 1
	return string.format("%." .. decimals .. "f", value)
end

-----------------------------------------------------------------------
-- Event handlers
-----------------------------------------------------------------------

-- Bool: state in toggleState, visual via DOM class swap, side effect via onChange
function widget:OnToggle(element)
	local id = (element:GetAttribute("id") or ""):gsub("^cfg%-", "")
	local entry = optionById[id]
	if not entry or entry.disabled then return end

	toggleState[id] = not toggleState[id]
	local val = toggleState[id]

	if entry.onChange then entry.onChange(val) end

	-- Visual: swap toggle segment classes on the parent panel
	local panel = element:QuerySelector(".toggle-panel")
	if panel then
		local danger = panel:GetChild(0)
		local success = panel:GetChild(1)
		if danger then
			danger:SetAttribute("class",
				val and "toggle-seg toggle-seg-inactive-danger"
				     or "toggle-seg toggle-seg-danger")
		end
		if success then
			success:SetAttribute("class",
				val and "toggle-seg toggle-seg-success"
				     or "toggle-seg toggle-seg-inactive-success")
		end
	end

	-- Dimming: find the children container and dim/undim it
	if document then
		local childContainer = document:GetElementById("children-" .. id)
		if childContainer then
			childContainer:SetClass("dimmed", not val)
		end
	end
end

-- Slider: read value from element (not model — data-value updates after event
-- per RmlUi #668). Call side effect, update readback via DOM.
--
-- Guard against spurious fires: RmlUi re-creates input/select elements when
-- their parent data-for array is reassigned (e.g. our lazy-populate tab
-- switcher), and recreation raises `onchange` even though the value didn't
-- actually change. Track the last-applied value on the entry and skip
-- `entry.onChange` when the incoming value matches.
function widget:OnSlider(element)
	local id = (element:GetAttribute("id") or ""):gsub("^cfg%-", "")
	local entry = optionById[id]
	if not entry or entry.disabled then return end

	-- Swallow the recreation-time spurious onchange (see controlSettleFrame).
	if Spring.GetDrawFrame() - controlSettleFrame <= CONTROL_SETTLE_FRAMES then
		return
	end

	local value = tonumber(element:GetAttribute("value"))
	if value then
		if entry.value ~= value then
			entry.value = value
			if entry.onChange then entry.onChange(value) end
		end
		if document then
			local span = document:GetElementById("val-" .. id)
			if span then
				span.inner_rml = formatValue(value, entry.step or 1)
			end
		end
	end
end

-- Select: read value from element, call side effect. Same spurious-fire
-- guard as OnSlider.
function widget:OnSelect(element)
	local id = (element:GetAttribute("id") or ""):gsub("^cfg%-", "")
	local entry = optionById[id]
	if not entry or entry.disabled then return end

	-- Swallow the recreation-time spurious onchange (see controlSettleFrame).
	-- This is the rml_theme="base" reset fix: on tab (re)populate the select
	-- briefly reports its first option ("base") before data-attr-selected
	-- binds, and the entry.value guard below does NOT catch it (loaded value
	-- != "base"), so without this it would apply base and call rml_theme_changed.
	if Spring.GetDrawFrame() - controlSettleFrame <= CONTROL_SETTLE_FRAMES then
		return
	end

	local value = element:GetAttribute("value")
	if value == nil then return end

	-- Coerce to number if the selectOptions use numeric values.
	if entry.selectOptions and entry.selectOptions[1] and type(entry.selectOptions[1].value) == "number" then
		value = tonumber(value)
	end

	if entry.value == value then return end
	entry.value = value
	if entry.onChange then entry.onChange(value) end
end

-- Action: just call onClick.
function widget:OnAction(element)
	local id = (element:GetAttribute("id") or ""):gsub("^cfg%-", "")
	local entry = optionById[id]
	if entry and not entry.disabled and entry.onClick then
		entry.onClick()
	end
end

-- Single dispatch point for the unified setting-row. The row's onclick fires
-- regardless of the option type; we look up the entry and route to the
-- per-type handler. Slider and select use `onchange` on their inner input/
-- select elements, so this click dispatch is a no-op for them (click events
-- bubble up from those inner controls but hit this function with type slider
-- or select and return quietly).
function widget:OnSettingClick(element)
	local id = (element:GetAttribute("id") or ""):gsub("^cfg%-", "")
	local entry = optionById[id]
	if not entry or entry.disabled then return end
	if entry.type == "bool" then
		widget:OnToggle(element)
	elseif entry.type == "action" then
		widget:OnAction(element)
	end
end

-- Reset just the search model fields (no repopulate). Callers that immediately
-- (re)populate a tab themselves use this; clearSearch wraps it for the cases
-- that need the current tab restored.
local function exitSearchState()
	if not dm_handle then return end
	lastSearchValue = nil
	dm_handle.searchQuery = ""
	dm_handle.searchSections = {}
	dm_handle.searchResultCount = 0
	dm_handle.searchActive = false
	-- Search off → the content panel returns to the currently-selected tab.
	dm_handle.contentView = dm_handle.activeTab
end

-- Clear search AND restore the active tab's content. Used when the query drops
-- below MIN_SEARCH_CHARS and on Escape (the tab doesn't change in those cases).
local function clearSearch()
	if not dm_handle then return end
	exitSearchState()
	-- Bring the normal tab content back (search emptied the tab arrays).
	populateActiveTabData(dm_handle.activeTab, dm_handle.gfxSubTab, dm_handle.interfaceSubTab)
end

-- Live cross-category filter. Builds the matching options into the SAME
-- { heading, groups } section shape the tabs use, grouped by sub-category and
-- ordered like the tab rail, then swaps them into dm_handle.searchSections and
-- flips searchActive. The search panel in the RML renders these through the
-- exact same interactive row markup as the tabs (real sliders/toggles/selects),
-- so options are editable in place — no navigate-and-scroll. We reuse the live
-- config entries from optionById (which carry current values + full field set),
-- not the lighter searchIndex rows. Called from onSearchInput (data-event-keyup)
-- with the value read off the element (RmlUi #668 — model commits after event).
local function performSearch(raw)
	if not dm_handle then return end
	local q = (raw or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")

	if #q < MIN_SEARCH_CHARS then
		clearSearch()
		return
	end

	-- Bucket matches by sub-category (locKey), preserving tab-rail order.
	local buckets = {}
	local count = 0
	for i = 1, #searchIndex do
		local e = searchIndex[i]
		if e.nameLower:find(q, 1, true) or e.descLower:find(q, 1, true) then
			local entry = optionById[e.id]
			if entry then
				local b = buckets[e.locKey]
				if not b then
					b = { heading = e.pathLabel, order = subTabOrderIndex[e.locKey] or 999, groups = {} }
					buckets[e.locKey] = b
				end
				-- Each match renders as a standalone row (no nested children in
				-- search results — a matched child is shown on its own).
				b.groups[#b.groups + 1] = {
					parent = entry,
					children = {},
					hasChildren = false,
					parentOff = false,
				}
				count = count + 1
			end
		end
	end

	local ordered = {}
	for _, b in pairs(buckets) do ordered[#ordered + 1] = b end
	table.sort(ordered, function(a, b) return a.order < b.order end)

	local sections = {}
	for _, b in ipairs(ordered) do
		sections[#sections + 1] = { heading = b.heading, groups = b.groups }
	end

	-- Empty the tab arrays so only the search panel produces DOM (data-if just
	-- hides — see rmlui_data_if_keeps_in_dom; emptying the arrays is what
	-- actually keeps the element count down). This also stamps controlSettleFrame
	-- so the spurious recreation onchange from the new selects is swallowed.
	populateActiveTabData(nil, nil, nil)
	dm_handle.searchSections = sections
	dm_handle.searchResultCount = count
	dm_handle.searchActive = true
	dm_handle.contentView = "search"
end

-----------------------------------------------------------------------
-- Data model factory
-----------------------------------------------------------------------

local function initModel()
	-- `abbr` is the short label shown in the icon-only tab rail.
	-- Custom SVG icons are a follow-up; abbreviations ship now.
	local tabs = {
		{ id = "gfx",           label = Spring.I18N('ui.settings.group.graphics')      or "Graphics",      abbr = "GFX"  },
		{ id = "audio",         label = Spring.I18N('ui.settings.group.audio')         or "Audio",         abbr = "AUD"  },
		{ id = "interface",     label = Spring.I18N('ui.settings.group.interface')     or "Interface",     abbr = "UI"   },
		{ id = "control",       label = Spring.I18N('ui.settings.group.control')       or "Control",       abbr = "CTL"  },
		{ id = "game",          label = Spring.I18N('ui.settings.group.game')          or "Game",          abbr = "GAM"  },
		{ id = "notifications", label = Spring.I18N('ui.settings.group.notifications') or "Notifications", abbr = "NTF"  },
		{ id = "accessibility", label = Spring.I18N('ui.settings.group.accessibility') or "Accessibility", abbr = "A11Y" },
		{ id = "dev",           label = Spring.I18N('ui.settings.group.dev')           or "Dev",           abbr = "DEV"  },
	}

	local gfxSubTabs = {
		{ id = "display",     label = Spring.I18N('ui.settings.subtab.display')     or "Display" },
		{ id = "rendering",   label = Spring.I18N('ui.settings.subtab.rendering')   or "Rendering" },
		{ id = "environment", label = Spring.I18N('ui.settings.subtab.environment') or "Environment" },
	}

	local interfaceSubTabs = {
		{ id = "general",   label = Spring.I18N('ui.settings.option.label_interface') or "General" },
		{ id = "widgets",   label = Spring.I18N('ui.settings.option.label_widgets')   or "Widgets" },
		{ id = "visuals",   label = Spring.I18N('ui.settings.option.label_visuals')   or "Visuals" },
		{ id = "info",      label = Spring.I18N('ui.settings.option.label_info')      or "Info" },
		{ id = "spectator", label = Spring.I18N('ui.settings.option.label_spectator') or "Spectator" },
	}

	-- Build the localized path-label lookup now, while we have direct
	-- access to the tab arrays (before they go through the data-model proxy).
	buildPathLabelLookup(tabs, gfxSubTabs, interfaceSubTabs)

	return {
		my = {
			panelHeading = "panel-heading-abs text-lg font-bold text-primary",
			-- Per-option wrapper. Previously used ccg.card.general, which
			-- expands to "bg-darker-alpha p-2 box-shadow-sm" — that shadow
			-- per option group × ~20 groups × N tabs was a major cost.
			-- Stripped the shadow; the panel signature already provides
			-- enough visual separation between rows.
			optionCard = "bg-darker-alpha p-2",
		},

		-- Top-level tab nav. activeTab drives the tab-rail highlight (and the
		-- sub-tab nav); contentView drives WHICH content panel shows. They match
		-- normally, but while a search is active contentView == "search" so the
		-- results panel replaces the tab content while the rail still highlights
		-- the tab you'd return to. Using a single == discriminator (not
		-- activeTab == X && !searchActive) keeps every data-if to the simple,
		-- well-supported equality form.
		activeTab = "gfx",
		contentView = "gfx",
		tabs = tabs,

		-- Graphics sub-tabs
		gfxSubTab = "display",
		gfxSubTabs = gfxSubTabs,

		-- Interface sub-tabs
		interfaceSubTab = "general",
		interfaceSubTabs = interfaceSubTabs,

		-- Tab / sub-tab navigation — REPLACES inline "activeTab = tab.id" /
		-- "gfxSubTab = st.id" assignments in the RML. An inline data-event
		-- assignment only updates RmlUi's own binding (so the highlight moves)
		-- and does NOT write back through the Lua data-model proxy, so
		-- widget:Update's poll of dm_handle never sees the switch and the new
		-- tab is never populated. Writing via dm_handle here is the sanctioned
		-- Lua path (keeps both sides in sync); we also repopulate immediately so
		-- the panel fills the same frame instead of waiting for the poll.
		-- Clicking any tab/sub-tab also leaves search mode: clear the query +
		-- result state and flip searchActive off so the tab content shows. We
		-- clear inline (not via clearSearch, which repopulates the CURRENT tab)
		-- because we're switching to a different tab in the same call.
		selectTab = function(_, id)
			exitSearchState()
			dm_handle.activeTab = id
			dm_handle.contentView = id
			populateActiveTabData(id, dm_handle.gfxSubTab, dm_handle.interfaceSubTab)
		end,
		selectGfxSubTab = function(_, id)
			exitSearchState()
			dm_handle.gfxSubTab = id
			populateActiveTabData("gfx", id, dm_handle.interfaceSubTab)
		end,
		selectInterfaceSubTab = function(_, id)
			exitSearchState()
			dm_handle.interfaceSubTab = id
			populateActiveTabData("interface", dm_handle.gfxSubTab, id)
		end,

		-- Search state. searchActive flips the whole panel from tab content to the
		-- grouped results view; searchSections holds the matches in the same
		-- { heading, groups } shape the tabs use (rendered by the same interactive
		-- row markup). searchResultCount drives the "N results" / no-matches line.
		searchQuery = "",
		searchActive = false,
		searchSections = {},
		searchResultCount = 0,

		onSearchInput = function(ev, keyId)
			-- Escape (81) is handled in onSearchKeyDown (clears + defocuses);
			-- ignore it here so a keyup re-read can't immediately re-filter.
			if keyId == 81 then return end
			-- Read the value from the ELEMENT, not the model: data-value
			-- commits AFTER the event (RmlUi #668). keyup => per-keystroke.
			local el = ev and ev.current_element  -- the bound input (see CLAUDE.md)
			local q = (el and el:GetAttribute("value")) or ""
			if q == lastSearchValue then return end
			lastSearchValue = q
			performSearch(q)
		end,

		onSearchKeyDown = function(ev, keyId)
			local KI_ESCAPE = 81
			if keyId == KI_ESCAPE then
				clearSearch()
				-- Pull focus away from the input by focusing the widget body.
				-- RmlUi has no Blur() API, but focusing a non-input element
				-- implicitly defocuses the text input.
				if document then
					local body = document:GetElementById("widget-container")
					if body then
						pcall(function() body:Focus() end)
					end
				end
			end
		end,

		-- Section data (populated in Initialize, written once, never mutated)
		gfxDisplaySections = {},
		gfxRenderingSections = {},
		gfxEnvironmentSections = {},
		audioSections = {},
		interfaceGeneralSections = {},
		interfaceWidgetsSections = {},
		interfaceVisualsSections = {},
		interfaceInfoSections = {},
		interfaceSpectatorSections = {},
		controlSections = {},
		gameSections = {},
		devSections = {},
		notificationsSections = {},
		accessibilitySections = {},
	}
end

-----------------------------------------------------------------------
-- Deferred content init — runs once from widget:Update() rather than
-- widget:Initialize(). Reason: several config entries depend on WG.*
-- tables (e.g. WG.screenMode from cmd_resolution_switcher at layer 0)
-- that aren't populated yet when Initialize runs at layer -1000. By the
-- first Update call, every widget has finished loading and initializing,
-- so those WG hooks are safe to read. Mirrors the legacy gui_options.lua
-- pattern (see the comment at gui_options.lua:1165).
-----------------------------------------------------------------------

local contentInitialized = false

-- Populate selectOptions for entries that need runtime data from other widgets.
local function populateDynamicSelectOptions()
	-- Monitor list from WG.screenMode
	local displayEntry = optionById["display"]
	if displayEntry and WG['screenMode'] and WG['screenMode'].GetDisplays then
		local displays = WG['screenMode'].GetDisplays() or {}
		local opts = {}
		for i, d in ipairs(displays) do
			if d.width and d.width > 0 then
				opts[#opts + 1] = {
					value = i,
					label = i .. ": " .. (d.name or "Display") .. " " .. d.width .. "×" .. d.height .. " (" .. (d.hz or "?") .. "hz)",
				}
			end
		end
		displayEntry.selectOptions = opts
	end

	-- Resolution list from WG.screenMode, filtered to the currently selected display
	local resEntry = optionById["resolution"]
	if resEntry and WG['screenMode'] and WG['screenMode'].GetScreenModes then
		local screenModes = WG['screenMode'].GetScreenModes() or {}
		local currentDisplay = Spring.GetConfigInt("SelectedDisplay", 1)
		local opts = {}
		for i, mode in ipairs(screenModes) do
			if mode.display == currentDisplay then
				opts[#opts + 1] = { value = i, label = mode.name or tostring(i) }
			end
		end
		resEntry.selectOptions = opts
	end
end

-- Local cache of built sections for every sub-tab. Populated once at
-- initializeContent(); only the active tab's entry is ever assigned to
-- dm_handle. See populateActiveTabData() below.
--
-- Why: RmlUi's `data-if` sets display:none on the element but keeps it in
-- the DOM — hidden elements are still Update-walked every frame. V1 with
-- all 8 tabs + 14 sub-tabs mounted simultaneously = 7800 elements walked
-- per frame for ~2.9 ms overhead. Keeping inactive tabs' arrays empty
-- means the data-for loops produce zero child elements and the walk
-- collapses to just the active tab (~1000 elements, ~0.4 ms).
local sectionsCache = {}

-- Maps top-level tab id → list of { modelKey, cacheKey, subTabId } entries.
-- Single-section tabs have one entry with subTabId=nil; multi-section tabs
-- have one entry per sub-tab.
local tabPlan = {
	gfx = {
		subTabVar = "gfxSubTab",
		entries = {
			{ modelKey = "gfxDisplaySections",     cacheKey = "gfx_display",     subTab = "display" },
			{ modelKey = "gfxRenderingSections",   cacheKey = "gfx_rendering",   subTab = "rendering" },
			{ modelKey = "gfxEnvironmentSections", cacheKey = "gfx_environment", subTab = "environment" },
		},
	},
	interface = {
		subTabVar = "interfaceSubTab",
		entries = {
			{ modelKey = "interfaceGeneralSections",   cacheKey = "interface_general",   subTab = "general" },
			{ modelKey = "interfaceWidgetsSections",   cacheKey = "interface_widgets",   subTab = "widgets" },
			{ modelKey = "interfaceVisualsSections",   cacheKey = "interface_visuals",   subTab = "visuals" },
			{ modelKey = "interfaceInfoSections",      cacheKey = "interface_info",      subTab = "info" },
			{ modelKey = "interfaceSpectatorSections", cacheKey = "interface_spectator", subTab = "spectator" },
		},
	},
	audio         = { entries = { { modelKey = "audioSections",         cacheKey = "audio"         } } },
	control       = { entries = { { modelKey = "controlSections",       cacheKey = "control"       } } },
	game          = { entries = { { modelKey = "gameSections",          cacheKey = "game"          } } },
	notifications = { entries = { { modelKey = "notificationsSections", cacheKey = "notifications" } } },
	accessibility = { entries = { { modelKey = "accessibilitySections", cacheKey = "accessibility" } } },
	dev           = { entries = { { modelKey = "devSections",           cacheKey = "dev"           } } },
}

-- Last-known tab/sub-tab state; compared against dm_handle each Update to
-- detect user tab switches and re-shuffle the populated arrays. Starts nil
-- so the first Update after initializeContent() always triggers one pass.
local lastActiveTab = nil
local lastGfxSubTab = nil
local lastInterfaceSubTab = nil

-- Last-known `show` state. Compared in widget:Update so that opening V1
-- populates the active tab's arrays and closing V1 empties them — saving
-- the Update-walk cost of a mounted-but-off-screen options panel.
local lastShow = false

-- Write empty arrays to every sub-tab model key, then populate only the
-- entries whose sub-tab matches (or single-section tabs get their one entry).
function populateActiveTabData(activeTab, gfxSubTab, interfaceSubTab)
	-- Mark the settle window so the spurious recreation onchange that follows
	-- this reassignment is ignored by OnSelect/OnSlider (see declaration).
	controlSettleFrame = Spring.GetDrawFrame()
	for _, plan in pairs(tabPlan) do
		for _, entry in ipairs(plan.entries) do
			dm_handle[entry.modelKey] = {}
		end
	end
	local plan = tabPlan[activeTab]
	if not plan then return end
	for _, entry in ipairs(plan.entries) do
		local subTabMatches = (entry.subTab == nil)
			or (plan.subTabVar == "gfxSubTab" and entry.subTab == gfxSubTab)
			or (plan.subTabVar == "interfaceSubTab" and entry.subTab == interfaceSubTab)
		if subTabMatches then
			dm_handle[entry.modelKey] = sectionsCache[entry.cacheKey] or {}
		end
	end
end

local function initializeContent()
	-- Populate dynamic selectOptions BEFORE reading onLoad / building sections,
	-- so the first render has the full list available.
	populateDynamicSelectOptions()

	-- Load current values from config onLoad functions.
	-- Seed bools: force boolean, copy into toggleState (source of truth for clicks).
	-- Normalize the field union: the RML row template binds group.parent.disabled
	-- on every row and group.parent.labelClass inside the action ternary, and
	-- RmlUi evaluates BOTH ternary/data-if branches regardless of which renders —
	-- so any entry missing those fields logs "Could not get value from data
	-- variable ...". Only a couple of entries declare them in config, so default
	-- the rest here (see rmlui_datafor_homogeneous: data-for rows must be a full
	-- field union with safe defaults). These live entries are shared by the tab
	-- sections and the search sections (both via optionById), so one pass covers
	-- both views.
	for _, subTabConfig in pairs(allConfig) do
		for _, entry in ipairs(subTabConfig) do
			if entry.onLoad then
				entry.value = entry.onLoad()
			end
			if entry.type == "bool" then
				entry.value = (entry.value == true)
				toggleState[entry.id] = entry.value
			end
			if entry.disabled == nil then entry.disabled = false end
			if entry.labelClass == nil then entry.labelClass = "" end
		end
	end

	-- Build every sub-tab's section tree once, cache locally. Then seed all
	-- model arrays to empty and populate only the active tab. Subsequent tab
	-- switches re-shuffle in widget:Update.
	sectionsCache.gfx_display         = buildSections(allConfig.gfx_display)
	sectionsCache.gfx_rendering       = buildSections(allConfig.gfx_rendering)
	sectionsCache.gfx_environment     = buildSections(allConfig.gfx_environment)
	sectionsCache.audio               = buildSections(allConfig.audio)
	sectionsCache.interface_general   = buildSections(allConfig.interface_general)
	sectionsCache.interface_widgets   = buildSections(allConfig.interface_widgets)
	sectionsCache.interface_visuals   = buildSections(allConfig.interface_visuals)
	sectionsCache.interface_info      = buildSections(allConfig.interface_info)
	sectionsCache.interface_spectator = buildSections(allConfig.interface_spectator)
	sectionsCache.control             = buildSections(allConfig.control)
	sectionsCache.game                = buildSections(allConfig.game)
	sectionsCache.dev                 = buildSections(allConfig.dev)
	sectionsCache.notifications       = buildSections(allConfig.notifications)
	sectionsCache.accessibility       = buildSections(allConfig.accessibility)

	-- Initial populate only if V1 happens to be visible at this point
	-- (unusual — V1 starts hidden). Otherwise widget:Update will populate
	-- on the first open-transition. Seed last* state either way so the
	-- polling doesn't fire a redundant populate on the first frame.
	if show then
		populateActiveTabData(dm_handle.activeTab, dm_handle.gfxSubTab, dm_handle.interfaceSubTab)
	end
	lastActiveTab       = dm_handle.activeTab
	lastGfxSubTab       = dm_handle.gfxSubTab
	lastInterfaceSubTab = dm_handle.interfaceSubTab
	lastShow            = show

	-- Build the search index now that onLoad has populated live name/desc
	-- values for entries whose labels depend on runtime state.
	searchIndex = buildSearchIndex(allConfig)
end

-----------------------------------------------------------------------
-- Widget lifecycle
-----------------------------------------------------------------------

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
	contentInitialized = false

	-- Start closed: hidden and out of the context's active set. Open does
	-- document:Show() (which also raises + focuses) then a one-frame-deferred
	-- .drawer-open class so the slide-in animates from the default
	-- translateX(-100%); close slides out then document:Hide() after the
	-- transition. See toggleShow + widget:Update.
	bodyElement = document:GetElementById('gui_options_rml-widget')
	document:Hide()
	show = false

	-- Glass-over-game: register the drawer body with the RML→guishader bridge
	-- so the 3D world blurs behind the options panel too. Globally gated by
	-- the "world blur" interface setting (WG['rml_guishader'].setEnabled).
	-- The drawer stays mounted and slides off-screen when closed, so the
	-- bridge relies on the `show` predicate (not geometry) to drop the rect.
	if WG['rml_guishader'] then
		WG['rml_guishader'].register(WIDGET_ID, bodyElement, {
			isVisible = function() return show end,
		})
	end

	WG['options_rml'] = {
		toggle    = function(state) toggleShow(state) end,
		isvisible = function() return show end,
		-- First Esc clears an active search (handled by onSearchKeyDown); only
		-- then should Esc fall through to the topbar to close the window. While
		-- search is active we tell the topbar to hold the close.
		disallowEsc = function()
			return show and dm_handle and dm_handle.searchActive
		end,
	}

	widgetHandler.actionHandler:AddAction(self, "options_rml", function() toggleShow() end, nil, 't')

	-- Perf diagnostics. Not user-facing; used with dbg_rml_perf_sweep to
	-- figure out where V1's cost is coming from.
	widgetHandler.actionHandler:AddAction(self, "options_rml_elemcount", function()
		if not document then return end
		local function countSel(sel)
			local els = document:QuerySelectorAll(sel)
			return els and #els or 0
		end
		local function countById(id)
			local el = document:GetElementById(id)
			if not el then return 0 end
			local els = el:QuerySelectorAll("*")
			return (els and #els or 0) + 1
		end
		local total = countSel("*")
		-- .options-content is the wrapper each tab uses. If data-if is actually
		-- removing inactive tabs, there will be exactly ONE of these. If data-if
		-- keeps them all in the DOM, there will be 8 (one per top-level tab).
		local optionsContentCount = countSel(".options-content")
		local scrollAreaCount = countSel(".scroll-area")
		local settingRowCount = countSel(".setting-row")
		Spring.Echo(string.format(
			"[options_rml V1] total=%d | tab-rail=%d | drawer=%d | .options-content=%d | .scroll-area=%d | .setting-row=%d | active=%s/%s",
			total, countById("tab-rail"), countById("drawer-content"),
			optionsContentCount, scrollAreaCount, settingRowCount,
			tostring(dm_handle and dm_handle.activeTab or "?"),
			tostring(dm_handle and dm_handle.gfxSubTab or "?")
		))
	end, nil, 't')

	-- Toggle document:Hide()/Show() on V1 — direct test of whether actually
	-- hiding (vs translateX off-screen) recovers Render cost. Separate from
	-- the normal toggleShow so we can measure each independently.
	local docHidden = false
	widgetHandler.actionHandler:AddAction(self, "options_rml_dochide", function()
		if not document then return end
		docHidden = not docHidden
		if docHidden then document:Hide() else document:Show() end
		Spring.Echo("[options_rml V1] document:Hide() = " .. tostring(docHidden))
	end, nil, 't')

	return true
end

function widget:Shutdown()
	widgetHandler.actionHandler:RemoveAction(self, "options_rml")
	widgetHandler.actionHandler:RemoveAction(self, "options_rml_elemcount")
	widgetHandler.actionHandler:RemoveAction(self, "options_rml_dochide")
	WG['options_rml'] = nil

	if WG['rml_guishader'] then
		WG['rml_guishader'].unregister(WIDGET_ID)
	end

	utils.shutdownRmlWidget(self, {
		widgetId = WIDGET_ID,
		modelName = MODEL_NAME,
	}, document, dm_handle)

	document = nil
	dm_handle = nil
	bodyElement = nil
	show = false
end

function widget:Update()
	if not dm_handle then return end

	-- Slide-in: .drawer-open is added the frame AFTER document:Show() so the
	-- transform transition has a laid-out translateX(-100%) 'from' state and
	-- animates instead of snapping straight to open.
	if pendingOpenClass and bodyElement then
		bodyElement:SetClass('drawer-open', true)
		pendingOpenClass = false
	end

	-- Slide-out: once the close transition has elapsed, drop the document
	-- from the context's active set. Re-opening clears hideTimer in
	-- toggleShow; the `show` guard here is a belt-and-braces backstop.
	if hideTimer then
		if show then
			hideTimer = nil
		elseif Spring.DiffTimers(Spring.GetTimer(), hideTimer) >= SLIDE_OUT_SEC then
			if document then document:Hide() end
			hideTimer = nil
		end
	end

	-- First-call deferred init: all widgets have now loaded, so WG.screenMode
	-- (and any other dependent WG hooks) are available for dynamic selectOptions.
	if not contentInitialized then
		contentInitialized = true
		initializeContent()
	end

	-- Detect open/close transitions first. When V1 is hidden we empty all
	-- section arrays entirely — the data-for loops iterate over empty tables
	-- and produce zero children, collapsing the Update-walk to the
	-- always-present shell elements only. When V1 opens, we populate the
	-- active tab's array. This is the price of RmlUi's data-if being a
	-- display toggle rather than DOM removal (see rmlui_data_if_keeps_in_dom).
	if show ~= lastShow then
		lastShow = show
		if show then
			-- Open fresh on the selected tab — drop any search left from a
			-- previous session (exitSearchState resets contentView to activeTab).
			exitSearchState()
			populateActiveTabData(dm_handle.activeTab, dm_handle.gfxSubTab, dm_handle.interfaceSubTab)
			lastActiveTab       = dm_handle.activeTab
			lastGfxSubTab       = dm_handle.gfxSubTab
			lastInterfaceSubTab = dm_handle.interfaceSubTab
		else
			populateActiveTabData(nil, nil, nil)
		end
	elseif show then
		-- Only poll for tab/sub-tab changes while V1 is visible. If something
		-- programmatically changes a tab while V1 is closed, we don't care —
		-- the next open-transition will populate from the current state.
		local currentTab         = dm_handle.activeTab
		local currentGfxSubTab   = dm_handle.gfxSubTab
		local currentInterfaceSubTab = dm_handle.interfaceSubTab
		if currentTab ~= lastActiveTab
			or (currentTab == "gfx" and currentGfxSubTab ~= lastGfxSubTab)
			or (currentTab == "interface" and currentInterfaceSubTab ~= lastInterfaceSubTab)
		then
			populateActiveTabData(currentTab, currentGfxSubTab, currentInterfaceSubTab)
			lastActiveTab         = currentTab
			lastGfxSubTab         = currentGfxSubTab
			lastInterfaceSubTab   = currentInterfaceSubTab
		end
	end

end

