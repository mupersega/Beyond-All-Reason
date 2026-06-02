-- Dev RML Inspect
--
-- Bridges the gap between what a human sees on screen and what an agent
-- (or anyone reading source) can know: it walks the LIVE RmlUi element tree
-- of any loaded RML widget and dumps a structured, indented JSON snapshot of
-- every element with its COMPUTED geometry and effective state. Source code
-- gives you the static DOM; this gives you the runtime truth source can't:
-- which elements are actually 0x0, where things really sit, who overlaps,
-- and which data-bound branches resolved to visible.
--
-- USAGE (in-game console / chat):
--   /rml_inspect              -> dump EVERY document in the shared context
--   /rml_inspect info         -> dump docs whose title/id contains "info"
--
-- OUTPUT: <SpringWriteDir>/LuaUI/RmlWidgets/dev_rml_inspect/dumps/<id>.json
--   io.open writes relative to the Spring WRITE dir (the data root), NOT the
--   .sdd content dir -- e.g. on this install:
--     .../Beyond-All-Reason/data/LuaUI/RmlWidgets/dev_rml_inspect/dumps/
--   Conveniently that is OUTSIDE the repo, so dumps never pollute git.
--
-- UNITS: geometry is reported in dp (px / context.dp_ratio), the same unit
--   RCSS is authored in -- so a "116dp" rule should read back as h ~= 116.
--   dpRatio is included in the header so raw px is recoverable (px = dp * ratio).
--
-- CAVEATS:
--   * Geometry is the proven offset_parent-chain walk (see
--     gfx_rml_guishader_bridge getAbsoluteBox); context px is treated as
--     screen px, the same assumption that bridge documents.
--   * child_nodes is the traversal source; a display:none subtree may be
--     omitted entirely (it isn't laid out anyway). vis=false flags elements
--     present but zero-area.
--   * Mixed text+element content captures only the child elements; pure-text
--     leaves capture their text.

function widget:GetInfo()
	return {
		name    = "Dev RML Inspect",
		desc    = "Dumps the live RmlUi element tree of loaded RML widgets to JSON (/rml_inspect)",
		author  = "BAR RML port",
		layer   = 0,
		enabled = false,
	}
end

local OUT_DIR = "luaui/RmlWidgets/dev_rml_inspect/dumps"
local CONTEXT_NAME = "shared"
local MAX_NODES = 6000
local MAX_DEPTH = 80

-- ── geometry ────────────────────────────────────────────────────────────────
-- Absolute box in context px (top-left origin). Walk the offset_parent chain
-- summing offsets and subtracting scrolled-ancestor scroll. Copied from the
-- proven gfx_rml_guishader_bridge primitive.
local function absBox(el)
	local x, y = 0, 0
	local node = el
	while node do
		x = x + (node.offset_left or 0)
		y = y + (node.offset_top or 0)
		local parent = node.offset_parent
		if parent then
			x = x - (parent.scroll_left or 0)
			y = y - (parent.scroll_top or 0)
		end
		node = parent
	end
	return x, y, (el.offset_width or 0), (el.offset_height or 0)
end

local function r1(v)
	return math.floor(v * 10 + 0.5) / 10
end

local function trim(s)
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- ── tree walk ───────────────────────────────────────────────────────────────
-- Counters are reset per document by dumpDocument().
local nodeCount, truncated

local function walk(el, depth, ratio)
	if nodeCount >= MAX_NODES or depth > MAX_DEPTH then
		truncated = true
		return nil
	end
	nodeCount = nodeCount + 1

	local node = {}
	local ok, v

	ok, v = pcall(function() return el.tag_name end);   node.tag   = (ok and v) or "?"
	ok, v = pcall(function() return el.id end);         node.id    = (ok and v) or ""
	ok, v = pcall(function() return el.class_name end); node.class = (ok and v) or ""

	local bx, by, bw, bh = 0, 0, 0, 0
	pcall(function() bx, by, bw, bh = absBox(el) end)
	node.box = { x = r1(bx / ratio), y = r1(by / ratio), w = r1(bw / ratio), h = r1(bh / ratio) }
	node.vis = (bw > 0 and bh > 0)

	-- Hidden state geometry alone misses. el.style returns the COMPUTED value
	-- here (confirmed: body reports visible/block though nothing is set inline),
	-- so display:"none" definitively flags a data-if'd element and
	-- visibility:"hidden" flags a data-visible-off element whose box is kept
	-- (vis stays true). visibility is emitted only when it isn't the "visible"
	-- default (keeps the dump quiet); display is always kept -- flex vs block is
	-- meaningful for the layout-perf doctrine, and "none" is a definitive hide.
	local sv, sd
	pcall(function() sv = el.style.visibility end)
	pcall(function() sd = el.style.display end)
	if sv and sv ~= "" and sv ~= "visible" then node.visibility = sv end
	if sd and sd ~= "" then node.display = sd end

	-- Collect real element children, skipping anonymous #text nodes: they carry
	-- no box, double the tree size, and never hold text we can read. The text
	-- itself lives on the PARENT element via inner_rml.
	local n = 0
	pcall(function() n = #el.child_nodes end)
	local realKids = {}
	for i = 1, n do
		local child
		pcall(function() child = el.child_nodes[i] end)
		if child then
			local ctag = "?"
			pcall(function() ctag = child.tag_name end)
			if ctag ~= "#text" then realKids[#realKids + 1] = child end
		end
	end

	if #realKids == 0 then
		-- Leaf (no element children, only text): capture the text. Reading
		-- inner_rml only on leaves also avoids slurping whole-subtree markup.
		local html
		pcall(function() html = el.inner_rml end)
		if html and html ~= "" and html:find("<") == nil then
			html = trim(html)
			if #html > 0 then
				node.text = (#html > 160) and (html:sub(1, 160) .. "...") or html
			end
		end
	else
		local kids = {}
		for _, child in ipairs(realKids) do
			local cn = walk(child, depth + 1, ratio)
			if cn then kids[#kids + 1] = cn end
		end
		node.children = kids
	end
	return node
end

-- ── JSON ─────────────────────────────────────────────────────────────────────
local ESC_MAP = {
	['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n',
	['\r'] = '\\r', ['\t'] = '\\t', ['\b'] = '\\b', ['\f'] = '\\f',
}
local function esc(s)
	return (tostring(s):gsub('[%z\1-\31\\"]', function(c)
		return ESC_MAP[c] or string.format('\\u%04x', string.byte(c))
	end))
end

-- Stable, readable key order for the known shapes.
local KEY_ORDER = {
	widget = 1, documentId = 2, unit = 3, dpRatio = 4, context = 5,
	nodeCount = 6, truncated = 7, tree = 8,
	tag = 1, id = 2, class = 3, box = 4, vis = 5, visibility = 6, display = 7, text = 8, children = 9,
	x = 1, y = 2, w = 3, h = 4,
}

local function scalarOnly(t)
	for _, val in pairs(t) do
		if type(val) == "table" then return false end
	end
	return true
end

local function encodeVal(v, indent)
	local t = type(v)
	if t == "string" then
		return '"' .. esc(v) .. '"'
	elseif t == "number" or t == "boolean" then
		return tostring(v)
	elseif t ~= "table" then
		return "null"
	end

	local pad  = string.rep("\t", indent)
	local pad2 = string.rep("\t", indent + 1)

	if rawget(v, 1) ~= nil then
		-- array (always non-empty by construction)
		local parts = {}
		for i = 1, #v do parts[i] = pad2 .. encodeVal(v[i], indent + 1) end
		return "[\n" .. table.concat(parts, ",\n") .. "\n" .. pad .. "]"
	end

	-- object
	local keys = {}
	for k in pairs(v) do keys[#keys + 1] = k end
	table.sort(keys, function(a, b) return (KEY_ORDER[a] or 99) < (KEY_ORDER[b] or 99) end)

	if scalarOnly(v) then
		-- inline small scalar objects (e.g. box) for compact reading
		local parts = {}
		for _, k in ipairs(keys) do
			parts[#parts + 1] = '"' .. esc(k) .. '": ' .. encodeVal(v[k], indent)
		end
		return "{ " .. table.concat(parts, ", ") .. " }"
	end

	local parts = {}
	for _, k in ipairs(keys) do
		parts[#parts + 1] = pad2 .. '"' .. esc(k) .. '": ' .. encodeVal(v[k], indent + 1)
	end
	return "{\n" .. table.concat(parts, ",\n") .. "\n" .. pad .. "}"
end

-- ── per-document dump ────────────────────────────────────────────────────────
local function sanitize(s)
	s = tostring(s or ""):lower():gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
	if s == "" then s = "doc" end
	return s
end

local function docName(doc, index)
	local id, title = "", ""
	pcall(function() id = doc.id or "" end)
	pcall(function() title = doc.title or "" end)
	if id ~= "" then return id, title end
	if title ~= "" then return title, title end
	return "doc" .. index, ""
end

local function dumpDocument(ctx, doc, index, ratio)
	local id, title = docName(doc, index)

	nodeCount, truncated = 0, false
	local root = walk(doc, 0, ratio)

	local ctxW, ctxH = 0, 0
	pcall(function() ctxW, ctxH = ctx.dimensions.x, ctx.dimensions.y end)

	local payload = {
		widget     = title,
		documentId = id,
		unit       = "dp",
		dpRatio    = ratio,
		context    = { w = ctxW, h = ctxH },
		nodeCount  = nodeCount,
		truncated  = truncated,
		tree       = root,
	}

	local path = OUT_DIR .. "/" .. sanitize(id) .. ".json"
	local f, err = io.open(path, "w")
	if not f then
		Spring.Echo("[rml_inspect] FAILED to write " .. path .. ": " .. tostring(err))
		return
	end
	f:write(encodeVal(payload, 0))
	f:write("\n")
	f:close()
	Spring.Echo(string.format("[rml_inspect] %s -> %s (%d nodes%s)",
		(title ~= "" and title or id), path, nodeCount, truncated and ", TRUNCATED" or ""))
end

-- ── command entry point ──────────────────────────────────────────────────────
local function runInspect(_, optLine)
	local filter = trim(tostring(optLine or "")):lower()

	local ctx
	pcall(function() ctx = RmlUi.GetContext(CONTEXT_NAME) end)
	if not ctx then
		Spring.Echo("[rml_inspect] no RmlUi context '" .. CONTEXT_NAME .. "' (is any RML widget loaded?)")
		return
	end

	local ratio = 1
	pcall(function() ratio = ctx.dp_ratio or 1 end)
	if (not ratio) or ratio <= 0 then
		ratio = (WG.rml_utils and WG.rml_utils.getDpRatio and WG.rml_utils.getDpRatio()) or 1
	end

	Spring.CreateDir(OUT_DIR)

	local matched = 0
	local available = {}
	local i = 0
	for _, doc in ipairs(ctx.documents) do
		i = i + 1
		local id, title = docName(doc, i)
		available[#available + 1] = (title ~= "" and title or id) .. " [" .. id .. "]"
		if filter == "" or id:lower():find(filter, 1, true) or title:lower():find(filter, 1, true) then
			matched = matched + 1
			pcall(dumpDocument, ctx, doc, i, ratio)
		end
	end

	if matched == 0 then
		Spring.Echo("[rml_inspect] no document matched '" .. filter .. "'. Loaded documents:")
		for _, name in ipairs(available) do
			Spring.Echo("  - " .. name)
		end
	else
		Spring.Echo(string.format("[rml_inspect] dumped %d/%d document(s) to %s/", matched, i, OUT_DIR))
	end
end

function widget:Initialize()
	-- Text action: typed as /rml_inspect [filter] in the console/chat.
	-- Auto-removed on widget shutdown by the widget handler.
	widgetHandler:AddAction("rml_inspect", runInspect, nil, "t")
	Spring.Echo("[rml_inspect] ready. Use /rml_inspect [name-filter] to dump the live RML tree.")
end
