-- Graphics tab config: Display, Lighting, Environment, Effects, Post-Processing sections.
-- Returns a builder function — call with deps table from the widget.

return function(deps)
	local saveOptionValue = deps.saveOptionValue
	local loadWidgetData = deps.loadWidgetData
	local getWidgetToggleValue = deps.getWidgetToggleValue

	return {
		---------------------------------------------------------------
		-- Display
		---------------------------------------------------------------
		{ id = "heading_screen", name = Spring.I18N('ui.settings.option.label_screen') or "Display", type = "heading" },

		{ id = "vsync", name = Spring.I18N('ui.settings.option.vsync') or "VSync",
		  type = "select", min = 0, max = 0, step = 0, value = "off",
		  desc = Spring.I18N('ui.settings.option.vsync_descr') or "",
		  selectOptions = {
			  { value = "off", label = "Off" },
			  { value = "enabled", label = "Enabled" },
			  { value = "adaptive", label = "Adaptive" },
		  },
		  onLoad = function()
			  local v = Spring.GetConfigInt("VSyncGame", -1)
			  if v == -1 then return "adaptive"
			  elseif v == 0 then return "off"
			  else return "enabled" end
		  end,
		  onChange = function(v)
			  local vsync
			  if v == "adaptive" then vsync = -1
			  elseif v == "off" then vsync = 0
			  else vsync = 1 end
			  Spring.SetConfigInt("VSync", vsync)
			  Spring.SetConfigInt("VSyncGame", vsync)
		  end,
		},

		{ id = "vsync_fraction", name = Spring.I18N('ui.settings.option.vsync_fraction') or "VSync Fraction",
		  type = "slider", min = 1, max = 4, step = 1, value = 1,
		  desc = Spring.I18N('ui.settings.option.vsync_fraction_descr') or "",
		  parentId = "vsync",
		  onLoad = function() return Spring.GetConfigInt("VSyncFraction", 1) end,
		  onChange = function(v)
			  Spring.SetConfigInt("VSyncFraction", math.floor(v))
		  end,
		},

		{ id = "limitoffscreenfps", name = Spring.I18N('ui.settings.option.limitoffscreenfps') or "Limit Offscreen FPS",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.limitoffscreenfps_descr') or "",
		  onLoad = function() return getWidgetToggleValue("Limit idle FPS") end,
		  onChange = function(v)
			  if v then widgetHandler:EnableWidget("Limit idle FPS")
			  else widgetHandler:DisableWidget("Limit idle FPS") end
		  end,
		},

		{ id = "limitidlefps", name = Spring.I18N('ui.settings.option.limitidlefps') or "Limit Idle FPS",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.limitidlefps_descr') or "",
		  parentId = "limitoffscreenfps",
		  onLoad = function() return Spring.GetConfigInt("LimitIdleFps", 0) == 1 end,
		  onChange = function(v)
			  Spring.SetConfigInt("LimitIdleFps", v and 1 or 0)
		  end,
		},

		{ id = "cas_sharpness", name = Spring.I18N('ui.settings.option.cas_sharpness') or "CAS Sharpness",
		  type = "slider", min = 0.5, max = 1.1, step = 0.01, value = 0.8,
		  desc = Spring.I18N('ui.settings.option.cas_sharpness_descr') or "",
		  onLoad = function() return loadWidgetData("Contrast Adaptive Sharpen", "SHARPNESS", 0.8) end,
		  onChange = function(v)
			  saveOptionValue('Contrast Adaptive Sharpen', 'cas_sharpness', 'SetSharpness', { 'SHARPNESS' }, v)
		  end,
		},

		{ id = "msaa", name = Spring.I18N('ui.settings.option.msaa') or "Anti-Aliasing",
		  type = "select", min = 0, max = 0, step = 0, value = "off",
		  desc = Spring.I18N('ui.settings.option.msaa_descr') or "",
		  selectOptions = {
			{ value = "off", label = "Off" },
			{ value = "2",   label = "x2" },
			{ value = "4",   label = "x4" },
			{ value = "8",   label = "x8" },
		  },
		  onLoad = function()
			  local level = Spring.GetConfigInt("MSAALevel", 0)
			  if level <= 0 then return "off"
			  elseif level <= 2 then return "2"
			  elseif level <= 4 then return "4"
			  else return "8" end
		  end,
		  onChange = function(v)
			  local level = v == "off" and 0 or tonumber(v) or 0
			  Spring.SetConfigInt("MSAALevel", level)
		  end,
		},

		---------------------------------------------------------------
		-- Lighting
		---------------------------------------------------------------
		{ id = "heading_lighting", name = Spring.I18N('ui.settings.option.label_lighting') or "Lighting", type = "heading" },

		{ id = "cusgl4_enabled", name = Spring.I18N('ui.settings.option.cus') or "Custom Unit Shaders",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.cus_descr') or "",
		  onLoad = function() return Spring.GetConfigInt("cus2", 1) == 1 end,
		  onChange = function(v)
			  Spring.SetConfigInt("cus2", v and 1 or 0)
			  Spring.SendCommands(v and "luarules reloadcusgl4" or "luarules disablecusgl4")
		  end,
		},

		{ id = "shadowslider", name = Spring.I18N('ui.settings.option.shadowslider') or "Shadows",
		  type = "select", min = 0, max = 0, step = 0, value = "3",
		  desc = Spring.I18N('ui.settings.option.shadowslider_descr') or "",
		  selectOptions = {
			{ value = "0", label = Spring.I18N('ui.settings.option.select_off') or "Off" },
			{ value = "1", label = Spring.I18N('ui.settings.option.select_lowest') or "Lowest" },
			{ value = "2", label = Spring.I18N('ui.settings.option.select_low') or "Low" },
			{ value = "3", label = Spring.I18N('ui.settings.option.select_medium') or "Medium" },
			{ value = "4", label = Spring.I18N('ui.settings.option.select_high') or "High" },
			{ value = "5", label = Spring.I18N('ui.settings.option.select_ultra') or "Ultra" },
		  },
		  onLoad = function() return tostring(Spring.GetConfigInt("ShadowQuality", 3)) end,
		  onChange = function(v)
			  local quality = tonumber(v) or 3
			  Spring.SetConfigInt("ShadowQuality", quality)
			  local vsx, vsy = Spring.GetViewGeometry()
			  local shadowMapSize = 600 + math.min(10240, (vsy + vsx) * 0.37) * (quality * 0.5)
			  Spring.SetConfigInt("Shadows", quality == 0 and 0 or 1)
			  Spring.SetConfigInt("ShadowMapSize", shadowMapSize)
			  Spring.SendCommands("shadows " .. (quality == 0 and 0 or 1) .. " " .. shadowMapSize)
		  end,
		},

		{ id = "shadows_opacity", name = Spring.I18N('ui.settings.option.shadows_opacity') or "Shadow Opacity",
		  type = "slider", min = 0.3, max = 1, step = 0.01, value = 0.5,
		  desc = "",
		  parentId = "shadowslider",
		  onLoad = function() return gl.GetSun("shadowDensity") or 0.5 end,
		  onChange = function(v)
			  Spring.SetSunLighting({ groundShadowDensity = v, modelShadowDensity = v })
		  end,
		},

		{ id = "ssao_enabled", name = Spring.I18N('ui.settings.option.ssao') or "SSAO",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.ssao_descr') or "",
		  onLoad = function() return getWidgetToggleValue("SSAO") end,
		  onChange = function(v)
			  if v then widgetHandler:EnableWidget("SSAO")
			  else widgetHandler:DisableWidget("SSAO") end
		  end,
		},

		{ id = "ssao_strength", name = Spring.I18N('ui.settings.option.ssao_strength') or "Strength",
		  type = "slider", min = 5, max = 11, step = 0.1, value = 8,
		  desc = "",
		  parentId = "ssao_enabled",
		  onLoad = function() return loadWidgetData("SSAO", "strength", 8) end,
		  onChange = function(v)
			  saveOptionValue('SSAO', 'ssao', 'setStrength', { 'strength' }, v)
		  end,
		},

		{ id = "ssao_quality", name = Spring.I18N('ui.settings.option.ssao_quality') or "Quality",
		  type = "select", min = 0, max = 0, step = 0, value = "2",
		  desc = Spring.I18N('ui.settings.option.ssao_quality_descr') or "",
		  parentId = "ssao_enabled",
		  selectOptions = {
			{ value = "1", label = Spring.I18N('ui.settings.option.select_low') or "Low" },
			{ value = "2", label = Spring.I18N('ui.settings.option.select_medium') or "Medium" },
			{ value = "3", label = Spring.I18N('ui.settings.option.select_high') or "High" },
		  },
		  onLoad = function()
			  return tostring(loadWidgetData("SSAO", "preset", 2))
		  end,
		  onChange = function(v)
			  saveOptionValue('SSAO', 'ssao', 'setPreset', { 'preset' }, tonumber(v) or 2)
		  end,
		},

		{ id = "bloomdeferred_enabled", name = Spring.I18N('ui.settings.option.bloomdeferred') or "Bloom",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.bloomdeferred_descr') or "",
		  onLoad = function() return getWidgetToggleValue("Bloom Shader Deferred") end,
		  onChange = function(v)
			  if v then widgetHandler:EnableWidget("Bloom Shader Deferred")
			  else widgetHandler:DisableWidget("Bloom Shader Deferred") end
		  end,
		},

		{ id = "bloomdeferredbrightness", name = Spring.I18N('ui.settings.option.bloomdeferredbrightness') or "Brightness",
		  type = "slider", min = 0.4, max = 1.4, step = 0.05, value = 0.9,
		  desc = "",
		  parentId = "bloomdeferred_enabled",
		  onLoad = function() return loadWidgetData("Bloom Shader Deferred", "glowAmplifier", 0.9) end,
		  onChange = function(v)
			  saveOptionValue('Bloom Shader Deferred', 'bloomdeferred', 'setBrightness', { 'glowAmplifier' }, v)
		  end,
		},

		{ id = "bloomdeferred_quality", name = Spring.I18N('ui.settings.option.bloomdeferred_quality') or "Quality",
		  type = "select", min = 0, max = 0, step = 0, value = "2",
		  desc = Spring.I18N('ui.settings.option.bloomdeferred_quality_descr') or "",
		  parentId = "bloomdeferred_enabled",
		  selectOptions = {
			{ value = "1", label = Spring.I18N('ui.settings.option.select_low') or "Low" },
			{ value = "2", label = Spring.I18N('ui.settings.option.select_medium') or "Medium" },
			{ value = "3", label = Spring.I18N('ui.settings.option.select_high') or "High" },
		  },
		  onLoad = function()
			  return tostring(loadWidgetData("Bloom Shader Deferred", "preset", 2))
		  end,
		  onChange = function(v)
			  saveOptionValue('Bloom Shader Deferred', 'bloomdeferred', 'setPreset', { 'preset' }, tonumber(v) or 2)
		  end,
		},

		{ id = "lighteffects_enabled", name = Spring.I18N('ui.settings.option.lighteffects') or "Light Effects",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.lighteffects_descr') or "",
		  onLoad = function() return getWidgetToggleValue("Deferred rendering GL4") end,
		  onChange = function(v)
			  if v then widgetHandler:EnableWidget("Deferred rendering GL4")
			  else widgetHandler:DisableWidget("Deferred rendering GL4") end
		  end,
		},

		{ id = "lighteffects_headlights", name = Spring.I18N('ui.settings.option.lighteffects_headlights') or "Headlights",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.lighteffects_headlights_descr') or "",
		  parentId = "lighteffects_enabled",
		  onLoad = function() return Spring.GetConfigInt("headlights", 1) == 1 end,
		  onChange = function(v)
			  Spring.SetConfigInt("headlights", v and 1 or 0)
		  end,
		},

		{ id = "lighteffects_buildlights", name = Spring.I18N('ui.settings.option.lighteffects_buildlights') or "Build Lights",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.lighteffects_buildlights_descr') or "",
		  parentId = "lighteffects_enabled",
		  onLoad = function() return Spring.GetConfigInt("buildlights", 1) == 1 end,
		  onChange = function(v)
			  Spring.SetConfigInt("buildlights", v and 1 or 0)
		  end,
		},

		{ id = "lighteffects_brightness", name = Spring.I18N('ui.settings.option.lighteffects_brightness') or "Brightness",
		  type = "slider", min = 0.4, max = 1.5, step = 0.05, value = 1,
		  desc = Spring.I18N('ui.settings.option.lighteffects_brightness_descr') or "",
		  parentId = "lighteffects_enabled",
		  onLoad = function() return loadWidgetData("Deferred rendering GL4", "intensityMultiplier", 1) end,
		  onChange = function(v)
			  saveOptionValue('Deferred rendering GL4', 'lighteffects', 'IntensityMultiplier', { 'intensityMultiplier' }, v)
		  end,
		},

		{ id = "lighteffects_radius", name = Spring.I18N('ui.settings.option.lighteffects_radius') or "Radius",
		  type = "slider", min = 0.4, max = 1.2, step = 0.05, value = 1,
		  desc = Spring.I18N('ui.settings.option.lighteffects_radius_descr') or "",
		  parentId = "lighteffects_enabled",
		  onLoad = function() return loadWidgetData("Deferred rendering GL4", "radiusMultiplier", 1) end,
		  onChange = function(v)
			  saveOptionValue('Deferred rendering GL4', 'lighteffects', 'RadiusMultiplier', { 'radiusMultiplier' }, v)
		  end,
		},

		{ id = "lighteffects_screenspaceshadows", name = Spring.I18N('ui.settings.option.lighteffects_screenspaceshadows') or "Screen Shadows",
		  type = "slider", min = 0, max = 4, step = 1, value = 2,
		  desc = Spring.I18N('ui.settings.option.lighteffects_screenspaceshadows_descr') or "",
		  parentId = "lighteffects_enabled",
		  onLoad = function() return loadWidgetData("Deferred rendering GL4", "screenSpaceShadows", 2) end,
		  onChange = function(v)
			  saveOptionValue('Deferred rendering GL4', 'lighteffects', 'ScreenSpaceShadows', { 'screenSpaceShadows' }, v)
		  end,
		},

		{ id = "distortioneffects_enabled", name = Spring.I18N('ui.settings.option.distortioneffects') or "Distortion",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.distortioneffects_descr') or "",
		  onLoad = function() return getWidgetToggleValue("Distortion GL4") end,
		  onChange = function(v)
			  if v then widgetHandler:EnableWidget("Distortion GL4")
			  else widgetHandler:DisableWidget("Distortion GL4") end
		  end,
		},

		{ id = "darkenmap", name = Spring.I18N('ui.settings.option.darkenmap') or "Darken Map",
		  type = "slider", min = 0, max = 0.33, step = 0.01, value = 0,
		  desc = Spring.I18N('ui.settings.option.darkenmap_descr') or "",
		  onLoad = function() return loadWidgetData("Darken map", "darknessvalue", 0) end,
		  onChange = function(v)
			  saveOptionValue('Darken map', 'darkenmap', 'setMapDarkness', { 'darknessvalue' }, v)
		  end,
		},

		---------------------------------------------------------------
		-- Environment
		---------------------------------------------------------------
		{ id = "heading_environment", name = Spring.I18N('ui.settings.option.label_environment') or "Environment", type = "heading" },

		{ id = "featuredrawdist", name = Spring.I18N('ui.settings.option.featuredrawdist') or "Feature Draw Distance",
		  type = "slider", min = 2500, max = 40000, step = 500, value = 10000,
		  desc = Spring.I18N('ui.settings.option.featuredrawdist_descr') or "",
		  onLoad = function() return Spring.GetConfigInt("FeatureDrawDistance", 10000) end,
		  onChange = function(v)
			  Spring.SetConfigInt("FeatureFadeDistance", math.floor(v * 0.8))
			  Spring.SetConfigInt("FeatureDrawDistance", math.floor(v))
		  end,
		},

		{ id = "losopacity", name = Spring.I18N('ui.settings.option.losopacity') or "LOS Opacity",
		  type = "slider", min = 0.01, max = 1, step = 0.01, value = 0.5,
		  desc = "",
		  onLoad = function() return loadWidgetData("LOS colors", "opacity", 0.5) end,
		  onChange = function(v)
			  saveOptionValue('LOS colors', 'loscolors', 'setOpacity', { 'opacity' }, v)
		  end,
		},

		{ id = "water", name = Spring.I18N('ui.settings.option.water') or "Water Quality",
		  type = "select", min = 0, max = 0, step = 0, value = "high",
		  desc = "",
		  selectOptions = {
			  { value = "low", label = "Low" },
			  { value = "high", label = "High" },
		  },
		  onLoad = function()
			  return Spring.GetConfigInt("Water", 4) >= 4 and "high" or "low"
		  end,
		  onChange = function(v)
			  local waterLevel = (v == "high") and 4 or 0
			  Spring.SetConfigInt("Water", waterLevel)
			  Spring.SendCommands("water " .. waterLevel)
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
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.mapedgeextension_curvature_descr') or "",
		  parentId = "mapedgeextension_enabled",
		  onLoad = function() return loadWidgetData("Map Edge Extension", "curvature", true) end,
		  onChange = function(v)
			  saveOptionValue('Map Edge Extension', 'mapedgeextension', 'setCurvature', { 'curvature' }, v)
		  end,
		},

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
		  type = "slider", min = 0, max = 3, step = 1, value = 0,
		  desc = Spring.I18N('ui.settings.option.decals_descr') or "",
		  onLoad = function() return Spring.GetConfigInt("GroundDecals", 0) end,
		  onChange = function(v)
			  Spring.SetConfigInt("GroundDecals", math.floor(v))
			  Spring.SendCommands("GroundDecals " .. math.floor(v))
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

		{ id = "treewind_enabled", name = Spring.I18N('ui.settings.option.treewind') or "Tree Wind",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.treewind_descr') or "",
		  onLoad = function() return Spring.GetConfigInt("TreeWind", 1) == 1 end,
		  onChange = function(v)
			  Spring.SendCommands("luarules treewind " .. (v and 1 or 0))
			  Spring.SetConfigInt("TreeWind", v and 1 or 0)
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

		{ id = "snowmap_enabled", name = Spring.I18N('ui.settings.option.snowmap') or "Snow on Map",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.snowmap_descr') or "",
		  parentId = "snow_enabled",
		  onLoad = function() return loadWidgetData("Snow", "snowMap", true) end,
		  onChange = function(v)
			  saveOptionValue('Snow', 'snow', 'setSnowMap', { 'snowMap' }, v)
		  end,
		},

		{ id = "snowautoreduce_enabled", name = Spring.I18N('ui.settings.option.snowautoreduce') or "Auto Reduce",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.snowautoreduce_descr') or "",
		  parentId = "snow_enabled",
		  onLoad = function() return loadWidgetData("Snow", "autoReduce", true) end,
		  onChange = function(v)
			  saveOptionValue('Snow', 'snow', 'setAutoReduce', { 'autoReduce' }, v)
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
		  onChange = function(v)
			  Spring.SetConfigFloat("FogMult", v)
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
			  Spring.SetConfigInt("MaxParticles", math.floor(v))
			  Spring.SetConfigInt("MaxNanoParticles", math.floor(v * 0.34))
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
		  type = "bool", min = 0, max = 1, step = 1, value = false,
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

		---------------------------------------------------------------
		-- Post-Processing
		---------------------------------------------------------------
		{ id = "heading_postprocessing", name = Spring.I18N('ui.settings.option.label_postprocessing') or "Post-Processing", type = "heading" },

		{ id = "sepiatone_enabled", name = Spring.I18N('ui.settings.option.sepiatone') or "Sepia Tone",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = "",
		  onLoad = function() return getWidgetToggleValue("Sepia Tone") end,
		  onChange = function(v)
			  if v then widgetHandler:EnableWidget("Sepia Tone")
			  else widgetHandler:DisableWidget("Sepia Tone") end
		  end,
		},

		{ id = "sepiatone_gamma", name = Spring.I18N('ui.settings.option.sepiatone_gamma') or "Gamma",
		  type = "slider", min = 0.1, max = 0.9, step = 0.02, value = 0.5,
		  desc = "",
		  parentId = "sepiatone_enabled",
		  onLoad = function() return loadWidgetData("Sepia Tone", "gamma", 0.5) end,
		  onChange = function(v)
			  saveOptionValue('Sepia Tone', 'sepiatone', 'setGamma', { 'gamma' }, v)
		  end,
		},

		{ id = "sepiatone_saturation", name = Spring.I18N('ui.settings.option.sepiatone_saturation') or "Saturation",
		  type = "slider", min = 0, max = 1, step = 0.02, value = 0.5,
		  desc = "",
		  parentId = "sepiatone_enabled",
		  onLoad = function() return loadWidgetData("Sepia Tone", "saturation", 0.5) end,
		  onChange = function(v)
			  saveOptionValue('Sepia Tone', 'sepiatone', 'setSaturation', { 'saturation' }, v)
		  end,
		},

		{ id = "sepiatone_contrast", name = Spring.I18N('ui.settings.option.sepiatone_contrast') or "Contrast",
		  type = "slider", min = 0.1, max = 0.9, step = 0.02, value = 0.5,
		  desc = "",
		  parentId = "sepiatone_enabled",
		  onLoad = function() return loadWidgetData("Sepia Tone", "contrast", 0.5) end,
		  onChange = function(v)
			  saveOptionValue('Sepia Tone', 'sepiatone', 'setContrast', { 'contrast' }, v)
		  end,
		},

		{ id = "sepiatone_sepia", name = Spring.I18N('ui.settings.option.sepiatone_sepia') or "Sepia",
		  type = "slider", min = 0, max = 0.5, step = 0.02, value = 0.5,
		  desc = Spring.I18N('ui.settings.option.sepiatone_sepia_descr') or "",
		  parentId = "sepiatone_enabled",
		  onLoad = function() return loadWidgetData("Sepia Tone", "sepia", 0.5) end,
		  onChange = function(v)
			  saveOptionValue('Sepia Tone', 'sepiatone', 'setSepia', { 'sepia' }, v)
		  end,
		},

		{ id = "sepiatone_shadeui", name = Spring.I18N('ui.settings.option.sepiatone_shadeui') or "Shade UI",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = "",
		  parentId = "sepiatone_enabled",
		  onLoad = function() return loadWidgetData("Sepia Tone", "shadeUI", false) end,
		  onChange = function(v)
			  saveOptionValue('Sepia Tone', 'sepiatone', 'setShadeUI', { 'shadeUI' }, v)
		  end,
		},
	}
end
