# Azeroth Data Collector

This repository is the **in-game collection layer** for a future **World of Warcraft AI companion** product. It runs inside the WoW **mainline** (“Retail”) **game client** and uses Blizzard’s permitted **in-game Addon / UI (Lua) APIs** — not Blizzard’s Battle.net HTTPS “developer” APIs — to read game state under normal addon rules (no automation, no protected actions, no outbound networking from our Lua code), then writes **persistent, structured snapshots** that are easy for **both humans and LLMs** to reason about.

**Design intent**

1. **Personalized player state (“user data”)** — Characters are keyed by GUID under `by_character`. Each domain (quests, gear, reputations, …) uses a predictable **envelope** shape (`records`, `partial`, `updated_at`, semantic `record_kind` fields, stable IDs where possible).
2. **Machine-readable WoW snapshots** — Output is Blizzard’s **`SavedVariables` Lua serialization** (`WTF/.../SavedVariables/*.lua`): plain tables/dictionaries LLM tooling can ingest, grep, parse, diff, or index without reverse-engineering bit-packed blobs.
3. **Companion-ready split** — The addon intentionally **does not** call LLMs or fetch external knowledge. A separate **desktop app / companion** is expected to combine these dumps with **static or refreshed external WoW knowledge** (wikis, patch notes, guides, item DBs, community content, RAG corpora) for answers, coaching, and UI—so this project stays a **safe, read-only data foundation**.

In short: **WoW Addon / Lua API → structured SavedVariables Lua files on disk** that can later sit next to your **knowledge pipeline** as the per-user half of an AI companion database.

---

## What this repo contains

**21 separate WoW addons** (1 main package + **20 modules**) live as sibling folders under `Interface/AddOns/`. The main addon is **`AzerothDataCollector`**; satellites are **`AzerothDataCollector_<Domain>/`**. Each has its own `.toc` and single entry `.lua`.

- **Main addon** [`AzerothDataCollector/AzerothDataCollector.toc`](AzerothDataCollector/AzerothDataCollector.toc): `## SavedVariables: AzerothDataCollectorDB` stores **only schema version + client metadata** (`WTF/.../SavedVariables/AzerothDataCollector.lua`).
- **Each module** declares its own **`## SavedVariables: ...DB`** global; Blizzard persists one SavedVariables Lua file per global (for example `AzerothDataCollector_Quests.lua`, `AzerothDataCollector_Currencies.lua`, …)—a **multi-file** snapshot layout keeps character-scale data out of the root DB.

Shared API: **`_G.AzerothDataCollector`** (`local AC = AzerothDataCollector`).

Repo: [github.com/avfurkanengin/AzerothDataCollector](https://github.com/avfurkanengin/AzerothDataCollector)

## Folder layout (Addons root)

```
AzerothDataCollector/                 ← Main: Core/ + AzerothDataCollector.toc + AzerothDataCollector.lua
AzerothDataCollector_Achievements/
AzerothDataCollector_Agenda/
AzerothDataCollector_Auctions/
AzerothDataCollector_Containers/
AzerothDataCollector_Currencies/
AzerothDataCollector_Delves/
AzerothDataCollector_Equipment/
AzerothDataCollector_GuildBank/
AzerothDataCollector_Garrison/
AzerothDataCollector_Mail/
AzerothDataCollector_Meta/
AzerothDataCollector_Mounts/
AzerothDataCollector_Pets/
AzerothDataCollector_Professions/
AzerothDataCollector_Quests/
AzerothDataCollector_Reputations/
AzerothDataCollector_Spells/
AzerothDataCollector_Stats/
AzerothDataCollector_Talents/
AzerothDataCollector_Transmog/
```

**Always enable** the `AzerothDataCollector/` main addon. Modules list **`## Dependencies: AzerothDataCollector`** in their `.toc` files. All TOCs share **`## Group: AzerothDataCollector`** and **`## Category: AzerothAiCompanion`** (custom group label in the in-game AddOns list; see [Addon Categories](https://warcraft.wiki.gg/wiki/Addon_Categories) for Blizzard’s built-in values). After editing TOCs you may need a **`/reload` or full client restart** before the launcher list settles.

## SavedVariables

Typical account path: `World of Warcraft/_retail_/WTF/Account/<AccountName>/SavedVariables/`

| File (example) | Contents (summary) |
|----------------|---------------------|
| `AzerothDataCollector.lua` | `AzerothDataCollectorDB` — `schema_version`, `client` |
| `AzerothDataCollector_Meta.lua` | `AzerothDataCollector_MetaDB` — root fields plus **`by_character[guid].meta`** (name/realm/GUID/level, class/race/faction; zone/subzone; item level summaries; specialization; server time string; **`time_played_total_sec`** / **`time_played_level_sec`** from `RequestTimePlayed`) and **`wallet`** (**`copper`** = `GetMoney()`, optional `partial` / `partial_reason`) |
| `AzerothDataCollector_Quests.lua` | `AzerothDataCollector_QuestsDB` — active log (`record_kind=quest_log_active`, `objectives[]`); completed IDs in `completed_quest_ids_chunk` rows + `_quests_completed_meta` (IDs above ~50k are truncated); objective description strings capped for readability/size |
| `AzerothDataCollector_Achievements.lua` | `AzerothDataCollector_AchievementsDB` — each achievement one **`achievement_entry`** row with **`completed`** (boolean), **`criteria[]`**, earned date fields when completed; overall safety cap (~40k rows) |
| `AzerothDataCollector_Talents.lua` | `AzerothDataCollector_TalentsDB` — class/spec rows plus Retail **`trait_config`** + per-node **`trait_node`** (ranks, `selected`, `trait_spell_id`, `definition_id`) from `C_Traits` |
| `AzerothDataCollector_Equipment.lua` | `AzerothDataCollector_EquipmentDB` — per-slot: `gems[]`, **`stats`**, **`temp_enchant_spell_id`** |
| `AzerothDataCollector_GuildBank.lua` | `AzerothDataCollector_GuildBankDB` — `guild_bank`; when the guild bank UI is closed the section stays **`partial`** |
| `AzerothDataCollector_Mounts.lua` | `AzerothDataCollector_MountsDB` → `by_character[guid].collections_mounts` |
| `AzerothDataCollector_Pets.lua` | `AzerothDataCollector_PetsDB` → `by_character[guid].collections_pets` |
| `AzerothDataCollector_Transmog.lua` | `AzerothDataCollector_TransmogDB` → `collections_transmog` (custom `record_kind` rows: category rollup + `appearance_collected`) + `collections_transmog_sets` |
| … | Remaining modules follow the same envelope + `records` convention |

**Mounts / pets / xmog split:** Remove legacy **`AzerothDataCollector_Collections*`** folders and the shared `AzerothDataCollector_Collections.lua` SV if you migrated; enable the Mount, Pets, and Transmog modules instead. Older collection SV blobs can be deleted in-game once you trust the replacement exports.

**Migration (`characters` → `by_character`):** `AC.EnsureModuleSavedVariables` rewires legacy `characters[...]` tables into **`by_character`** and removes the obsolete key on load. `schema_version` **5** extends **4** (quests envelope, achievement criteria detail, equipment snapshot, `guild_bank`) with achievements listing **earned and incomplete** rows (`achievement_entry.completed`) and Retail talent **`trait_node`** rows from `C_Traits.GetNodeInfo(configID, nodeID)`.

**Disk persistence:** Tables update instantly in Lua memory; Blizzard flushes SavedVariables **`/reload` or logout** in normal cases—you do not need a slash command for snapshots to accumulate in RAM.

**Single-file-era data:** Older builds that persisted everything inside `AzerothDataCollectorDB.characters` are **not automatically split**. Copy this build into `Interface/AddOns`, `/reload`, and let scanners repopulate (or migrate manually). If the root SV now only mirrors schema/client metadata you may trim `AzerothDataCollectorDB` accordingly.

**Rename note:** Migrating **`AzerothDataCollector_Main` → `AzerothDataCollector`** still applies for anyone on ancient paths; SV file name **`AzerothDataCollector.lua`** must match the new global.

## Commands (optional manual refresh)

- `/adc`, `/azerothdata`, `/azdatacollect`, `/azadc`, `/acc`

Defined in [`AzerothDataCollector/AzerothDataCollector.lua`](AzerothDataCollector/AzerothDataCollector.lua). For debugging, assigning `_G.ADC_DEBUG = true` mirrors the slash chat confirmation after automated scans finish.

## Git

`SampleAddon/` is referenced locally for prototyping; it is **not** tracked (`.gitignore`).

## Requirements

World of Warcraft **mainline** client (often called **Retail**) — enforced in-game as **`WOW_PROJECT_MAINLINE`**. Classic / Era / other branches are unsupported.
