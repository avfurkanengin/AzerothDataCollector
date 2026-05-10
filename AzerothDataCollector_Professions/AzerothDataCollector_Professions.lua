--[[ AzerothDataCollector_Professions: bağımsız addon (kendi .toc + bu .lua) ]] 
local ADDON_NAME, _unused = ...

local AC = AzerothDataCollector
if type(AC) ~= "table" then
	return
end

local function safeRecipeDump(skillLineID, env)
	if not skillLineID then return end
	local ok, isRecipeLine = pcall(function()
		return C_TradeSkillUI.IsRecipeProfessionSkillLine(skillLineID)
	end)
	if not ok or not isRecipeLine then return end

	local ids = C_TradeSkillUI.GetAllRecipeIDs(skillLineID)
	if not ids then return end
	local capped = math.min(#ids, 900)
	local added = 0
	for i = 1, capped do
		local info = C_TradeSkillUI.GetRecipeInfo(ids[i])
		if info and info.learned then
			added = added + 1
			env.records[#env.records + 1] = {
				id = ids[i],
				name = info.name or ("recipe_" .. ids[i]),
				trade_skill_line_id = skillLineID,
			}
		end
	end
	if #ids > capped then
		env.records[#env.records + 1] = {
			id = -10,
			name = "_recipe_list_truncated",
			truncated_from = #ids,
		}
	end
	return added > 0
end

function AC.Scanners.professions()
	local env = AC.NewEnvelope(true, "open_trade_skill_ui_for_full_recipe_dump")

	env.records[#env.records + 1] = {
		id = -5,
		name = "_profession_header_note",
	}

	if not GetProfessions then
		AC.CommitSection("professions", env)
		return
	end

	local majors = { GetProfessions() }
	local slots = {
		"major_1", "major_2", "archaeology",
		"fishing", "cooking"
	}

	for idx = 1, #majors do
		local profIndex = majors[idx]
		if profIndex and profIndex ~= 0 then
			local pi = { pcall(GetProfessionInfo, profIndex) }
			if pi[1] then
				local name, tex, rn, mx, _, _, skillLine = pi[2], pi[3], pi[4], pi[5], pi[6], pi[7], pi[8], pi[9]
				env.records[#env.records + 1] = {
					id = skillLine or profIndex or idx,
					name = name or "?",
					skill_rank = rn,
					skill_max = mx,
					slot_index = slots[idx] or ("slot_" .. idx),
					texture = tex,
				}
				if skillLine then
					pcall(function() safeRecipeDump(skillLine, env) end)
				end
			end
		end
	end

	env.partial = false
	env.partial_reason = nil
	AC.CommitSection("professions", env)
end

AC.RegisterEvent("PLAYER_ALIVE", function()
	if AC.Scanners.professions then AC.Scanners.professions() end
end)
AC.RegisterEvent("SKILL_LINES_CHANGED", function()
	if AC.Scanners.professions then AC.Scanners.professions() end
end)
