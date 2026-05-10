local _, AC = ...

AC.Scanners = AC.Scanners or {}

function AC.Scanners.agenda()
	local env = AC.NewEnvelope(false, nil)

	RequestRaidInfo()

	local num = GetNumSavedInstances()
	for i = 1, num do
		local name, _, reset, difficultyID, locked, extend, _, _, maxPlayers, difficultyName, encountersTotal, encountersDone =
			GetSavedInstanceInfo(i)
		env.records[#env.records + 1] = {
			id = i,
			name = name or "?",
			saved_slot = i,
			instance_reset_unix = reset,
			difficulty_id = difficultyID,
			difficulty_name = difficultyName,
			instance_locked_flag = locked,
			extended_flag = extend,
			max_players = maxPlayers,
			encounters_total = encountersTotal,
			encounters_done = encountersDone,
			instance_flag = "raid_lockout_save",
		}
	end

	-- Calendar API needs Blizzard_Calendar; keep load-safe via pcall when frame exists.
	if CalendarFrame and C_Calendar and C_DateAndTime then
		local ok = pcall(function()
			local dt = C_DateAndTime.GetCurrentCalendarTime()
			if not dt then return end
			C_Calendar.SetAbsMonth(dt.month, dt.year)
			for day = dt.monthDay, dt.monthDay do
				for ei = 1, C_Calendar.GetNumDayEvents(0, day) do
					local ev = C_Calendar.GetDayEvent(0, day, ei)
					if ev and ev.calendarType and ev.calendarType ~= "HOLIDAY" and ev.calendarType ~= "RAID_LOCKOUT" and ev.calendarType ~= "RAID_RESET" then
						env.records[#env.records + 1] = {
							id = ev.eventID or (day * 100 + ei),
							name = ev.title or "?",
							calendar_type = ev.calendarType,
							event_hour = ev.startTime and ev.startTime.hour,
							event_minute = ev.startTime and ev.startTime.minute,
							month_day = day,
							instance_flag = "calendar_day_event",
						}
					end
				end
			end
		end)
		if not ok then
			env.partial = true
			env.partial_reason = "calendar_scan_failed"
		end
	end

	AC.CommitSection("agenda", env)
end

AC.RegisterEvent("PLAYER_ENTERING_WORLD", function()
	RequestRaidInfo()
	if AC.Scanners.agenda then C_Timer.After(2, AC.Scanners.agenda) end
end)

AC.RegisterEvent("UPDATE_INSTANCE_INFO", function()
	if AC.Scanners.agenda then AC.Scanners.agenda() end
end)
