-- Centralized Options Configuration — thin loader.
-- Each sub-tab's config lives in its own file under options_config/.
-- This file assembles them into the structure the widget expects:
--   { gfx_environment = { sections... }, gfx_rendering = { ... }, ... }

local CONFIG_DIR = "luaui/Include/rml_utilities/options_config/"

return function(deps)
	return {
		gfx_environment = VFS.Include(CONFIG_DIR .. "gfx_environment.lua")(deps),
		gfx_rendering = VFS.Include(CONFIG_DIR .. "gfx_rendering.lua")(deps),
		gfx_display = VFS.Include(CONFIG_DIR .. "gfx_display.lua")(deps),
		audio = VFS.Include(CONFIG_DIR .. "sound.lua")(deps),
		interface_general = VFS.Include(CONFIG_DIR .. "interface_general.lua")(deps),
		interface_widgets = VFS.Include(CONFIG_DIR .. "interface_widgets.lua")(deps),
		interface_visuals = VFS.Include(CONFIG_DIR .. "interface_visuals.lua")(deps),
		interface_info = VFS.Include(CONFIG_DIR .. "interface_info.lua")(deps),
		interface_spectator = VFS.Include(CONFIG_DIR .. "interface_spectator.lua")(deps),
		control = VFS.Include(CONFIG_DIR .. "control.lua")(deps),
		game = VFS.Include(CONFIG_DIR .. "game.lua")(deps),
		dev = VFS.Include(CONFIG_DIR .. "dev.lua")(deps),
		notifications = VFS.Include(CONFIG_DIR .. "notifications.lua")(deps),
		accessibility = VFS.Include(CONFIG_DIR .. "accessibility.lua")(deps),
	}
end
