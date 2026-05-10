local _, AC = ...

AC.Scanners = AC.Scanners or {}

function AC.Scanners.garrison()
	local env = AC.NewEnvelope(true, "garrison_legacy_maybe_empty")

	if C_Garrison and C_Garrison.GetLandingPageGarrisonType then
		env.partial = false
		env.partial_reason = nil
		local t = C_Garrison.GetLandingPageGarrisonType()
		env.records[#env.records + 1] = {
			id = tonumber(t) or 0,
			name = "landing_page_garrison_type",
			raw_type = tostring(t),
		}
	elseif C_Garrison and C_Garrison.GetGarrisonFollowerAbilities then
		env.partial = false
		env.records[#env.records + 1] = {
			id = 0,
			name = "garrison_api_present_but_unscanned",
		}
	end

	AC.CommitSection("garrison", env)
end

AC.RegisterEvent("PLAYER_ALIVE", function()
	if AC.Scanners.garrison then AC.Scanners.garrison() end
end)
