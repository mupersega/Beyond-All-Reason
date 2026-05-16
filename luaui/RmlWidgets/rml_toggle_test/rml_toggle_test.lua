if not RmlUi then return end

local widget = widget ---@type Widget
local utils = VFS.Include("luaui/Include/rml_utilities/utils.lua")
local ccg = VFS.Include("luaui/Include/rml_utilities/common_class_groups.lua")

local WIDGET_ID = "rml_toggle_test"
local MODEL_NAME = "rml_toggle_test_model"
local RML_PATH = "luaui/RmlWidgets/rml_toggle_test/rml_toggle_test.rml"

local document
local dm_handle

local function log(msg) Spring.Echo(msg) end

-- saveOptionValue — matches luaui/Widgets/gui_options.lua:1449-1476 behavior.
-- configVar is a table of keys forming a nested path; intermediate sub-tables
-- are created as needed. The 6th arg widgetApiFunctionParam overrides what
-- gets passed to the widget API function (for widgets whose setters take a
-- different shape than the raw value, e.g. setMetricEnabled expects {key, v}).
local function saveOptionValue(widgetName, wgKey, setterName, configVar, value, widgetApiFunctionParam)
	if widgetHandler.configData[widgetName] == nil then
		widgetHandler.configData[widgetName] = {}
	end
	-- Walk configVar as a nested path, creating sub-tables along the way,
	-- and write at the deepest level.
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

-- loadWidgetData — supports both a flat string key (backward compat) and a
-- table of keys forming a nested path. Returns default if any step is nil
-- or not a table.
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

local function getWidgetToggleValue(widgetName)
	if not widgetHandler.orderList then return false end
	local order = widgetHandler.orderList[widgetName]
	if not order or order == 0 then return false end
	if widgetHandler.knownWidgets and widgetHandler.knownWidgets[widgetName] then
		return widgetHandler.knownWidgets[widgetName].active == true
	end
	return false
end

---------------------------------------------------------------
-- Options config: flat array, exactly like the real widget
-- would use. Headings, bools, sliders all in one list.
---------------------------------------------------------------

local options = {
	-- Section heading
	{ id = "heading_weather", name = "Weather", type = "heading" },

	-- Bool: widget toggle
	{ id = "snow_enabled", name = "Snow", type = "bool",
	  min = 0, max = 1, step = 1, value = false, desc = "Enable snow particles",
	  onLoad = function() return getWidgetToggleValue("Snow") end,
	  onChange = function(v)
		if v then widgetHandler:EnableWidget("Snow")
		else widgetHandler:DisableWidget("Snow") end
	  end,
	},

	-- Slider: child of snow
	{ id = "snowamount", name = "Amount", type = "slider",
	  min = 0.2, max = 3, step = 0.2, value = 1, desc = "Snow particle density",
	  parentId = "snow_enabled",
	  onLoad = function() return loadWidgetData("Snow", "multiplier", 1) end,
	  onChange = function(v)
		saveOptionValue('Snow', 'snow', 'setMultiplier', { 'customParticleMultiplier' }, v)
	  end,
	},

	-- Bool: widget toggle
	{ id = "grass_enabled", name = "Grass", type = "bool",
	  min = 0, max = 1, step = 1, value = false, desc = "Enable map grass",
	  onLoad = function() return getWidgetToggleValue("Map Grass GL4") end,
	  onChange = function(v)
		if v then widgetHandler:EnableWidget("Map Grass GL4")
		else widgetHandler:DisableWidget("Map Grass GL4") end
	  end,
	},

	-- Slider: child of grass
	{ id = "grassdist", name = "Distance", type = "slider",
	  min = 0.3, max = 1, step = 0.01, value = 1, desc = "Grass draw distance",
	  parentId = "grass_enabled",
	  onLoad = function() return loadWidgetData("Map Grass GL4", "distanceMult", 1) end,
	  onChange = function(v)
		saveOptionValue('Map Grass GL4', 'grassgl4', 'setDistanceMult', { 'distanceMult' }, v)
	  end,
	},

	-- Section heading
	{ id = "heading_effects", name = "Effects", type = "heading" },

	-- Standalone slider
	{ id = "particles", name = "Max Particles", type = "slider",
	  min = 10000, max = 40000, step = 1000, value = 15000, desc = "Maximum particle count",
	  onLoad = function() return Spring.GetConfigInt("MaxParticles", 15000) end,
	  onChange = function(v)
		local val = math.floor(v)
		Spring.SetConfigInt("MaxParticles", val)
		Spring.SetConfigInt("MaxNanoParticles", math.floor(val * 0.34))
	  end,
	},

	-- Standalone bool
	{ id = "sepia_enabled", name = "Sepia Tone", type = "bool",
	  min = 0, max = 1, step = 1, value = false, desc = "Apply sepia post-processing",
	  onLoad = function() return getWidgetToggleValue("Sepia Tone") end,
	  onChange = function(v)
		if v then widgetHandler:EnableWidget("Sepia Tone")
		else widgetHandler:DisableWidget("Sepia Tone") end
	  end,
	},

	-- Section heading
	{ id = "heading_volume", name = "Volume", type = "heading" },

	-- Standalone slider
	{ id = "sndvolmaster", name = "Master Volume", type = "slider",
	  min = 0, max = 100, step = 1, value = 40, desc = "Overall sound volume",
	  onLoad = function() return Spring.GetConfigInt("snd_volmaster", 40) end,
	  onChange = function(v)
		local vol = math.floor(v)
		Spring.SetConfigInt("snd_volmaster", vol)
		Spring.SendCommands("set snd_volmaster " .. vol)
	  end,
	},

	-- Section heading
	{ id = "heading_interface", name = "Interface", type = "heading" },

	-- Select: RML theme
	{ id = "rml_theme", name = "RML Theme", type = "select",
	  min = 0, max = 0, step = 0, value = "base",
	  desc = "Visual theme for RML widgets",
	  selectOptions = {
		{ value = "base",   label = "Base" },
		{ value = "armada", label = "Armada" },
		{ value = "cortex", label = "Cortex" },
		{ value = "legion", label = "Legion" },
	  },
	  onLoad = function()
		local tu = WG.rml_themeUtils
		return tu and tu.GetCurrentTheme() or "base"
	  end,
	  onChange = function(v)
		local tu = WG.rml_themeUtils
		if tu then tu.setAndApplyTheme(v) end
	  end,
	},

	-- Section heading
	{ id = "heading_system", name = "System", type = "heading" },

	-- Action: restart engine
	{ id = "restart_engine", name = "Restart Engine", type = "action",
	  min = 0, max = 0, step = 0, value = false,
	  desc = "Restarts the engine to apply changes that require it",
	  labelClass = ccg.definitions.text.danger .. " text-upper",
	  onClick = function()
		local startScript = VFS.LoadFile("_script.txt")
		if startScript then
			Spring.Restart("", startScript)
		end
	  end,
	},
}

-- Append sound config from the real config file
local buildOptionsConfig = VFS.Include("luaui/Include/rml_utilities/options_config.lua")
local allConfig = buildOptionsConfig({
	saveOptionValue = saveOptionValue,
	loadWidgetData = loadWidgetData,
	getWidgetToggleValue = getWidgetToggleValue,
})
for _, tabKey in ipairs({ "interface_general" }) do
	if allConfig[tabKey] then
		for _, entry in ipairs(allConfig[tabKey]) do
			options[#options + 1] = entry
		end
	end
end

-- O(1) lookup
local optionById = {}
for _, opt in ipairs(options) do
	optionById[opt.id] = opt
end

-- Build sectioned + grouped structure for triple data-for rendering.
-- Input: flat array where type="heading" entries mark section boundaries.
-- Output: array of sections, each with { heading, groups }.
-- Each group has { parent, children, hasChildren }.
local function buildSections(flat)
	local sections = {}
	local childrenByParent = {}

	-- First pass: collect children
	for _, entry in ipairs(flat) do
		if entry.parentId then
			childrenByParent[entry.parentId] = childrenByParent[entry.parentId] or {}
			table.insert(childrenByParent[entry.parentId], entry)
		end
	end

	-- Second pass: build sections and groups
	local currentSection = nil
	for _, entry in ipairs(flat) do
		if entry.type == "heading" then
			currentSection = { heading = entry.name, groups = {} }
			table.insert(sections, currentSection)
		elseif not entry.parentId and currentSection then
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

-- Toggle state: separate from config entries, never touches proxy
local toggleState = {}

---------------------------------------------------------------
-- Handlers
---------------------------------------------------------------

-- Bool toggle: state in toggleState, visual via DOM, side effect via onChange
-- Impl functions (file-local, not widget: methods). Invoked from model
-- fns in initModel via data-event-*. DOM swaps below are sanctioned
-- escapes (proven toggle pattern / slider readback) — see CLAUDE.md.
local function onToggleImpl(element)
	local id = (element:GetAttribute("id") or ""):gsub("^cfg%-", "")
	local entry = optionById[id]
	if not entry then return end

	toggleState[id] = not toggleState[id]
	local val = toggleState[id]

	log("[toggle] " .. entry.name .. " -> " .. tostring(val))
	if entry.onChange then entry.onChange(val) end

	-- Visual: swap toggle segment classes
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

-- Format value to match step precision, stripping float noise.
-- step=1 → "15000", step=0.2 → "1.2", step=0.01 → "0.35"
local function formatValue(value, step)
	if step >= 1 then
		return tostring(math.floor(value + 0.5))
	end
	local stepStr = tostring(step)
	local dot = stepStr:find("%.")
	local decimals = dot and (#stepStr - dot) or 1
	return string.format("%." .. decimals .. "f", value)
end

-- Slider: read from element (RmlUi#668), call side effect, update readback via DOM
local function onSliderImpl(element)
	local id = (element:GetAttribute("id") or ""):gsub("^cfg%-", "")
	local entry = optionById[id]
	if not entry then return end

	local value = tonumber(element:GetAttribute("value"))
	if value then
		if entry.onChange then entry.onChange(value) end
		-- Update readback span via DOM (no proxy mutation)
		if document then
			local span = document:GetElementById("val-" .. id)
			if span then
				span.inner_rml = formatValue(value, entry.step or 1)
			end
		end
	end
end

-- Action: just call onClick
local function onActionImpl(element)
	local id = (element:GetAttribute("id") or ""):gsub("^cfg%-", "")
	local entry = optionById[id]
	if entry and entry.onClick then
		log("[action] " .. entry.name)
		entry.onClick()
	end
end

-- Select: read from element, call side effect
local function onSelectImpl(element)
	local id = (element:GetAttribute("id") or ""):gsub("^cfg%-", "")
	local entry = optionById[id]
	if not entry then return end

	local value = element:GetAttribute("value")
	if value then
		log("[select] " .. entry.name .. " -> " .. tostring(value))
		if entry.onChange then entry.onChange(value) end
	end
end

---------------------------------------------------------------
-- Model + lifecycle
---------------------------------------------------------------

local function initModel()
	return {
		sections = {},  -- populated in Initialize
		my = {
			panelHeading = "panel-heading-abs text-lg font-bold text-primary",
		},

		-- No widget: methods — model fns via data-event-*. The bound
		-- element is ev.current_element (NOT target_element, which is the
		-- click origin / a possible child). current_element matches the
		-- element the old onclick="widget:Fn(element)" inline syntax gave.
		onToggle = function(ev) local e = ev and ev.current_element; if e then onToggleImpl(e) end end,
		onSlider = function(ev) local e = ev and ev.current_element; if e then onSliderImpl(e) end end,
		onSelect = function(ev) local e = ev and ev.current_element; if e then onSelectImpl(e) end end,
		onAction = function(ev) local e = ev and ev.current_element; if e then onActionImpl(e) end end,
	}
end

function widget:GetInfo()
	return {
		name = "RML Input Test",
		desc = "Validates flat config array with single data-for",
		author = "debug",
		date = "2025",
		license = "GNU GPL, v2 or later",
		layer = -999,
		enabled = false,
		handler = true,
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
	if not result then return false end
	document = result.document
	dm_handle = result.dm_handle

	-- Load current values from config onLoad functions
	for _, opt in ipairs(options) do
		if opt.onLoad then
			opt.value = opt.onLoad()
		end
		if opt.type == "bool" then
			-- Force boolean — onLoad may return truthy numbers
			opt.value = (opt.value == true)
			toggleState[opt.id] = opt.value
		end
	end

	-- Build sectioned + grouped structure and push ONCE
	dm_handle.sections = buildSections(options)

	-- Initial dimming handled by group.parentOff in the RML template.
	-- Initial toggle visuals handled by opt.value (forced boolean) in data-attr-class.

	return true
end

function widget:Shutdown()
	utils.shutdownRmlWidget(self, {
		widgetId = WIDGET_ID,
		modelName = MODEL_NAME,
	}, document, dm_handle)
	document = nil
	dm_handle = nil
end
