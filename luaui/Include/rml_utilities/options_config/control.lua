-- Control config: Hotkeys, Cursor, Camera, Commands.

local keyLayouts = VFS.Include("luaui/configs/keyboard_layouts.lua")

return function(deps)
	local saveOptionValue = deps.saveOptionValue
	local loadWidgetData = deps.loadWidgetData
	local getWidgetToggleValue = deps.getWidgetToggleValue

	-- Keyboard layout select options (values are layout names: 'qwerty', 'qwertz', ...)
	local keyLayoutOptions = {}
	for _, layout in ipairs(keyLayouts.layouts) do
		keyLayoutOptions[#keyLayoutOptions + 1] = { value = layout, label = layout }
	end

	-- Keybinding preset select options (values are preset names: 'Grid', 'Legacy', ...)
	local keybindingOptions = {}
	for _, preset in ipairs(keyLayouts.keybindingLayouts) do
		keybindingOptions[#keybindingOptions + 1] = { value = preset, label = preset }
	end

	-- Camera mode select options (CamMode config is 0..4, UI value is 1..5)
	local cameraModeOptions = {
		{ value = 1, label = Spring.I18N('ui.settings.option.select_firstperson') or "First Person" },
		{ value = 2, label = Spring.I18N('ui.settings.option.select_overhead') or "Overhead" },
		{ value = 3, label = Spring.I18N('ui.settings.option.select_springcam') or "Spring" },
		{ value = 4, label = Spring.I18N('ui.settings.option.select_rotoverhead') or "Rotatable Overhead" },
		{ value = 5, label = Spring.I18N('ui.settings.option.select_free') or "Free" },
	}

	-- Spring cam height mode options (CamSpringTrackMapHeightMode is 0..2, UI value is 1..3)
	local springCamHeightOptions = {
		{ value = 1, label = Spring.I18N('ui.settings.option.select_constant') or "Constant" },
		{ value = 2, label = Spring.I18N('ui.settings.option.select_terrain') or "Terrain" },
		{ value = 3, label = Spring.I18N('ui.settings.option.select_smooth') or "Smooth" },
	}

	-- Smoothing mode options (CamTransitionMode is 0..1, UI value is 1..2)
	local smoothingModeOptions = {
		{ value = 1, label = Spring.I18N('ui.settings.option.smoothing_exponential') or "Exponential" },
		{ value = 2, label = Spring.I18N('ui.settings.option.smoothing_spring') or "Spring" },
	}

	return {
		---------------------------------------------------------------
		-- Hotkeys
		---------------------------------------------------------------
		{ id = "heading_hotkeys", name = Spring.I18N('ui.settings.option.label_hotkeys') or "Hotkeys", type = "heading" },

		{ id = "keylayout", name = Spring.I18N('ui.settings.option.keylayout') or "Keyboard Layout",
		  type = "select", min = 0, max = 0, step = 0, value = "qwerty",
		  desc = Spring.I18N('ui.settings.option.keylayout_descr') or "",
		  selectOptions = keyLayoutOptions,
		  onLoad = function()
			  local keyLayout = Spring.GetConfigString("KeyboardLayout", "")
			  if not keyLayout or keyLayout == "" then
				  keyLayout = keyLayouts.layouts[1]
				  Spring.SetConfigString("KeyboardLayout", keyLayout)
			  end
			  return keyLayout
		  end,
		  onChange = function(v)
			  Spring.SetConfigString("KeyboardLayout", v)
			  if WG['bar_hotkeys'] and WG['bar_hotkeys'].reloadBindings then
				  WG['bar_hotkeys'].reloadBindings()
			  end
		  end,
		},

		{ id = "keybindings", name = Spring.I18N('ui.settings.option.keybindings') or "Keybindings",
		  type = "select", min = 0, max = 0, step = 0, value = "Grid",
		  desc = Spring.I18N('ui.settings.option.keybindings_descr') or "",
		  selectOptions = keybindingOptions,
		  onLoad = function()
			  local keyFile = Spring.GetConfigString("KeybindingFile", "")
			  if (not keyFile) or (keyFile == "") or (not VFS.FileExists(keyFile)) then
				  keyFile = keyLayouts.keybindingLayoutFiles[1]
			  end
			  return keyLayouts.presetKeybindings[keyFile] or keyLayouts.keybindingLayouts[1]
		  end,
		  onChange = function(v)
			  local keyFile = keyLayouts.keybindingPresets[v]
			  if not keyFile or keyFile == "" then return end

			  local isCustom = keyLayouts.keybindingPresets["Custom"] == keyFile

			  if isCustom and not VFS.FileExists(keyFile) then
				  Spring.SendCommands("keysave " .. keyFile)
				  Spring.Echo("Preset Custom selected, file saved at: " .. keyFile)
			  end

			  Spring.SetConfigString("KeybindingFile", keyFile)
			  if isCustom then
				  Spring.Echo("To test your custom bindings after changes type in chat: /keyreload")
			  end

			  -- Enable Grid menu for grid keybinds, otherwise Build menu
			  if string.find(string.lower(v), "grid", nil, true) then
				  widgetHandler:DisableWidget('Build menu')
				  widgetHandler:EnableWidget('Grid menu')
			  elseif v ~= 'Custom' then
				  widgetHandler:DisableWidget('Grid menu')
				  widgetHandler:EnableWidget('Build menu')
			  end

			  if WG['bar_hotkeys'] and WG['bar_hotkeys'].reloadBindings then
				  WG['bar_hotkeys'].reloadBindings()
			  end
		  end,
		},

		{ id = "gridmenu", name = Spring.I18N('ui.settings.option.gridmenu') or "Grid Menu",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.gridmenu_descr') or "",
		  onLoad = function() return getWidgetToggleValue("Grid menu") end,
		  onChange = function(v)
			  if v then
				  widgetHandler:DisableWidget('Build menu')
				  widgetHandler:EnableWidget('Grid menu')
			  else
				  widgetHandler:DisableWidget('Grid menu')
				  widgetHandler:EnableWidget('Build menu')
			  end
		  end,
		},

		{ id = "gridmenu_alwaysreturn", name = Spring.I18N('ui.settings.option.gridmenu_alwaysreturn') or "Always Return",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.gridmenu_alwaysreturn_descr') or "",
		  parentId = "gridmenu",
		  onLoad = function() return loadWidgetData("Grid menu", { 'alwaysReturn' }, false) end,
		  onChange = function(v)
			  saveOptionValue('Grid menu', 'gridmenu', 'setAlwaysReturn', { 'alwaysReturn' }, v)
		  end,
		},

		{ id = "gridmenu_autoselectfirst", name = Spring.I18N('ui.settings.option.gridmenu_autoselectfirst') or "Auto-select First",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.gridmenu_autoselectfirst_descr') or "",
		  parentId = "gridmenu",
		  onLoad = function() return loadWidgetData("Grid menu", { 'autoSelectFirst' }, false) end,
		  onChange = function(v)
			  saveOptionValue('Grid menu', 'gridmenu', 'setAutoSelectFirst', { 'autoSelectFirst' }, v)
		  end,
		},

		{ id = "gridmenu_labbuildmode", name = Spring.I18N('ui.settings.option.gridmenu_labbuildmode') or "Lab Build Mode",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.gridmenu_labbuildmode_descr') or "",
		  parentId = "gridmenu",
		  onLoad = function() return loadWidgetData("Grid menu", { 'useLabBuildMode' }, false) end,
		  onChange = function(v)
			  saveOptionValue('Grid menu', 'gridmenu', 'setUseLabBuildMode', { 'useLabBuildMode' }, v)
		  end,
		},

		{ id = "gridmenu_ctrlkeymodifier", name = Spring.I18N('ui.settings.option.gridmenu_ctrlkeymodifier') or "Ctrl Key Modifier",
		  type = "slider", min = -20, max = 100, step = 1, value = 0,
		  desc = Spring.I18N('ui.settings.option.gridmenu_ctrlkeymodifier_descr') or "",
		  parentId = "gridmenu",
		  onLoad = function() return loadWidgetData("Grid menu", { 'ctrlKeyModifier' }, 0) end,
		  onChange = function(v)
			  saveOptionValue('Grid menu', 'gridmenu', 'setCtrlKeyModifier', { 'ctrlKeyModifier' }, v)
		  end,
		},

		{ id = "gridmenu_shiftkeymodifier", name = Spring.I18N('ui.settings.option.gridmenu_shiftkeymodifier') or "Shift Key Modifier",
		  type = "slider", min = -20, max = 100, step = 1, value = 0,
		  desc = Spring.I18N('ui.settings.option.gridmenu_shiftkeymodifier_descr') or "",
		  parentId = "gridmenu",
		  -- Note: legacy gui_options.lua saved this under 'ShiftKeyModifier' (capital S), but Grid menu
		  -- widget reads 'shiftKeyModifier' (lowercase). Using lowercase here so the setting persists.
		  onLoad = function() return loadWidgetData("Grid menu", { 'shiftKeyModifier' }, 0) end,
		  onChange = function(v)
			  saveOptionValue('Grid menu', 'gridmenu', 'setShiftKeyModifier', { 'shiftKeyModifier' }, v)
		  end,
		},

		---------------------------------------------------------------
		-- Cursor
		---------------------------------------------------------------
		{ id = "heading_cursor", name = Spring.I18N('ui.settings.option.label_cursor') or "Cursor", type = "heading" },

		{ id = "hwcursor", name = Spring.I18N('ui.settings.option.hwcursor') or "Hardware Cursor",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.hwcursor_descr') or "",
		  onLoad = function() return Spring.GetConfigInt("HardwareCursor", 0) == 1 end,
		  onChange = function(v)
			  Spring.SendCommands("HardwareCursor " .. (v and 1 or 0))
			  Spring.SetConfigInt("HardwareCursor", v and 1 or 0)
		  end,
		},

		{ id = "setcamera_bugfix", name = Spring.I18N('ui.settings.option.setcamera_bugfix') or "SetCamera Bugfix",
		  type = "bool", min = 0, max = 1, step = 1, value = true,
		  desc = Spring.I18N('ui.settings.option.setcamera_bugfix_descr') or "",
		  onLoad = function()
			  if WG['setcamera_bugfix'] == nil then WG['setcamera_bugfix'] = true end
			  return WG['setcamera_bugfix'] == true
		  end,
		  onChange = function(v) WG['setcamera_bugfix'] = v end,
		},

		{ id = "cursorsize", name = Spring.I18N('ui.settings.option.cursorsize') or "Cursor Size",
		  type = "slider", min = 0.3, max = 1.7, step = 0.1, value = 1,
		  desc = Spring.I18N('ui.settings.option.cursorsize_descr') or "",
		  onLoad = function()
			  -- No stable source of truth (legacy had no onLoad either); default to 1
			  return 1
		  end,
		  onChange = function(v)
			  if WG['cursors'] and WG['cursors'].setsizemult then
				  WG['cursors'].setsizemult(v)
			  end
		  end,
		},

		{ id = "containmouse", name = Spring.I18N('ui.settings.option.containmouse') or "Contain Mouse",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.containmouse_descr') or "",
		  onLoad = function() return Spring.GetConfigInt("grabinput", 1) == 1 end,
		  onChange = function(v) Spring.SetConfigInt("grabinput", v and 1 or 0) end,
		},

		{ id = "doubleclicktime", name = Spring.I18N('ui.settings.option.doubleclicktime') or "Double Click Time",
		  type = "slider", min = 150, max = 400, step = 10, value = 200,
		  desc = Spring.I18N('ui.settings.option.doubleclicktime_descr') or "",
		  onLoad = function() return Spring.GetConfigInt("DoubleClickTime", 200) end,
		  onChange = function(v) Spring.SetConfigInt("DoubleClickTime", math.floor(v)) end,
		},

		{ id = "dragthreshold", name = Spring.I18N('ui.settings.option.dragthreshold') or "Drag Threshold",
		  type = "slider", min = 4, max = 50, step = 1, value = 4,
		  desc = Spring.I18N('ui.settings.option.dragthreshold_descr') or "",
		  onLoad = function() return Spring.GetConfigInt("MouseDragSelectionThreshold", 4) end,
		  onChange = function(v)
			  local iv = math.floor(v)
			  Spring.SetConfigInt("MouseDragSelectionThreshold", iv)
			  Spring.SetConfigInt("MouseDragCircleCommandThreshold", iv)
			  Spring.SetConfigInt("MouseDragBoxCommandThreshold", iv + 12)
			  Spring.SetConfigInt("MouseDragFrontCommandThreshold", iv + 26)
		  end,
		},

		---------------------------------------------------------------
		-- Camera
		---------------------------------------------------------------
		{ id = "heading_camera", name = Spring.I18N('ui.settings.option.label_camera') or "Camera", type = "heading" },

		{ id = "middleclicktoggle", name = Spring.I18N('ui.settings.option.middleclicktoggle') or "Middle Click Toggle",
		  type = "bool", min = 0, max = 1, step = 1, value = true,
		  desc = Spring.I18N('ui.settings.option.middleclicktoggle_descr') or "",
		  onLoad = function() return Spring.GetConfigFloat("MouseDragScrollThreshold", 0.3) ~= 0 end,
		  onChange = function(v) Spring.SetConfigFloat("MouseDragScrollThreshold", v and 0.3 or 0) end,
		},

		{ id = "screenedgemove", name = Spring.I18N('ui.settings.option.screenedgemove') or "Screen Edge Move",
		  type = "bool", min = 0, max = 1, step = 1, value = true,
		  desc = Spring.I18N('ui.settings.option.screenedgemove_descr') or "",
		  onLoad = function() return Spring.GetConfigInt("FullscreenEdgeMove", 1) == 1 end,
		  onChange = function(v)
			  Spring.SetConfigInt("FullscreenEdgeMove", v and 1 or 0)
			  Spring.SetConfigInt("WindowedEdgeMove", v and 1 or 0)
			  if v then
				  Spring.SetConfigFloat("EdgeMoveWidth", Spring.GetConfigFloat("EdgeMoveWidth", 0.02))
			  else
				  Spring.SetConfigFloat("EdgeMoveWidth", 0)
			  end
		  end,
		},

		{ id = "screenedgemovewidth", name = Spring.I18N('ui.settings.option.screenedgemovewidth') or "Edge Move Width",
		  type = "slider", min = 0, max = 0.1, step = 0.01, value = 0.02,
		  desc = Spring.I18N('ui.settings.option.screenedgemovewidth_descr') or "",
		  parentId = "screenedgemove",
		  onLoad = function() return Spring.GetConfigFloat("EdgeMoveWidth", 0.02) end,
		  onChange = function(v) Spring.SetConfigFloat("EdgeMoveWidth", v) end,
		},

		{ id = "screenedgemovedynamic", name = Spring.I18N('ui.settings.option.screenedgemovedynamic') or "Edge Move Dynamic",
		  type = "bool", min = 0, max = 1, step = 1, value = true,
		  desc = Spring.I18N('ui.settings.option.screenedgemovedynamic_descr') or "",
		  parentId = "screenedgemove",
		  onLoad = function() return Spring.GetConfigInt("EdgeMoveDynamic", 1) == 1 end,
		  onChange = function(v) Spring.SetConfigInt("EdgeMoveDynamic", v and 1 or 0) end,
		},

		{ id = "camera", name = Spring.I18N('ui.settings.option.camera') or "Camera Mode",
		  type = "select", min = 0, max = 0, step = 0, value = 2,
		  desc = "",
		  selectOptions = cameraModeOptions,
		  onLoad = function() return Spring.GetConfigInt("CamMode", 1) + 1 end,
		  onChange = function(v)
			  Spring.SetConfigInt("CamMode", v - 1)
			  if v == 1 then Spring.SendCommands('viewfps')
			  elseif v == 2 then Spring.SendCommands('viewta')
			  elseif v == 3 then Spring.SendCommands('viewspring')
			  elseif v == 4 then Spring.SendCommands('viewrot')
			  elseif v == 5 then Spring.SendCommands('viewfree')
			  end
		  end,
		},

		{ id = "springcamheightmode", name = Spring.I18N('ui.settings.option.springcamheightmode') or "Spring Cam Height Mode",
		  type = "select", min = 0, max = 0, step = 0, value = 1,
		  desc = Spring.I18N('ui.settings.option.springcamheightmode_descr') or "",
		  selectOptions = springCamHeightOptions,
		  onLoad = function() return Spring.GetConfigInt("CamSpringTrackMapHeightMode", 0) + 1 end,
		  onChange = function(v) Spring.SetConfigInt("CamSpringTrackMapHeightMode", v - 1) end,
		},

		{ id = "mincamheight", name = Spring.I18N('ui.settings.option.mincamheight') or "Min Camera Height",
		  type = "slider", min = 0, max = 1500, step = 1, value = 0,
		  desc = Spring.I18N('ui.settings.option.mincamheight_descr') or "",
		  onLoad = function() return Spring.GetConfigInt("CamSpringMinZoomDistance", 0) end,
		  onChange = function(v)
			  local iv = math.floor(v)
			  Spring.SetConfigInt("CamSpringMinZoomDistance", iv)
			  Spring.SetConfigInt("OverheadMinZoomDistance", iv)
		  end,
		},

		{ id = "camerashake", name = Spring.I18N('ui.settings.option.camerashake') or "Camera Shake",
		  type = "slider", min = 0, max = 200, step = 10, value = 80,
		  desc = Spring.I18N('ui.settings.option.camerashake_descr') or "",
		  onLoad = function() return loadWidgetData("CameraShake", { 'powerScale' }, 80) end,
		  onChange = function(v)
			  saveOptionValue('CameraShake', 'camerashake', 'setStrength', { 'powerScale' }, v)
			  if v > 0 then
				  widgetHandler:EnableWidget("CameraShake")
			  end
		  end,
		},

		{ id = "smoothingmode", name = Spring.I18N('ui.settings.option.smoothingmode') or "Smoothing Mode",
		  type = "select", min = 0, max = 0, step = 0, value = 2,
		  desc = "",
		  selectOptions = smoothingModeOptions,
		  onLoad = function() return Spring.GetConfigInt("CamTransitionMode", 1) + 1 end,
		  onChange = function(v) Spring.SetConfigInt("CamTransitionMode", v - 1) end,
		},

		{ id = "camerasmoothness", name = Spring.I18N('ui.settings.option.camerasmoothness') or "Camera Smoothness",
		  type = "slider", min = 0.04, max = 2, step = 0.01, value = 0.4,
		  desc = Spring.I18N('ui.settings.option.camerasmoothness_descr') or "",
		  onLoad = function()
			  -- Reverse-compute user-facing value from stored CamSpringHalflife.
			  -- Forward: halfLife = value * 200 if value <= 1 else value * 600 - 400
			  local halfLife = Spring.GetConfigFloat("CamSpringHalflife", 80)
			  if halfLife <= 200 then
				  return halfLife / 200
			  else
				  return (halfLife + 400) / 600
			  end
		  end,
		  onChange = function(v)
			  local halfLife = v
			  if halfLife <= 1 then
				  halfLife = halfLife * 200
			  else
				  halfLife = halfLife * 600 - 400
			  end
			  Spring.SetConfigFloat("CamSpringHalflife", halfLife)
		  end,
		},

		{ id = "camerapanspeed", name = Spring.I18N('ui.settings.option.camerapanspeed') or "Camera Pan Speed",
		  type = "slider", min = -0.01, max = -0.00195, step = 0.0001, value = -0.0035,
		  desc = Spring.I18N('ui.settings.option.camerapanspeed_descr') or "",
		  onLoad = function() return Spring.GetConfigFloat("MiddleClickScrollSpeed", 0.0035) end,
		  onChange = function(v) Spring.SetConfigFloat("MiddleClickScrollSpeed", v) end,
		},

		{ id = "cameramovespeed", name = Spring.I18N('ui.settings.option.cameramovespeed') or "Camera Move Speed",
		  type = "slider", min = 0, max = 100, step = 1, value = 10,
		  desc = Spring.I18N('ui.settings.option.cameramovespeed_descr') or "",
		  onLoad = function() return Spring.GetConfigInt("CamSpringScrollSpeed", 10) end,
		  onChange = function(v)
			  local iv = math.floor(v)
			  Spring.SetConfigInt("FPSScrollSpeed", iv)
			  Spring.SetConfigInt("OverheadScrollSpeed", iv)
			  Spring.SetConfigInt("RotOverheadScrollSpeed", iv)
			  Spring.SetConfigFloat("CamFreeScrollSpeed", iv * 50)
			  Spring.SetConfigInt("CamSpringScrollSpeed", iv)
		  end,
		},

		{ id = "scrollspeed", name = Spring.I18N('ui.settings.option.scrollspeed') or "Scroll Wheel Speed",
		  type = "slider", min = 1, max = 50, step = 1, value = 25,
		  desc = "",
		  onLoad = function() return math.abs(Spring.GetConfigInt("ScrollWheelSpeed", 25)) end,
		  onChange = function(v)
			  local iv = math.floor(v)
			  local inverted = Spring.GetConfigInt("ScrollWheelSpeed", 25) < 0
			  Spring.SetConfigInt("ScrollWheelSpeed", inverted and -iv or iv)
		  end,
		},

		{ id = "scrollinverse", name = Spring.I18N('ui.settings.option.scrollinverse') or "Invert Scroll Wheel",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = "",
		  onLoad = function() return Spring.GetConfigInt("ScrollWheelSpeed", 25) < 0 end,
		  onChange = function(v)
			  local mag = math.abs(Spring.GetConfigInt("ScrollWheelSpeed", 25))
			  Spring.SetConfigInt("ScrollWheelSpeed", v and -mag or mag)
		  end,
		},

		{ id = "invertmouse", name = Spring.I18N('ui.settings.option.invertmouse') or "Invert Mouse",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = "",
		  onLoad = function() return Spring.GetConfigInt("InvertMouse", 0) == 1 end,
		  onChange = function(v) Spring.SetConfigInt("InvertMouse", v and 1 or 0) end,
		},

		{ id = "scrolltoggleoverview", name = Spring.I18N('ui.settings.option.scrolltoggleoverview') or "Scroll-down Toggles Overview",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.scrolltoggleoverview_descr') or "",
		  onLoad = function() return getWidgetToggleValue("Scrolldown Toggleoverview") end,
		  onChange = function(v)
			  if v then widgetHandler:EnableWidget("Scrolldown Toggleoverview")
			  else widgetHandler:DisableWidget("Scrolldown Toggleoverview") end
		  end,
		},

		{ id = "camoverviewrestore", name = Spring.I18N('ui.settings.option.camoverviewrestore') or "Overview Camera Restore Position",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.camoverviewrestore_descr') or "",
		  onLoad = function() return getWidgetToggleValue("Overview Camera Keep Position") end,
		  onChange = function(v)
			  if v then widgetHandler:EnableWidget("Overview Camera Keep Position")
			  else widgetHandler:DisableWidget("Overview Camera Keep Position") end
		  end,
		},

		{ id = "lockcamera_transitiontime", name = Spring.I18N('ui.settings.option.lockcamera_transitiontime') or "Lock Camera Transition Time",
		  type = "slider", min = 0.5, max = 1.7, step = 0.01, value = 1,
		  desc = Spring.I18N('ui.settings.option.lockcamera_transitiontime_descr') or "",
		  onLoad = function() return loadWidgetData("Lockcamera", { 'transitionTime' }, 1) end,
		  onChange = function(v)
			  saveOptionValue('Lockcamera', 'lockcamera', 'SetTransitionTime', { 'transitionTime' }, v)
		  end,
		},

		{ id = "allyselunits_select", name = Spring.I18N('ui.settings.option.allyselunits_select') or "Select Ally Units",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.allyselunits_select_descr') or "",
		  onLoad = function() return loadWidgetData("Ally Selected Units", { 'selectPlayerUnits' }, false) end,
		  onChange = function(v)
			  saveOptionValue('Ally Selected Units', 'allyselectedunits', 'setSelectPlayerUnits', { 'selectPlayerUnits' }, v)
		  end,
		},

		{ id = "lockcamera_hideenemies", name = Spring.I18N('ui.settings.option.lockcamera_hideenemies') or "Lock Camera Hide Enemies",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.lockcamera_hideenemies_descr') or "",
		  onLoad = function() return loadWidgetData("Lockcamera", { 'lockcameraHideEnemies' }, false) end,
		  onChange = function(v)
			  saveOptionValue('Lockcamera', 'lockcamera', 'SetHideEnemies', { 'lockcameraHideEnemies' }, v)
		  end,
		},

		{ id = "lockcamera_los", name = Spring.I18N('ui.settings.option.lockcamera_los') or "Lock Camera LOS",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.lockcamera_los_descr') or "",
		  onLoad = function() return loadWidgetData("Lockcamera", { 'lockcameraLos' }, false) end,
		  onChange = function(v)
			  saveOptionValue('Lockcamera', 'lockcamera', 'SetLos', { 'lockcameraLos' }, v)
		  end,
		},

		---------------------------------------------------------------
		-- Commands
		---------------------------------------------------------------
		{ id = "heading_commands", name = Spring.I18N('ui.settings.option.label_commands') or "Commands", type = "heading" },

		{ id = "drag_multicommand_shift", name = Spring.I18N('ui.settings.option.drag_multicommand_shift') or "Drag Multi-Command Shift",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.drag_multicommand_shift_descr') or "",
		  onLoad = function() return loadWidgetData("CustomFormations2", { 'repeatForSingleUnit' }, false) end,
		  onChange = function(v)
			  saveOptionValue('CustomFormations2', 'customformations', 'setRepeatForSingleUnit', { 'repeatForSingleUnit' }, v)
		  end,
		},
	}
end
