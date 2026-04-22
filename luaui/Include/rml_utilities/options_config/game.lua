-- Game config: Behavior, Cloak.

return function(deps)
	local saveOptionValue = deps.saveOptionValue
	local loadWidgetData = deps.loadWidgetData
	local getWidgetToggleValue = deps.getWidgetToggleValue

	return {
		---------------------------------------------------------------
		-- Behavior
		---------------------------------------------------------------
		{ id = "heading_behavior", name = Spring.I18N('ui.settings.option.label_behavior') or "Behavior", type = "heading" },

		-- Smart Select
		{ id = "smartselect_includebuildings", name = Spring.I18N('ui.settings.option.smartselect_includebuildings') or "Smart Select: Include Buildings",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.smartselect_includebuildings_descr') or "",
		  onLoad = function() return loadWidgetData("SmartSelect", { 'selectBuildingsWithMobile' }, false) end,
		  onChange = function(v)
			  saveOptionValue('SmartSelect', 'smartselect', 'setIncludeBuildings', { 'selectBuildingsWithMobile' }, v)
		  end,
		},

		{ id = "smartselect_includebuilders", name = Spring.I18N('ui.settings.option.smartselect_includebuilders') or "Include Builders",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.smartselect_includebuilders_descr') or "",
		  parentId = "smartselect_includebuildings",
		  onLoad = function() return loadWidgetData("SmartSelect", { 'includeBuilders' }, false) end,
		  onChange = function(v)
			  saveOptionValue('SmartSelect', 'smartselect', 'setIncludeBuilders', { 'includeBuilders' }, v)
		  end,
		},

		{ id = "smartselect_includeantinuke", name = Spring.I18N('ui.settings.option.smartselect_includeantinuke') or "Include Antinuke",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.smartselect_includeantinuke_descr') or "",
		  parentId = "smartselect_includebuildings",
		  onLoad = function() return loadWidgetData("SmartSelect", { 'includeAntinuke' }, false) end,
		  onChange = function(v)
			  saveOptionValue('SmartSelect', 'smartselect', 'setIncludeAntinuke', { 'includeAntinuke' }, v)
		  end,
		},

		{ id = "smartselect_includeradar", name = Spring.I18N('ui.settings.option.smartselect_includeradar') or "Include Radar",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.smartselect_includeradar_descr') or "",
		  parentId = "smartselect_includebuildings",
		  onLoad = function() return loadWidgetData("SmartSelect", { 'includeRadar' }, false) end,
		  onChange = function(v)
			  saveOptionValue('SmartSelect', 'smartselect', 'setIncludeRadar', { 'includeRadar' }, v)
		  end,
		},

		{ id = "smartselect_includejammer", name = Spring.I18N('ui.settings.option.smartselect_includejammer') or "Include Jammer",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.smartselect_includejammer_descr') or "",
		  parentId = "smartselect_includebuildings",
		  onLoad = function() return loadWidgetData("SmartSelect", { 'includeJammer' }, false) end,
		  onChange = function(v)
			  saveOptionValue('SmartSelect', 'smartselect', 'setIncludeJammer', { 'includeJammer' }, v)
		  end,
		},

		-- Priority Construction Turrets
		{ id = "prioconturrets", name = Spring.I18N('ui.settings.option.prioconturrets') or "Priority Construction Turrets",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.prioconturrets_descr') or "",
		  onLoad = function() return getWidgetToggleValue("Priority Construction Turrets") end,
		  onChange = function(v)
			  if v then widgetHandler:EnableWidget("Priority Construction Turrets")
			  else widgetHandler:DisableWidget("Priority Construction Turrets") end
		  end,
		},

		-- Builder Priority (parent + children)
		{ id = "builderpriority", name = Spring.I18N('ui.settings.option.builderpriority') or "Builder Priority",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.builderpriority_descr') or "",
		  onLoad = function() return getWidgetToggleValue("Builder Priority") end,
		  onChange = function(v)
			  if v then widgetHandler:EnableWidget("Builder Priority")
			  else widgetHandler:DisableWidget("Builder Priority") end
		  end,
		},

		{ id = "builderpriority_nanos", name = Spring.I18N('ui.settings.option.builderpriority_nanos') or "Low Priority Nanos",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.builderpriority_nanos_descr') or "",
		  parentId = "builderpriority",
		  onLoad = function() return loadWidgetData("Builder Priority", { 'lowpriorityNanos' }, false) end,
		  onChange = function(v)
			  saveOptionValue('Builder Priority', 'builderpriority', 'setLowPriorityNanos', { 'lowpriorityNanos' }, v)
		  end,
		},

		{ id = "builderpriority_cons", name = Spring.I18N('ui.settings.option.builderpriority_cons') or "Low Priority Cons",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.builderpriority_cons_descr') or "",
		  parentId = "builderpriority",
		  onLoad = function() return loadWidgetData("Builder Priority", { 'lowpriorityCons' }, false) end,
		  onChange = function(v)
			  saveOptionValue('Builder Priority', 'builderpriority', 'setLowPriorityCons', { 'lowpriorityCons' }, v)
		  end,
		},

		{ id = "builderpriority_labs", name = Spring.I18N('ui.settings.option.builderpriority_labs') or "Low Priority Labs",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.builderpriority_labs_descr') or "",
		  parentId = "builderpriority",
		  onLoad = function() return loadWidgetData("Builder Priority", { 'lowpriorityLabs' }, false) end,
		  onChange = function(v)
			  saveOptionValue('Builder Priority', 'builderpriority', 'setLowPriorityLabs', { 'lowpriorityLabs' }, v)
		  end,
		},

		-- Factory trio (flat)
		{ id = "factoryguard", name = Spring.I18N('ui.settings.option.factoryguard') or "Factory Guard Default On",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.factoryguard_descr') or "",
		  onLoad = function() return getWidgetToggleValue("Factory Guard Default On") end,
		  onChange = function(v)
			  if v then widgetHandler:EnableWidget("Factory Guard Default On")
			  else widgetHandler:DisableWidget("Factory Guard Default On") end
		  end,
		},

		{ id = "factoryholdpos", name = Spring.I18N('ui.settings.option.factoryholdpos') or "Factory Hold Position",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.factoryholdpos_descr') or "",
		  onLoad = function() return getWidgetToggleValue("Factory hold position") end,
		  onChange = function(v)
			  if v then widgetHandler:EnableWidget("Factory hold position")
			  else widgetHandler:DisableWidget("Factory hold position") end
		  end,
		},

		{ id = "factoryrepeat", name = Spring.I18N('ui.settings.option.factoryrepeat') or "Factory Auto-Repeat",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.factoryrepeat_descr') or "",
		  onLoad = function() return getWidgetToggleValue("Factory Auto-Repeat") end,
		  onChange = function(v)
			  if v then widgetHandler:EnableWidget("Factory Auto-Repeat")
			  else widgetHandler:DisableWidget("Factory Auto-Repeat") end
		  end,
		},

		-- Combat bools
		{ id = "transportai", name = Spring.I18N('ui.settings.option.transportai') or "Transport AI",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.transportai_descr') or "",
		  onLoad = function() return getWidgetToggleValue("Transport AI") end,
		  onChange = function(v)
			  if v then widgetHandler:EnableWidget("Transport AI")
			  else widgetHandler:DisableWidget("Transport AI") end
		  end,
		},

		{ id = "onlyfighterspatrol", name = Spring.I18N('ui.settings.option.onlyfighterspatrol') or "Only Fighters Patrol",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.onlyfighterspatrol_descr') or "",
		  onLoad = function() return getWidgetToggleValue("OnlyFightersPatrol") end,
		  onChange = function(v)
			  if v then widgetHandler:EnableWidget("OnlyFightersPatrol")
			  else widgetHandler:DisableWidget("OnlyFightersPatrol") end
		  end,
		},

		{ id = "fightersfly", name = Spring.I18N('ui.settings.option.fightersfly') or "Fighters Fly Mode",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.fightersfly_descr') or "",
		  onLoad = function() return getWidgetToggleValue("Set fighters on Fly mode") end,
		  onChange = function(v)
			  if v then widgetHandler:EnableWidget("Set fighters on Fly mode")
			  else widgetHandler:DisableWidget("Set fighters on Fly mode") end
		  end,
		},

		{ id = "settargetdefault", name = Spring.I18N('ui.settings.option.settargetdefault') or "Set Target Default",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.settargetdefault_descr') or "",
		  onLoad = function() return getWidgetToggleValue("Set target default") end,
		  onChange = function(v)
			  if v then widgetHandler:EnableWidget("Set target default")
			  else widgetHandler:DisableWidget("Set target default") end
		  end,
		},

		{ id = "dgunnogroundenemies", name = Spring.I18N('ui.settings.option.dgunnogroundenemies') or "DGun No Ground Enemies",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.dgunnogroundenemies_descr') or "",
		  onLoad = function() return getWidgetToggleValue("DGun no ground enemies") end,
		  onChange = function(v)
			  if v then widgetHandler:EnableWidget("DGun no ground enemies")
			  else widgetHandler:DisableWidget("DGun no ground enemies") end
		  end,
		},

		{ id = "dgunstallassist", name = Spring.I18N('ui.settings.option.dgunstallassist') or "DGun Stall Assist",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.dgunstallassist_descr') or "",
		  onLoad = function() return getWidgetToggleValue("DGun Stall Assist") end,
		  onChange = function(v)
			  if v then widgetHandler:EnableWidget("DGun Stall Assist")
			  else widgetHandler:DisableWidget("DGun Stall Assist") end
		  end,
		},

		{ id = "unitreclaimer", name = Spring.I18N('ui.settings.option.unitreclaimer') or "Specific Unit Reclaimer",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.unitreclaimer_descr') or "",
		  onLoad = function() return getWidgetToggleValue("Specific Unit Reclaimer") end,
		  onChange = function(v)
			  if v then widgetHandler:EnableWidget("Specific Unit Reclaimer")
			  else widgetHandler:DisableWidget("Specific Unit Reclaimer") end
		  end,
		},

		-- Auto Group
		{ id = "autogroup_immediate", name = Spring.I18N('ui.settings.option.autogroup_immediate') or "Auto Group: Immediate",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.autogroup_immediate_descr') or "",
		  onLoad = function() return loadWidgetData("Auto Group", { 'immediate' }, false) end,
		  onChange = function(v)
			  saveOptionValue('Auto Group', 'autogroup', 'setImmediate', { 'immediate' }, v)
		  end,
		},

		{ id = "autogroup_persist", name = Spring.I18N('ui.settings.option.autogroup_persist') or "Auto Group: Persist",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.autogroup_persist_descr') or "",
		  onLoad = function() return loadWidgetData("Auto Group", { 'persist' }, false) end,
		  onChange = function(v)
			  saveOptionValue('Auto Group', 'autogroup', 'setPersist', { 'persist' }, v)
		  end,
		},

		---------------------------------------------------------------
		-- Cloak
		---------------------------------------------------------------
		{ id = "heading_cloak", name = Spring.I18N('ui.settings.option.label_cloak') or "Cloak", type = "heading" },

		{ id = "autocloak", name = Spring.I18N('ui.settings.option.autocloak') or "Auto Cloak Units",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = "",
		  onLoad = function() return getWidgetToggleValue("Auto Cloak Units") end,
		  onChange = function(v)
			  if v then widgetHandler:EnableWidget("Auto Cloak Units")
			  else widgetHandler:DisableWidget("Auto Cloak Units") end
		  end,
		},
	}
end
