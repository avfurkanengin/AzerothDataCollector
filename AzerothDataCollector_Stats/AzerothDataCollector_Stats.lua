--[[
	AzerothDataCollector_Stats — SV: AzerothDataCollector_StatsDB
	Root DB fields plus by_character[guid].stats envelope; legacy characters migrated via AC.EnsureModuleSavedVariables.
	Extra triggers: UNIT_INVENTORY_CHANGED, WEEKLY_REWARDS_UPDATE (weekly rewards / inventory sync).
]]
local ADDON_NAME, _unused = ...

local AC = AzerothDataCollector
if type(AC) ~= "table" then
	return
end

AC.OnAddonLoaded(ADDON_NAME, function()
	AC.EnsureModuleSavedVariables(ADDON_NAME)
	local function addRow(env, id, name, value, extra)
		local r = { id = id, name = name, value = tostring(value) }
		if extra and type(extra) == "table" then
			for k, v in pairs(extra) do
				r[k] = v
			end
		end
		env.records[#env.records + 1] = r
	end

	function AC.Scanners.stats()
		local env = AC.NewEnvelope(false, nil)

		-- Core combat stats as flat rows
		addRow(env, "health_max", "HealthMax", UnitHealthMax("player"))
		addRow(env, "power_type", "PrimaryPowerType", UnitPowerType("player"))
		addRow(env, "power_max", "PrimaryPowerMax", UnitPowerMax("player"))
		addRow(env, "str", "Strength", UnitStat("player", 1))
		addRow(env, "agi", "Agility", UnitStat("player", 2))
		addRow(env, "sta", "Stamina", UnitStat("player", 3))
		addRow(env, "int", "Intellect", UnitStat("player", 4))
		addRow(env, "armor", "Armor", UnitArmor("player"))

		local minD, maxD = UnitDamage("player")
		addRow(env, "melee_damage", "MeleeDamage", string.format("%s-%s", math.floor(minD or 0), math.ceil(maxD or 0)))

		if C_WeeklyRewards then
			env.records[#env.records + 1] = {
				id = "weekly_rewards_available",
				name = "WeeklyRewardsAvailable",
				value = tostring(C_WeeklyRewards.HasAvailableRewards() and true or false),
			}

			local rf = { "ActivitiesReward", "RankedPvPReward", "RaidReward", "AlsoReceiveReward", "ConcessionReward", "WorldReward" }
			local enumT = Enum.WeeklyRewardChestThresholdType
			local types = {
				enumT.Activities,
				enumT.RankedPvP,
				enumT.Raid,
				enumT.AlsoReceive,
				enumT.Concession,
				enumT.World,
			}
			for i, rt in ipairs(types) do
				local ok, acts = pcall(function() return C_WeeklyRewards.GetActivities(rt) end)
				if ok and type(acts) == "table" then
					for _, act in pairs(acts) do
						if type(act) == "table" and act.index == 3 then
							addRow(env, "weekly_" .. tostring(i), rf[i] or ("RewardType" .. i), act.progress or 0, { reward_type_index = i })
						end
					end
				end
			end
		end

		-- Mythic+
		if C_ChallengeMode and C_MythicPlus then
			addRow(env, "dungeon_score", "OverallDungeonScore", C_ChallengeMode.GetOverallDungeonScore() or 0)
			if C_MythicPlus.RequestMapInfo then
				pcall(function() C_MythicPlus.RequestMapInfo() end)
			end

			local maps = C_ChallengeMode.GetMapTable()
			if maps then
				local bestTime, bestLevel, bestMapID = 999999, 0, nil
				for i = 1, #maps do
					local mapID = maps[i]
					local nm = C_ChallengeMode.GetMapUIInfo(mapID)
					local durSec, wkLevel = C_MythicPlus.GetWeeklyBestForMap(mapID)
					local intime, overtime = C_MythicPlus.GetSeasonBestForMap(mapID)
					local row = {
						id = mapID,
						name = nm or ("Map " .. mapID),
						weekly_best_level = wkLevel,
						weekly_best_time_sec = durSec,
					}
					if intime and intime.level then
						row.season_best_in_time_level = intime.level
						row.season_best_in_time_sec = intime.durationSec
					end
					if overtime and overtime.level then
						row.season_best_overtime_level = overtime.level
						row.season_best_overtime_sec = overtime.durationSec
					end
					env.records[#env.records + 1] = row

					if wkLevel and ((wkLevel > bestLevel) or (wkLevel == bestLevel and durSec and durSec < bestTime)) then
						bestTime = durSec or bestTime
						bestLevel = wkLevel
						bestMapID = mapID
					end
				end
				if bestMapID then
					local bestName = select(1, C_ChallengeMode.GetMapUIInfo(bestMapID))
					addRow(env, "mplus_weekly_best_map", "WeeklyBestMap", bestName or "", {
						level = bestLevel,
						time_sec = bestTime,
						map_id = bestMapID,
					})
				end
			end

			local okHist, hist = pcall(function()
				return C_MythicPlus.GetRunHistory(false, true)
			end)
			if okHist and type(hist) == "table" then
				local function appendRun(runInfo, suffix)
					if type(runInfo) ~= "table" then
						return
					end
					env.records[#env.records + 1] = {
						id = "run_" .. tostring(suffix),
						name = "MythicPlusRecentRun",
						map_challenge_mode_id = runInfo.mapChallengeModeID,
						level = runInfo.level,
						completed = runInfo.completed,
					}
				end
				local iter = hist[1] ~= nil and ipairs or pairs
				for idx, runInfo in iter(hist) do
					appendRun(runInfo, idx)
				end
			end
		end

		AC.CommitSection("stats", env)
	end

	AC.RegisterEvent("PLAYER_ALIVE", function()
		if AC.Scanners.stats then AC.Scanners.stats() end
	end)
	local CM_DEB = 1.25
	local CM_KEY = "adc_stats_challenge_maps"
	AC.RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE", function()
		local fn = AC.Scanners.stats
		if fn then AC.Debounce(CM_KEY, CM_DEB, fn) end
	end)

	local inventoryWeeklyDebounceSec = 1.0
	local inventoryWeeklyKey = "adc_stats_inventory_weekly"
	local function debouncedStatsInventoryAndWeekly()
		local fn = AC.Scanners.stats
		if fn then AC.Debounce(inventoryWeeklyKey, inventoryWeeklyDebounceSec, fn) end
	end
	AC.RegisterEvent("UNIT_INVENTORY_CHANGED", debouncedStatsInventoryAndWeekly)
	AC.RegisterEvent("WEEKLY_REWARDS_UPDATE", debouncedStatsInventoryAndWeekly)
end)
