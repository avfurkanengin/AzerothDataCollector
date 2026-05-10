--[[
	AzerothDataCollector_Mail — SV: AzerothDataCollector_MailDB
	Root DB fields plus by_character[guid].mail envelope; legacy characters migrated via AC.EnsureModuleSavedVariables.
	MAIL_SHOW + MAIL_INBOX_UPDATE snapshot once while open; BAG_UPDATE while mailbox visible (debounced);
	InteractionManager MailInfo show/hide hooks.
]]
local ADDON_NAME, _unused = ...

local AC = AzerothDataCollector
if type(AC) ~= "table" then
	return
end

local MAIL_DEBOUNCE_BAG = 0.35
local MAIL_DEBOUNCE_CLOSE = 0.3
local KEY_MAIL_BAG = "adc_mail_bag"
local KEY_MAIL_CLOSE = "adc_mail_close"

AC.OnAddonLoaded(ADDON_NAME, function()
	AC.EnsureModuleSavedVariables(ADDON_NAME)

	local inboxOpenTracked = false
	local inboxBootstrapFrame = CreateFrame("Frame")

	local function inboxOneShotBootstrap()
		inboxBootstrapFrame:RegisterEvent("MAIL_INBOX_UPDATE")
		inboxBootstrapFrame:SetScript("OnEvent", function(self)
			self:UnregisterEvent("MAIL_INBOX_UPDATE")
			if AC.Scanners.mail then
				pcall(AC.Scanners.mail)
			end
		end)
	end

	local function stopInboxBootstrap()
		inboxBootstrapFrame:UnregisterEvent("MAIL_INBOX_UPDATE")
	end

	local function mailVisible()
		if MailboxFrame and MailboxFrame:IsShown() then
			return true
		end
		local mf = MailFrame
		return mf and mf:IsShown()
	end

	local function runMailDebounced(key, delaySec)
		if AC.Scanners.mail then
			AC.Debounce(key, delaySec or MAIL_DEBOUNCE_CLOSE, AC.Scanners.mail)
		end
	end

	function AC.Scanners.mail()
		local env = AC.NewEnvelope(true, "not_at_mailbox")

		local count = GetInboxNumItems and GetInboxNumItems() or 0

		if mailVisible() then
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
			local _, _, sender, subject, money, CODAmount, daysLeft, itemCount, wasRead =
				GetInboxHeaderInfo(i)

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

	local function onMailShown()
		inboxOpenTracked = true
		stopInboxBootstrap()
		inboxOneShotBootstrap()
		if AC.Scanners.mail then
			pcall(AC.Scanners.mail)
		end
	end

	AC.RegisterEvent("MAIL_SHOW", onMailShown)
	AC.RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", function(_, paneType)
		local okMail = Enum and Enum.PlayerInteractionType and paneType == Enum.PlayerInteractionType.MailInfo
		if okMail then
			onMailShown()
		end
	end)

	AC.RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", function(_, paneType)
		local okMail = Enum and Enum.PlayerInteractionType and paneType == Enum.PlayerInteractionType.MailInfo
		if not okMail then
			return
		end
		inboxOpenTracked = false
		stopInboxBootstrap()
		runMailDebounced(KEY_MAIL_CLOSE)
	end)

	AC.RegisterEvent("MAIL_CLOSED", function()
		inboxOpenTracked = false
		stopInboxBootstrap()
		runMailDebounced(KEY_MAIL_CLOSE)
	end)

	AC.RegisterEvent("BAG_UPDATE", function()
		if not inboxOpenTracked and not mailVisible() then
			return
		end
		runMailDebounced(KEY_MAIL_BAG, MAIL_DEBOUNCE_BAG)
	end)
end)
