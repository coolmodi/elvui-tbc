--[[
# Element: Health Prediction Bars

Handles the visibility and updating of incoming heals.

## Widget

HealthPrediction - A `table` containing references to sub-widgets and options.

## Sub-Widgets

myBar          - A `StatusBar` used to represent incoming heals from the player.
otherBar       - A `StatusBar` used to represent incoming heals from others.

## Notes

A default texture will be applied to the StatusBar widgets if they don't have a texture set.
A default texture will be applied to the Texture widgets if they don't have a texture or a color set.

## Options

.maxOverflow - The maximum amount of overflow past the end of the health bar. Set this to 1 to disable the overflow.
               Defaults to 1.05 (number)

## Examples

    -- Position and size
    local myBar = CreateFrame('StatusBar', nil, self.Health)
    myBar:SetPoint('TOP')
    myBar:SetPoint('BOTTOM')
    myBar:SetPoint('LEFT', self.Health:GetStatusBarTexture(), 'RIGHT')
    myBar:SetWidth(200)

    local otherBar = CreateFrame('StatusBar', nil, self.Health)
    otherBar:SetPoint('TOP')
    otherBar:SetPoint('BOTTOM')
    otherBar:SetPoint('LEFT', myBar:GetStatusBarTexture(), 'RIGHT')
    otherBar:SetWidth(200)

    -- Register with oUF
    self.HealthPrediction = {
        myBar = myBar,
        otherBar = otherBar,
        maxOverflow = 1.05,
    }
--]]

local _, ns = ...
local oUF = ns.oUF
local HealComm = LibStub("LibHealComm-4.0")

local function Update(self, event, unit)
	if(self.unit ~= unit) then return end

	local element = self.HealthPrediction

	--[[ Callback: HealthPrediction:PreUpdate(unit)
	Called before the element has been updated.

	* self - the HealthPrediction element
	* unit - the unit for which the update has been triggered (string)
	--]]
	if(element.PreUpdate) then
		element:PreUpdate(unit)
	end

	local unitGUID = UnitGUID(unit)
	local predictionTime = GetTime() + element.predictionTime
	local FLAG_DIRECT_HEALS = HealComm.DIRECT_HEALS

	local allDirectHeal = HealComm:GetHealAmount(unitGUID, FLAG_DIRECT_HEALS) or 0
	local beforeMyHeal = 0
	local myDirectHeal = (HealComm:GetHealAmount(unitGUID, FLAG_DIRECT_HEALS, nil, myGUID) or 0)
	local afterMyHeal = 0
	local health, maxHealth = UnitHealth(unit), UnitHealthMax(unit)
	local healMod = HealComm:GetHealModifier(unitGUID) or 1
	local maxHealShowm = maxHealth * element.maxOverflow - health

	if maxHealShowm > 0 then
		if myDirectHeal > 0 then
			-- We also have heal on the target, check if some direct heals land before ours.
			local _, healFrom, healAmount = HealComm:GetNextHealAmount(unitGUID, FLAG_DIRECT_HEALS, predictionTime)
			if healFrom and healFrom ~= myGUID then
				beforeMyHeal = healAmount
				-- Without much overflow we can probably stop here already very often.
				if beforeMyHeal < maxHealShowm then
					_, healFrom, healAmount = HealComm:GetNextHealAmount(unitGUID, FLAG_DIRECT_HEALS, predictionTime, healFrom)
					if healFrom and healFrom ~= myGUID then
						beforeMyHeal = beforeMyHeal + healAmount
					end
				end
			end
			-- Everything else (probably) comes after our heal.
			afterMyHeal = allDirectHeal - beforeMyHeal - myDirectHeal
		else
			afterMyHeal = allDirectHeal;
		end

		-- Append over time heal if direct heal isn't already above the overflow limit.
		if allDirectHeal < maxHealShowm then
			afterMyHeal = afterMyHeal + (HealComm:GetHealAmount(unitGUID, HealComm.OVERTIME_AND_BOMB_HEALS, predictionTime) or 0)
		end
	end

	beforeMyHeal = beforeMyHeal * healMod;
	myDirectHeal = myDirectHeal * healMod;
	afterMyHeal = afterMyHeal * healMod;

	if beforeMyHeal > maxHealShowm then
		beforeMyHeal = maxHealShowm
		myDirectHeal = 0
		afterMyHeal = 0
	else
		maxHealShowm = maxHealShowm - beforeMyHeal
		if myDirectHeal > maxHealShowm then
			myDirectHeal = maxHealShowm
			afterMyHeal = 0
		else
			maxHealShowm = maxHealShowm - myDirectHeal
			if afterMyHeal > maxHealShowm then
				afterMyHeal = maxHealShowm
			end
		end
	end

	if(element.beforeBar) then
		element.beforeBar:SetMinMaxValues(0, maxHealth)
		element.beforeBar:SetValue(beforeMyHeal)
		element.beforeBar:Show()
	end

	if(element.myBar) then
		element.myBar:SetMinMaxValues(0, maxHealth)
		element.myBar:SetValue(myDirectHeal)
		element.myBar:Show()
	end

	if(element.afterBar) then
		element.afterBar:SetMinMaxValues(0, maxHealth)
		element.afterBar:SetValue(afterMyHeal)
		element.afterBar:Show()
	end

	--[[ Callback: HealthPrediction:PostUpdate(unit, myIncomingHeal, otherIncomingHeal)
	Called after the element has been updated.

	* self              - the HealthPrediction element
	* unit              - the unit for which the update has been triggered (string)
	* myIncomingHeal    - the amount of incoming healing done by the player (number)
	* otherIncomingHeal - the amount of incoming healing done by others (number)
	--]]
	if(element.PostUpdate) then
		return element:PostUpdate(unit, myDirectHeal, beforeMyHeal + afterMyHeal)
	end
end

local function Path(self, ...)
	--[[ Override: HealthPrediction.Override(self, event, unit)
	Used to completely override the internal update function.

	* self  - the parent object
	* event - the event triggering the update (string)
	* unit  - the unit accompanying the event
	--]]
	return (self.HealthPrediction.Override or Update) (self, ...)
end

local function ForceUpdate(element)
	return Path(element.__owner, 'ForceUpdate', element.__owner.unit)
end

local function Enable(self)
	local element = self.HealthPrediction
	if(element) then
		element.__owner = self
		element.ForceUpdate = ForceUpdate
		element.healType = element.healType or HealComm.ALL_HEALS

		self:RegisterEvent('UNIT_HEALTH_FREQUENT', Path)
		self:RegisterEvent('UNIT_MAXHEALTH', Path)
		self:RegisterEvent('UNIT_HEAL_PREDICTION', Path)

		local function HealCommUpdate(...)
			if self.HealthPrediction and self:IsVisible() then
				for i = 1, select('#', ...) do
					if self.unit and UnitGUID(self.unit) == select(i, ...) then
						Path(self, nil, self.unit)
					end
				end
			end
		end

		local function HealComm_Heal_Update(event, casterGUID, spellID, healType, _, ...)
			HealCommUpdate(...)
		end

		local function HealComm_Modified(event, guid)
			HealCommUpdate(guid)
		end

		HealComm.RegisterCallback(element, 'HealComm_HealStarted', HealComm_Heal_Update)
		HealComm.RegisterCallback(element, 'HealComm_HealUpdated', HealComm_Heal_Update)
		HealComm.RegisterCallback(element, 'HealComm_HealDelayed', HealComm_Heal_Update)
		HealComm.RegisterCallback(element, 'HealComm_HealStopped', HealComm_Heal_Update)
		HealComm.RegisterCallback(element, 'HealComm_ModifierChanged', HealComm_Modified)
		HealComm.RegisterCallback(element, 'HealComm_GUIDDisappeared', HealComm_Modified)

		if(not element.maxOverflow) then
			element.maxOverflow = 1.05
		end

		if(element.beforeBar) then
			if(element.beforeBar:IsObjectType('StatusBar') and not element.beforeBar:GetStatusBarTexture()) then
				element.beforeBar:SetStatusBarTexture([[Interface\TargetingFrame\UI-StatusBar]])
			end
		end

		if(element.afterBar) then
			if(element.afterBar:IsObjectType('StatusBar') and not element.afterBar:GetStatusBarTexture()) then
				element.afterBar:SetStatusBarTexture([[Interface\TargetingFrame\UI-StatusBar]])
			end
		end

		if(element.myBar) then
			if(element.myBar:IsObjectType('StatusBar') and not element.myBar:GetStatusBarTexture()) then
				element.myBar:SetStatusBarTexture([[Interface\TargetingFrame\UI-StatusBar]])
			end
		end

		return true
	end
end

local function Disable(self)
	local element = self.HealthPrediction
	if(element) then
		if(element.beforeBar) then
			element.beforeBar:Hide()
		end

		if(element.afterBar) then
			element.afterBar:Hide()
		end

		if(element.myBar) then
			element.myBar:Hide()
		end

		HealComm.UnregisterCallback(element, 'HealComm_HealStarted')
		HealComm.UnregisterCallback(element, 'HealComm_HealUpdated')
		HealComm.UnregisterCallback(element, 'HealComm_HealDelayed')
		HealComm.UnregisterCallback(element, 'HealComm_HealStopped')
		HealComm.UnregisterCallback(element, 'HealComm_ModifierChanged')
		HealComm.UnregisterCallback(element, 'HealComm_GUIDDisappeared')

		self:UnregisterEvent('UNIT_MAXHEALTH', Path)
		self:UnregisterEvent('UNIT_HEALTH_FREQUENT', Path)
		self:UnregisterEvent('UNIT_HEAL_PREDICTION', Path)
	end
end

oUF:AddElement('HealthPrediction', Path, Enable, Disable)
