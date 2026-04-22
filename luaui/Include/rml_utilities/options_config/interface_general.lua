-- Interface > General config: Interface, Minimap, Build Menu, Order Menu, Info Panel.

return function(deps)
	local saveOptionValue = deps.saveOptionValue
	local loadWidgetData = deps.loadWidgetData
	local getWidgetToggleValue = deps.getWidgetToggleValue

	-- Build language select options from available locales
	local function buildLanguageOptions()
		local codes = { 'en', 'fr', 'ru', 'es' }
		local options = {}
		for _, code in ipairs(codes) do
			local label = (Spring.I18N.languages and Spring.I18N.languages[code]) or code
			options[#options + 1] = { value = code, label = label }
		end
		return options
	end

	local languageOptions = buildLanguageOptions()

	-- Minimap rotation select options
	local minimapRotationOptions = {
		{ value = 1, label = Spring.I18N('ui.settings.option.minimaprotation_none') or "None" },
		{ value = 2, label = Spring.I18N('ui.settings.option.minimaprotation_autoflip') or "Auto-Flip" },
		{ value = 3, label = Spring.I18N('ui.settings.option.minimaprotation_autorotate') or "Auto-Rotate" },
	}

	return {
		---------------------------------------------------------------
		-- Interface
		---------------------------------------------------------------
		{ id = "heading_interface", name = Spring.I18N('ui.settings.option.label_interface') or "Interface", type = "heading" },

		{ id = "language", name = Spring.I18N('ui.settings.option.language') or "Language",
		  type = "select", min = 0, max = 0, step = 0, value = "en",
		  desc = "",
		  selectOptions = languageOptions,
		  onLoad = function()
			  local locale = Spring.I18N.getLocale()
			  return locale or "en"
		  end,
		  onChange = function(v)
			  if WG['language'] and WG['language'].setLanguage then
				  WG['language'].setLanguage(v)
			  end
			  if widgetHandler.orderList["Notifications"] ~= nil then
				  widgetHandler:DisableWidget("Notifications")
				  widgetHandler:EnableWidget("Notifications")
			  end
		  end,
		},

		{ id = "language_english_unit_names", name = Spring.I18N('ui.settings.option.language_english_unit_names') or "English Unit Names",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = "",
		  parentId = "language",
		  onLoad = function() return Spring.GetConfigInt("language_english_unit_names", 0) == 1 end,
		  onChange = function(v)
			  if WG['language'] and WG['language'].setEnglishUnitNames then
				  WG['language'].setEnglishUnitNames(v)
			  end
		  end,
		},

		{ id = "uiscale", name = Spring.I18N('ui.settings.option.uiscale') or "UI Scale",
		  type = "slider", min = 0.8, max = 1.3, step = 0.01, value = 1,
		  desc = "",
		  onLoad = function() return Spring.GetConfigFloat("ui_scale", 1) end,
		  onChange = function(v)
			  Spring.SetConfigFloat("ui_scale", v)
			  -- Live-apply to all RML contexts via the hook registered by rml_context_manager.
			  -- Legacy (non-RML) widgets still pick up ui_scale at init only.
			  if WG.rml_ui_scale_changed then
				  WG.rml_ui_scale_changed()
			  end
		  end,
		},

		{ id = "rml_theme", name = Spring.I18N('ui.settings.option.rml_theme') or "RML Theme",
		  type = "select", min = 0, max = 0, step = 0, value = "base",
		  desc = Spring.I18N('ui.settings.option.rml_theme_descr') or "Choose the color theme for RML widgets",
		  selectOptions = {
			  { value = "base", label = "Base" },
			  { value = "armada", label = "Armada" },
			  { value = "cortex", label = "Cortex" },
			  { value = "legion", label = "Legion" },
		  },
		  onLoad = function()
			  return Spring.GetConfigString("rml_theme", "base")
		  end,
		  onChange = function(v)
			  Spring.SetConfigString("rml_theme", v)
			  if WG.rml_theme_changed then
				  WG.rml_theme_changed(v)
			  end
		  end,
		},

		{ id = "guiopacity", name = Spring.I18N('ui.settings.option.guiopacity') or "GUI Opacity",
		  type = "slider", min = 0.3, max = 1, step = 0.01, value = 0.7,
		  desc = "",
		  onLoad = function() return Spring.GetConfigFloat("ui_opacity", 0.7) end,
		  onChange = function(v)
			  Spring.SetConfigFloat("ui_opacity", v)
			  -- NOTE: requires engine restart to apply (reloadluaui would infinite-loop)
		  end,
		},

		{ id = "guitilescale", name = Spring.I18N('ui.settings.option.guitilescale') or "GUI Tile Scale",
		  type = "slider", min = 4, max = 40, step = 1, value = 7,
		  desc = "",
		  onLoad = function() return Spring.GetConfigFloat("ui_tilescale", 7) end,
		  onChange = function(v)
			  Spring.SetConfigFloat("ui_tilescale", v)
			  -- NOTE: requires engine restart to apply (reloadluaui would infinite-loop)
		  end,
		},

		{ id = "guitileopacity", name = Spring.I18N('ui.settings.option.guitileopacity') or "GUI Tile Opacity",
		  type = "slider", min = 0, max = 0.03, step = 0.001, value = 0.014,
		  desc = "",
		  onLoad = function() return Spring.GetConfigFloat("ui_tileopacity", 0.014) end,
		  onChange = function(v)
			  Spring.SetConfigFloat("ui_tileopacity", v)
			  -- NOTE: requires engine restart to apply (reloadluaui would infinite-loop)
		  end,
		},

		{ id = "guishader", name = Spring.I18N('ui.settings.option.guishader') or "GUI Shader",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = "",
		  onLoad = function() return getWidgetToggleValue("GUI Shader") end,
		  onChange = function(v)
			  if v then
				  widgetHandler:EnableWidget("GUI Shader")
			  else
				  widgetHandler:DisableWidget("GUI Shader")
			  end
		  end,
		},

		{ id = "rendertotexture", name = Spring.I18N('ui.settings.option.rendertotexture') or "Render To Texture",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  disabled = true,
		  desc = (Spring.I18N('ui.settings.option.rendertotexture_descr') or "") ..
		         "\n\nDisabled: toggling currently breaks the UI.",
		  onLoad = function() return Spring.GetConfigInt("ui_rendertotexture", 1) == 1 end,
		  onChange = function(v)
			  Spring.SetConfigInt("ui_rendertotexture", v and 1 or 0)
			  Spring.SendCommands("luaui reload")
		  end,
		},

		---------------------------------------------------------------
		-- Minimap
		---------------------------------------------------------------
		{ id = "heading_minimap", name = Spring.I18N('ui.settings.option.minimap') or "Minimap", type = "heading" },

		{ id = "minimap_maxheight", name = Spring.I18N('ui.settings.option.minimap_maxheight') or "Max Height",
		  type = "slider", min = 0.2, max = 0.4, step = 0.01, value = 0.35,
		  desc = Spring.I18N('ui.settings.option.minimap_maxheight_descr') or "",
		  onLoad = function() return loadWidgetData("Minimap", "maxHeight", 0.35) end,
		  onChange = function(v)
			  saveOptionValue('Minimap', 'minimap', 'setMaxHeight', { 'maxHeight' }, v)
		  end,
		},

		{ id = "minimapleftclick", name = Spring.I18N('ui.settings.option.minimapleftclick') or "Left Click Move",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.minimapleftclick_descr') or "",
		  parentId = "minimap_maxheight",
		  onLoad = function() return Spring.GetConfigInt("MinimapLeftClickMove", 1) == 1 end,
		  onChange = function(v)
			  Spring.SetConfigInt("MinimapLeftClickMove", v and 1 or 0)
			  if WG['minimap'] and WG['minimap'].setLeftClickMove then
				  WG['minimap'].setLeftClickMove(v)
			  end
		  end,
		},

		{ id = "minimapiconsize", name = Spring.I18N('ui.settings.option.minimapiconsize') or "Icon Size",
		  type = "slider", min = 2, max = 5, step = 0.25, value = 3.5,
		  desc = "",
		  parentId = "minimap_maxheight",
		  onLoad = function() return Spring.GetConfigFloat("MinimapIconScale", 3.5) end,
		  onChange = function(v)
			  Spring.SetConfigFloat("MinimapIconScale", v)
			  Spring.SendCommands("minimap unitsize " .. v)
		  end,
		},

		{ id = "minimap_minimized", name = Spring.I18N('ui.settings.option.minimapminimized') or "Minimized",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.minimapminimized_descr') or "",
		  parentId = "minimap_maxheight",
		  onLoad = function() return Spring.GetConfigInt("MinimapMinimize", 0) == 1 end,
		  onChange = function(v)
			  Spring.SendCommands("minimap minimize " .. (v and '1' or '0'))
			  Spring.SetConfigInt("MinimapMinimize", v and 1 or 0)
		  end,
		},

		{ id = "minimaprotation", name = Spring.I18N('ui.settings.option.minimaprotation') or "Rotation",
		  type = "select", min = 0, max = 0, step = 0, value = 1,
		  desc = Spring.I18N('ui.settings.option.minimaprotation_descr') or "",
		  parentId = "minimap_maxheight",
		  selectOptions = minimapRotationOptions,
		  onLoad = function() return loadWidgetData("Minimap Rotation Manager", "mode", 1) end,
		  onChange = function(v)
			  if WG['minimaprotationmanager'] ~= nil and WG['minimaprotationmanager'].setMode ~= nil then
				  saveOptionValue("Minimap Rotation Manager", "minimaprotationmanager", "setMode", { 'mode' }, v)
			  else
				  widgetHandler:EnableWidget("Minimap Rotation Manager")
			  end
		  end,
		},

		{ id = "minimappip", name = Spring.I18N('ui.settings.option.minimappip') or "PiP Minimap",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.minimappip_descr') or "",
		  parentId = "minimap_maxheight",
		  onLoad = function() return getWidgetToggleValue("Picture-in-Picture Minimap") end,
		  onChange = function(v)
			  if v then
				  widgetHandler:EnableWidget("Picture-in-Picture Minimap")
			  else
				  widgetHandler:DisableWidget("Picture-in-Picture Minimap")
			  end
		  end,
		},

		{ id = "pip", name = Spring.I18N('ui.settings.option.pip') or "Picture-in-Picture",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.pip_descr') or "",
		  onLoad = function() return getWidgetToggleValue("Picture-in-Picture") end,
		  onChange = function(v)
			  if v then
				  widgetHandler:EnableWidget("Picture-in-Picture")
			  else
				  widgetHandler:DisableWidget("Picture-in-Picture")
			  end
		  end,
		},

		{ id = "pip2", name = Spring.I18N('ui.settings.option.pip2') or "Picture-in-Picture 2",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.pip2_descr') or "",
		  onLoad = function() return getWidgetToggleValue("Picture-in-Picture 2") end,
		  onChange = function(v)
			  if v then
				  widgetHandler:EnableWidget("Picture-in-Picture 2")
			  else
				  widgetHandler:DisableWidget("Picture-in-Picture 2")
			  end
		  end,
		},

		---------------------------------------------------------------
		-- Build Menu
		---------------------------------------------------------------
		{ id = "heading_buildmenu", name = Spring.I18N('ui.settings.option.buildmenu') or "Build Menu", type = "heading" },

		{ id = "buildmenu_bottom", name = Spring.I18N('ui.settings.option.buildmenu_bottom') or "Bottom Position",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.buildmenu_bottom_descr') or "",
		  onLoad = function() return loadWidgetData("Build menu", "stickToBottom", false) end,
		  onChange = function(v)
			  saveOptionValue('Build menu', 'buildmenu', 'setBottomPosition', { 'stickToBottom' }, v)
			  saveOptionValue('Grid menu', 'buildmenu', 'setBottomPosition', { 'stickToBottom' }, v)
		  end,
		},

		{ id = "buildmenu_maxposy", name = Spring.I18N('ui.settings.option.buildmenu_maxposy') or "Max Y Position",
		  type = "slider", min = 0.66, max = 0.88, step = 0.01, value = 0.74,
		  desc = Spring.I18N('ui.settings.option.buildmenu_maxposy_descr') or "",
		  parentId = "buildmenu_bottom",
		  onLoad = function() return loadWidgetData("Build menu", "maxPosY", 0.74) end,
		  onChange = function(v)
			  saveOptionValue('Build menu', 'buildmenu', 'setMaxPosY', { 'maxPosY' }, v)
		  end,
		},

		{ id = "buildmenu_alwaysshow", name = Spring.I18N('ui.settings.option.buildmenu_alwaysshow') or "Always Show",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.buildmenu_alwaysshow_descr') or "",
		  parentId = "buildmenu_bottom",
		  onLoad = function() return loadWidgetData("Build menu", "alwaysShow", false) end,
		  onChange = function(v)
			  saveOptionValue('Build menu', 'buildmenu', 'setAlwaysShow', { 'alwaysShow' }, v)
			  saveOptionValue('Grid menu', 'buildmenu', 'setAlwaysShow', { 'alwaysShow' }, v)
		  end,
		},

		{ id = "buildmenu_prices", name = Spring.I18N('ui.settings.option.buildmenu_prices') or "Show Prices",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.buildmenu_prices_descr') or "",
		  parentId = "buildmenu_bottom",
		  onLoad = function() return loadWidgetData("Build menu", "showPrice", false) end,
		  onChange = function(v)
			  saveOptionValue('Build menu', 'buildmenu', 'setShowPrice', { 'showPrice' }, v)
			  saveOptionValue('Grid menu', 'buildmenu', 'setShowPrice', { 'showPrice' }, v)
		  end,
		},

		{ id = "buildmenu_groupicon", name = Spring.I18N('ui.settings.option.buildmenu_groupicon') or "Group Icon",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.buildmenu_groupicon_descr') or "",
		  parentId = "buildmenu_bottom",
		  onLoad = function() return loadWidgetData("Build menu", "showGroupIcon", false) end,
		  onChange = function(v)
			  saveOptionValue('Build menu', 'buildmenu', 'setShowGroupIcon', { 'showGroupIcon' }, v)
			  saveOptionValue('Grid menu', 'buildmenu', 'setShowGroupIcon', { 'showGroupIcon' }, v)
		  end,
		},

		{ id = "buildmenu_radaricon", name = Spring.I18N('ui.settings.option.buildmenu_radaricon') or "Radar Icon",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.buildmenu_radaricon_descr') or "",
		  parentId = "buildmenu_bottom",
		  onLoad = function() return loadWidgetData("Build menu", "showRadarIcon", false) end,
		  onChange = function(v)
			  saveOptionValue('Build menu', 'buildmenu', 'setShowRadarIcon', { 'showRadarIcon' }, v)
			  saveOptionValue('Grid menu', 'buildmenu', 'setShowRadarIcon', { 'showRadarIcon' }, v)
		  end,
		},

		---------------------------------------------------------------
		-- Order Menu
		---------------------------------------------------------------
		{ id = "heading_ordermenu", name = Spring.I18N('ui.settings.option.ordermenu') or "Order Menu", type = "heading" },

		{ id = "ordermenu_bottompos", name = Spring.I18N('ui.settings.option.ordermenu_bottompos') or "Bottom Position",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.ordermenu_bottompos_descr') or "",
		  onLoad = function() return loadWidgetData("Order menu", "stickToBottom", false) end,
		  onChange = function(v)
			  saveOptionValue('Order menu', 'ordermenu', 'setBottomPosition', { 'stickToBottom' }, v)
		  end,
		},

		{ id = "ordermenu_colorize", name = Spring.I18N('ui.settings.option.ordermenu_colorize') or "Colorize",
		  type = "slider", min = 0, max = 1, step = 0.1, value = 0.5,
		  desc = "",
		  parentId = "ordermenu_bottompos",
		  onLoad = function() return loadWidgetData("Order menu", "colorize", 0.5) end,
		  onChange = function(v)
			  saveOptionValue('Order menu', 'ordermenu', 'setColorize', { 'colorize' }, v)
		  end,
		},

		{ id = "ordermenu_alwaysshow", name = Spring.I18N('ui.settings.option.ordermenu_alwaysshow') or "Always Show",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.ordermenu_alwaysshow_descr') or "",
		  parentId = "ordermenu_bottompos",
		  onLoad = function() return loadWidgetData("Order menu", "alwaysShow", false) end,
		  onChange = function(v)
			  saveOptionValue('Order menu', 'ordermenu', 'setAlwaysShow', { 'alwaysShow' }, v)
		  end,
		},

		{ id = "ordermenu_hideset", name = Spring.I18N('ui.settings.option.ordermenu_hideset') or "Hide Set Commands",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.ordermenu_hideset_descr') or "",
		  parentId = "ordermenu_bottompos",
		  onLoad = function() return loadWidgetData("Order menu", "disabledCmd", false) end,
		  onChange = function(v)
			  local cmds = { 'Move', 'Stop', 'Attack', 'Patrol', 'Fight', 'Wait', 'Guard', 'Reclaim', 'Repair', 'ManualFire' }
			  for _, cmd in pairs(cmds) do
				  saveOptionValue('Order menu', 'ordermenu', 'setDisabledCmd', { 'disabledCmd', cmd }, v, { cmd, v })
			  end
		  end,
		},

		---------------------------------------------------------------
		-- Info Panel
		---------------------------------------------------------------
		{ id = "heading_info_panel", name = Spring.I18N('ui.settings.option.info') or "Info Panel", type = "heading" },

		{ id = "info_buildlist", name = Spring.I18N('ui.settings.option.info_buildlist') or "Show Build List",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.info_buildlist_descr') or "",
		  onLoad = function() return loadWidgetData("Info", "showBuilderBuildlist", false) end,
		  onChange = function(v)
			  saveOptionValue('Info', 'info', 'setShowBuilderBuildlist', { 'showBuilderBuildlist' }, v)
		  end,
		},

		{ id = "info_mappos", name = Spring.I18N('ui.settings.option.info_mappos') or "Map Position",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.info_mappos_descr') or "",
		  parentId = "info_buildlist",
		  onLoad = function() return loadWidgetData("Info", "displayMapPosition", false) end,
		  onChange = function(v)
			  saveOptionValue('Info', 'info', 'setDisplayMapPosition', { 'displayMapPosition' }, v)
		  end,
		},

		{ id = "info_alwaysshow", name = Spring.I18N('ui.settings.option.info_alwaysshow') or "Always Show",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = "",
		  parentId = "info_buildlist",
		  onLoad = function() return loadWidgetData("Info", "alwaysShow", false) end,
		  onChange = function(v)
			  saveOptionValue('Info', 'info', 'setAlwaysShow', { 'alwaysShow' }, v)
		  end,
		},
	}
end
