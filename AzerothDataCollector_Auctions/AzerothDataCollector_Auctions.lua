--[[ AzerothDataCollector_Auctions: bağımsız addon (kendi .toc + bu .lua) ]] 
local ADDON_NAME, _unused = ...

local AC = AzerothDataCollector
if type(AC) ~= "table" then
	return
end

AC.OnAddonLoaded(ADDON_NAME, function()
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

	AC.RegisterEvent("AUCTION_HOUSE_SHOW", function()
		if AC.Scanners.auctions then AC.Scanners.auctions() end
	end)
end)
