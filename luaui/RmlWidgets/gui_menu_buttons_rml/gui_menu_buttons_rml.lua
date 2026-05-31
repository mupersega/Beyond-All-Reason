-- gui_menu_buttons_rml — top-right menu launcher buttons (RML)
--
-- THE MODEL IS KING. Change the view by mutating dm_handle fields and letting
-- data binding update it. No GetElementById / QuerySelector / SetClass /
-- .inner_rml to drive UI. See luaui/RmlWidgets/CLAUDE.md — "The model is king".
--
-- ── SCOPE ─────────────────────────────────────────────────────────────────
-- A small, single-purpose launcher: the top-right cluster of buttons that OPEN
-- other UI states — Settings, Keys, Changelog, Stats, Save, Lobby. This is NOT
-- the options panel; it just toggles the various windows other widgets own.
-- Extracted from the legacy gui_top_bar.lua, which currently bundles these
-- buttons into the resource HUD.
--
-- Coexistence: the legacy gui_top_bar.lua stays enabled and OWNS WG['topbar']
-- and still draws its own button cluster. This widget is additive + opt-in
-- (enabled = false) so previewing it overlaps the legacy buttons during the
-- migration — expected. It publishes NO shared WG state; it only CALLS the
-- toggle APIs the target widgets already expose, via self-contained copies of
-- the legacy hideWindows/toggleWindow helpers (so it doesn't depend on the
-- legacy top bar being present).
--
-- DEFERRED (own pass): the quit/resign confirm overlay (a full drawn overlay
-- in the legacy widget, not a simple WG toggle) and the end-game graphs button.

if not RmlUi then
	return
end

local widget = widget ---@type Widget
local utils = VFS.Include("luaui/Include/rml_utilities/utils.lua")

local WIDGET_ID = "gui_menu_buttons_rml"
local MODEL_NAME = "gui_menu_buttons_rml_model"
local RML_PATH = "luaui/RmlWidgets/gui_menu_buttons_rml/gui_menu_buttons_rml.rml"

local document
local dm_handle

-- Refresh cadence for the changelog "has changes" highlight (external state,
-- can't be expressed declaratively — low-cadence poll is the sanctioned case).
local REFRESH_INTERVAL = 0.5
local sinceRefresh = 0

-- Environment flags, resolved once at deferred init (after all widgets load).
local isSinglePlayer = false
local chobbyLoaded = false

-- Local mirror of the changelog-highlight flag so we only rebuild the buttons
-- array when it actually flips (never read arrays back off the proxy).
local lastHasChanges = nil

-----------------------------------------------------------------------
-- Window toggle helpers — self-contained copies of the legacy top bar's
-- closeWindow/hideWindows/toggleWindow (gui_top_bar.lua:2021-2097). Kept
-- local so this widget works whether or not the legacy top bar is loaded.
-- They read WG at call time, so target widgets need not exist at our init.
-----------------------------------------------------------------------

-- The set of windows that are mutually exclusive — opening one closes the rest.
local MANAGED_WINDOWS = {
	"options", "options_rml", "scavengerinfo", "keybinds",
	"changelog", "gameinfo", "teamstats", "widgetselector",
}

local function closeWindow(name)
	local w = WG[name]
	if w ~= nil and w.isvisible and w.isvisible() then
		w.toggle(false)
		return true
	end
	return false
end

local function hideWindows()
	local closed = false
	for i = 1, #MANAGED_WINDOWS do
		closed = closeWindow(MANAGED_WINDOWS[i]) or closed
	end
	return closed
end

-- Toggle a single window: close everything else first, then open the target if
-- it wasn't already open (a second click thus just closes it).
local function toggleWindow(name)
	local w = WG[name]
	local wasVisible = w ~= nil and w.isvisible and w.isvisible()
	hideWindows()
	if w ~= nil and not wasVisible and w.toggle then
		w.toggle()
	end
end

-- Treat multiple WG namespaces as aliases for one logical window (the Settings
-- button dispatches to both legacy gui_options.lua [WG.options] and
-- gui_options_rml [WG.options_rml]; only the enabled one responds). Sequential
-- toggleWindow calls would break this — the second's hideWindows() would close
-- what the first opened. Mirrors legacy toggleWindowMulti.
local function toggleWindowMulti(names)
	local anyVisible = false
	for i = 1, #names do
		local w = WG[names[i]]
		if w ~= nil and w.isvisible and w.isvisible() then
			anyVisible = true
			break
		end
	end
	if anyVisible then
		for i = 1, #names do
			local w = WG[names[i]]
			if w ~= nil and w.isvisible and w.isvisible() then w.toggle() end
		end
	else
		hideWindows()
		for i = 1, #names do
			local w = WG[names[i]]
			if w ~= nil and w.toggle then w.toggle() end
		end
	end
end

-----------------------------------------------------------------------
-- Button list — built once at deferred init, gated by WG availability +
-- environment flags (matches legacy updateButtons gui_top_bar.lua:307-343).
-- Order is left→right; Lobby sits at the far right (the screen corner).
-----------------------------------------------------------------------

local function changelogHasChanges()
	local w = WG["changelog"]
	return (w and w.haschanges and w.haschanges()) and true or false
end

local function buildButtons()
	local list = {}
	local function add(id, i18nKey, fallback, highlight)
		list[#list + 1] = {
			id = id,
			label = Spring.I18N(i18nKey) or fallback,
			highlight = highlight or false,  -- homogeneous field on every row
		}
	end

	if WG["options"] or WG["options_rml"] then
		add("settings", "ui.topbar.button.settings", "Settings")
	end
	if WG["keybinds"] then
		add("keys", "ui.topbar.button.keys", "Keys")
	end
	if WG["changelog"] then
		add("changelog", "ui.topbar.button.changes", "Changes", changelogHasChanges())
	end
	if WG["teamstats"] then
		add("stats", "ui.topbar.button.stats", "Stats")
	end
	if isSinglePlayer and WG["savegame"] then
		add("save", "ui.topbar.button.save", "Save")
	end
	if chobbyLoaded then
		add("lobby", "ui.topbar.button.lobby", "Lobby")
	end

	return list
end

-----------------------------------------------------------------------
-- Data model
-----------------------------------------------------------------------

local function initModel()
	return {
		-- Populated at deferred init (first Update) once all widgets have loaded
		-- and their WG.* toggle APIs exist.
		buttons = {},

		-- Dispatch a button to its target window/action. Wired via
		-- data-event-click="activate(b.id)"; the Event is the implicit first
		-- arg (unused here). Mirrors legacy applyButtonAction.
		activate = function(_, id)
			if id == "settings" then
				toggleWindowMulti({ "options", "options_rml" })
			elseif id == "keys" then
				toggleWindow("keybinds")
			elseif id == "changelog" then
				toggleWindow("changelog")
			elseif id == "stats" then
				toggleWindow("teamstats")
			elseif id == "save" then
				-- Single-player save (same command + timestamp the legacy uses).
				local time = os.date("%Y%m%d_%H%M%S")
				Spring.SendCommands("savegame " .. time)
			elseif id == "lobby" then
				Spring.SendLuaMenuMsg("showLobby")
			end
		end,

		-- Shared utility-class bundle.
		my = {
			btn = "px-2 text-sm font-bold cursor-pointer menu-btn",
		},
	}
end

-----------------------------------------------------------------------
-- Lifecycle
-----------------------------------------------------------------------

function widget:GetInfo()
	return {
		name = "Menu Buttons RML",
		desc = "Top-right launcher buttons (Settings/Keys/Changelog/Stats/Save/Lobby). Opt-in; coexists with the legacy top bar.",
		author = "mupersega",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = -99988, -- just above gui_top_bar_rml (-99989) for previewing
		enabled = false,
	}
end

local contentInitialized = false

-- Deferred content init: run once from Update so every widget has finished
-- loading and its WG.* toggle API exists (we register at a very low layer).
-- Mirrors the legacy top bar reading these flags after load.
local function initializeContent()
	-- Match the legacy top bar's derivations exactly (gui_top_bar.lua:62, 2339).
	isSinglePlayer = Spring.Utilities.Gametype.IsSinglePlayer() and true or false
	chobbyLoaded = (Spring.GetMenuName
		and string.find(string.lower(Spring.GetMenuName()), 'chobby')) and true or false
	lastHasChanges = changelogHasChanges()
	dm_handle.buttons = buildButtons()
end

function widget:Initialize()
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
	contentInitialized = false
	return true
end

function widget:Update(dt)
	if not dm_handle then return end

	if not contentInitialized then
		contentInitialized = true
		initializeContent()
		return
	end

	-- Re-poll only the changelog highlight (the one piece of live external
	-- state). Rebuild the buttons array only when it actually flips — the array
	-- is otherwise static. Each row keeps the full field set (homogeneous
	-- data-for; see rmlui_datafor_homogeneous).
	sinceRefresh = sinceRefresh + (dt or 0)
	if sinceRefresh < REFRESH_INTERVAL then return end
	sinceRefresh = 0

	local hc = changelogHasChanges()
	if hc ~= lastHasChanges then
		lastHasChanges = hc
		dm_handle.buttons = buildButtons()
	end
end

function widget:Shutdown()
	utils.shutdownRmlWidget(self, {
		widgetId = WIDGET_ID,
		modelName = MODEL_NAME,
	}, document, dm_handle)
	document = nil
	dm_handle = nil
end
