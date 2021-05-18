local PLUGIN_NAME = "HealCommTags";
local E, L, V, P, G = unpack(ElvUI);
local oUF = E.oUF;
local Plugin = E:NewModule(PLUGIN_NAME);
local EP = LibStub("LibElvUIPlugin-1.0");
local HealComm = LibStub("LibHealComm-4.0");

local STRING_GHOST = GetSpellInfo(8326);
local STRING_FEIGN_DEATH = GetSpellInfo(5384);
local TAG_HEALPREDICTION = "hchealth";
local TAG_HEALPREDICTION_NAME = "hchealth:name";
local TAG_HEALPREDICTION_NOSTATUS = "hchealth:nostatus";
local TAG_HEALPREDICTION_NAME_NOSTATUS = "hchealth:name-nostatus";

local HCBitflag = HealComm.ALL_HEALS;
local healTimeframe = 2;

---------------------------------
-- Add tags
---------------------------------

local function PredictionTag(unit, showStatus, showName)
	if UnitIsGhost(unit) then
        return showStatus and STRING_GHOST or nil;
    end

    if not UnitIsConnected(unit) then
        return showStatus and FRIENDS_LIST_OFFLINE or nil;
    end

    local hp = UnitHealth(unit);
    local maxhp = UnitHealthMax(unit);

    if hp < 1 then
        if UnitIsFeignDeath(unit) then
            return showStatus and STRING_FEIGN_DEATH or nil;
        else
            return showStatus and DEAD or nil;
        end
    end

    if UnitIsEnemy("player", unit) then
        return hp .. "/" .. maxhp;
    end

    local incomingHeal = (HealComm:GetHealAmount(UnitGUID(unit), HCBitflag, GetTime() + healTimeframe) or 0) * (HealComm:GetHealModifier(UnitGUID(unit)) or 1);
    local hpDeficitAfterHeal = math.floor(incomingHeal) + hp - maxhp;

    if incomingHeal > 0 then
        return "|cFF00FF00" .. hpDeficitAfterHeal .. "|r";
    else
        if hpDeficitAfterHeal ~= 0 then
            return hpDeficitAfterHeal;
        else
            return showName and UnitName(unit) or nil;
        end
    end
end

oUF.Tags.Events[TAG_HEALPREDICTION] = "UNIT_CONNECTION UNIT_HEALTH_FREQUENT UNIT_MAXHEALTH HealComm_HealStarted HealComm_HealUpdated HealComm_HealStopped HealComm_ModifierChanged HealComm_GUIDDisappeared";
oUF.Tags.Methods[TAG_HEALPREDICTION] = function(unit)
    return PredictionTag(unit, true);
end

oUF.Tags.Events[TAG_HEALPREDICTION_NAME] = oUF.Tags.Events[TAG_HEALPREDICTION];
oUF.Tags.Methods[TAG_HEALPREDICTION_NAME] = function(unit)
    return PredictionTag(unit, true, true);
end

oUF.Tags.Events[TAG_HEALPREDICTION_NOSTATUS] = oUF.Tags.Events[TAG_HEALPREDICTION];
oUF.Tags.Methods[TAG_HEALPREDICTION_NOSTATUS] = function(unit)
    return PredictionTag(unit);
end

oUF.Tags.Events[TAG_HEALPREDICTION_NAME_NOSTATUS] = oUF.Tags.Events[TAG_HEALPREDICTION];
oUF.Tags.Methods[TAG_HEALPREDICTION_NAME_NOSTATUS] = function(unit)
    return PredictionTag(unit, false, true);
end

---------------------------------
-- ElvUI module stuff
---------------------------------

P[PLUGIN_NAME] = {
	["includeHoTsInTag"] = true,
	["healTimeframe"] = healTimeframe,
}

function Plugin:Update()
	HCBitflag = E.db[PLUGIN_NAME].includeHoTsInTag and HealComm.ALL_HEALS or HealComm.DIRECT_HEALS;
	healTimeframe = E.db[PLUGIN_NAME].healTimeframe;
end

function Plugin:InsertOptions()
	E.Options.args[PLUGIN_NAME] = {
		order = 100,
		type = "group",
		name = PLUGIN_NAME,
		args = {
			includeHoTsInTag = {
				order = 1,
				type = "toggle",
				name = "Include HoTs",
				get = function(info)
					return E.db[PLUGIN_NAME].includeHoTsInTag;
				end,
				set = function(info, value)
					E.db[PLUGIN_NAME].includeHoTsInTag = value;
					Plugin:Update();
				end,
			},
			healTimeframe = {
				order = 2,
				type = "range",
				name = "Prediction timeframe.",
				desc = "How many seconds to look ahead for incoming heals.",
				min = 2,
				max = 20,
				step = 1,
				get = function(info)
					return E.db[PLUGIN_NAME].healTimeframe;
				end,
				set = function(info, value)
					E.db[PLUGIN_NAME].healTimeframe = value;
					Plugin:Update();
				end,
			},
		},
	}
end

function Plugin:Initialize()
	EP:RegisterPlugin(PLUGIN_NAME, Plugin.InsertOptions);
	E:AddTagInfo(TAG_HEALPREDICTION, "Health", "Displays HP deficit with HealComm prediction");
	E:AddTagInfo(TAG_HEALPREDICTION_NAME, "Health", "Displays HP deficit with HealComm prediction, name at full HP");
	E:AddTagInfo(TAG_HEALPREDICTION_NOSTATUS, "Health", "Displays HP deficit with HealComm prediction, without status");
	E:AddTagInfo(TAG_HEALPREDICTION_NAME_NOSTATUS, "Health", "Displays HP deficit with HealComm prediction, name at full HP, without status");
end

E:RegisterModule(Plugin:GetName());