-- Interface > Info config: Info, Building, Ranges.

return function(deps)
	local saveOptionValue = deps.saveOptionValue
	local loadWidgetData = deps.loadWidgetData
	local getWidgetToggleValue = deps.getWidgetToggleValue

	-- Reclaim field highlight select options
	local reclaimFieldHighlightOptions = {
		{ value = 1, label = Spring.I18N('ui.settings.option.reclaimfieldhighlight_always') or "Always" },
		{ value = 2, label = Spring.I18N('ui.settings.option.reclaimfieldhighlight_resource') or "Resource View" },
		{ value = 3, label = Spring.I18N('ui.settings.option.reclaimfieldhighlight_reclaimer') or "Reclaimer Selected" },
		{ value = 4, label = Spring.I18N('ui.settings.option.reclaimfieldhighlight_resbot') or "Res Bot Selected" },
		{ value = 5, label = Spring.I18N('ui.settings.option.reclaimfieldhighlight_order') or "Reclaim Order" },
		{ value = 6, label = Spring.I18N('ui.settings.option.reclaimfieldhighlight_disabled') or "Disabled" },
	}

	return {
		---------------------------------------------------------------
		-- Info
		---------------------------------------------------------------
		{ id = "heading_info", name = Spring.I18N('ui.settings.option.label_info') or "Info", type = "heading" },

		{ id = "metalspots_values", name = Spring.I18N('ui.settings.option.metalspots_values') or "Metal Spots",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.metalspots_values_descr') or "",
		  onLoad = function() return loadWidgetData("Metalspots", "showValues", false) end,
		  onChange = function(v)
			  if WG.metalspots then
				  WG.metalspots.setShowValue(v)
			  end
			  saveOptionValue('Metalspots', 'metalspots', 'setShowValue', { 'showValue' }, v)
		  end,
		},

		{ id = "metalspots_metalviewonly", name = Spring.I18N('ui.settings.option.metalspots_metalviewonly') or "Metal View Only",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.metalspots_metalviewonly_descr') or "",
		  parentId = "metalspots_values",
		  onLoad = function() return loadWidgetData("Metalspots", "metalViewOnly", false) end,
		  onChange = function(v)
			  saveOptionValue('Metalspots', 'metalspots', 'setMetalViewOnly', { 'showValue' }, v)
		  end,
		},

		{ id = "geospots", name = Spring.I18N('ui.settings.option.geospots') or "Geo Spots",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.geospots_descr') or "",
		  onLoad = function() return getWidgetToggleValue("Geothermalspots") end,
		  onChange = function(v)
			  if v then
				  widgetHandler:EnableWidget("Geothermalspots")
			  else
				  widgetHandler:DisableWidget("Geothermalspots")
			  end
		  end,
		},

		{ id = "healthbarsscale", name = Spring.I18N('ui.settings.option.healthbarsscale') or "Health Bars Scale",
		  type = "slider", min = 0.6, max = 2.0, step = 0.1, value = 1,
		  desc = "",
		  onLoad = function() return loadWidgetData("Health Bars GL4", "barScale", 1) end,
		  onChange = function(v)
			  saveOptionValue('Health Bars GL4', 'healthbars', 'setScale', { 'barScale' }, v)
		  end,
		},

		{ id = "healthbarsheight", name = Spring.I18N('ui.settings.option.healthbarsheight') or "Health Bars Height",
		  type = "slider", min = 0.7, max = 2, step = 0.1, value = 0.9,
		  desc = "",
		  parentId = "healthbarsscale",
		  onLoad = function() return loadWidgetData("Health Bars GL4", "barHeight", 0.9) end,
		  onChange = function(v)
			  saveOptionValue('Health Bars GL4', 'healthbars', 'setHeight', { 'barHeight' }, v)
			  widgetHandler:DisableWidget("Health Bars GL4")
			  widgetHandler:EnableWidget("Health Bars GL4")
		  end,
		},

		{ id = "healthbarsvariable", name = Spring.I18N('ui.settings.option.healthbarsvariable') or "Variable Sizes",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.healthbarsvariable_descr') or "",
		  parentId = "healthbarsscale",
		  onLoad = function() return loadWidgetData("Health Bars GL4", "variableBarSizes", false) end,
		  onChange = function(v)
			  saveOptionValue('Health Bars GL4', 'healthbars', 'setVariableSizes', { 'variableBarSizes' }, v)
		  end,
		},

		{ id = "healthbarswhenguihidden", name = Spring.I18N('ui.settings.option.healthbarswhenguihidden') or "Draw When GUI Hidden",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.healthbarswhenguihidden_descr') or "",
		  parentId = "healthbarsscale",
		  onLoad = function() return loadWidgetData("Health Bars GL4", "drawWhenGuiHidden", false) end,
		  onChange = function(v)
			  saveOptionValue('Health Bars GL4', 'healthbars', 'setDrawWhenGuiHidden', { 'drawWhenGuiHidden' }, v)
		  end,
		},

		{ id = "rankicons", name = Spring.I18N('ui.settings.option.rankicons') or "Rank Icons",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.rankicons_descr') or "",
		  onLoad = function() return getWidgetToggleValue("Rank Icons GL4") end,
		  onChange = function(v)
			  if v then
				  widgetHandler:EnableWidget("Rank Icons GL4")
			  else
				  widgetHandler:DisableWidget("Rank Icons GL4")
			  end
		  end,
		},

		{ id = "rankicons_distance", name = Spring.I18N('ui.settings.option.rankicons_distance') or "Draw Distance",
		  type = "slider", min = 0.1, max = 1.5, step = 0.05, value = 1,
		  desc = "",
		  parentId = "rankicons",
		  onLoad = function() return loadWidgetData("Rank Icons", "distanceMult", 1) end,
		  onChange = function(v)
			  saveOptionValue('Rank Icons', 'rankicons', 'setDrawDistance', { 'distanceMult' }, v)
		  end,
		},

		{ id = "rankicons_scale", name = Spring.I18N('ui.settings.option.rankicons_scale') or "Scale",
		  type = "slider", min = 0.5, max = 2, step = 0.1, value = 1,
		  desc = "",
		  parentId = "rankicons",
		  onLoad = function() return loadWidgetData("Rank Icons", "iconsizeMult", 1) end,
		  onChange = function(v)
			  saveOptionValue('Rank Icons', 'rankicons', 'setScale', { 'iconsizeMult' }, v)
		  end,
		},

		{ id = "allycursors", name = Spring.I18N('ui.settings.option.allycursors') or "Ally Cursors",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.allycursors_descr') or "",
		  onLoad = function() return getWidgetToggleValue("AllyCursors") end,
		  onChange = function(v)
			  if v then
				  widgetHandler:EnableWidget("AllyCursors")
			  else
				  widgetHandler:DisableWidget("AllyCursors")
			  end
		  end,
		},

		{ id = "allycursors_playername", name = Spring.I18N('ui.settings.option.allycursors_playername') or "Player Name",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.allycursors_playername_descr') or "",
		  parentId = "allycursors",
		  onLoad = function() return loadWidgetData("AllyCursors", "showPlayerName", true) end,
		  onChange = function(v)
			  saveOptionValue('AllyCursors', 'allycursors', 'setPlayerNames', { 'showPlayerName' }, v)
		  end,
		},

		{ id = "allycursors_showdot", name = Spring.I18N('ui.settings.option.allycursors_showdot') or "Show Dot",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.allycursors_showdot_descr') or "",
		  parentId = "allycursors",
		  onLoad = function() return loadWidgetData("AllyCursors", "showCursorDot", true) end,
		  onChange = function(v)
			  saveOptionValue('AllyCursors', 'allycursors', 'setCursorDot', { 'showCursorDot' }, v)
		  end,
		},

		{ id = "allycursors_spectatorname", name = Spring.I18N('ui.settings.option.allycursors_spectatorname') or "Spectator Name",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.allycursors_spectatorname_descr') or "",
		  parentId = "allycursors",
		  onLoad = function() return loadWidgetData("AllyCursors", "showSpectatorName", true) end,
		  onChange = function(v)
			  saveOptionValue('AllyCursors', 'allycursors', 'setSpectatorNames', { 'showSpectatorName' }, v)
		  end,
		},

		{ id = "allycursors_lights", name = Spring.I18N('ui.settings.option.allycursors_lights') or "Lights",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.allycursors_lights_descr') or "",
		  parentId = "allycursors",
		  onLoad = function() return loadWidgetData("AllyCursors", "addLights", true) end,
		  onChange = function(v)
			  saveOptionValue('AllyCursors', 'allycursors', 'setLights', { 'addLights' }, v)
		  end,
		},

		{ id = "allycursors_lightradius", name = Spring.I18N('ui.settings.option.allycursors_lightradius') or "Light Radius",
		  type = "slider", min = 0.15, max = 1, step = 0.05, value = 0.5,
		  desc = "",
		  parentId = "allycursors",
		  onLoad = function() return loadWidgetData("AllyCursors", "lightRadiusMult", 0.5) end,
		  onChange = function(v)
			  saveOptionValue('AllyCursors', 'allycursors', 'setLightRadius', { 'lightRadiusMult' }, v)
		  end,
		},

		{ id = "allycursors_lightstrength", name = Spring.I18N('ui.settings.option.allycursors_lightstrength') or "Light Strength",
		  type = "slider", min = 0.1, max = 1.2, step = 0.05, value = 0.85,
		  desc = "",
		  parentId = "allycursors",
		  onLoad = function() return loadWidgetData("AllyCursors", "lightStrengthMult", 0.85) end,
		  onChange = function(v)
			  saveOptionValue('AllyCursors', 'allycursors', 'setLightStrength', { 'lightStrengthMult' }, v)
		  end,
		},

		{ id = "allycursors_selfshadowing", name = Spring.I18N('ui.settings.option.allycursors_selfshadowing') or "Self Shadowing",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = "",
		  parentId = "allycursors",
		  onLoad = function() return loadWidgetData("AllyCursors", "lightSelfShadowing", false) end,
		  onChange = function(v)
			  saveOptionValue('AllyCursors', 'allycursors', 'setLightSelfShadowing', { 'lightSelfShadowing' }, v)
		  end,
		},

		{ id = "givenunits", name = Spring.I18N('ui.settings.option.givenunits') or "Given Units",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.givenunits_descr') or "",
		  onLoad = function() return getWidgetToggleValue("Given Units") end,
		  onChange = function(v)
			  if v then
				  widgetHandler:EnableWidget("Given Units")
			  else
				  widgetHandler:DisableWidget("Given Units")
			  end
		  end,
		},

		{ id = "nametags_rank", name = Spring.I18N('ui.settings.option.nametags_rank') or "Name Tags Rank",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.nametags_rank_descr') or "",
		  onLoad = function() return loadWidgetData("Commander Name Tags", "showPlayerRank", true) end,
		  onChange = function(v)
			  saveOptionValue('Commander Name Tags', 'nametags', 'SetShowPlayerRank', { 'showPlayerRank' }, v)
		  end,
		},

		{ id = "displayselectedname", name = Spring.I18N('ui.settings.option.displayselectedname') or "Display Selected Name",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.displayselectedname_descr') or "",
		  onLoad = function() return loadWidgetData("Player-TV", "alwaysDisplayName", false) end,
		  onChange = function(v)
			  saveOptionValue('Player-TV', 'playertv', 'SetAlwaysDisplayName', { 'alwaysDisplayName' }, v)
		  end,
		},

		---------------------------------------------------------------
		-- Building
		---------------------------------------------------------------
		{ id = "heading_building", name = Spring.I18N('ui.settings.option.label_building') or "Building", type = "heading" },

		{ id = "buildinggrid", name = Spring.I18N('ui.settings.option.buildinggrid') or "Building Grid",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.buildinggrid_descr') or "",
		  onLoad = function() return getWidgetToggleValue("Building Grid GL4") end,
		  onChange = function(v)
			  if v then
				  widgetHandler:EnableWidget("Building Grid GL4")
			  else
				  widgetHandler:DisableWidget("Building Grid GL4")
			  end
		  end,
		},

		{ id = "buildinggridopacity", name = Spring.I18N('ui.settings.option.buildinggridopacity') or "Opacity",
		  type = "slider", min = 0.3, max = 1, step = 0.05, value = 1,
		  desc = "",
		  parentId = "buildinggrid",
		  onLoad = function() return loadWidgetData("Building Grid GL4", "opacity", 1) end,
		  onChange = function(v)
			  if widgetHandler.orderList["Building Grid GL4"] and widgetHandler.orderList["Building Grid GL4"] >= 0.5 then
				  widgetHandler:DisableWidget("Building Grid GL4")
				  saveOptionValue('Building Grid GL4', 'buildinggrid', 'setOpacity', { 'opacity' }, v)
				  widgetHandler:EnableWidget("Building Grid GL4")
			  else
				  saveOptionValue('Building Grid GL4', 'buildinggrid', 'setOpacity', { 'opacity' }, v)
			  end
		  end,
		},

		{ id = "startpositionsuggestions", name = Spring.I18N('ui.settings.option.startpositionsuggestions') or "Start Position Suggestions",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.startpositionsuggestions_descr') or "",
		  onLoad = function() return getWidgetToggleValue("Start Position Suggestions") end,
		  onChange = function(v)
			  if v then
				  widgetHandler:EnableWidget("Start Position Suggestions")
			  else
				  widgetHandler:DisableWidget("Start Position Suggestions")
			  end
		  end,
		},

		{ id = "flankingicons", name = Spring.I18N('ui.settings.option.flankingicons') or "Flanking Icons",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.flankingicons_descr') or "",
		  onLoad = function() return getWidgetToggleValue("Flanking Icons GL4") end,
		  onChange = function(v)
			  if v then
				  widgetHandler:EnableWidget("Flanking Icons GL4")
			  else
				  widgetHandler:DisableWidget("Flanking Icons GL4")
			  end
		  end,
		},

		{ id = "showbuilderqueue", name = Spring.I18N('ui.settings.option.showbuilderqueue') or "Show Builder Queue",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.showbuilderqueue_descr') or "",
		  onLoad = function() return getWidgetToggleValue("Show Builder Queue") end,
		  onChange = function(v)
			  if v then
				  widgetHandler:EnableWidget("Show Builder Queue")
			  else
				  widgetHandler:DisableWidget("Show Builder Queue")
			  end
		  end,
		},

		{ id = "unitenergyicons", name = Spring.I18N('ui.settings.option.unitenergyicons') or "Unit Energy Icons",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.unitenergyicons_descr') or "",
		  onLoad = function() return getWidgetToggleValue("Unit Energy Icons") end,
		  onChange = function(v)
			  if v then
				  widgetHandler:EnableWidget("Unit Energy Icons")
			  else
				  widgetHandler:DisableWidget("Unit Energy Icons")
			  end
		  end,
		},

		{ id = "unitidlebuildericons", name = Spring.I18N('ui.settings.option.unitidlebuildericons') or "Unit Idle Builder Icons",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.unitidlebuildericons_descr') or "",
		  onLoad = function() return getWidgetToggleValue("Unit Idle Builder Icons") end,
		  onChange = function(v)
			  if v then
				  widgetHandler:EnableWidget("Unit Idle Builder Icons")
			  else
				  widgetHandler:DisableWidget("Unit Idle Builder Icons")
			  end
		  end,
		},

		{ id = "reclaimfieldhighlight", name = Spring.I18N('ui.settings.option.reclaimfieldhighlight') or "Reclaim Field Highlight",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.reclaimfieldhighlight_descr') or "",
		  onLoad = function() return getWidgetToggleValue("Reclaim Field Highlight") end,
		  onChange = function(v)
			  if v then
				  widgetHandler:EnableWidget("Reclaim Field Highlight")
			  else
				  widgetHandler:DisableWidget("Reclaim Field Highlight")
			  end
		  end,
		},

		{ id = "reclaimfieldhighlight_metal", name = Spring.I18N('ui.settings.option.reclaimfieldhighlight_metal') or "Metal Select",
		  type = "select", min = 0, max = 0, step = 0, value = 3,
		  desc = Spring.I18N('ui.settings.option.reclaimfieldhighlight_metal_descr') or "",
		  parentId = "reclaimfieldhighlight",
		  selectOptions = reclaimFieldHighlightOptions,
		  onLoad = function() return loadWidgetData("Reclaim Field Highlight", "showOption", 3) end,
		  onChange = function(v)
			  saveOptionValue('Reclaim Field Highlight', 'reclaimfieldhighlight', 'setShowOption', { 'showOption' }, v)
		  end,
		},

		{ id = "reclaimfieldhighlight_energy", name = Spring.I18N('ui.settings.option.reclaimfieldhighlight_energy') or "Energy Select",
		  type = "select", min = 0, max = 0, step = 0, value = 3,
		  desc = Spring.I18N('ui.settings.option.reclaimfieldhighlight_energy_descr') or "",
		  parentId = "reclaimfieldhighlight",
		  selectOptions = reclaimFieldHighlightOptions,
		  onLoad = function() return loadWidgetData("Reclaim Field Highlight", "showEnergyOption", 3) end,
		  onChange = function(v)
			  saveOptionValue('Reclaim Field Highlight', 'reclaimfieldhighlight', 'setShowEnergyOption', { 'showEnergyOption' }, v)
		  end,
		},

		{ id = "highlightcomwrecks", name = Spring.I18N('ui.settings.option.highlightcomwrecks') or "Highlight Com Wrecks",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.highlightcomwrecks_descr') or "",
		  onLoad = function() return getWidgetToggleValue("Highlight Commander Wrecks") end,
		  onChange = function(v)
			  if v then
				  widgetHandler:EnableWidget("Highlight Commander Wrecks")
			  else
				  widgetHandler:DisableWidget("Highlight Commander Wrecks")
			  end
		  end,
		},

		{ id = "highlightcomwrecks_teamcolor", name = Spring.I18N('ui.settings.option.highlightcomwrecks_teamcolor') or "Team Color",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.highlightcomwrecks_teamcolor_descr') or "",
		  parentId = "highlightcomwrecks",
		  onLoad = function() return loadWidgetData("Highlight Commander Wrecks", "useTeamColor", true) end,
		  onChange = function(v)
			  saveOptionValue('Highlight Commander Wrecks', 'highlightcomwrecks', 'setUseTeamColor', { 'useTeamColor' }, v)
		  end,
		},

		---------------------------------------------------------------
		-- Ranges
		---------------------------------------------------------------
		{ id = "heading_ranges", name = Spring.I18N('ui.settings.option.label_ranges') or "Ranges", type = "heading" },

		{ id = "radarrange", name = Spring.I18N('ui.settings.option.radarrange') or "Radar Range",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.radarrange_descr') or "",
		  onLoad = function() return getWidgetToggleValue("Sensor Ranges Radar") end,
		  onChange = function(v)
			  if v then
				  widgetHandler:EnableWidget("Sensor Ranges Radar")
			  else
				  widgetHandler:DisableWidget("Sensor Ranges Radar")
			  end
		  end,
		},

		{ id = "radarrangeopacity", name = Spring.I18N('ui.settings.option.radarrangeopacity') or "Opacity",
		  type = "slider", min = 0.01, max = 0.33, step = 0.01, value = 0.08,
		  desc = "",
		  parentId = "radarrange",
		  onLoad = function() return loadWidgetData("Sensor Ranges Radar", "opacity", 0.08) end,
		  onChange = function(v)
			  saveOptionValue('Sensor Ranges Radar', 'radarrange', 'setOpacity', { 'opacity' }, v)
		  end,
		},

		{ id = "sonarrange", name = Spring.I18N('ui.settings.option.sonarrange') or "Sonar Range",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.sonarrange_descr') or "",
		  onLoad = function() return getWidgetToggleValue("Sensor Ranges Sonar") end,
		  onChange = function(v)
			  if v then
				  widgetHandler:EnableWidget("Sensor Ranges Sonar")
			  else
				  widgetHandler:DisableWidget("Sensor Ranges Sonar")
			  end
		  end,
		},

		{ id = "sonarrangeopacity", name = Spring.I18N('ui.settings.option.sonarrangeopacity') or "Opacity",
		  type = "slider", min = 0.01, max = 0.33, step = 0.01, value = 0.08,
		  desc = "",
		  parentId = "sonarrange",
		  onLoad = function() return loadWidgetData("Sensor Ranges Sonar", "opacity", 0.08) end,
		  onChange = function(v)
			  saveOptionValue('Sensor Ranges Sonar', 'sonarrange', 'setOpacity', { 'opacity' }, v)
		  end,
		},

		{ id = "jammerrange", name = Spring.I18N('ui.settings.option.jammerrange') or "Jammer Range",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.jammerrange_descr') or "",
		  onLoad = function() return getWidgetToggleValue("Sensor Ranges Jammer") end,
		  onChange = function(v)
			  if v then
				  widgetHandler:EnableWidget("Sensor Ranges Jammer")
			  else
				  widgetHandler:DisableWidget("Sensor Ranges Jammer")
			  end
		  end,
		},

		{ id = "jammerrangeopacity", name = Spring.I18N('ui.settings.option.jammerrangeopacity') or "Opacity",
		  type = "slider", min = 0.01, max = 0.66, step = 0.01, value = 0.08,
		  desc = "",
		  parentId = "jammerrange",
		  onLoad = function() return loadWidgetData("Sensor Ranges Jammer", "opacity", 0.08) end,
		  onChange = function(v)
			  saveOptionValue('Sensor Ranges Jammer', 'jammerrange', 'setOpacity', { 'opacity' }, v)
		  end,
		},

		{ id = "losrange", name = Spring.I18N('ui.settings.option.losrange') or "LOS Range",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.losrange_descr') or "",
		  onLoad = function() return getWidgetToggleValue("Sensor Ranges LOS") end,
		  onChange = function(v)
			  if v then
				  widgetHandler:EnableWidget("Sensor Ranges LOS")
			  else
				  widgetHandler:DisableWidget("Sensor Ranges LOS")
			  end
		  end,
		},

		{ id = "losrangeopacity", name = Spring.I18N('ui.settings.option.losrangeopacity') or "Opacity",
		  type = "slider", min = 0.01, max = 0.33, step = 0.01, value = 0.08,
		  desc = "",
		  parentId = "losrange",
		  onLoad = function() return loadWidgetData("Sensor Ranges LOS", "opacity", 0.08) end,
		  onChange = function(v)
			  saveOptionValue('Sensor Ranges LOS', 'losrange', 'setOpacity', { 'opacity' }, v)
		  end,
		},

		{ id = "losrangeteamcolors", name = Spring.I18N('ui.settings.option.losrangeteamcolors') or "Team Colors",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = "",
		  parentId = "losrange",
		  onLoad = function() return loadWidgetData("Sensor Ranges LOS", "useteamcolors", false) end,
		  onChange = function(v)
			  saveOptionValue('Sensor Ranges LOS', 'losrange', 'setUseTeamColors', { 'useteamcolors' }, v)
		  end,
		},

		{ id = "attackrange", name = Spring.I18N('ui.settings.option.attackrange') or "Attack Range",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.attackrange_descr') or "",
		  onLoad = function() return getWidgetToggleValue("Attack Range GL4") end,
		  onChange = function(v)
			  if v then
				  widgetHandler:EnableWidget("Attack Range GL4")
			  else
				  widgetHandler:DisableWidget("Attack Range GL4")
			  end
		  end,
		},

		{ id = "attackrange_shiftonly", name = Spring.I18N('ui.settings.option.attackrange_shiftonly') or "Shift Only",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.attackrange_shiftonly_descr') or "",
		  parentId = "attackrange",
		  onLoad = function() return loadWidgetData("Attack Range GL4", "shift_only", false) end,
		  onChange = function(v)
			  saveOptionValue('Attack Range GL4', 'attackrange', 'setShiftOnly', { 'shift_only' }, v)
		  end,
		},

		{ id = "attackrange_cursorunitrange", name = Spring.I18N('ui.settings.option.attackrange_cursorunitrange') or "Cursor Unit Range",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.attackrange_cursorunitrange_descr') or "",
		  parentId = "attackrange",
		  onLoad = function() return loadWidgetData("Attack Range GL4", "cursor_unit_range", false) end,
		  onChange = function(v)
			  saveOptionValue('Attack Range GL4', 'attackrange', 'setCursorUnitRange', { 'cursor_unit_range' }, v)
		  end,
		},

		{ id = "attackrange_numrangesmult", name = Spring.I18N('ui.settings.option.attackrange_numrangesmult') or "Num Ranges Mult",
		  type = "slider", min = 0.3, max = 1, step = 0.1, value = 1,
		  desc = Spring.I18N('ui.settings.option.attackrange_numrangesmult_descr') or "",
		  parentId = "attackrange",
		  onLoad = function() return loadWidgetData("Attack Range GL4", "selectionDisableThresholdMult", 1) end,
		  onChange = function(v)
			  saveOptionValue('Attack Range GL4', 'attackrange', 'setNumRangesMult', { 'selectionDisableThresholdMult' }, v)
		  end,
		},

		{ id = "defrange", name = Spring.I18N('ui.settings.option.defrange') or "Defense Range",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.defrange_descr') or "",
		  onLoad = function() return getWidgetToggleValue("Defense Range GL4") end,
		  onChange = function(v)
			  if v then
				  widgetHandler:EnableWidget("Defense Range GL4")
			  else
				  widgetHandler:DisableWidget("Defense Range GL4")
			  end
		  end,
		},

		{ id = "defrange_allyair", name = Spring.I18N('ui.settings.option.defrange_allyair') or "Ally Air",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.defrange_allyair_descr') or "",
		  parentId = "defrange",
		  onLoad = function() return loadWidgetData("Defense Range GL4", "enabled.ally.air", false) end,
		  onChange = function(v)
			  saveOptionValue('Defense Range GL4', 'defrange', 'setAllyAir', { 'enabled', 'ally', 'air' }, v)
		  end,
		},

		{ id = "defrange_allyground", name = Spring.I18N('ui.settings.option.defrange_allyground') or "Ally Ground",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.defrange_allyground_descr') or "",
		  parentId = "defrange",
		  onLoad = function() return loadWidgetData("Defense Range GL4", "enabled.ally.ground", false) end,
		  onChange = function(v)
			  saveOptionValue('Defense Range GL4', 'defrange', 'setAllyGround', { 'enabled', 'ally', 'ground' }, v)
			  saveOptionValue('Defense Range GL4', 'defrange', 'setAllyGround', { 'enabled', 'ally', 'cannon' }, v)
		  end,
		},

		{ id = "defrange_allynuke", name = Spring.I18N('ui.settings.option.defrange_allynuke') or "Ally Nuke",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.defrange_allynuke_descr') or "",
		  parentId = "defrange",
		  onLoad = function() return loadWidgetData("Defense Range GL4", "enabled.ally.nuke", false) end,
		  onChange = function(v)
			  saveOptionValue('Defense Range GL4', 'defrange', 'setAllyNuke', { 'enabled', 'ally', 'nuke' }, v)
		  end,
		},

		{ id = "defrange_allylrpc", name = Spring.I18N('ui.settings.option.defrange_allylrpc') or "Ally LRPC",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.defrange_allylrpc_descr') or "",
		  parentId = "defrange",
		  onLoad = function() return loadWidgetData("Defense Range GL4", "enabled.ally.lrpc", false) end,
		  onChange = function(v)
			  saveOptionValue('Defense Range GL4', 'defrange', 'setAllyLRPC', { 'enabled', 'ally', 'lrpc' }, v)
		  end,
		},

		{ id = "defrange_enemyair", name = Spring.I18N('ui.settings.option.defrange_enemyair') or "Enemy Air",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.defrange_enemyair_descr') or "",
		  parentId = "defrange",
		  onLoad = function() return loadWidgetData("Defense Range GL4", "enabled.enemy.air", false) end,
		  onChange = function(v)
			  saveOptionValue('Defense Range GL4', 'defrange', 'setEnemyAir', { 'enabled', 'enemy', 'air' }, v)
		  end,
		},

		{ id = "defrange_enemyground", name = Spring.I18N('ui.settings.option.defrange_enemyground') or "Enemy Ground",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.defrange_enemyground_descr') or "",
		  parentId = "defrange",
		  onLoad = function() return loadWidgetData("Defense Range GL4", "enabled.enemy.ground", false) end,
		  onChange = function(v)
			  saveOptionValue('Defense Range GL4', 'defrange', 'setEnemyGround', { 'enabled', 'enemy', 'ground' }, v)
			  saveOptionValue('Defense Range GL4', 'defrange', 'setEnemyGround', { 'enabled', 'enemy', 'cannon' }, v)
		  end,
		},

		{ id = "defrange_enemynuke", name = Spring.I18N('ui.settings.option.defrange_enemynuke') or "Enemy Nuke",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.defrange_enemynuke_descr') or "",
		  parentId = "defrange",
		  onLoad = function() return loadWidgetData("Defense Range GL4", "enabled.enemy.nuke", false) end,
		  onChange = function(v)
			  saveOptionValue('Defense Range GL4', 'defrange', 'setEnemyNuke', { 'enabled', 'enemy', 'nuke' }, v)
		  end,
		},

		{ id = "defrange_enemylrpc", name = Spring.I18N('ui.settings.option.defrange_enemylrpc') or "Enemy LRPC",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.defrange_enemylrpc_descr') or "",
		  parentId = "defrange",
		  onLoad = function() return loadWidgetData("Defense Range GL4", "enabled.enemy.lrpc", false) end,
		  onChange = function(v)
			  saveOptionValue('Defense Range GL4', 'defrange', 'setEnemyLRPC', { 'enabled', 'enemy', 'lrpc' }, v)
		  end,
		},

		{ id = "antiranges", name = Spring.I18N('ui.settings.option.antiranges') or "Anti Ranges",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.antiranges_descr') or "",
		  onLoad = function() return getWidgetToggleValue("Anti Ranges") end,
		  onChange = function(v)
			  if v then
				  widgetHandler:EnableWidget("Anti Ranges")
			  else
				  widgetHandler:DisableWidget("Anti Ranges")
			  end
		  end,
		},
	}
end
