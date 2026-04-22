-- Notifications config.
--
-- The per-message toggle list (~30 entries generated from
-- WG.notifications.getNotificationList() in the legacy widget at lines
-- 6430-6463) is deliberately skipped for this pass — quality pass later.

return function(deps)
	local saveOptionValue = deps.saveOptionValue
	local loadWidgetData = deps.loadWidgetData

	-- Enumerate voice sets from sounds/voice/<lang>/<set>/.
	-- Mirrors gui_options.lua:6392-6426. Runs at config load; since that
	-- happens before cmd_resolution_switcher on the layered widget handler
	-- the VFS is available already (filesystem access, not a WG dependency).
	local voiceSetOptions = {}
	local languageDirs = VFS.SubDirs('sounds/voice', '*')
	local seen = {}
	for _, langDir in ipairs(languageDirs) do
		-- Strip "sounds/voice/" prefix and trailing slash.
		local lang = string.gsub(string.sub(langDir, 14, #langDir - 1), "\\", "/")
		local setDirs = VFS.SubDirs('sounds/voice/' .. lang, '*')
		for _, setDir in ipairs(setDirs) do
			local setName = string.gsub(string.sub(setDir, 14, #setDir - 1), "\\", "/")
			if not seen[setName] then
				seen[setName] = true
				voiceSetOptions[#voiceSetOptions + 1] = { value = setName, label = setName }
			end
		end
	end

	return {
		{ id = "heading_notifications", name = Spring.I18N('ui.settings.group.notifications') or "Notifications", type = "heading" },

		{ id = "notifications_set", name = Spring.I18N('ui.settings.option.notifications_set') or "Voice Set",
		  type = "select", min = 0, max = 0, step = 0, value = "en/cephis",
		  desc = "",
		  selectOptions = voiceSetOptions,
		  onLoad = function() return Spring.GetConfigString("voiceset", "en/cephis") end,
		  onChange = function(v)
			  Spring.SetConfigString("voiceset", v)
			  if widgetHandler.orderList["Notifications"] ~= nil then
				  widgetHandler:DisableWidget("Notifications")
				  widgetHandler:EnableWidget("Notifications")
			  end
		  end,
		},

		{ id = "notifications_messages", name = Spring.I18N('ui.settings.option.notifications_messages') or "Display Messages",
		  type = "bool", min = 0, max = 1, step = 1, value = true,
		  desc = Spring.I18N('ui.settings.option.notifications_messages_descr') or "",
		  onLoad = function() return loadWidgetData("Notifications", { 'displayMessages' }, true) end,
		  onChange = function(v)
			  saveOptionValue('Notifications', 'notifications', 'setMessages', { 'displayMessages' }, v)
		  end,
		},

		{ id = "notifications_spoken", name = Spring.I18N('ui.settings.option.notifications_spoken') or "Spoken",
		  type = "bool", min = 0, max = 1, step = 1, value = true,
		  desc = Spring.I18N('ui.settings.option.notifications_spoken_descr') or "",
		  onLoad = function() return loadWidgetData("Notifications", { 'spoken' }, true) end,
		  onChange = function(v)
			  saveOptionValue('Notifications', 'notifications', 'setSpoken', { 'spoken' }, v)
		  end,
		},

		{ id = "notifications_volume", name = Spring.I18N('ui.settings.option.notifications_volume') or "Volume",
		  type = "slider", min = 0.05, max = 1, step = 0.05, value = 0.7,
		  desc = Spring.I18N('ui.settings.option.notifications_volume_descr') or "",
		  onLoad = function() return loadWidgetData("Notifications", { 'globalVolume' }, 0.7) end,
		  onChange = function(v)
			  saveOptionValue('Notifications', 'notifications', 'setVolume', { 'globalVolume' }, v)
		  end,
		},

		{ id = "notifications_substitute", name = Spring.I18N('ui.settings.option.notifications_substitute') or "Use Substitutes",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.notifications_substitute_descr') or "",
		  onLoad = function() return Spring.GetConfigInt("NotificationsSubstitute", 0) == 1 end,
		  onChange = function(v)
			  Spring.SetConfigInt("NotificationsSubstitute", v and 1 or 0)
			  widgetHandler:DisableWidget("Notifications")
			  widgetHandler:EnableWidget("Notifications")
		  end,
		},

		{ id = "notifications_refresh", name = Spring.I18N('ui.settings.option.notifications_refresh') or "Refresh Notifications",
		  type = "action", min = 0, max = 0, step = 0, value = false,
		  desc = Spring.I18N('ui.settings.option.notifications_refresh_descr') or "",
		  onClick = function()
			  widgetHandler:DisableWidget("Notifications")
			  widgetHandler:EnableWidget("Notifications")
		  end,
		},
	}
end
