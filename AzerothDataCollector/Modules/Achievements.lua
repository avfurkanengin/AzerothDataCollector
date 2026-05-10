local _, AC = ...

AC.Scanners = AC.Scanners or {}

function AC.Scanners.achievements()
	local env = AC.NewEnvelope(false, nil)

	local CAP = 3000

	env.records[#env.records + 1] = {
		id = -3,
		name = "_achievement_totals",
		total_points = GetTotalAchievementPoints and GetTotalAchievementPoints() or 0,
	}

	local okCats, cats = pcall(function() return { GetCategoryList() } end)
	if not okCats then
		env.partial = true
		env.partial_reason = "achievement_category_list_failed"
		AC.CommitSection("achievements", env)
		return
	end
	local nStored = 0

	for _, catID in ipairs(cats) do
		local na = GetCategoryNumAchievements(catID)
		if na and na > 0 then
			for ix = 1, na do
				local achievementID = GetAchievementInfo(catID, ix)
				if achievementID then
					local _, name, points, completed, month, day, year, _, flags =
						GetAchievementInfo(achievementID)
					local ACCOUNT_FLAG = ACHIEVEMENT_FLAGS_ACCOUNT or 131072 -- 0x20000 fallback
					local isAccountWide = flags and bit.band(flags, ACCOUNT_FLAG) ~= 0 or false
						or false

					if completed and not isAccountWide and nStored < CAP then
						nStored = nStored + 1
						env.records[#env.records + 1] = {
							id = achievementID,
							name = name or ("achievement_" .. achievementID),
							points = points or 0,
							earned_month = month,
							earned_day = day,
							earned_year = year,
						}
					end
				end
			end
		end
	end

	if nStored >= CAP then
		env.records[#env.records + 1] = { id = -4, name = "_achievements_truncated", capped_at = CAP }
	end

	AC.CommitSection("achievements", env)
end

AC.RegisterEvent("PLAYER_ALIVE", function()
	if AC.Scanners.achievements then AC.Scanners.achievements() end
end)
