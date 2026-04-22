-- Accessibility config: Team colors (anonymous + simple team colors).

return function(deps)
	return {
		---------------------------------------------------------------
		-- Team Colors
		---------------------------------------------------------------
		{ id = "heading_teamcolors", name = Spring.I18N('ui.settings.option.label_teamcolors') or "Team Colors", type = "heading" },

		-- Anonymous color (RGB sliders 0-255).
		-- Legacy writes to AnonymousColorR/G/B configs and triggers a luaui reload.
		-- Skip the reload here — the user can reload manually if they want an
		-- immediate visible change. Avoids destabilising the options panel.
		{ id = "anonymous_r", name = Spring.I18N('ui.settings.option.anonymous_r') or "Anonymous Red",
		  type = "slider", min = 0, max = 255, step = 1, value = 255,
		  desc = Spring.I18N('ui.settings.option.anonymous_descr') or "",
		  onLoad = function() return Spring.GetConfigInt("anonymousColorR", 255) end,
		  onChange = function(v) Spring.SetConfigInt("anonymousColorR", math.floor(v)) end,
		},

		{ id = "anonymous_g", name = Spring.I18N('ui.settings.option.anonymous_g') or "Anonymous Green",
		  type = "slider", min = 0, max = 255, step = 1, value = 0,
		  desc = Spring.I18N('ui.settings.option.anonymous_descr') or "",
		  onLoad = function() return Spring.GetConfigInt("anonymousColorG", 0) end,
		  onChange = function(v) Spring.SetConfigInt("anonymousColorG", math.floor(v)) end,
		},

		{ id = "anonymous_b", name = Spring.I18N('ui.settings.option.anonymous_b') or "Anonymous Blue",
		  type = "slider", min = 0, max = 255, step = 1, value = 0,
		  desc = Spring.I18N('ui.settings.option.anonymous_descr') or "",
		  onLoad = function() return Spring.GetConfigInt("anonymousColorB", 0) end,
		  onChange = function(v) Spring.SetConfigInt("anonymousColorB", math.floor(v)) end,
		},

		-- Simple Team Colors master toggle
		{ id = "simpleteamcolors", name = Spring.I18N('ui.settings.option.playercolors') or "Simple Team Colors",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.simpleteamcolors_descr') or "",
		  onLoad = function() return Spring.GetConfigInt("SimpleTeamColors", 0) == 1 end,
		  onChange = function(v)
			  Spring.SetConfigInt("SimpleTeamColors", v and 1 or 0)
			  Spring.SetConfigInt("UpdateTeamColors", 1)
		  end,
		},

		-- Reset — action that restores the legacy default RGB values
		{ id = "simpleteamcolors_reset", name = Spring.I18N('ui.settings.option.simpleteamcolors_reset') or "Reset to Defaults",
		  type = "action", min = 0, max = 0, step = 0, value = false,
		  desc = "",
		  parentId = "simpleteamcolors",
		  onClick = function()
			  Spring.SetConfigInt("SimpleTeamColorsUseGradient", 0)
			  Spring.SetConfigInt("SimpleTeamColorsPlayerR", 0)
			  Spring.SetConfigInt("SimpleTeamColorsPlayerG", 77)
			  Spring.SetConfigInt("SimpleTeamColorsPlayerB", 255)
			  Spring.SetConfigInt("SimpleTeamColorsAllyR", 0)
			  Spring.SetConfigInt("SimpleTeamColorsAllyG", 255)
			  Spring.SetConfigInt("SimpleTeamColorsAllyB", 0)
			  Spring.SetConfigInt("SimpleTeamColorsEnemyR", 255)
			  Spring.SetConfigInt("SimpleTeamColorsEnemyG", 16)
			  Spring.SetConfigInt("SimpleTeamColorsEnemyB", 5)
			  Spring.SetConfigInt("UpdateTeamColors", 1)
		  end,
		},

		{ id = "simpleteamcolors_use_gradient", name = Spring.I18N('ui.settings.option.simpleteamcolors_use_gradient') or "Use Gradient",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = "",
		  parentId = "simpleteamcolors",
		  onLoad = function() return Spring.GetConfigInt("SimpleTeamColorsUseGradient", 0) == 1 end,
		  onChange = function(v)
			  Spring.SetConfigInt("SimpleTeamColorsUseGradient", v and 1 or 0)
			  Spring.SetConfigInt("UpdateTeamColors", 1)
		  end,
		},

		{ id = "simpleteamcolorsfactionspecific", name = Spring.I18N('ui.settings.option.simpleteamcolorsfactionspecific') or "Faction-Specific Colors",
		  type = "bool", min = 0, max = 1, step = 1, value = false,
		  desc = Spring.I18N('ui.settings.option.simpleteamcolorsfactionspecific_descr') or "",
		  parentId = "simpleteamcolors",
		  onLoad = function() return Spring.GetConfigInt("SimpleTeamColorsFactionSpecific", 0) == 1 end,
		  onChange = function(v)
			  Spring.SetConfigInt("SimpleTeamColorsFactionSpecific", v and 1 or 0)
			  Spring.SetConfigInt("UpdateTeamColors", 1)
		  end,
		},

		-- Player color RGB
		{ id = "simpleteamcolors_player_r", name = Spring.I18N('ui.settings.option.simpleteamcolors_player_r') or "Player Red",
		  type = "slider", min = 0, max = 255, step = 1, value = 0,
		  desc = "",
		  parentId = "simpleteamcolors",
		  onLoad = function() return Spring.GetConfigInt("SimpleTeamColorsPlayerR", 0) end,
		  onChange = function(v)
			  Spring.SetConfigInt("SimpleTeamColorsPlayerR", math.floor(v))
			  Spring.SetConfigInt("UpdateTeamColors", 1)
		  end,
		},

		{ id = "simpleteamcolors_player_g", name = Spring.I18N('ui.settings.option.simpleteamcolors_player_g') or "Player Green",
		  type = "slider", min = 0, max = 255, step = 1, value = 77,
		  desc = "",
		  parentId = "simpleteamcolors",
		  onLoad = function() return Spring.GetConfigInt("SimpleTeamColorsPlayerG", 77) end,
		  onChange = function(v)
			  Spring.SetConfigInt("SimpleTeamColorsPlayerG", math.floor(v))
			  Spring.SetConfigInt("UpdateTeamColors", 1)
		  end,
		},

		{ id = "simpleteamcolors_player_b", name = Spring.I18N('ui.settings.option.simpleteamcolors_player_b') or "Player Blue",
		  type = "slider", min = 0, max = 255, step = 1, value = 255,
		  desc = "",
		  parentId = "simpleteamcolors",
		  onLoad = function() return Spring.GetConfigInt("SimpleTeamColorsPlayerB", 255) end,
		  onChange = function(v)
			  Spring.SetConfigInt("SimpleTeamColorsPlayerB", math.floor(v))
			  Spring.SetConfigInt("UpdateTeamColors", 1)
		  end,
		},

		-- Ally color RGB
		{ id = "simpleteamcolors_ally_r", name = Spring.I18N('ui.settings.option.simpleteamcolors_ally_r') or "Ally Red",
		  type = "slider", min = 0, max = 255, step = 1, value = 0,
		  desc = "",
		  parentId = "simpleteamcolors",
		  onLoad = function() return Spring.GetConfigInt("SimpleTeamColorsAllyR", 0) end,
		  onChange = function(v)
			  Spring.SetConfigInt("SimpleTeamColorsAllyR", math.floor(v))
			  Spring.SetConfigInt("UpdateTeamColors", 1)
		  end,
		},

		{ id = "simpleteamcolors_ally_g", name = Spring.I18N('ui.settings.option.simpleteamcolors_ally_g') or "Ally Green",
		  type = "slider", min = 0, max = 255, step = 1, value = 255,
		  desc = "",
		  parentId = "simpleteamcolors",
		  onLoad = function() return Spring.GetConfigInt("SimpleTeamColorsAllyG", 255) end,
		  onChange = function(v)
			  Spring.SetConfigInt("SimpleTeamColorsAllyG", math.floor(v))
			  Spring.SetConfigInt("UpdateTeamColors", 1)
		  end,
		},

		{ id = "simpleteamcolors_ally_b", name = Spring.I18N('ui.settings.option.simpleteamcolors_ally_b') or "Ally Blue",
		  type = "slider", min = 0, max = 255, step = 1, value = 0,
		  desc = "",
		  parentId = "simpleteamcolors",
		  onLoad = function() return Spring.GetConfigInt("SimpleTeamColorsAllyB", 0) end,
		  onChange = function(v)
			  Spring.SetConfigInt("SimpleTeamColorsAllyB", math.floor(v))
			  Spring.SetConfigInt("UpdateTeamColors", 1)
		  end,
		},

		-- Enemy color RGB
		{ id = "simpleteamcolors_enemy_r", name = Spring.I18N('ui.settings.option.simpleteamcolors_enemy_r') or "Enemy Red",
		  type = "slider", min = 0, max = 255, step = 1, value = 255,
		  desc = "",
		  parentId = "simpleteamcolors",
		  onLoad = function() return Spring.GetConfigInt("SimpleTeamColorsEnemyR", 255) end,
		  onChange = function(v)
			  Spring.SetConfigInt("SimpleTeamColorsEnemyR", math.floor(v))
			  Spring.SetConfigInt("UpdateTeamColors", 1)
		  end,
		},

		{ id = "simpleteamcolors_enemy_g", name = Spring.I18N('ui.settings.option.simpleteamcolors_enemy_g') or "Enemy Green",
		  type = "slider", min = 0, max = 255, step = 1, value = 16,
		  desc = "",
		  parentId = "simpleteamcolors",
		  onLoad = function() return Spring.GetConfigInt("SimpleTeamColorsEnemyG", 16) end,
		  onChange = function(v)
			  Spring.SetConfigInt("SimpleTeamColorsEnemyG", math.floor(v))
			  Spring.SetConfigInt("UpdateTeamColors", 1)
		  end,
		},

		{ id = "simpleteamcolors_enemy_b", name = Spring.I18N('ui.settings.option.simpleteamcolors_enemy_b') or "Enemy Blue",
		  type = "slider", min = 0, max = 255, step = 1, value = 5,
		  desc = "",
		  parentId = "simpleteamcolors",
		  onLoad = function() return Spring.GetConfigInt("SimpleTeamColorsEnemyB", 5) end,
		  onChange = function(v)
			  Spring.SetConfigInt("SimpleTeamColorsEnemyB", math.floor(v))
			  Spring.SetConfigInt("UpdateTeamColors", 1)
		  end,
		},
	}
end
