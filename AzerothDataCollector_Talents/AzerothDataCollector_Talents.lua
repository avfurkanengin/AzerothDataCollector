--[[
	AzerothDataCollector_Talents — SV: AzerothDataCollector_TalentsDB
	Kök + by_character[guid].talents = envelope | eski characters → by_character.
]]
local ADDON_NAME, _unused = ...

local AC = AzerothDataCollector
if type(AC) ~= "table" then
	return
end

AC.OnAddonLoaded(ADDON_NAME, function()
	AC.EnsureModuleSavedVariables(ADDON_NAME)
	local function scanClassicTalentGrid()
		local records = {}
		local maxTier = GetMaxTalentTier and GetMaxTalentTier() or 0
		for tier = 1, maxTier do
			for column = 1, 3 do
				local tid, name, _, selected = GetTalentInfo(tier, column, 1)
				if tid then
					records[#records + 1] = {
						id = tid,
						name = name or ("talent_" .. tier .. "_" .. column),
						tier = tier,
						column = column,
						selected = selected and true or false,
					}
				end
			end
		end
		return records
	end

	local function scanTraitConfigs()
		local records = {}
		if not (C_ClassTalents and C_Traits) then
			return records
		end
		local ok, configID = pcall(function() return C_ClassTalents.GetActiveConfigID() end)
		if not ok or not configID then
			return records
		end

		local cfgInfoOk, configInfo = pcall(function()
			return C_Traits.GetConfigInfo(configID)
		end)
		if cfgInfoOk and configInfo then
			records[#records + 1] = {
				id = configID,
				name = configInfo.name or "active_trait_config",
				trait_currency_id = configInfo.currencyID,
			}
		end

		local treeIDsOk, treeIDs = pcall(function() return C_Traits.GetTreeIDs(configID) end)
		if not treeIDsOk or not treeIDs then return records end

		for _, treeID in ipairs(treeIDs) do
			local nodesOk, nodes = pcall(function() return C_Traits.GetTreeNodes(treeID) end)
			if nodesOk and nodes then
				for _, nodeID in ipairs(nodes) do
					local nOk, ni = pcall(function() return C_Traits.GetNodeInfo(nodeID) end)
					if nOk and ni and ni.activeEntry then
						local entryOk, entry = pcall(function() return C_Traits.GetEntryInfo(ni.activeEntry) end)
						if entryOk and entry and entry.definitionID then
							local defOk, di = pcall(function() return C_Traits.GetDefinitionInfo(entry.definitionID) end)
							records[#records + 1] = {
								id = entry.definitionID,
								name = (di and di.name) or ("node_" .. nodeID),
								node_id = nodeID,
								tree_id = treeID,
								rank = ni.activeRank or ni.currentRank or 1,
								trait_spell_id = entry.spellID,
							}
						end
					end
				end
			end
		end
		return records
	end

	function AC.Scanners.talents()
		local env = AC.NewEnvelope(false, nil)
		env.records[#env.records + 1] = {
			id = 0,
			name = "class",
			value = select(2, UnitClass("player")),
			class_id = select(3, UnitClass("player")),
		}

		local idx = GetSpecialization and GetSpecialization() or nil
		if idx then
			local sid, sname = GetSpecializationInfo(idx)
			env.records[#env.records + 1] = {
				id = sid or idx,
				name = "specialization_active",
				spec_index = idx,
				spec_localized_name = sname,
			}
		end

		local level = UnitLevel("player") or 0
		if level >= 10 then
			for _, row in ipairs(scanClassicTalentGrid()) do
				env.records[#env.records + 1] = row
			end
			for _, row in ipairs(scanTraitConfigs()) do
				env.records[#env.records + 1] = row
			end
		end

		if #env.records == 1 then -- only class row
			env.partial = level < 10
			env.partial_reason = level < 10 and "low_level" or nil
		end

		AC.CommitSection("talents", env)
	end

	AC.RegisterEvent("PLAYER_ALIVE", function()
		if AC.Scanners.talents then AC.Scanners.talents() end
	end)
	AC.RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED", function()
		if AC.Scanners.talents then AC.Scanners.talents() end
	end)
	AC.RegisterEvent("PLAYER_TALENT_UPDATE", function()
		if AC.Scanners.talents then AC.Scanners.talents() end
	end)
	AC.RegisterEvent("TRAIT_TREE_CURRENCY_INFO_UPDATED", function()
		if AC.Scanners.talents then AC.Scanners.talents() end
	end)
end)
