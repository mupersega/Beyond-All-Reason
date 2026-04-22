-- changelog_data.lua
--
-- Pure-Lua loader/parser for changelog.txt. Produces a structured table
-- consumed by the gui_changelog_rml widget (markup + model building).
--
-- Output shape:
--   {
--       raw     = "<original file contents>",
--       hash    = <VFS hash of raw, matches gui_changelog_info.lua>,
--       length  = #raw,
--       months  = {
--           {
--               id       = "2026-02",        -- stable string id
--               heading  = "February",       -- display label (text after "# ")
--               year     = "2026",            -- parsed or inferred, "" if unknown
--               entries  = {
--                   {
--                       date       = "22/02/26",      -- optional
--                       text       = "330 -> 325 range",
--                       tag        = "Centurion",     -- optional (from [Tag] prefix)
--                       subbullets = { "...", ... },  -- optional
--                   },
--                   ...
--               },
--           },
--           ...
--       },
--       tags    = { "Centurion", "Hound", ... },  -- unique, sorted
--   }
--
-- Notes on input format:
--   * The file mixes two eras. Modern entries use "•" as the top-level bullet
--     and leading tabs + "-" for sub-bullets. Legacy (pre-2023) entries use
--     leading spaces + "•" or bare "-" indented with spaces.
--   * Month headings look like "# February", "# January 2026", "# July, 30"
--     (a legacy "July 30" day-stamp), or "# 2019 - 2021" (a range).
--   * Some entries have the bullet marker but an empty text, followed by
--     sub-bullets on the next lines — e.g. "• [Rez subs]" + indented "-" rows.
--   * Section headers like "Bugfixes", "General", "Units", "Air" appear inside
--     a month as bare words on their own line. We surface these as "synthetic"
--     entries with no tag so the UI can optionally style them.
--   * The very bottom of the file has a stray "10.24" + "24/02/2019" footer
--     that is not under any "#" heading. We capture it under a synthetic
--     "Pre-release" bucket so nothing is lost.

local M = {}

-- -------------------------------------------------------------------------
-- small helpers
-- -------------------------------------------------------------------------

local function trim(s)
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function splitLines(s)
	local lines = {}
	-- Normalise Windows line endings first.
	s = s:gsub("\r\n", "\n"):gsub("\r", "\n")
	for line in (s .. "\n"):gmatch("([^\n]*)\n") do
		lines[#lines + 1] = line
	end
	return lines
end

local MONTH_NUMBERS = {
	january = "01", february = "02", march = "03", april = "04",
	may = "05", june = "06", july = "07", august = "08",
	september = "09", october = "10", november = "11", december = "12",
}

local function slugify(s)
	s = s:lower()
	s = s:gsub("[^%w]+", "-")
	s = s:gsub("^%-+", ""):gsub("%-+$", "")
	if s == "" then
		s = "month"
	end
	return s
end

-- Capitalise first letter (mirrors how the old widget presents bullet lines).
local function ucfirst(s)
	if s == "" then
		return s
	end
	return s:sub(1, 1):upper() .. s:sub(2)
end

-- -------------------------------------------------------------------------
-- line classification
-- -------------------------------------------------------------------------
--
-- Returns one of:
--   "blank"    — whitespace only
--   "heading"  — "# ..." month header
--   "date"     — standalone date like "24/02/2019"
--   "bullet"   — top-level entry marker ("•" or, for some legacy blocks, "-")
--   "subbullet"— indented "-" (or deeply-indented "•") continuation line
--   "section"  — bare word line inside a month (e.g. "Bugfixes", "Units")
--   "prose"    — any other non-empty text (continuation / free paragraph)

local function classifyLine(rawLine)
	if rawLine == nil then
		return "blank", ""
	end
	local stripped = trim(rawLine)
	if stripped == "" then
		return "blank", ""
	end
	if stripped:sub(1, 2) == "# " then
		return "heading", trim(stripped:sub(3))
	end
	-- Standalone date line: dd/mm/yy or dd/mm/yyyy (also accepts single-digit day).
	if stripped:match("^%d?%d/%d%d/%d%d%d?%d?$") then
		return "date", stripped
	end
	-- Top-level bullet: leading "•", optionally with preceding whitespace.
	local bulletBody = stripped:match("^•%s*(.*)$")
	if bulletBody then
		return "bullet", bulletBody
	end
	-- Sub-bullet: original line has leading whitespace AND starts (after trim)
	-- with "-". The old widget treats bare "-" as a bullet, but in this file
	-- "-" lines are *always* continuations under a "•" entry, so detecting
	-- them via leading indent is the right call.
	local hasLeadingIndent = rawLine:match("^[%s\t]") ~= nil
	local dashBody = stripped:match("^%-%s*(.*)$")
	if dashBody and hasLeadingIndent then
		return "subbullet", dashBody
	end
	-- A handful of short, known subsection headers appear inside months.
	-- Match them conservatively: no punctuation, short, title-case word(s).
	local sectionHeaders = {
		["Bugfixes"]      = true,
		["Other"]         = true,
		["General"]       = true,
		["Units"]         = true,
		["Air"]           = true,
		["Sea"]           = true,
		["Renamed units:"] = true,
	}
	if sectionHeaders[stripped] then
		return "section", stripped
	end
	return "prose", stripped
end

-- -------------------------------------------------------------------------
-- heading parsing
-- -------------------------------------------------------------------------

local function parseHeading(label)
	-- Try to pull an explicit 4-digit year first.
	local year = label:match("(%d%d%d%d)")
	-- Try to pull a month name (case-insensitive).
	local monthWord = label:match("([A-Za-z]+)")
	local monthNum = nil
	if monthWord then
		monthNum = MONTH_NUMBERS[monthWord:lower()]
	end
	return {
		label    = label,
		year     = year,    -- may be nil
		monthNum = monthNum, -- may be nil (e.g. "2019 - 2021" has no month word)
	}
end

-- Walk the heading list and fill in years for headings that didn't have one.
-- File is ordered newest-first, so an undated heading at position i is
-- *temporally after* the next explicit-year heading at position j > i.
-- Rule:
--   * If undated month > next explicit month (e.g. "February" above
--     "January 2026"), it shares the same year ("February 2026").
--   * If undated month < next explicit month (e.g. "January" above
--     "December 2025"), it belongs to the year after ("January 2026").
--   * If they're equal (e.g. "# July, 30" above "# July 2025"), keep the
--     same year — it's usually a day-within-month marker, not a new month.
local function backfillYears(headings)
	for i = 1, #headings do
		local h = headings[i]
		if not h.year then
			for j = i + 1, #headings do
				local next_ = headings[j]
				if next_.year then
					local y = tonumber(next_.year)
					if h.monthNum and next_.monthNum then
						local hN = tonumber(h.monthNum)
						local nN = tonumber(next_.monthNum)
						if hN < nN then
							y = y + 1
						end
					end
					h.year = tostring(y)
					break
				end
			end
		end
	end
end

-- Build a stable, unique id per month. Prefers "YYYY-MM"; falls back to a
-- slug of the label when the month number is unknown (e.g. "2019 - 2021").
local function assignIds(months)
	local seen = {}
	for _, m in ipairs(months) do
		local base
		if m.year ~= "" and m.monthNum then
			base = m.year .. "-" .. m.monthNum
		else
			-- Slug includes any digits present in the heading, so we don't
			-- double-prefix the year when the heading is already a year range.
			base = slugify(m.heading)
		end
		local id = base
		local n = 2
		while seen[id] do
			id = base .. "-" .. n
			n = n + 1
		end
		seen[id] = true
		m.id = id
	end
end

-- -------------------------------------------------------------------------
-- entry construction
-- -------------------------------------------------------------------------

-- Strip a leading "[Tag] " prefix from bullet text, returning (tag, remainder).
local function extractTag(text)
	local tag, rest = text:match("^%[([^%]]+)%]%s*(.*)$")
	if tag then
		return trim(tag), trim(rest)
	end
	return nil, text
end

-- Strip a leading "dd/mm/yy" or "dd/mm/yyyy" date prefix.
local function extractInlineDate(text)
	local date, rest = text:match("^(%d?%d/%d%d/%d%d%d?%d?)%s*[-:]?%s*(.*)$")
	if date then
		return date, trim(rest)
	end
	return nil, text
end

local function newEntry()
	return { text = "", subbullets = nil }
end

local function entryIsEmpty(e)
	return (e.text == "" or e.text == nil)
		and not e.tag
		and not e.date
		and (not e.subbullets or #e.subbullets == 0)
end

-- -------------------------------------------------------------------------
-- main parse
-- -------------------------------------------------------------------------

local function parseChangelog(raw)
	local lines = splitLines(raw)

	local months = {}
	local tagSet = {}
	local currentMonth = nil
	local currentEntry = nil
	-- Pending standalone date line that should attach to the next entry.
	local pendingDate = nil
	-- Blank lines finalise the current entry, so subsequent prose starts a
	-- fresh entry instead of being glued onto the previous one.
	local entrySealed = false

	local function pushEntry()
		if currentEntry and not entryIsEmpty(currentEntry) and currentMonth then
			currentMonth.entries[#currentMonth.entries + 1] = currentEntry
		end
		currentEntry = nil
	end

	local function startMonth(label)
		pushEntry()
		local parsed = parseHeading(label)
		currentMonth = {
			heading  = label,
			year     = parsed.year or "",
			monthNum = parsed.monthNum, -- consumed later by assignIds, stripped from output
			entries  = {},
		}
		months[#months + 1] = currentMonth
		pendingDate = nil
	end

	-- Synthetic container for stray content that appears before any heading
	-- or after the last heading (e.g. the trailing "10.24" / "24/02/2019").
	local function ensureOrphanMonth()
		if not currentMonth then
			startMonth("Pre-release")
		end
	end

	for _, rawLine in ipairs(lines) do
		local kind, body = classifyLine(rawLine)

		if kind == "blank" then
			-- A blank line seals the current entry: subsequent prose lines
			-- won't prose-merge into it, and sub-bullets after a blank still
			-- attach via their indent (so we deliberately don't pushEntry
			-- here — that would cost us the sub-bullet block in e.g. "[Rez
			-- subs]" which has a blank line between text and sub-bullets…
			-- actually it doesn't, but future-proofing).
			entrySealed = true

		elseif kind == "heading" then
			startMonth(body)
			entrySealed = false

		elseif kind == "date" then
			-- Save as a pending date to attach to the next bullet entry (or
			-- store as a standalone prose entry if nothing follows).
			ensureOrphanMonth()
			pendingDate = body

		elseif kind == "bullet" then
			ensureOrphanMonth()
			pushEntry()
			entrySealed = false
			currentEntry = newEntry()
			if pendingDate then
				currentEntry.date = pendingDate
				pendingDate = nil
			end
			local text = body
			local tag
			tag, text = extractTag(text)
			if tag then
				currentEntry.tag = tag
				if not tagSet[tag] then
					tagSet[tag] = true
				end
			end
			-- A date may also appear inline at the start of the bullet.
			if not currentEntry.date then
				local inlineDate, rest = extractInlineDate(text)
				if inlineDate then
					currentEntry.date = inlineDate
					text = rest
				end
			end
			currentEntry.text = ucfirst(trim(text))

		elseif kind == "subbullet" then
			ensureOrphanMonth()
			if not currentEntry or entrySealed then
				-- Orphan sub-bullet (shouldn't normally happen); promote to
				-- a top-level entry so nothing is lost.
				pushEntry()
				currentEntry = newEntry()
				currentEntry.text = ucfirst(trim(body))
				entrySealed = false
			else
				currentEntry.subbullets = currentEntry.subbullets or {}
				currentEntry.subbullets[#currentEntry.subbullets + 1] = trim(body)
			end

		elseif kind == "section" then
			ensureOrphanMonth()
			pushEntry()
			entrySealed = false
			currentEntry = newEntry()
			currentEntry.text = body
			currentEntry.section = true

		elseif kind == "prose" then
			ensureOrphanMonth()
			if currentEntry and not currentEntry.section and not entrySealed then
				-- If we're already collecting sub-bullets, treat prose as a
				-- continuation of the last sub-bullet (covers deeply-indented
				-- lines nested under a sub-bullet, e.g. the "Legion fusion:"
				-- cost list in January 2026).
				if currentEntry.subbullets and #currentEntry.subbullets > 0 then
					local last = #currentEntry.subbullets
					currentEntry.subbullets[last] =
						currentEntry.subbullets[last] .. " " .. trim(body)
				elseif currentEntry.text == "" then
					currentEntry.text = ucfirst(trim(body))
				else
					currentEntry.text = currentEntry.text .. " " .. trim(body)
				end
			else
				pushEntry()
				entrySealed = false
				currentEntry = newEntry()
				if pendingDate then
					currentEntry.date = pendingDate
					pendingDate = nil
				end
				currentEntry.text = ucfirst(trim(body))
			end
		end
	end

	-- Flush last pending entry.
	pushEntry()

	-- Post-process: fill in years, assign ids, clean up internal fields.
	local headings = {}
	for _, m in ipairs(months) do
		headings[#headings + 1] = { year = (m.year ~= "" and m.year) or nil, monthNum = m.monthNum }
	end
	backfillYears(headings)
	for i, m in ipairs(months) do
		m.year = headings[i].year or ""
		m.monthNum = headings[i].monthNum -- retained for assignIds below
	end
	assignIds(months)
	-- Strip monthNum (internal) from the final output.
	for _, m in ipairs(months) do
		m.monthNum = nil
	end

	-- Collect tags as a sorted array.
	local tags = {}
	for tag in pairs(tagSet) do
		tags[#tags + 1] = tag
	end
	table.sort(tags, function(a, b) return a:lower() < b:lower() end)

	return months, tags
end

-- -------------------------------------------------------------------------
-- public API
-- -------------------------------------------------------------------------

-- Loads changelog.txt via VFS and returns the structured table described at
-- the top of this file. Returns nil + error message on failure.
function M.load()
	local raw = VFS.LoadFile("changelog.txt")
	if not raw then
		return nil, "Changelog: couldn't load changelog.txt"
	end
	-- Match gui_changelog_info.lua: tabs become 4 spaces before hashing, so
	-- the hash we emit matches the one the old widget stores in config.
	raw = raw:gsub("\t", "    ")
	local hash = VFS.CalculateHash(raw, 0)
	local length = #raw

	local months, tags = parseChangelog(raw)
	return {
		raw    = raw,
		hash   = hash,
		length = length,
		months = months,
		tags   = tags,
	}
end

-- Exposed for the scratch sample dumper and unit tests. Takes a raw string
-- (already tab-expanded) and returns (months, tags).
M._parse = parseChangelog

return M
