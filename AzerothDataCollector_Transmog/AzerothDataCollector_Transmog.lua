--[[
	AzerothDataCollector_Transmog — SV: AzerothDataCollector_TransmogDB
	by_character[guid].collections_transmog — category summary plus collected appearance rows.
	by_character[guid].collections_transmog_sets — collected set snapshot.
	TRANSMOG_COLLECTION_UPDATED debounced; TRANSMOG_COLLECTION_LOADED and PLAYER_ALIVE flush immediately.
]]
local ADDON_NAME, _unused = ...

local AC = AzerothDataCollector
if type(AC) ~= "table" then
	return
end

AC.OnAddonLoaded(ADDON_NAME, function()
	AC.EnsureModuleSavedVariables(ADDON_NAME)

	--- Safety cap for very large wardrobes
	local APPEARANCES_CAP = 28000
	local TRANSMOG_DEBOUNCE_SEC = 2
	local DEBOUNCE_KEY_TRANSMOG = "adc_collections_transmog"

	local function scanTransmogSummary()
		local rec = {}
		if not C_TransmogCollection.GetCategoryCollectedCount then
			return rec
		end
		for catId = 0, 55 do
			local ok, nm = pcall(function()
				return C_TransmogCollection.GetCategoryInfo(catId)
			end)
			if ok and nm then
				rec[#rec + 1] = {
					record_kind = "category_summary",
					category_id = catId,
					name = nm or ("appearance_cat_" .. catId),
					collected = C_TransmogCollection.GetCategoryCollectedCount(catId) or 0,
					total = C_TransmogCollection.GetCategoryTotal(catId) or 0,
				}
			end
		end
		return rec
	end

	local function appearanceSourceItemLink(sourceID)
		local ok, link = pcall(function()
			local r = { C_TransmogCollection.GetAppearanceSourceInfo(sourceID) }
			for _, v in ipairs(r) do
				if type(v) == "string" and v:find("|Hitem:") then
					return v
				end
			end
			return nil
		end)
		if ok and type(link) == "string" then
			return link
		end
		return nil
	end

	local function scanTransmogCollectedAppearances(cap)
		local rec = {}
		local partial = false
		local partialReason

		local function addRow(catId, catNameStr, visualID, chosenSourceID)
			if #rec >= cap then
				partial = true
				partialReason = "appearances_detail_capped_" .. cap
				return false
			end
			local item_link = appearanceSourceItemLink(chosenSourceID)
			local item_id
			local name
			if item_link then
				item_id = tonumber(string.match(item_link, "item:(%d+)"))
				name = GetItemInfo(item_link)
			end
			rec[#rec + 1] = {
				record_kind = "appearance_collected",
				category_id = catId,
				category_name = catNameStr,
				visual_id = visualID,
				source_id = chosenSourceID,
				item_id = item_id,
				name = name,
				item_link = item_link,
			}
			return true
		end

		for catId = 0, 55 do
			if partial then
				break
			end

			local appearances = select(2, pcall(function()
				return C_TransmogCollection.GetCategoryAppearances(catId)
			end))
			if type(appearances) ~= "table" then
			else
				local catName = select(2, pcall(function()
					return C_TransmogCollection.GetCategoryInfo(catId)
				end))
				local catNameStr = type(catName) == "string" and catName or nil

				for _, appearance in ipairs(appearances) do
					if partial then
						break
					end
					local visualID = appearance and appearance.visualID
					if not visualID then
					else
						if appearance.isCollected == false then
						else
							local sources = select(2, pcall(function()
								local fn = C_TransmogCollection.GetAppearanceSources
								if type(fn) ~= "function" then
									return nil
								end
								return fn(visualID)
							end))
							if type(sources) ~= "table" then
							else
								local chosenSourceID
								for _, src in ipairs(sources) do
									if src and src.sourceID and src.isCollected then
										chosenSourceID = src.sourceID
										break
									end
								end
								if not chosenSourceID and appearance.isCollected == true then
									for _, src in ipairs(sources) do
										if src and src.sourceID then
											chosenSourceID = src.sourceID
											break
										end
									end
								end
								if chosenSourceID then
									if not addRow(catId, catNameStr, visualID, chosenSourceID) then
										break
									end
								end
							end
						end
					end
				end
			end
		end

		return rec, partial, partialReason
	end

	local function scanTransmogSets()
		local rec = {}
		if type(C_TransmogSets) ~= "table" or type(C_TransmogSets.GetAllSets) ~= "function" then
			return rec
		end
		local okSets, sets = pcall(function()
			return C_TransmogSets.GetAllSets()
		end)
		if not okSets or type(sets) ~= "table" then
			return rec
		end
		local isCollectedFn = C_TransmogSets.IsSetCollected
		for _, info in ipairs(sets) do
			if type(info) ~= "table" or not info.setID then
			else
				local collected = false
				if type(isCollectedFn) == "function" then
					local okC, c = pcall(isCollectedFn, info.setID)
					collected = okC and c and true or false
				end
				local hid = info.hiddenUnlessCollected or false
				if (not hid) or collected then
					rec[#rec + 1] = {
						id = info.setID,
						name = info.name or "?",
						collected = collected or false,
						ui_order = info.uiOrder,
						label = info.label,
						class_mask = info.classMask,
					}
				end
			end
		end
		return rec
	end

	function AC.Scanners.collections_transmog()
		local envAppear = AC.NewEnvelope(false, nil)
		for _, row in ipairs(scanTransmogSummary()) do
			envAppear.records[#envAppear.records + 1] = row
		end

		local detailRecords, partial, preason = scanTransmogCollectedAppearances(APPEARANCES_CAP)
		for _, row in ipairs(detailRecords) do
			envAppear.records[#envAppear.records + 1] = row
		end

		if partial then
			envAppear.partial = true
			envAppear.partial_reason = preason or "appearances_truncated"
		end

		envAppear.records[#envAppear.records + 1] = {
			record_kind = "_transmog_scan_meta",
			detail_rows_capped_at = APPEARANCES_CAP,
		}

		AC.CommitSection("collections_transmog", envAppear)

		local envSets = AC.NewEnvelope(false, nil)
		envSets.records = scanTransmogSets()
		AC.CommitSection("collections_transmog_sets", envSets)
	end

	AC.RegisterEvent("PLAYER_ALIVE", function()
		if AC.Scanners.collections_transmog then AC.Scanners.collections_transmog() end
	end)
	AC.RegisterEvent("TRANSMOG_COLLECTION_UPDATED", function()
		if AC.Scanners.collections_transmog then
			AC.Debounce(DEBOUNCE_KEY_TRANSMOG, TRANSMOG_DEBOUNCE_SEC, AC.Scanners.collections_transmog)
		end
	end)
	AC.RegisterEvent("TRANSMOG_COLLECTION_LOADED", function()
		if AC.Scanners.collections_transmog then AC.Scanners.collections_transmog() end
	end)
end)
