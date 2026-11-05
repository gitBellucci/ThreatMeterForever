--[[
  Options window styled after EllesmereUI:
  dark panel, teal accent, faint 1px borders, relative layout.
]]

local TT = _G.DetailsTinyThreat
if not TT then
	return
end

local UIFont = "Fonts\\ARIALN.TTF"

local function Accent()
	if EllesmereUI then
		if EllesmereUI.GetAccentColor then
			local r, g, b = EllesmereUI.GetAccentColor()
			if r then
				return r, g, b
			end
		end
		if EllesmereUI.DEFAULT_ACCENT_R then
			return EllesmereUI.DEFAULT_ACCENT_R, EllesmereUI.DEFAULT_ACCENT_G, EllesmereUI.DEFAULT_ACCENT_B
		end
	end
	return 12 / 255, 210 / 255, 157 / 255
end

local function Fill(frame, r, g, b, a)
	local tex = frame:CreateTexture(nil, "BACKGROUND")
	tex:SetAllPoints()
	tex:SetColorTexture(r, g, b, a or 1)
	return tex
end

local function Border(frame, r, g, b, a)
	local texs = {}
	local function edge(p1, rp1, p2, rp2, w, h)
		local t = frame:CreateTexture(nil, "BORDER")
		t:SetColorTexture(r, g, b, a or 1)
		t:SetPoint(p1, frame, rp1)
		t:SetPoint(p2, frame, rp2)
		if w then
			t:SetWidth(w)
		end
		if h then
			t:SetHeight(h)
		end
		texs[#texs + 1] = t
		return t
	end
	edge("TOPLEFT", "TOPLEFT", "TOPRIGHT", "TOPRIGHT", nil, 1)
	edge("BOTTOMLEFT", "BOTTOMLEFT", "BOTTOMRIGHT", "BOTTOMRIGHT", nil, 1)
	edge("TOPLEFT", "TOPLEFT", "BOTTOMLEFT", "BOTTOMLEFT", 1, nil)
	edge("TOPRIGHT", "TOPRIGHT", "BOTTOMRIGHT", "BOTTOMRIGHT", 1, nil)
	return {
		SetColor = function(_, cr, cg, cb, ca)
			for i = 1, #texs do
				texs[i]:SetColorTexture(cr, cg, cb, ca or 1)
			end
		end,
	}
end

local function Font(parent, size, r, g, b, a)
	local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	pcall(fs.SetFont, fs, UIFont, size or 13, "")
	fs:SetTextColor(r or 1, g or 1, b or 1, a or 1)
	return fs
end

local function Tooltip(frame, title, body)
	frame:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(title, 1, 1, 1)
		if body then
			GameTooltip:AddLine(body, 0.85, 0.85, 0.85, true)
		end
		GameTooltip:Show()
	end)
	frame:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
end

local function Notify(key)
	if TT.OnOptionChanged then
		TT.OnOptionChanged(key)
	end
end

local function DB()
	return TT.db
end

local optionsFrame
local openMenu

local function HideMenu()
	if openMenu then
		openMenu:Hide()
	end
end

local function MakeCard(parent)
	local card = CreateFrame("Frame", nil, parent)
	Fill(card, 0.06, 0.08, 0.10, 1)
	Border(card, 1, 1, 1, 0.06)
	local ar, ag, ab = Accent()
	local accent = card:CreateTexture(nil, "ARTWORK")
	accent:SetPoint("TOPLEFT", 1, -1)
	accent:SetPoint("TOPRIGHT", -1, -1)
	accent:SetHeight(2)
	accent:SetColorTexture(ar, ag, ab, 0.7)
	return card
end

local function MakeSectionLabel(parent, text)
	local fs = Font(parent, 11, 1, 1, 1, 0.41)
	fs:SetText(string.upper(text))
	return fs
end

local function MakeCheck(parent, label, key, tooltip, inverted)
	local db = DB()
	local row = CreateFrame("Button", nil, parent)
	row:SetHeight(24)
	local box = CreateFrame("Frame", nil, row)
	box:SetSize(14, 14)
	box:SetPoint("LEFT", row, "LEFT", 0, 0)
	Fill(box, 0.075, 0.113, 0.141, 1)
	local brd = Border(box, 1, 1, 1, 0.25)
	local ar, ag, ab = Accent()
	local check = box:CreateTexture(nil, "ARTWORK")
	check:SetPoint("TOPLEFT", 3, -3)
	check:SetPoint("BOTTOMRIGHT", -3, 3)
	check:SetColorTexture(ar, ag, ab, 1)
	local lbl = Font(row, 13, 1, 1, 1, 0.86)
	lbl:SetPoint("LEFT", box, "RIGHT", 8, 0)
	lbl:SetText(label)
	row:SetWidth(14 + 8 + (lbl:GetStringWidth() or 120) + 8)

	local function Paint()
		local on = db[key] and true or false
		if inverted then
			on = not on
		end
		check:SetShown(on)
		if on then
			brd:SetColor(ar, ag, ab, 0.85)
		else
			brd:SetColor(1, 1, 1, 0.25)
		end
	end
	Paint()
	row:SetScript("OnClick", function()
		db[key] = not (db[key] and true or false)
		Paint()
		Notify(key)
	end)
	Tooltip(row, (label ~= "" and label) or "Toggle", tooltip)
	row.Paint = Paint
	return row
end

local function MakeSplitCheck(parent, label, key, tooltip, inverted)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetHeight(40)
	holder:SetPoint("LEFT", parent, "LEFT", 30, 0)
	holder:SetPoint("RIGHT", parent, "RIGHT", -15, 0)
	local lbl = Font(holder, 13, 1, 1, 1, 0.9)
	lbl:SetPoint("LEFT", 20, 0)
	lbl:SetPoint("RIGHT", holder, "CENTER", -30, 0)
	lbl:SetJustifyH("RIGHT")
	lbl:SetText(label)
	local box = MakeCheck(holder, "", key, tooltip, inverted)
	box:SetPoint("LEFT", holder, "CENTER", -15, 0)
	holder.Paint = function()
		if box.Paint then
			box:Paint()
		end
	end
	holder.box = box
	return holder
end

local function MakeButton(parent, label, width)
	local ar, ag, ab = Accent()
	local btn = CreateFrame("Button", nil, parent)
	btn:SetSize(width or 120, 26)
	local bg = Fill(btn, 0.10, 0.12, 0.14, 1)
	local brd = Border(btn, ar, ag, ab, 0.35)
	local fs = Font(btn, 12, 1, 1, 1, 0.9)
	fs:SetPoint("CENTER")
	fs:SetText(label)
	btn.label = fs
	btn:SetScript("OnEnter", function()
		bg:SetColorTexture(0.14, 0.16, 0.18, 1)
		brd:SetColor(ar, ag, ab, 0.9)
		fs:SetTextColor(ar, ag, ab, 1)
	end)
	btn:SetScript("OnLeave", function()
		bg:SetColorTexture(0.10, 0.12, 0.14, 1)
		brd:SetColor(ar, ag, ab, 0.35)
		fs:SetTextColor(1, 1, 1, 0.9)
	end)
	btn.SetLabel = function(_, text)
		fs:SetText(text)
	end
	return btn
end

local function MakeDropdown(parent, width, items, getValue, setValue)
	local ar, ag, ab = Accent()
	local btn = CreateFrame("Button", nil, parent)
	btn:SetSize(width, 26)
	local bg = Fill(btn, 0.07, 0.09, 0.11, 1)
	local brd = Border(btn, 1, 1, 1, 0.10)
	local lbl = Font(btn, 13, 1, 1, 1, 0.86)
	lbl:SetPoint("LEFT", 12, 0)
	lbl:SetPoint("RIGHT", -22, 0)
	lbl:SetJustifyH("LEFT")
	lbl:SetWordWrap(false)
	local arrow = Font(btn, 10, 1, 1, 1, 0.45)
	arrow:SetPoint("RIGHT", -8, 0)
	arrow:SetText("▼")

	local function CurrentLabel()
		local value = getValue()
		for i = 1, #items do
			if items[i][2] == value then
				return items[i][1]
			end
		end
		return items[1][1]
	end
	lbl:SetText(CurrentLabel())

	local menu = CreateFrame("Frame", nil, UIParent)
	menu:SetFrameStrata("FULLSCREEN_DIALOG")
	menu:SetToplevel(true)
	menu:SetClampedToScreen(true)
	menu:SetSize(width, 8 + #items * 24)
	Fill(menu, 0.06, 0.08, 0.10, 0.98)
	Border(menu, 1, 1, 1, 0.12)
	menu:Hide()
	menu:EnableMouse(true)

	for i, info in ipairs(items) do
		local item = CreateFrame("Button", nil, menu)
		item:SetHeight(24)
		item:SetPoint("TOPLEFT", 1, -4 - (i - 1) * 24)
		item:SetPoint("TOPRIGHT", -1, -4 - (i - 1) * 24)
		local hl = item:CreateTexture(nil, "ARTWORK")
		hl:SetAllPoints()
		hl:SetColorTexture(1, 1, 1, 0)
		local ifs = Font(item, 13, 1, 1, 1, 0.53)
		ifs:SetPoint("LEFT", 10, 0)
		pcall(ifs.SetFont, ifs, info[2], 13, "")
		ifs:SetText(info[1])
		item:SetScript("OnEnter", function()
			hl:SetColorTexture(1, 1, 1, 0.06)
			ifs:SetTextColor(1, 1, 1, 1)
		end)
		item:SetScript("OnLeave", function()
			hl:SetColorTexture(1, 1, 1, 0)
			ifs:SetTextColor(1, 1, 1, 0.53)
		end)
		item:SetScript("OnClick", function()
			setValue(info[2])
			lbl:SetText(info[1])
			menu:Hide()
		end)
	end

	menu:SetScript("OnUpdate", function(self)
		if not self:IsShown() then
			return
		end
		if IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton") then
			if not self:IsMouseOver() and not btn:IsMouseOver() then
				self:Hide()
			end
		end
	end)

	btn:SetScript("OnEnter", function()
		brd:SetColor(ar, ag, ab, 0.7)
		lbl:SetTextColor(1, 1, 1, 1)
	end)
	btn:SetScript("OnLeave", function()
		brd:SetColor(1, 1, 1, 0.10)
		lbl:SetTextColor(1, 1, 1, 0.86)
	end)
	btn:SetScript("OnClick", function()
		if menu:IsShown() then
			menu:Hide()
			if openMenu == menu then
				openMenu = nil
			end
			return
		end
		HideMenu()
		menu:ClearAllPoints()
		menu:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
		menu:Show()
		openMenu = menu
	end)

	btn.menu = menu
	btn.Refresh = function()
		lbl:SetText(CurrentLabel())
	end
	return btn
end

local function MakeLabeledRow(parent, label)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(40)
	row:SetPoint("LEFT", parent, "LEFT", 30, 0)
	row:SetPoint("RIGHT", parent, "RIGHT", -30, 0)
	local fs = Font(row, 13, 1, 1, 1, 0.9)
	fs:SetPoint("LEFT", 20, 0)
	fs:SetPoint("RIGHT", row, "CENTER", -50, 0)
	fs:SetJustifyH("RIGHT")
	fs:SetText(label)
	row.label = fs
	return row
end

local function CreateOptions()
	if optionsFrame then
		return optionsFrame
	end

	local db = DB()
	local ar, ag, ab = Accent()

	local f = CreateFrame("Frame", "DetailsTinyThreatOptions", UIParent)
	f:Hide()
	f:SetSize(560, 680)
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:SetToplevel(true)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	Fill(f, 0.05, 0.07, 0.09, 0.97)
	Border(f, ar, ag, ab, 0.45)
	tinsert(UISpecialFrames, "DetailsTinyThreatOptions")
	optionsFrame = f
	TT.optionsFrame = f

	local header = CreateFrame("Frame", nil, f)
	header:SetPoint("TOPLEFT", 1, -1)
	header:SetPoint("TOPRIGHT", -1, -1)
	header:SetHeight(58)
	Fill(header, 0.055, 0.07, 0.09, 1)
	header:EnableMouse(true)
	header:RegisterForDrag("LeftButton")
	header:SetScript("OnDragStart", function()
		f:StartMoving()
	end)
	header:SetScript("OnDragStop", function()
		f:StopMovingOrSizing()
	end)
	local accentLine = header:CreateTexture(nil, "ARTWORK")
	accentLine:SetPoint("BOTTOMLEFT")
	accentLine:SetPoint("BOTTOMRIGHT")
	accentLine:SetHeight(2)
	accentLine:SetColorTexture(ar, ag, ab, 1)

	local title = Font(header, 18, ar, ag, ab, 1)
	title:SetPoint("TOPLEFT", 18, -12)
	title:SetText("Tiny Threat")

	local sub = Font(header, 12, 1, 1, 1, 0.45)
	sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
	sub:SetText("Click widgets on the plate to move and configure them")

	local close = CreateFrame("Button", nil, header)
	close:SetSize(22, 22)
	close:SetPoint("TOPRIGHT", -12, -14)
	local closeFs = Font(close, 18, 1, 1, 1, 0.45)
	closeFs:SetPoint("CENTER", 0, 1)
	closeFs:SetText("×")
	close:SetScript("OnEnter", function()
		closeFs:SetTextColor(ar, ag, ab, 1)
	end)
	close:SetScript("OnLeave", function()
		closeFs:SetTextColor(1, 1, 1, 0.45)
	end)
	close:SetScript("OnClick", function()
		HideMenu()
		f:Hide()
	end)

	local tabBar = CreateFrame("Frame", nil, f)
	tabBar:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 16, -10)
	tabBar:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", -16, -10)
	tabBar:SetHeight(26)

	local scroll = CreateFrame("ScrollFrame", "DetailsTinyThreatOptionsScroll", f)
	scroll:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, -10)
	scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 16)
	scroll:EnableMouse(true)
	scroll:EnableMouseWheel(true)

	local body = CreateFrame("Frame", nil, scroll)
	body:SetPoint("TOPLEFT")
	scroll:SetScrollChild(body)

	local general, plates
	local function LayoutScroll()
		local width = scroll:GetWidth()
		if not width or width < 100 then
			width = 528
		end
		body:SetWidth(width)
		local height = 1
		if plates and plates:IsShown() then
			height = plates:GetHeight() or 1
		elseif general and general:IsShown() then
			height = general:GetHeight() or 1
		end
		body:SetHeight(height)
		local view = scroll:GetHeight() or 0
		local maxScroll = math.max(0, height - view)
		if scroll:GetVerticalScroll() > maxScroll then
			scroll:SetVerticalScroll(maxScroll)
		end
	end

	scroll:SetScript("OnSizeChanged", function()
		LayoutScroll()
	end)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local maxScroll = math.max(0, (body:GetHeight() or 0) - (self:GetHeight() or 0))
		local new = self:GetVerticalScroll() - delta * 48
		if new < 0 then
			new = 0
		elseif new > maxScroll then
			new = maxScroll
		end
		self:SetVerticalScroll(new)
	end)

	general = MakeCard(body)
	general:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
	general:SetPoint("TOPRIGHT", body, "TOPRIGHT", 0, 0)

	local gLabel = MakeSectionLabel(general, "Meter")
	gLabel:SetPoint("TOPLEFT", general, "TOPLEFT", 14, -14)

	local generalOpts = {
		{ "Enable addon", "enabled", "Master toggle for the threat window." },
		{ "Lock window", "locked", "Prevent moving and resizing." },
		{ "Hide out of combat", "hideOutOfCombat", "Hide the whole window when you leave combat." },
		{ "Hide when solo", "hideWhenSolo", "Hide the window when you are not in a group." },
		{ "Use class colors", "useclasscolors", "Color bars with the player's class color." },
		{ "Highlight my bar", "useplayercolor", "Paint your own bar with a custom color." },
		{ "Track focus if available", "usefocus", "Use focus target when one exists, otherwise target." },
		{ "Show pull aggro bar", "hide_pull_bar", "In absolute mode, draw 110% melee and 130% ranged pull lines.", true },
		{ "Display absolute threat", "absolute_mode", "Off: aggro switches at 100%.\nOn: melee pull at 110%, ranged at 130%." },
		{ "Show pets in party", "show_party_pets", "Include party pets on the meter." },
		{ "Show only my raid group", "only_my_group", "In a raid, only list your subgroup." },
	}

	local leftCol = CreateFrame("Frame", nil, general)
	leftCol:SetPoint("TOPLEFT", gLabel, "BOTTOMLEFT", 0, -12)
	leftCol:SetWidth(250)
	local rightCol = CreateFrame("Frame", nil, general)
	rightCol:SetPoint("TOPLEFT", leftCol, "TOPRIGHT", 18, 0)
	rightCol:SetPoint("RIGHT", general, "RIGHT", -14, 0)

	local leftLast, rightLast
	local leftCount, rightCount = 0, 0
	for i, info in ipairs(generalOpts) do
		local parentCol = (i % 2 == 1) and leftCol or rightCol
		local prev = (i % 2 == 1) and leftLast or rightLast
		local row = MakeCheck(parentCol, info[1], info[2], info[3], info[4])
		if prev then
			row:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -4)
		else
			row:SetPoint("TOPLEFT", parentCol, "TOPLEFT", 0, 0)
		end
		row:SetPoint("RIGHT", parentCol, "RIGHT", 0, 0)
		if i % 2 == 1 then
			leftLast = row
			leftCount = leftCount + 1
		else
			rightLast = row
			rightCount = rightCount + 1
		end
	end
	local rows = math.max(leftCount, rightCount)
	leftCol:SetHeight(rows * 28)
	rightCol:SetHeight(rows * 28)
	general:SetHeight(14 + 14 + 12 + rows * 28 + 16)

	plates = CreateFrame("Frame", nil, body)
	plates:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
	plates:SetPoint("TOPRIGHT", body, "TOPRIGHT", 0, 0)

	local plateThreat = MakeSplitCheck(plates, "Threat numbers on nameplates", "platesThreat", "Show signed threat difference vs the highest other player on enemy plates.")
	plateThreat:SetPoint("TOP", plates, "TOP", 0, -4)

	local plateOp = MakeSplitCheck(plates, "Overpower icon on nameplates", "platesOverpower", "Show the Overpower icon on your current target while Overpower is actually usable (dodge proc). Warrior only.")
	plateOp:SetPoint("TOPLEFT", plateThreat, "BOTTOMLEFT", 0, 0)
	plateOp:SetPoint("TOPRIGHT", plateThreat, "BOTTOMRIGHT", 0, 0)

	local RefreshPreview
	local selectedWidget
	local db = DB()
	local ar, ag, ab = Accent()
	local selR, selG, selB = 78 / 255, 165 / 255, 252 / 255

	local previewInset
	local insetOk = pcall(function()
		previewInset = CreateFrame("Frame", nil, plates, "InsetFrameTemplate")
	end)
	if not insetOk or not previewInset then
		previewInset = CreateFrame("Frame", nil, plates)
		Fill(previewInset, 0.10, 0.10, 0.10, 1)
		Border(previewInset, 0, 0, 0, 0.55)
	end
	previewInset:SetPoint("TOP", plateOp, "BOTTOM", 0, -15)
	previewInset:SetPoint("LEFT", plates, "LEFT", 20, 0)
	previewInset:SetPoint("RIGHT", plates, "RIGHT", -20, 0)
	previewInset:SetHeight(235)
	previewInset:EnableMouse(true)
	if previewInset.SetClipsChildren then
		previewInset:SetClipsChildren(true)
	end

	local preview = CreateFrame("Frame", nil, previewInset)
	preview:SetAllPoints()
	preview:EnableMouse(true)

	-- Nameplate-sized mock in the middle of the well, with room to drag widgets.
	local mock = CreateFrame("Frame", nil, preview)
	mock:SetSize(150, 14)
	mock:SetPoint("CENTER", preview, "CENTER", 0, 6)
	mock:EnableMouse(false)

	local mockName = Font(preview, 11, 1, 1, 1, 1)
	mockName:SetWidth(180)
	mockName:SetWordWrap(false)
	mockName:SetJustifyH("CENTER")
	mockName:SetPoint("BOTTOM", mock, "TOP", 0, 4)
	mockName:SetText("Scarlet Warrior")

	Fill(mock, 0.08, 0.02, 0.02, 1)
	Border(mock, 0, 0, 0, 1)
	local hp = mock:CreateTexture(nil, "ARTWORK")
	hp:SetPoint("TOPLEFT", 1, -1)
	hp:SetPoint("BOTTOMLEFT", 1, 1)
	hp:SetWidth(104)
	hp:SetColorTexture(0.78, 0.13, 0.13, 1)
	local hpText = Font(mock, 10, 1, 1, 1, 1)
	hpText:SetPoint("CENTER", mock, "CENTER", 0, 0)
	hpText:SetText("71K")

	local cast = CreateFrame("Frame", nil, preview)
	cast:SetSize(150, 10)
	cast:SetPoint("TOP", mock, "BOTTOM", 0, -3)
	Fill(cast, 0.10, 0.09, 0.02, 1)
	Border(cast, 0, 0, 0, 0.9)
	local castFill = cast:CreateTexture(nil, "ARTWORK")
	castFill:SetPoint("TOPLEFT", 1, -1)
	castFill:SetPoint("BOTTOMLEFT", 1, 1)
	castFill:SetWidth(86)
	castFill:SetColorTexture(0.90, 0.75, 0.12, 1)
	local castIcon = preview:CreateTexture(nil, "OVERLAY")
	castIcon:SetSize(10, 10)
	castIcon:SetPoint("RIGHT", cast, "LEFT", -2, 0)
	castIcon:SetTexture("Interface\\Icons\\Spell_Nature_StarFall")
	castIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	local castText = Font(cast, 9, 1, 0.86, 0.2, 1)
	castText:SetPoint("LEFT", 4, 0)
	castText:SetText("Arcane Flurry")

	local function MakeOutline()
		local holder = CreateFrame("Frame", nil, previewInset)
		holder:SetFrameLevel((preview:GetFrameLevel() or 1) + 10)
		local tex = holder:CreateTexture(nil, "OVERLAY")
		tex:SetAllPoints()
		local sliced = false
		pcall(function()
			tex:SetTexture("Interface\\AddOns\\ThreatMeterForever\\Assets\\selection-outline.png")
			if tex.SetTextureSliceMargins then
				tex:SetTextureSliceMargins(45, 45, 45, 45)
				if Enum and Enum.UITextureSliceMode then
					tex:SetTextureSliceMode(Enum.UITextureSliceMode.Tiled)
				end
			end
			if tex.SetScale then
				tex:SetScale(0.25)
			end
			tex:SetVertexColor(selR, selG, selB, 0.8)
			sliced = true
		end)
		local edges
		if not sliced then
			tex:SetColorTexture(0, 0, 0, 0)
			edges = Border(holder, selR, selG, selB, 0.9)
		end
		holder.SetShownColor = function(_, shown, hover)
			holder:SetShown(shown and true or false)
			local a = hover and 0.45 or 0.8
			if sliced then
				tex:SetVertexColor(selR, selG, selB, a)
			elseif edges then
				edges:SetColor(selR, selG, selB, a)
			end
		end
		holder.Attach = function(_, widget)
			holder:ClearAllPoints()
			holder:SetPoint("TOPLEFT", widget, "TOPLEFT", -2, 2)
			holder:SetPoint("BOTTOMRIGHT", widget, "BOTTOMRIGHT", 2, -2)
		end
		holder:Hide()
		return holder
	end

	local threatDrag = CreateFrame("Button", nil, preview)
	threatDrag:SetSize(40, 16)
	threatDrag:SetFrameLevel(preview:GetFrameLevel() + 6)
	local threatSample = threatDrag:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	threatSample:SetPoint("CENTER")
	pcall(threatSample.SetFont, threatSample, db.platesThreatFont or "Fonts\\FRIZQT__.TTF", db.platesThreatFontSize or 12, db.platesThreatOutline or "OUTLINE")
	threatSample:SetText("+2.4K")
	threatSample:SetTextColor(0.25, 1, 0.25, 1)
	local threatOutline = MakeOutline()

	local opDrag = CreateFrame("Button", nil, preview)
	opDrag:SetSize(22, 22)
	opDrag:SetFrameLevel(preview:GetFrameLevel() + 6)
	local opSample = opDrag:CreateTexture(nil, "ARTWORK")
	opSample:SetAllPoints()
	opSample:SetTexture("Interface\\Icons\\Ability_MeleeDamage")
	opSample:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	local opOutline = MakeOutline()

	local hint = plates:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	pcall(hint.SetFont, hint, UIFont, 15, "")
	hint:SetTextColor(1, 1, 1, 0.85)
	hint:SetPoint("TOP", previewInset, "BOTTOM", 0, -15)
	hint:SetText("Click on a widget for settings")

	local widgetTitle = plates:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	pcall(widgetTitle.SetFont, widgetTitle, UIFont, 15, "")
	widgetTitle:SetTextColor(1, 1, 1, 0.95)
	widgetTitle:SetPoint("TOP", previewInset, "BOTTOM", 0, -15)
	widgetTitle:SetPoint("RIGHT", plates, "RIGHT", -40, 0)
	widgetTitle:SetJustifyH("RIGHT")
	widgetTitle:Hide()

	local settings = CreateFrame("Frame", nil, plates)
	settings:SetPoint("TOP", previewInset, "BOTTOM", 0, -45)
	settings:SetPoint("LEFT", plates, "LEFT", 0, 0)
	settings:SetPoint("RIGHT", plates, "RIGHT", 0, 0)
	settings:SetHeight(120)
	settings:Hide()

	local plateFonts = {
		{ "Friz Quadrata", "Fonts\\FRIZQT__.TTF" },
		{ "Arial Narrow", "Fonts\\ARIALN.TTF" },
		{ "Morpheus", "Fonts\\MORPHEUS.TTF" },
		{ "Skurri", "Fonts\\SKURRI.TTF" },
	}

	local threatSettings = CreateFrame("Frame", nil, settings)
	threatSettings:SetAllPoints()

	local fontRow = MakeLabeledRow(threatSettings, "Font")
	fontRow:SetPoint("TOP", settings, "TOP", 0, 0)
	local fontDrop = MakeDropdown(fontRow, 200, plateFonts, function()
		return db.platesThreatFont
	end, function(path)
		db.platesThreatFont = path
		if RefreshPreview then
			RefreshPreview()
		end
		if TT.Plates and TT.Plates.Refresh then
			TT.Plates.Refresh()
		end
	end)
	fontDrop:SetPoint("LEFT", fontRow, "CENTER", -32, 0)

	local sizeRow = MakeLabeledRow(threatSettings, "Size")
	sizeRow:SetPoint("TOP", fontRow, "BOTTOM", 0, 0)
	local minus = MakeButton(sizeRow, "−", 28)
	minus:SetPoint("LEFT", sizeRow, "CENTER", -32, 0)
	local sizeText = Font(sizeRow, 13, 1, 1, 1, 0.95)
	sizeText:SetPoint("LEFT", minus, "RIGHT", 10, 0)
	sizeText:SetWidth(28)
	sizeText:SetJustifyH("CENTER")
	sizeText:SetText(tostring(db.platesThreatFontSize or 12))
	local plus = MakeButton(sizeRow, "+", 28)
	plus:SetPoint("LEFT", sizeText, "RIGHT", 10, 0)

	local lockRow = MakeLabeledRow(threatSettings, "Locked")
	lockRow:SetPoint("TOP", sizeRow, "BOTTOM", 0, 0)
	local lockThreat = MakeCheck(lockRow, "", "platesThreatLocked", "Prevent dragging the threat number.")
	lockThreat:SetPoint("LEFT", lockRow, "CENTER", -32, 0)

	local opSettings = CreateFrame("Frame", nil, settings)
	opSettings:SetAllPoints()
	opSettings:Hide()
	local opSizeRow = MakeLabeledRow(opSettings, "Size")
	opSizeRow:SetPoint("TOP", settings, "TOP", 0, 0)
	local opMinus = MakeButton(opSizeRow, "−", 28)
	opMinus:SetPoint("LEFT", opSizeRow, "CENTER", -32, 0)
	local opSizeText = Font(opSizeRow, 13, 1, 1, 1, 0.95)
	opSizeText:SetPoint("LEFT", opMinus, "RIGHT", 10, 0)
	opSizeText:SetWidth(28)
	opSizeText:SetJustifyH("CENTER")
	opSizeText:SetText(tostring(db.platesOverpowerSize or 22))
	local opPlus = MakeButton(opSizeRow, "+", 28)
	opPlus:SetPoint("LEFT", opSizeText, "RIGHT", 10, 0)
	local opLockRow = MakeLabeledRow(opSettings, "Locked")
	opLockRow:SetPoint("TOP", opSizeRow, "BOTTOM", 0, 0)
	local lockOp = MakeCheck(opLockRow, "", "platesOverpowerLocked", "Prevent dragging the Overpower icon.")
	lockOp:SetPoint("LEFT", opLockRow, "CENTER", -32, 0)

	local function SyncLocks()
		if lockThreat.Paint then
			lockThreat:Paint()
		end
		if lockOp.Paint then
			lockOp:Paint()
		end
	end

	local function SelectWidget(kind)
		selectedWidget = kind
		if kind == "threat" then
			threatOutline:Attach(threatDrag)
			threatOutline:SetShownColor(true, false)
			opOutline:SetShownColor(false, false)
			settings:Show()
			threatSettings:Show()
			opSettings:Hide()
			hint:Hide()
			widgetTitle:SetText("Threat number")
			widgetTitle:Show()
		elseif kind == "overpower" then
			opOutline:Attach(opDrag)
			opOutline:SetShownColor(true, false)
			threatOutline:SetShownColor(false, false)
			settings:Show()
			opSettings:Show()
			threatSettings:Hide()
			hint:Hide()
			widgetTitle:SetText("Overpower")
			widgetTitle:Show()
		else
			threatOutline:SetShownColor(false, false)
			opOutline:SetShownColor(false, false)
			settings:Hide()
			hint:Show()
			widgetTitle:Hide()
		end
	end

	local function bumpSize(delta)
		local v = (db.platesThreatFontSize or 12) + delta
		if v < 8 then v = 8 end
		if v > 28 then v = 28 end
		db.platesThreatFontSize = v
		sizeText:SetText(tostring(v))
		if RefreshPreview then
			RefreshPreview()
		end
		if TT.Plates and TT.Plates.Refresh then
			TT.Plates.Refresh()
		end
	end
	minus:SetScript("OnClick", function() bumpSize(-1) end)
	plus:SetScript("OnClick", function() bumpSize(1) end)

	local function bumpOpSize(delta)
		local v = (db.platesOverpowerSize or 22) + delta
		if v < 12 then v = 12 end
		if v > 40 then v = 40 end
		db.platesOverpowerSize = v
		opSizeText:SetText(tostring(v))
		if RefreshPreview then
			RefreshPreview()
		end
		if TT.Plates and TT.Plates.Refresh then
			TT.Plates.Refresh()
		end
	end
	opMinus:SetScript("OnClick", function() bumpOpSize(-1) end)
	opPlus:SetScript("OnClick", function() bumpOpSize(1) end)
	SyncLocks()

	local function OffsetFromMock(frame)
		local mx, my = mock:GetCenter()
		local fx, fy = frame:GetCenter()
		if not mx or not fx then
			return 0, 0
		end
		return math.floor(fx - mx + 0.5), math.floor(fy - my + 0.5)
	end

	local function ClampOffset(dx, dy)
		dx = math.floor((dx or 0) + 0.5)
		dy = math.floor((dy or 0) + 0.5)
		if dx > 170 then dx = 170 end
		if dx < -170 then dx = -170 end
		if dy > 95 then dy = 95 end
		if dy < -95 then dy = -95 end
		return dx, dy
	end

	local function MakeDraggable(frame, kind, lockedKey, xKey, yKey, outline)
		frame:EnableMouse(true)
		frame:RegisterForDrag("LeftButton")
		frame:SetScript("OnEnter", function()
			if selectedWidget ~= kind then
				outline:Attach(frame)
				outline:SetShownColor(true, true)
			end
		end)
		frame:SetScript("OnLeave", function()
			if selectedWidget ~= kind then
				outline:SetShownColor(false, false)
			end
		end)
		frame:SetScript("OnMouseDown", function()
			SelectWidget(kind)
			HideMenu()
		end)
		frame:SetScript("OnDragStart", function(self)
			SelectWidget(kind)
			if db[lockedKey] then
				return
			end
			HideMenu()
			self.dragging = true
		end)
		frame:SetScript("OnDragStop", function(self)
			self.dragging = false
			local dx, dy = ClampOffset(OffsetFromMock(self))
			db[xKey] = dx
			db[yKey] = dy
			self:ClearAllPoints()
			self:SetPoint("CENTER", mock, "CENTER", dx, dy)
			outline:Attach(self)
			if TT.Plates and TT.Plates.Refresh then
				TT.Plates.Refresh()
			end
			if RefreshPreview then
				RefreshPreview()
			end
		end)
		frame:SetScript("OnUpdate", function(self)
			if not self.dragging or db[lockedKey] then
				return
			end
			local scale = self:GetEffectiveScale() or 1
			local cx, cy = GetCursorPosition()
			cx, cy = cx / scale, cy / scale
			local mx, my = mock:GetCenter()
			if not mx then
				return
			end
			local dx, dy = ClampOffset(cx - mx, cy - my)
			db[xKey] = dx
			db[yKey] = dy
			self:ClearAllPoints()
			self:SetPoint("CENTER", mock, "CENTER", dx, dy)
			outline:Attach(self)
		end)
	end
	MakeDraggable(threatDrag, "threat", "platesThreatLocked", "platesThreatOffsetX", "platesThreatOffsetY", threatOutline)
	MakeDraggable(opDrag, "overpower", "platesOverpowerLocked", "platesOverpowerOffsetX", "platesOverpowerOffsetY", opOutline)

	local function Deselect()
		HideMenu()
		SelectWidget(nil)
	end
	preview:SetScript("OnMouseDown", Deselect)
	previewInset:SetScript("OnMouseDown", Deselect)

	RefreshPreview = function()
		local tx, ty = ClampOffset(db.platesThreatOffsetX or 90, db.platesThreatOffsetY or 0)
		local ox, oy = ClampOffset(db.platesOverpowerOffsetX or -90, db.platesOverpowerOffsetY or 0)
		db.platesThreatOffsetX, db.platesThreatOffsetY = tx, ty
		db.platesOverpowerOffsetX, db.platesOverpowerOffsetY = ox, oy
		if not threatDrag.dragging then
			threatDrag:ClearAllPoints()
			threatDrag:SetPoint("CENTER", mock, "CENTER", tx, ty)
		end
		if not opDrag.dragging then
			opDrag:ClearAllPoints()
			opDrag:SetPoint("CENTER", mock, "CENTER", ox, oy)
		end
		local opSize = db.platesOverpowerSize or 22
		opDrag:SetSize(opSize, opSize)
		pcall(threatSample.SetFont, threatSample, db.platesThreatFont or "Fonts\\FRIZQT__.TTF", db.platesThreatFontSize or 12, db.platesThreatOutline or "OUTLINE")
		threatSample:SetJustifyH("CENTER")
		local fs = db.platesThreatFontSize or 12
		local tw = threatSample:GetStringWidth() or 40
		threatDrag:SetSize(math.max(28, tw + 8), math.max(14, fs + 4))
		if selectedWidget == "threat" then
			threatOutline:Attach(threatDrag)
		elseif selectedWidget == "overpower" then
			opOutline:Attach(opDrag)
		end
		local tLock = db.platesThreatLocked and true or false
		local oLock = db.platesOverpowerLocked and true or false
		threatSample:SetTextColor(tLock and 0.75 or 0.2, tLock and 0.75 or 1, tLock and 0.75 or 0.2, 1)
		threatDrag:SetAlpha(tLock and 0.7 or 1)
		opDrag:SetAlpha(oLock and 0.55 or 1)
		sizeText:SetText(tostring(db.platesThreatFontSize or 12))
		opSizeText:SetText(tostring(db.platesOverpowerSize or 22))
		SyncLocks()
		if TT.Plates and TT.Plates.Refresh then
			TT.Plates.Refresh()
		end
	end

	SelectWidget(nil)
	plates:SetHeight(4 + 40 + 40 + 15 + 235 + 15 + 22 + 8 + 120 + 16)

	local function PaintTab(btn, selected)
		if selected then
			btn.bg:SetColorTexture(ar, ag, ab, 0.18)
			btn.label:SetTextColor(ar, ag, ab, 1)
			btn.bar:Show()
		else
			btn.bg:SetColorTexture(0.08, 0.09, 0.10, 1)
			btn.label:SetTextColor(1, 1, 1, 0.5)
			btn.bar:Hide()
		end
	end
	local function MakeTab(text)
		local btn = CreateFrame("Button", nil, tabBar)
		btn:SetSize(118, 26)
		btn.bg = Fill(btn, 0.08, 0.09, 0.10, 1)
		Border(btn, 1, 1, 1, 0.06)
		btn.label = Font(btn, 13, 1, 1, 1, 0.5)
		btn.label:SetPoint("CENTER", 0, 1)
		btn.label:SetText(text)
		btn.bar = btn:CreateTexture(nil, "ARTWORK")
		btn.bar:SetPoint("BOTTOMLEFT", 1, 0)
		btn.bar:SetPoint("BOTTOMRIGHT", -1, 0)
		btn.bar:SetHeight(2)
		btn.bar:SetColorTexture(ar, ag, ab, 1)
		btn.bar:Hide()
		return btn
	end
	local tabMeter = MakeTab("Meter")
	tabMeter:SetPoint("LEFT", tabBar, "LEFT", 0, 0)
	local tabDesigner = MakeTab("Designer")
	tabDesigner:SetPoint("LEFT", tabMeter, "RIGHT", 6, 0)

	local function ShowTab(which)
		if which == "designer" then
			general:Hide()
			plates:Show()
			PaintTab(tabMeter, false)
			PaintTab(tabDesigner, true)
		else
			plates:Hide()
			general:Show()
			PaintTab(tabMeter, true)
			PaintTab(tabDesigner, false)
		end
		scroll:SetVerticalScroll(0)
		LayoutScroll()
		if which == "designer" and RefreshPreview then
			RefreshPreview()
		end
	end
	tabMeter:SetScript("OnClick", function()
		ShowTab("meter")
	end)
	tabDesigner:SetScript("OnClick", function()
		ShowTab("designer")
	end)
	ShowTab("designer")
	LayoutScroll()

	f:SetScript("OnHide", HideMenu)
	f:SetScript("OnShow", function()
		LayoutScroll()
		if RefreshPreview then
			RefreshPreview()
		end
	end)

	C_Timer.After(0, RefreshPreview)
	return f
end

function TT.CreateOptions()
	return CreateOptions()
end

function TT.ToggleOptions()
	CreateOptions()
	if optionsFrame:IsShown() then
		HideMenu()
		optionsFrame:Hide()
	else
		optionsFrame:ClearAllPoints()
		optionsFrame:SetPoint("CENTER")
		optionsFrame:Show()
	end
end
