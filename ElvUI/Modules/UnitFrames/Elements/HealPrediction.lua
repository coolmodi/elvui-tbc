local E, L, V, P, G = unpack(select(2, ...)) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local UF = E:GetModule('UnitFrames')
local HealComm = LibStub("LibHealComm-4.0")

--WoW API / Variables
local CreateFrame = CreateFrame

function UF.HealthClipFrame_HealComm(frame)
	local pred = frame.HealthPrediction
	if pred then
		UF:SetAlpha_HealComm(pred, true)
		UF:SetVisibility_HealComm(pred)
	end
end

function UF:SetAlpha_HealComm(obj, show)
	obj.beforeBar:SetAlpha(show and 1 or 0)
	obj.myBar:SetAlpha(show and 1 or 0)
	obj.afterBar:SetAlpha(show and 1 or 0)
end

function UF:SetVisibility_HealComm(obj)
	-- the first update is from `HealthClipFrame_HealComm`
	-- we set this variable to allow `Configure_HealComm` to
	-- update the elements overflow lock later on by option
	if not obj.allowClippingUpdate then
		obj.allowClippingUpdate = true
	end

	if obj.maxOverflow > 1 then
		obj.beforeBar:SetParent(obj.health)
		obj.myBar:SetParent(obj.health)
		obj.afterBar:SetParent(obj.health)
	else
		obj.beforeBar:SetParent(obj.parent)
		obj.myBar:SetParent(obj.parent)
		obj.afterBar:SetParent(obj.parent)
	end
end

function UF:Construct_HealComm(frame)
	local health = frame.Health
	local parent = health.ClipFrame

	local beforeBar = CreateFrame('StatusBar', nil, parent)
	local myBar = CreateFrame('StatusBar', nil, parent)
	local afterBar = CreateFrame('StatusBar', nil, parent)

	beforeBar:SetFrameLevel(11)
	myBar:SetFrameLevel(11)
	afterBar:SetFrameLevel(11)

	UF.statusbars[beforeBar] = true
	UF.statusbars[myBar] = true
	UF.statusbars[afterBar] = true

	local texture = (not health.isTransparent and health:GetStatusBarTexture()) or E.media.blankTex
	UF:Update_StatusBar(beforeBar, texture)
	UF:Update_StatusBar(myBar, texture)
	UF:Update_StatusBar(afterBar, texture)

	local healPrediction = {
		predictionTime = 3,
		beforeBar = beforeBar,
		myBar = myBar,
		afterBar = afterBar,
		maxOverflow = 1,
		health = health,
		parent = parent,
		frame = frame
	}

	UF:SetAlpha_HealComm(healPrediction)

	return healPrediction
end

function UF:Configure_HealComm(frame)
	if frame.db.healPrediction and frame.db.healPrediction.enable then
		local healPrediction = frame.HealthPrediction
		local beforeBar = healPrediction.beforeBar
		local myBar = healPrediction.myBar
		local afterBar = healPrediction.afterBar
		local c = self.db.colors.healPrediction
		healPrediction.maxOverflow = 1 + (c.maxOverflow or 0)

		if healPrediction.allowClippingUpdate then
			UF:SetVisibility_HealComm(healPrediction)
		end

		if not frame:IsElementEnabled('HealthPrediction') then
			frame:EnableElement('HealthPrediction')
		end

		healPrediction.healType = HealComm[frame.db.healPrediction.healType]
		healPrediction.predictionTime = frame.db.healPrediction.predictionTime

		local health = frame.Health
		local orientation = health:GetOrientation()
		local reverseFill = health:GetReverseFill()
		local healthBarTexture = health:GetStatusBarTexture()

		beforeBar:SetOrientation(orientation)
		myBar:SetOrientation(orientation)
		afterBar:SetOrientation(orientation)

		if orientation == "HORIZONTAL" then
			local width = health:GetWidth()
			width = (width > 0 and width) or health.WIDTH
			local p1 = reverseFill and "RIGHT" or "LEFT"
			local p2 = reverseFill and "LEFT" or "RIGHT"

			beforeBar:Size(width, 0)
			beforeBar:ClearAllPoints()
			beforeBar:Point("TOP", health, "TOP")
			beforeBar:Point("BOTTOM", health, "BOTTOM")
			beforeBar:Point(p1, healthBarTexture, p2)

			myBar:Size(width, 0)
			myBar:ClearAllPoints()
			myBar:Point("TOP", health, "TOP")
			myBar:Point("BOTTOM", health, "BOTTOM")
			myBar:Point(p1, beforeBar:GetStatusBarTexture(), p2)

			afterBar:Size(width, 0)
			afterBar:ClearAllPoints()
			afterBar:Point("TOP", health, "TOP")
			afterBar:Point("BOTTOM", health, "BOTTOM")
			afterBar:Point(p1, myBar:GetStatusBarTexture(), p2)
		else
			local height = health:GetHeight()
			height = (height > 0 and height) or health.HEIGHT
			local p1 = reverseFill and "TOP" or "BOTTOM"
			local p2 = reverseFill and "BOTTOM" or "TOP"

			beforeBar:Size(0, height)
			beforeBar:ClearAllPoints()
			beforeBar:Point("LEFT", health, "LEFT")
			beforeBar:Point("RIGHT", health, "RIGHT")
			beforeBar:Point(p1, healthBarTexture, p2)

			myBar:Size(0, height)
			myBar:ClearAllPoints()
			myBar:Point("LEFT", health, "LEFT")
			myBar:Point("RIGHT", health, "RIGHT")
			myBar:Point(p1, beforeBar:GetStatusBarTexture(), p2)

			afterBar:Size(0, height)
			afterBar:ClearAllPoints()
			afterBar:Point("LEFT", health, "LEFT")
			afterBar:Point("RIGHT", health, "RIGHT")
			afterBar:Point(p1, myBar:GetStatusBarTexture(), p2)
		end

		beforeBar:SetReverseFill(reverseFill)
		myBar:SetReverseFill(reverseFill)
		afterBar:SetReverseFill(reverseFill)

		beforeBar:SetStatusBarColor(c.others.r, c.others.g, c.others.b, c.others.a)
		myBar:SetStatusBarColor(c.personal.r, c.personal.g, c.personal.b, c.personal.a)
		afterBar:SetStatusBarColor(c.others.r, c.others.g, c.others.b, c.others.a)
	elseif frame:IsElementEnabled('HealthPrediction') then
		frame:DisableElement('HealthPrediction')
	end
end
