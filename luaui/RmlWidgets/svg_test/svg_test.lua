if not RmlUi then
	return
end

local widget = widget ---@type Widget
local utils = VFS.Include("luaui/Include/rml_utilities/utils.lua")
local EzSVG = VFS.Include("luaui/Include/rml_utilities/EzSVG.lua")
local svgShapes = VFS.Include("luaui/Include/rml_utilities/svg_shapes.lua")

-- Title-bar angle decorator: a small tapered dark block that sits behind the
-- debug-controls buttons at top-right of the header. Same pattern used by
-- widget_controller — SVG for crisp angled edges, element size matches the
-- visible content, slight negative top/right so stroke pixels at the viewBox
-- boundary get clipped by the parent edge instead of bleeding through.
local function buildAngleDecoratorSVG()
	return svgShapes.taper({
		side = "left",
		depth = "medium",
		fill = "rgb(6, 6, 6)",
		opacity = 0.73,
		stroke = "rgb(250, 212, 0)",
		stroke_width = 1,
		outline = true,
	})
end

function widget:GetInfo()
	return {
		name = "SVG Test",
		desc = "Probes different approaches for dynamic SVG in RmlUi",
		author = "mupersega",
		date = "2025",
		license = "GNU GPL, v2 or later",
		layer = -10000,
		enabled = false,
	}
end

local WIDGET_ID = "svg_test"
local MODEL_NAME = "svg_test_model"
local RML_PATH = "luaui/RmlWidgets/svg_test/svg_test.rml"
local GENERATED_SVG_PATH = "luaui/RmlWidgets/svg_test/generated_test.svg"

local document
local dm_handle

local dynamicSvgEl
local graphSvgEl
local animTime = 0
local animFrameCount = 0

local spGetTimer = Spring.GetTimer
local spDiffTimers = Spring.DiffTimers
local initTimer

-- Animation state
local animRunning = false
local animSkip = 1

-- Cached value of the "RML Debug Controls" dev flag
local lastRmlDebug = nil

-- Graph state
local CONFIG_SMOOTH = "svg_test_smooth_graphs"
local graphData = nil        -- array of player tables
local graphSmooth = Spring.GetConfigInt(CONFIG_SMOOTH, 0) == 1
local graphSweepRunning = false
local graphSweepFrame = 0
local graphSweepTotalFrames = 0
local graphPointCount = 0
local graphMaxScore = 0      -- locked Y-axis scale from full dataset

-- Wind particle field state (post-apocalyptic ambient debris)
-- A small playground for basic Newtonian physics with layered chaotic forces.
--
-- Physics:    F = m·a  →  a = (baseWind(t) + flowField(x,y,t)) / mass
-- Integration: v += a·dt - drag·v·dt ; x += v·dt
--
-- Two force sources compete:
--  1. baseWind(t): global ambient wind whose direction rotates and whose
--     strength gusts/lulls on layered sinusoids. Drives the overall flow.
--  2. flowField(x,y,t): multi-frequency spatial noise that varies per-position
--     and drifts over time. Drives eddies, turbulence, local swirls.
-- Their magnitudes are comparable so the flow field can briefly overpower
-- the base wind in turbulent zones — particles get genuinely flustered.
--
-- Heavy particles (mass = size²) plod through the chaos with momentum; light
-- particles snap to local flow and visibly whip around.
--
-- Performance: physics + SVG rebuild run on a 30fps accumulator throttle
-- rather than every engine tick. The expensive part is SetAttribute("src"...)
-- which re-parses SVG — halving the rate halves that cost. Halved tick rate
-- is the budget that lets us afford the beefier force math and more particles.
--
-- All tuning knobs are inline here — edit and reload to iterate.
local WIND_VIEWBOX_W      = 400
local WIND_VIEWBOX_H      = 140
local WIND_BASE_STRENGTH  = 85     -- peak base-wind magnitude (viewBox units/sec²)
local WIND_DRAG           = 0.25   -- velocity damping per second (lower = more momentum)
local WIND_STEP           = 1 / 30 -- seconds between physics+render updates (~30fps)
local WIND_PERSPECTIVE    = 0.3    -- depth falloff; scale = 1/(1 + z*persp). Higher = more dramatic.

-- Particle count is tied to the actual in-game wind strength, not a graphics
-- setting. We read Spring.GetWind() and linearly map the current strength
-- within the map's [Game.windMin .. Game.windMax] range to a particle count
-- in [WIND_PARTICLE_MIN .. WIND_PARTICLE_MAX]. Calm maps show a sparse field,
-- windy maps show a dense one, and the count updates periodically during
-- gameplay as wind cycles. WIND_CHECK_INTERVAL throttles the re-sample so
-- we're not doing array resize work every physics step.
local WIND_PARTICLE_MIN    = 3     -- never fewer than this (calm / no-wind maps)
local WIND_PARTICLE_MAX    = 25    -- maxed out at peak wind
local WIND_CHECK_INTERVAL  = 0.5   -- seconds between wind re-samples
local windParticleCount    = WIND_PARTICLE_MIN  -- mutable, recomputed from wind
local windLastCheck        = 0     -- windTime of last wind re-sample
local WIND_COLORS = {
	"rgb(120, 110, 95)",   -- dusty tan
	"rgb(90, 85, 75)",     -- dark ash
	"rgb(140, 105, 80)",   -- rust / sienna
	"rgb(160, 150, 130)",  -- light dust
	"rgb(70, 65, 55)",     -- near-black char
	"rgb(180, 140, 60)",   -- muted warning amber
}
local windRunning   = false
local windEl                  -- cached element ref, populated in Initialize
local windParticles = {}      -- array of particle tables
local windAccum     = 0       -- dt accumulator for the 30fps throttle
local windTime      = 0       -- elapsed sim time, fed to the flow field

-- Filter state
local graphSelected = {}     -- [playerIndex] = true/false, empty = show all
local graphMyIndex = 1       -- "your" player, always at top of filter list
local graphHasSelection = false -- true if any player is explicitly selected

-- Sweep config
local sweepDurationMode = "auto" -- "auto", "1", "3", "5", "10"
local sweepEasing = "easeInOutCubic"

local FPS_ESTIMATE = 60

-- Auto-duration: sqrt curve mapping point count to seconds
-- ~20 points (short game) -> ~2s, ~60 points -> ~3.5s, ~120 points -> ~5s, ~200 points -> ~6.3s
local function calcAutoDuration(pointCount)
	return math.max(1.5, math.sqrt(pointCount) * 0.45)
end

local function getSweepDuration()
	if sweepDurationMode == "auto" then
		return calcAutoDuration(graphPointCount)
	end
	return tonumber(sweepDurationMode) or 3
end

local function log(msg)
	Spring.Echo("[SVG Test] " .. msg)
end

-- ── Easing functions ──

local function linear(t)
	return t
end

local function easeInOutCubic(t)
	if t < 0.5 then
		return 4 * t * t * t
	else
		local f = 2 * t - 2
		return 0.5 * f * f * f + 1
	end
end

local function easeOutBounce(t)
	if t < 1 / 2.75 then
		return 7.5625 * t * t
	elseif t < 2 / 2.75 then
		t = t - 1.5 / 2.75
		return 7.5625 * t * t + 0.75
	elseif t < 2.5 / 2.75 then
		t = t - 2.25 / 2.75
		return 7.5625 * t * t + 0.9375
	else
		t = t - 2.625 / 2.75
		return 7.5625 * t * t + 0.984375
	end
end

local function easeOutElastic(t)
	if t == 0 or t == 1 then return t end
	return math.pow(2, -10 * t) * math.sin((t - 0.075) * (2 * math.pi) / 0.3) + 1
end

local function easeInOutQuad(t)
	if t < 0.5 then
		return 2 * t * t
	else
		return -1 + (4 - 2 * t) * t
	end
end

local EASING_FUNCTIONS = {
	linear = linear,
	easeInOutCubic = easeInOutCubic,
	easeInOutQuad = easeInOutQuad,
	easeOutBounce = easeOutBounce,
	easeOutElastic = easeOutElastic,
}

local EASING_NAMES = { "linear", "easeInOutQuad", "easeInOutCubic", "easeOutBounce", "easeOutElastic" }

-- ── Catmull-Rom spline for data smoothing ──

local function catmullRom(p0, p1, p2, p3, t)
	local t2 = t * t
	local t3 = t2 * t
	return 0.5 * (
		(2 * p1) +
		(-p0 + p2) * t +
		(2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 +
		(-p0 + 3 * p1 - 3 * p2 + p3) * t3
	)
end

local function smoothScores(scores, subdivisions)
	local n = #scores
	if n < 2 then return scores end
	subdivisions = subdivisions or 3

	local result = {}
	for i = 1, n - 1 do
		local p0 = scores[math.max(1, i - 1)]
		local p1 = scores[i]
		local p2 = scores[math.min(n, i + 1)]
		local p3 = scores[math.min(n, i + 2)]

		result[#result + 1] = p1
		for s = 1, subdivisions - 1 do
			local t = s / subdivisions
			result[#result + 1] = math.max(0, catmullRom(p0, p1, p2, p3, t))
		end
	end
	result[#result + 1] = scores[n]
	return result
end

-- ── Dynamic animation SVG ──

local function buildAnimatedSvg(t)
	local W, H = 200, 120
	local doc = EzSVG.Document(W, H)

	doc:add(EzSVG.Rect(0, 0, W, H, 4, 4, {
		fill = "rgb(15, 15, 25)",
	}))

	local barGroup = EzSVG.Group()
	local barCount = 32
	local barWidth = (W - 20) / barCount
	for i = 0, barCount - 1 do
		local x = 10 + i * barWidth
		local phase = t * 3 + i * 0.3
		local barH = 10 + math.abs(math.sin(phase)) * (H - 30)
		local hue = math.floor((i / barCount) * 255)

		barGroup:add(EzSVG.Rect(x, H - barH - 5, barWidth - 1, barH, 1, 1, {
			fill = EzSVG.hsv(hue, 200, 220),
			opacity = tostring(0.6 + 0.4 * math.abs(math.sin(phase))),
		}))
	end
	doc:add(barGroup)

	local cx = W / 2 + math.cos(t * 2) * 60
	local cy = H / 2 + math.sin(t * 2) * 25
	local pulse = 6 + math.sin(t * 5) * 3
	doc:add(EzSVG.Circle(cx, cy, pulse, {
		fill = "rgb(255, 255, 255)",
		opacity = "0.9",
	}))
	doc:add(EzSVG.Circle(cx, cy, pulse + 4, {
		fill = "none",
		stroke = "rgb(43, 165, 234)",
		["stroke-width"] = "2",
		opacity = tostring(0.4 + 0.3 * math.sin(t * 5)),
	}))

	return doc:tostr()
end

-- ── Score graph SVG ──

local GRAPH_COLORS = {
	"rgb(43, 165, 234)",
	"rgb(239, 68, 68)",
	"rgb(34, 197, 94)",
	"rgb(250, 212, 0)",
	"rgb(168, 85, 247)",
	"rgb(251, 146, 60)",
	"rgb(236, 72, 153)",
	"rgb(20, 184, 166)",
}

local PLAYER_NAMES = {
	"Alpha", "Bravo", "Charlie", "Delta",
	"Echo", "Foxtrot", "Golf", "Hotel",
}

local function generateScoreData()
	local playerCount = 3 + math.floor(math.random() * 6)
	local pointCount = 20 + math.floor(math.random() * 180) -- 20-199 points (short skirmish to long game)
	local players = {}
	for p = 1, playerCount do
		local scores = {}
		local score = math.random(50, 200)
		for i = 1, pointCount do
			score = math.max(0, score + math.random(-30, 50))
			scores[i] = score
		end
		players[p] = {
			name = PLAYER_NAMES[p] or ("P" .. p),
			color = GRAPH_COLORS[((p - 1) % #GRAPH_COLORS) + 1],
			scores = scores,
		}
	end
	return players, pointCount
end

local function buildGraphSvg(players, revealFraction, smooth, fixedMaxScore)
	local W, H = 500, 200
	local PAD_LEFT, PAD_RIGHT, PAD_TOP, PAD_BOTTOM = 40, 15, 10, 30
	local gw = W - PAD_LEFT - PAD_RIGHT
	local gh = H - PAD_TOP - PAD_BOTTOM

	local doc = EzSVG.Document(W, H)
	doc:add(EzSVG.Rect(0, 0, W, H, 4, 4, { fill = "rgb(15, 15, 25)" }))

	local rawPointCount = 0
	for _, player in ipairs(players) do
		rawPointCount = math.max(rawPointCount, #player.scores)
	end
	if rawPointCount < 2 then return doc:tostr() end

	local maxScore = fixedMaxScore or 0
	if maxScore == 0 then
		for _, player in ipairs(players) do
			for _, s in ipairs(player.scores) do
				if s > maxScore then maxScore = s end
			end
		end
	end
	if maxScore == 0 then maxScore = 1 end

	local SUBDIVISIONS = 4
	local drawPlayers = {}
	for _, player in ipairs(players) do
		local scores = player.scores
		if smooth then
			scores = smoothScores(scores, SUBDIVISIONS)
		end
		drawPlayers[#drawPlayers + 1] = {
			name = player.name,
			color = player.color,
			scores = scores,
		}
	end

	local pointCount = smooth
		and ((rawPointCount - 1) * SUBDIVISIONS + 1)
		or rawPointCount

	local drawCount = pointCount
	if revealFraction and revealFraction < 1.0 then
		drawCount = math.max(1, math.floor(revealFraction * pointCount))
	end

	-- Grid
	local gridGroup = EzSVG.Group()
	local gridSteps = 4
	for i = 0, gridSteps do
		local y = PAD_TOP + gh - (i / gridSteps) * gh
		gridGroup:add(EzSVG.Line(PAD_LEFT, y, W - PAD_RIGHT, y, {
			stroke = "rgb(60, 60, 80)",
			["stroke-width"] = "0.5",
		}))
		gridGroup:add(EzSVG.Text(tostring(math.floor(maxScore * i / gridSteps)), PAD_LEFT - 5, y + 3, {
			fill = "rgb(120, 120, 140)",
			["font-size"] = "8",
			["text-anchor"] = "end",
		}))
	end
	doc:add(gridGroup)

	-- X-axis labels
	local xLabelGroup = EzSVG.Group()
	local xSteps = math.min(rawPointCount - 1, 6)
	for i = 0, xSteps do
		local idx = math.floor(i / xSteps * (rawPointCount - 1)) + 1
		local x = PAD_LEFT + ((idx - 1) / (rawPointCount - 1)) * gw
		xLabelGroup:add(EzSVG.Text(tostring(idx), x, H - PAD_BOTTOM + 15, {
			fill = "rgb(120, 120, 140)",
			["font-size"] = "8",
			["text-anchor"] = "middle",
		}))
	end
	doc:add(xLabelGroup)

	-- Sweep cursor
	if drawCount < pointCount then
		local cursorX = PAD_LEFT + ((drawCount - 1) / (pointCount - 1)) * gw
		doc:add(EzSVG.Line(cursorX, PAD_TOP, cursorX, PAD_TOP + gh, {
			stroke = "rgb(255, 255, 255)",
			["stroke-width"] = "0.5",
			opacity = "0.3",
		}))
	end

	-- Lines
	for _, player in ipairs(drawPlayers) do
		if #player.scores >= 1 then
			local path = EzSVG.Path({
				fill = "none",
				stroke = player.color,
				["stroke-width"] = "1.5",
				["stroke-linejoin"] = "round",
			})

			local limit = math.min(drawCount, #player.scores)
			for i = 1, limit do
				local x = PAD_LEFT + ((i - 1) / (pointCount - 1)) * gw
				local y = PAD_TOP + gh - (player.scores[i] / maxScore) * gh
				if i == 1 then
					path:moveToA(x, y)
				else
					path:lineToA(x, y)
				end
			end
			doc:add(path)

			if drawCount < pointCount and limit >= 1 then
				local tipX = PAD_LEFT + ((limit - 1) / (pointCount - 1)) * gw
				local tipY = PAD_TOP + gh - (player.scores[limit] / maxScore) * gh
				doc:add(EzSVG.Circle(tipX, tipY, 2.5, { fill = player.color }))
			end
		end
	end

	-- Progress
	if drawCount < pointCount then
		local pct = math.floor((drawCount / pointCount) * 100)
		doc:add(EzSVG.Text(pct .. "%", W - PAD_RIGHT - 5, PAD_TOP + 10, {
			fill = "rgb(200, 200, 200)",
			["font-size"] = "10",
			["text-anchor"] = "end",
		}))
	end

	return doc:tostr()
end

-- ── Static test helpers ──

local function generateTestSvg()
	local doc = EzSVG.Document(100, 100)
	doc:add(EzSVG.Circle(50, 50, 40, {
		fill = "rgb(43, 165, 234)",
		stroke = "rgb(255, 255, 255)",
		["stroke-width"] = "2",
	}))
	doc:add(EzSVG.Rect(25, 25, 50, 50, 4, 4, {
		fill = "rgb(250, 212, 0)",
		opacity = "0.6",
	}))
	return doc
end

local function generateSimpleSvgString()
	return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="100" height="100">'
		.. '<circle cx="50" cy="50" r="40" fill="rgb(34,197,94)" stroke="white" stroke-width="2"/>'
		.. '<rect x="30" y="30" width="40" height="40" rx="4" fill="rgb(239,68,68)" opacity="0.7"/>'
		.. '</svg>'
end

-- ── Filtering ──

local function getFilteredPlayers()
	if not graphData then return {} end
	if not graphHasSelection then return graphData end

	local filtered = {}
	for i, player in ipairs(graphData) do
		if graphSelected[i] then
			filtered[#filtered + 1] = player
		end
	end
	return filtered
end

local function updatePlayerListModel()
	if not dm_handle or not graphData then return end
	-- Rebuild the playerList array on the model
	-- Order: "my" player first, then rest
	local list = {}
	-- Add "my" player first
	if graphData[graphMyIndex] then
		list[#list + 1] = {
			index = tostring(graphMyIndex),
			name = graphData[graphMyIndex].name,
			color = graphData[graphMyIndex].color,
			selected = graphSelected[graphMyIndex] and true or false,
			isMe = true,
		}
	end
	-- Add the rest
	for i, player in ipairs(graphData) do
		if i ~= graphMyIndex then
			list[#list + 1] = {
				index = tostring(i),
				name = player.name,
				color = player.color,
				selected = graphSelected[i] and true or false,
				isMe = false,
			}
		end
	end
	dm_handle.playerList = list
end

-- ── Render ──

local function renderGraph()
	if not graphData or not graphSvgEl then return end
	local fraction = nil
	if graphSweepRunning and graphSweepTotalFrames > 0 then
		local linearT = math.min(1.0, graphSweepFrame / graphSweepTotalFrames)
		local easeFn = EASING_FUNCTIONS[sweepEasing] or easeInOutCubic
		fraction = easeFn(linearT)
	end
	local players = getFilteredPlayers()
	graphSvgEl:SetAttribute("src", buildGraphSvg(players, fraction, graphSmooth, graphMaxScore))
end

-- ── Data model ──

local function initModel()
	return {
		animRunning = false,
		graphSweepRunning = false,
		graphSmooth = graphSmooth,
		sweepDurationMode = "auto",
		sweepEasing = "easeInOutCubic",
		sweepInfo = "",
		playerList = {},
		rmlDebugControls = false,
		windRunning = false,

		my = {
			sectionLabel = "text-xs text-medium mb-1",
			optBtn = "px-2 py-0-5 text-xs cursor-pointer",
		},

		toggleAnim = function()
			animRunning = not animRunning
			dm_handle.animRunning = animRunning
			if animRunning then
				initTimer = spGetTimer()
				animFrameCount = 0
			end
		end,

		toggleWind = function()
			windRunning = not windRunning
			dm_handle.windRunning = windRunning
			if windRunning then
				-- Fresh start — avoid accumulator carrying a big dt from
				-- the stopped period, which would cause a physics jump.
				windAccum = 0
			end
		end,

		generateGraph = function()
			local players, pointCount = generateScoreData()
			graphData = players
			graphPointCount = pointCount
			graphSweepRunning = false
			graphSweepFrame = 0

			-- Compute fixed Y-axis scale from full dataset
			graphMaxScore = 0
			for _, player in ipairs(players) do
				for _, s in ipairs(player.scores) do
					if s > graphMaxScore then graphMaxScore = s end
				end
			end

			-- Reset filters — no selection = show all
			graphSelected = {}
			graphHasSelection = false
			graphMyIndex = math.random(1, #players)

			local dur = getSweepDuration()
			dm_handle.graphSweepRunning = false
			dm_handle.sweepInfo = pointCount .. " pts / " .. string.format("%.1fs", dur)
			updatePlayerListModel()
			renderGraph()
			log("Generated graph: " .. #players .. " players, " .. pointCount .. " points, you=" .. players[graphMyIndex].name)
		end,

		toggleSweep = function()
			if not graphData then return end

			graphSweepRunning = not graphSweepRunning
			dm_handle.graphSweepRunning = graphSweepRunning

			if graphSweepRunning then
				graphSweepFrame = 0
				local dur = getSweepDuration()
				graphSweepTotalFrames = math.floor(dur * FPS_ESTIMATE)
				dm_handle.sweepInfo = graphPointCount .. " pts / " .. string.format("%.1fs", dur)
			end
			renderGraph()
		end,

		toggleSmooth = function()
			graphSmooth = not graphSmooth
			dm_handle.graphSmooth = graphSmooth
			Spring.SetConfigInt(CONFIG_SMOOTH, graphSmooth and 1 or 0)
			renderGraph()
		end,

		setDuration = function(event, mode)
			sweepDurationMode = mode
			dm_handle.sweepDurationMode = mode
			local dur = getSweepDuration()
			dm_handle.sweepInfo = graphPointCount .. " pts / " .. string.format("%.1fs", dur)
		end,

		setEasing = function(event, name)
			if not EASING_FUNCTIONS[name] then return end
			sweepEasing = name
			dm_handle.sweepEasing = name
		end,

		togglePlayer = function(event, indexStr)
			if not graphData then return end
			local idx = tonumber(indexStr)
			if not idx or not graphData[idx] then return end

			if not graphHasSelection then
				-- First click: solo this player
				graphSelected = {}
				graphSelected[idx] = true
				graphHasSelection = true
			else
				-- Toggle this player
				graphSelected[idx] = not graphSelected[idx] or nil

				-- Check if anyone is still selected
				graphHasSelection = false
				for _ in pairs(graphSelected) do
					graphHasSelection = true
					break
				end
			end

			updatePlayerListModel()
			renderGraph()
		end,
	}
end

-- ── Wind particle helpers ──

local function windRand(lo, hi)
	return lo + (hi - lo) * math.random()
end

-- Build one particle with randomized properties.
-- startFromRight=true places it just past the right edge (respawn case);
-- false scatters it randomly across the canvas (initial population).
local function spawnWindParticle(startFromRight)
	local size = windRand(1, 2.5)
	local nVerts = 5
	-- Local-space vertices: 5 points around the particle center with jittered
	-- radii, giving each particle a unique chunky debris silhouette.
	local verts = {}
	for i = 0, nVerts - 1 do
		local angle = (i / nVerts) * 2 * math.pi
		local r = size * windRand(0.6, 1.2)
		verts[#verts + 1] = r * math.cos(angle)
		verts[#verts + 1] = r * math.sin(angle)
	end
	return {
		x        = startFromRight and (WIND_VIEWBOX_W + windRand(10, 60))
		                          or windRand(0, WIND_VIEWBOX_W),
		y        = windRand(10, WIND_VIEWBOX_H - 10),
		z        = windRand(0, 6),        -- depth: 0 = near camera, higher = further away
		vx       = windRand(-40, -10),    -- already drifting leftward on spawn
		vy       = windRand(-8, 8),
		vz       = windRand(-0.4, 0.4),   -- depth drift velocity (slow in/out)
		mass     = size * size * 0.5,     -- proportional to area → heavy plods, light zips
		size     = size,
		rotation = windRand(0, 360),
		vrot     = windRand(-180, 180),   -- degrees per second (wild tumble)
		color    = WIND_COLORS[math.random(#WIND_COLORS)],
		opacity  = windRand(0.4, 0.85),
		verts    = verts,
	}
end

-- Compute target particle count from the current in-game wind strength.
-- Returns an integer in [WIND_PARTICLE_MIN .. WIND_PARTICLE_MAX]. Handles
-- no-wind maps (windMin == windMax) without divide-by-zero.
local function computeTargetWindCount()
	local currentStrength = select(4, Spring.GetWind()) or 0
	local range = math.max(0.1, (Game.windMax or 0) - (Game.windMin or 0))
	local normalized = math.max(0, math.min(1,
		(currentStrength - (Game.windMin or 0)) / range))
	return math.floor(WIND_PARTICLE_MIN
		+ normalized * (WIND_PARTICLE_MAX - WIND_PARTICLE_MIN) + 0.5)
end

-- Grow or shrink windParticles in place to match `target`. New particles
-- spawn from the right edge (fresh entrants). Trimmed particles are just
-- discarded from the tail. No reordering, no reallocation beyond the
-- append/pop operations.
local function resizeWindParticles(target)
	while #windParticles < target do
		windParticles[#windParticles + 1] = spawnWindParticle(true)
	end
	while #windParticles > target do
		windParticles[#windParticles] = nil
	end
	windParticleCount = target
end

local function initWindParticles()
	windParticles = {}
	for i = 1, windParticleCount do
		windParticles[i] = spawnWindParticle(false)  -- pre-scatter across canvas
	end
end

-- Ambient base wind. Direction rotates and strength gusts over time, via
-- layered oscillators at different frequencies so the combined motion feels
-- unpredictable rather than cyclic. Direction is clamped to ±0.9 radians
-- (~±51°) from straight-left so particles still broadly drift right-to-left
-- on average — but within that envelope, direction and magnitude swing hard.
-- Gust coefficient ranges roughly 0.3..1.7, so strength oscillates between
-- ~25 and ~145 units — lulls where particles coast on momentum, pulses where
-- they get genuinely launched.
local function baseWind(t)
	local dirAngle = math.sin(t * 0.35) * 0.7 + math.cos(t * 0.80) * 0.3
	local gust     = 1.0 + 0.4 * math.sin(t * 0.60) + 0.3 * math.cos(t * 1.20 + 0.8)
	local strength = WIND_BASE_STRENGTH * gust
	local fx = -math.cos(dirAngle) * strength
	local fy = math.sin(dirAngle) * strength * 0.5 + 10  -- +10 settle offset
	return fx, fy
end

-- Spatial flow field. Returns an (fx, fy) velocity-force modifier at world
-- position (x, y) and sim-time t. Three layered multi-frequency sinusoids per
-- axis — a "poor man's Perlin" with enough mode density to feel turbulent.
-- Peak magnitude per axis sums to ~160, which can briefly exceed the base
-- wind in eddy hot spots — that's where particles get genuinely flustered.
local function flowField(x, y, t)
	local fx = math.sin(y * 0.040 + t * 0.65)        * 70
	         + math.cos((x + y) * 0.025 - t * 0.40)  * 50
	         + math.sin(x * 0.030 - t * 0.55 + 2.1)  * 40
	local fy = math.cos(x * 0.035 + t * 0.55)        * 65
	         + math.sin((x - y) * 0.028 + t * 0.30)  * 45
	         + math.cos(y * 0.050 - t * 0.70 + 0.7)  * 35
	return fx, fy
end

-- Physics step. Combines the rotating/gusting base wind with the spatial
-- flow field, applies F=ma per particle, integrates with light drag, and
-- respawns off-screen slots in place (no array growth). Base wind sampled
-- once per step (global to all particles); flow field sampled per particle
-- since it's position-dependent.
local function updateWindParticles(dt)
	-- Throttled re-sample of in-game wind strength. Every WIND_CHECK_INTERVAL
	-- seconds, recompute the target particle count and resize the array if
	-- it changed. This is what makes the density visibly track live wind.
	if windTime - windLastCheck >= WIND_CHECK_INTERVAL then
		windLastCheck = windTime
		local target = computeTargetWindCount()
		if target ~= windParticleCount then
			resizeWindParticles(target)
		end
	end

	local dragFactor = 1 - WIND_DRAG * dt
	local baseFx, baseFy = baseWind(windTime)
	for _, p in ipairs(windParticles) do
		local fieldFx, fieldFy = flowField(p.x, p.y, windTime)
		local ax = (baseFx + fieldFx) / p.mass
		local ay = (baseFy + fieldFy) / p.mass
		p.vx = p.vx * dragFactor + ax * dt
		p.vy = p.vy * dragFactor + ay * dt
		p.x  = p.x  + p.vx * dt
		p.y  = p.y  + p.vy * dt
		p.z  = p.z  + p.vz * dt   -- depth drifts linearly; no drag, no forces
		p.rotation = p.rotation + p.vrot * dt

		-- Despawn from any edge now — the wind can temporarily push
		-- particles rightward or vertically out of bounds. The right-edge
		-- threshold is generous (W + 100) so freshly spawned particles at
		-- W + 10..60 don't trigger immediate respawn. Also respawn if z
		-- drifts to an extreme (invisibly tiny at z>15, absurdly huge at
		-- z<-2) to avoid wasted slots.
		if p.x < -30 or p.x > WIND_VIEWBOX_W + 100
		   or p.y < -30 or p.y > WIND_VIEWBOX_H + 30
		   or p.z < -2 or p.z > 15 then
			local fresh = spawnWindParticle(true)
			for k, v in pairs(fresh) do p[k] = v end
		end
	end
end

-- Composite SVG: one polygon per particle, with each particle's local verts
-- transformed to world coords via its rotation + position. Rebuilt from
-- scratch every frame while the field is running.
local function buildWindSvg()
	local doc = EzSVG.Document(WIND_VIEWBOX_W, WIND_VIEWBOX_H)
	doc["viewBox"] = "0 0 " .. WIND_VIEWBOX_W .. " " .. WIND_VIEWBOX_H
	doc["preserveAspectRatio"] = "none"
	doc["width"] = nil
	doc["height"] = nil

	for _, p in ipairs(windParticles) do
		local cosR = math.cos(math.rad(p.rotation))
		local sinR = math.sin(math.rad(p.rotation))
		-- Perspective divide: near particles full size, far ones shrink.
		-- Scale is applied to the local vertex offsets (around the particle
		-- center) so the particle grows/shrinks in place without shifting.
		local scale = 1 / (1 + p.z * WIND_PERSPECTIVE)
		local worldPoints = {}
		for i = 1, #p.verts, 2 do
			local lx = p.verts[i]
			local ly = p.verts[i + 1]
			worldPoints[#worldPoints + 1] = p.x + (lx * cosR - ly * sinR) * scale
			worldPoints[#worldPoints + 1] = p.y + (lx * sinR + ly * cosR) * scale
		end
		-- Atmospheric perspective: far particles proportionally fainter.
		-- Blends between full opacity at scale=1 and 40% at deep z.
		local depthOpacity = p.opacity * (0.4 + 0.6 * scale)
		doc:add(EzSVG.Polygon(worldPoints, {
			fill    = p.color,
			opacity = tostring(depthOpacity),
		}))
	end

	return doc:tostr()
end

-- ── Widget lifecycle ──

function widget:Initialize()
	local result = utils.initializeRmlWidget(self, {
		widgetId = WIDGET_ID,
		modelName = MODEL_NAME,
		rmlPath = RML_PATH,
		initModel = initModel(),
		useCommonClassGroups = true,
	})
	if not result then return false end

	document = result.document
	dm_handle = result.dm_handle

	-- Inject the title-bar angle decorator SVG
	local decoratorEl = document:GetElementById("angle-decorator")
	if decoratorEl then
		pcall(function() decoratorEl:SetAttribute("src", buildAngleDecoratorSVG()) end)
	end

	log("Widget initialized. Running SVG tests...")
	self:RunTests()
	self:RunShapeTests()

	dynamicSvgEl = document:GetElementById("dynamic-svg")
	graphSvgEl = document:GetElementById("graph-svg")
	initTimer = spGetTimer()
	animFrameCount = 0

	-- Wind particle field (pre-populated so Start has instant effect).
	-- Initial count reflects current in-game wind strength; updateWindParticles
	-- will continue to re-sample periodically during gameplay as wind cycles.
	windParticleCount = computeTargetWindCount()
	windLastCheck = 0
	windEl = document:GetElementById("wind-svg")
	initWindParticles()
	if windEl then
		-- Render the initial scattered state once so the canvas isn't blank
		-- before the user clicks Start.
		pcall(function() windEl:SetAttribute("src", buildWindSvg()) end)
	end

	return true
end

function widget:Shutdown()
	utils.shutdownRmlWidget(self, {
		widgetId = WIDGET_ID,
		modelName = MODEL_NAME,
	}, document, dm_handle)
	document = nil
	dm_handle = nil
	dynamicSvgEl = nil
	graphSvgEl = nil
	animRunning = false
	graphSweepRunning = false
	graphData = nil
	windEl = nil
	windParticles = {}
	windRunning = false
	windAccum = 0
	windTime = 0
	windLastCheck = 0

	os.remove(GENERATED_SVG_PATH)
end

function widget:Update(dt)
	-- Sync "RML Debug Controls" dev flag so reload/debug buttons reflect state
	if dm_handle then
		local rmlDebug = utils.isRmlDebugEnabled()
		if rmlDebug ~= lastRmlDebug then
			lastRmlDebug = rmlDebug
			dm_handle.rmlDebugControls = rmlDebug
		end
	end

	if animRunning and dynamicSvgEl and initTimer then
		animFrameCount = animFrameCount + 1
		if animFrameCount % animSkip == 0 then
			animTime = spDiffTimers(spGetTimer(), initTimer)
			dynamicSvgEl:SetAttribute("src", buildAnimatedSvg(animTime))
		end
	end

	if graphSweepRunning and graphData and graphSvgEl then
		graphSweepFrame = graphSweepFrame + 1
		if graphSweepFrame >= graphSweepTotalFrames then
			graphSweepFrame = graphSweepTotalFrames
			graphSweepRunning = false
			if dm_handle then
				dm_handle.graphSweepRunning = false
			end
		end
		renderGraph()
	end

	-- Wind particles: 30fps throttle via dt accumulator. Physics and SVG
	-- rebuild run together when the accumulator crosses the step threshold,
	-- with the accumulated dt so motion stays frame-rate independent.
	if windRunning and windEl and dt then
		windAccum = windAccum + dt
		if windAccum >= WIND_STEP then
			windTime = windTime + windAccum
			updateWindParticles(windAccum)
			pcall(function() windEl:SetAttribute("src", buildWindSvg()) end)
			windAccum = 0
		end
	end
end

-- ── Static tests ──

function widget:RunTests()
	local test1El = document:GetElementById("test1-svg")
	if test1El then log("Test 1 (static src): OK.") end

	local test2El = document:GetElementById("test2-svg")
	if test2El then
		pcall(function() test2El:SetAttribute("src", "../svg/copy_icon.svg") end)
	end

	local test3El = document:GetElementById("test3-container")
	if test3El then
		pcall(function() test3El.inner_rml = '<svg src="../svg/bin_icon.svg" class="h-8 w-8" />' end)
	end

	local test4El = document:GetElementById("test4-svg")
	if test4El then
		pcall(function()
			local svgDoc = generateTestSvg()
			local file = io.open(GENERATED_SVG_PATH, "w")
			if file then
				file:write(svgDoc:tostr())
				file:close()
				test4El:SetAttribute("src", "generated_test.svg")
			end
		end)
	end

	local test8El = document:GetElementById("test8-svg")
	if test8El then
		pcall(function() test8El:SetAttribute("src", generateTestSvg():tostr()) end)
	end

	local test9El = document:GetElementById("test9-svg")
	if test9El then
		pcall(function() test9El:SetAttribute("src", generateSimpleSvgString()) end)
	end

	log("All tests dispatched.")
end

function widget:RunShapeTests()
	local shapeTests = {
		{ id = "shape-parallelogram",  fn = function() return svgShapes.parallelogram({ skew = 15, fill = "rgb(43, 165, 234)" }) end },
		{ id = "shape-parallelogram2", fn = function() return svgShapes.parallelogram({ skew = -15, fill = "rgb(239, 68, 68)" }) end },
		{ id = "shape-chevron",        fn = function() return svgShapes.chevron({ depth = 30, fill = "rgb(34, 197, 94)" }) end },
		{ id = "shape-notched",        fn = function() return svgShapes.notchedRect({ cut = 15, fill = "rgb(250, 212, 0)" }) end },
		{ id = "shape-notched-tr",     fn = function() return svgShapes.notchedRect({ cut = 20, corners = "tr", fill = "rgb(168, 85, 247)" }) end },
		{ id = "shape-diamond",        fn = function() return svgShapes.diamond({ fill = "rgb(251, 146, 60)" }) end },
		{ id = "shape-hexagon",        fn = function() return svgShapes.hexagon({ fill = "rgb(236, 72, 153)" }) end },
		{ id = "shape-toggle",         fn = function() return svgShapes.parallelogram({ skew = 8, fill = "rgb(22, 197, 94)", stroke = "rgb(22, 197, 94)", stroke_width = 1 }) end },
	}

	for _, test in ipairs(shapeTests) do
		local el = document:GetElementById(test.id)
		if el then
			pcall(function() el:SetAttribute("src", test.fn()) end)
		end
	end

	-- Color integration tests
	local transparentPara = svgShapes.parallelogram({ skew = 8, fill = "none" , stroke = "rgb(255,255,255)", stroke_width = 2 })
	local semiTransPara = svgShapes.parallelogram({ skew = 8, fill = "rgba(255,255,255,0.15)", stroke = "rgb(255,255,255)", stroke_width = 1 })

	-- Test A: transparent SVG over CSS background — does bg bleed through the shape?
	local testA = document:GetElementById("color-test-a")
	if testA then
		pcall(function() testA:SetAttribute("src", transparentPara) end)
		log("Color test A (transparent SVG over CSS bg): dispatched.")
	end

	-- Test B: try setting SVG as a decorator image
	local testB = document:GetElementById("color-test-b")
	if testB then
		local paraStr = svgShapes.parallelogram({ skew = 8, fill = "rgb(43, 165, 234)" })
		-- Try various decorator syntaxes to see if any work with SVG strings
		pcall(function()
			testB:SetAttribute("style", 'decorator: image("' .. "../svg/pin_icon.svg" .. '");')
		end)
		log("Color test B (decorator with SVG file): dispatched.")
	end

	-- Test C: pre-cached swap (green/red toggle)
	colorTestCActive = true
	local testC = document:GetElementById("color-test-c")
	if testC then
		pcall(function() testC:SetAttribute("src", colorTestCGreen) end)
		log("Color test C (pre-cached swap): dispatched.")
	end

	-- Test D: transparent SVG, CSS hover changes parent bg
	local testD = document:GetElementById("color-test-d")
	if testD then
		pcall(function() testD:SetAttribute("src", semiTransPara) end)
		log("Color test D (hover bg change): dispatched.")
	end

	-- ── Translucency tests ──
	-- Each sits over a bright red background div. If translucent, you'll see red bleeding through.

	-- Test E: SVG fill-opacity attribute
	local testE = document:GetElementById("alpha-test-e")
	if testE then
		pcall(function()
			local doc = EzSVG.Document(100, 100)
			doc["viewBox"] = "0 0 100 100"
			doc["preserveAspectRatio"] = "none"
			doc["width"] = nil
			doc["height"] = nil
			doc:add(EzSVG.Rect(5, 5, 90, 90, 4, 4, {
				fill = "rgb(43, 165, 234)",
				["fill-opacity"] = "0.5",
			}))
			testE:SetAttribute("src", doc:tostr())
		end)
		log("Alpha test E (fill-opacity): dispatched.")
	end

	-- Test F: SVG opacity attribute on the element
	local testF = document:GetElementById("alpha-test-f")
	if testF then
		pcall(function()
			local doc = EzSVG.Document(100, 100)
			doc["viewBox"] = "0 0 100 100"
			doc["preserveAspectRatio"] = "none"
			doc["width"] = nil
			doc["height"] = nil
			doc:add(EzSVG.Rect(5, 5, 90, 90, 4, 4, {
				fill = "rgb(43, 165, 234)",
				opacity = "0.5",
			}))
			testF:SetAttribute("src", doc:tostr())
		end)
		log("Alpha test F (opacity attr): dispatched.")
	end

	-- Test G: rgba() fill value
	local testG = document:GetElementById("alpha-test-g")
	if testG then
		pcall(function()
			local doc = EzSVG.Document(100, 100)
			doc["viewBox"] = "0 0 100 100"
			doc["preserveAspectRatio"] = "none"
			doc["width"] = nil
			doc["height"] = nil
			doc:add(EzSVG.Rect(5, 5, 90, 90, 4, 4, {
				fill = "rgba(43, 165, 234, 0.5)",
			}))
			testG:SetAttribute("src", doc:tostr())
		end)
		log("Alpha test G (rgba fill): dispatched.")
	end

	-- Test H: overlapping shapes — two rects at different positions + opacity
	local testH = document:GetElementById("alpha-test-h")
	if testH then
		pcall(function()
			local doc = EzSVG.Document(100, 100)
			doc["viewBox"] = "0 0 100 100"
			doc["preserveAspectRatio"] = "none"
			doc["width"] = nil
			doc["height"] = nil
			doc:add(EzSVG.Rect(5, 10, 60, 80, 4, 4, {
				fill = "rgb(43, 165, 234)",
				opacity = "0.6",
			}))
			doc:add(EzSVG.Rect(35, 10, 60, 80, 4, 4, {
				fill = "rgb(250, 212, 0)",
				opacity = "0.6",
			}))
			testH:SetAttribute("src", doc:tostr())
		end)
		log("Alpha test H (overlap): dispatched.")
	end

	log("Shape tests dispatched.")

	-- ── Panel incubator ──
	self:BuildPanels()
end

function widget:BuildPanels()
	local notchedCornerOpts = {
		sizeX = 45,
		sizeY = 30,
		fill = "rgb(38, 38, 42)",
	}

	-- Four corner variants
	local corners = { "bl", "br", "tl", "tr" }
	for _, corner in ipairs(corners) do
		local el = document:GetElementById("clip-" .. corner)
		if el then
			local opts = {}
			for k, v in pairs(notchedCornerOpts) do opts[k] = v end
			opts.corner = corner
			pcall(function() el:SetAttribute("src", svgShapes.notchedCorner(opts)) end)
		end
	end

	-- Size variants (all BL)
	local sizeIds = { "clip-xs", "clip-sm", "clip-md2", "clip-lg", "clip-wide" }
	for _, id in ipairs(sizeIds) do
		local el = document:GetElementById(id)
		if el then
			local opts = {}
			for k, v in pairs(notchedCornerOpts) do opts[k] = v end
			opts.corner = "bl"
			pcall(function() el:SetAttribute("src", svgShapes.notchedCorner(opts)) end)
		end
	end

	-- Taper angle variants (iterates shared intensity presets)
	local taperBase = {
		fill = "rgb(38, 38, 42)",
	}
	for _, presetName in ipairs(svgShapes.intensityOrder) do
		for _, side in ipairs({ "l", "r" }) do
			local el = document:GetElementById("taper-" .. side .. "-" .. presetName)
			if el then
				local opts = {}
				for k, v in pairs(taperBase) do opts[k] = v end
				opts.depth = presetName
				opts.side = side == "l" and "left" or "right"
				pcall(function() el:SetAttribute("src", svgShapes.taper(opts)) end)
			end
		end
	end

	log("Shape panels built.")
end

-- Pre-cache color variants for test C
local colorTestCGreen = svgShapes.parallelogram({ skew = 8, fill = "rgb(34, 197, 94)" })
local colorTestCRed = svgShapes.parallelogram({ skew = 8, fill = "rgb(239, 68, 68)" })
local colorTestCActive = true

function widget:ToggleColorTest()
	local el = document:GetElementById("color-test-c")
	if not el then return end
	colorTestCActive = not colorTestCActive
	el:SetAttribute("src", colorTestCActive and colorTestCGreen or colorTestCRed)
end

function widget:Reload()
	Spring.Echo(WIDGET_ID .. ": Reloading...")
	widget:Shutdown()
	widget:Initialize()
end

function widget:ToggleDebugger()
	if dm_handle then
		dm_handle.debugMode = not dm_handle.debugMode
		RmlUi.SetDebugContext(dm_handle.debugMode and 'shared' or nil)
	end
end
