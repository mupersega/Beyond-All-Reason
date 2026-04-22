-- Dev config: root options, Debug, Other, Map (representative subset).
--
-- This is a "get the tab in" pass; a quality pass will add the splat-tex /
-- ground ambient-diffuse-specular RGB walls and language/font selects.

return function(deps)
	local getWidgetToggleValue = deps.getWidgetToggleValue
	local restartEngine = deps.restartEngine

	-- Capture initial sun position + fog at config load so the _reset actions
	-- have a stable default to restore to. Mirrors defaultMapSunPos / defaultMapFog
	-- in the legacy widget.
	local defaultMapSunPos = { gl.GetSun("pos") }  -- { x, y, z }
	local defaultFogStart = gl.GetAtmosphere("fogStart")
	local defaultFogEnd   = gl.GetAtmosphere("fogEnd")
	local defaultFogColor = { gl.GetAtmosphere("fogColor") }  -- { r, g, b, a }

	return {
		---------------------------------------------------------------
		-- Root (no heading)
		---------------------------------------------------------------
		{ id = "heading_dev_root", name = Spring.I18N('ui.settings.group.dev') or "Developer", type = "heading" },

		{ id = "customwidgets", name = Spring.I18N('ui.settings.option.customwidgets') or "Allow Custom Widgets",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  disabled = true,
		  desc = (Spring.I18N('ui.settings.option.customwidgets_descr') or "") ..
		         "\n\nDisabled: toggling reloads luaui mid-change which destabilises the options panel.",
		  onLoad = function() return widgetHandler.allowUserWidgets == true end,
		  onChange = function(v)
			  widgetHandler.__allowUserWidgets = v
			  Spring.SendCommands("luarules reloadluaui")
		  end,
		},

		{ id = "autocheat", name = Spring.I18N('ui.settings.option.autocheat') or "Auto Cheat",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.autocheat_descr') or "",
		  onLoad = function() return getWidgetToggleValue("Dev Auto cheat") end,
		  onChange = function(v)
			  if v then widgetHandler:EnableWidget("Dev Auto cheat")
			  else widgetHandler:DisableWidget("Dev Auto cheat") end
		  end,
		},

		{ id = "restart", name = Spring.I18N('ui.settings.option.restart') or "Restart Engine",
		  type = "action", min = 0, max = 0, step = 0, value = false,
		  labelClass = "text-danger text-upper font-bold",
		  desc = Spring.I18N('ui.settings.option.restart_descr') or "",
		  onClick = function() restartEngine() end,
		},

		---------------------------------------------------------------
		-- Debug
		---------------------------------------------------------------
		{ id = "heading_debug", name = Spring.I18N('ui.settings.option.label_debug') or "Debug", type = "heading" },

		-- Central RML debug toggle. Persists to Spring config "RMLDebugControls"
		-- (the same key RML widgets already poll via utils.isRmlDebugEnabled()
		-- to show/hide their per-widget reload buttons), AND opens/closes the
		-- RmlUi debugger overlay directly. Replaces the per-widget "debug"
		-- button — those can be removed in a later cleanup pass.
		{ id = "rml_debug", name = "RML Debugger",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = "Opens the RmlUi debugger overlay and shows per-widget reload buttons across all RML widgets.",
		  onLoad = function() return Spring.GetConfigInt("RMLDebugControls", 0) == 1 end,
		  onChange = function(v)
			  Spring.SetConfigInt("RMLDebugControls", v and 1 or 0)
			  if RmlUi and RmlUi.SetDebugContext then
				  RmlUi.SetDebugContext(v and 'shared' or nil)
			  end
		  end,
		},

		{ id = "profiler_widget", name = Spring.I18N('ui.settings.option.profiler_widget') or "Widget Profiler",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = "",
		  onLoad = function() return getWidgetToggleValue("Widget Profiler") end,
		  onChange = function(v)
			  if v then widgetHandler:EnableWidget("Widget Profiler")
			  else widgetHandler:DisableWidget("Widget Profiler") end
		  end,
		},

		{ id = "profiler_gadget", name = Spring.I18N('ui.settings.option.profiler_gadget') or "Gadget Profiler",
		  type = "action", min = 0, max = 0, step = 0, value = false,
		  desc = "Toggle the gadget (luarules) profiler.",
		  onClick = function() Spring.SendCommands("luarules profile") end,
		},

		{ id = "profiler_sort_by_load", name = Spring.I18N('ui.settings.option.profiler_sort_by_load') or "Profiler: Sort By Load",
		  type = "bool", min = 0, max = 1, step = 1, value = true,
		  desc = Spring.I18N('ui.settings.option.profiler_sort_by_load_descr') or "",
		  onLoad = function() return Spring.GetConfigInt("profiler_sort_by_load", 1) == 1 end,
		  onChange = function(v) Spring.SetConfigInt("profiler_sort_by_load", v and 1 or 0) end,
		},

		{ id = "profiler_averagetime", name = Spring.I18N('ui.settings.option.profiler_averagetime') or "Profiler: Average Time",
		  type = "slider", min = 0.1, max = 10, step = 0.1, value = 2,
		  desc = Spring.I18N('ui.settings.option.profiler_averagetime_descr') or "",
		  onLoad = function() return Spring.GetConfigFloat("profiler_averagetime", 2) end,
		  onChange = function(v) Spring.SetConfigFloat("profiler_averagetime", v) end,
		},

		{ id = "framegrapher", name = Spring.I18N('ui.settings.option.framegrapher') or "Frame Grapher",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = "",
		  onLoad = function() return getWidgetToggleValue("Frame Grapher") end,
		  onChange = function(v)
			  if v then widgetHandler:EnableWidget("Frame Grapher")
			  else widgetHandler:DisableWidget("Frame Grapher") end
		  end,
		},

		{ id = "debugcolvol", name = Spring.I18N('ui.settings.option.debugcolvol') or "Debug Collision Volumes",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = "",
		  onLoad = function() return false end,  -- no persisted state; always starts off
		  onChange = function(v) Spring.SendCommands("DebugColVol " .. (v and 1 or 0)) end,
		},

		{ id = "echocamerastate", name = Spring.I18N('ui.settings.option.echocamerastate') or "Echo Camera State",
		  type = "action", min = 0, max = 0, step = 0, value = false,
		  desc = Spring.I18N('ui.settings.option.echocamerastate_descr') or "",
		  onClick = function() Spring.Echo(Spring.GetCameraState()) end,
		},

		---------------------------------------------------------------
		-- Other
		---------------------------------------------------------------
		{ id = "heading_other", name = Spring.I18N('ui.settings.option.label_other') or "Other", type = "heading" },

		{ id = "storedefaultsettings", name = Spring.I18N('ui.settings.option.storedefaultsettings') or "Store Default Settings",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.storedefaultsettings_descr') or "",
		  onLoad = function() return Spring.GetConfigInt("StoreDefaultSettings", 0) == 1 end,
		  onChange = function(v) Spring.SetConfigInt("StoreDefaultSettings", v and 1 or 0) end,
		},

		{ id = "startboxeditor", name = Spring.I18N('ui.settings.option.startboxeditor') or "Startbox Editor",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.startboxeditor_descr') or "",
		  onLoad = function() return getWidgetToggleValue("Startbox Editor") end,
		  onChange = function(v)
			  if v then widgetHandler:EnableWidget("Startbox Editor")
			  else widgetHandler:DisableWidget("Startbox Editor") end
		  end,
		},

		---------------------------------------------------------------
		-- Map
		---------------------------------------------------------------
		{ id = "heading_map", name = Spring.I18N('ui.settings.option.label_map') or "Map", type = "heading" },

		-- Sun position
		{ id = "sun_x", name = Spring.I18N('ui.settings.option.sun_x') or "Sun X",
		  type = "slider", min = -0.9999, max = 0.9999, step = 0.0001, value = 0,
		  desc = "",
		  onLoad = function() return (select(1, gl.GetSun("pos"))) or 0 end,
		  onChange = function(v)
			  local _, sy, sz = gl.GetSun("pos")
			  Spring.SetSunDirection(v, sy, sz)
			  local d = gl.GetSun("shadowDensity")
			  Spring.SetSunLighting({ groundShadowDensity = d, modelShadowDensity = d })
		  end,
		},

		{ id = "sun_y", name = Spring.I18N('ui.settings.option.sun_y') or "Sun Y",
		  type = "slider", min = 0.05, max = 0.9999, step = 0.0001, value = 0.5,
		  desc = "",
		  onLoad = function() return (select(2, gl.GetSun("pos"))) or 0.5 end,
		  onChange = function(v)
			  local sx, _, sz = gl.GetSun("pos")
			  Spring.SetSunDirection(sx, v, sz)
			  local d = gl.GetSun("shadowDensity")
			  Spring.SetSunLighting({ groundShadowDensity = d, modelShadowDensity = d })
		  end,
		},

		{ id = "sun_z", name = Spring.I18N('ui.settings.option.sun_z') or "Sun Z",
		  type = "slider", min = -0.9999, max = 0.9999, step = 0.0001, value = 0,
		  desc = "",
		  onLoad = function() return (select(3, gl.GetSun("pos"))) or 0 end,
		  onChange = function(v)
			  local sx, sy = gl.GetSun("pos")
			  Spring.SetSunDirection(sx, sy, v)
			  local d = gl.GetSun("shadowDensity")
			  Spring.SetSunLighting({ groundShadowDensity = d, modelShadowDensity = d })
		  end,
		},

		{ id = "sun_reset", name = Spring.I18N('ui.settings.option.sun_reset') or "Reset Sun Position",
		  type = "action", min = 0, max = 0, step = 0, value = false,
		  desc = "",
		  onClick = function()
			  Spring.SetSunDirection(defaultMapSunPos[1], defaultMapSunPos[2], defaultMapSunPos[3])
			  local d = gl.GetSun("shadowDensity")
			  Spring.SetSunLighting({ groundShadowDensity = d, modelShadowDensity = d })
		  end,
		},

		-- Fog start/end
		{ id = "fog_start", name = Spring.I18N('ui.settings.option.fog_start') or "Fog Start",
		  type = "slider", min = 0, max = 1.99, step = 0.01, value = 0,
		  desc = "",
		  onLoad = function() return gl.GetAtmosphere("fogStart") or 0 end,
		  onChange = function(v) Spring.SetAtmosphere({ fogStart = v }) end,
		},

		{ id = "fog_end", name = Spring.I18N('ui.settings.option.fog_end') or "Fog End",
		  type = "slider", min = 0.5, max = 2, step = 0.01, value = 1,
		  desc = "",
		  onLoad = function() return gl.GetAtmosphere("fogEnd") or 1 end,
		  onChange = function(v) Spring.SetAtmosphere({ fogEnd = v }) end,
		},

		{ id = "fog_reset", name = Spring.I18N('ui.settings.option.fog_reset') or "Reset Fog Distance",
		  type = "action", min = 0, max = 0, step = 0, value = false,
		  desc = "",
		  onClick = function()
			  Spring.SetAtmosphere({ fogStart = defaultFogStart, fogEnd = defaultFogEnd })
		  end,
		},

		-- Fog color RGB
		{ id = "fog_r", name = Spring.I18N('ui.settings.option.red') or "Fog Red",
		  type = "slider", min = 0, max = 1, step = 0.01, value = 0.5,
		  desc = "",
		  onLoad = function() return (select(1, gl.GetAtmosphere("fogColor"))) or 0.5 end,
		  onChange = function(v)
			  local _, g, b, a = gl.GetAtmosphere("fogColor")
			  Spring.SetAtmosphere({ fogColor = { v, g, b, a } })
		  end,
		},

		{ id = "fog_g", name = Spring.I18N('ui.settings.option.green') or "Fog Green",
		  type = "slider", min = 0, max = 1, step = 0.01, value = 0.5,
		  desc = "",
		  onLoad = function() return (select(2, gl.GetAtmosphere("fogColor"))) or 0.5 end,
		  onChange = function(v)
			  local r, _, b, a = gl.GetAtmosphere("fogColor")
			  Spring.SetAtmosphere({ fogColor = { r, v, b, a } })
		  end,
		},

		{ id = "fog_b", name = Spring.I18N('ui.settings.option.blue') or "Fog Blue",
		  type = "slider", min = 0, max = 1, step = 0.01, value = 0.5,
		  desc = "",
		  onLoad = function() return (select(3, gl.GetAtmosphere("fogColor"))) or 0.5 end,
		  onChange = function(v)
			  local r, g, _, a = gl.GetAtmosphere("fogColor")
			  Spring.SetAtmosphere({ fogColor = { r, g, v, a } })
		  end,
		},

		{ id = "fog_color_reset", name = Spring.I18N('ui.settings.option.fog_color_reset') or "Reset Fog Color",
		  type = "action", min = 0, max = 0, step = 0, value = false,
		  desc = "",
		  onClick = function()
			  Spring.SetAtmosphere({ fogColor = defaultFogColor })
		  end,
		},

		-- Void rendering
		{ id = "map_voidwater", name = Spring.I18N('ui.settings.option.map_voidwater') or "Void Water",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = "",
		  onLoad = function() return gl.GetMapRendering("voidWater") == true end,
		  onChange = function(v) Spring.SetMapRenderingParams({ voidWater = v }) end,
		},

		{ id = "map_voidground", name = Spring.I18N('ui.settings.option.map_voidground') or "Void Ground",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = "",
		  onLoad = function() return gl.GetMapRendering("voidGround") == true end,
		  onChange = function(v) Spring.SetMapRenderingParams({ voidGround = v }) end,
		},

		-- Shadow densities
		{ id = "GroundShadowDensity", name = Spring.I18N('ui.settings.option.GroundShadowDensity') or "Ground Shadow Density",
		  type = "slider", min = 0, max = 1.5, step = 0.001, value = 1,
		  desc = "",
		  onLoad = function() return gl.GetSun("shadowDensity", "ground") or 1 end,
		  onChange = function(v)
			  Spring.SetSunLighting({ groundShadowDensity = v })
			  Spring.SendCommands("luarules updatesun")
		  end,
		},

		{ id = "UnitShadowDensity", name = Spring.I18N('ui.settings.option.UnitShadowDensity') or "Unit Shadow Density",
		  type = "slider", min = 0, max = 1.5, step = 0.001, value = 1,
		  desc = "",
		  onLoad = function() return gl.GetSun("shadowDensity", "unit") or 1 end,
		  onChange = function(v)
			  Spring.SetSunLighting({ modelShadowDensity = v })
			  Spring.SendCommands("luarules updatesun")
		  end,
		},
	}
end
