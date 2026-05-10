--[[ AzerothDataCollector_Meta: bağımsız addon (kendi .toc + bu .lua) ]] 
local ADDON_NAME, _unused = ...

local AC = AzerothDataCollector
if type(AC) ~= "table" then
	return
end

local function zoneText()
	local sub = GetRealZoneText() or ""
	local mini = GetMinimapZoneText() or ""
	if sub ~= "" then
		return sub
	end
	return mini
end

function AC.Scanners.meta()
	local ch = AC.GetCharacterRoot()
	local _, classFile = UnitClass("player")
	local raceName, _, raceID = UnitRace("player")
	local guid = AC.GetPlayerGuid()
	local specIdx = GetSpecialization and GetSpecialization() or nil
	local specId, specName
	if specIdx then
		specId, specName = select(1, GetSpecializationInfo(specIdx)), select(2, GetSpecializationInfo(specIdx))
	end
	local ailOverall, ailEquip = GetAverageItemLevel()
	ch.meta = {
		guid = guid,
		name = UnitName("player") or "?",
		realm = GetRealmName() or "?",
		level = UnitLevel("player") or 0,
		class = classFile,
		class_localized = select(1, UnitClass("player")),
		race = raceName,
		race_id = raceID,
		faction = UnitFactionGroup("player"),
		gender_id = UnitSex("player"),
		zone = zoneText(),
		subzone = GetSubZoneText(),
		ilvl_equipped = ailEquip or 0,
		ilvl_overall = ailOverall or 0,
		spec_index = specIdx,
		spec_id = specId,
		spec_name = specName,
		server_time = date("%Y-%m-%d %H:%M:%S"),
	}
	ch.meta.updated_at = time()
end

function AC.Scanners.wallet()
	local ch = AC.GetCharacterRoot()
	ch.wallet.copper = GetMoney()
	ch.wallet.updated_at = time()
	ch.wallet.partial = false
	ch.wallet.partial_reason = nil
end

local function bindMetaMoney()
	if AC.Scanners.meta then AC.Scanners.meta() end
	if AC.Scanners.wallet then AC.Scanners.wallet() end
end

AC.RegisterEvent("PLAYER_ENTERING_WORLD", function(_, isLogin, isReload)
	C_Timer.After(1, bindMetaMoney)
end)
AC.RegisterEvent("PLAYER_ALIVE", bindMetaMoney)
AC.RegisterEvent("PLAYER_MONEY", function()
	if AC.Scanners.wallet then AC.Scanners.wallet() end
end)
AC.RegisterEvent("PLAYER_LEVEL_UP", bindMetaMoney)
AC.RegisterEvent("PLAYER_GUILD_UPDATE", bindMetaMoney)
AC.RegisterEvent("ZONE_CHANGED_NEW_AREA", function()
	if AC.Scanners.meta then AC.Scanners.meta() end
end)
AC.RegisterEvent("ZONE_CHANGED", function()
	if AC.Scanners.meta then AC.Scanners.meta() end
end)
AC.RegisterEvent("PLAYER_XP_UPDATE", bindMetaMoney)
AC.RegisterEvent("PLAYER_UPDATE_RESTING", bindMetaMoney)
AC.RegisterEvent("HEARTHSTONE_BOUND", bindMetaMoney)
AC.RegisterEvent("TIME_PLAYED_MSG", function(_, total, lvl)
	local ch = AC.GetCharacterRoot()
	ch.meta = ch.meta or {}
	ch.meta.time_played_total_sec = total
	ch.meta.time_played_level_sec = lvl
	ch.meta.updated_at = time()
end)
