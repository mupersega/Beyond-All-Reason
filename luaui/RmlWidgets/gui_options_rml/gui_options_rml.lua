if not RmlUi then
	return
end

local widget = widget ---@type Widget
local utils = VFS.Include("luaui/Include/rml_utilities/utils.lua")
local ccg = VFS.Include("luaui/Include/rml_utilities/common_class_groups.lua")
include("keysym.h.lua")

function widget:GetInfo()
	return {
		name = "Options RML (V1 heavy)",
		desc = "Original RML-based options panel with full tab/search/CCG system. Kept for reference; the lightweight 'Options RML' V2 is the default.",
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
local lastRmlDebug = nil

-- Search feature state
local searchIndex = {}          -- flat list built at content-init, source of truth for search
local pathLabels = {}           -- ["gfx/display"] -> "Graphics > Display" (localized)
local localSearchResults = {}   -- local mirror of results for arrow-nav lookup (never read from proxy)
local selectedIndex = 0         -- 0 = none; 1-based index into localSearchResults
local lastSearchValue           -- guard: only re-filter when the input text actually changed (nav-key keyups must not reset the dropdown)
local pendingScrollId = nil     -- id to scroll into view next Update after tab switch
local pendingScrollElement = nil -- element ref found on frame N; scrolled on frame N+1
local pendingScrollFrames = 0   -- retry counter for deferred scroll
local highlightElement = nil    -- currently-highlighted option card
local highlightTimer = nil      -- Spring.GetTimer ref; nil when no highlight active

local MIN_SEARCH_CHARS = 3
local MAX_SEARCH_RESULTS = 12
local MAX_SCROLL_RETRY_FRAMES = 10
local HIGHLIGHT_DURATION_SEC = 1.5

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
local bodyElement  -- cached #gui_options_rml-widget element; populated in Initialize
local function toggleShow(newState)
	if newState == nil then
		newState = not show
	end
	if newState and WG['topbar'] then
		WG['topbar'].hideWindows()
	end
	show = newState
	-- Drawer visibility is class-driven so the slide transition fires.
	-- The document itself stays mounted; translateX(-100%) takes it off-screen.
	if bodyElement then
		bodyElement:SetClass('drawer-open', show)
	end
	if show then
		Spring.SDLStartTextInput()
		widgetHandler.textOwner = nil
	else
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

-- Filter searchIndex by plain substring match (name weighted higher than
-- desc), cap results, and push to the proxy for the dropdown. Called from
-- the `onSearchInput` model function (wired to `data-event-keyup` on the
-- search input) with the value read from the element, not the model.
local function performSearch(raw)
	if not dm_handle then return end
	raw = raw or ""
	local q = raw:lower():gsub("^%s+", ""):gsub("%s+$", "")

	if #q < MIN_SEARCH_CHARS then
		dm_handle.searchResults = {}
		dm_handle.showSearchResults = false
		return
	end

	local scored = {}
	for i = 1, #searchIndex do
		local entry = searchIndex[i]
		local score = 0
		if entry.nameLower:find(q, 1, true) then score = score + 10 end
		if entry.descLower:find(q, 1, true) then score = score + 1 end
		if score > 0 then
			scored[#scored + 1] = { entry = entry, score = score }
		end
	end
	table.sort(scored, function(a, b)
		if a.score ~= b.score then return a.score > b.score end
		return a.entry.nameLower < b.entry.nameLower
	end)

	local results = {}
	local limit = math.min(#scored, MAX_SEARCH_RESULTS)
	for i = 1, limit do
		local e = scored[i].entry
		-- Build full breadcrumb: "Tab > SubTab > [Parent >] Name"
		local path = getPathLabel(e.tab, e.subTab)
		if e.parentName then
			path = path .. " > " .. e.parentName
		end
		path = path .. " > " .. e.name
		results[#results + 1] = {
			id = e.id,
			name = e.name,
			pathLabel = path,
			index = i,
		}
	end
	localSearchResults = results
	selectedIndex = 0
	dm_handle.selectedResultIndex = 0
	dm_handle.searchResults = results
	dm_handle.showSearchResults = #results > 0
end

-- Navigate to a search result: switch tab + sub-tab, clear search UI, queue
-- a deferred scroll. Shared by OnSearchResultClick (mouse) and KeyPress (Enter).
local function navigateToResult(id)
	if not dm_handle or not id or id == "" then return end

	local target
	for i = 1, #searchIndex do
		if searchIndex[i].id == id then
			target = searchIndex[i]
			break
		end
	end
	if not target then return end

	dm_handle.activeTab = target.tab
	if target.subTabKey and target.subTab then
		dm_handle[target.subTabKey] = target.subTab
	end

	dm_handle.searchQuery = ""
	dm_handle.searchResults = {}
	dm_handle.showSearchResults = false
	localSearchResults = {}
	lastSearchValue = nil
	selectedIndex = 0
	dm_handle.selectedResultIndex = 0

	if highlightElement then
		highlightElement:SetClass("highlight-search-match", false)
		highlightElement = nil
	end
	highlightTimer = nil
	pendingScrollId = id
	pendingScrollElement = nil
	pendingScrollFrames = 0
end

function widget:OnSearchResultClick(element)
	local id = (element:GetAttribute("id") or ""):gsub("^searchresult%-", "")
	navigateToResult(id)
end

-- Form submit: Enter pressed while the search input has focus. RmlUi fires
-- a submit event on the <form> element at the C++ level before Lua's
-- widget:KeyPress ever sees the key — so we catch it here instead.
function widget:OnSearchSubmit()
	Spring.Echo("[options_rml] OnSearchSubmit fired — selectedIndex=" .. tostring(selectedIndex) .. " resultCount=" .. tostring(#localSearchResults))
	if not dm_handle or #localSearchResults == 0 then return end
	local idx = selectedIndex
	if idx < 1 then idx = 1 end
	if idx <= #localSearchResults then
		navigateToResult(localSearchResults[idx].id)
	end
end

-- Arrow-key navigation: when the dropdown is visible, intercept Up/Down.
-- Enter and Escape are handled elsewhere: Enter via data-event-submit on
-- the <form>, Escape via onSearchKeyDown (search-clear) + topbar's
-- hideWindows/disallowEsc chain (widget-close).
function widget:KeyPress(key, mods, isRepeat)
	if not show or not dm_handle then return false end
	if not dm_handle.showSearchResults then return false end

	if key == KEYSYMS.DOWN then
		if selectedIndex < #localSearchResults then
			selectedIndex = selectedIndex + 1
			dm_handle.selectedResultIndex = selectedIndex
		end
		return true
	elseif key == KEYSYMS.UP then
		if selectedIndex > 1 then
			selectedIndex = selectedIndex - 1
			dm_handle.selectedResultIndex = selectedIndex
		end
		return true
	end

	return false
end

-- Tab navigation: RML uses inline proxy writes (data-event-mousedown="activeTab = tab.id")
-- so no handler methods needed here.

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
		debugMode = false,
		rmlDebugControls = false,

		my = {
			panelHeading = "panel-heading-abs text-lg font-bold text-primary",
			-- Per-option wrapper. Previously used ccg.card.general, which
			-- expands to "bg-darker-alpha p-2 box-shadow-sm" — that shadow
			-- per option group × ~20 groups × N tabs was a major cost.
			-- Stripped the shadow; the panel signature already provides
			-- enough visual separation between rows.
			optionCard = "bg-darker-alpha p-2",
		},

		-- Top-level tab nav
		activeTab = "gfx",
		tabs = tabs,

		-- Graphics sub-tabs
		gfxSubTab = "display",
		gfxSubTabs = gfxSubTabs,

		-- Interface sub-tabs
		interfaceSubTab = "general",
		interfaceSubTabs = interfaceSubTabs,

		-- Search state
		searchQuery = "",
		searchResults = {},
		showSearchResults = false,
		selectedResultIndex = 0,

		onSearchInput = function(ev, keyId)
			-- Nav/commit keys (Enter 72, Down 20, Up 19, Escape 81) are
			-- handled in onSearchKeyDown; ignore them here so a keyup
			-- can't re-filter — Escape clears the box in keydown and a
			-- stale element re-read would undo it — or reset the
			-- dropdown selection on Up/Down.
			if keyId == 72 or keyId == 20 or keyId == 19 or keyId == 81 then
				return
			end
			-- Read the value from the ELEMENT, not the model: data-value
			-- commits AFTER the event (RmlUi #668). keyup => per-keystroke.
			local el = ev and ev.target_element
			local q = (el and el:GetAttribute("value")) or ""
			if q == lastSearchValue then return end
			lastSearchValue = q
			performSearch(q)
		end,

		onSearchSubmit = function()
			Spring.Echo("[options_rml] onSearchSubmit fired — selectedIndex=" .. tostring(selectedIndex) .. " resultCount=" .. tostring(#localSearchResults))
			if #localSearchResults == 0 then return end
			local idx = selectedIndex
			if idx < 1 then idx = 1 end
			if idx <= #localSearchResults then
				navigateToResult(localSearchResults[idx].id)
			end
		end,

		onSearchKeyDown = function(ev, keyId)
			local KI_RETURN = 72
			local KI_DOWN = 20
			local KI_UP = 19
			local KI_ESCAPE = 81

			if keyId == KI_RETURN then
				if #localSearchResults > 0 then
					local idx = selectedIndex
					if idx < 1 then idx = 1 end
					if idx <= #localSearchResults then
						navigateToResult(localSearchResults[idx].id)
					end
				end
			elseif keyId == KI_DOWN then
				if selectedIndex < #localSearchResults then
					selectedIndex = selectedIndex + 1
					dm_handle.selectedResultIndex = selectedIndex
				end
			elseif keyId == KI_UP then
				if selectedIndex > 1 then
					selectedIndex = selectedIndex - 1
					dm_handle.selectedResultIndex = selectedIndex
				end
			elseif keyId == KI_ESCAPE then
				dm_handle.searchQuery = ""
				dm_handle.searchResults = {}
				dm_handle.showSearchResults = false
				localSearchResults = {}
				lastSearchValue = nil
				selectedIndex = 0
				dm_handle.selectedResultIndex = 0
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
local function populateActiveTabData(activeTab, gfxSubTab, interfaceSubTab)
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
	for _, subTabConfig in pairs(allConfig) do
		for _, entry in ipairs(subTabConfig) do
			if entry.onLoad then
				entry.value = entry.onLoad()
			end
			if entry.type == "bool" then
				entry.value = (entry.value == true)
				toggleState[entry.id] = entry.value
			end
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

	-- Drawer stays mounted; off-screen by default (no .drawer-open class).
	-- Showing/hiding just toggles the class to drive the slide transition.
	document:Show()
	bodyElement = document:GetElementById('gui_options_rml-widget')
	show = false

	WG['options_rml'] = {
		toggle    = function(state) toggleShow(state) end,
		isvisible = function() return show end,
		disallowEsc = function()
			return show and dm_handle and dm_handle.showSearchResults
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

	local rmlDebug = utils.isRmlDebugEnabled()
	if rmlDebug ~= lastRmlDebug then
		lastRmlDebug = rmlDebug
		dm_handle.rmlDebugControls = rmlDebug
	end

	-- Deferred scroll: two-stage pipeline.
	-- Stage 1 (pendingScrollElement == nil): find the element in the DOM.
	--   Record it but DON'T scroll yet — RmlUi hasn't computed its layout
	--   position because data-if/data-for just created it this frame.
	-- Stage 2 (pendingScrollElement set): one frame later, scroll + highlight.
	if pendingScrollId and document then
		pendingScrollFrames = pendingScrollFrames + 1
		local target = document:GetElementById("cfg-" .. pendingScrollId)
		if target then
			if not pendingScrollElement then
				pendingScrollElement = target
			else
				pendingScrollElement:ScrollIntoView()
				pendingScrollElement:SetClass("highlight-search-match", true)
				highlightElement = pendingScrollElement
				highlightTimer = Spring.GetTimer()
				pendingScrollId = nil
				pendingScrollElement = nil
				pendingScrollFrames = 0
			end
		elseif pendingScrollFrames > MAX_SCROLL_RETRY_FRAMES then
			pendingScrollId = nil
			pendingScrollElement = nil
			pendingScrollFrames = 0
		end
	end

	-- Remove highlight class once the pulse duration has elapsed.
	if highlightTimer then
		local elapsed = Spring.DiffTimers(Spring.GetTimer(), highlightTimer)
		if elapsed >= HIGHLIGHT_DURATION_SEC then
			if highlightElement then
				highlightElement:SetClass("highlight-search-match", false)
				highlightElement = nil
			end
			highlightTimer = nil
		end
	end
end

-----------------------------------------------------------------------
-- Dev helpers
-----------------------------------------------------------------------

function widget:Reload()
	widget:Shutdown()
	widget:Initialize()
end

function widget:ToggleDebugger()
	if dm_handle then
		dm_handle.debugMode = not dm_handle.debugMode
		RmlUi.SetDebugContext(dm_handle.debugMode and 'shared' or nil)
	end
end
