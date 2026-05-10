--[[
  Ana addon: AzerothDataCollectorDB — schema + client meta (DataStore’daki DataStore ana SV’ye benzer).

  Her modül addon’u: tek bir SV global (DataStore modülü gibi bir .lua dosyası), iç yapı okunaklı kök alanlar:
    schema_version, module_key, addon_folder, last_saved_at,
    by_character = { [guid] = { <section> = envelope, ... } }

  Eski kayıtlarda "characters" kullanıldıysa yüklemede "by_character"a taşınır.
--]]

local ADDON_NAME, AC = ...

AzerothDataCollectorDB = AzerothDataCollectorDB or {}

--- Addon klasör adı → SV global + hangi bölümler bu dosyada / özel meta_wallet
AC.MODULE_SV_CONFIG = {
	["AzerothDataCollector_Meta"] = { sv_global = "AzerothDataCollector_MetaDB" },
	["AzerothDataCollector_Currencies"] = { sv_global = "AzerothDataCollector_CurrenciesDB", sections = { "currencies" } },
	["AzerothDataCollector_Reputations"] = { sv_global = "AzerothDataCollector_ReputationsDB", sections = { "reputations" } },
	["AzerothDataCollector_Talents"] = { sv_global = "AzerothDataCollector_TalentsDB", sections = { "talents" } },
	["AzerothDataCollector_Stats"] = { sv_global = "AzerothDataCollector_StatsDB", sections = { "stats" } },
	["AzerothDataCollector_Equipment"] = { sv_global = "AzerothDataCollector_EquipmentDB", sections = { "equipment" } },
	["AzerothDataCollector_Collections"] = {
		sv_global = "AzerothDataCollector_CollectionsDB",
		sections = { "collections_mounts", "collections_pets", "collections_transmog", "collections_transmog_sets" },
	},
	["AzerothDataCollector_Containers"] = { sv_global = "AzerothDataCollector_ContainersDB", sections = { "containers" } },
	["AzerothDataCollector_Quests"] = { sv_global = "AzerothDataCollector_QuestsDB", sections = { "quests" } },
	["AzerothDataCollector_Achievements"] = { sv_global = "AzerothDataCollector_AchievementsDB", sections = { "achievements" } },
	["AzerothDataCollector_Professions"] = { sv_global = "AzerothDataCollector_ProfessionsDB", sections = { "professions" } },
	["AzerothDataCollector_Mail"] = { sv_global = "AzerothDataCollector_MailDB", sections = { "mail" } },
	["AzerothDataCollector_Auctions"] = { sv_global = "AzerothDataCollector_AuctionsDB", sections = { "auctions" } },
	["AzerothDataCollector_Agenda"] = { sv_global = "AzerothDataCollector_AgendaDB", sections = { "agenda" } },
	["AzerothDataCollector_Spells"] = { sv_global = "AzerothDataCollector_SpellsDB", sections = { "spells" } },
	["AzerothDataCollector_Garrison"] = { sv_global = "AzerothDataCollector_GarrisonDB", sections = { "garrison" } },
	["AzerothDataCollector_Delves"] = { sv_global = "AzerothDataCollector_DelvesDB", sections = { "delves" } },
}

do
	AC.SECTION_SV_GLOBAL = {}
	for folder, cfg in pairs(AC.MODULE_SV_CONFIG) do
		if cfg.sections then
			for _, sec in ipairs(cfg.sections) do
				AC.SECTION_SV_GLOBAL[sec] = cfg.sv_global
			end
		end
	end
end

local function migrateLegacyCharacters(db)
	if type(db.characters) == "table" then
		if type(db.by_character) ~= "table" then
			db.by_character = db.characters
		else
			for g, row in pairs(db.characters) do
				if not db.by_character[g] then
					db.by_character[g] = row
				end
			end
		end
	end
	db.characters = nil
end

local function ensureModuleDbShape(db, addonFolder, cfg)
	if type(db) ~= "table" then
		db = {}
	end
	migrateLegacyCharacters(db)
	db.by_character = db.by_character or {}
	db.schema_version = db.schema_version or AC.SCHEMA_VERSION
	db.module_key = db.module_key or addonFolder:gsub("^AzerothDataCollector_", ""):lower()
	db.addon_folder = db.addon_folder or addonFolder
	db.last_saved_at = db.last_saved_at or 0
	return db
end

function AC.EnsureModuleSavedVariables(addonFolderName)
	local cfg = AC.MODULE_SV_CONFIG[addonFolderName]
	if not cfg then
		return
	end
	local gname = cfg.sv_global
	local raw = rawget(_G, gname)
	local db = ensureModuleDbShape(raw, addonFolderName, cfg)
	_G[gname] = db
end

local function getModuleRoot(globalName)
	local db = rawget(_G, globalName)
	local folder = nil
	for f, c in pairs(AC.MODULE_SV_CONFIG) do
		if c.sv_global == globalName then
			folder = f
			break
		end
	end
	if not folder then
		if type(db) ~= "table" then
			db = {}
			_G[globalName] = db
		end
		db.by_character = db.by_character or {}
		return db
	end
	db = ensureModuleDbShape(db or {}, folder, AC.MODULE_SV_CONFIG[folder])
	_G[globalName] = db
	return db
end

function AC.GetDB()
	return AzerothDataCollectorDB
end

function AC.UpdateClientMeta()
	local db = AzerothDataCollectorDB
	db.schema_version = AC.SCHEMA_VERSION
	db.client = db.client or {}
	local _, build, _, interfaceVersion = GetBuildInfo()
	db.client.interface_version = tonumber(interfaceVersion) or 0
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
	AC.UpdateClientMeta()
end

--- Meta / wallet (Meta modülü SV dosyası)
function AC.GetCharacterRoot()
	AC.InitRoot()
	local guid = AC.GetPlayerGuid()
	local db = getModuleRoot("AzerothDataCollector_MetaDB")
	if not db.by_character[guid] then
		db.by_character[guid] = {
			meta = {},
			wallet = {
				copper = 0,
				updated_at = 0,
				partial = false,
				partial_reason = nil,
			},
		}
	end
	local ch = db.by_character[guid]
	ch.meta = ch.meta or {}
	ch.wallet = ch.wallet or {
		copper = 0,
		updated_at = 0,
		partial = false,
		partial_reason = nil,
	}
	return ch
end

function AC.CommitSection(sectionName, data)
	local globalName = AC.SECTION_SV_GLOBAL[sectionName]
	if not globalName or type(sectionName) ~= "string" then
		return
	end
	local db = getModuleRoot(globalName)
	local guid = AC.GetPlayerGuid()
	db.by_character[guid] = db.by_character[guid] or {}
	db.by_character[guid][sectionName] = data
	db.last_saved_at = time()
	if sectionName ~= "meta" and sectionName ~= "wallet" and type(data) == "table" then
		data.updated_at = time()
	end
end
