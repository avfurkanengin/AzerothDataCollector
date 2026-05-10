--[[
	AzerothDataCollector_Equipment — SV: AzerothDataCollector_EquipmentDB
	Kök + by_character[guid].equipment = envelope | eski characters → by_character.
]]
local ADDON_NAME, _unused = ...

local AC = AzerothDataCollector
if type(AC) ~= "table" then
	return
end

AC.OnAddonLoaded(ADDON_NAME, function()
	AC.EnsureModuleSavedVariables(ADDON_NAME)
	local NUM_SLOTS = 30

	local function itemRow(slot)
		local link = GetInventoryItemLink("player", slot)
		if not link then
			return nil
		end
		local id = tonumber(link:match("item:(%d+)"))
		local name, _, quality, ilevel = GetItemInfo(link)
		return {
			id = id or 0,
			name = name or "?",
			slot = slot,
			quality = quality,
			item_level = ilevel,
			item_link = link,
		}
	end

	function AC.Scanners.equipment()
		local env = AC.NewEnvelope(false, nil)
		for slot = 1, NUM_SLOTS do
			local row = itemRow(slot)
			if row then
				env.records[#env.records + 1] = row
			end
		end
		local o, e = GetAverageItemLevel()
		env.records[#env.records + 1] = {
			id = -1,
			name = "average_ilvl_summary",
			ilvl_overall = o or 0,
			ilvl_equipped = e or 0,
		}
		AC.CommitSection("equipment", env)
	end

	AC.RegisterEvent("PLAYER_EQUIPMENT_UPDATED", function()
		if AC.Scanners.equipment then AC.Scanners.equipment() end
	end)
	AC.RegisterEvent("PLAYER_AVG_ITEM_LEVEL_UPDATE", function()
		if AC.Scanners.equipment then AC.Scanners.equipment() end
	end)
	AC.RegisterEvent("PLAYER_ALIVE", function()
		if AC.Scanners.equipment then AC.Scanners.equipment() end
	end)
end)
