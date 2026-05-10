--[[
  Queued ADDON_LOADED / PLAYER_LOGIN callbacks for module registration and deferred work.
--]]

local ADDON_NAME, AC = ...

local TableInsert, ipairs = table.insert, ipairs

local addonLoadedCallbacks = {}
local loginQueue = {}
local loginHandled = false

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

frame:SetScript("OnEvent", function(_, event, arg1, ...)
	if event == "ADDON_LOADED" then
		local list = addonLoadedCallbacks[arg1]
		if list then
			for _, cb in ipairs(list) do
				cb()
			end
			addonLoadedCallbacks[arg1] = nil
		end
	elseif event == "PLAYER_LOGIN" then
		loginHandled = true
		local q = loginQueue
		loginQueue = nil
		if q then
			for _, cb in ipairs(q) do
				cb()
			end
		end
	end
end)

function AC.OnAddonLoaded(targetAddonName, callback)
	addonLoadedCallbacks[targetAddonName] = addonLoadedCallbacks[targetAddonName] or {}
	TableInsert(addonLoadedCallbacks[targetAddonName], callback)
end

function AC.OnPlayerLogin(callback)
	if loginHandled then
		callback()
		return
	end
	loginQueue = loginQueue or {}
	TableInsert(loginQueue, callback)
end
