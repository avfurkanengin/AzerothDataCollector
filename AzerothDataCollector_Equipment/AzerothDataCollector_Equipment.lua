--[[
	AzerothDataCollector_Equipment — SV: AzerothDataCollector_EquipmentDB
	Slot özeti + mücevher yuvaları (C_Item) + istatistik tablosu; silah görünmez büyü varsa Inventory API.
]]
local ADDON_NAME, _unused = ...

local AC = AzerothDataCollector
if type(AC) ~= "table" then
	return
end

local NUM_SLOTS = 30

AC.OnAddonLoaded(ADDON_NAME, function()
	AC.EnsureModuleSavedVariables(ADDON_NAME)

	local function collectGemsSockets(itemLoc, item_link)
		local sockets = {}
		if not item_link or not C_Item.GetItemGem then
			return sockets
		end
		local hasLoc = itemLoc and C_Item.DoesItemExist and C_Item.DoesItemExist(itemLoc)

		for ix = 1, 16 do
			local okg, gn, gl = pcall(C_Item.GetItemGem, item_link, ix)
			if not okg or (gl == nil and gn == nil) then
				break
			end
			local gid = nil
			if hasLoc and C_Item.GetItemGemID then
				local oki, gidv = pcall(C_Item.GetItemGemID, itemLoc, ix)
				if oki and type(gidv) == "number" then
					gid = gidv
				end
			end
			local gem_item_id = nil
			if type(gl) == "string" then
				gem_item_id = tonumber(gl:match("item:(%d+)"))
			end
			sockets[#sockets + 1] = {
				socket_index = ix,
				gem_name = gn,
				gem_link = gl,
				gem_item_id = gem_item_id or gid,
			}
		end
		return sockets
	end

	local function collectStatsLimited(item_link, maxpairs)
		if not item_link or not C_Item.GetItemStats then
			return nil
		end
		local ok, st = pcall(C_Item.GetItemStats, item_link)
		if not ok or type(st) ~= "table" then
			return nil
		end
		local out = {}
		local n = 0
		for k, v in pairs(st) do
			n = n + 1
			if n > maxpairs then
				out["_truncated"] = true
				break
			end
			out[tostring(k)] = v
		end
		return out
	end

	local function itemRow(slot)
		local link = GetInventoryItemLink("player", slot)
		if not link then
			return nil
		end
		local id = tonumber(link:match("item:(%d+)"))
		local name, _, quality, ilevel = GetItemInfo(link)
		local row = {
			id = id or 0,
			name = name or "?",
			slot = slot,
			quality = quality,
			item_level = ilevel,
			item_link = link,
			gems = {},
			stats = collectStatsLimited(link, 40),
			temp_enchant_spell_id = nil,
		}

		local enchantId = nil
		if GetInventoryItemEnchantment then
			local okE, eh = pcall(GetInventoryItemEnchantment, slot)
			if okE and eh then
				enchantId = eh
			end
		end
		row.temp_enchant_spell_id = enchantId

		if ItemLocation and ItemLocation.CreateFromEquipmentSlot then
			local okL, loc = pcall(function()
				return ItemLocation:CreateFromEquipmentSlot(slot)
			end)
			if okL and loc and (not C_Item.DoesItemExist or C_Item.DoesItemExist(loc)) then
				row.gems = collectGemsSockets(loc, link)
			end
		end

		return row
	end

	function AC.Scanners.equipment()
		local env = AC.NewEnvelope(false, nil)
		for s = 1, NUM_SLOTS do
			local ok, row = pcall(itemRow, s)
			if ok and row then
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
