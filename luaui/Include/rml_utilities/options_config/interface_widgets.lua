-- Interface > Widgets config: Player List, Console, Widgets.
-- Returns a builder function — call with deps table from the widget.

return function(deps)
	local saveOptionValue = deps.saveOptionValue
	local loadWidgetData = deps.loadWidgetData
	local getWidgetToggleValue = deps.getWidgetToggleValue

	return {
		---------------------------------------------------------------
		-- Player List
		---------------------------------------------------------------
		{ id = "heading_playerlist", name = Spring.I18N('ui.settings.option.advplayerlist') or "Player List", type = "heading" },

		{ id = "advplayerlist_country", name = Spring.I18N('ui.settings.option.advplayerlist_country') or "Country Flags",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.advplayerlist_country_descr') or "",
		  onLoad = function() return loadWidgetData("AdvPlayersList", "m_active_Table.country", true) end,
		  onChange = function(v)
			  saveOptionValue('AdvPlayersList', 'advplayerlist_api', 'SetModuleActive', { 'm_active_Table', 'country' }, v, { 'country', v })
		  end,
		},

		{ id = "advplayerlist_scale", name = Spring.I18N('ui.settings.option.advplayerlist_scale') or "Scale",
		  type = "slider", min = 0.85, max = 1.2, step = 0.01, value = 1,
		  desc = Spring.I18N('ui.settings.option.advplayerlist_scale_descr') or "",
		  parentId = "advplayerlist_country",
		  onLoad = function() return loadWidgetData("AdvPlayersList", "customScale", 1) end,
		  onChange = function(v)
			  saveOptionValue('AdvPlayersList', 'advplayerlist_api', 'SetScale', { 'customScale' }, v)
		  end,
		},

		{ id = "advplayerlist_showallyid", name = Spring.I18N('ui.settings.option.advplayerlist_showallyid') or "Ally ID",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.advplayerlist_showallyid_descr') or "",
		  parentId = "advplayerlist_country",
		  onLoad = function() return loadWidgetData("AdvPlayersList", "m_active_Table.allyid", false) end,
		  onChange = function(v)
			  saveOptionValue('AdvPlayersList', 'advplayerlist_api', 'SetModuleActive', { 'm_active_Table', 'allyid' }, v, { 'allyid', v })
		  end,
		},

		{ id = "advplayerlist_showid", name = Spring.I18N('ui.settings.option.advplayerlist_showid') or "Player ID",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.advplayerlist_showid_descr') or "",
		  parentId = "advplayerlist_country",
		  onLoad = function() return loadWidgetData("AdvPlayersList", "m_active_Table.id", false) end,
		  onChange = function(v)
			  saveOptionValue('AdvPlayersList', 'advplayerlist_api', 'SetModuleActive', { 'm_active_Table', 'id' }, v, { 'id', v })
		  end,
		},

		{ id = "advplayerlist_showplayerid", name = Spring.I18N('ui.settings.option.advplayerlist_showplayerid') or "Show Player ID",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.advplayerlist_showplayerid_descr') or "",
		  parentId = "advplayerlist_country",
		  onLoad = function() return loadWidgetData("AdvPlayersList", "m_active_Table.playerid", false) end,
		  onChange = function(v)
			  saveOptionValue('AdvPlayersList', 'advplayerlist_api', 'SetModuleActive', { 'm_active_Table', 'playerid' }, v, { 'playerid', v })
		  end,
		},

		{ id = "advplayerlist_rank", name = Spring.I18N('ui.settings.option.advplayerlist_rank') or "Rank",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.advplayerlist_rank_descr') or "",
		  parentId = "advplayerlist_country",
		  onLoad = function() return loadWidgetData("AdvPlayersList", "m_active_Table.rank", true) end,
		  onChange = function(v)
			  saveOptionValue('AdvPlayersList', 'advplayerlist_api', 'SetModuleActive', { 'm_active_Table', 'rank' }, v, { 'rank', v })
		  end,
		},

		{ id = "advplayerlist_skill", name = Spring.I18N('ui.settings.option.advplayerlist_skill') or "Skill",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.advplayerlist_skill_descr') or "",
		  parentId = "advplayerlist_country",
		  onLoad = function() return loadWidgetData("AdvPlayersList", "m_active_Table.skill", true) end,
		  onChange = function(v)
			  saveOptionValue('AdvPlayersList', 'advplayerlist_api', 'SetModuleActive', { 'm_active_Table', 'skill' }, v, { 'skill', v })
		  end,
		},

		{ id = "advplayerlist_cpuping", name = Spring.I18N('ui.settings.option.advplayerlist_cpuping') or "CPU/Ping",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.advplayerlist_cpuping_descr') or "",
		  parentId = "advplayerlist_country",
		  onLoad = function() return loadWidgetData("AdvPlayersList", "m_active_Table.cpuping", true) end,
		  onChange = function(v)
			  saveOptionValue('AdvPlayersList', 'advplayerlist_api', 'SetModuleActive', { 'm_active_Table', 'cpuping' }, v, { 'cpuping', v })
		  end,
		},

		{ id = "advplayerlist_resources", name = Spring.I18N('ui.settings.option.advplayerlist_resources') or "Resources",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.advplayerlist_resources_descr') or "",
		  parentId = "advplayerlist_country",
		  onLoad = function() return loadWidgetData("AdvPlayersList", "m_active_Table.resources", true) end,
		  onChange = function(v)
			  saveOptionValue('AdvPlayersList', 'advplayerlist_api', 'SetModuleActive', { 'm_active_Table', 'resources' }, v, { 'resources', v })
		  end,
		},

		{ id = "advplayerlist_income", name = Spring.I18N('ui.settings.option.advplayerlist_income') or "Income",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.advplayerlist_income_descr') or "",
		  parentId = "advplayerlist_country",
		  onLoad = function() return loadWidgetData("AdvPlayersList", "m_active_Table.income", true) end,
		  onChange = function(v)
			  saveOptionValue('AdvPlayersList', 'advplayerlist_api', 'SetModuleActive', { 'm_active_Table', 'income' }, v, { 'income', v })
		  end,
		},

		{ id = "advplayerlist_absresbars", name = Spring.I18N('ui.settings.option.advplayerlist_absresbars') or "Absolute Res Bars",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.advplayerlist_absresbars_descr') or "",
		  parentId = "advplayerlist_country",
		  onLoad = function() return loadWidgetData("AdvPlayersList", "absoluteResbarValues", false) end,
		  onChange = function(v)
			  saveOptionValue('AdvPlayersList', 'advplayerlist_api', 'SetAbsoluteResbars', { 'absoluteResbarValues' }, v)
		  end,
		},

		{ id = "advplayerlist_share", name = Spring.I18N('ui.settings.option.advplayerlist_share') or "Share",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.advplayerlist_share_descr') or "",
		  parentId = "advplayerlist_country",
		  onLoad = function() return loadWidgetData("AdvPlayersList", "m_active_Table.share", true) end,
		  onChange = function(v)
			  saveOptionValue('AdvPlayersList', 'advplayerlist_api', 'SetModuleActive', { 'm_active_Table', 'share' }, v, { 'share', v })
		  end,
		},

		{ id = "advplayerlist_hidespecs", name = Spring.I18N('ui.settings.option.advplayerlist_hidespecs') or "Hide Spectators",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.advplayerlist_hidespecs_descr') or "",
		  parentId = "advplayerlist_country",
		  onLoad = function() return loadWidgetData("AdvPlayersList", "alwaysHideSpecs", true) end,
		  onChange = function(v)
			  saveOptionValue('AdvPlayersList', 'advplayerlist_api', 'SetAlwaysHideSpecs', { 'alwaysHideSpecs' }, v)
		  end,
		},

		{ id = "unittotals", name = Spring.I18N('ui.settings.option.unittotals') or "Unit Totals",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.unittotals_descr') or "",
		  parentId = "advplayerlist_country",
		  onLoad = function() return getWidgetToggleValue("AdvPlayersList Unit Totals") end,
		  onChange = function(v)
			  if v then
				  widgetHandler:EnableWidget("AdvPlayersList Unit Totals")
			  else
				  widgetHandler:DisableWidget("AdvPlayersList Unit Totals")
			  end
		  end,
		},

		{ id = "musicplayer", name = Spring.I18N('ui.settings.option.musicplayer') or "Music Player",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.musicplayer_descr') or "",
		  parentId = "advplayerlist_country",
		  onLoad = function() return loadWidgetData("AdvPlayersList Music Player New", "showGUI", false) end,
		  onChange = function(v)
			  saveOptionValue('AdvPlayersList Music Player New', 'music', 'SetShowGui', { 'showGUI' }, v)
		  end,
		},

		{ id = "mascot", name = Spring.I18N('ui.settings.option.mascot') or "Mascot",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.mascot_descr') or "",
		  parentId = "advplayerlist_country",
		  onLoad = function() return getWidgetToggleValue("AdvPlayersList Mascot") end,
		  onChange = function(v)
			  if v then
				  widgetHandler:EnableWidget("AdvPlayersList Mascot")
			  else
				  widgetHandler:DisableWidget("AdvPlayersList Mascot")
			  end
		  end,
		},

		---------------------------------------------------------------
		-- Console
		---------------------------------------------------------------
		{ id = "heading_console", name = Spring.I18N('ui.settings.option.console') or "Console", type = "heading" },

		{ id = "console_fontsize", name = Spring.I18N('ui.settings.option.console_fontsize') or "Font Size",
		  type = "slider", min = 0.92, max = 1.12, step = 0.02, value = 1,
		  desc = "",
		  onLoad = function() return loadWidgetData("Chat", "fontsizeMult", 1) end,
		  onChange = function(v)
			  saveOptionValue('Chat', 'chat', 'setFontsize', { 'fontsizeMult' }, v)
		  end,
		},

		{ id = "console_backgroundopacity", name = Spring.I18N('ui.settings.option.console_backgroundopacity') or "Background Opacity",
		  type = "slider", min = 0, max = 0.45, step = 0.01, value = 0,
		  desc = Spring.I18N('ui.settings.option.console_backgroundopacity_descr') or "",
		  parentId = "console_fontsize",
		  onLoad = function() return loadWidgetData("Chat", "chatBackgroundOpacity", 0) end,
		  onChange = function(v)
			  saveOptionValue('Chat', 'chat', 'setBackgroundOpacity', { 'chatBackgroundOpacity' }, v)
		  end,
		},

		{ id = "console_hidespecchat", name = Spring.I18N('ui.settings.option.console_hidespecchat') or "Hide Spec Chat",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.console_hidespecchat_descr') or "",
		  parentId = "console_fontsize",
		  onLoad = function() return Spring.GetConfigInt("HideSpecChat", 0) == 1 end,
		  onChange = function(v)
			  Spring.SetConfigInt("HideSpecChat", v and 1 or 0)
		  end,
		},

		{ id = "console_hidespecchatplayer", name = Spring.I18N('ui.settings.option.console_hidespecchatplayer') or "Hide Spec Chat (Player)",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.console_hidespecchatplayer_descr') or "",
		  parentId = "console_fontsize",
		  onLoad = function() return Spring.GetConfigInt("HideSpecChatPlayer", 1) == 1 end,
		  onChange = function(v)
			  Spring.SetConfigInt("HideSpecChatPlayer", v and 1 or 0)
		  end,
		},

		{ id = "console_hide", name = Spring.I18N('ui.settings.option.console_hide') or "Hide Console",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.console_hide_descr') or "",
		  parentId = "console_fontsize",
		  onLoad = function() return loadWidgetData("Chat", "hide", false) end,
		  onChange = function(v)
			  saveOptionValue('Chat', 'chat', 'setHide', { 'hide' }, v)
		  end,
		},

		{ id = "console_maxlines", name = Spring.I18N('ui.settings.option.console_maxlines') or "Max Lines",
		  type = "slider", min = 3, max = 7, step = 1, value = 5,
		  desc = "",
		  parentId = "console_fontsize",
		  onLoad = function() return loadWidgetData("Chat", "maxLines", 5) end,
		  onChange = function(v)
			  saveOptionValue('Chat', 'chat', 'setMaxLines', { 'maxLines' }, v)
		  end,
		},

		{ id = "console_maxconsolelines", name = Spring.I18N('ui.settings.option.console_maxconsolelines') or "Max Console Lines",
		  type = "slider", min = 2, max = 12, step = 1, value = 2,
		  desc = "",
		  parentId = "console_fontsize",
		  onLoad = function() return loadWidgetData("Chat", "maxConsoleLines", 2) end,
		  onChange = function(v)
			  saveOptionValue('Chat', 'chat', 'setMaxConsoleLines', { 'maxConsoleLines' }, v)
		  end,
		},

		---------------------------------------------------------------
		-- Widgets
		---------------------------------------------------------------
		{ id = "heading_widgets", name = Spring.I18N('ui.settings.option.label_widgets') or "Widgets", type = "heading" },

		{ id = "unitgroups", name = Spring.I18N('ui.settings.option.unitgroups') or "Unit Groups",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.unitgroups_descr') or "",
		  onLoad = function() return getWidgetToggleValue("Unit Groups") end,
		  onChange = function(v)
			  if v then
				  widgetHandler:EnableWidget("Unit Groups")
			  else
				  widgetHandler:DisableWidget("Unit Groups")
			  end
		  end,
		},

		{ id = "idlebuilders", name = Spring.I18N('ui.settings.option.idlebuilders') or "Idle Builders",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.idlebuilders_descr') or "",
		  onLoad = function() return getWidgetToggleValue("Idle Builders") end,
		  onChange = function(v)
			  if v then
				  widgetHandler:EnableWidget("Idle Builders")
			  else
				  widgetHandler:DisableWidget("Idle Builders")
			  end
		  end,
		},

		{ id = "buildbar", name = Spring.I18N('ui.settings.option.buildbar') or "Build Bar",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.buildbar_descr') or "",
		  onLoad = function() return getWidgetToggleValue("BuildBar") end,
		  onChange = function(v)
			  if v then
				  widgetHandler:EnableWidget("BuildBar")
			  else
				  widgetHandler:DisableWidget("BuildBar")
			  end
		  end,
		},

		{ id = "converterusage", name = Spring.I18N('ui.settings.option.converterusage') or "Converter Usage",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.converterusage_descr') or "",
		  onLoad = function() return getWidgetToggleValue("Converter Usage") end,
		  onChange = function(v)
			  if v then
				  widgetHandler:EnableWidget("Converter Usage")
			  else
				  widgetHandler:DisableWidget("Converter Usage")
			  end
		  end,
		},

		{ id = "widgetselector", name = Spring.I18N('ui.settings.option.widgetselector') or "Widget Selector",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.widgetselector_descr') or "",
		  onLoad = function() return Spring.GetConfigInt("widgetselector", 0) == 1 end,
		  onChange = function(v)
			  Spring.SetConfigInt("widgetselector", v and 1 or 0)
		  end,
		},
	}
end
