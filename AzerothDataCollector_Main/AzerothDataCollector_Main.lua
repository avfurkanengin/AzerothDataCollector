--[[
  AzerothDataCollector_Main — entry .lua (klasör / .toc ile aynı taban ad).
  SavedVariables: AzerothDataCollectorDB
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
	"collections_all",
	"containers",
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

	if reason then
		print("|cff33ff99[ADC]|r Full snapshot updated (" .. reason .. ").")
	end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventFrame:SetScript("OnEvent", function(_, evt, arg1)
	if evt == "ADDON_LOADED" and arg1 == ADDON_NAME then
		if WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE then
			print("|cffff5555[ADC]|r Azeroth Data Collector requires retail (mainline).")
			return
		end
		AC.InitRoot()
	end
	if evt == "PLAYER_ENTERING_WORLD" then
		if RequestTimePlayed then
			pcall(RequestTimePlayed)
		end
		C_Timer.After(2.5, function()
			AC.RunFullScan("player_entering_world")
		end)
	end
end)

SLASH_AZEROTHDATACOLLECTOR1 = "/adc"
SLASH_AZEROTHDATACOLLECTOR2 = "/azerothdata"
SlashCmdList["AZEROTHDATACOLLECTOR"] = function()
	AC.RunFullScan("slash_command")
end

SLASH_ADCLEGACY_ACC1 = "/acc"
SlashCmdList["ADCLEGACY_ACC"] = function()
	AC.RunFullScan("slash_command")
end
