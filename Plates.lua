--[[
  Nameplate overlays for Classic Forever.

  Forever uses Midnight secret values: threat APIs on "nameplateN" tokens
  return secrets that Lua cannot test or do math on. Combat log registration
  from a tainted login path is also forbidden.

  Safe approach:
  - Never pass nameplate unit IDs into UnitDetailedThreatSituation.
  - Map plates via C_NamePlate.GetNamePlateForUnit for target/focus/mouseover/pettarget only.
    Forever rejects partyN/raidN tokens in that API; those are matched from GetNamePlates().
  - Show Overpower when the spell is usable, on the current target plate.
]]

local TT = _G.DetailsTinyThreat
if not TT then
	return
end

local Plates = {}
TT.Plates = Plates

local pairs = pairs
local format = string.format
local wipe = wipe or table.wipe
local GetTime = GetTime
local UnitExists = UnitExists
local UnitIsUnit = UnitIsUnit
local IsInRaid = IsInRaid
local IsInGroup = IsInGroup
local GetNumGroupMembers = GetNumGroupMembers

local OVERPOWER_WINDOW = 5
local OVERPOWER_ICON = "Interface\\Icons\\Ability_MeleeDamage"
local OVERPOWER_SPELLS = {7384, 7887, 11584, 11585, 25286}
local OVERPOWER_IDS = {
	[7384] = true,
	[7887] = true,
	[11584] = true,
	[11585] = true,
	[25286] = true,
}
local REVENGE_SPELLS = {
	[6572] = true,
	[6574] = true,
	[7379] = true,
	[11600] = true,
	[11601] = true,
	[25288] = true,
	[25269] = true,
	[30357] = true,
}
local TANK_AURAS = {
	[71] = true,
	[5487] = true,
	[9634] = true,
	[25780] = true,
}

local overlays = {}
local opUntilPlate = {}
local ticker
local events

local function DB()
	return TT.db
end

local function IsSecret(v)
	return issecretvalue and issecretvalue(v)
end

local function SafeBool(v)
	if IsSecret(v) then
		return false
	end
	if v then
		return true
	end
	return false
end

local function SafeNum(v)
	if IsSecret(v) then
		return nil
	end
	return v
end

local function ToK2(n)
	if TT.ToK2 then
		return TT.ToK2(n)
	end
	n = tonumber(n) or 0
	if n >= 10000 then
		return format("%.1fK", n / 1000)
	elseif n >= 1000 then
		return format("%.1fK", n / 1000)
	end
	return format("%.0f", n)
end

local function ThreatSit(unit, mob)
	if not UnitDetailedThreatSituation then
		return
	end
	local ok, a, b, c, d, e = pcall(UnitDetailedThreatSituation, unit, mob)
	if not ok then
		return
	end
	return a, b, c, d, e
end

local function PlatesReady()
	return C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlates
end

local function PlateOk(plate)
	return plate and not (plate.IsForbidden and plate:IsForbidden())
end

local function ForEachGroupUnit(fn)
	fn("player")
	if IsInRaid() then
		for i = 1, GetNumGroupMembers() do
			fn("raid" .. i)
		end
	elseif IsInGroup() then
		for i = 1, GetNumGroupMembers() - 1 do
			fn("party" .. i)
		end
	end
	if UnitExists("pet") then
		fn("pet")
	end
end

local function UnitHasTankAura(unit)
	if not UnitExists(unit) then
		return false
	end
	if UnitGroupRolesAssigned then
		local ok, role = pcall(UnitGroupRolesAssigned, unit)
		if ok and role == "TANK" then
			return true
		end
	end
	local function scan()
		if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
			for i = 1, 40 do
				local data = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
				if not data then
					break
				end
				if data.spellId and TANK_AURAS[data.spellId] then
					return true
				end
			end
			return false
		end
		for i = 1, 40 do
			local name, _, _, _, _, _, _, _, _, spellId = UnitBuff(unit, i)
			if not name then
				break
			end
			if spellId and TANK_AURAS[spellId] then
				return true
			end
		end
		return false
	end
	local ok, result = pcall(scan)
	return ok and result
end

local function PlayerKnowsOverpower()
	local _, class = UnitClass("player")
	if class ~= "WARRIOR" then
		return false
	end
	local check = IsPlayerSpell or IsSpellKnown
	if check then
		for i = 1, #OVERPOWER_SPELLS do
		local ok, known = pcall(check, OVERPOWER_SPELLS[i])
		if ok and not IsSecret(known) and known then
			return true
		end
	end
	end
	return class == "WARRIOR"
end

local function OverpowerProcActive()
	if not PlayerKnowsOverpower() then
		return false
	end
	local sawSecret = false
	local function check(spell)
		local ok, usable, nomana = pcall(IsUsableSpell, spell)
		if not ok then
			return false
		end
		if IsSecret(usable) then
			sawSecret = true
			return false
		end
		if usable then
			return true
		end
		if IsSecret(nomana) then
			sawSecret = true
			return false
		end
		return nomana and true or false
	end
	if check("Overpower") then
		return true
	end
	for i = #OVERPOWER_SPELLS, 1, -1 do
		if check(OVERPOWER_SPELLS[i]) then
			return true
		end
	end
	if sawSecret then
		return nil
	end
	return false
end

local function IsSimpleMobToken(token)
	return token == "target" or token == "focus" or token == "mouseover" or token == "pettarget"
end

local function IsGroupUnitToken(token)
	return type(token) == "string" and (token:find("^party") or token:find("^raid"))
end

local function PlateUnitToken(plate)
	if not plate then
		return nil
	end
	local unit = plate.namePlateUnitToken
	if type(unit) == "string" then
		return unit
	end
	local uf = plate.UnitFrame
	if uf and type(uf.unit) == "string" then
		return uf.unit
	end
	return nil
end

local function UnitsAreSame(a, b)
	if not a or not b then
		return false
	end
	local ok, same = pcall(UnitIsUnit, a, b)
	if not ok or same == nil or IsSecret(same) then
		return false
	end
	return same and true or false
end

local function SafeGetNamePlate(token)
	if not token or not PlatesReady() then
		return nil
	end
	if not IsGroupUnitToken(token) then
		local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, token)
		if ok then
			return plate
		end
		return nil
	end
	local plates = C_NamePlate.GetNamePlates()
	if not plates then
		return nil
	end
	for i = 1, #plates do
		local plate = plates[i]
		local unit = PlateUnitToken(plate)
		if unit and UnitsAreSame(unit, token) then
			return plate
		end
	end
	return nil
end

local function CollectMobTokens()
	local list = {}
	local function add(token)
		if token and UnitExists(token) then
			list[#list + 1] = token
		end
	end
	add("target")
	add("focus")
	add("mouseover")
	add("pettarget")
	if IsInRaid() then
		for i = 1, GetNumGroupMembers() do
			add("raid" .. i .. "target")
		end
	elseif IsInGroup() then
		for i = 1, GetNumGroupMembers() - 1 do
			add("party" .. i .. "target")
		end
	end
	return list
end

local function GetOverlay(plate)
	local ov = overlays[plate]
	if ov then
		return ov
	end

	ov = CreateFrame("Frame", nil, plate)
	ov:SetFrameStrata("HIGH")
	ov:SetAllPoints(plate)
	ov:EnableMouse(false)

	local text = ov:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	pcall(text.SetFont, text, (GameFontHighlightSmall and select(1, GameFontHighlightSmall:GetFont())) or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
	text:SetShadowOffset(1, -1)
	ov.text = text

	local icon = ov:CreateTexture(nil, "OVERLAY")
	icon:SetTexture(OVERPOWER_ICON)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	icon:Hide()
	ov.icon = icon

	overlays[plate] = ov
	return ov
end

local function LayoutOverlay(ov, db)
	local size = db.platesOverpowerSize or 22

	ov.text:ClearAllPoints()
	ov.text:SetPoint("CENTER", ov, "CENTER", db.platesThreatOffsetX or 90, db.platesThreatOffsetY or 0)
	ov.text:SetJustifyH("CENTER")
	ov.text:SetFont(db.platesThreatFont or "Fonts\\FRIZQT__.TTF", db.platesThreatFontSize or 12, db.platesThreatOutline or "OUTLINE")

	ov.icon:ClearAllPoints()
	ov.icon:SetSize(size, size)
	ov.icon:SetPoint("CENTER", ov, "CENTER", db.platesOverpowerOffsetX or -90, db.platesOverpowerOffsetY or 0)
end

local function HideOverlay(ov)
	if not ov then
		return
	end
	ov.text:SetText("")
	ov.icon:Hide()
	ov:Hide()
end

local function ComputeThreatDiff(mobToken)
	local isTankingRaw, statusRaw, _, _, myThreatRaw = ThreatSit("player", mobToken)
	local isTanking = SafeBool(isTankingRaw)
	local status = SafeNum(statusRaw)
	local myThreat = SafeNum(myThreatRaw)

	if myThreat == nil then
		if IsSecret(myThreatRaw) then
			return myThreatRaw, 1, 1, 1, true
		end
		return nil
	end

	local highestOther = 0
	local highestIsTank = false
	local otherIsTanking = false

	if IsSimpleMobToken(mobToken) or IsGroupUnitToken(mobToken) then
		ForEachGroupUnit(function(member)
			if member == "player" then
				return
			end
			local otherTankingRaw, _, _, _, otherThreatRaw = ThreatSit(member, mobToken)
			local otherThreat = SafeNum(otherThreatRaw)
			if otherThreat == nil then
				return
			end
			if SafeBool(otherTankingRaw) then
				otherIsTanking = true
			end
			if otherThreat > highestOther then
				highestOther = otherThreat
				highestIsTank = UnitHasTankAura(member)
			end
		end)
	end

	local diff = myThreat - highestOther
	local playerIsTank = UnitHasTankAura("player")
	local threshold = (DB() and DB().platesSecureThreshold) or 3000

	local r, g, b = 1, 0.15, 0.15
	local text

	if isTanking then
		if (status == 3 or diff >= threshold) then
			r, g, b = 0.2, 1, 0.2
			text = "+" .. ToK2(diff)
		elseif highestIsTank and diff < threshold then
			r, g, b = 1, 0.9, 0.2
			text = "+" .. ToK2(diff)
		else
			r, g, b = 1, 0.55, 0.1
			if diff < 1 then
				text = "!!!"
			else
				text = "+" .. ToK2(diff)
			end
		end
	else
		if otherIsTanking then
			r, g, b = 0.25, 0.55, 1
		else
			r, g, b = 1, 0.15, 0.15
		end
		if diff < 0 then
			text = ToK2(diff)
		elseif diff == 0 then
			text = "0"
		else
			text = "+" .. ToK2(diff)
		end
		if playerIsTank then
			r, g, b = 1, 0.15, 0.15
		end
	end

	return text, r, g, b, false
end

local function UpdatePlateByToken(mobToken, plate)
	local db = DB()
	if not db then
		return false
	end
	if not PlateOk(plate) then
		return false
	end

	local ov = GetOverlay(plate)
	ov:SetParent(plate)
	ov:ClearAllPoints()
	ov:SetAllPoints(plate)
	pcall(function()
		ov:SetFrameLevel((plate:GetFrameLevel() or 0) + 20)
	end)
	LayoutOverlay(ov, db)

	local showAnything = false

	if db.platesThreat then
		local text, r, g, b, rawSecret = ComputeThreatDiff(mobToken)
		if text then
			if rawSecret then
				ov.text:SetFormattedText("%s", text)
				ov.text:SetTextColor(1, 1, 1, 1)
			else
				ov.text:SetText(text)
				ov.text:SetTextColor(r, g, b, 1)
			end
			showAnything = true
		else
			ov.text:SetText("")
		end
	else
		ov.text:SetText("")
	end

	local showOp = false
	if db.platesOverpower then
		local proc = OverpowerProcActive()
		local targetPlate = SafeGetNamePlate("target")
		local expire = opUntilPlate[plate]
		if expire and GetTime() >= expire then
			opUntilPlate[plate] = nil
			expire = nil
		end
		if proc == true and plate == targetPlate then
			showOp = true
		elseif proc ~= false and expire and plate == targetPlate then
			showOp = true
		end
	end
	if showOp then
		ov.icon:Show()
		showAnything = true
	else
		ov.icon:Hide()
	end

	if showAnything then
		ov:Show()
	else
		ov:Hide()
	end
	return true
end

local function UpdateAllPlates()
	if not PlatesReady() then
		return
	end
	local db = DB()
	if not db or (not db.platesThreat and not db.platesOverpower) then
		for _, ov in pairs(overlays) do
			HideOverlay(ov)
		end
		return
	end

	local seen = {}
	local tokens = CollectMobTokens()
	for i = 1, #tokens do
		local token = tokens[i]
		if not IsGroupUnitToken(token) then
			local plate = SafeGetNamePlate(token)
			if PlateOk(plate) and not seen[plate] then
				seen[plate] = true
				UpdatePlateByToken(token, plate)
			end
		end
	end

	local plates = C_NamePlate.GetNamePlates()
	if plates then
		for i = 1, #plates do
			local plate = plates[i]
			if PlateOk(plate) and not seen[plate] then
				local unit = PlateUnitToken(plate)
				if unit then
					for t = 1, #tokens do
						local token = tokens[t]
						if IsGroupUnitToken(token) and UnitsAreSame(unit, token) then
							seen[plate] = true
							UpdatePlateByToken(token, plate)
							break
						end
					end
				end
			end
		end
	end

	for plate, ov in pairs(overlays) do
		if not seen[plate] then
			HideOverlay(ov)
		end
	end
end

local function MarkOverpowerOnTarget()
	if not PlatesReady() then
		return
	end
	local db = DB()
	if not db or not db.platesOverpower then
		return
	end
	if not PlayerKnowsOverpower() then
		return
	end
	local plate = SafeGetNamePlate("target")
	if PlateOk(plate) then
		opUntilPlate[plate] = GetTime() + OVERPOWER_WINDOW
		UpdateAllPlates()
	end
end

local function ClearOverpower()
	wipe(opUntilPlate)
	UpdateAllPlates()
end

local function HandleCLEU()
	if not CombatLogGetCurrentEventInfo then
		return
	end
	local _, subevent, _, sourceGUID, _, sourceFlags, _, _, _, _, _, a12, _, _, a15 = CombatLogGetCurrentEventInfo()
	local mine = false
	if not IsSecret(sourceFlags) and sourceFlags then
		local mineBit = COMBATLOG_OBJECT_AFFILIATION_MINE or 0x00000001
		local band = bit and bit.band
		if band and band(sourceFlags, mineBit) ~= 0 then
			mine = true
		end
	end
	if not mine and not IsSecret(sourceGUID) then
		local pg = UnitGUID("player")
		if not IsSecret(pg) and sourceGUID == pg then
			mine = true
		end
	end

	if subevent == "SWING_MISSED" then
		local miss = a12
		if not IsSecret(miss) and miss == "DODGE" and (mine or OverpowerProcActive() == true) then
			MarkOverpowerOnTarget()
		end
	elseif subevent == "SPELL_MISSED" then
		local miss = a15
		if not IsSecret(miss) and miss == "DODGE" and (mine or OverpowerProcActive() == true) then
			MarkOverpowerOnTarget()
		end
	elseif mine and subevent == "SPELL_CAST_SUCCESS" and not IsSecret(a12) then
		if OVERPOWER_IDS[a12] or REVENGE_SPELLS[a12] then
			ClearOverpower()
		end
	end
end

-- Forever forbids COMBAT_LOG_EVENT_UNFILTERED from this addon (ADDON_ACTION_FORBIDDEN).
-- Overpower is detected from SPELL_UPDATE_USABLE / action-bar usable instead.

local function StartTicker()
	if ticker then
		return
	end
	ticker = C_Timer.NewTicker(0.2, UpdateAllPlates)
end

local function StopTicker()
	if ticker then
		ticker:Cancel()
		ticker = nil
	end
end

local function SafeRegister(frame, event)
	pcall(frame.RegisterEvent, frame, event)
end

function Plates.Enable()
	if not PlatesReady() then
		return
	end
	if not events then
		events = CreateFrame("Frame")
		events:SetScript("OnEvent", function(_, event, arg1, _, spellId)
			if event == "PLAYER_TARGET_CHANGED" then
				local keep = SafeGetNamePlate("target")
				for plate in pairs(opUntilPlate) do
					if plate ~= keep then
						opUntilPlate[plate] = nil
					end
				end
				UpdateAllPlates()
			elseif event == "PLAYER_REGEN_ENABLED" then
				wipe(opUntilPlate)
				UpdateAllPlates()
			elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
				if arg1 == "player" and spellId and not IsSecret(spellId) then
					if REVENGE_SPELLS[spellId] or OVERPOWER_IDS[spellId] then
						ClearOverpower()
						return
					end
				end
				UpdateAllPlates()
			elseif event == "SPELL_UPDATE_USABLE" or event == "ACTIONBAR_UPDATE_USABLE" or event == "ACTIONBAR_UPDATE_STATE" then
				local proc = OverpowerProcActive()
				if proc == true then
					MarkOverpowerOnTarget()
				elseif proc == false then
					ClearOverpower()
				else
					UpdateAllPlates()
				end
			elseif event == "NAME_PLATE_UNIT_ADDED" or event == "NAME_PLATE_UNIT_REMOVED" or event == "PLAYER_FOCUS_CHANGED" or event == "UPDATE_MOUSEOVER_UNIT" or event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_ENTERING_WORLD" then
				UpdateAllPlates()
			end
		end)
		SafeRegister(events, "NAME_PLATE_UNIT_ADDED")
		SafeRegister(events, "NAME_PLATE_UNIT_REMOVED")
		SafeRegister(events, "PLAYER_TARGET_CHANGED")
		SafeRegister(events, "PLAYER_FOCUS_CHANGED")
		SafeRegister(events, "UPDATE_MOUSEOVER_UNIT")
		SafeRegister(events, "PLAYER_REGEN_ENABLED")
		SafeRegister(events, "PLAYER_REGEN_DISABLED")
		SafeRegister(events, "PLAYER_ENTERING_WORLD")
		SafeRegister(events, "UNIT_SPELLCAST_SUCCEEDED")
		SafeRegister(events, "SPELL_UPDATE_USABLE")
		SafeRegister(events, "ACTIONBAR_UPDATE_USABLE")
		SafeRegister(events, "ACTIONBAR_UPDATE_STATE")
	end

	local db = DB()
	if db and (db.platesThreat or db.platesOverpower) then
		StartTicker()
		UpdateAllPlates()
	else
		StopTicker()
		for _, ov in pairs(overlays) do
			HideOverlay(ov)
		end
	end
end

function Plates.Refresh()
	UpdateAllPlates()
end

function Plates.OnLogin()
	Plates.Enable()
end
