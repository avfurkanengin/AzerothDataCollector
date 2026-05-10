--[[
  Shared schema constants (retail). All persisted sections use snake_case.
  Envelope: updated_at, partial, partial_reason, records
--]]

local ADDON_NAME, AC = ...

AC.SCHEMA_VERSION = 1

-- Envelope-backed sections only (meta + wallet are plain tables; not in this list)
AC.SECTION_NAMES = {
	"currencies",
	"reputations",
	"talents",
	"stats",
	"equipment",
	"containers",
	"quests",
	"achievements",
	"collections_mounts",
	"collections_pets",
	"collections_transmog",
	"collections_transmog_sets",
	"professions",
	"mail",
	"auctions",
	"agenda",
	"spells",
	"garrison",
	"delves",
}

function AC.NewEnvelope(partial, partialReason)
	return {
		updated_at = time(),
		partial = partial and true or false,
		partial_reason = partialReason,
		records = {},
	}
end

function AC.EnsureEnvelope(t)
	if type(t) ~= "table" then
		return AC.NewEnvelope(true, "missing_section")
	end
	t.updated_at = t.updated_at or 0
	t.partial = t.partial and true or false
	t.partial_reason = t.partial_reason
	t.records = t.records or {}
	return t
end
