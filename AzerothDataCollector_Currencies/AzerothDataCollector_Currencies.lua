--[[
	AzerothDataCollector_Currencies — SV: AzerothDataCollector_CurrenciesDB
	Root DB fields plus by_character[guid].currencies envelope; legacy characters migrated via AC.EnsureModuleSavedVariables.
	CURRENCY_DISPLAY_UPDATE and transfer log churn debounced to avoid hammering SavedVariables.
]]
local ADDON_NAME, _unused = ...

local AC = AzerothDataCollector
if type(AC) ~= "table" then
	return
end

local CURRENCY_DEBOUNCE_SEC = 3
local DEBOUNCE_KEY_DISPLAY = "adc_currencies_display"
local DEBOUNCE_KEY_TRANSFER = "adc_currencies_transfer"

local function debouncedCurrencyScan(key)
	local fn = AC.Scanners.currencies
	if not fn then
		return
	end
	AC.Debounce(key, CURRENCY_DEBOUNCE_SEC, fn)
end

AC.OnAddonLoaded(ADDON_NAME, function()
	AC.EnsureModuleSavedVariables(ADDON_NAME)
	local headersState = {}
	local headerCounter = 0

	local function expandHeadersRetail()
		headerCounter = 0
		wipe(headersState)
		for i = C_CurrencyInfo.GetCurrencyListSize(), 1, -1 do
			local info = C_CurrencyInfo.GetCurrencyListInfo(i)
			if info.isHeader then
				headerCounter = headerCounter + 1
				if not info.isHeaderExpanded then
					C_CurrencyInfo.ExpandCurrencyList(i, 1)
					headersState[headerCounter] = true
				end
			end
		end
	end

	local function collapseHeadersRetail()
		headerCounter = 0
		for i = C_CurrencyInfo.GetCurrencyListSize(), 1, -1 do
			local info = C_CurrencyInfo.GetCurrencyListInfo(i)
			if info.isHeader then
				headerCounter = headerCounter + 1
				if headersState[headerCounter] then
					C_CurrencyInfo.ExpandCurrencyList(i, 0)
				end
			end
		end
		wipe(headersState)
	end

	function AC.Scanners.currencies()
		local env = AC.NewEnvelope(false, nil)
		local category = ""

		expandHeadersRetail()

		for i = 1, C_CurrencyInfo.GetCurrencyListSize() do
			local li = C_CurrencyInfo.GetCurrencyListInfo(i)
			if li.isHeader then
				category = li.name or ""
			else
				local link = C_CurrencyInfo.GetCurrencyListLink(i)
				local currencyID = link and C_CurrencyInfo.GetCurrencyIDFromLink(link) or nil
				local details = currencyID and C_CurrencyInfo.GetCurrencyInfo(currencyID) or nil
				local qty = details and details.quantity or (li.quantity or 0)
				env.records[#env.records + 1] = {
					id = currencyID or 0,
					name = (details and details.name) or li.name or "?",
					quantity = qty,
					category_header = category,
					max_quantity = details and details.maxQuantity or nil,
					quantity_earned_this_week = details and details.quantityEarnedThisWeek or nil,
					max_weekly_quantity = details and details.maxWeeklyQuantity or nil,
					is_account_wide = details and details.isAccountTransferable or nil,
				}
			end
		end

		collapseHeadersRetail()
		AC.CommitSection("currencies", env)
	end

	AC.RegisterEvent("PLAYER_ALIVE", function()
		if AC.Scanners.currencies then AC.Scanners.currencies() end
	end)
	AC.RegisterEvent("CURRENCY_DISPLAY_UPDATE", function()
		debouncedCurrencyScan(DEBOUNCE_KEY_DISPLAY)
	end)
	AC.RegisterEvent("CURRENCY_TRANSFER_LOG_UPDATE", function()
		debouncedCurrencyScan(DEBOUNCE_KEY_TRANSFER)
	end)
	AC.RegisterEvent("CHAT_MSG_SYSTEM", function(_, msg)
		if msg == ITEM_REFUND_MSG and AC.Scanners.currencies then
			AC.Scanners.currencies()
		end
	end)
end)
