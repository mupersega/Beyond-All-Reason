-- Graphics > Environment config: Terrain, Weather, Effects.

return function(deps)
	local saveOptionValue = deps.saveOptionValue
	local loadWidgetData = deps.loadWidgetData
	local getWidgetToggleValue = deps.getWidgetToggleValue

	return {
		---------------------------------------------------------------
		-- Terrain
		---------------------------------------------------------------
		{ id = "heading_terrain", name = Spring.I18N('ui.settings.option.label_terrain') or "Terrain", type = "heading" },

		{ id = "decalsgl4_enabled", name = Spring.I18N('ui.settings.option.decalsgl4') or "Ground Scarring",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = "",
		  onLoad = function() return getWidgetToggleValue("Decals GL4") end,
		  onChange = function(v)
			  if v then widgetHandler:EnableWidget("Decals GL4")
			  else widgetHandler:DisableWidget("Decals GL4") end
		  end,
		},

		{ id = "decalsgl4_lifetime", name = Spring.I18N('ui.settings.option.decalsgl4_lifetime') or "Lifetime",
		  type = "slider", min = 0.5, max = 8, step = 0.1, value = 1,
		  desc = Spring.I18N('ui.settings.option.decalsgl4_lifetime_descr') or "",
		  parentId = "decalsgl4_enabled",
		  onLoad = function() return loadWidgetData("Decals GL4", "lifeTimeMult", 1) end,
		  onChange = function(v)
			  saveOptionValue('Decals GL4', 'decalsgl4', 'SetLifeTimeMult', { 'lifeTimeMult' }, v)
		  end,
		},

		{ id = "decals", name = Spring.I18N('ui.settings.option.decals') or "Ground Decals",
		  type = "slider", min = 0, max = 3, step = 0.1, value = 0,
		  desc = Spring.I18N('ui.settings.option.decals_descr') or "",
		  onLoad = function() return Spring.GetConfigInt("GroundDecals", 0) end,
		  onChange = function(v)
			  Spring.SetConfigInt("GroundDecals", v)
			  Spring.SendCommands("GroundDecals " .. v)
		  end,
		},

		{ id = "grass_enabled", name = Spring.I18N('ui.settings.option.grass') or "Grass",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.grass_desc') or "",
		  onLoad = function() return getWidgetToggleValue("Map Grass GL4") end,
		  onChange = function(v)
			  if v then widgetHandler:EnableWidget("Map Grass GL4")
			  else widgetHandler:DisableWidget("Map Grass GL4") end
		  end,
		},

		{ id = "grassdistance", name = Spring.I18N('ui.settings.option.grassdistance') or "Distance",
		  type = "slider", min = 0.3, max = 1, step = 0.01, value = 1,
		  desc = Spring.I18N('ui.settings.option.grassdistance_desc') or "",
		  parentId = "grass_enabled",
		  onLoad = function() return loadWidgetData("Map Grass GL4", "distanceMult", 1) end,
		  onChange = function(v)
			  saveOptionValue('Map Grass GL4', 'grassgl4', 'setDistanceMult', { 'distanceMult' }, v)
		  end,
		},

		{ id = "mapedgeextension_enabled", name = Spring.I18N('ui.settings.option.mapedgeextension') or "Map Edge Extension",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.mapedgeextension_descr') or "",
		  onLoad = function() return getWidgetToggleValue("Map Edge Extension") end,
		  onChange = function(v)
			  if v then widgetHandler:EnableWidget("Map Edge Extension")
			  else widgetHandler:DisableWidget("Map Edge Extension") end
		  end,
		},

		{ id = "mapedgeextension_brightness", name = Spring.I18N('ui.settings.option.mapedgeextension_brightness') or "Brightness",
		  type = "slider", min = 0.2, max = 1, step = 0.01, value = 0.3,
		  desc = "",
		  parentId = "mapedgeextension_enabled",
		  onLoad = function() return loadWidgetData("Map Edge Extension", "brightness", 0.3) end,
		  onChange = function(v)
			  saveOptionValue('Map Edge Extension', 'mapedgeextension', 'setBrightness', { 'brightness' }, v)
		  end,
		},

		{ id = "mapedgeextension_curvature", name = Spring.I18N('ui.settings.option.mapedgeextension_curvature') or "Curvature",
		  type = "bool", min = 0, max = 1, step = 1, value = true,
		  desc = Spring.I18N('ui.settings.option.mapedgeextension_curvature_descr') or "",
		  parentId = "mapedgeextension_enabled",
		  onLoad = function() return loadWidgetData("Map Edge Extension", "curvature", true) end,
		  onChange = function(v)
			  saveOptionValue('Map Edge Extension', 'mapedgeextension', 'setCurvature', { 'curvature' }, v)
		  end,
		},

		{ id = "treewind_enabled", name = Spring.I18N('ui.settings.option.treewind') or "Tree Wind",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.treewind_descr') or "",
		  onLoad = function() return Spring.GetConfigInt("TreeWind", 1) == 1 end,
		  onChange = function(v)
			  Spring.SendCommands("luarules treewind " .. (v and 1 or 0))
			  Spring.SetConfigInt("TreeWind", v and 1 or 0)
		  end,
		},

		---------------------------------------------------------------
		-- Weather
		---------------------------------------------------------------
		{ id = "heading_weather", name = Spring.I18N('ui.settings.option.label_weather') or "Weather", type = "heading" },

		{ id = "water", name = Spring.I18N('ui.settings.option.water') or "Water Quality",
		  type = "select", min = 0, max = 0, step = 0, value = 1,
		  desc = "",
		  selectOptions = {
			  { value = 1, label = "Basic" },
			  { value = 2, label = "Reflective" },
		  },
		  onLoad = function() return Spring.GetConfigInt("Water", 4) >= 4 and 2 or 1 end,
		  onChange = function(v)
			  local waterLevel = (v == 2) and 4 or 0
			  Spring.SetConfigInt("Water", waterLevel)
			  Spring.SendCommands("water " .. waterLevel)
		  end,
		},

		{ id = "snow_enabled", name = Spring.I18N('ui.settings.option.snow') or "Snow",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.snow_descr') or "",
		  onLoad = function() return getWidgetToggleValue("Snow") end,
		  onChange = function(v)
			  if v then widgetHandler:EnableWidget("Snow")
			  else widgetHandler:DisableWidget("Snow") end
		  end,
		},

		{ id = "snowamount", name = Spring.I18N('ui.settings.option.snowamount') or "Amount",
		  type = "slider", min = 0.2, max = 3, step = 0.2, value = 1,
		  desc = Spring.I18N('ui.settings.option.snowamount_descr') or "",
		  parentId = "snow_enabled",
		  onLoad = function() return loadWidgetData("Snow", "multiplier", 1) end,
		  onChange = function(v)
			  saveOptionValue('Snow', 'snow', 'setMultiplier', { 'customParticleMultiplier' }, v)
		  end,
		},

		{ id = "snowmap_enabled", name = Spring.I18N('ui.settings.option.snowmap') or "Snow on Map",
		  type = "bool", min = 0, max = 1, step = 1, value = true,
		  desc = Spring.I18N('ui.settings.option.snowmap_descr') or "",
		  parentId = "snow_enabled",
		  onLoad = function() return loadWidgetData("Snow", "snowMap", true) end,
		  onChange = function(v)
			  saveOptionValue('Snow', 'snow', 'setSnowMap', { 'snowMap' }, v)
		  end,
		},

		{ id = "snowautoreduce_enabled", name = Spring.I18N('ui.settings.option.snowautoreduce') or "Auto Reduce",
		  type = "bool", min = 0, max = 1, step = 1, value = true,
		  desc = Spring.I18N('ui.settings.option.snowautoreduce_descr') or "",
		  parentId = "snow_enabled",
		  onLoad = function() return loadWidgetData("Snow", "autoReduce", true) end,
		  onChange = function(v)
			  saveOptionValue('Snow', 'snow', 'setAutoReduce', { 'autoReduce' }, v)
		  end,
		},

		{ id = "clouds_enabled", name = Spring.I18N('ui.settings.option.clouds') or "Volumetric Clouds",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = "",
		  onLoad = function() return getWidgetToggleValue("Volumetric Clouds") end,
		  onChange = function(v)
			  if v then widgetHandler:EnableWidget("Volumetric Clouds")
			  else widgetHandler:DisableWidget("Volumetric Clouds") end
		  end,
		},

		{ id = "clouds_opacity", name = Spring.I18N('ui.settings.option.clouds_opacity') or "Opacity",
		  type = "slider", min = 0.2, max = 1.4, step = 0.05, value = 1,
		  desc = "",
		  parentId = "clouds_enabled",
		  onLoad = function() return loadWidgetData("Volumetric Clouds", "opacityMult", 1) end,
		  onChange = function(v)
			  saveOptionValue('Volumetric Clouds', 'clouds', 'setOpacity', { 'opacityMult' }, v)
		  end,
		},

		{ id = "fogmult", name = Spring.I18N('ui.settings.option.fog') or "Fog",
		  type = "slider", min = 0, max = 1, step = 0.01, value = 1,
		  desc = Spring.I18N('ui.settings.option.fogmult_descr') or "",
		  onLoad = function() return Spring.GetConfigFloat("FogMult", 1) end,
		  onChange = function(v) Spring.SetConfigFloat("FogMult", v) end,
		},

		{ id = "losopacity", name = Spring.I18N('ui.settings.option.losopacity') or "LOS Opacity",
		  type = "slider", min = 0.01, max = 1, step = 0.01, value = 0.5,
		  desc = "",
		  onLoad = function() return loadWidgetData("LOS colors", "opacity", 0.5) end,
		  onChange = function(v)
			  saveOptionValue('LOS colors', 'loscolors', 'setOpacity', { 'opacity' }, v)
		  end,
		},

		---------------------------------------------------------------
		-- Effects
		---------------------------------------------------------------
		{ id = "heading_effects", name = Spring.I18N('ui.settings.option.label_effects') or "Effects", type = "heading" },

		{ id = "particles", name = Spring.I18N('ui.settings.option.particles') or "Max Particles",
		  type = "slider", min = 10000, max = 40000, step = 1000, value = 15000,
		  desc = Spring.I18N('ui.settings.option.particles_descr') or "",
		  onLoad = function() return Spring.GetConfigInt("MaxParticles", 15000) end,
		  onChange = function(v)
			  local iv = math.floor(v)
			  Spring.SetConfigInt("MaxParticles", iv)
			  Spring.SetConfigInt("MaxNanoParticles", math.floor(iv * 0.34))
		  end,
		},

		{ id = "featuredrawdist", name = Spring.I18N('ui.settings.option.featuredrawdist') or "Feature Draw Distance",
		  type = "slider", min = 2500, max = 40000, step = 100, value = 10000,
		  desc = Spring.I18N('ui.settings.option.featuredrawdist_descr') or "",
		  onLoad = function() return Spring.GetConfigInt("FeatureDrawDistance", 10000) end,
		  onChange = function(v)
			  local iv = math.floor(v)
			  Spring.SetConfigInt("FeatureFadeDistance", math.floor(iv * 0.8))
			  Spring.SetConfigInt("FeatureDrawDistance", iv)
		  end,
		},

		{ id = "resurrectionhalos_enabled", name = Spring.I18N('ui.settings.option.resurrectionhalos') or "Resurrection Halos",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.resurrectionhalos_descr') or "",
		  onLoad = function() return getWidgetToggleValue("Resurrection Halos GL4") end,
		  onChange = function(v)
			  if v then widgetHandler:EnableWidget("Resurrection Halos GL4")
			  else widgetHandler:DisableWidget("Resurrection Halos GL4") end
		  end,
		},

		{ id = "dof_enabled", name = Spring.I18N('ui.settings.option.dof') or "Depth of Field",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.dof_descr') or "",
		  onLoad = function() return getWidgetToggleValue("Depth of Field") end,
		  onChange = function(v)
			  if v then widgetHandler:EnableWidget("Depth of Field")
			  else widgetHandler:DisableWidget("Depth of Field") end
		  end,
		},

		{ id = "dof_autofocus", name = Spring.I18N('ui.settings.option.dof_autofocus') or "Autofocus",
		  type = "bool", min = 0, max = 1, step = 1, value = true,
		  desc = Spring.I18N('ui.settings.option.dof_autofocus_descr') or "",
		  parentId = "dof_enabled",
		  onLoad = function() return loadWidgetData("Depth of Field", "autofocus", true) end,
		  onChange = function(v)
			  saveOptionValue('Depth of Field', 'dof', 'setAutofocus', { 'autofocus' }, v)
		  end,
		},

		{ id = "dof_fstop", name = Spring.I18N('ui.settings.option.dof_fstop') or "F-Stop",
		  type = "slider", min = 1, max = 6, step = 0.1, value = 2,
		  desc = Spring.I18N('ui.settings.option.dof_fstop_descr') or "",
		  parentId = "dof_enabled",
		  onLoad = function() return loadWidgetData("Depth of Field", "fStop", 2) end,
		  onChange = function(v)
			  saveOptionValue('Depth of Field', 'dof', 'setFstop', { 'fStop' }, v)
		  end,
		},

		-- (limitoffscreenfps_enabled + limitidlefps_enabled moved to gfx_display.lua)
	}
end
