-- Graphics > Rendering config: Lighting, Post-Processing.

return function(deps)
	local saveOptionValue = deps.saveOptionValue
	local loadWidgetData = deps.loadWidgetData
	local getWidgetToggleValue = deps.getWidgetToggleValue

	return {
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
		  type = "slider", min = 0, max = 5, step = 0.1, value = 3,
		  desc = Spring.I18N('ui.settings.option.shadowslider_descr') or "",
		  onLoad = function() return Spring.GetConfigInt("ShadowQuality", 3) end,
		  onChange = function(v)
			  Spring.SetConfigInt("ShadowQuality", math.floor(v))
			  local vsx, vsy = Spring.GetViewGeometry()
			  local quality = math.floor(v)
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
		  type = "bool", min = 0, max = 1, step = 1, value = true,
		  desc = "",
		  parentId = "lighteffects_enabled",
		  onLoad = function() return Spring.GetConfigInt("headlights", 1) == 1 end,
		  onChange = function(v) Spring.SetConfigInt("headlights", v and 1 or 0) end,
		},

		{ id = "lighteffects_buildlights", name = Spring.I18N('ui.settings.option.lighteffects_buildlights') or "Build Lights",
		  type = "bool", min = 0, max = 1, step = 1, value = true,
		  desc = "",
		  parentId = "lighteffects_enabled",
		  onLoad = function() return Spring.GetConfigInt("buildlights", 1) == 1 end,
		  onChange = function(v) Spring.SetConfigInt("buildlights", v and 1 or 0) end,
		},

		{ id = "lighteffects_brightness", name = Spring.I18N('ui.settings.option.lighteffects_brightness') or "Brightness",
		  type = "slider", min = 0.4, max = 1.5, step = 0.05, value = 1,
		  desc = "",
		  parentId = "lighteffects_enabled",
		  onLoad = function() return loadWidgetData("Deferred rendering GL4", "intensityMultiplier", 1) end,
		  onChange = function(v)
			  saveOptionValue('Deferred rendering GL4', 'lighteffects', 'IntensityMultiplier', { 'intensityMultiplier' }, v)
		  end,
		},

		{ id = "lighteffects_radius", name = Spring.I18N('ui.settings.option.lighteffects_radius') or "Radius",
		  type = "slider", min = 0.4, max = 1.2, step = 0.05, value = 1,
		  desc = "",
		  parentId = "lighteffects_enabled",
		  onLoad = function() return loadWidgetData("Deferred rendering GL4", "radiusMultiplier", 1) end,
		  onChange = function(v)
			  saveOptionValue('Deferred rendering GL4', 'lighteffects', 'RadiusMultiplier', { 'radiusMultiplier' }, v)
		  end,
		},

		{ id = "lighteffects_screenspaceshadows", name = Spring.I18N('ui.settings.option.lighteffects_screenspaceshadows') or "Screen Shadows",
		  type = "slider", min = 0, max = 4, step = 0.1, value = 2,
		  desc = "",
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
