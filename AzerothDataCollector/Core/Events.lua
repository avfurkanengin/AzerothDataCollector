local ADDON_NAME, AC = ...

AC._eventFrame = AC._eventFrame or CreateFrame("Frame")
AC._registry = AC._registry or {}

function AC.RegisterEvent(ev, cb)
	local reg = AC._registry[ev]
	if not reg then
		reg = {}
		AC._registry[ev] = reg
		AC._eventFrame:RegisterEvent(ev)
	end
	reg[#reg + 1] = cb
end

AC._eventFrame:SetScript("OnEvent", function(_, event, ...)
	local reg = AC._registry[event]
	if not reg then return end
	for i = 1, #reg do
		reg[i](event, ...)
	end
end)
