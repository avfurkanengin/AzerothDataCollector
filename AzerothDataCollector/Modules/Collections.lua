local _, AC = ...

AC.Scanners = AC.Scanners or {}

local function scanMounts()
	local rec = {}
	local ok, ids = pcall(function()
		return C_MountJournal.GetMountIDs()
	end)
	if not ok or not ids then return rec end
	for _, mountID in ipairs(ids) do
		local ok, name, spellID, _, _, source, _, _, _, _, _, isCollected = pcall(function()
			return C_MountJournal.GetMountInfoByID(mountID)
		end)
		if ok and isCollected then
			rec[#rec + 1] = {
				id = mountID,
				name = name or ("mount_" .. mountID),
				spell_id = spellID,
				source_type = source,
			}
		end
	end
	return rec
end

local function scanPetsOwned()
	local rec = {}
	local numTotal, owned = C_PetJournal.GetNumPets()
	for i = 1, owned do
		local petID = C_PetJournal.GetPetInfoByIndex(i)
		if petID then
			local info = C_PetJournal.GetPetInfoTableByPetID(petID)
			if info then
				rec[#rec + 1] = {
					id = info.speciesID or 0,
					name = info.name or "?",
					pet_guid = petID,
					level = info.level,
					breed_quality = info.breedQuality,
					custom_name = info.customName,
				}
			end
		end
	end
	return rec
end

local function scanTransmogCats()
	local rec = {}
	if not C_TransmogCollection.GetCategoryCollectedCount then
		return rec
	end
	for i = 0, 55 do
		local ok, nm = pcall(function() return C_TransmogCollection.GetCategoryInfo(i) end)
		if ok and nm then
			rec[#rec + 1] = {
				id = i,
				name = nm or ("appearance_cat_" .. i),
				collected = C_TransmogCollection.GetCategoryCollectedCount(i) or 0,
				total = C_TransmogCollection.GetCategoryTotal(i) or 0,
			}
		end
	end
	return rec
end

local function scanTransmogSets()
	local rec = {}
	if not C_TransmogSets.GetAllSets then return rec end
	local sets = C_TransmogSets.GetAllSets()
	if not sets then return rec end
	for _, info in ipairs(sets) do
		local collected = C_TransmogSets.IsSetCollected(info.setID)
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
	return rec
end

function AC.Scanners.collections_all()
	local m = AC.NewEnvelope(false, nil)
	m.records = scanMounts()
	AC.CommitSection("collections_mounts", m)

	local p = AC.NewEnvelope(false, nil)
	p.records = scanPetsOwned()
	AC.CommitSection("collections_pets", p)

	local t = AC.NewEnvelope(false, nil)
	t.records = scanTransmogCats()
	AC.CommitSection("collections_transmog", t)

	local s = AC.NewEnvelope(false, nil)
	s.records = scanTransmogSets()
	AC.CommitSection("collections_transmog_sets", s)
end

AC.RegisterEvent("PLAYER_ALIVE", function()
	if AC.Scanners.collections_all then AC.Scanners.collections_all() end
end)
AC.RegisterEvent("COMPANION_LEARNED", function()
	if AC.Scanners.collections_all then AC.Scanners.collections_all() end
end)
AC.RegisterEvent("NEW_MOUNT_ADDED", function()
	if AC.Scanners.collections_all then AC.Scanners.collections_all() end
end)
AC.RegisterEvent("TRANSMOG_COLLECTION_UPDATED", function()
	if AC.Scanners.collections_all then AC.Scanners.collections_all() end
end)
AC.RegisterEvent("TRANSMOG_COLLECTION_LOADED", function()
	if AC.Scanners.collections_all then AC.Scanners.collections_all() end
end)
