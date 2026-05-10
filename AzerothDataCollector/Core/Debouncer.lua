local ADDON_NAME, AC = ...

AC._debounceTimers = AC._debounceTimers or {}

--- Coalesce rapid events (bags, etc.).
function AC.Debounce(key, delaySec, fn)
	local existing = AC._debounceTimers[key]
	if existing and existing.Cancel then
		existing:Cancel()
	end
	if C_Timer and C_Timer.NewTimer then
		AC._debounceTimers[key] = C_Timer.NewTimer(delaySec, function()
			AC._debounceTimers[key] = nil
			fn()
		end)
	elseif C_Timer and C_Timer.After then
		C_Timer.After(delaySec, fn)
	end
end
