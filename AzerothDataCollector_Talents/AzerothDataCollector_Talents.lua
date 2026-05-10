--[[
	AzerothDataCollector_Talents — SV: AzerothDataCollector_TalentsDB
	Root DB fields plus by_character[guid].talents envelope; legacy characters migrated via AC.EnsureModuleSavedVariables.
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

	local function definitionDisplayName(definitionID)
		if not definitionID then
			return nil
		end
		local ok, di = pcall(function()
			return C_Traits.GetDefinitionInfo(definitionID)
		end)
		if not ok or not di then
			return nil
		end
		if di.overrideName and di.overrideName ~= "" then
			return di.overrideName
		end
		if di.spellID and di.spellID ~= 0 then
			local nm = GetSpellInfo(di.spellID)
			if nm and nm ~= "" then
				return nm
			end
		end
		return nil
	end

	--- Retail Dragonflight+ talents use C_Traits; GetNodeInfo(configID, nodeID) takes TWO arguments.
	local function scanTraitConfigs()
		local records = {}
		if not (C_ClassTalents and C_Traits) then
			return records
		end
		local ok, configID = pcall(function()
			return C_ClassTalents.GetActiveConfigID()
		end)
		if not ok or not configID or configID == -1 then
			return records
		end

		local cfgInfoOk, configInfo = pcall(function()
			return C_Traits.GetConfigInfo(configID)
		end)
		if cfgInfoOk and configInfo then
			records[#records + 1] = {
				record_kind = "trait_config",
				id = configID,
				name = configInfo.name or "active_trait_config",
				trait_currency_id = configInfo.currencyID,
			}
		end

		local treeIDsOk, treeIDs = pcall(function()
			return C_Traits.GetTreeIDs(configID)
		end)
		if not treeIDsOk or not treeIDs then
			return records
		end

		for _, treeID in ipairs(treeIDs) do
			local nodesOk, nodes = pcall(function()
				return C_Traits.GetTreeNodes(treeID)
			end)
			if nodesOk and nodes then
				local nodeList = {}
				if type(nodes) == "table" then
					local nlen = #nodes
					if nlen > 0 then
						for i = 1, nlen do
							nodeList[#nodeList + 1] = nodes[i]
						end
					else
						for _, nid in pairs(nodes) do
							if type(nid) == "number" then
								nodeList[#nodeList + 1] = nid
							end
						end
					end
				end
				for _, nodeID in ipairs(nodeList) do
					local nOk, ni = pcall(function()
						return C_Traits.GetNodeInfo(configID, nodeID)
					end)
					if not nOk or not ni or not ni.ID or ni.ID == 0 then
						-- hidden / unavailable
					else
						local ranksPurchased = tonumber(ni.ranksPurchased) or 0
						local activeRank = tonumber(ni.activeRank or ni.currentRank) or 0
						local maxRanks = tonumber(ni.maxRanks) or 0
						local primaryName
						local primarySpellID
						local primaryDefinitionID

						local function applyEntry(entryID)
							if not entryID then
								return
							end
							local eOk, entry = pcall(function()
								return C_Traits.GetEntryInfo(configID, entryID)
							end)
							if not eOk or not entry or not entry.definitionID then
								return
							end
							local nm = definitionDisplayName(entry.definitionID)
							local diOk, di = pcall(function()
								return C_Traits.GetDefinitionInfo(entry.definitionID)
							end)
							local sp = (diOk and di and di.spellID) or nil
							if nm and nm ~= "" then
								primaryName = primaryName or nm
							end
							if sp and sp ~= 0 then
								primarySpellID = primarySpellID or sp
							end
							primaryDefinitionID = primaryDefinitionID or entry.definitionID
						end

						if ni.activeEntry and ni.activeEntry.entryID then
							applyEntry(ni.activeEntry.entryID)
						end
						if type(ni.entryIDsWithCommittedRanks) == "table" then
							for _, eid in ipairs(ni.entryIDsWithCommittedRanks) do
								if type(eid) == "number" then
									applyEntry(eid)
								end
							end
						end
						if type(ni.entryIDs) == "table" then
							for _, eid in ipairs(ni.entryIDs) do
								applyEntry(eid)
								if primaryName then
									break
								end
							end
						end

						records[#records + 1] = {
							record_kind = "trait_node",
							node_id = nodeID,
							tree_id = treeID,
							config_id = configID,
							name = primaryName or ("trait_node_" .. nodeID),
							definition_id = primaryDefinitionID,
							trait_spell_id = primarySpellID,
							ranks_purchased = ranksPurchased,
							active_rank = activeRank,
							max_ranks = maxRanks,
							selected = (activeRank > 0 or ranksPurchased > 0) and true or false,
							node_type = ni.type,
							sub_tree_id = ni.subTreeID,
							sub_tree_active = ni.subTreeActive,
						}
					end
				end
			end
		end
		return records
	end

	function AC.Scanners.talents()
		local env = AC.NewEnvelope(false, nil)
		env.records[#env.records + 1] = {
			record_kind = "player_class",
			id = 0,
			name = "class",
			value = select(2, UnitClass("player")),
			class_id = select(3, UnitClass("player")),
		}

		local idx = GetSpecialization and GetSpecialization() or nil
		if idx then
			local sid, sname = GetSpecializationInfo(idx)
			env.records[#env.records + 1] = {
				record_kind = "specialization_active",
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

		local traitRows = 0
		for i = 1, #env.records do
			local r = env.records[i]
			if type(r) == "table" and (r.record_kind == "trait_node" or r.record_kind == "trait_config") then
				traitRows = traitRows + 1
			end
		end

		if level < 10 then
			env.partial = true
			env.partial_reason = "low_level"
		elseif level >= 10 and traitRows == 0 then
			env.partial = true
			env.partial_reason = env.partial_reason or "trait_scan_empty"
		end

		AC.CommitSection("talents", env)
	end

	local T_DEB = 0.55
	local T_KEY = "adc_talents"
	local function debouncedTalents()
		local fn = AC.Scanners.talents
		if fn then AC.Debounce(T_KEY, T_DEB, fn) end
	end

	AC.RegisterEvent("PLAYER_ALIVE", function()
		if AC.Scanners.talents then AC.Scanners.talents() end
	end)
	AC.RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED", debouncedTalents)
	AC.RegisterEvent("PLAYER_TALENT_UPDATE", debouncedTalents)
	AC.RegisterEvent("TRAIT_TREE_CURRENCY_INFO_UPDATED", debouncedTalents)
end)
