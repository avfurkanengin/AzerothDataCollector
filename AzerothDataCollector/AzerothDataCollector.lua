--[[
  AzerothDataCollector — main entry Lua (basename matches addon folder / .toc).
  SavedVariables: AzerothDataCollectorDB — schema_version + client only; per-character data lives in module SV files under by_character.
]]

local ADDON_NAME, AC = ...

_G.AzerothDataCollector = AC

-- Reset each main-addon load before module addons register their scanners.
AC.Scanners = {}

AC.FULL_SCAN_SEQUENCE = {
	"meta",
	"wallet",
	"currencies",
	"reputations",
	"talents",
	"stats",
	"equipment",
	"collections_mounts",
	"collections_pets",
	"collections_transmog",
	"containers",
	"guild_bank",
	"quests",
	"achievements",
	"professions",
	"mail",
	"auctions",
	"agenda",
	"spells",
	"garrison",
	"delves",
}

function AC.RunFullScan(reason)
	if WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE then
		print("|cffff5555[ADC]|r Retail only. Skipping snapshot.")
		return
	end
	if not UnitGUID("player") then return end

	AC.InitRoot()
	AC.UpdateClientMeta()

	for _, key in ipairs(AC.FULL_SCAN_SEQUENCE) do
		local fn = AC.Scanners[key]
		if fn then
			local ok, err = pcall(fn)
			if not ok then
				print("|cffff5555[ADC]|r Scan error in " .. tostring(key) .. ": " .. tostring(err))
			end
		end
	end

	-- Quiet automatic scans (no spam); optional confirmation on slash-triggered scans or ADC_DEBUG.
	if reason == "slash_command" or _G.ADC_DEBUG then
		print("|cff33ff99[ADC]|r Full snapshot updated (" .. tostring(reason) .. ").")
	end
end

--- GUID can lag a few seconds after entering world; retry quietly (no slash required).
local function scheduleAutoFullScan(reason)
	if RequestTimePlayed then
		pcall(RequestTimePlayed)
	end
	local debounceDelay = 2.0
	local retryInterval = 0.4
	local maxAttempts = 40

	AC.Debounce("adc_full_scan", debounceDelay, function()
		local attempt = 0
		local function tryScan()
			attempt = attempt + 1
			if WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE then
				return
			end
			if UnitGUID("player") then
				AC.RunFullScan(reason)
				return
			end
			if attempt >= maxAttempts then
				return
			end
			C_Timer.After(retryInterval, tryScan)
		end
		tryScan()
	end)
end

local function slashRunFullScan(reason)
	local AD = _G.AzerothDataCollector
	if type(AD) ~= "table" or type(AD.RunFullScan) ~= "function" then
		print("|cffff5555[ADC]|r Addon not ready yet.")
		return
	end
	-- Slash path retries until GUID exists so RunFullScan can show a clear message if needed.
	reason = reason or "slash_command"
	if UnitGUID("player") then
		AD.RunFullScan(reason)
		return
	end
	local a = 0
	local function try()
		a = a + 1
		if UnitGUID("player") then
			AD.RunFullScan(reason)
			return
		end
		if a >= 75 then
			print("|cffff5555[ADC]|r Player not ready yet; try again in a few seconds.")
			return
		end
		C_Timer.After(0.35, try)
	end
	try()
end

SLASH_ADC_AZEROTH_DATA1 = "/adc"
SLASH_ADC_AZEROTH_DATA2 = "/azerothdata"
SLASH_ADC_AZEROTH_DATA3 = "/azdatacollect"
SLASH_ADC_AZEROTH_DATA4 = "/azadc"
SlashCmdList["ADC_AZEROTH_DATA"] = function()
	slashRunFullScan("slash_command")
end

SLASH_ADC_LEGACY_ACC1 = "/acc"
SlashCmdList["ADC_LEGACY_ACC"] = function()
	slashRunFullScan("slash_command")
end

AC.OnAddonLoaded(ADDON_NAME, function()
	if WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE then
		print("|cffff5555[ADC]|r Azeroth Data Collector requires retail (mainline).")
		return
	end
	AC.InitRoot()
end)

AC.OnPlayerLogin(function()
	scheduleAutoFullScan("player_login")
end)

local pewFrame = CreateFrame("Frame")
pewFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
pewFrame:SetScript("OnEvent", function()
	scheduleAutoFullScan("player_entering_world")
end)
