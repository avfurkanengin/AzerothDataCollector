--[[
	AzerothDataCollector_Mail — SV: AzerothDataCollector_MailDB
	Kök + by_character[guid].mail = envelope | eski characters → by_character.
]]
local ADDON_NAME, _unused = ...

local AC = AzerothDataCollector
if type(AC) ~= "table" then
	return
end

AC.OnAddonLoaded(ADDON_NAME, function()
	AC.EnsureModuleSavedVariables(ADDON_NAME)
	local function inboxOpen()
		return MailboxFrame and MailboxFrame:IsShown()
	end

	function AC.Scanners.mail()
		local env = AC.NewEnvelope(true, "not_at_mailbox")

		local count = GetInboxNumItems and GetInboxNumItems() or 0

		if inboxOpen() then
			env.partial = false
			env.partial_reason = nil
		elseif count > 0 then
			env.partial = false
			env.partial_reason = nil
		else
			env.partial = true
			env.partial_reason = "mailbox_visibility_unknown"
		end

		for i = 1, math.min(count, 80) do
			local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, itemCount,
				wasRead, _, _, _, isGM = GetInboxHeaderInfo(i)

			env.records[#env.records + 1] = {
				id = i,
				name = subject or "?",
				mail_index = i,
				sender = sender,
				has_money_copper = money or 0,
				cod_copper = CODAmount or 0,
				days_left = daysLeft,
				items_attached_hint = itemCount or 0,
				read_flag = wasRead,
			}
		end

		if count > 80 then
			env.records[#env.records + 1] = { id = -11, name = "_mail_truncated", total_count = count }
		end

		AC.CommitSection("mail", env)
	end

	AC.RegisterEvent("MAIL_CLOSED", function()
		if AC.Scanners.mail then AC.Scanners.mail() end
	end)
	AC.RegisterEvent("MAIL_SHOW", function()
		if AC.Scanners.mail then AC.Scanners.mail() end
	end)
end)
