local _, AC = ...

AC.Scanners = AC.Scanners or {}

function AC.Scanners.spells()
	local env = AC.NewEnvelope(false, nil)

	local nLines = C_SpellBook.GetNumSpellBookSkillLines()
	local spellBank = Enum.SpellBookSpellBank.Player
	local flyoutTy = Enum.SpellBookItemType and Enum.SpellBookItemType.Flyout or 11

	for line = 1, nLines do
		local sb = C_SpellBook.GetSpellBookSkillLineInfo(line)
		if sb and sb.numSpellBookItems and sb.numSpellBookItems > 0 then
			for index = sb.itemIndexOffset + 1, sb.itemIndexOffset + sb.numSpellBookItems do
				local info = C_SpellBook.GetSpellBookItemInfo(index, spellBank)
				if info then
					local sid = info.spellID
					if sid and info.itemType ~= flyoutTy then
						local name = C_Spell.GetSpellName and C_Spell.GetSpellName(sid) or GetSpellInfo(sid)
						env.records[#env.records + 1] = {
							id = sid,
							name = name or ("spell_" .. sid),
							tab = sb.name,
							spell_book_index = index,
							item_type = info.itemType and tostring(info.itemType) or "nil",
						}
					elseif sid and info.itemType == flyoutTy then
						local _, _, numSlots = GetFlyoutInfo(sid)
						for i = 1, numSlots or 0 do
							local flySpell, _, known = GetFlyoutSlotInfo(sid, i)
							if known and flySpell then
								local name = C_Spell.GetSpellName and C_Spell.GetSpellName(flySpell) or GetSpellInfo(flySpell)
								env.records[#env.records + 1] = {
									id = flySpell,
									name = name or ("spell_" .. flySpell),
									tab = sb.name,
									flyout_parent = sid,
								}
							end
						end
					end
				end
			end
		end
	end

	AC.CommitSection("spells", env)
end

AC.RegisterEvent("PLAYER_ALIVE", function()
	if AC.Scanners.spells then AC.Scanners.spells() end
end)
AC.RegisterEvent("SPELLS_CHANGED", function()
	if AC.Scanners.spells then AC.Scanners.spells() end
end)
