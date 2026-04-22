-- Interface > Spectator config: Spectator, Developer.

return function(deps)
	local saveOptionValue = deps.saveOptionValue
	local loadWidgetData = deps.loadWidgetData
	local getWidgetToggleValue = deps.getWidgetToggleValue

	-- Spectator HUD config select options
	local spectatorHUDConfigOptions = {
		{ value = 1, label = Spring.I18N('ui.settings.option.spectator_hud_config_basic') or "Basic" },
		{ value = 2, label = Spring.I18N('ui.settings.option.spectator_hud_config_advanced') or "Advanced" },
		{ value = 3, label = Spring.I18N('ui.settings.option.spectator_hud_config_expert') or "Expert" },
		{ value = 4, label = Spring.I18N('ui.settings.option.spectator_hud_config_custom') or "Custom" },
	}

	return {
		---------------------------------------------------------------
		-- Spectator
		---------------------------------------------------------------
		{ id = "heading_spectator", name = Spring.I18N('ui.settings.option.label_spectator') or "Spectator", type = "heading" },

		{ id = "spectator_hud", name = Spring.I18N('ui.settings.option.spectator_hud') or "Spectator HUD",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.spectator_hud_descr') or "",
		  onLoad = function() return getWidgetToggleValue("Spectator HUD") end,
		  onChange = function(v)
			  if v then
				  widgetHandler:EnableWidget("Spectator HUD")
			  else
				  widgetHandler:DisableWidget("Spectator HUD")
			  end
		  end,
		},

		{ id = "spectator_hud_size", name = Spring.I18N('ui.settings.option.spectator_hud_size') or "Size",
		  type = "slider", min = 0.1, max = 2, step = 0.1, value = 0.8,
		  desc = "",
		  parentId = "spectator_hud",
		  onLoad = function() return loadWidgetData("Spectator HUD", "widgetScale", 0.8) end,
		  onChange = function(v)
			  saveOptionValue('Spectator HUD', 'spectator_hud', 'setWidgetSize', { 'widgetScale' }, v)
		  end,
		},

		{ id = "spectator_hud_config", name = Spring.I18N('ui.settings.option.spectator_hud_config') or "Config",
		  type = "select", min = 0, max = 0, step = 0, value = 1,
		  desc = Spring.I18N('ui.settings.option.spectator_hud_config_descr') or "",
		  parentId = "spectator_hud",
		  selectOptions = spectatorHUDConfigOptions,
		  onLoad = function() return loadWidgetData("Spectator HUD", "config", 1) end,
		  onChange = function(v)
			  saveOptionValue('Spectator HUD', 'spectator_hud', 'setConfig', { 'config' }, v)
		  end,
		},

		{ id = "spectator_hud_metric_metalIncome", name = Spring.I18N('ui.spectator_hud.metalIncome_title') or "Metal Income",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.spectator_hud.metalIncome_tooltip') or "",
		  parentId = "spectator_hud",
		  onLoad = function() return loadWidgetData("Spectator HUD", { 'metricsEnabled', 'metalIncome' }, true) end,
		  onChange = function(v)
			  saveOptionValue('Spectator HUD', 'spectator_hud', 'setMetricEnabled', { 'metricsEnabled', 'metalIncome' }, v, { 'metalIncome', v })
		  end,
		},

		{ id = "spectator_hud_metric_energyIncome", name = Spring.I18N('ui.spectator_hud.energyIncome_title') or "Energy Income",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.spectator_hud.energyIncome_tooltip') or "",
		  parentId = "spectator_hud",
		  onLoad = function() return loadWidgetData("Spectator HUD", { 'metricsEnabled', 'energyIncome' }, true) end,
		  onChange = function(v)
			  saveOptionValue('Spectator HUD', 'spectator_hud', 'setMetricEnabled', { 'metricsEnabled', 'energyIncome' }, v, { 'energyIncome', v })
		  end,
		},

		{ id = "spectator_hud_metric_buildPower", name = Spring.I18N('ui.spectator_hud.buildPower_title') or "Build Power",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.spectator_hud.buildPower_tooltip') or "",
		  parentId = "spectator_hud",
		  onLoad = function() return loadWidgetData("Spectator HUD", { 'metricsEnabled', 'buildPower' }, true) end,
		  onChange = function(v)
			  saveOptionValue('Spectator HUD', 'spectator_hud', 'setMetricEnabled', { 'metricsEnabled', 'buildPower' }, v, { 'buildPower', v })
		  end,
		},

		{ id = "spectator_hud_metric_metalProduced", name = Spring.I18N('ui.spectator_hud.metalProduced_title') or "Metal Produced",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.spectator_hud.metalProduced_tooltip') or "",
		  parentId = "spectator_hud",
		  onLoad = function() return loadWidgetData("Spectator HUD", { 'metricsEnabled', 'metalProduced' }, true) end,
		  onChange = function(v)
			  saveOptionValue('Spectator HUD', 'spectator_hud', 'setMetricEnabled', { 'metricsEnabled', 'metalProduced' }, v, { 'metalProduced', v })
		  end,
		},

		{ id = "spectator_hud_metric_energyProduced", name = Spring.I18N('ui.spectator_hud.energyProduced_title') or "Energy Produced",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.spectator_hud.energyProduced_tooltip') or "",
		  parentId = "spectator_hud",
		  onLoad = function() return loadWidgetData("Spectator HUD", { 'metricsEnabled', 'energyProduced' }, true) end,
		  onChange = function(v)
			  saveOptionValue('Spectator HUD', 'spectator_hud', 'setMetricEnabled', { 'metricsEnabled', 'energyProduced' }, v, { 'energyProduced', v })
		  end,
		},

		{ id = "spectator_hud_metric_metalExcess", name = Spring.I18N('ui.spectator_hud.metalExcess_title') or "Metal Excess",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.spectator_hud.metalExcess_tooltip') or "",
		  parentId = "spectator_hud",
		  onLoad = function() return loadWidgetData("Spectator HUD", { 'metricsEnabled', 'metalExcess' }, true) end,
		  onChange = function(v)
			  saveOptionValue('Spectator HUD', 'spectator_hud', 'setMetricEnabled', { 'metricsEnabled', 'metalExcess' }, v, { 'metalExcess', v })
		  end,
		},

		{ id = "spectator_hud_metric_energyExcess", name = Spring.I18N('ui.spectator_hud.energyExcess_title') or "Energy Excess",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.spectator_hud.energyExcess_tooltip') or "",
		  parentId = "spectator_hud",
		  onLoad = function() return loadWidgetData("Spectator HUD", { 'metricsEnabled', 'energyExcess' }, true) end,
		  onChange = function(v)
			  saveOptionValue('Spectator HUD', 'spectator_hud', 'setMetricEnabled', { 'metricsEnabled', 'energyExcess' }, v, { 'energyExcess', v })
		  end,
		},

		{ id = "spectator_hud_metric_armyValue", name = Spring.I18N('ui.spectator_hud.armyValue_title') or "Army Value",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.spectator_hud.armyValue_tooltip') or "",
		  parentId = "spectator_hud",
		  onLoad = function() return loadWidgetData("Spectator HUD", { 'metricsEnabled', 'armyValue' }, true) end,
		  onChange = function(v)
			  saveOptionValue('Spectator HUD', 'spectator_hud', 'setMetricEnabled', { 'metricsEnabled', 'armyValue' }, v, { 'armyValue', v })
		  end,
		},

		{ id = "spectator_hud_metric_defenseValue", name = Spring.I18N('ui.spectator_hud.defenseValue_title') or "Defense Value",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.spectator_hud.defenseValue_tooltip') or "",
		  parentId = "spectator_hud",
		  onLoad = function() return loadWidgetData("Spectator HUD", { 'metricsEnabled', 'defenseValue' }, true) end,
		  onChange = function(v)
			  saveOptionValue('Spectator HUD', 'spectator_hud', 'setMetricEnabled', { 'metricsEnabled', 'defenseValue' }, v, { 'defenseValue', v })
		  end,
		},

		{ id = "spectator_hud_metric_utilityValue", name = Spring.I18N('ui.spectator_hud.utilityValue_title') or "Utility Value",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.spectator_hud.utilityValue_tooltip') or "",
		  parentId = "spectator_hud",
		  onLoad = function() return loadWidgetData("Spectator HUD", { 'metricsEnabled', 'utilityValue' }, true) end,
		  onChange = function(v)
			  saveOptionValue('Spectator HUD', 'spectator_hud', 'setMetricEnabled', { 'metricsEnabled', 'utilityValue' }, v, { 'utilityValue', v })
		  end,
		},

		{ id = "spectator_hud_metric_economyValue", name = Spring.I18N('ui.spectator_hud.economyValue_title') or "Economy Value",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.spectator_hud.economyValue_tooltip') or "",
		  parentId = "spectator_hud",
		  onLoad = function() return loadWidgetData("Spectator HUD", { 'metricsEnabled', 'economyValue' }, true) end,
		  onChange = function(v)
			  saveOptionValue('Spectator HUD', 'spectator_hud', 'setMetricEnabled', { 'metricsEnabled', 'economyValue' }, v, { 'economyValue', v })
		  end,
		},

		{ id = "spectator_hud_metric_damageDealt", name = Spring.I18N('ui.spectator_hud.damageDealt_title') or "Damage Dealt",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.spectator_hud.damageDealt_tooltip') or "",
		  parentId = "spectator_hud",
		  onLoad = function() return loadWidgetData("Spectator HUD", { 'metricsEnabled', 'damageDealt' }, true) end,
		  onChange = function(v)
			  saveOptionValue('Spectator HUD', 'spectator_hud', 'setMetricEnabled', { 'metricsEnabled', 'damageDealt' }, v, { 'damageDealt', v })
		  end,
		},

		---------------------------------------------------------------
		-- Developer
		---------------------------------------------------------------
		{ id = "heading_developer", name = Spring.I18N('ui.settings.option.label_developer') or "Developer", type = "heading" },

		{ id = "devmode", name = Spring.I18N('ui.settings.option.devmode') or "Developer Mode",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.devmode_descr') or "",
		  onLoad = function() return Spring.GetConfigInt("DevUI", 0) == 1 end,
		  onChange = function(v)
			  Spring.SetConfigInt("DevUI", v and 1 or 0)
			  Spring.SendCommands("luaui reload")
		  end,
		},
	}
end
