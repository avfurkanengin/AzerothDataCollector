--[[
	AzerothDataCollector_Auctions — SV: AzerothDataCollector_AuctionsDB
	Root DB fields plus by_character[guid].auctions envelope; legacy characters migrated via AC.EnsureModuleSavedVariables.
	Auction house events merged under one debounced scan.
]]
local ADDON_NAME, _unused = ...

local AC = AzerothDataCollector
if type(AC) ~= "table" then
	return
end

local AUCTION_DEBOUNCE_SEC = 1.25
local DEBOUNCE_KEY_AUCTION = "adc_auctions"

AC.OnAddonLoaded(ADDON_NAME, function()
	AC.EnsureModuleSavedVariables(ADDON_NAME)

	local function debouncedAuctions()
		local fn = AC.Scanners.auctions
		if not fn then
			return
		end
		AC.Debounce(DEBOUNCE_KEY_AUCTION, AUCTION_DEBOUNCE_SEC, fn)
	end

	function AC.Scanners.auctions()
		local env = AC.NewEnvelope(true, "auction_house_not_recently_loaded")

		local used = false
		if C_AuctionHouse and C_AuctionHouse.GetNumOwnedAuctions then
			local n = C_AuctionHouse.GetNumOwnedAuctions()
			for i = 1, math.min(n, 200) do
				local info = C_AuctionHouse.GetOwnedAuctionInfo(i)
				if info and info.itemKey and info.itemKey.itemID then
					used = true
					env.records[#env.records + 1] = {
						id = info.auctionID or i,
						name = "_owned_auction",
						item_id = info.itemKey.itemID,
						quantity = info.quantity,
						time_left_seconds = info.timeLeftSeconds,
						bid_amount = info.bidAmount,
						buyout_amount = info.buyoutAmount,
						raw_status_field = info.status,
					}
				end
			end

			local b = C_AuctionHouse.GetNumBids and C_AuctionHouse.GetNumBids() or 0
			for i = 1, math.min(b, 200) do
				local info = C_AuctionHouse.GetBidInfo(i)
				if info and info.itemKey and info.itemKey.itemID then
					used = true
					env.records[#env.records + 1] = {
						id = ("bid_" .. i),
						name = "_auction_bid",
						item_id = info.itemKey.itemID,
						quantity = info.quantity,
					}
				end
			end
		end

		if used then env.partial = false env.partial_reason = nil end

		AC.CommitSection("auctions", env)
	end

	local auctionEventsRetail = {
		"AUCTION_HOUSE_SHOW",
		"AUCTION_HOUSE_CLOSED",
		"OWNED_AUCTIONS_UPDATED",
		"AUCTION_HOUSE_AUCTION_CREATED",
		"BIDS_UPDATED",
	}

	for _, ev in ipairs(auctionEventsRetail) do
		AC.RegisterEvent(ev, debouncedAuctions)
	end

	AC.RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", function(_, paneType)
		if Enum and Enum.PlayerInteractionType and paneType == Enum.PlayerInteractionType.Auctioneer then
			debouncedAuctions()
		end
	end)
end)
