--[[
	AzerothDataCollector_Achievements — SV: AzerothDataCollector_AchievementsDB
	Tamamlanmış başarılar: hem account-wide hem karakter başına (achievement_scope ile ayrım).
	Eski kod yalnızca non-account kaydediyordu; yeni karakterde liste boş kalıyordu.

	Snapshot by_character ile saklanır; hesap bazlı başarı anahtarı hâlâ oyuncunun dosyasında
	toplanır çünkü export her karakter bağlamında güncellenir (diğer modüllerle aynı model).
]]
local ADDON_NAME, _unused = ...

local AC = AzerothDataCollector
if type(AC) ~= "table" then
	return
end

AC.OnAddonLoaded(ADDON_NAME, function()
	AC.EnsureModuleSavedVariables(ADDON_NAME)
	function AC.Scanners.achievements()
		local env = AC.NewEnvelope(false, nil)

		--- Bir hesaptaki tamamlanan kayıtlar çok fazla olabilir; yükle süresini sınırla
		local CAP = 9000

		env.records[#env.records + 1] = {
			id = -3,
			name = "_achievement_totals",
			total_points = GetTotalAchievementPoints and GetTotalAchievementPoints() or 0,
			record_format = "each_row_has achievement_scope account_wide_or_character_and account_wide_boolean",
		}

		local okCats, cats = pcall(function() return { GetCategoryList() } end)
		if not okCats then
			env.partial = true
			env.partial_reason = "achievement_category_list_failed"
			AC.CommitSection("achievements", env)
			return
		end
		local nStored = 0
		local ACCOUNT_FLAG = ACHIEVEMENT_FLAGS_ACCOUNT or 131072

		for _, catID in ipairs(cats) do
			local na = GetCategoryNumAchievements(catID)
			if na and na > 0 then
				for ix = 1, na do
					local achievementID = GetAchievementInfo(catID, ix)
					if achievementID then
						local _, name, points, completed, month, day, year, _, flags =
							GetAchievementInfo(achievementID)
						local isAccountWide = false
						if type(flags) == "number" then
							isAccountWide = bit.band(flags, ACCOUNT_FLAG) ~= 0
						end

						if completed and nStored < CAP then
							nStored = nStored + 1
							env.records[#env.records + 1] = {
								id = achievementID,
								name = name or ("achievement_" .. achievementID),
								points = points or 0,
								achievement_scope = isAccountWide and "account_wide" or "character",
								account_wide = isAccountWide and true or false,
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
			env.partial = true
			env.partial_reason = env.partial_reason or "achievement_list_capped"
			env.records[#env.records + 1] = { id = -4, name = "_achievements_truncated", capped_at = CAP }
		end

		AC.CommitSection("achievements", env)
	end

	AC.RegisterEvent("PLAYER_ALIVE", function()
		if AC.Scanners.achievements then AC.Scanners.achievements() end
	end)
end)
