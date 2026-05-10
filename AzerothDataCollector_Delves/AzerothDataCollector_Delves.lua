--[[
	AzerothDataCollector_Delves — SV: AzerothDataCollector_DelvesDB
	Root DB fields plus by_character[guid].delves envelope; legacy characters migrated via AC.EnsureModuleSavedVariables.
]]
local ADDON_NAME, _unused = ...

local AC = AzerothDataCollector
if type(AC) ~= "table" then
	return
end

AC.OnAddonLoaded(ADDON_NAME, function()
	AC.EnsureModuleSavedVariables(ADDON_NAME)
	function AC.Scanners.delves()
		local env = AC.NewEnvelope(true, "delve_api_optional_per_patch")

		local used = false

		if C_Delves and C_Delves.GetTrackedDelveTier then
			local ok, tier = pcall(function() return C_Delves.GetTrackedDelveTier() end)
			if ok and tier ~= nil then
				used = true
				env.records[#env.records + 1] = {
					id = 1,
					name = "tracked_delve_tier",
					tier = tier,
				}
			end
		end

		if used then
			env.partial = false
			env.partial_reason = nil
		end

		AC.CommitSection("delves", env)
	end

	AC.RegisterEvent("PLAYER_ALIVE", function()
		if AC.Scanners.delves then AC.Scanners.delves() end
	end)
end)
