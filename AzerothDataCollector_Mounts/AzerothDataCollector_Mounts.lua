--[[ AzerothDataCollector_Mounts — SV: AzerothDataCollector_MountsDB — by_character[guid].collections_mounts ]]
local ADDON_NAME, _unused = ...

local AC = AzerothDataCollector
if type(AC) ~= "table" then
	return
end

AC.OnAddonLoaded(ADDON_NAME, function()
	AC.EnsureModuleSavedVariables(ADDON_NAME)

	local function scanMounts()
		local rec = {}
		local ok, ids = pcall(function()
			return C_MountJournal.GetMountIDs()
		end)
		if not ok or not ids then return rec end
		for _, mountID in ipairs(ids) do
			local okm, name, spellID, _, _, source, _, _, _, _, _, isCollected = pcall(function()
				return C_MountJournal.GetMountInfoByID(mountID)
			end)
			if okm and isCollected then
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

	function AC.Scanners.collections_mounts()
		local env = AC.NewEnvelope(false, nil)
		env.records = scanMounts()
		AC.CommitSection("collections_mounts", env)
	end

	AC.RegisterEvent("PLAYER_ALIVE", function()
		if AC.Scanners.collections_mounts then AC.Scanners.collections_mounts() end
	end)
	AC.RegisterEvent("NEW_MOUNT_ADDED", function()
		if AC.Scanners.collections_mounts then AC.Scanners.collections_mounts() end
	end)
end)
