--[[
  Threat Meter Forever for WoW Classic Forever
  Standalone threat meter modeled on Details Tiny Threat (Midnight).
  Does not require the full Details addon.
]]

local ADDON_NAME = ...

local TT = {}
_G.DetailsTinyThreat = TT

local ipairs = ipairs
local pairs = pairs
local unpack = unpack
local floor = math.floor
local abs = math.abs
local max = math.max
local min = math.min
local format = string.format
local tsort = table.sort
local wipe = wipe or table.wipe

local GetTime = GetTime
local GetUnitName = GetUnitName
local UnitClass = UnitClass
local UnitExists = UnitExists
local UnitIsFriend = UnitIsFriend
local UnitIsUnit = UnitIsUnit
local UnitAffectingCombat = UnitAffectingCombat
local IsInRaid = IsInRaid
local IsInGroup = IsInGroup
local GetNumGroupMembers = GetNumGroupMembers
local GetRaidRosterInfo = GetRaidRosterInfo
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local CLASS_ICON_TCOORDS = CLASS_ICON_TCOORDS

local TITLE_HEIGHT = 18
local DEFAULT_WIDTH = 250
local DEFAULT_HEIGHT = 140
local BAR_GAP = 1
local UPDATE_HZ = 0.2

local defaults = {
	enabled = true,
	locked = false,
	hideOutOfCombat = false,
	hideWhenSolo = false,
	point = "CENTER",
	x = 280,
	y = -60,
	width = DEFAULT_WIDTH,
	height = DEFAULT_HEIGHT,
	barHeight = 16,
	fontSize = 11,
	updatespeed = 0.5,
	useplayercolor = true,
	playercolor = {1, 1, 1, 1},
	useclasscolors = true,
	usefocus = false,
	hide_pull_bar = false,
	absolute_mode = false,
	show_party_pets = true,
	only_my_group = false,
	showWindow = true,
	platesThreat = true,
	platesLayoutVersion = 2,
	platesThreatOffsetX = 90,
	platesThreatOffsetY = 0,
	platesThreatLocked = false,
	platesThreatFont = "Fonts\\FRIZQT__.TTF",
	platesThreatFontSize = 12,
	platesThreatOutline = "OUTLINE",
	platesSecureThreshold = 3000,
	platesOverpower = true,
	platesOverpowerOffsetX = -90,
	platesOverpowerOffsetY = 0,
	platesOverpowerLocked = false,
	platesOverpowerSize = 22,
}

local db
local window
local bars = {}
local shownBars = {}
local playerList = {}
local playerHash = {}
local ticker
local inCombat = false
local testMode = false
local playerFullName

local function CopyDefaults(src, dest)
	dest = dest or {}
	for k, v in pairs(src) do
		if type(v) == "table" then
			dest[k] = CopyDefaults(v, dest[k])
		elseif dest[k] == nil then
			dest[k] = v
		end
	end
	return dest
end

local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffThreat Meter Forever|r: " .. tostring(msg))
end

local function ToK2(n)
	n = tonumber(n) or 0
	local sign = ""
	if n < 0 then
		sign = "-"
		n = -n
	end
	local text
	if n >= 1000000000 then
		text = format("%.2fB", n / 1000000000)
	elseif n >= 1000000 then
		text = format("%.2fM", n / 1000000)
	elseif n >= 10000 then
		text = format("%.1fK", n / 1000)
	elseif n >= 1000 then
		text = format("%.1fK", n / 1000)
	elseif n >= 100 then
		text = format("%.0f", n)
	elseif n > 0 and n < 1 then
		text = format("%.2f", n)
	else
		-- Keep one decimal so low Classic values do not round to 0.
		text = format("%.0f", n)
	end
	return sign .. text
end

local function PercentColor(value, inverted)
	value = value or 0
	local r, g
	if value < 50 then
		r = 255
	else
		r = floor(255 - (value * 2 - 100) * 255 / 100)
	end
	if value > 50 then
		g = 255
	else
		g = floor((value * 2) * 255 / 100)
	end
	if inverted then
		return g / 255, r / 255, 0
	end
	return r / 255, g / 255, 0
end

local function ShortName(name)
	if not name then
		return ""
	end
	return name:match("^([^%-]+)") or name
end

local function GetPlayerName()
	return GetUnitName("player", true) or UnitName("player")
end

-- Forever already returns threat in display units. Do not divide by 100;
-- that turns real values like 100 into 1, which is what the window was showing.
local function ThreatSituation(source, target)
	if not UnitDetailedThreatSituation then
		return nil, nil, nil, nil, nil
	end
	local isTanking, status, threatpct, rawthreatpct, threatvalue = UnitDetailedThreatSituation(source, target)
	return isTanking, status, threatpct, rawthreatpct, threatvalue or 0
end
TT.ToK2 = ToK2
TT.ThreatSituation = ThreatSituation

local function GetTrackedUnit()
	if db.usefocus and UnitExists("focus") and not UnitIsFriend("player", "focus") then
		return "focus"
	end
	if UnitExists("target") and not UnitIsFriend("player", "target") then
		return "target"
	end
	return nil
end

local function GetPlayerRaidSubgroup()
	if not IsInRaid() then
		return nil
	end
	for i = 1, GetNumGroupMembers() do
		if UnitIsUnit("raid" .. i, "player") then
			local _, _, subgroup = GetRaidRosterInfo(i)
			return subgroup
		end
	end
	return nil
end

local function ShouldShowWindow()
	if not db.enabled or not db.showWindow then
		return false
	end
	if db.hideWhenSolo and not IsInGroup() and not IsInRaid() then
		return false
	end
	if db.hideOutOfCombat and not inCombat and not testMode then
		return false
	end
	return true
end

local function SetBarTexture(statusbar)
	statusbar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	if statusbar.SetStatusBarDesaturated then
		statusbar:SetStatusBarDesaturated(false)
	end
end

local function CreateBar(index)
	local bar = CreateFrame("StatusBar", "DetailsTinyThreatBar" .. index, window)
	bar:SetMinMaxValues(0, 100)
	bar:SetValue(0)
	SetBarTexture(bar)
	bar:SetStatusBarColor(0.3, 0.7, 1, 1)

	local bg = bar:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0.07, 0.07, 0.07, 0.85)
	bar.bg = bg

	local icon = bar:CreateTexture(nil, "OVERLAY")
	icon:SetSize(14, 14)
	icon:SetPoint("LEFT", bar, "LEFT", 2, 0)
	icon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
	bar.icon = icon

	local right = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	right:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
	right:SetJustifyH("RIGHT")
	bar.right = right

	local left = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	left:SetPoint("LEFT", icon, "RIGHT", 3, 0)
	left:SetPoint("RIGHT", right, "LEFT", -6, 0)
	left:SetJustifyH("LEFT")
	left:SetWordWrap(false)
	bar.left = left

	bar:Hide()
	bars[index] = bar
	return bar
end

local function LayoutBars()
	local width = window:GetWidth()
	local height = window:GetHeight() - TITLE_HEIGHT - 4
	local barHeight = db.barHeight
	local canShow = max(1, floor(height / (barHeight + BAR_GAP)))

	for i = #bars + 1, canShow do
		CreateBar(i)
	end

	wipe(shownBars)
	for i = 1, canShow do
		local bar = bars[i]
		bar:ClearAllPoints()
		bar:SetPoint("TOPLEFT", window, "TOPLEFT", 3, -(TITLE_HEIGHT + 1 + (i - 1) * (barHeight + BAR_GAP)))
		bar:SetPoint("TOPRIGHT", window, "TOPRIGHT", -3, -(TITLE_HEIGHT + 1 + (i - 1) * (barHeight + BAR_GAP)))
		bar:SetHeight(barHeight)
		local fontPath = (GameFontHighlightSmall and GameFontHighlightSmall:GetFont()) or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
		bar.left:SetFont(fontPath, db.fontSize, "OUTLINE")
		bar.right:SetFont(fontPath, db.fontSize, "OUTLINE")
		bar.icon:SetSize(barHeight - 2, barHeight - 2)
		shownBars[i] = bar
	end

	for i = canShow + 1, #bars do
		bars[i]:Hide()
	end
end

local function HideBars()
	for i = 1, #bars do
		bars[i]:Hide()
	end
end

local function SetClassIcon(bar, class)
	bar.icon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
	local coords = class and CLASS_ICON_TCOORDS[class]
	if coords then
		bar.icon:SetTexCoord(unpack(coords))
		bar.icon:Show()
	else
		bar.icon:SetTexCoord(0, 1, 0, 1)
		bar.icon:Hide()
	end
end

local function SetGenericIcon(bar, path)
	bar.icon:SetTexture(path)
	bar.icon:SetTexCoord(0, 1, 0, 1)
	bar.icon:Show()
end

local function PaintBar(bar, r, g, b, a)
	bar:SetStatusBarColor(r, g, b, a or 1)
end

local function ApplyActorColor(bar, actor, pct, isPlayer)
	if isPlayer and db.useplayercolor then
		local c = db.playercolor
		PaintBar(bar, c[1], c[2], c[3], c[4] or 1)
		return
	end
	if db.useclasscolors and actor[5] then
		local color = RAID_CLASS_COLORS[actor[5]]
		if color then
			PaintBar(bar, color.r, color.g, color.b, 1)
			return
		end
	end
	if actor[3] then
		local r, g = 0, 1
		for _, t in ipairs(playerList) do
			if not t[3] then
				local otherPct = t[db.absolute_mode and 7 or 2]
				r, g = (otherPct * 0.01), (abs(otherPct - 100) * 0.01)
				break
			end
		end
		PaintBar(bar, r, g, 0, 1)
	else
		local r, g = PercentColor(pct, true)
		PaintBar(bar, r, g, 0, 1)
	end
end

local function AddActor(unit)
	if not UnitExists(unit) then
		return
	end
	local name = GetUnitName(unit, true)
	if not name or playerHash[name] then
		return
	end
	local _, class = UnitClass(unit)
	local row = {name, 0, false, "NONE", class, 0, 0, unit}
	playerList[#playerList + 1] = row
	playerHash[name] = #playerList
end

local function AddPet(unit, ownerClass)
	if not UnitExists(unit) then
		return
	end
	local petName = GetUnitName(unit, true)
	if not petName then
		return
	end
	petName = petName .. " *PET*"
	if playerHash[petName] then
		return
	end
	local row = {petName, 0, false, "DAMAGER", ownerClass, 0, 0, unit}
	playerList[#playerList + 1] = row
	playerHash[petName] = #playerList
end

local function RebuildRoster()
	wipe(playerList)
	wipe(playerHash)

	if IsInRaid() then
		local myGroup = db.only_my_group and GetPlayerRaidSubgroup() or nil
		for i = 1, GetNumGroupMembers() do
			local unit = "raid" .. i
			if myGroup then
				local _, _, subgroup = GetRaidRosterInfo(i)
				if subgroup == myGroup then
					AddActor(unit)
				end
			else
				AddActor(unit)
			end
		end
	elseif IsInGroup() then
		AddActor("player")
		if db.show_party_pets then
			local _, class = UnitClass("player")
			AddPet("pet", class)
		end
		local partyCount = GetNumGroupMembers() - 1
		for i = 1, partyCount do
			local unit = "party" .. i
			AddActor(unit)
			if db.show_party_pets then
				local _, class = UnitClass(unit)
				AddPet("partypet" .. i, class)
			end
		end
	else
		AddActor("player")
		local _, class = UnitClass("player")
		AddPet("pet", class)
	end
end

local function UpdateActor(actor, unit, threatened)
	local isTanking, status, threatpct, rawthreatpct, threatvalue = ThreatSituation(unit, threatened)
	if status then
		actor[2] = threatpct or 0
		actor[3] = isTanking and true or false
		actor[6] = threatvalue or 0
		actor[7] = isTanking and 100 or (rawthreatpct or 0)
	else
		actor[2] = 0
		actor[3] = false
		actor[6] = 0
		actor[7] = 0
	end
end

local function SortAbsolute(a, b)
	return (a[6] or 0) > (b[6] or 0)
end

local function SortRelative(a, b)
	return (a[2] or 0) > (b[2] or 0)
end

local function ShowDummyBar(bar, leftText, rightText, value, r, g, b, iconPath)
	bar.left:SetText(leftText)
	bar.right:SetText(rightText)
	bar:SetValue(value)
	PaintBar(bar, r, g, b, 1)
	if iconPath then
		SetGenericIcon(bar, iconPath)
	else
		bar.icon:Hide()
	end
	bar:Show()
end

local function RefreshThreat()
	if not window then
		return
	end

	if not ShouldShowWindow() then
		window:Hide()
		return
	end
	window:Show()

	if testMode then
		return
	end

	local unitId = GetTrackedUnit()
	if not inCombat or not unitId then
		HideBars()
		return
	end

	if #playerList == 0 then
		RebuildRoster()
	end

	for i = 1, #playerList do
		local actor = playerList[i]
		if actor[8] and UnitExists(actor[8]) then
			UpdateActor(actor, actor[8], unitId)
		else
			UpdateActor(actor, actor[1], unitId)
		end
		playerHash[actor[1]] = i
	end

	local useAbsolute = db.absolute_mode
	tsort(playerList, useAbsolute and SortAbsolute or SortRelative)
	local needMainTankDummy = true
	for i = 1, #playerList do
		playerHash[playerList[i][1]] = i
		if playerList[i][3] then
			needMainTankDummy = false
		end
	end

	if not playerList[1] or (playerList[1][7] or 0) < 1 then
		HideBars()
		return
	end

	local topRaw = playerList[1][7]
	if topRaw < 1 then
		HideBars()
		return
	end

	local rawDiv = playerList[1][7] / 100
	if rawDiv <= 0 then
		HideBars()
		return
	end
	local mainTankThreat = playerList[1][6] / rawDiv
	local hidePullBar = db.hide_pull_bar
	local needRangedPull = (not hidePullBar) and useAbsolute
	local needMeleePull = (not hidePullBar) and useAbsolute

	local me = playerHash[playerFullName] and playerList[playerHash[playerFullName]]
	local needRelativePull = (not hidePullBar) and (not useAbsolute) and me and me[2] > 0 and (not me[3])

	local barValueUnit = 1
	if useAbsolute then
		barValueUnit = max(playerList[1][7] / 100, needRangedPull and 1.3 or needMeleePull and 1.1 or 1.0)
	end

	local index = 1
	local lastIndex = #shownBars
	local dummyCount = 0
	local shownMe = false

	while index <= lastIndex do
		local bar = shownBars[index]
		local actor = playerList[index - dummyCount]

		if needRelativePull then
			local myPullThreat = me[6] * (100 / me[2])
			local r, g = PercentColor(me[2], true)
			ShowDummyBar(
				bar,
				"You pull at",
				"+" .. ToK2(myPullThreat - me[6]) .. " (" .. format("%.1f", 100 - me[2]) .. "%)",
				me[2] / barValueUnit,
				r, g, 0,
				"Interface\\Icons\\Ability_Warrior_OffensiveStance"
			)
			needRelativePull = false
			index = index + 1
			dummyCount = dummyCount + 1
			if index > lastIndex then
				break
			end
			bar = shownBars[index]
		end

		if needRangedPull and ((not actor) or actor[7] < 130) then
			ShowDummyBar(
				bar,
				"Ranged pull at",
				ToK2(mainTankThreat * 1.3) .. " (130.0%)",
				130 / barValueUnit,
				1, 0, 0,
				"Interface\\PaperDoll\\UI-PaperDoll-Slot-Ranged"
			)
			needRangedPull = false
			index = index + 1
			dummyCount = dummyCount + 1
			if index > lastIndex then
				break
			end
			bar = shownBars[index]
		end

		if needMeleePull and ((not actor) or actor[7] < 110) then
			ShowDummyBar(
				bar,
				"Melee pull at",
				ToK2(mainTankThreat * 1.1) .. " (110.0%)",
				110 / barValueUnit,
				1, 0, 0,
				"Interface\\PaperDoll\\UI-PaperDoll-Slot-MainHand"
			)
			needMeleePull = false
			index = index + 1
			dummyCount = dummyCount + 1
			if index > lastIndex then
				break
			end
			bar = shownBars[index]
		end

		if needMainTankDummy and ((not actor) or (not useAbsolute) or (actor[6] < mainTankThreat)) then
			local r, g = 0, 1
			for _, t in ipairs(playerList) do
				if not t[3] then
					local otherPct = t[useAbsolute and 7 or 2] or 0
					r, g = otherPct * 0.01, abs(otherPct - 100) * 0.01
					break
				end
			end
			ShowDummyBar(
				bar,
				"Current Tank",
				ToK2(mainTankThreat) .. " (100.0%)",
				100 / barValueUnit,
				r, g, 0,
				"Interface\\Icons\\Ability_Warrior_DefensiveStance"
			)
			needMainTankDummy = false
			index = index + 1
			dummyCount = dummyCount + 1
			if index > lastIndex then
				break
			end
			bar = shownBars[index]
		end

		if actor then
			local pct = actor[useAbsolute and 7 or 2] or 0
			bar.left:SetText(ShortName(actor[1]))
			bar.right:SetText(ToK2(actor[6]) .. " (" .. format("%.1f", pct) .. "%)")
			bar:SetValue(pct / barValueUnit)
			SetClassIcon(bar, actor[5])
			ApplyActorColor(bar, actor, pct, actor[1] == playerFullName)
			bar:Show()
			if actor[1] == playerFullName then
				shownMe = true
			end
		else
			bar:Hide()
		end

		index = index + 1
	end

	if (not shownMe) and me and me[2] and me[2] > 0.1 and shownBars[lastIndex] then
		local bar = shownBars[lastIndex]
		bar.left:SetText(ShortName(me[1]))
		bar.right:SetText(ToK2(me[6]) .. " (" .. format("%.1f", me[2]) .. "%)")
		bar:SetValue(me[2])
		SetClassIcon(bar, me[5])
		if db.useplayercolor then
			local c = db.playercolor
			PaintBar(bar, c[1], c[2], c[3], c[4] or 1)
		else
			local r, g = PercentColor(me[2], true)
			PaintBar(bar, r, g, 0, 0.35)
		end
		bar:Show()
	end
end

local function ShowTestBars()
	testMode = true
	window:Show()
	LayoutBars()
	local classes = {"WARRIOR", "MAGE", "ROGUE", "PRIEST", "HUNTER"}
	local names = {ShortName(GetPlayerName()), "Tankly", "Frosty", "Stabby", "Holyone"}
	local values = {72, 100, 64, 41, 18}
	for i = 1, #shownBars do
		local bar = shownBars[i]
		if names[i] then
			bar.left:SetText(names[i])
			bar.right:SetText(ToK2(values[i] * 120) .. " (" .. format("%.1f", values[i]) .. "%)")
			bar:SetValue(values[i])
			SetClassIcon(bar, classes[i])
			local color = RAID_CLASS_COLORS[classes[i]]
			if color then
				PaintBar(bar, color.r, color.g, color.b, 1)
			end
			bar:Show()
		else
			bar:Hide()
		end
	end
	C_Timer.After(6, function()
		testMode = false
		RefreshThreat()
	end)
end

local function StopTicker()
	if ticker then
		ticker:Cancel()
		ticker = nil
	end
end

local function StartTicker()
	StopTicker()
	inCombat = true
	playerFullName = GetPlayerName()
	RebuildRoster()
	local speed = db.updatespeed or 0.5
	if speed < UPDATE_HZ then
		speed = UPDATE_HZ
	end
	ticker = C_Timer.NewTicker(speed, RefreshThreat)
	RefreshThreat()
end

local function LeaveCombat()
	inCombat = false
	StopTicker()
	HideBars()
	if ShouldShowWindow() then
		window:Show()
	else
		window:Hide()
	end
end

local function SavePosition()
	if not window then
		return
	end
	local point, _, _, x, y = window:GetPoint(1)
	db.point = point or "CENTER"
	db.x = x or 0
	db.y = y or 0
	db.width = window:GetWidth()
	db.height = window:GetHeight()
end

local function ApplyLock()
	if db.locked then
		window:EnableMouse(false)
		window.resize:Hide()
	else
		window:EnableMouse(true)
		window.resize:Show()
	end
end

local function CreateWindow()
	window = CreateFrame("Frame", "DetailsTinyThreatFrame", UIParent, "BackdropTemplate")
	window:SetSize(db.width or DEFAULT_WIDTH, db.height or DEFAULT_HEIGHT)
	window:SetPoint(db.point or "CENTER", UIParent, db.point or "CENTER", db.x or 280, db.y or -60)
	window:SetClampedToScreen(true)
	window:SetFrameStrata("MEDIUM")
	window:SetMovable(true)
	window:SetResizable(true)
	if window.SetResizeBounds then
		window:SetResizeBounds(160, 70, 600, 600)
	elseif window.SetMinResize then
		window:SetMinResize(160, 70)
		window:SetMaxResize(600, 600)
	end
	window:EnableMouse(true)
	window:RegisterForDrag("LeftButton")
	window:SetScript("OnDragStart", function(self)
		if not db.locked then
			self:StartMoving()
		end
	end)
	window:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		SavePosition()
	end)

	window:SetBackdrop({
		bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 12,
		insets = {left = 2, right = 2, top = 2, bottom = 2},
	})
	window:SetBackdropColor(0.05, 0.05, 0.05, 0.92)
	window:SetBackdropBorderColor(0.15, 0.15, 0.15, 1)

	local titleBg = window:CreateTexture(nil, "ARTWORK")
	titleBg:SetPoint("TOPLEFT", 3, -3)
	titleBg:SetPoint("TOPRIGHT", -3, -3)
	titleBg:SetHeight(TITLE_HEIGHT - 4)
	titleBg:SetColorTexture(0.12, 0.12, 0.12, 1)

	local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	title:SetPoint("LEFT", window, "TOPLEFT", 8, -(TITLE_HEIGHT / 2))
	title:SetText("|cff00ccffThreat Meter|r Forever")
	window.title = title

	local config = CreateFrame("Button", nil, window)
	config:SetSize(14, 14)
	config:SetPoint("RIGHT", window, "TOPRIGHT", -20, -(TITLE_HEIGHT / 2))
	config:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
	config:SetHighlightTexture("Interface\\Buttons\\UI-OptionsButton")
	config:SetScript("OnClick", function()
		TT.ToggleOptions()
	end)
	config:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("Tiny Threat options", 1, 1, 1)
		GameTooltip:AddLine("Right-click the title bar for a menu.", 0.8, 0.8, 0.8, true)
		GameTooltip:Show()
	end)
	config:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
	close:SetSize(20, 20)
	close:SetPoint("RIGHT", window, "TOPRIGHT", 0, -(TITLE_HEIGHT / 2) + 1)
	close:SetScript("OnClick", function()
		db.showWindow = false
		window:Hide()
		Print("window hidden. Type |cffffff00/dtt show|r to restore it.")
	end)

	window:SetScript("OnMouseUp", function(self, button)
		if button == "RightButton" then
			TT.ToggleOptions()
		end
	end)

	local resize = CreateFrame("Button", nil, window)
	resize:SetSize(14, 14)
	resize:SetPoint("BOTTOMRIGHT", -1, 1)
	resize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	resize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	resize:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	resize:SetScript("OnMouseDown", function()
		if not db.locked then
			window:StartSizing("BOTTOMRIGHT")
		end
	end)
	resize:SetScript("OnMouseUp", function()
		window:StopMovingOrSizing()
		SavePosition()
		LayoutBars()
		RefreshThreat()
	end)
	window.resize = resize

	window:SetScript("OnSizeChanged", function()
		if window:IsShown() then
			LayoutBars()
		end
	end)

	LayoutBars()
	ApplyLock()
end

function TT.OnOptionChanged(key)
	if key == "locked" then
		ApplyLock()
	end
	if key == "enabled" or key == "hideOutOfCombat" or key == "hideWhenSolo" or key == "showWindow" then
		if window then
			if ShouldShowWindow() then
				window:Show()
			else
				window:Hide()
			end
		end
	end
	if type(key) == "string" and key:find("^plates") then
		if TT.Plates and TT.Plates.Enable then
			TT.Plates.Enable()
		end
	end
	RebuildRoster()
	RefreshThreat()
end

SLASH_DETAILSTINYTHREAT1 = "/dtt"
SLASH_DETAILSTINYTHREAT2 = "/detailsthreat"

SlashCmdList.DETAILSTINYTHREAT = function(msg)
	msg = (msg or ""):lower():match("^%s*(.-)%s*$")
	if msg == "" or msg == "help" then
		Print("commands:")
		print("  |cffffff00/dtt|r - open options")
		print("  |cffffff00/dtt lock|r - lock/unlock the window")
		print("  |cffffff00/dtt show|r / |cffffff00hide|r - toggle the window")
		print("  |cffffff00/dtt test|r - show sample bars")
		print("  |cffffff00/dtt reset|r - reset position and size")
		print("  |cffffff00/dtt absolute|r - toggle 110%/130% pull mode")
		print("  |cffffff00/dtt plates|r - toggle nameplate threat numbers")
		print("  |cffffff00/dtt overpower|r - toggle Overpower icons on plates")
	elseif msg == "lock" or msg == "unlock" then
		db.locked = not db.locked
		ApplyLock()
		Print(db.locked and "window locked." or "window unlocked. Drag to move, corner to resize.")
	elseif msg == "show" then
		db.enabled = true
		db.showWindow = true
		window:Show()
	elseif msg == "hide" then
		db.showWindow = false
		window:Hide()
	elseif msg == "test" then
		db.showWindow = true
		ShowTestBars()
	elseif msg == "reset" then
		db.point, db.x, db.y = "CENTER", 280, -60
		db.width, db.height = DEFAULT_WIDTH, DEFAULT_HEIGHT
		window:ClearAllPoints()
		window:SetSize(DEFAULT_WIDTH, DEFAULT_HEIGHT)
		window:SetPoint("CENTER", UIParent, "CENTER", 280, -60)
		LayoutBars()
		Print("position reset.")
	elseif msg == "absolute" then
		db.absolute_mode = not db.absolute_mode
		Print(db.absolute_mode and "absolute threat (110%/130% pull)." or "relative threat (pull at 100%).")
		RefreshThreat()
	elseif msg == "plates" then
		db.platesThreat = not db.platesThreat
		if TT.Plates then
			TT.Plates.Enable()
		end
		Print(db.platesThreat and "nameplate threat numbers on." or "nameplate threat numbers off.")
	elseif msg == "overpower" or msg == "op" then
		db.platesOverpower = not db.platesOverpower
		if TT.Plates then
			TT.Plates.Enable()
		end
		Print(db.platesOverpower and "Overpower icons on plates on." or "Overpower icons on plates off.")
	elseif msg == "config" or msg == "options" then
		TT.ToggleOptions()
	else
		TT.ToggleOptions()
	end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("UNIT_PET")
pcall(eventFrame.RegisterEvent, eventFrame, "PLAYER_FOCUS_CHANGED")

eventFrame:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= ADDON_NAME then
			return
		end
		if DetailsTinyThreatDB and (DetailsTinyThreatDB.platesLayoutVersion or 0) < 2 then
			local saved = DetailsTinyThreatDB
			local function convert(anchor, ox, oy)
				ox = tonumber(ox) or 8
				oy = tonumber(oy) or 0
				if math.abs(ox) > 20 then
					return ox, oy
				end
				if anchor == "LEFT" then
					return -75 - ox, oy
				elseif anchor == "RIGHT" then
					return 75 + ox, oy
				elseif anchor == "TOP" then
					return 0, 20 + oy
				elseif anchor == "BOTTOM" then
					return 0, -20 + oy
				end
				return ox, oy
			end
			local tAnchor = saved.platesThreatAnchor or (saved.platesThreatLeft and "LEFT") or "RIGHT"
			saved.platesThreatOffsetX, saved.platesThreatOffsetY = convert(tAnchor, saved.platesThreatOffsetX, saved.platesThreatOffsetY)
			local oAnchor = saved.platesOverpowerAnchor or (saved.platesOverpowerLeft and "LEFT") or "LEFT"
			saved.platesOverpowerOffsetX, saved.platesOverpowerOffsetY = convert(oAnchor, saved.platesOverpowerOffsetX, saved.platesOverpowerOffsetY)
			saved.platesLayoutVersion = 2
		end
		DetailsTinyThreatDB = CopyDefaults(defaults, DetailsTinyThreatDB)
		db = DetailsTinyThreatDB
		TT.db = db
	elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
		if not window then
			CreateWindow()
			if TT.CreateOptions then
				TT.CreateOptions()
			end
		end
		playerFullName = GetPlayerName()
		if TT.Plates and TT.Plates.OnLogin then
			TT.Plates.OnLogin()
		end
		if UnitAffectingCombat("player") then
			StartTicker()
		else
			if ShouldShowWindow() then
				window:Show()
			else
				window:Hide()
			end
		end
		if event == "PLAYER_LOGIN" then
			if not UnitDetailedThreatSituation then
				Print("this client has no threat API. The window will stay empty.")
			else
				Print("loaded. Drag the window to move it, |cffffff00/dtt|r for options, |cffffff00/dtt test|r for a preview.")
			end
		end
	elseif event == "PLAYER_REGEN_DISABLED" then
		StartTicker()
	elseif event == "PLAYER_REGEN_ENABLED" then
		LeaveCombat()
	elseif event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" then
		RefreshThreat()
	elseif event == "GROUP_ROSTER_UPDATE" or event == "UNIT_PET" then
		if inCombat then
			RebuildRoster()
		end
		RefreshThreat()
	end
end)
