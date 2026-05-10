--[[
	AzerothDataCollector_GuildBank — SV: AzerothDataCollector_GuildBankDB by_character[guid].guild_bank

	Lonca bankası penceresi açıkken sekme içerikleri okunur; kapalıyken yalnızca meta + partial.
]]
local ADDON_NAME, _unused = ...

local AC = AzerothDataCollector
if type(AC) ~= "table" then
	return
end

local SLOTS_PER_TAB = 98

AC.OnAddonLoaded(ADDON_NAME, function()
	AC.EnsureModuleSavedVariables(ADDON_NAME)

	local function guildBankFrameVisible()
		return GuildBankFrame and GuildBankFrame:IsShown()
	end

	local function scanGuildBankImmediate()
		local env = AC.NewEnvelope(true, "guild_bank_unavailable")

		if not IsInGuild() then
			env.partial_reason = "player_not_in_guild"
			AC.CommitSection("guild_bank", env)
			return
		end

		local guildName = select(1, GetGuildInfo("player")) or "?"
		local numTabsOk, numTabs = pcall(GetNumGuildBankTabs)
		if not numTabsOk or not numTabs or numTabs <= 0 then
			env.partial_reason = "get_num_tabs_failed"
			AC.CommitSection("guild_bank", env)
			return
		end

		env.records[#env.records + 1] = {
			record_kind = "_guild_bank_meta",
			guild_name = guildName,
			num_tabs = numTabs,
			slots_per_tab = SLOTS_PER_TAB,
			frame_open = guildBankFrameVisible() and true or false,
		}

		if not guildBankFrameVisible() then
			env.partial = true
			env.partial_reason = "guild_bank_frame_not_open"
			AC.CommitSection("guild_bank", env)
			return
		end

		env.partial = false
		env.partial_reason = nil

		for tab = 1, numTabs do
			pcall(QueryGuildBankTab, tab)

			local tabLabel
			if GetGuildBankTabInfo then
				local okInfo, name = pcall(GetGuildBankTabInfo, tab)
				if okInfo and type(name) == "string" then
					tabLabel = name
				end
			end

			for slot = 1, SLOTS_PER_TAB do
				local linkOk, link = pcall(GetGuildBankItemLink, tab, slot)
				if not linkOk then
					link = nil
				end

				local qty, locked, filtered, qlty
				local infoOk, _tex, ct, lk, filt, qi = pcall(GetGuildBankItemInfo, tab, slot)
				if infoOk then
					qty = ct
					locked = lk
					filtered = filt
					qlty = qi
				end

				local hasThing = (type(link) == "string" and link ~= "") or (type(qty) == "number" and qty > 0)
				if hasThing then
					local itemId = nil
					if type(link) == "string" then
						itemId = tonumber(link:match("item:(%d+)"))
					end
					env.records[#env.records + 1] = {
						record_kind = "guild_bank_slot",
						tab_index = tab,
						tab_label = tabLabel,
						slot_index = slot,
						item_link = link,
						item_id = itemId,
						quantity = qty,
						locked_client = (locked ~= nil),
						filter_hidden = filtered and true or false,
						quality = qlty,
					}
				end
			end
		end

		AC.CommitSection("guild_bank", env)
	end

	function AC.Scanners.guild_bank()
		scanGuildBankImmediate()
	end

	local function deferredScan()
		C_Timer.After(0.08, scanGuildBankImmediate)
	end

	AC.RegisterEvent("GUILDBANKFRAME_OPENED", deferredScan)
	AC.RegisterEvent("GUILDBANKFRAME_CLOSED", function()
		scanGuildBankImmediate()
	end)
	AC.RegisterEvent("GUILDBANK_UPDATE", deferredScan)
end)
