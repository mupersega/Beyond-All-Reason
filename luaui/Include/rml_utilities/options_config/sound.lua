-- Audio tab config: General, Volume, Settings, Soundtrack sections.
-- Returns a builder function — call with deps table from the widget.

return function(deps)
	local saveOptionValue = deps.saveOptionValue
	local loadWidgetData = deps.loadWidgetData

	local function refreshTrackList()
		if WG['music'] and WG['music'].RefreshTrackList then
			WG['music'].RefreshTrackList()
		end
	end

	local function refreshSettings()
		if WG['music'] and WG['music'].RefreshSettings then
			WG['music'].RefreshSettings()
		end
	end

	-- Build sound device list from infolog
	local function buildSoundDevices()
		local devices = { { value = "default", label = "Default" } }
		local infolog = VFS.LoadFile("infolog.txt")
		if infolog then
			for line in infolog:gmatch("[^\n]+") do
				if line:find('     [', nil, true) then
					local device = line:match('     %[([0-9a-zA-Z _%/%%-%(%)]*)') or ""
					device = device:sub(1)
					if #device > 0 then
						devices[#devices + 1] = { value = device, label = device }
					end
				end
			end
		end
		return devices
	end

	local soundDevices = buildSoundDevices()

	return {
		---------------------------------------------------------------
		-- General
		---------------------------------------------------------------
		{ id = "heading_general", name = Spring.I18N('ui.settings.option.label_general') or "General", type = "heading" },

		{ id = "snddevice", name = Spring.I18N('ui.settings.option.snddevice') or "Sound Device",
		  type = "select", min = 0, max = 0, step = 0, value = "default",
		  desc = Spring.I18N('ui.settings.option.snddevice_descr') or "",
		  selectOptions = soundDevices,
		  onLoad = function()
			  local current = Spring.GetConfigString("snd_device", "")
			  if current == "" then return "default" end
			  return current
		  end,
		  onChange = function(v)
			  if v == "default" then
				  Spring.SetConfigString("snd_device", "")
			  else
				  Spring.SetConfigString("snd_device", v)
			  end
		  end,
		},

		{ id = "sndunitsound", name = Spring.I18N('ui.settings.option.sndunitsound') or "Unit Response Sounds",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.sndunitsound_desc') or "",
		  onLoad = function() return Spring.GetConfigInt("snd_unitsound", 1) == 1 end,
		  onChange = function(v)
			  Spring.SetConfigInt("snd_unitsound", v and 1 or 0)
		  end,
		},

		{ id = "sndairabsorption", name = Spring.I18N('ui.settings.option.sndairabsorption') or "Air Absorption",
		  type = "slider", min = 0, max = 0.4, step = 0.01, value = 0.35,
		  desc = Spring.I18N('ui.settings.option.sndairabsorption_descr') or "",
		  onLoad = function() return Spring.GetConfigFloat("snd_airAbsorption", 0.35) end,
		  onChange = function(v)
			  Spring.SetConfigFloat("snd_airAbsorption", v)
		  end,
		},

		{ id = "sndzoomvolume", name = Spring.I18N('ui.settings.option.sndzoomvolume') or "Zoom Volume",
		  type = "slider", min = 0, max = 3, step = 0.01, value = 1.0,
		  desc = Spring.I18N('ui.settings.option.sndzoomvolume_descr') or "",
		  onLoad = function() return Spring.GetConfigFloat("snd_zoomVolume", 1.0) end,
		  onChange = function(v)
			  Spring.SetConfigFloat("snd_zoomVolume", v)
		  end,
		},

		{ id = "muteoffscreen", name = Spring.I18N('ui.settings.option.muteoffscreen') or "Mute When Offscreen",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.muteoffscreen_descr') or "",
		  onLoad = function() return Spring.GetConfigInt("muteOffscreen", 0) == 1 end,
		  onChange = function(v)
			  Spring.SetConfigInt("muteOffscreen", v and 1 or 0)
		  end,
		},

		---------------------------------------------------------------
		-- Volume — master is parent, sub-volumes are children
		---------------------------------------------------------------
		{ id = "heading_volume", name = Spring.I18N('ui.settings.option.volume') or "Volume", type = "heading" },

		{ id = "sndvolmaster", name = Spring.I18N('ui.settings.option.sndvolmaster') or "Master Volume",
		  type = "slider", min = 0, max = 100, step = 1, value = 0,
		  desc = Spring.I18N('ui.settings.option.sndvolmaster_descr') or "",
		  onLoad = function() return Spring.GetConfigInt("snd_volmaster", 40) end,
		  onChange = function(v)
			  Spring.SetConfigInt("snd_volmaster", math.floor(v))
		  end,
		},

		{ id = "sndvolgeneral", name = Spring.I18N('ui.settings.option.sndvolgeneral') or "General",
		  type = "slider", min = 0, max = 100, step = 2, value = 100,
		  desc = Spring.I18N('ui.settings.option.sndvolgeneral_descr') or "",
		  parentId = "sndvolmaster",
		  onLoad = function() return Spring.GetConfigInt("snd_volgeneral", 100) end,
		  onChange = function(v)
			  Spring.SetConfigInt("snd_volgeneral", math.floor(v))
		  end,
		},

		{ id = "sndvolbattle", name = Spring.I18N('ui.settings.option.sndvolbattle') or "Battle",
		  type = "slider", min = 0, max = 100, step = 2, value = 100,
		  desc = Spring.I18N('ui.settings.option.sndvolbattle_descr') or "",
		  parentId = "sndvolmaster",
		  onLoad = function() return Spring.GetConfigInt("snd_volbattle_options", 100) end,
		  onChange = function(v)
			  Spring.SetConfigInt("snd_volbattle_options", math.floor(v))
		  end,
		},

		{ id = "sndvolui", name = Spring.I18N('ui.settings.option.sndvolui') or "Interface",
		  type = "slider", min = 0, max = 100, step = 2, value = 100,
		  desc = Spring.I18N('ui.settings.option.sndvolui_descr') or "",
		  parentId = "sndvolmaster",
		  onLoad = function() return Spring.GetConfigInt("snd_volui", 100) end,
		  onChange = function(v)
			  Spring.SetConfigInt("snd_volui", math.floor(v))
		  end,
		},

		{ id = "sndvolmusic", name = Spring.I18N('ui.settings.option.sndvolmusic') or "Music",
		  type = "slider", min = 0, max = 99, step = 1, value = 50,
		  desc = Spring.I18N('ui.settings.option.sndvolmusic_descr') or "",
		  parentId = "sndvolmaster",
		  onLoad = function() return Spring.GetConfigInt("snd_volmusic", 50) end,
		  onChange = function(v)
			  if WG['music'] and WG['music'].SetMusicVolume then
				  WG['music'].SetMusicVolume(math.floor(v))
			  else
				  Spring.SetConfigInt("snd_volmusic", math.floor(v))
			  end
		  end,
		},

		{ id = "console_chatvolume", name = Spring.I18N('ui.settings.option.console_chatvolume') or "Chat Message",
		  type = "slider", min = 0, max = 1, step = 0.01, value = 0,
		  desc = Spring.I18N('ui.settings.option.console_chatvolume_descr') or "",
		  parentId = "sndvolmaster",
		  onLoad = function() return loadWidgetData("Chat", "sndChatFileVolume", 0) end,
		  onChange = function(v)
			  saveOptionValue('Chat', 'chat', 'setChatVolume', { 'sndChatFileVolume' }, v)
		  end,
		},

		{ id = "mapmarkvolume", name = Spring.I18N('ui.settings.option.console_mapmarkvolume') or "Map Mark Point",
		  type = "slider", min = 0, max = 1, step = 0.01, value = 0.6,
		  desc = Spring.I18N('ui.settings.option.console_mapmarkvolume_descr') or "",
		  parentId = "sndvolmaster",
		  onLoad = function() return loadWidgetData("Chat", "volume", 0.6) end,
		  onChange = function(v)
			  saveOptionValue('Chat', 'mapmarkping', 'setMapmarkVolume', { 'volume' }, v)
		  end,
		},

		---------------------------------------------------------------
		-- Soundtrack — "Original Soundtrack" is parent, tracks are children
		---------------------------------------------------------------
		{ id = "heading_soundtrack", name = Spring.I18N('ui.settings.option.label_soundtrack') or "Soundtrack", type = "heading" },

		{ id = "soundtrackNew", name = Spring.I18N('ui.settings.option.soundtracknew') or "Original Soundtrack",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.soundtracknew_descr') or "",
		  onLoad = function() return Spring.GetConfigInt('UseSoundtrackNew', 1) == 1 end,
		  onChange = function(v)
			  Spring.SetConfigInt('UseSoundtrackNew', v and 1 or 0)
			  refreshTrackList()
		  end,
		},

		{ id = "soundtrackRaptors", name = Spring.I18N('ui.settings.option.soundtrackraptors') or "Raptors",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.soundtrackraptors_descr') or "",
		  parentId = "soundtrackNew",
		  onLoad = function() return Spring.GetConfigInt('UseSoundtrackRaptors', 0) == 1 end,
		  onChange = function(v)
			  Spring.SetConfigInt('UseSoundtrackRaptors', v and 1 or 0)
			  refreshTrackList()
		  end,
		},

		{ id = "soundtrackScavengers", name = Spring.I18N('ui.settings.option.soundtrackscavengers') or "Scavengers",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.soundtrackscavengers_descr') or "",
		  parentId = "soundtrackNew",
		  onLoad = function() return Spring.GetConfigInt('UseSoundtrackScavengers', 0) == 1 end,
		  onChange = function(v)
			  Spring.SetConfigInt('UseSoundtrackScavengers', v and 1 or 0)
			  refreshTrackList()
		  end,
		},

		{ id = "soundtrackAprilFools", name = Spring.I18N('ui.settings.option.soundtrackaprilfools') or "April Fools",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.soundtrackaprilfools_descr') or "",
		  parentId = "soundtrackNew",
		  onLoad = function() return Spring.GetConfigInt('UseSoundtrackAprilFools', 1) == 1 end,
		  onChange = function(v)
			  Spring.SetConfigInt('UseSoundtrackAprilFools', v and 1 or 0)
			  refreshTrackList()
		  end,
		},

		{ id = "soundtrackAprilFoolsPostEvent", name = Spring.I18N('ui.settings.option.soundtrackaprilfoolspostevent') or "April Fools (Post-Event)",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.soundtrackaprilfoolspostevent_descr') or "",
		  parentId = "soundtrackNew",
		  onLoad = function() return Spring.GetConfigInt('UseSoundtrackAprilFoolsPostEvent', 0) == 1 end,
		  onChange = function(v)
			  Spring.SetConfigInt('UseSoundtrackAprilFoolsPostEvent', v and 1 or 0)
			  refreshTrackList()
		  end,
		},

		{ id = "soundtrackHalloween", name = Spring.I18N('ui.settings.option.soundtrackhalloween') or "Halloween",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.soundtrackhalloween_descr') or "",
		  parentId = "soundtrackNew",
		  onLoad = function() return Spring.GetConfigInt('UseSoundtrackHalloween', 1) == 1 end,
		  onChange = function(v)
			  Spring.SetConfigInt('UseSoundtrackHalloween', v and 1 or 0)
			  refreshTrackList()
		  end,
		},

		{ id = "soundtrackHalloweenPostEvent", name = Spring.I18N('ui.settings.option.soundtrackhalloweenpostevent') or "Halloween (Post-Event)",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.soundtrackhalloweenpostevent_descr') or "",
		  parentId = "soundtrackNew",
		  onLoad = function() return Spring.GetConfigInt('UseSoundtrackHalloweenPostEvent', 0) == 1 end,
		  onChange = function(v)
			  Spring.SetConfigInt('UseSoundtrackHalloweenPostEvent', v and 1 or 0)
			  refreshTrackList()
		  end,
		},

		{ id = "soundtrackXmas", name = Spring.I18N('ui.settings.option.soundtrackxmas') or "Christmas",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.soundtrackxmas_descr') or "",
		  parentId = "soundtrackNew",
		  onLoad = function() return Spring.GetConfigInt('UseSoundtrackXmas', 1) == 1 end,
		  onChange = function(v)
			  Spring.SetConfigInt('UseSoundtrackXmas', v and 1 or 0)
			  refreshTrackList()
		  end,
		},

		{ id = "soundtrackXmasPostEvent", name = Spring.I18N('ui.settings.option.soundtrackxmaspostevent') or "Christmas (Post-Event)",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.soundtrackxmaspostevent_descr') or "",
		  parentId = "soundtrackNew",
		  onLoad = function() return Spring.GetConfigInt('UseSoundtrackXmasPostEvent', 0) == 1 end,
		  onChange = function(v)
			  Spring.SetConfigInt('UseSoundtrackXmasPostEvent', v and 1 or 0)
			  refreshTrackList()
		  end,
		},

		{ id = "soundtrackCustom", name = Spring.I18N('ui.settings.option.soundtrackcustom') or "Custom Tracks",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.soundtrackcustom_descr') or "",
		  onLoad = function() return Spring.GetConfigInt('UseSoundtrackCustom', 1) == 1 end,
		  onChange = function(v)
			  Spring.SetConfigInt('UseSoundtrackCustom', v and 1 or 0)
			  refreshTrackList()
		  end,
		},

		{ id = "soundtrackInterruption", name = Spring.I18N('ui.settings.option.soundtrackinterruption') or "Track Interruption",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.soundtrackinterruption_descr') or "",
		  onLoad = function() return Spring.GetConfigInt('UseSoundtrackInterruption', 1) == 1 end,
		  onChange = function(v)
			  Spring.SetConfigInt('UseSoundtrackInterruption', v and 1 or 0)
			  refreshSettings()
		  end,
		},

		{ id = "soundtrackFades", name = Spring.I18N('ui.settings.option.soundtrackfades') or "Track Fades",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.soundtrackfades_descr') or "",
		  onLoad = function() return Spring.GetConfigInt('UseSoundtrackFades', 1) == 1 end,
		  onChange = function(v)
			  Spring.SetConfigInt('UseSoundtrackFades', v and 1 or 0)
			  refreshSettings()
		  end,
		},
	}
end
