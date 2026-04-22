-- Graphics > Display config: Preset, Display, Anti-Aliasing.
--
-- Note: the `display` and `resolution` select entries have dynamically populated
-- selectOptions (built from WG.screenMode at runtime). Because cmd_resolution_switcher
-- loads AFTER this widget, the gui_options_rml widget defers entry value loading +
-- section building until the first Update() call, by which time WG.screenMode exists.
-- Until that deferred population, both entries start with an empty selectOptions list.

return function(deps)
	local saveOptionValue = deps.saveOptionValue
	local loadWidgetData = deps.loadWidgetData
	local getWidgetToggleValue = deps.getWidgetToggleValue

	-- Graphics preset (persisted as string name, not applied to other options yet —
	-- the legacy widget has a big table of preset→option values; porting that is a
	-- later pass. For now this just stores the user's selected preset label.)
	local presetOptions = {
		{ value = "lowest", label = Spring.I18N('ui.settings.option.select_lowest') or "Lowest" },
		{ value = "low",    label = Spring.I18N('ui.settings.option.select_low')    or "Low" },
		{ value = "medium", label = Spring.I18N('ui.settings.option.select_medium') or "Medium" },
		{ value = "high",   label = Spring.I18N('ui.settings.option.select_high')   or "High" },
		{ value = "ultra",  label = Spring.I18N('ui.settings.option.select_ultra')  or "Ultra" },
		{ value = "custom", label = Spring.I18N('ui.settings.option.select_custom') or "Custom" },
	}

	-- VSync (Off / Enabled / Adaptive). Stored in VSyncGame config:
	--   0  = off
	--   >0 = enabled (value = VSyncFraction)
	--   <0 = adaptive (value = -VSyncFraction)
	local vsyncOptions = {
		{ value = 0, label = Spring.I18N('ui.settings.option.select_off')      or "Off" },
		{ value = 1, label = Spring.I18N('ui.settings.option.select_enabled')  or "Enabled" },
		{ value = 2, label = Spring.I18N('ui.settings.option.select_adaptive') or "Adaptive" },
	}

	-- MSAA level (Off / x2 / x4 / x8). Stored in MSAALevel config (-1 = off).
	local msaaOptions = {
		{ value = 0, label = Spring.I18N('ui.settings.option.select_off') or "Off" },
		{ value = 2, label = "x2" },
		{ value = 4, label = "x4" },
		{ value = 8, label = "x8" },
	}

	return {
		-- Graphics preset (standalone, no heading — sits at top of the sub-tab)
		{ id = "heading_preset", name = Spring.I18N('ui.settings.option.preset') or "Graphics Preset", type = "heading" },

		{ id = "preset", name = Spring.I18N('ui.settings.option.preset') or "Graphics Preset",
		  type = "select", min = 0, max = 0, step = 0, value = "custom",
		  desc = Spring.I18N('ui.settings.option.preset_descr') or "",
		  selectOptions = presetOptions,
		  onLoad = function() return Spring.GetConfigString("graphicsPreset", "custom") end,
		  onChange = function(v) Spring.SetConfigString("graphicsPreset", v) end,
		},

		---------------------------------------------------------------
		-- Display
		---------------------------------------------------------------
		{ id = "heading_screen", name = Spring.I18N('ui.settings.option.label_screen') or "Display", type = "heading" },

		-- Monitor select — selectOptions populated at first Update() by the widget,
		-- after cmd_resolution_switcher has loaded and exposed WG.screenMode.
		{ id = "display", name = Spring.I18N('ui.settings.option.display') or "Monitor",
		  type = "select", min = 0, max = 0, step = 0, value = 1,
		  desc = "",
		  selectOptions = {},  -- populated dynamically
		  onLoad = function() return Spring.GetConfigInt("SelectedDisplay", 1) end,
		  onChange = function(v)
			  Spring.SetConfigInt("SelectedDisplay", v)
		  end,
		},

		-- Resolution select — selectOptions populated at first Update() by the widget.
		{ id = "resolution", name = Spring.I18N('ui.settings.option.resolution') or "Resolution",
		  type = "select", min = 0, max = 0, step = 0, value = 1,
		  desc = Spring.I18N('ui.settings.option.resolution_descr') or "",
		  selectOptions = {},  -- populated dynamically
		  onLoad = function() return Spring.GetConfigInt("SelectedScreenMode", 1) end,
		  onChange = function(v)
			  Spring.SetConfigInt("SelectedScreenMode", v)
			  if WG['screenMode'] and WG['screenMode'].SetScreenMode then
				  WG['screenMode'].SetScreenMode(v)
			  end
		  end,
		},

		{ id = "vsync", name = Spring.I18N('ui.settings.option.vsync') or "VSync",
		  type = "select", min = 0, max = 0, step = 0, value = 2,
		  desc = Spring.I18N('ui.settings.option.vsync_descr') or "",
		  selectOptions = vsyncOptions,
		  onLoad = function()
			  local v = Spring.GetConfigInt("VSyncGame", -1)
			  if v > 0 then return 1       -- Enabled
			  elseif v < 0 then return 2   -- Adaptive
			  else return 0 end            -- Off
		  end,
		  onChange = function(v)
			  local fraction = Spring.GetConfigInt("VSyncFraction", 1)
			  local vsync = 0
			  if v == 1 then vsync = fraction
			  elseif v == 2 then vsync = -fraction end
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
			  local iv = math.floor(v)
			  Spring.SetConfigInt("VSyncFraction", iv)
			  local vsync = Spring.GetConfigInt("VSyncGame", -1)
			  if vsync ~= 0 then
				  Spring.SetConfigInt("VSync", (vsync > 0 and iv or -iv))
				  Spring.SetConfigInt("VSyncGame", (vsync > 0 and iv or -iv))
			  end
		  end,
		},

		-- Performance: Limit Offscreen FPS (parent toggle)
		{ id = "limitoffscreenfps_enabled", name = Spring.I18N('ui.settings.option.limitoffscreenfps') or "Limit Offscreen FPS",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.limitoffscreenfps_descr') or "",
		  onLoad = function() return getWidgetToggleValue("Limit idle FPS") end,
		  onChange = function(v)
			  if v then widgetHandler:EnableWidget("Limit idle FPS")
			  else widgetHandler:DisableWidget("Limit idle FPS") end
		  end,
		},

		{ id = "limitidlefps_enabled", name = Spring.I18N('ui.settings.option.limitidlefps') or "Limit Idle FPS",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.limitidlefps_descr') or "",
		  parentId = "limitoffscreenfps_enabled",
		  onLoad = function() return Spring.GetConfigInt("LimitIdleFps", 0) == 1 end,
		  onChange = function(v) Spring.SetConfigInt("LimitIdleFps", v and 1 or 0) end,
		},

		---------------------------------------------------------------
		-- Anti-Aliasing
		---------------------------------------------------------------
		{ id = "heading_antialiasing", name = Spring.I18N('ui.settings.option.msaa') or "Anti-Aliasing", type = "heading" },

		{ id = "msaa", name = Spring.I18N('ui.settings.option.msaa') or "MSAA",
		  type = "select", min = 0, max = 0, step = 0, value = 0,
		  desc = Spring.I18N('ui.settings.option.msaa_descr') or "",
		  selectOptions = msaaOptions,
		  onLoad = function()
			  local level = Spring.GetConfigInt("MSAALevel", 0)
			  if level <= 0 then return 0 end
			  return level
		  end,
		  onChange = function(v)
			  if v == 0 then
				  Spring.SetConfigInt("MSAA", 0)
				  Spring.SetConfigInt("MSAALevel", -1)  -- -1 means off; 0 resets to default
			  else
				  Spring.SetConfigInt("MSAA", 1)
				  Spring.SetConfigInt("MSAALevel", v)
			  end
		  end,
		},

		{ id = "cas_sharpness", name = Spring.I18N('ui.settings.option.cas_sharpness') or "CAS Sharpness",
		  type = "slider", min = 0.5, max = 1.1, step = 0.01, value = 0.8,
		  desc = Spring.I18N('ui.settings.option.cas_sharpness_descr') or "",
		  onLoad = function() return loadWidgetData("Contrast Adaptive Sharpen", { 'SHARPNESS' }, 0.8) end,
		  onChange = function(v)
			  -- Also enable the widget if it isn't already — matches legacy behavior.
			  if not getWidgetToggleValue("Contrast Adaptive Sharpen") then
				  widgetHandler:EnableWidget("Contrast Adaptive Sharpen")
			  end
			  saveOptionValue('Contrast Adaptive Sharpen', 'cas_sharpness', 'SetSharpness', { 'SHARPNESS' }, v)
		  end,
		},
	}
end
