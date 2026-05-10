--[[
	AzerothDataCollector_Quests — SV: AzerothDataCollector_QuestsDB — by_character[guid].quests envelope.
	Active quest log: objectives via C_QuestLog.GetQuestObjectives.
	Completed quests: IDs in completed_quest_ids_chunk rows (CHUNK_SIZE); ABSOLUTE_MAX caps huge accounts.
	Events: QUEST_LOG_UPDATE, UNIT_QUEST_LOG_CHANGED, WORLD_QUEST_COMPLETED_BY_SPELL, COVENANT_CALLINGS_UPDATED.
	Active quests commit eagerly; completed list coalesced via SV cache + debounce.
]]
local ADDON_NAME, _unused = ...

local AC = AzerothDataCollector
if type(AC) ~= "table" then
	return
end

local CHUNK_SIZE = 600
local ABSOLUTE_MAX_COMPLETED_IDS = 50000
local MAX_OBJECTIVE_TEXT_LEN = 2000
local COMPLETED_DEBOUNCE_SEC = 12
local DEBOUNCE_KEY_COMPLETED = "adc_quests_completed"

AC.OnAddonLoaded(ADDON_NAME, function()
	AC.EnsureModuleSavedVariables(ADDON_NAME)
	local function push(env, row)
		env.records[#env.records + 1] = row
	end

	local function trimText(s)
		if type(s) ~= "string" then
			return s
		end
		if #s <= MAX_OBJECTIVE_TEXT_LEN then
			return s
		end
		return string.sub(s, 1, MAX_OBJECTIVE_TEXT_LEN) .. "...[trunc]"
	end

	local function objectivesForQuest(qid)
		if not qid or not C_QuestLog.GetQuestObjectives then
			return {}
		end
		local ok, list = pcall(C_QuestLog.GetQuestObjectives, qid)
		if not ok or type(list) ~= "table" then
			return {}
		end
		local out = {}
		for _, o in ipairs(list) do
			if type(o) == "table" then
				out[#out + 1] = {
					text = trimText(o.text),
					type = o.type,
					objective_type = o.objectiveType,
					finished = o.finished and true or false,
					num_fulfilled = o.numFulfilled,
					num_required = o.numRequired,
				}
			end
		end
		return out
	end

	local function flushActiveInto(env)
		local n = C_QuestLog.GetNumQuestLogEntries()
		for idx = 1, n do
			local info = C_QuestLog.GetInfo(idx)
			if info and not info.isHeader then
				local qid = info.questID
				local tag = qid and C_QuestLog.GetQuestTagInfo(qid)
				push(env, {
					record_kind = "quest_log_active",
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
					objectives = objectivesForQuest(qid),
				})
			end
		end
	end

	local function flushCompletedInto(env)
		local ids = {}
		if C_QuestLog.GetAllCompletedQuestIDs then
			ids = C_QuestLog.GetAllCompletedQuestIDs() or {}
		elseif GetQuestsCompleted then
			ids = GetQuestsCompleted() or {}
		end

		local flat = {}
		if #ids > 0 then
			for _, questId in ipairs(ids) do
				if questId then
					flat[#flat + 1] = questId
				end
			end
		else
			for questId, done in pairs(ids) do
				if done then
					local qn = type(questId) == "number" and questId or tonumber(questId)
					if qn then
						flat[#flat + 1] = qn
					end
				end
			end
		end

		do
			local seen = {}
			local u = {}
			for _, q in ipairs(flat) do
				if not seen[q] then
					seen[q] = true
					u[#u + 1] = q
				end
			end
			flat = u
			table.sort(flat)
		end

		local total = #flat
		local exportCount = math.min(total, ABSOLUTE_MAX_COMPLETED_IDS)
		push(env, {
			record_kind = "_quests_completed_meta",
			total_completed_known = total,
			exported_count = exportCount,
			chunk_size = CHUNK_SIZE,
			truncated = total > ABSOLUTE_MAX_COMPLETED_IDS or false,
		})

		if total > ABSOLUTE_MAX_COMPLETED_IDS then
			env.partial = true
			env.partial_reason = "completed_quest_ids_absolute_cap"
		end

		local chunkIdx = 0
		local buf = {}
		for i = 1, exportCount do
			buf[#buf + 1] = flat[i]
			if #buf >= CHUNK_SIZE or i == exportCount then
				chunkIdx = chunkIdx + 1
				push(env, {
					record_kind = "completed_quest_ids_chunk",
					chunk_index = chunkIdx,
					quest_ids = buf,
				})
				buf = {}
			end
		end
	end

	function AC.Scanners.quests()
		local env = AC.NewEnvelope(false, nil)
		flushActiveInto(env)
		flushCompletedInto(env)
		AC.CommitSection("quests", env)
	end

	local function copyCompletedRow(row)
		local kind = row.record_kind
		if kind == "_quests_completed_meta" then
			return {
				record_kind = "_quests_completed_meta",
				total_completed_known = row.total_completed_known,
				exported_count = row.exported_count,
				chunk_size = row.chunk_size,
				truncated = row.truncated and true or false,
			}
		end
		if kind == "completed_quest_ids_chunk" then
			local ids = {}
			if type(row.quest_ids) == "table" then
				for i, q in ipairs(row.quest_ids) do
					ids[i] = q
				end
			end
			return {
				record_kind = "completed_quest_ids_chunk",
				chunk_index = row.chunk_index,
				quest_ids = ids,
			}
		end
		return nil
	end

	local function commitQuestsActiveWithCachedCompleted()
		local env = AC.NewEnvelope(false, nil)
		flushActiveInto(env)

		local db = rawget(_G, "AzerothDataCollector_QuestsDB")
		local guid = AC.GetPlayerGuid()
		local prev = db and db.by_character and db.by_character[guid] and db.by_character[guid].quests
		if type(prev) == "table" then
			prev = AC.EnsureEnvelope(prev)
			for _, r in ipairs(prev.records) do
				local k = r.record_kind
				if k == "_quests_completed_meta" or k == "completed_quest_ids_chunk" then
					local c = copyCompletedRow(r)
					if c then
						push(env, c)
					end
				end
			end
			if prev.partial then
				env.partial = true
				env.partial_reason = prev.partial_reason
			end
		end

		AC.CommitSection("quests", env)
	end

	local function onQuestLogBurst()
		if not AC.Scanners.quests then
			return
		end
		commitQuestsActiveWithCachedCompleted()
		AC.Debounce(DEBOUNCE_KEY_COMPLETED, COMPLETED_DEBOUNCE_SEC, AC.Scanners.quests)
	end

	AC.RegisterEvent("PLAYER_ALIVE", function()
		if AC.Scanners.quests then AC.Scanners.quests() end
	end)
	AC.RegisterEvent("QUEST_LOG_UPDATE", onQuestLogBurst)
	AC.RegisterEvent("UNIT_QUEST_LOG_CHANGED", onQuestLogBurst)
	AC.RegisterEvent("WORLD_QUEST_COMPLETED_BY_SPELL", onQuestLogBurst)
	AC.RegisterEvent("COVENANT_CALLINGS_UPDATED", onQuestLogBurst)
end)
