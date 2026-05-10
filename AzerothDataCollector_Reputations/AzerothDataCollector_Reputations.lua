--[[
	AzerothDataCollector_Reputations — SV: AzerothDataCollector_ReputationsDB
	Root DB fields plus by_character[guid].reputations envelope; legacy characters migrated via AC.EnsureModuleSavedVariables.
	UPDATE_FACTION can spam; faction rescans ride a debounced full reputations scanner.
]]
local ADDON_NAME, _unused = ...

local AC = AzerothDataCollector
if type(AC) ~= "table" then
	return
end

local REPUTATION_UPDATE_DELAY_SEC = 3
local DEBOUNCE_KEY_FACTION = "adc_reputations_faction"

AC.OnAddonLoaded(ADDON_NAME, function()
	AC.EnsureModuleSavedVariables(ADDON_NAME)
	local headerState = {}

	local function SaveHeadersRetail()
		local n = C_Reputation.GetNumFactions()
		wipe(headerState)
		local count = 0
		for i = n, 1, -1 do
			local data = C_Reputation.GetFactionDataByIndex(i)
			if data and data.isHeader then
				count = count + 1
				if data.isCollapsed then
					C_Reputation.ExpandFactionHeader(i)
					headerState[count] = true
				end
			end
		end
	end

	local function RestoreHeadersRetail()
		local n = C_Reputation.GetNumFactions()
		local count = 0
		for i = n, 1, -1 do
			local data = C_Reputation.GetFactionDataByIndex(i)
			if data and data.isHeader then
				count = count + 1
				if headerState[count] then
					C_Reputation.CollapseFactionHeader(i)
				end
			end
		end
		wipe(headerState)
	end

	local function factionRow(factionID, indexInList)
		if not factionID or factionID == 0 then return nil end

		-- Major faction (renown)
		if C_Reputation.IsMajorFaction and C_Reputation.IsMajorFaction(factionID) then
			local md = C_MajorFactions and C_MajorFactions.GetMajorFactionData(factionID)
			if md then
				local nameData = C_Reputation.GetFactionDataByID(factionID)
				return {
					id = factionID,
					name = nameData and nameData.name or ("Faction " .. factionID),
					faction_type = "major",
					renown_level = md.renownLevel,
					renown_rep_earned = md.renownReputationEarned,
					renown_threshold = md.renownLevelThreshold,
				}
			end
		end

		-- Friendship
		local fr = C_GossipInfo and C_GossipInfo.GetFriendshipReputation(factionID)
		if fr and fr.friendshipFactionID and fr.friendshipFactionID > 0 then
			local ranks = C_GossipInfo.GetFriendshipReputationRanks(factionID)
			local nameData = C_Reputation.GetFactionDataByID(factionID)
			return {
				id = factionID,
				name = nameData and nameData.name or ("Faction " .. factionID),
				faction_type = "friendship",
				friendship_level = ranks and ranks.currentLevel or nil,
				friendship_standing = fr.standing,
				friendship_next_threshold = fr.nextThreshold,
			}
		end

		local data = C_Reputation.GetFactionDataByIndex(indexInList)
		if not data then return nil end

		local earned = data.currentStanding
		local standing = data.reaction

		-- Paragon
		if C_Reputation.IsFactionParagon and C_Reputation.IsFactionParagon(factionID) then
			local cur, threshold, _, hasReward = C_Reputation.GetFactionParagonInfo(factionID)
			local display = cur
			if display and threshold then
				while display >= 10000 do
					display = display - 10000
				end
			end
			if hasReward and display then
				display = display + 10000
			end
			return {
				id = factionID,
				name = data.name,
				faction_type = "paragon",
				standing_index = standing,
				paragon_value = display,
				paragon_threshold = threshold,
			}
		end

		return {
			id = factionID,
			name = data.name,
			faction_type = "normal",
			standing_index = standing,
			reputation_value = earned,
			is_header = data.isHeader,
		}
	end

	function AC.Scanners.reputations()
		local env = AC.NewEnvelope(false, nil)
		SaveHeadersRetail()

		for i = 1, C_Reputation.GetNumFactions() do
			local data = C_Reputation.GetFactionDataByIndex(i)
			if data and not data.isHeader then
				local row = factionRow(data.factionID, i)
				if row and not row.is_header then
					env.records[#env.records + 1] = row
				end
			end
		end

		RestoreHeadersRetail()

		-- Guild renown-style row via GetFactionDataByGuild if present
		do
			local gName = GetGuildInfo("player")
			if gName and gName ~= "" then
				for _, row in ipairs(env.records) do
					if row.name == gName then
						row.is_guild = true
					end
				end
			end
		end

		AC.CommitSection("reputations", env)
	end

	AC.RegisterEvent("PLAYER_ALIVE", function()
		if AC.Scanners.reputations then AC.Scanners.reputations() end
	end)
	AC.RegisterEvent("UPDATE_FACTION", function()
		if not AC.Scanners.reputations then
			return
		end
		AC.Debounce(DEBOUNCE_KEY_FACTION, REPUTATION_UPDATE_DELAY_SEC, AC.Scanners.reputations)
	end)
end)
