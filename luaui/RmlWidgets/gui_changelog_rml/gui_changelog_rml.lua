if not RmlUi then
	return
end

local widget = widget ---@type Widget

local utils = VFS.Include("luaui/Include/rml_utilities/utils.lua")
local changelogData = VFS.Include("luaui/RmlWidgets/gui_changelog_rml/changelog_data.lua")

function widget:GetInfo()
	return {
		name    = "Changelog (RML)",
		desc    = "Displays the game changelog in a dockable RML panel.",
		author  = "Floris, <RML migration>",
		date    = "2026",
		license = "GNU GPL, v2 or later",
		layer   = -99990,
		enabled = false,
	}
end

-- Constants
local WIDGET_ID   = "gui_changelog_rml"
local MODEL_NAME  = "gui_changelog_rml_model"
local RML_PATH    = "luaui/RmlWidgets/gui_changelog_rml/gui_changelog_rml.rml"
local SDLK_ESCAPE = 27

-- Widget state
local document
local dm_handle
local isVisible = false
local ownsWgChangelog = false
local lastRmlDebug = nil  -- cache for the "RML Debug Controls" dev flag

-- Unread-hash tracking (ported from gui_changelog_info.lua lines 26-32, 495-509)
local changelogFileHash         = 0
local changelogFileLength       = 0
local lastviewedHash            = ""
local lastviewedChangelogLength = 0

-- Source-of-truth Lua tables. The dm_handle proxy is string-keyed and cannot
-- be read back as an array, so we keep the parsed data in file-local upvalues
-- and only write views of it to the model.
local parsedData
local monthById

-- -------------------------------------------------------------------------
-- helpers operating on the Lua-side source-of-truth tables
-- -------------------------------------------------------------------------

local function buildIndexes(data)
	monthById = {}
	if not data or not data.months then
		return
	end
	for _, month in ipairs(data.months) do
		monthById[month.id] = month
	end
end

-- Build the flat sidebar month list the RML side iterates over.
local function buildMonthList(data)
	local list = {}
	if not data or not data.months then
		return list
	end
	for _, m in ipairs(data.months) do
		list[#list + 1] = {
			id      = m.id,
			heading = m.heading,
			year    = m.year or "",
		}
	end
	return list
end

-- Normalise an entry for the model. Every optional field becomes a non-nil
-- scalar so RML bindings can use cheap `!= ''` and truthy tests without
-- risking proxy-nil surprises. Sub-bullets render inline (no collapse chip).
local function normaliseEntry(entry)
	local subs = {}
	if entry.subbullets then
		for i, sb in ipairs(entry.subbullets) do
			subs[i] = { text = sb }
		end
	end
	return {
		text          = entry.text or "",
		tag           = entry.tag or "",
		date          = entry.date or "",
		section       = entry.section == true,
		hasTag        = entry.tag ~= nil and entry.tag ~= "",
		hasDate       = entry.date ~= nil and entry.date ~= "",
		hasSubbullets = subs[1] ~= nil,
		subbullets    = subs,
	}
end

local function buildEntriesForMonth(month)
	local list = {}
	if not month or not month.entries then
		return list
	end
	for _, e in ipairs(month.entries) do
		list[#list + 1] = normaliseEntry(e)
	end
	return list
end

-- Build the display label shown in the body's title bar, e.g. "February 2026".
-- Returns "" when the month is unknown or the heading is empty.
local function buildMonthHeading(month)
	if not month then
		return ""
	end
	local heading = month.heading or ""
	local year = month.year or ""
	if heading == "" then
		return year
	end
	if year == "" then
		return heading
	end
	-- Avoid double-printing the year when the heading already contains it.
	if heading:find(year, 1, true) then
		return heading
	end
	return heading .. " " .. year
end

-- Refresh the main-pane body from whatever month is currently active.
-- Assumes dm_handle is valid.
local function refreshBody()
	if not dm_handle then
		return
	end
	local month = monthById[dm_handle.activeMonth]
	local entries = buildEntriesForMonth(month)
	dm_handle.currentMonthEntries = entries
	dm_handle.currentMonthEmpty   = #entries == 0
	dm_handle.activeMonthHeading  = buildMonthHeading(month)
end

local function markViewed()
	lastviewedHash = changelogFileHash
	if changelogFileLength > lastviewedChangelogLength then
		lastviewedChangelogLength = changelogFileLength
	end
end

-- Toggles the panel visibility and (on first show) records the unread hash.
-- Mirrors the show/hide semantics of gui_changelog_info.lua lines 431-443.
local function setVisible(state)
	if state == nil then
		state = not isVisible
	end
	isVisible = state and true or false
	if document then
		if isVisible then
			document:Show()
		else
			document:Hide()
		end
	end
	if dm_handle then
		dm_handle.visible = isVisible
	end
	if isVisible then
		markViewed()
	end
end

-- -------------------------------------------------------------------------
-- data model factory
-- -------------------------------------------------------------------------
-- IMPORTANT: every key must be defined at init time. The dm_handle proxy
-- locks its schema when the model is opened — adding keys later silently
-- fails. Keep this in sync with the RML side's bindings.

local function initModel()
	return {
		-- Panel state
		visible          = false,
		debugMode        = false,
		rmlDebugControls = false,  -- driven by utils.isRmlDebugEnabled() in Update
		reloadRequested  = false,  -- set by requestReload(); acted on in widget:Update

		-- Dev-only model fns (gated by data-if="rmlDebugControls"). No
		-- widget: methods — see CLAUDE.md "The model is king". requestReload
		-- defers teardown to Update so the model isn't destroyed mid-dispatch.
		requestReload = function()
			dm_handle.reloadRequested = true
		end,
		toggleDebugger = function()
			dm_handle.debugMode = not dm_handle.debugMode
			RmlUi.SetDebugContext(dm_handle.debugMode and 'shared' or nil)
		end,

		-- Localised header label (overwritten in Initialize with Spring.I18N).
		titleText = "Changelog",

		-- Sidebar: flat month list
		months             = {},
		activeMonth        = "",
		activeMonthHeading = "",

		-- Body: entries for the currently-selected month
		currentMonthEntries = {},
		currentMonthEmpty   = true,

		-- Widget-specific class shortcuts. Borrowed from rml_starter so the
		-- nav column gets the same gradient + radial focus glow treatment.
		my = {
			tabsNavigationStyles = "font-bold bg-darkest-semi-alpha bg-gradient-darker-alpha radial-focus-start text-outline-darkest-lg border-bottom border-darkest",
		},

		setActiveMonth = function(event, id)
			if not id or id == "" then
				return
			end
			if not monthById[id] then
				return
			end
			dm_handle.activeMonth = id
			refreshBody()
		end,
	}
end

-- -------------------------------------------------------------------------
-- widget lifecycle
-- -------------------------------------------------------------------------

function widget:Initialize()
	local data, err = changelogData.load()
	if not data then
		Spring.Echo(WIDGET_ID .. ": " .. (err or "failed to load changelog"))
		widgetHandler:RemoveWidget()
		return false
	end
	parsedData = data
	changelogFileHash   = data.hash or 0
	changelogFileLength = data.length or 0
	buildIndexes(parsedData)

	local result = utils.initializeRmlWidget(self, {
		widgetId             = WIDGET_ID,
		modelName            = MODEL_NAME,
		rmlPath              = RML_PATH,
		initModel            = initModel(),
		useCommonClassGroups = true,
	})
	if not result then
		return false
	end

	document  = result.document
	dm_handle = result.dm_handle

	-- Resolve the localised window title. Spring.I18N returns the key itself
	-- on lookup miss, so treat that as "no translation" and fall back to the
	-- hardcoded English label (matches the old widget's behaviour).
	local localisedTitle = Spring.I18N and Spring.I18N('ui.changelog.title') or nil
	if localisedTitle and localisedTitle ~= "" and localisedTitle ~= 'ui.changelog.title' then
		dm_handle.titleText = localisedTitle
	else
		dm_handle.titleText = "Changelog"
	end

	dm_handle.months = buildMonthList(parsedData)
	local firstMonth = parsedData.months[1]
	dm_handle.activeMonth = (firstMonth and firstMonth.id) or ""

	-- First-time body population. Go through refreshBody so the derived keys
	-- (activeMonthHeading, currentMonthEmpty) get initialised consistently
	-- instead of drifting from initModel defaults.
	refreshBody()

	-- Start hidden; show() is called by the topbar via WG['changelog'].toggle.
	document:Hide()
	isVisible = false
	dm_handle.visible = false

	-- Register the public API for gui_top_bar.lua. Guard against the old
	-- widget still owning it — both widgets coexist during the RML migration,
	-- and the one that ships enabled must keep the slot.
	if WG['changelog'] == nil then
		WG['changelog'] = {
			toggle = function(state)
				setVisible(state)
			end,
			isvisible = function()
				return isVisible
			end,
			haschanges = function()
				return lastviewedHash ~= changelogFileHash
					and lastviewedChangelogLength < changelogFileLength
			end,
		}
		ownsWgChangelog = true
	end

	return true
end

function widget:Shutdown()
	if ownsWgChangelog and WG['changelog'] then
		WG['changelog'] = nil
		ownsWgChangelog = false
	end

	utils.shutdownRmlWidget(self, {
		widgetId  = WIDGET_ID,
		modelName = MODEL_NAME,
	}, document, dm_handle)

	document   = nil
	dm_handle  = nil
	parsedData = nil
	monthById  = nil
	isVisible  = false
end

function widget:KeyPress(key, mods, isRepeat)
	if key == SDLK_ESCAPE and isVisible and not isRepeat then
		setVisible(false)
		return true
	end
	return false
end

function widget:Update()
	if not dm_handle then return end
	if dm_handle.reloadRequested then
		-- Deferred reload: tear down OUTSIDE the data-event dispatch that
		-- requested it (Shutdown from inside a model fn = use-after-free).
		widget:Shutdown()
		widget:Initialize()
		return
	end
	-- change-gated dev-flag sync; no per-frame polling. See CLAUDE.md.
	local rmlDebug = utils.isRmlDebugEnabled()
	if rmlDebug ~= lastRmlDebug then
		lastRmlDebug = rmlDebug
		dm_handle.rmlDebugControls = rmlDebug
	end
end

-- -------------------------------------------------------------------------
-- config persistence (ported verbatim from gui_changelog_info.lua 495-509)
-- -------------------------------------------------------------------------

function widget:GetConfigData()
	return {
		lastviewedHash            = lastviewedHash,
		lastviewedChangelogLength = lastviewedChangelogLength,
	}
end

function widget:SetConfigData(data)
	if data then
		if data.lastviewedHash ~= nil then
			lastviewedHash = data.lastviewedHash
		end
		if data.lastviewedChangelogLength ~= nil then
			lastviewedChangelogLength = data.lastviewedChangelogLength
		end
	end
end
