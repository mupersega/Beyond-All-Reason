-- Interface > Visuals config: Visuals, Commands FX.
-- Returns a builder function — call with deps table from the widget.

return function(deps)
	local saveOptionValue = deps.saveOptionValue
	local loadWidgetData = deps.loadWidgetData
	local getWidgetToggleValue = deps.getWidgetToggleValue

	return {
		---------------------------------------------------------------
		-- Visuals
		---------------------------------------------------------------
		{ id = "heading_visuals", name = Spring.I18N('ui.settings.option.label_visuals') or "Visuals", type = "heading" },

		{ id = "uniticon_scaleui", name = Spring.I18N('ui.settings.option.uniticonscaleui') or "Unit Icon Scale",
		  type = "slider", min = 0.85, max = 3, step = 0.05, value = 1,
		  desc = Spring.I18N('ui.settings.option.uniticonscaleui_descr') or "",
		  onLoad = function() return Spring.GetConfigFloat("UnitIconScaleUI", 1) end,
		  onChange = function(v)
			  Spring.SendCommands("iconscaleui " .. v)
			  Spring.SetConfigFloat("UnitIconScaleUI", v)
		  end,
		},

		{ id = "uniticon_distance", name = Spring.I18N('ui.settings.option.uniticondistance') or "Icon Distance",
		  type = "slider", min = 1, max = 12000, step = 50, value = 2700,
		  desc = Spring.I18N('ui.settings.option.uniticondistance_descr') or "",
		  parentId = "uniticon_scaleui",
		  onLoad = function() return Spring.GetConfigInt("UnitIconFadeVanish", 2700) end,
		  onChange = function(v)
			  Spring.SendCommands("iconfadestart " .. v)
			  Spring.SetConfigInt("UnitIconFadeStart", math.floor(v))
			  Spring.SendCommands("iconfadevanish " .. v)
			  Spring.SetConfigInt("UnitIconFadeVanish", math.floor(v))
		  end,
		},

		{ id = "uniticon_hidewithui", name = Spring.I18N('ui.settings.option.uniticonhidewithui') or "Hide With UI",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.uniticonhidewithui_descr') or "",
		  parentId = "uniticon_scaleui",
		  onLoad = function() return Spring.GetConfigInt("UnitIconsHideWithUI", 0) == 1 end,
		  onChange = function(v)
			  Spring.SendCommands("iconshidewithui " .. (v and 1 or 0))
			  Spring.SetConfigInt("UnitIconsHideWithUI", v and 1 or 0)
		  end,
		},

		{ id = "teamplatter", name = Spring.I18N('ui.settings.option.teamplatter') or "Team Platter",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.teamplatter_descr') or "",
		  onLoad = function() return getWidgetToggleValue("TeamPlatter") end,
		  onChange = function(v)
			  if v then
				  widgetHandler:EnableWidget("TeamPlatter")
			  else
				  widgetHandler:DisableWidget("TeamPlatter")
			  end
		  end,
		},

		{ id = "teamplatter_opacity", name = Spring.I18N('ui.settings.option.teamplatter_opacity') or "Opacity",
		  type = "slider", min = 0.05, max = 0.4, step = 0.01, value = 0.25,
		  desc = Spring.I18N('ui.settings.option.teamplatter_opacity_descr') or "",
		  parentId = "teamplatter",
		  onLoad = function() return loadWidgetData("TeamPlatter", "opacity", 0.25) end,
		  onChange = function(v)
			  saveOptionValue('TeamPlatter', 'teamplatter', 'setOpacity', { 'opacity' }, v)
		  end,
		},

		{ id = "teamplatter_skipownteam", name = Spring.I18N('ui.settings.option.teamplatter_skipownteam') or "Skip Own Team",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.teamplatter_skipownteam_descr') or "",
		  parentId = "teamplatter",
		  onLoad = function() return loadWidgetData("TeamPlatter", "skipOwnTeam", false) end,
		  onChange = function(v)
			  saveOptionValue('TeamPlatter', 'teamplatter', 'setSkipOwnTeam', { 'skipOwnTeam' }, v)
		  end,
		},

		{ id = "enemyspotter", name = Spring.I18N('ui.settings.option.enemyspotter') or "Enemy Spotter",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.enemyspotter_descr') or "",
		  onLoad = function() return getWidgetToggleValue("EnemySpotter") end,
		  onChange = function(v)
			  if v then
				  widgetHandler:EnableWidget("EnemySpotter")
			  else
				  widgetHandler:DisableWidget("EnemySpotter")
			  end
		  end,
		},

		{ id = "enemyspotter_opacity", name = Spring.I18N('ui.settings.option.enemyspotter_opacity') or "Opacity",
		  type = "slider", min = 0.12, max = 0.4, step = 0.01, value = 0.15,
		  desc = Spring.I18N('ui.settings.option.enemyspotter_opacity_descr') or "",
		  parentId = "enemyspotter",
		  onLoad = function() return loadWidgetData("EnemySpotter", "opacity", 0.15) end,
		  onChange = function(v)
			  saveOptionValue('EnemySpotter', 'enemyspotter', 'setOpacity', { 'opacity' }, v)
		  end,
		},

		{ id = "selectedunits_opacity", name = Spring.I18N('ui.settings.option.selectedunits_opacity') or "Selected Units Opacity",
		  type = "slider", min = 0, max = 0.5, step = 0.01, value = 0.19,
		  desc = Spring.I18N('ui.settings.option.selectedunits_opacity_descr') or "",
		  onLoad = function() return loadWidgetData("Selected Units GL4", "opacity", 0.19) end,
		  onChange = function(v)
			  saveOptionValue('Selected Units GL4', 'selectedunits', 'setOpacity', { 'opacity' }, v)
		  end,
		},

		{ id = "selectedunits_teamcoloropacity", name = Spring.I18N('ui.settings.option.selectedunits_teamcoloropacity') or "Team Color Opacity",
		  type = "slider", min = 0, max = 1, step = 0.01, value = 0.6,
		  desc = Spring.I18N('ui.settings.option.selectedunits_teamcoloropacity_descr') or "",
		  parentId = "selectedunits_opacity",
		  onLoad = function() return loadWidgetData("Selected Units GL4", "teamcolorOpacity", 0.6) end,
		  onChange = function(v)
			  saveOptionValue('Selected Units GL4', 'selectedunits', 'setTeamcolorOpacity', { 'teamcolorOpacity' }, v)
		  end,
		},

		{ id = "highlightselunits", name = Spring.I18N('ui.settings.option.highlightselunits') or "Highlight Selected",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.selectedunits_teamcoloropacity_descr') or "",
		  parentId = "selectedunits_opacity",
		  onLoad = function() return loadWidgetData("Selected Units GL4", "selectionHighlight", true) end,
		  onChange = function(v)
			  saveOptionValue('Selected Units GL4', 'selectedunits', 'setSelectionHighlight', { 'selectionHighlight' }, v)
		  end,
		},

		{ id = "highlightunit", name = Spring.I18N('ui.settings.option.highlightunit') or "Highlight Unit",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.highlightunit_descr') or "",
		  onLoad = function() return loadWidgetData("Selected Units GL4", "mouseoverHighlight", true) end,
		  onChange = function(v)
			  saveOptionValue('Selected Units GL4', 'selectedunits', 'setMouseoverHighlight', { 'mouseoverHighlight' }, v)
		  end,
		},

		{ id = "ghosticons_brightness", name = Spring.I18N('ui.settings.option.ghosticons_brightness') or "Ghost Icons Brightness",
		  type = "slider", min = 0, max = 1.0, step = 0.15, value = 0.8,
		  desc = Spring.I18N('ui.settings.option.ghosticons_brightness_descr') or "",
		  onLoad = function() return Spring.GetConfigFloat("UnitGhostIconsDimming", 0.8) end,
		  onChange = function(v)
			  Spring.SetConfigFloat("UnitGhostIconsDimming", v)
		  end,
		},

		{ id = "cursorlight", name = Spring.I18N('ui.settings.option.cursorlight') or "Cursor Light",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.cursorlight_descr') or "",
		  onLoad = function() return loadWidgetData("Deferred rendering GL4", "showPlayerCursorLight", false) end,
		  onChange = function(v)
			  saveOptionValue('Deferred rendering GL4', 'lightsgl4', 'ShowPlayerCursorLight', { 'showPlayerCursorLight' }, v)
		  end,
		},

		{ id = "cursorlight_lightradius", name = Spring.I18N('ui.settings.option.cursorlight_lightradius') or "Cursor Light Radius",
		  type = "slider", min = 0.3, max = 2, step = 0.05, value = 1,
		  desc = "",
		  parentId = "cursorlight",
		  onLoad = function() return loadWidgetData("Deferred rendering GL4", "playerCursorLightRadius", 1) end,
		  onChange = function(v)
			  saveOptionValue('Deferred rendering GL4', 'lightsgl4', 'PlayerCursorLightRadius', { 'playerCursorLightRadius' }, v)
		  end,
		},

		{ id = "cursorlight_lightstrength", name = Spring.I18N('ui.settings.option.cursorlight_lightstrength') or "Cursor Light Strength",
		  type = "slider", min = 0.3, max = 2, step = 0.05, value = 1,
		  desc = "",
		  parentId = "cursorlight",
		  onLoad = function() return loadWidgetData("Cursor Light", "playerCursorLightBrightness", 1) end,
		  onChange = function(v)
			  saveOptionValue('Deferred rendering GL4', 'lightsgl4', 'PlayerCursorLightBrightness', { 'playerCursorLightBrightness' }, v)
		  end,
		},

		{ id = "autoeraser", name = Spring.I18N('ui.settings.option.autoeraser') or "Auto Eraser",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.autoeraser_descr') or "",
		  onLoad = function() return getWidgetToggleValue("Auto mapmark eraser") end,
		  onChange = function(v)
			  if v then
				  widgetHandler:EnableWidget("Auto mapmark eraser")
			  else
				  widgetHandler:DisableWidget("Auto mapmark eraser")
			  end
		  end,
		},

		{ id = "autoeraser_erasetime", name = Spring.I18N('ui.settings.option.autoeraser_erasetime') or "Erase Time",
		  type = "slider", min = 10, max = 200, step = 1, value = 60,
		  desc = Spring.I18N('ui.settings.option.autoeraser_erasetime_descr') or "",
		  parentId = "autoeraser",
		  onLoad = function() return loadWidgetData("Auto mapmark eraser", "eraseTime", 60) end,
		  onChange = function(v)
			  saveOptionValue('Auto mapmark eraser', 'autoeraser', 'setEraseTime', { 'eraseTime' }, v)
		  end,
		},

		{ id = "topbar_hidebuttons", name = Spring.I18N('ui.settings.option.topbar_hidebuttons') or "Top Bar Hide Buttons",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = "",
		  onLoad = function() return loadWidgetData("Top Bar", "autoHideButtons", false) end,
		  onChange = function(v)
			  saveOptionValue('Top Bar', 'topbar', 'setAutoHideButtons', { 'autoHideButtons' }, v)
		  end,
		},

		{ id = "continuouslyclearmapmarks", name = Spring.I18N('ui.settings.option.continuouslyclearmapmarks') or "Continuously Clear Map Marks",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.continuouslyclearmapmarks_descr') or "",
		  onLoad = function() return Spring.GetConfigInt("ContinuouslyClearMapmarks", 0) == 1 end,
		  onChange = function(v)
			  Spring.SetConfigInt("ContinuouslyClearMapmarks", v and 1 or 0)
			  if v then
				  Spring.SendCommands("clearmapmarks")
			  end
		  end,
		},

		{ id = "displaydps", name = Spring.I18N('ui.settings.option.displaydps') or "Display DPS",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.displaydps_descr') or "",
		  onLoad = function() return Spring.GetConfigInt("DisplayDPS", 0) == 1 end,
		  onChange = function(v)
			  Spring.SetConfigInt("DisplayDPS", v and 1 or 0)
		  end,
		},

		---------------------------------------------------------------
		-- Commands FX
		---------------------------------------------------------------
		{ id = "heading_commandsfx", name = Spring.I18N('ui.settings.option.commandsfx') or "Commands FX", type = "heading" },

		{ id = "commandsfx", name = Spring.I18N('ui.settings.option.commandsfx') or "Commands FX",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.commandsfx_descr') or "",
		  onLoad = function() return getWidgetToggleValue("Commands FX") end,
		  onChange = function(v)
			  if v then
				  widgetHandler:EnableWidget("Commands FX")
			  else
				  widgetHandler:DisableWidget("Commands FX")
			  end
		  end,
		},

		{ id = "commandsfxopacity", name = Spring.I18N('ui.settings.option.commandsfxopacity') or "Opacity",
		  type = "slider", min = 0.25, max = 1, step = 0.1, value = 1,
		  desc = "",
		  parentId = "commandsfx",
		  onLoad = function() return loadWidgetData("Commands FX", "opacity", 1) end,
		  onChange = function(v)
			  saveOptionValue('Commands FX', 'commandsfx', 'setOpacity', { 'opacity' }, v)
		  end,
		},

		{ id = "commandsfxduration", name = Spring.I18N('ui.settings.option.commandsfxduration') or "Duration",
		  type = "slider", min = 0.5, max = 2, step = 0.01, value = 1,
		  desc = "",
		  parentId = "commandsfx",
		  onLoad = function() return loadWidgetData("Commands FX", "duration", 1) end,
		  onChange = function(v)
			  saveOptionValue('Commands FX', 'commandsfx', 'setDuration', { 'duration' }, v)
		  end,
		},

		{ id = "commandsfxfilterai", name = Spring.I18N('ui.settings.option.commandsfxfilterai') or "Filter AI",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.commandsfxfilterai_descr') or "",
		  parentId = "commandsfx",
		  onLoad = function() return loadWidgetData("Commands FX", "filterAIteams", true) end,
		  onChange = function(v)
			  saveOptionValue('Commands FX', 'commandsfx', 'setFilterAI', { 'filterAIteams' }, v)
		  end,
		},

		{ id = "commandsfxuseteamcolors", name = Spring.I18N('ui.settings.option.commandsfxuseteamcolors') or "Use Team Colors",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.commandsfxuseteamcolors_descr') or "",
		  parentId = "commandsfx",
		  onLoad = function() return loadWidgetData("Commands FX", "useTeamColors", false) end,
		  onChange = function(v)
			  saveOptionValue('Commands FX', 'commandsfx', 'setUseTeamColors', { 'useTeamColors' }, v)
		  end,
		},

		{ id = "commandsfxuseteamcolorswhenspec", name = Spring.I18N('ui.settings.option.commandsfxuseteamcolorswhenspec') or "Use Team Colors When Spectating",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.commandsfxuseteamcolorswhenspec_descr') or "",
		  parentId = "commandsfx",
		  onLoad = function() return loadWidgetData("Commands FX", "useTeamColorsWhenSpec", false) end,
		  onChange = function(v)
			  saveOptionValue('Commands FX', 'commandsfx', 'setUseTeamColorsWhenSpec', { 'useTeamColorsWhenSpec' }, v)
		  end,
		},
	}
end
