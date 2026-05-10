--[[
	AzerothDataCollector_Quests — SV: AzerothDataCollector_QuestsDB
	Kök + by_character[guid].quests = envelope | eski characters → by_character.
]]
local ADDON_NAME, _unused = ...

local AC = AzerothDataCollector
if type(AC) ~= "table" then
	return
end

AC.OnAddonLoaded(ADDON_NAME, function()
	AC.EnsureModuleSavedVariables(ADDON_NAME)
	local function push(env, row)
		env.records[#env.records + 1] = row
	end

	function AC.Scanners.quests()
		local env = AC.NewEnvelope(false, nil)

		local n = C_QuestLog.GetNumQuestLogEntries()

		for idx = 1, n do
			local info = C_QuestLog.GetInfo(idx)
			if info and not info.isHeader then
				local qid = info.questID
				local tag = qid and C_QuestLog.GetQuestTagInfo(qid)
				push(env, {
					id = qid or 0,
					name = info.title or "?",
					quest_log_index = idx,
					level = info.level or 0,
					is_daily = info.frequency == Enum.QuestFrequency.Daily or false,
					is_weekly = info.frequency == Enum.QuestFrequency.Weekly or false,
					is_complete = info.isComplete or info.isCompleted or false,
					is_story = info.isStory or false,
					is_hidden = info.isHidden or false,
					is_TASK = info.isTask or false,
					is_ACCOUNT = info.accountCompleted or nil,
					suggested_group = info.suggestedGroup or 0,
					tag_id = tag and tag.tagID or nil,
					object_text = "", -- omit heavy objective strings unless needed later
				})
			end
		end

		do
			local ids = {}
			if C_QuestLog.GetAllCompletedQuestIDs then
				ids = C_QuestLog.GetAllCompletedQuestIDs() or {}
			elseif GetQuestsCompleted then
				ids = GetQuestsCompleted() or {}
			end
			local count = 0
			local function ingestQuestId(questId)
				if not questId then return end
				count = count + 1
				if count <= 2000 then
					push(env, {
						id = questId,
						name = C_QuestLog.GetTitleForQuestID(questId) or ("completed_quest_" .. questId),
						quest_flag = "completed_historical",
					})
				end
			end
			if #ids > 0 then
				for _, questId in ipairs(ids) do
					ingestQuestId(questId)
				end
			else
				for questId, done in pairs(ids) do
					if done then
						local qn = type(questId) == "number" and questId or tonumber(questId)
						ingestQuestId(qn)
					end
				end
			end
			if count > 2000 then
				env.records[#env.records + 1] = {
					id = -9,
					name = "_quests_completed_truncated_note",
					value = count,
				}
			end
		end

		AC.CommitSection("quests", env)
	end

	AC.RegisterEvent("PLAYER_ALIVE", function()
		if AC.Scanners.quests then AC.Scanners.quests() end
	end)
	AC.RegisterEvent("QUEST_LOG_UPDATE", function()
		if AC.Scanners.quests then AC.Scanners.quests() end
	end)
	AC.RegisterEvent("UNIT_QUEST_LOG_CHANGED", function()
		if AC.Scanners.quests then AC.Scanners.quests() end
	end)
end)
