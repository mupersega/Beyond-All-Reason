if not RmlUi then
	return
end

local widget = widget ---@type Widget
local utils = VFS.Include("luaui/Include/rml_utilities/utils.lua")

function widget:GetInfo()
	return {
		name = "rml_tooltip_layer",
		desc = "RML-native tooltip overlay for all RML widgets",
		author = "mupersega",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 2,
		enabled = true,
	}
end

-- Constants
local WIDGET_ID = "rml_tooltip_layer"
local MODEL_NAME = "rml_tooltip_layer_model"
local RML_PATH = "luaui/RmlWidgets/rml_tooltip_layer/rml_tooltip_layer.rml"

-- Tooltip slot dimensions (dp) — max-width matches RCSS, heights are
-- estimates for edge clamping (actual height is content-driven)
local SLOT_DESC_W = 200
local SLOT_DESC_H = 40
local SLOT_TITLED_W = 200
local SLOT_TITLED_H = 56

-- Positioning
local CURSOR_OFFSET = 10  -- dp offset from cursor
local PARK_POS = "-9999dp"
local STALE_THRESHOLD = 10  -- draw frames without Show() before auto-hide (~170ms at 60fps)

-- RML state
local document
local dm_handle

-- Cached element references (GetElementById once at init, reuse forever)
local elTooltipDesc
local elTooltipTitled
local elTooltipTitledTitle
local elTooltipTitledDesc

-- Active tooltip state
local activeSlot = nil
local activeSlotW = 0
local activeSlotH = 0
local lastShowFrame = -100

-- Viewport cache
local vsx, vsy = Spring.GetViewGeometry()

-- Localized API
local spGetViewGeometry = Spring.GetViewGeometry
local spGetDrawFrame = Spring.GetDrawFrame
local mathMax = math.max
local mathMin = math.min
local strFormat = string.format

-- ── Coordinate conversion ──────────────────────────────────────────────
-- Spring px ↔ RML dp lives in shared utils (also drives every context's
-- dp_ratio via rml_context_manager): utils.getDpRatio() / utils.springToDp().
-- See luaui/Include/rml_utilities/utils.lua.

-- ── Edge clamping ──────────────────────────────────────────────────────

local function clampPosition(cursorDpX, cursorDpY, slotW, slotH)
	local dpRatio = utils.getDpRatio()
	if dpRatio <= 0 then dpRatio = 1 end
	local vpW = vsx / dpRatio
	local vpH = vsy / dpRatio

	-- Default: offset to right and below cursor
	local x = cursorDpX + CURSOR_OFFSET
	local y = cursorDpY + CURSOR_OFFSET

	-- Flip horizontally if overflows right
	if x + slotW > vpW then
		x = cursorDpX - CURSOR_OFFSET - slotW
	end

	-- Flip vertically if overflows bottom
	if y + slotH > vpH then
		y = cursorDpY - CURSOR_OFFSET - slotH
	end

	-- Final clamp to viewport bounds
	x = mathMax(0, mathMin(x, vpW - slotW))
	y = mathMax(0, mathMin(y, vpH - slotH))

	return x, y
end

-- ── Slot management ────────────────────────────────────────────────────

local function parkSlot(el)
	if el then
		el:SetAttribute("style", strFormat("left: %s; top: %s;", PARK_POS, PARK_POS))
	end
end

local function positionSlot(el, dpX, dpY)
	if el then
		el:SetAttribute("style", strFormat("left: %.1fdp; top: %.1fdp;", dpX, dpY))
	end
end

local function hideActive()
	if activeSlot then
		parkSlot(activeSlot)
		activeSlot = nil
	end
end

-- ── Core show functions ────────────────────────────────────────────────

local function showDescTooltip(content, springX, springY)
	hideActive()

	elTooltipDesc.inner_rml = content

	local cursorDpX, cursorDpY = utils.springToDp(springX, springY)
	local dpX, dpY = clampPosition(cursorDpX, cursorDpY, SLOT_DESC_W, SLOT_DESC_H)

	positionSlot(elTooltipDesc, dpX, dpY)
	activeSlot = elTooltipDesc
	activeSlotW = SLOT_DESC_W
	activeSlotH = SLOT_DESC_H
	lastShowFrame = spGetDrawFrame()
	document:Show()
end

local function showTitledTooltip(content, springX, springY, title)
	hideActive()

	elTooltipTitledTitle.inner_rml = title
	elTooltipTitledDesc.inner_rml = content

	local cursorDpX, cursorDpY = utils.springToDp(springX, springY)
	local dpX, dpY = clampPosition(cursorDpX, cursorDpY, SLOT_TITLED_W, SLOT_TITLED_H)

	positionSlot(elTooltipTitled, dpX, dpY)
	activeSlot = elTooltipTitled
	activeSlotW = SLOT_TITLED_W
	activeSlotH = SLOT_TITLED_H
	lastShowFrame = spGetDrawFrame()
	document:Show()
end

-- ── Public API ─────────────────────────────────────────────────────────

local function apiShow(content, x, y, title)
	if not content or content == "" then
		hideActive()
		return
	end
	if title and title ~= "" then
		showTitledTooltip(content, x, y, title)
	else
		showDescTooltip(content, x, y)
	end
end

local function apiHide()
	hideActive()
end

-- ── Model (minimal — exists to satisfy initializeRmlWidget) ────────────

local function initModel()
	return {
		my = {
			titledTitle = "font-bold",
			titledDesc = "text-xs text-medium mt-1",
		},
	}
end

-- ── Widget lifecycle ───────────────────────────────────────────────────

function widget:Initialize()
	vsx, vsy = spGetViewGeometry()

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

	-- Cache element references (once, reused for lifetime)
	elTooltipDesc = document:GetElementById("tooltip-desc")
	elTooltipTitled = document:GetElementById("tooltip-titled")
	elTooltipTitledTitle = document:GetElementById("tooltip-titled-title")
	elTooltipTitledDesc = document:GetElementById("tooltip-titled-desc")

	-- Park all slots off-screen
	parkSlot(elTooltipDesc)
	parkSlot(elTooltipTitled)

	-- Expose WG service API
	WG['rml_tooltip'] = {
		Show = apiShow,
		Hide = apiHide,
	}

	return true
end

function widget:Shutdown()
	WG['rml_tooltip'] = nil

	if document then
		utils.shutdownRmlWidget(self, {
			widgetId = WIDGET_ID,
			modelName = MODEL_NAME,
		}, document, dm_handle)
	end

	document = nil
	dm_handle = nil
	elTooltipDesc = nil
	elTooltipTitled = nil
	elTooltipTitledTitle = nil
	elTooltipTitledDesc = nil
	activeSlot = nil
end

function widget:ViewResize()
	vsx, vsy = spGetViewGeometry()
end

function widget:Update(dt)
	-- Stale detection: if no Show() call for STALE_THRESHOLD frames,
	-- the consumer stopped driving the tooltip. Auto-hide as safety net.
	if activeSlot then
		if spGetDrawFrame() - lastShowFrame > STALE_THRESHOLD then
			hideActive()
		end
	end
end
