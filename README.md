# Azeroth Data Collector

Retail **World of Warcraft** addon that writes **AI-friendly, snake_case** character snapshots to **`SavedVariables`** (`AzerothDataCollectorDB`).

Repository: [github.com/avfurkanengin/AzerothDataCollector](https://github.com/avfurkanengin/AzerothDataCollector)

## Install

1. Copy the folder **`AzerothDataCollector`** into:
   - `_retail_/Interface/AddOns/AzerothDataCollector/`
2. Ensure `AzerothDataCollector.toc` lives next to `Main.lua`.
3. Enable **Azeroth Data Collector** in the AddOns list.

## Slash commands

- `/adc` or `/azerothdata` — run a full snapshot
- `/acc` — same (legacy alias)

## Repo layout

| Path | Purpose |
|------|---------|
| `AzerothDataCollector/` | Main WoW addon (the one you install) |
| `SubAddons/` | Placeholder for future optional companion addons (empty for now) |
| `SampleAddon/` | **Not in git** — local DataStore reference only (see `.gitignore`) |

## Data file

After `/reload` or logout, the client writes:

`WTF/Account/<account>/SavedVariables/AzerothDataCollector.lua`

## Requirements

- **Retail / mainline** only (`WOW_PROJECT_MAINLINE`)
