-- gui_factionpicker_rml — RML widget
--
-- Pregame faction pick. Each faction is a LARGE outlined NAME (no icon),
-- coloured by its OWN faction colour (NOT the active UI theme). A GL
-- DrawScreen pass draws a circuit anchored to the selected name: a hard-coded
-- central horizontal spine (encased in black, matching the text outline) with
-- a branch tree growing up/down from the central axis. Built ONCE then static;
-- pulses crackle through it. Armada + Cortex share the pattern (colour differs);
-- Legion = tight ripples. Random sits below the commanders.
-- Owner-directed redesign of legacy gui_factionpicker.lua (stays enabled).
--
-- THE MODEL IS KING for the RML layer: change the view via dm_handle + data
-- binding, never DOM. The GL pass is a separate render layer; it only READS
-- the selected field's screen rect (offset_* walk, like gfx_rml_guishader_bridge).

if not RmlUi then
    return
end

local widget = widget ---@type Widget
local utils = VFS.Include("luaui/Include/rml_utilities/utils.lua")

local WIDGET_ID = "gui_factionpicker_rml"
local MODEL_NAME = "gui_factionpicker_rml_model"
local RML_PATH = "luaui/RmlWidgets/gui_factionpicker_rml/gui_factionpicker_rml.rml"

local document
local dm_handle

-- ── Tunables (eyeball-tuned in-game; gated on owner verification) ────────
local MAX_SLOTS = 5
local REVEAL_START = 0.3
local REVEAL_INTERVAL = 0.18
local POLL_INTERVAL = 0.2
local PULSE_PERIOD = 1.6       -- seconds for a pulse to travel root->tip
local GROW_DURATION = 0.25     -- quick build-out time on select (then pulses)
local NUM_PULSES = 2           -- moving dots at once (rotate through roots → even coverage)
local SPINE_DY = -2            -- spine/effect sits this many px below the text centre
local SHOW_SPINE = true        -- the continuous horizontal bar (off: the letter-nodes carry the structure)

local SOUND_REVEAL = 'LuaUI/Sounds/buildbar_add.wav'
local SOUND_SELECT = 'LuaUI/Sounds/buildbar_waypoint.wav'
local playSounds = true

local START_SET_TEXT = "Start position set"

-- Faction effect colours (GL needs numeric RGB) — the per-theme primaries,
-- fixed here so each faction is coloured correctly regardless of UI theme.
local FACTION_COL = {
    arm = { 0.169, 0.647, 0.918 },   -- #2BA5EA
    cor = { 0.902, 0.224, 0.275 },   -- #E63946
    leg = { 0.494, 0.694, 0.255 },   -- #7EB141
    random = { 0.992, 0.753, 0.298 },-- #FDC04C
}
-- Dark accents (matches the text's dark outline) — drawn with NORMAL blend.
local DARK = { 0.03, 0.03, 0.045 }

-- Branch-tree shape PER FACTION (embodies the tooltip personality): Armada =
-- finesse → gently CURVED branches at soft angles; Cortex = brute force → hard
-- 90-degree orthogonal grid. Lengths in units of field height.
local TREE_OF = {
    arm = { roots = 9, rootLen = 0.55, depth = 3, rootW = 1.2, forkProb = 0.9, curve = 0.20, branchAngle = 0.9,    panelProb = 0.45 },
    cor = { roots = 9, rootLen = 0.55, depth = 3, rootW = 1.2, forkProb = 0.9, curve = 0.0,  branchAngle = 1.5708, panelProb = 0.45 },
}

-- ── State (file-locals; reset in Initialize) ────────────────────────────
local myTeamID = Spring.GetMyTeamID()
local factions = {}            -- [n] = { startUnit, faction, name, blurb, isRandom }

local revealStarted = false
local elapsed = 0
local revealIndex = 0
local pollTimer = 0
local lastSelectedStartUnit
local lastStartChosen
local hoveredSlot
local selectLockUntil = 0      -- ignore poll reconciliation briefly after a click

-- GL effect state
local fieldEls = {}            -- commander name fields (fp-field-N)
local rfieldEls = {}           -- random name fields (fp-rfield-N)
local anchorEls = {}           -- the VISIBLE field per slot (commander or random)
local selectedSlot
local selectedFaction
local selectT = 0              -- Legion build gate 0..1
local effectClock = 0
local treeRoots                -- per-root sub-trees (arm/cor), each w/ own growT
local treeHW = 0.5             -- selected field half-width (units of its height)
-- Draw context for the stable batch closures below (set before each gl.BeginEnd
-- so the closures need no per-frame allocation).
local d_cx, d_cy, d_scale, d_r, d_g, d_b = 0, 0, 1, 1, 1, 1
local d_spx0, d_spx1, d_spy = 0, 0, 0
local letterXs                 -- selected name's letter x-offsets (the letter spine)

-- Build the live faction list from validStartUnits (source-of-truth, runtime).
local function buildFactions()
    local raw = Spring.GetTeamRulesParam(myTeamID, "validStartUnits")
        or Spring.GetGameRulesParam("validStartUnits")
    if not raw or raw == "" then
        return {}
    end
    local list = {}
    for _, idStr in ipairs(string.split(raw, "|")) do
        local unitID = tonumber(idStr)
        local ud = unitID and UnitDefs[unitID]
        if ud then
            local key = string.sub(ud.name, 1, 3)
            if key == "dum" then
                key = "random"
            end
            list[#list + 1] = {
                startUnit = unitID,
                faction = key,
                name = Spring.I18N('units.factions.' .. key),
                blurb = Spring.I18N('ui.factionPicker.factions.' .. key),
                isRandom = (key == "random"),
            }
        end
    end
    local ordered = {}
    for _, f in ipairs(list) do if not f.isRandom then ordered[#ordered + 1] = f end end
    for _, f in ipairs(list) do if f.isRandom then ordered[#ordered + 1] = f end end
    return ordered
end

-- ── GL effect helpers ───────────────────────────────────────────────────

local cos, sin, sqrt, pi = math.cos, math.sin, math.sqrt, math.pi

local function clamp01(x)
    if x < 0 then return 0 elseif x > 1 then return 1 else return x end
end

-- Selected field's screen centre + size (offset_* walk, Y-flipped to Spring).
local function elementRect(el, vsy)
    if not el then return nil end
    local x, y = 0, 0
    local node = el
    while node do
        x = x + (node.offset_left or 0)
        y = y + (node.offset_top or 0)
        local p = node.offset_parent
        if p then
            x = x - (p.scroll_left or 0)
            y = y - (p.scroll_top or 0)
        end
        node = p
    end
    local w = el.offset_width or 0
    local h = el.offset_height or 0
    if w <= 0 or h <= 0 then return nil end
    return x + w * 0.5, vsy - (y + h * 0.5), w, h
end

-- ── Batched draw closures (STABLE references → no per-frame allocation) ──
-- Passing a stable function (not a fresh inline closure) to gl.BeginEnd avoids
-- allocating a closure every frame. They read the file-local draw context
-- (d_*) + treeRoots, set in drawForest before each gl.BeginEnd. The tree is
-- hundreds of segments — the old per-segment inline closures were the memory hog.

-- The LETTER SPINE: a connector hopping between adjacent letter x-positions
-- (all at the spine y), so the line is built FROM the letters themselves.
local function emitLetterSpine()
    local xs = letterXs
    if not xs or #xs < 2 then return end
    for i = 1, #xs - 1 do
        gl.Vertex(d_cx + xs[i] * d_scale, d_spy)
        gl.Vertex(d_cx + xs[i + 1] * d_scale, d_spy)
    end
end

local function emitBranches()
    local roots = treeRoots
    if not roots then return end
    for ri = 1, #roots do
        local root = roots[ri]
        local G = clamp01(root.growT) * root.maxLen
        local segs = root.segs
        for i = 1, #segs do
            local s = segs[i]
            if G > s.t0 then
                local f = (G - s.t0) / (s.t1 - s.t0)
                if f > 1 then f = 1 end
                gl.Vertex(d_cx + s.x0 * d_scale, d_cy + s.y0 * d_scale)
                gl.Vertex(d_cx + (s.x0 + (s.x1 - s.x0) * f) * d_scale, d_cy + (s.y0 + (s.y1 - s.y0) * f) * d_scale)
            end
        end
    end
end

local function emitNodes()
    local roots = treeRoots
    if not roots then return end
    for ri = 1, #roots do
        local root = roots[ri]
        local G = clamp01(root.growT) * root.maxLen
        local nodes = root.nodes
        for i = 1, #nodes do
            local nd = nodes[i]
            if G >= nd.atLen then
                local ns = 0.9 + nd.w * 0.6
                local ex, ey = d_cx + nd.x * d_scale, d_cy + nd.y * d_scale
                gl.Vertex(ex - ns, ey - ns); gl.Vertex(ex + ns, ey - ns)
                gl.Vertex(ex + ns, ey + ns); gl.Vertex(ex - ns, ey + ns)
            end
        end
        -- bright node where each LETTER meets the spine
        local s0 = root.segs[1]
        if s0 then
            local jx, jy = d_cx + s0.x0 * d_scale, d_cy + s0.y0 * d_scale
            gl.Vertex(jx - 2.4, jy - 2.4); gl.Vertex(jx + 2.4, jy - 2.4)
            gl.Vertex(jx + 2.4, jy + 2.4); gl.Vertex(jx - 2.4, jy + 2.4)
        end
    end
end

local function emitPanels()
    local roots = treeRoots
    if not roots then return end
    for ri = 1, #roots do
        local root = roots[ri]
        local G = clamp01(root.growT) * root.maxLen
        local pns = root.panels
        for i = 1, #pns do
            local pn = pns[i]
            if G >= pn.atLen then
                gl.Color(d_r, d_g, d_b, pn.alpha)   -- per-panel static opacity
                gl.Vertex(d_cx + pn.c1x * d_scale, d_cy + pn.c1y * d_scale)
                gl.Vertex(d_cx + pn.c2x * d_scale, d_cy + pn.c2y * d_scale)
                gl.Vertex(d_cx + pn.c3x * d_scale, d_cy + pn.c3y * d_scale)
                gl.Vertex(d_cx + pn.c4x * d_scale, d_cy + pn.c4y * d_scale)
            end
        end
    end
end

local function glowCircle(cx, cy, rad, r, g, b, a)
    local SEG = 32
    local function ring()
        gl.BeginEnd(GL.LINE_LOOP, function()
            for i = 0, SEG - 1 do
                local ang = (i / SEG) * pi * 2
                gl.Vertex(cx + cos(ang) * rad, cy + sin(ang) * rad)
            end
        end)
    end
    gl.Color(r, g, b, 0.10 * a); gl.LineWidth(6);   ring()
    gl.Color(r, g, b, 0.70 * a); gl.LineWidth(1.5); ring()
end

local function rot(dx, dy, ang)
    local c, s = cos(ang), sin(ang)
    return dx * c - dy * s, dx * s + dy * c
end

-- Emit a branch from (x,y) along (dx,dy) for `length`. curve~=0 → it ARCS
-- (sub-segments rotate = finesse); curve==0 → one straight segment (brute).
-- Returns end x, y, end dir, end arc-length.
local function emitArc(x, y, dx, dy, length, curve, width, startLen, segs)
    local K = (curve ~= 0) and 4 or 1
    local sub = length / K
    local sl = startLen
    for _ = 1, K do
        if curve ~= 0 then dx, dy = rot(dx, dy, curve) end
        local nx, ny = x + dx * sub, y + dy * sub
        segs[#segs + 1] = { x0 = x, y0 = y, x1 = nx, y1 = ny, w = width, t0 = sl, t1 = sl + sub }
        x, y, sl = nx, ny, sl + sub
    end
    return x, y, dx, dy, sl
end

-- Recursive branch: spine reaches outward + side branch(es) at p.branchAngle
-- (90deg for Cortex, ~50deg for Armada); tips become nodes.
local function growBranch(x, y, dx, dy, length, depth, width, startLen, segs, nodes, panels, p)
    -- random bend DIRECTION per branch, so the tree doesn't favour one rotation
    local cv = p.curve * ((math.random() < 0.5) and 1 or -1)
    local ex, ey, ndx, ndy, endLen = emitArc(x, y, dx, dy, length, cv, width, startLen, segs)
    if depth > 0 and math.random() < p.forkProb then
        local ba = p.branchAngle
        local side = (math.random() < 0.5) and 1 or -1
        local sx, sy = rot(ndx, ndy, ba * side)
        -- holographic panel in the wedge between spine + side branch, DENSER near
        -- the trunk (scaled by depth) — a quad we fill in a secondary pass.
        if math.random() < p.panelProb * (depth / p.depth) then
            local pl = length * (0.32 + math.random() * 0.22)
            local c2x, c2y = ex + ndx * pl, ey + ndy * pl
            local c4x, c4y = ex + sx * pl, ey + sy * pl
            panels[#panels + 1] = {
                c1x = ex, c1y = ey, c2x = c2x, c2y = c2y,
                c3x = c2x + (c4x - ex), c3y = c2y + (c4y - ey),
                c4x = c4x, c4y = c4y, atLen = endLen,
                alpha = 0.05 + math.random() * 0.14,   -- varied panel opacity
            }
        end
        growBranch(ex, ey, ndx, ndy, length * 0.82, depth - 1, width * 0.78, endLen, segs, nodes, panels, p)
        growBranch(ex, ey, sx, sy, length * 0.6, depth - 1, width * 0.66, endLen, segs, nodes, panels, p)
        if math.random() < 0.45 then
            local sx2, sy2 = rot(ndx, ndy, -ba * side)   -- true mirror (keeps Cortex 90deg)
            growBranch(ex, ey, sx2, sy2, length * 0.5, depth - 1, width * 0.58, endLen, segs, nodes, panels, p)
        end
    else
        nodes[#nodes + 1] = { x = ex, y = ey, w = width, atLen = endLen, phase = math.random() }
    end
end

local function genSubTree(rx, ry, dx, dy, p)
    local segs, nodes, panels = {}, {}, {}
    growBranch(rx, ry, dx, dy, p.rootLen * (0.8 + math.random() * 0.4), p.depth, p.rootW, 0, segs, nodes, panels, p)
    local maxLen = 1
    for i = 1, #segs do if segs[i].t1 > maxLen then maxLen = segs[i].t1 end end
    return { segs = segs, nodes = nodes, panels = panels, maxLen = maxLen, growT = 0 }
end

-- Approximate per-letter advance widths (uppercase) for the font. Only the
-- RATIOS matter — positions are normalized to the actual rendered text width.
local LETTER_W = {
    A = 1.0, B = 0.95, C = 1.0, D = 1.05, E = 0.85, F = 0.8, G = 1.05,
    H = 1.05, I = 0.4, J = 0.7, K = 1.0, L = 0.8, M = 1.5, N = 1.1,
    O = 1.15, P = 0.9, Q = 1.15, R = 1.0, S = 0.9, T = 0.85, U = 1.05,
    V = 1.0, W = 1.55, X = 1.0, Y = 0.95, Z = 0.9,
}

-- The x-offset (normalized, units of field height) of each letter's CENTRE,
-- so roots can sprout from under the actual letters.
local function letterPositions(name, hw)
    local upper = (name or ""):upper()
    local n = #upper
    if n == 0 then return {} end
    local adv, total = {}, 0
    for i = 1, n do
        local w = LETTER_W[upper:sub(i, i)] or 0.9
        adv[i] = w
        total = total + w
    end
    local pos, acc = {}, 0
    for i = 1, n do
        pos[i] = ((acc + adv[i] * 0.5) / total) * (2 * hw) - hw
        acc = acc + adv[i]
    end
    return pos
end

-- A tree rooted under each LETTER (alternating up/down, sometimes both), so the
-- nodes come out of the text itself. Build-out sweeps left → right.
local function genForest(p, pos)
    local roots = {}
    for li = 1, #pos do
        local stagger = -(li - 1) * 0.08
        local dir = (li % 2 == 0) and 1 or -1
        local a = genSubTree(pos[li], 0, 0, dir, p)
        a.growT = stagger
        roots[#roots + 1] = a
        if math.random() < 0.45 then
            local b = genSubTree(pos[li], 0, 0, -dir, p)
            b.growT = stagger
            roots[#roots + 1] = b
        end
    end
    return roots
end

-- A soft dark radial mass (NORMAL blend) under a name, so the bright detail
-- reads against the noisy map. Dark centre fading to transparent at the rim.
local function drawBackdrop(cx, cy, halfW, halfH)
    local SEG = 22
    gl.BeginEnd(GL.TRIANGLE_FAN, function()
        gl.Color(0, 0, 0, 0.5)
        gl.Vertex(cx, cy)
        gl.Color(0, 0, 0, 0)
        for i = 0, SEG do
            local a = (i / SEG) * pi * 2
            gl.Vertex(cx + cos(a) * halfW, cy + sin(a) * halfH)
        end
    end)
end

-- Dark pass (NORMAL blend, UNDER the glow): ONLY a black casing around the
-- central spine (no dark behind nodes — that read as confusing over the map).
local function drawDark(cx, cy, scale)
    if not treeRoots then return end
    local hwS = treeHW * scale   -- spans the TEXT width (anchored to the name)
    gl.Color(DARK[1], DARK[2], DARK[3], 0.92)
    gl.Rect(cx - hwS - 5, cy - 5, cx + hwS + 5, cy + 5)   -- fully encased, closed ends
end

local function drawForest(cx, cy, scale, clock, r, g, b)
    if not treeRoots then return end
    d_cx, d_cy, d_scale, d_r, d_g, d_b = cx, cy, scale, r, g, b

    -- letter spine: a connector hopping letter-to-letter (built from the letters)
    if SHOW_SPINE then
        d_spy = cy
        gl.Color(r, g, b, 0.22); gl.LineWidth(5); gl.BeginEnd(GL.LINES, emitLetterSpine)
        gl.Color(r, g, b, 0.85); gl.LineWidth(2); gl.BeginEnd(GL.LINES, emitLetterSpine)
    end

    -- branches: 3 batched glow passes (ALL segments per pass, one stable closure)
    gl.Color(r, g, b, 0.10); gl.LineWidth(6);   gl.BeginEnd(GL.LINES, emitBranches)
    gl.Color(r, g, b, 0.28); gl.LineWidth(2.5); gl.BeginEnd(GL.LINES, emitBranches)
    gl.Color(r, g, b, 0.90); gl.LineWidth(1.3); gl.BeginEnd(GL.LINES, emitBranches)

    -- holographic panels (one batched QUADS pass; per-panel static opacity)
    gl.BeginEnd(GL.QUADS, emitPanels)

    -- nodes + junctions (one batched QUADS pass)
    gl.Color(r, g, b, 0.85); gl.BeginEnd(GL.QUADS, emitNodes)

    -- a few small pulses, rotating through the roots (dynamic; gl.Rect = no closures)
    local nr = #treeRoots
    if nr > 0 then
        local cyc = math.floor(clock / PULSE_PERIOD)
        local phase = (clock / PULSE_PERIOD) % 1
        for k = 0, NUM_PULSES - 1 do
            local root = treeRoots[((cyc * NUM_PULSES + k) % nr) + 1]
            if root and clamp01(root.growT) >= 1 then
                local pd = phase * root.maxLen
                local segs = root.segs
                for i = 1, #segs do
                    local s = segs[i]
                    if pd >= s.t0 and pd <= s.t1 then
                        local f = (pd - s.t0) / (s.t1 - s.t0)
                        local px = cx + (s.x0 + (s.x1 - s.x0) * f) * scale
                        local py = cy + (s.y0 + (s.y1 - s.y0) * f) * scale
                        gl.Color(r, g, b, 0.95)
                        gl.Rect(px - 1.6, py - 1.6, px + 1.6, py + 1.6)
                    end
                end
            end
        end
    end

    -- a pulse travelling along the letter spine (first letter → last)
    if SHOW_SPINE and letterXs and #letterXs >= 2 then
        local x0, x1 = letterXs[1], letterXs[#letterXs]
        local sp = (clock / PULSE_PERIOD) % 1
        local spx = cx + (x0 + (x1 - x0) * sp) * scale
        gl.Color(r, g, b, 0.95)
        gl.Rect(spx - 1.6, cy - 1.6, spx + 1.6, cy + 1.6)
    end
end

-- Legion: tight concentric ripples hugging the field.
local function drawLegion(cx, cy, scale, t, clock, r, g, b)
    local startR = 0.7 * scale
    local maxR = 0.9 * scale
    local LIFE = 1.3
    local N = 4
    for k = 0, N - 1 do
        local phase = ((clock / LIFE) + k / N) % 1
        local rad = startR + phase * maxR
        local a = (1 - phase) * clamp01(t)
        if a > 0.03 then glowCircle(cx, cy, rad, r, g, b, a) end
    end
end

-- Drive the GL effect for a selection immediately (no poll lag / state mismatch).
local function triggerSelection(slot, fac)
    if slot == selectedSlot and fac == selectedFaction then return end
    selectedSlot = slot
    selectedFaction = fac
    selectT = 0
    treeRoots = nil
    if fac == "arm" or fac == "cor" then
        local _, vsyG = Spring.GetViewGeometry()
        local _, _, fw, fh = elementRect(anchorEls[slot], vsyG)
        if fh and fh > 0 then treeHW = (fw / fh) * 0.5 end
        local f = factions[slot]
        letterXs = letterPositions(f and f.name, treeHW)
        treeRoots = genForest(TREE_OF[fac], letterXs)
    end
end

-- Factory: a fresh model table every init.
local function initModel()
    local m = {
        title = Spring.I18N('ui.factionPicker.pick'),
        promptText = Spring.I18N('ui.initialSpawn.choosePoint'),
        startChosen = false,
        shown = false,

        my = {},

        pickFaction = function(_, n)
            local f = factions[n]
            if not f then return end
            if playSounds then
                Spring.PlaySoundFile(SOUND_SELECT, 0.6, 'ui')
            end
            Spring.SendLuaRulesMsg('changeStartUnit' .. tostring(f.startUnit))
            for i = 1, MAX_SLOTS do
                dm_handle['selected' .. i] = (i == n)
            end
            lastSelectedStartUnit = f.startUnit
            selectLockUntil = effectClock + 0.6
            triggerSelection(n, f.faction)
        end,

        onHover = function(_, n)
            local f = factions[n]
            if not f then return end
            hoveredSlot = n
            for i = 1, MAX_SLOTS do
                dm_handle['hovered' .. i] = (i == n)
            end
            if WG['rml_tooltip'] and f.blurb and f.blurb ~= '' then
                local mx, my = Spring.GetMouseState()
                WG['rml_tooltip'].Show(f.blurb, mx, my, f.name)
            end
        end,

        onUnhover = function()
            hoveredSlot = nil
            for i = 1, MAX_SLOTS do
                dm_handle['hovered' .. i] = false
            end
            if WG['rml_tooltip'] then
                WG['rml_tooltip'].Hide()
            end
        end,
    }

    for i = 1, MAX_SLOTS do
        local f = factions[i]
        m['slot' .. i] = {
            has = f ~= nil,
            name = f and f.name or "",
            faction = f and f.faction or "random",
            isRandom = (f ~= nil and f.isRandom) or false,
            showCmd = (f ~= nil and not f.isRandom) or false,  -- shows in commander row
            showRnd = (f ~= nil and f.isRandom) or false,      -- shows in random row
        }
        m['revealed' .. i] = false
        m['selected' .. i] = false
        m['hovered' .. i] = false
    end

    return m
end

function widget:GetInfo()
    return {
        name = "Faction Picker RML",
        desc = "Pregame faction pick (large text fields + GL branch effects); port of gui_factionpicker",
        author = "mupersega",
        date = "2026",
        license = "GNU GPL, v2 or later",
        layer = -1,
        enabled = false,
    }
end

function widget:Initialize()
    if Spring.GetSpectatingState() then return false end
    if Spring.GetGameFrame() > 0 then return false end
    if Spring.IsReplay and Spring.IsReplay() then return false end

    local mo = Spring.GetModOptions()
    if mo and mo.scenariooptions then
        local ok, opts = pcall(function()
            return Json.decode(string.base64Decode(mo.scenariooptions))
        end)
        if ok and opts and opts.disablefactionpicker == true then
            return false
        end
    end

    myTeamID = Spring.GetMyTeamID()
    factions = buildFactions()
    if #factions < 2 then
        return false
    end

    local result = utils.initializeRmlWidget(self, {
        widgetId = WIDGET_ID,
        modelName = MODEL_NAME,
        rmlPath = RML_PATH,
        initModel = initModel(),
        useCommonClassGroups = true,
    })
    if not result then
        return false
    end
    document = result.document
    dm_handle = result.dm_handle

    -- Cache the field element refs (geometry anchor for the GL pass). The
    -- visible field per slot is the random-row instance for random, else the
    -- commander-row instance.
    fieldEls, rfieldEls, anchorEls = {}, {}, {}
    for i = 1, MAX_SLOTS do
        fieldEls[i] = document:GetElementById("fp-name-" .. i)
        rfieldEls[i] = document:GetElementById("fp-rname-" .. i)
        local f = factions[i]
        anchorEls[i] = (f and f.isRandom) and rfieldEls[i] or fieldEls[i]
    end

    revealStarted = false
    elapsed = 0
    revealIndex = 0
    pollTimer = 0
    lastSelectedStartUnit = nil
    lastStartChosen = nil
    hoveredSlot = nil
    selectLockUntil = 0
    selectedSlot = nil
    selectedFaction = nil
    selectT = 0
    effectClock = 0
    treeRoots = nil
    treeHW = 0.5
    letterXs = nil
    return true
end

function widget:Update(dt)
    if not dm_handle then return end
    dt = dt or 0

    if not revealStarted then
        revealStarted = true
        dm_handle.shown = true
    end

    elapsed = elapsed + dt
    effectClock = effectClock + dt

    -- Quick build-out (GROW_DURATION) of the selected tree / Legion ripples.
    if selectedSlot then
        selectT = math.min(1, selectT + dt / GROW_DURATION)
    end
    if treeRoots then
        for i = 1, #treeRoots do
            local root = treeRoots[i]
            root.growT = math.min(1, root.growT + dt / GROW_DURATION)
        end
    end

    -- Gentle staggered reveal.
    local count = #factions
    if revealIndex < count then
        if elapsed >= REVEAL_START + revealIndex * REVEAL_INTERVAL then
            revealIndex = revealIndex + 1
            dm_handle['revealed' .. revealIndex] = true
            local f = factions[revealIndex]
            if playSounds and f and not f.isRandom then
                Spring.PlaySoundFile(SOUND_REVEAL, 0.4, 'ui')
            end
        end
    end

    if hoveredSlot and WG['rml_tooltip'] then
        local f = factions[hoveredSlot]
        if f and f.blurb and f.blurb ~= '' then
            local mx, my = Spring.GetMouseState()
            WG['rml_tooltip'].Show(f.blurb, mx, my, f.name)
        end
    end

    pollTimer = pollTimer + dt
    if pollTimer >= POLL_INTERVAL then
        pollTimer = 0

        -- reconcile against the engine, unless a click just set it optimistically
        local cur = Spring.GetTeamRulesParam(myTeamID, 'startUnit')
        if effectClock >= selectLockUntil and cur ~= lastSelectedStartUnit then
            lastSelectedStartUnit = cur
            for i = 1, MAX_SLOTS do
                local f = factions[i]
                dm_handle['selected' .. i] = (f ~= nil and f.startUnit == cur)
            end
            local newSlot, newFac
            for i = 1, #factions do
                if factions[i].startUnit == cur then
                    newSlot = i
                    newFac = factions[i].faction
                    break
                end
            end
            if newSlot then
                triggerSelection(newSlot, newFac)
            end
        end

        local sx, _, sz = Spring.GetTeamStartPosition(myTeamID)
        local chosen = (sx ~= nil and sx > 0 and sz ~= nil and sz > 0)
        if chosen ~= lastStartChosen then
            lastStartChosen = chosen
            dm_handle.startChosen = chosen
            dm_handle.promptText = chosen and START_SET_TEXT
                or Spring.I18N('ui.initialSpawn.choosePoint')
        end
    end
end

-- GL pass, drawn under the RmlUi text (RmlUi composites last).
function widget:DrawScreen()
    if not document then return end
    local _, vsy = Spring.GetViewGeometry()

    gl.PushMatrix()
    gl.Texture(false)
    gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

    -- soft darkness under EVERY visible name (so detail reads over the map)
    for i = 1, MAX_SLOTS do
        local el = anchorEls[i]
        if el then
            local bx, by, bw, bh = elementRect(el, vsy)
            if bx then drawBackdrop(bx, by, bw * 0.62, bh * 1.15) end
        end
    end

    -- the selected faction's effect
    if selectedSlot and selectedFaction then
        local el = anchorEls[selectedSlot]
        if el then
            local cx, cy, _, h = elementRect(el, vsy)
            if cx then
                local cyE = cy + SPINE_DY
                local col = FACTION_COL[selectedFaction] or FACTION_COL.random
                local r, g, b = col[1], col[2], col[3]
                if selectedFaction == "arm" or selectedFaction == "cor" then
                    if SHOW_SPINE then drawDark(cx, cyE, h) end    -- casing for the spine bar
                    gl.Blending(GL.SRC_ALPHA, GL.ONE)              -- glow on top
                    drawForest(cx, cyE, h, effectClock, r, g, b)
                else
                    gl.Blending(GL.SRC_ALPHA, GL.ONE)
                    drawLegion(cx, cy, h, selectT, effectClock, r, g, b)
                end
            end
        end
    end

    gl.Color(1, 1, 1, 1)
    gl.LineWidth(1)
    gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
    gl.PopMatrix()
end

function widget:GameFrame()
    widgetHandler:RemoveWidget()
end

function widget:Shutdown()
    if WG['rml_tooltip'] then
        WG['rml_tooltip'].Hide()
    end
    utils.shutdownRmlWidget(self, {
        widgetId = WIDGET_ID,
        modelName = MODEL_NAME,
    }, document, dm_handle)
    document = nil
    dm_handle = nil
    fieldEls = {}
    rfieldEls = {}
    anchorEls = {}
end
