--[[
	AzerothDataCollector_Containers — SV: AzerothDataCollector_ContainersDB
	Kök + by_character[guid].containers = envelope | eski characters → by_character otomatik.
]]
local ADDON_NAME, _unused = ...

local AC = AzerothDataCollector
if type(AC) ~= "table" then
	return
end

AC.OnAddonLoaded(ADDON_NAME, function()
	AC.EnsureModuleSavedVariables(ADDON_NAME)
	AC._bankOpened = AC._bankOpened or false

	local function slotRecord(container_kind, bag_id, slot, link)
		if not link then return nil end
		local itemID = tonumber(link:match("item:(%d+)"))
		local name, _, quality, lvl = GetItemInfo(link)
		local count = 1
		local info = C_Container.GetContainerItemInfo(bag_id, slot)
		if info then
			count = info.stackCount or 1
			quality = quality or info.quality
		end
		return {
			id = itemID or 0,
			name = name or "?",
			container_kind = container_kind,
			bag_id = bag_id,
			slot = slot,
			count = count,
			quality = quality,
			item_level = lvl,
			item_link = link,
		}
	end

	local function scanBagRange(env, kind, bagFrom, bagTo, partial_note)
		local any = false
		for bag_id = bagFrom, bagTo do
			local n = C_Container.GetContainerNumSlots(bag_id)
			if n and n > 0 then
				for slot = 1, n do
					local link = C_Container.GetContainerItemLink(bag_id, slot)
					local row = slotRecord(kind, bag_id, slot, link)
					if row then
						env.records[#env.records + 1] = row
						any = true
					end
				end
			end
		end
		return any
	end

	function AC.Scanners.containers()
		local env = AC.NewEnvelope(false, nil)

		env.records[1] = {
			id = -2,
			name = "_container_scan_meta",
			bank_ui_opened_at_least_once = AC._bankOpened or false,
		}

		local commonTop = NUM_BAG_SLOTS and (NUM_BAG_SLOTS + 1) or 5
		for bag_id = 0, commonTop do
			scanBagRange(env, "character_bag", bag_id, bag_id, nil)
		end

		-- Main bank slots when server has cached contents (often visible after login)
		do
			local bc = BANK_CONTAINER or -1
			local n = C_Container.GetContainerNumSlots(bc)
			if n and n > 0 then
				for slot = 1, n do
					local link = C_Container.GetContainerItemLink(bc, slot)
					local row = slotRecord("character_bank_main", bc, slot, link)
					if row then
						env.records[#env.records + 1] = row
					end
				end
			end
		end

		local minB = Enum.BagIndex.CharacterBankTab_1 or 6
		local maxB = Enum.BagIndex.CharacterBankTab_6 or 12
		if AC._bankOpened then
			scanBagRange(env, "character_bank_bag_slot", minB, maxB)
		end

		local wb1 = Enum.BagIndex.AccountBankTab_1 or 13
		local wbN = Enum.BagIndex.AccountBankTab_5 or 17
		scanBagRange(env, "warband_bank_tab", wb1, wbN)

		if GetVoidItemInfo then
			for tab = 1, 2 do
				for slot = 1, 80 do
					local itemID = GetVoidItemInfo(tab, slot)
					if itemID then
						local name = select(1, GetItemInfo(itemID))
						env.records[#env.records + 1] = {
							id = itemID,
							name = name or "?",
							container_kind = "void_storage",
							void_tab = tab,
							slot = slot,
							count = 1,
						}
					end
				end
			end
		end

		pcall(function()
			local bid = REAGENTBANK_CONTAINER
			if not bid then return end
			local nslots = C_Container.GetContainerNumSlots(bid)
			if not nslots or nslots <= 0 then return end
			for slot = 1, nslots do
				local link = C_Container.GetContainerItemLink(bid, slot)
				local row = slotRecord("reagent_bank", bid, slot, link)
				if row then env.records[#env.records + 1] = row end
			end
		end)

		AC.CommitSection("containers", env)
	end

	local function delayedContainers()
		if AC.Scanners.containers then
			C_Timer.After(0.15, AC.Scanners.containers)
		end
	end

	AC.RegisterEvent("BANKFRAME_OPENED", function()
		AC._bankOpened = true
		delayedContainers()
	end)
	AC.RegisterEvent("BANKFRAME_CLOSED", function()
		delayedContainers()
	end)
	AC.RegisterEvent("BAG_UPDATE", function(_, bagID)
		local commonTop = NUM_BAG_SLOTS and (NUM_BAG_SLOTS + 1) or 5
		if bagID >= 0 and bagID <= commonTop then
			AC.Debounce("bags_char", 0.75, delayedContainers)
			return
		end
		local minB = Enum.BagIndex.CharacterBankTab_1 or 6
		local maxB = Enum.BagIndex.CharacterBankTab_6 or 12
		if bagID >= minB and bagID <= maxB and AC._bankOpened then
			AC.Debounce("bags_bank", 0.75, delayedContainers)
			return
		end
		local wb1 = Enum.BagIndex.AccountBankTab_1 or 13
		local wbN = Enum.BagIndex.AccountBankTab_5 or 17
		if bagID >= wb1 and bagID <= wbN then
			AC.Debounce("bags_wb", 0.75, delayedContainers)
		end
	end)
	AC.RegisterEvent("PLAYER_ALIVE", function()
		AC.Debounce("bags_login", 1.25, delayedContainers)
	end)
end)
