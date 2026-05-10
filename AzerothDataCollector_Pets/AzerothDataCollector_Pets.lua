--[[ AzerothDataCollector_Pets — SV: AzerothDataCollector_PetsDB — by_character[guid].collections_pets
	First COMPANION_UPDATE bootstrap runs from AzerothDataCollector_Mounts.lua (duplicate events avoided there).]]
local ADDON_NAME, _unused = ...

local AC = AzerothDataCollector
if type(AC) ~= "table" then
	return
end

AC.OnAddonLoaded(ADDON_NAME, function()
	AC.EnsureModuleSavedVariables(ADDON_NAME)

	local function scanPetsOwned()
		local rec = {}
		local _, owned = C_PetJournal.GetNumPets()
		for i = 1, owned or 0 do
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

	function AC.Scanners.collections_pets()
		local env = AC.NewEnvelope(false, nil)
		env.records = scanPetsOwned()
		AC.CommitSection("collections_pets", env)
	end

	AC.RegisterEvent("PLAYER_ALIVE", function()
		if AC.Scanners.collections_pets then AC.Scanners.collections_pets() end
	end)
	AC.RegisterEvent("COMPANION_LEARNED", function()
		if AC.Scanners.collections_pets then AC.Scanners.collections_pets() end
	end)
end)
