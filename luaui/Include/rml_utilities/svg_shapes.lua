-- SVG Shape Library
-- Higher-level parameterized shapes built on EzSVG.
-- All shapes return SVG strings suitable for element:SetAttribute("src", str).
-- Shapes use viewBox so they scale to fill their container via CSS sizing.

local EzSVG = VFS.Include("luaui/Include/rml_utilities/EzSVG.lua")

if not WG.rml_svg_shapes then
	WG.rml_svg_shapes = {}
end
local shapes = WG.rml_svg_shapes

-- ── Intensity presets ──
-- Named presets for depth-style parameters. Functions that accept `depth`
-- (chevron, wedge, taper) will also accept one of these string keys.
--
--   svgShapes.taper({ side = "left", depth = "subtle" })  -- same as depth = 15
--   svgShapes.taper({ side = "left", depth = 15 })        -- still works
--
-- `intensity` is the lookup hash; `intensityOrder` is the stable iteration
-- order for UIs that want to show the variants consistently (subtle → harsh).
shapes.intensity = {
	subtle = 15,
	medium = 30,
	sharp  = 50,
	harsh  = 70,
}

shapes.intensityOrder = { "subtle", "medium", "sharp", "harsh" }

-- Internal: resolve a depth value that may be a number or a preset key name.
local function resolveDepth(depth, fallback)
	if type(depth) == "string" then
		return shapes.intensity[depth] or fallback
	end
	return depth or fallback
end

-- Internal: create a viewBox-based SVG document that scales to its container.
-- coordW/coordH define the internal coordinate space (viewBox).
local function createScalableDoc(coordW, coordH)
	local doc = EzSVG.Document(coordW, coordH)
	doc["viewBox"] = "0 0 " .. coordW .. " " .. coordH
	doc["preserveAspectRatio"] = "none"
	-- Remove fixed dimensions so CSS controls the actual size
	doc["width"] = nil
	doc["height"] = nil
	return doc
end

-- ── Parallelogram ──
-- A four-sided shape with vertical edges skewed by `skew` units.
-- Positive skew leans right, negative leans left.
--   skew > 0:       skew < 0:
--     ╱──────╲       ╲──────╱
--    ╱________╲       ╲________╱
--
-- opts: { fill, stroke, stroke_width, opacity, outline }
function shapes.parallelogram(opts)
	opts = opts or {}
	local W, H = 100, 100
	local skew = opts.skew or 15
	local doc = createScalableDoc(W, H)

	local points = {}
	if skew >= 0 then
		-- Top-left, top-right, bottom-right, bottom-left
		points = { skew, 0, W, 0, W - skew, H, 0, H }
	else
		local s = math.abs(skew)
		points = { 0, 0, W - s, 0, W, H, s, H }
	end

	if opts.outline then
		doc:add(EzSVG.Polygon(points, {
			fill = opts.fill or "rgb(100, 100, 100)",
			opacity = opts.opacity and tostring(opts.opacity) or nil,
			stroke = opts.stroke or "rgb(90, 90, 95)",
			["stroke-width"] = tostring(opts.stroke_width or 0.5),
			["stroke-linejoin"] = "round",
			["stroke-opacity"] = "0.5",
		}))
	else
		doc:add(EzSVG.Polygon(points, {
			fill = opts.fill or "rgb(100, 100, 100)",
			stroke = opts.stroke or "none",
			["stroke-width"] = tostring(opts.stroke_width or 0),
			opacity = opts.opacity and tostring(opts.opacity) or nil,
		}))
	end

	return doc:tostr()
end

-- ── Chevron ──
-- A right-pointing arrow/chevron shape.
-- depth controls how deep the point is (0-50 in viewBox units).
--
--   ╱╲
--  ╱  ╲
--  ╲  ╱
--   ╲╱
--
-- opts: { fill, stroke, stroke_width, depth, opacity, outline }
function shapes.chevron(opts)
	opts = opts or {}
	local W, H = 100, 100
	local depth = resolveDepth(opts.depth, 30)
	local doc = createScalableDoc(W, H)

	local points = { 0, 0, W - depth, 0, W, H / 2, W - depth, H, 0, H, depth, H / 2 }

	if opts.outline then
		doc:add(EzSVG.Polygon(points, {
			fill = opts.fill or "rgb(100, 100, 100)",
			opacity = opts.opacity and tostring(opts.opacity) or nil,
			stroke = opts.stroke or "rgb(90, 90, 95)",
			["stroke-width"] = tostring(opts.stroke_width or 0.5),
			["stroke-linejoin"] = "round",
			["stroke-opacity"] = "0.5",
		}))
	else
		doc:add(EzSVG.Polygon(points, {
			fill = opts.fill or "rgb(100, 100, 100)",
			stroke = opts.stroke or "none",
			["stroke-width"] = tostring(opts.stroke_width or 0),
			opacity = opts.opacity and tostring(opts.opacity) or nil,
		}))
	end

	return doc:tostr()
end

-- ── Notched Rectangle ──
-- A rectangle with a diagonal cut on one or both corners.
-- cut: size of the corner notch in viewBox units.
-- corners: "tr" (top-right), "bl" (bottom-left), "both" (default)
--
--  ┌──────╲
--  │        │
--  ╱──────┘
--
-- opts: { fill, stroke, stroke_width, cut, corners, opacity, outline }
function shapes.notchedRect(opts)
	opts = opts or {}
	local W, H = 100, 100
	local cut = opts.cut or 15
	local corners = opts.corners or "both"
	local doc = createScalableDoc(W, H)

	local points
	if corners == "tr" then
		points = { 0, 0, W - cut, 0, W, cut, W, H, 0, H }
	elseif corners == "bl" then
		points = { 0, 0, W, 0, W, H, cut, H, 0, H - cut }
	else -- "both"
		points = { 0, 0, W - cut, 0, W, cut, W, H, cut, H, 0, H - cut }
	end

	if opts.outline then
		doc:add(EzSVG.Polygon(points, {
			fill = opts.fill or "rgb(100, 100, 100)",
			opacity = opts.opacity and tostring(opts.opacity) or nil,
			stroke = opts.stroke or "rgb(90, 90, 95)",
			["stroke-width"] = tostring(opts.stroke_width or 0.5),
			["stroke-linejoin"] = "round",
			["stroke-opacity"] = "0.5",
		}))
	else
		doc:add(EzSVG.Polygon(points, {
			fill = opts.fill or "rgb(100, 100, 100)",
			stroke = opts.stroke or "none",
			["stroke-width"] = tostring(opts.stroke_width or 0),
			opacity = opts.opacity and tostring(opts.opacity) or nil,
		}))
	end

	return doc:tostr()
end

-- ── Diamond ──
-- A rotated square / rhombus.
--
-- opts: { fill, stroke, stroke_width, opacity, outline }
function shapes.diamond(opts)
	opts = opts or {}
	local W, H = 100, 100
	local doc = createScalableDoc(W, H)

	local points = { W / 2, 0, W, H / 2, W / 2, H, 0, H / 2 }

	if opts.outline then
		doc:add(EzSVG.Polygon(points, {
			fill = opts.fill or "rgb(100, 100, 100)",
			opacity = opts.opacity and tostring(opts.opacity) or nil,
			stroke = opts.stroke or "rgb(90, 90, 95)",
			["stroke-width"] = tostring(opts.stroke_width or 0.5),
			["stroke-linejoin"] = "round",
			["stroke-opacity"] = "0.5",
		}))
	else
		doc:add(EzSVG.Polygon(points, {
			fill = opts.fill or "rgb(100, 100, 100)",
			stroke = opts.stroke or "none",
			["stroke-width"] = tostring(opts.stroke_width or 0),
			opacity = opts.opacity and tostring(opts.opacity) or nil,
		}))
	end

	return doc:tostr()
end

-- ── Hexagon ──
-- A regular hexagon (flat-top orientation).
--
-- opts: { fill, stroke, stroke_width, opacity, outline }
function shapes.hexagon(opts)
	opts = opts or {}
	local W, H = 100, 100
	local doc = createScalableDoc(W, H)

	local inset = W * 0.25
	local points = { inset, 0, W - inset, 0, W, H / 2, W - inset, H, inset, H, 0, H / 2 }

	if opts.outline then
		doc:add(EzSVG.Polygon(points, {
			fill = opts.fill or "rgb(100, 100, 100)",
			opacity = opts.opacity and tostring(opts.opacity) or nil,
			stroke = opts.stroke or "rgb(90, 90, 95)",
			["stroke-width"] = tostring(opts.stroke_width or 0.5),
			["stroke-linejoin"] = "round",
			["stroke-opacity"] = "0.5",
		}))
	else
		doc:add(EzSVG.Polygon(points, {
			fill = opts.fill or "rgb(100, 100, 100)",
			stroke = opts.stroke or "none",
			["stroke-width"] = tostring(opts.stroke_width or 0),
			opacity = opts.opacity and tostring(opts.opacity) or nil,
		}))
	end

	return doc:tostr()
end

-- ── Corner Notch ──
-- A chamfered rectangle — fills the viewBox with one corner cut diagonally.
-- corner: "tr", "tl", "br", "bl" — which corner gets the diagonal cut
-- size: depth of the chamfer in viewBox units (default 30 out of 100)
--
-- Example (tr):  ╱────┐
--               │     │
--               └─────┘
--
-- opts: { corner, size, fill, stroke, stroke_width, opacity }
function shapes.notchedCorner(opts)
	opts = opts or {}
	local W, H = 100, 100
	local sx = opts.sizeX or opts.size or 30  -- horizontal depth of cut
	local sy = opts.sizeY or opts.size or 20  -- vertical depth of cut
	local corner = opts.corner or "tr"
	local doc = createScalableDoc(W, H)

	-- Rectangle with one corner chamfered asymmetrically
	local points
	if corner == "tr" then
		points = { 0, 0, W - sx, 0, W, sy, W, H, 0, H }
	elseif corner == "tl" then
		points = { sx, 0, W, 0, W, H, 0, H, 0, sy }
	elseif corner == "br" then
		points = { 0, 0, W, 0, W, H - sy, W - sx, H, 0, H }
	elseif corner == "bl" then
		points = { 0, 0, W, 0, W, H, sx, H, 0, H - sy }
	end

	if points then
		local strokeColor = opts.stroke or "rgb(90, 90, 95)"
		local strokeWidth = tostring(opts.stroke_width or 0.5)

		if opts.outline then
			-- Stroke the full perimeter
			doc:add(EzSVG.Polygon(points, {
				fill = opts.fill or "rgb(55, 55, 60)",
				opacity = opts.opacity and tostring(opts.opacity) or "0.8",
				stroke = strokeColor,
				["stroke-width"] = strokeWidth,
				["stroke-linejoin"] = "round",
				["stroke-opacity"] = "0.5",
			}))
		else
			-- Fill only, no stroke
			doc:add(EzSVG.Polygon(points, {
				fill = opts.fill or "rgb(55, 55, 60)",
				opacity = opts.opacity and tostring(opts.opacity) or "0.8",
			}))
		end
	end

	return doc:tostr()
end

-- ── Wedge ──
-- A rectangle with one side coming to a centered point (arrow/pentagon shape).
-- side: which side has the point ("left", "right", "top", "bottom")
-- depth: how far the point extends inward (default 25 in viewBox units)
--
-- Example (left):    ┌──────────┐
--                   ╱            │
--                  ╳             │
--                   ╲            │
--                    └──────────┘
--
-- opts: { side, depth, fill, stroke, stroke_width, opacity, outline }
function shapes.wedge(opts)
	opts = opts or {}
	local W, H = 100, 100
	local d = resolveDepth(opts.depth, 25)
	local side = opts.side or opts.corner or "left"
	local doc = createScalableDoc(W, H)

	local points
	if side == "left" or side == "bl" then
		points = { d, 0, W, 0, W, H, d, H, 0, H / 2 }
	elseif side == "right" or side == "br" then
		points = { 0, 0, W - d, 0, W, H / 2, W - d, H, 0, H }
	elseif side == "top" or side == "tl" then
		points = { 0, d, W / 2, 0, W, d, W, H, 0, H }
	elseif side == "bottom" or side == "tr" then
		points = { 0, 0, W, 0, W, H - d, W / 2, H, 0, H - d }
	end

	if points then
		local strokeColor = opts.stroke or "rgb(90, 90, 95)"
		local strokeWidth = tostring(opts.stroke_width or 0.5)

		if opts.outline then
			doc:add(EzSVG.Polygon(points, {
				fill = opts.fill or "rgb(55, 55, 60)",
				opacity = opts.opacity and tostring(opts.opacity) or "0.8",
				stroke = strokeColor,
				["stroke-width"] = strokeWidth,
				["stroke-linejoin"] = "round",
				["stroke-opacity"] = "0.5",
			}))
		else
			doc:add(EzSVG.Polygon(points, {
				fill = opts.fill or "rgb(55, 55, 60)",
				opacity = opts.opacity and tostring(opts.opacity) or "0.8",
			}))
		end
	end

	return doc:tostr()
end

-- ── Taper ──
-- A rectangle with one side angled inward — a trapezoid.
-- side: which side tapers ("left", "right", "top", "bottom")
-- depth: how far the taper cuts in (default 30 in viewBox units)
-- flip: for "left" and "right" sides, mirror the angle vertically so the
--       taper is wide at the BOTTOM instead of the top (i.e. the angled
--       corner is at the TOP of the tapered side instead of the bottom).
--       Ignored for "top"/"bottom" sides (use the opposite side instead).
--
-- Example (right, default):     Example (right, flip=true):
--   ┌──────────┐                   ┌────────┐
--   │           ╲                  │         ╲
--   │            ╲                 │          ╲
--   │            ╱                 │           ╲
--   │           ╱                  │            ╲
--   └──────────┘                   └─────────────┘
--   wide at top                    wide at bottom
--
-- opts: { side, depth, fill, stroke, stroke_width, opacity, outline, flip }
function shapes.taper(opts)
	opts = opts or {}
	local W, H = 100, 100
	local d = resolveDepth(opts.depth, 30)
	local side = opts.side or "left"
	local flip = opts.flip
	local doc = createScalableDoc(W, H)

	local points
	if side == "left" then
		if flip then
			-- Top-left corner pulled inward; wide end at bottom.
			points = { d, 0, W, 0, W, H, 0, H }
		else
			-- Bottom-left corner pulled inward; wide end at top (default).
			points = { 0, 0, W, 0, W, H, d, H }
		end
	elseif side == "right" then
		if flip then
			-- Top-right corner pulled inward; wide end at bottom.
			points = { 0, 0, W - d, 0, W, H, 0, H }
		else
			-- Bottom-right corner pulled inward; wide end at top (default).
			points = { 0, 0, W, 0, W - d, H, 0, H }
		end
	elseif side == "top" then
		points = { d, 0, W - d, 0, W, H, 0, H }
	elseif side == "bottom" then
		points = { 0, 0, W, 0, W - d, H, d, H }
	end

	if points then
		local strokeColor = opts.stroke or "rgb(90, 90, 95)"
		local strokeWidth = tostring(opts.stroke_width or 0.5)

		if opts.outline then
			doc:add(EzSVG.Polygon(points, {
				fill = opts.fill or "rgb(55, 55, 60)",
				opacity = opts.opacity and tostring(opts.opacity) or "0.8",
				stroke = strokeColor,
				["stroke-width"] = strokeWidth,
				["stroke-linejoin"] = "round",
				["stroke-opacity"] = "0.5",
			}))
		else
			doc:add(EzSVG.Polygon(points, {
				fill = opts.fill or "rgb(55, 55, 60)",
				opacity = opts.opacity and tostring(opts.opacity) or "0.8",
			}))
		end
	end

	return doc:tostr()
end

-- ── Wedge Clip ──
-- Combines a clip (chamfer) on one corner with a sharp point on the adjacent
-- corner of the same side. The opposite side stays flat.
--
-- side: which side has the point+chamfer ("left", "right", "top", "bottom")
-- sizeX/sizeY: chamfer dimensions
-- pointDepth: how far the point extends beyond the edge (default 15)
--
-- Example (left):     ┌──────────┐
--                    ╱            │
--                   ╱             │
--                  ╳              │
--                   ╲             │
--                    ╲     ╱─────┘
--                     ╲───╱
--
-- The point is at the top of the left side, chamfer at the bottom.
--
-- opts: { side, sizeX, sizeY, pointDepth, fill, stroke, stroke_width, opacity, outline }
function shapes.wedgeClip(opts)
	opts = opts or {}
	local W, H = 100, 100
	local sx = opts.sizeX or opts.size or 45
	local sy = opts.sizeY or opts.size or 30
	local pd = opts.pointDepth or 15
	local side = opts.side or "left"
	local doc = createScalableDoc(W, H)

	local points
	if side == "left" then
		-- point top-left, chamfer bottom-left
		points = { pd, 0, W, 0, W, H, sx, H, 0, H - sy }
	elseif side == "right" then
		-- point top-right, chamfer bottom-right
		points = { 0, 0, W - pd, 0, W, sy, W, H - sy, W - sx, H, 0, H }
	elseif side == "top" then
		-- point top-left, chamfer top-right
		points = { 0, pd, sx, 0, W - sx, 0, W, pd, W, H, 0, H }
	elseif side == "bottom" then
		-- point bottom-left, chamfer bottom-right
		points = { 0, 0, W, 0, W, H - pd, W - sx, H, sx, H, 0, H - pd }
	end

	if points then
		local strokeColor = opts.stroke or "rgb(90, 90, 95)"
		local strokeWidth = tostring(opts.stroke_width or 0.5)

		if opts.outline then
			doc:add(EzSVG.Polygon(points, {
				fill = opts.fill or "rgb(55, 55, 60)",
				opacity = opts.opacity and tostring(opts.opacity) or "0.8",
				stroke = strokeColor,
				["stroke-width"] = strokeWidth,
				["stroke-linejoin"] = "round",
				["stroke-opacity"] = "0.5",
			}))
		else
			doc:add(EzSVG.Polygon(points, {
				fill = opts.fill or "rgb(55, 55, 60)",
				opacity = opts.opacity and tostring(opts.opacity) or "0.8",
			}))
		end
	end

	return doc:tostr()
end

return shapes
