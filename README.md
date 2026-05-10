# Azeroth Data Collector

**18 ayrı WoW eklentisi** — `Interface/AddOns/` altında yan yana klasörler. Ana paket klasörü **`AzerothDataCollector`** (DataStore’daki **`DataStore`** yapısına paralel); modüller **`AzerothDataCollector_<Alan>/`**. Her birinin kendi `.toc` ve tek giriş `.lua` dosyası var.

- **Ana addon** [`AzerothDataCollector/AzerothDataCollector.toc`](AzerothDataCollector/AzerothDataCollector.toc): `## SavedVariables: AzerothDataCollectorDB` → yalnızca **schema sürümü + client meta** (`WTF/.../SavedVariables/AzerothDataCollector.lua`).
- **Her modül** kendi klasörüne paralel **`## SavedVariables: ...DB`** bildirir; Blizzard her biri için ayrı dosya yazar (ör. `AzerothDataCollector_Quests.lua`, `AzerothDataCollector_Currencies.lua`, …). DataStore’daki gibi **birden çok SV dosyası**.

Paylaşılan API: **`_G.AzerothDataCollector`** (`local AC = AzerothDataCollector`).


Repo: [github.com/avfurkanengin/AzerothDataCollector](https://github.com/avfurkanengin/AzerothDataCollector)

## Klasör yapısı (AddOns kökünde)

```
AzerothDataCollector/                 ← Ana: Core/ + AzerothDataCollector.toc + AzerothDataCollector.lua
AzerothDataCollector_Achievements/
AzerothDataCollector_Agenda/
AzerothDataCollector_Auctions/
AzerothDataCollector_Collections/
AzerothDataCollector_Containers/
AzerothDataCollector_Currencies/
AzerothDataCollector_Delves/
AzerothDataCollector_Equipment/
AzerothDataCollector_Garrison/
AzerothDataCollector_Mail/
AzerothDataCollector_Meta/
AzerothDataCollector_Professions/
AzerothDataCollector_Quests/
AzerothDataCollector_Reputations/
AzerothDataCollector_Spells/
AzerothDataCollector_Stats/
AzerothDataCollector_Talents/
```

**Mutlaka** `AzerothDataCollector/` ana paketini de kopyala ve etkinleştir. Modüller `.toc` içinde **`## Dependencies: AzerothDataCollector`** ile bağlıdır. Ana ve modül `.toc` dosyalarında **`## Group` / `## Category` aynı metin** olmalı; ana pakette group eksik olursa bazı client sürümlerinde liste “ana ayrı, modüller ayrı” düz görünür.

## Kayıtlı değişkenler (SavedVariables)

Hesap düzeyi örnek yol: `World of Warcraft/_retail_/WTF/Account/<HesapAdı>/SavedVariables/`

| Dosya (örnek) | İçerik özeti |
|---------------|----------------|
| `AzerothDataCollector.lua` | `AzerothDataCollectorDB` — `schema_version`, `client` |
| `AzerothDataCollector_Meta.lua` | `AzerothDataCollector_MetaDB` — kök: `schema_version`, `module_key`, `addon_folder`, `last_saved_at`; `by_character[guid].meta` / `wallet` |
| `AzerothDataCollector_Quests.lua` | `AzerothDataCollector_QuestsDB` — aynı kök + `by_character[guid].quests` (envelope) |
| … | Diğer modüller aynı kalıp (`...DB`, `by_character[guid].<section>`) |

**Migrasyon (`characters` → `by_character`):** Eski oturumlarda yazılmış `characters[...]` tabloları, modül yüklendiğinde `AC.EnsureModuleSavedVariables` ile `by_character`a taşınır (`characters` silinir). Harici araçlar sadece `by_character` okumalı; `schema_version` modül kökünde **2**.

**Diske yazma:** Oturum içi bellekte güncellenir; Blizzard dosyayı tipik olarak **`/reload` veya tam çıkış** sonrası yazar (DataStore ile aynı). Slash zorunlu değil.

**Eski tek dosya dönemi:** Daha önce tüm veri tek `AzerothDataCollectorDB.characters` altındaysa, yeni yapıda veri **modül dosyalarına bölünür**; eski SV’yi otomatik bölmüyoruz — **yeni build’i kopyalayıp `/reload` ile taramayı yeniden çalıştır** (veya veriyi elle taşı). Ana dosyada sadece meta kaldıysa `AzerothDataCollectorDB`’yi silebilir veya sadece `schema_version` / `client` bırakabilirsin.

**Güncelleme:** `AzerothDataCollector_Main` → `AzerothDataCollector` taşıması için eski notlar geçerli; SV adı `AzerothDataCollector.lua` olmalı.

## Komutlar (isteğe bağlı, manuel yenileme)

- `/adc`, `/azerothdata`, `/azdatacollect`, `/azadc`, `/acc`

Tanım: [`AzerothDataCollector/AzerothDataCollector.lua`](AzerothDataCollector/AzerothDataCollector.lua). Geliştirici teşhisinde chat’te `ADC_DEBUG = true` atanırsa otomatik taramadan sonra da onay mesajı basılır.

## Git

`SampleAddon/` yerel referanstır; repoda yok (`.gitignore`).

## Gereksinim

Retail / mainline (`WOW_PROJECT_MAINLINE`).
