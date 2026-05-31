if not RmlUi then
	return
end

local widget = widget ---@type Widget
local utils = VFS.Include("luaui/Include/rml_utilities/utils.lua")
include("keysym.h.lua")

function widget:GetInfo()
	return {
		name = "Log Viewer (RML)",
		desc = "Scrollable, selectable read-only log viewer",
		author = "mupersega",
		date = "2025",
		license = "GNU GPL, v2 or later",
		layer = -1000,
		enabled = true,
	}
end

-- Constants
local WIDGET_ID = "gui_log_viewer_rml"
local MODEL_NAME = "gui_log_viewer_rml_model"
local RML_PATH = "luaui/RmlWidgets/gui_log_viewer_rml/gui_log_viewer_rml.rml"

local MAX_LINES = 500
local TRIM_COUNT = 100
local UPDATE_INTERVAL = 0.1 -- seconds

-- Widget state
local document
local dm_handle
local show = false

local lines = {}
local dirty = false
local lastUpdateTimer
local consoleElement
local scrollAnchor
local autoScroll = true
local copiedTimer
local selAnchor       -- selection start line index (set on a plain click)
local selFocus        -- selection end line index (set on click / shift-click)
local copiedCount     -- number of lines in the last copy (for the COPIED badge)
local copiedTextElement

local L_DEPRECATED = LOG.DEPRECATED
local L_ERROR = LOG.ERROR
local L_WARNING = LOG.WARNING
local L_DEBUG = LOG.DEBUG
local isDevSingle = (Spring.Utilities.IsDevMode() and Spring.Utilities.Gametype.IsSinglePlayer())

-- Priority to CSS class mapping
local priorityClass = {
	[LOG.ERROR] = " console-error",
	[LOG.WARNING] = " console-warning",
	[LOG.DEBUG] = " console-debug",
}

-- Text pattern fallback when priority doesn't classify
local function classifyByText(text)
	local sfind = string.find
	if sfind(text, "[Ee]rror", 1) or sfind(text, "Failed to load", 1, true) then
		return " console-error"
	end
	if sfind(text, "[Ww]arning", 1) then
		return " console-warning"
	end
	return nil
end

local spGetGameFrame = Spring.GetGameFrame
local spGetTimer = Spring.GetTimer
local spDiffTimers = Spring.DiffTimers

-- Message classification: returns true if line is player chat (not console)
local function isPlayerChatMessage(line)
	if line:sub(1, 1) == "<" then return true end
	if line:match("^%[.-%] ") then return true end
	if line:sub(1, 1) == ">" then return true end
	if line:find(" added point: ", 1, true) then return true end
	if line:find(" shared units to ", 1, true) then return true end
	return false
end

-- Message noise filter: returns true if line should be skipped
local function shouldFilterMessage(line)
	local sfind = string.find
	if sfind(line, "Input grabbing is ", 1, true) then return true end
	if sfind(line, " to access the quit menu", 1, true) then return true end
	if sfind(line, "VSync::SetInterval", 1, true) then return true end
	if sfind(line, " now spectating team ", 1, true) then return true end
	if sfind(line, "TotalHideLobbyInterface, ", 1, true) then return true end
	if sfind(line, "HandleLobbyOverlay", 1, true) then return true end
	if sfind(line, "Chobby]", 1, true) then return true end
	if sfind(line, "liblobby]", 1, true) then return true end
	if sfind(line, "[LuaMenu", 1, true) then return true end
	if sfind(line, "ClientMessage]", 1, true) then return true end
	if sfind(line, "ServerMessage]", 1, true) then return true end
	if sfind(line, "->", 1, true) then return true end
	if sfind(line, "server=[0-9a-z][0-9a-z][0-9a-z][0-9a-z]") or sfind(line, "client=[0-9a-z][0-9a-z][0-9a-z][0-9a-z]") then return true end
	if sfind(line, "-> Version", 1, true) or sfind(line, "ClientReadNet", 1, true) or sfind(line, "Address", 1, true) then return true end
	if sfind(line, "My player ID is", 1, true) then return true end
	if sfind(line, "self-destruct in ", 1, true) then return true end
	if sfind(line, "could not load sound", 1, true) then return true end
	return false
end

-- Strip Spring color codes (\255\r\g\b) from text
local function stripColorCodes(text)
	return text:gsub("\255...", "")
end

-- Escape text for safe RML insertion
local function escapeRml(text)
	text = text:gsub("&", "&amp;")
	text = text:gsub("<", "&lt;")
	text = text:gsub(">", "&gt;")
	return text
end

-- Format timestamp from game frames
local function formatTimestamp(gameFrame)
	local totalSeconds = math.floor(gameFrame / 30)
	local minutes = math.floor(totalSeconds / 60)
	local seconds = totalSeconds % 60
	return string.format("[%d:%02d]", minutes, seconds)
end

local function scrollToBottom()
	if scrollAnchor then
		scrollAnchor:ScrollIntoView(false)
	end
end


local function flushToConsole()
	if not consoleElement then return end

	-- Trim old lines if over limit
	if #lines > MAX_LINES then
		local newLines = {}
		for i = TRIM_COUNT + 1, #lines do
			newLines[#newLines + 1] = lines[i]
		end
		lines = newLines
	end

	-- Selected range (sorted) — highlights every line the last copy grabbed.
	local selLo, selHi = selAnchor, selFocus
	if selLo and selHi and selLo > selHi then selLo, selHi = selHi, selLo end

	-- Build RML: one <p> per line, each with an index attribute for click-to-copy
	local parts = {}
	for i, entry in ipairs(lines) do
		local cls = "console-line"
		if selLo and i >= selLo and i <= selHi then
			cls = cls .. " console-line-copied"
		end
		cls = cls .. entry.cls
		parts[i] = '<p class="' .. cls .. '" line-index="' .. i .. '">' .. escapeRml(entry.text) .. '</p>'
	end
	-- rml-dom-escape: high-volume append-only log — building markup as a
	-- string and injecting it beats a data-for of thousands of lines re-bound
	-- every flush (escape case 3: measured perf hot path). Line click-to-copy
	-- is wired by ONE delegated data-event-click on #console-text (.rml) →
	-- the copyLine() model fn — no per-line inline handlers, no widget: method.
	consoleElement.inner_rml = table.concat(parts)

	if autoScroll then
		scrollToBottom()
	end
end

local function toggleShow(newState)
	if newState == nil then
		newState = not show
	end
	show = newState
	if show then
		document:Show()
	else
		document:Hide()
	end
end

local function initModel()
	return {
		copiedAgo = "",

		my = {
			svgStyles = "h-2-5 w-2-5",
			headerBtn = "px-1-5 py-0-5 rounded text-xs cursor-pointer",
			closeBtn  = "px-1-5 py-0-5 rounded text-xl cursor-pointer",
		},

		clearConsole = function()
			lines = {}
			selAnchor = nil
			selFocus = nil
			dirty = true
		end,

		scrollToBottom = function()
			autoScroll = true
			scrollToBottom()
		end,

		-- Close button: route the view-state change through the model.
		-- toggleShow(false) uses the documented document:Hide() path.
		close = function()
			toggleShow(false)
		end,

		copyAll = function()
			local textParts = {}
			for i, entry in ipairs(lines) do
				textParts[i] = entry.text
			end
			local text = table.concat(textParts, "\n")
			if text ~= "" then
				Spring.SetClipboard(text)
				copiedTimer = spGetTimer()
			end
		end,

		-- Click a log line to copy it. Delegated: a single
		-- data-event-click lives on #console-text; ev.target_element is
		-- the actual clicked <p> (read its line-index), not the bound
		-- container — the one legitimate use of target_element over
		-- current_element (event delegation onto string-injected rows).
		--
		-- Plain click selects (and copies) a single line and sets it as the
		-- anchor; shift+click extends the selection from that anchor to the
		-- clicked line and copies the whole range. The shift state rides on
		-- the click event itself (ev.parameters.shift_key, int 0/1) — the
		-- engine dispatches EventId::Click with the key-modifier parameters.
		copyLine = function(ev)
			local el = ev and ev.target_element
			local idx = el and tonumber(el:GetAttribute("line-index"))
			if not (idx and lines[idx]) then return end

			local params = ev.parameters
			local shift = params and (params.shift_key == 1 or params.shift_key == true)

			if shift and selAnchor then
				selFocus = idx               -- extend the existing selection
			else
				selAnchor = idx              -- start a fresh single-line selection
				selFocus = idx
			end

			local lo, hi = selAnchor, selFocus
			if lo > hi then lo, hi = hi, lo end

			local textParts = {}
			for i = lo, hi do
				if lines[i] then textParts[#textParts + 1] = lines[i].text end
			end
			local text = table.concat(textParts, "\n")
			if text ~= "" then
				Spring.SetClipboard(text)
				copiedTimer = spGetTimer()
				copiedCount = #textParts
			end
			dirty = true
		end,

		onScroll = function()
			autoScroll = false
		end,
	}
end

function widget:Initialize()
	RmlUi.LoadFontFace("fonts/monospaced/SourceCodePro-Medium.otf")

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

	consoleElement = document:GetElementById("console-text")
	scrollAnchor = document:GetElementById("scroll-anchor")
	copiedTextElement = document:GetElementById("copied-text")

	-- utils.initializeRmlWidget auto-calls document:Show(); start hidden.
	document:Hide()
	show = false

	WG['log_viewer_rml'] = {
		toggle = function(state) toggleShow(state) end,
		isVisible = function() return show end,
	}

	-- /log_viewer_rml slash-command and rebindable action entry point.
	widgetHandler:AddAction("log_viewer_rml", function() toggleShow() end, nil, 't')

	return true
end

function widget:Shutdown()
	widgetHandler:RemoveAction("log_viewer_rml")

	utils.shutdownRmlWidget(self, {
		widgetId = WIDGET_ID,
		modelName = MODEL_NAME,
	}, document, dm_handle)

	WG['log_viewer_rml'] = nil
	document = nil
	dm_handle = nil
	consoleElement = nil
	scrollAnchor = nil
	copiedTextElement = nil
	selAnchor = nil
	selFocus = nil
	copiedCount = nil
	lines = {}
end

function widget:AddConsoleLine(msg, priority)
	if priority and priority == L_DEPRECATED and not isDevSingle then return end

	msg = msg:match('^%[f=[0-9]+%] (.*)$') or msg

	local gameFrame = spGetGameFrame()
	local timestamp = formatTimestamp(gameFrame)

	for line in msg:gmatch("[^\n]+") do
		line = stripColorCodes(line)

		if not isPlayerChatMessage(line) and not shouldFilterMessage(line) then
			local cls = (priority and priorityClass[priority]) or classifyByText(line) or ""
			lines[#lines + 1] = { text = timestamp .. " " .. line, cls = cls }
			dirty = true
		end
	end
end

function widget:Update()
	if not document or not dm_handle then return end

	local now = spGetTimer()

	-- Update copiedAgo timer and opacity every frame
	if copiedTimer then
		local elapsed = spDiffTimers(now, copiedTimer)
		if elapsed >= 5 then
			copiedTimer = nil
			selAnchor = nil
			selFocus = nil
			copiedCount = nil
			dm_handle.copiedAgo = ""
			if copiedTextElement then
				copiedTextElement:SetAttribute("style", "opacity: 1;")
			end
			flushToConsole()
		else
			dm_handle.copiedAgo = (copiedCount and copiedCount > 1) and ("COPIED " .. copiedCount) or "COPIED"
			if copiedTextElement then
				local opacity = 1.0 - (elapsed / 5.0)
				copiedTextElement:SetAttribute("style", "opacity: " .. string.format("%.2f", opacity) .. ";")
			end
		end
	end

	-- Flush new lines to DOM at throttled rate
	if dirty then
		if not lastUpdateTimer or spDiffTimers(now, lastUpdateTimer) >= UPDATE_INTERVAL then
			lastUpdateTimer = now
			dirty = false
			flushToConsole()
		end
	end
end

function widget:KeyPress(key, mods, isRepeat)
	if key == KEYSYMS.BACKQUOTE and not isRepeat
	   and not (mods.alt or mods.ctrl or mods.meta or mods.shift) then
		toggleShow()
		return true
	end
	if show and key == KEYSYMS.ESCAPE then
		toggleShow(false)
		return true
	end
	return false
end
