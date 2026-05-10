--[[
  Root SavedVariable: AzerothDataCollectorDB
--]]

local ADDON_NAME, AC = ...

AzerothDataCollectorDB = AzerothDataCollectorDB or {}

function AC.GetDB()
	return AzerothDataCollectorDB
end

function AC.UpdateClientMeta()
	local db = AzerothDataCollectorDB
	db.schema_version = AC.SCHEMA_VERSION
	db.client = db.client or {}
	local _, build = GetBuildInfo()
	db.client.interface_version = tonumber(select(4, GetBuildInfo())) or 0
	db.client.game_build = build
	db.client.locale = GetLocale()
	db.client.captured_at = time()
end

function AC.GetPlayerGuid()
	return UnitGUID("player") or "unknown"
end

function AC.InitRoot()
	local db = AzerothDataCollectorDB
	db.schema_version = AC.SCHEMA_VERSION
	db.characters = db.characters or {}
	AC.UpdateClientMeta()
end

local function emptyCharacterSkeleton()
	local c = {
		meta = {},
		wallet = {
			copper = 0,
			updated_at = 0,
			partial = false,
			partial_reason = nil,
		},
	}
	for _, name in ipairs(AC.SECTION_NAMES) do
		c[name] = AC.NewEnvelope(true, "not_scanned")
	end
	return c
end

function AC.GetCharacterRoot()
	AC.InitRoot()
	local guid = AC.GetPlayerGuid()
	local db = AzerothDataCollectorDB
	if not db.characters[guid] then
		db.characters[guid] = emptyCharacterSkeleton()
	end
	local ch = db.characters[guid]
	for _, name in ipairs(AC.SECTION_NAMES) do
		ch[name] = AC.EnsureEnvelope(ch[name])
	end
	ch.wallet = ch.wallet or { copper = 0, updated_at = 0, partial = false }
	ch.meta = ch.meta or {}
	return ch
end

--- Replace a section with a full envelope (or wallet/meta exception).
function AC.CommitSection(sectionName, data)
	local ch = AC.GetCharacterRoot()
	ch[sectionName] = data
	if sectionName ~= "meta" and sectionName ~= "wallet" and type(data) == "table" then
		data.updated_at = time()
	end
end
