-- SVG Decorators
-- Reusable chrome decorator vocabulary for RML widgets.
-- Thin wrapper over svg_shapes.lua that produces cached SVG strings for the
-- common BAR chrome shapes (panel chamfers, title bar accents, active-tab
-- tapers). Consumers inject the returned strings via element:SetAttribute("src", ...).
--
-- This module is a shape vocabulary, not a theme engine. Color tables stay
-- with the consumer widget. Add new shapes here only when a second widget
-- needs them.

local svgShapes = VFS.Include("luaui/Include/rml_utilities/svg_shapes.lua")

local M = {}
local cache = {}

local function cached(key, builder)
	if cache[key] == nil then
		cache[key] = builder()
	end
	return cache[key]
end

local function colorKey(colors, ...)
	local parts = { ... }
	for i = 1, #parts do
		parts[i] = tostring(colors[parts[i]] or "")
	end
	return table.concat(parts, "|")
end

-- Clear cache — call from a widget's Reload() handler if color palettes may
-- have been edited on the fly.
function M.clearCache()
	cache = {}
end

return M
