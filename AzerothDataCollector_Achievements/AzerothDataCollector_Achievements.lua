--[[
	AzerothDataCollector_Achievements — SV: AzerothDataCollector_AchievementsDB
	Completed achievements only (account-wide flag preserved); each row includes criteria[] detail.
	Incomplete achievements are omitted to curb SavedVariables size; a leading `_achievement_totals` row summarizes caps and totals.
	In session: ACHIEVEMENT_EARNED triggers a debounced full scan (event is rare enough to stay fairly fresh).
]]
local ADDON_NAME, _unused = ...

local AC = AzerothDataCollector
if type(AC) ~= "table" then
	return
end

local SAFETY_CAP_ACHIEVEMENTS = 40000
local EARNED_DEBOUNCE_SEC = 3
local DEBOUNCE_KEY_EARNED = "adc_achievements_earned"

AC.OnAddonLoaded(ADDON_NAME, function()
	AC.EnsureModuleSavedVariables(ADDON_NAME)

	local function achievementCriteriaTable(achievementID)
		local t = {}
		local nc = 0
		local ok1, n1 = pcall(GetAchievementNumCriteria, achievementID, true)
		if ok1 and type(n1) == "number" then
			nc = n1
		end
		if nc <= 0 then
			local ok2, n2 = pcall(GetAchievementNumCriteria, achievementID)
			if ok2 and type(n2) == "number" then
				nc = n2
			end
		end
		if nc <= 0 then
			return t
		end
		for cix = 1, nc do
			local ok, critStr, critType, critCompleted, quantity, reqQuantity, _, flags2, assetID, _, criteriaID =
				pcall(GetAchievementCriteriaInfo, achievementID, cix, true)
			if ok and critStr ~= nil then
				t[#t + 1] = {
					criteria_index = cix,
					criteria_id = criteriaID,
					description = critStr,
					criteria_type = critType,
					completed = critCompleted and true or false,
					quantity = quantity,
					required_quantity = reqQuantity,
					asset_id = assetID,
					flags = flags2,
				}
			end
		end
		return t
	end

	function AC.Scanners.achievements()
		local env = AC.NewEnvelope(false, nil)

		env.records[#env.records + 1] = {
			record_kind = "_achievement_totals",
			id = -3,
			name = "_achievement_totals",
			total_points = GetTotalAchievementPoints and GetTotalAchievementPoints() or 0,
			note_completed_only_detail = true,
			safety_cap = SAFETY_CAP_ACHIEVEMENTS,
		}

		local okCats, cats = pcall(function()
			return { GetCategoryList() }
		end)
		if not okCats then
			env.partial = true
			env.partial_reason = "achievement_category_list_failed"
			AC.CommitSection("achievements", env)
			return
		end
		local nStored = 0
		local ACCOUNT_FLAG = ACHIEVEMENT_FLAGS_ACCOUNT or 131072

		local function categoryAchievementTotal(catID)
			local ok, total = pcall(function()
				return GetCategoryNumAchievements(catID, true)
			end)
			if ok and type(total) == "number" and total > 0 then
				return total
			end
			ok, total = pcall(function()
				return GetCategoryNumAchievements(catID, false)
			end)
			if ok and type(total) == "number" and total > 0 then
				return total
			end
			ok, total = pcall(function()
				return GetCategoryNumAchievements(catID)
			end)
			if ok and type(total) == "number" then
				return total
			end
			return 0
		end

		for _, catID in ipairs(cats) do
			if nStored >= SAFETY_CAP_ACHIEVEMENTS then
				break
			end
			local na = categoryAchievementTotal(catID)
			if na > 0 then
				for ix = 1, na do
					if nStored >= SAFETY_CAP_ACHIEVEMENTS then
						break
					end
					local achievementID = GetAchievementInfo(catID, ix)
					if achievementID then
						local _, name, points, completed, month, day, year, _, flags =
							GetAchievementInfo(achievementID)
						if completed then
							local isAccountWide = false
							if type(flags) == "number" then
								isAccountWide = bit.band(flags, ACCOUNT_FLAG) ~= 0
							end
							nStored = nStored + 1
							env.records[#env.records + 1] = {
								record_kind = "achievement_completed",
								id = achievementID,
								category_id = catID,
								name = name or ("achievement_" .. achievementID),
								points = points or 0,
								achievement_scope = isAccountWide and "account_wide" or "character",
								account_wide = isAccountWide and true or false,
								earned_month = month,
								earned_day = day,
								earned_year = year,
								criteria = achievementCriteriaTable(achievementID),
							}
						end
					end
				end
			end
		end

		if nStored >= SAFETY_CAP_ACHIEVEMENTS then
			env.partial = true
			env.partial_reason = env.partial_reason or ("achievement_completed_capped_" .. SAFETY_CAP_ACHIEVEMENTS)
			env.records[#env.records + 1] = {
				record_kind = "_achievements_truncated",
				id = -4,
				name = "_achievements_truncated",
				capped_at = SAFETY_CAP_ACHIEVEMENTS,
			}
		end

		AC.CommitSection("achievements", env)
	end

	AC.RegisterEvent("PLAYER_ALIVE", function()
		if AC.Scanners.achievements then AC.Scanners.achievements() end
	end)
	AC.RegisterEvent("ACHIEVEMENT_EARNED", function()
		if not AC.Scanners.achievements then
			return
		end
		AC.Debounce(DEBOUNCE_KEY_EARNED, EARNED_DEBOUNCE_SEC, AC.Scanners.achievements)
	end)
end)
