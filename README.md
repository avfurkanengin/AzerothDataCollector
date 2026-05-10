# Azeroth Data Collector

**18 ayrı WoW eklentisi** — `Interface/AddOns/` altında yan yana klasörler. Ana paket klasörü **`AzerothDataCollector`** (DataStore’daki **`DataStore`** yapısına paralel); modüller **`AzerothDataCollector_<Alan>/`**. Her birinin kendi `.toc` ve tek giriş `.lua` dosyası var.

Veri tek **SavedVariables** global’ında (`AzerothDataCollectorDB`); tanım yalnızca ana [`AzerothDataCollector/AzerothDataCollector.toc`](AzerothDataCollector/AzerothDataCollector.toc) içinde. Paylaşılan API: **`_G.AzerothDataCollector`** (`local AC = AzerothDataCollector`).

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

**Mutlaka** `AzerothDataCollector/` ana paketini de kopyala ve etkinleştir. Modüller `.toc` içinde **`## Dependencies: AzerothDataCollector`** ile bağlıdır.

## Kayıtlı değişkenler (SavedVariables)

Hesap düzeyi (örnek):

`World of Warcraft/_retail_/WTF/Account/<HesapAdı>/SavedVariables/AzerothDataCollector.lua`

**Güncelleme:** Daha önce ana klasör **`AzerothDataCollector_Main`** kullandıysan: eski klasörü AddOns’tan kaldırıp yeni **`AzerothDataCollector`** klasörünü koy. Eski **`AzerothDataCollector_Main.lua`** dosyasını **`AzerothDataCollector.lua`** olarak yeniden adlandır veya içindeki **`AzerothDataCollectorDB = { ... }`** bloğunu yeni dosyaya taşı (global adı değişmez).

## Komutlar (chat)

- `/adc`
- `/azerothdata`
- `/azdatacollect`
- `/azadc`
- `/acc`

Tanım: [`AzerothDataCollector/AzerothDataCollector.lua`](AzerothDataCollector/AzerothDataCollector.lua). Çakışma teşhisi: `/run print(SlashCmdList["ADC_AZEROTH_DATA"] ~= nil)`.

## Git

`SampleAddon/` yerel referanstır; repoda yok (`.gitignore`).

## Gereksinim

Retail / mainline (`WOW_PROJECT_MAINLINE`).
