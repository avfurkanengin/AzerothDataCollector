# Azeroth Data Collector

**18 ayrı WoW eklentisi** — hepsi `Interface/AddOns/` altında **aynı seviyede** klasör: `AzerothDataCollector_<Ad>/` (ana paket de **`AzerothDataCollector_Main`**). Her birinin kendi **`.toc`** ve kendi **tek giriş `.lua`** dosyası vardır; ortak `Modules/` kabı yok.

Veri tek bir **SavedVariables** global’ına (`AzerothDataCollectorDB`) yazılır; bu değişken **yalnızca `AzerothDataCollector_Main`** `.toc` dosyasında tanımlıdır. Lua tarafında paylaşılan API hâlâ **`_G.AzerothDataCollector`** (modüller `local AC = AzerothDataCollector` kullanır).

Repo: [github.com/avfurkanengin/AzerothDataCollector](https://github.com/avfurkanengin/AzerothDataCollector)

## Klasör yapısı (AddOns kökünde yan yana)

```
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
AzerothDataCollector_Main/          ← Core/ + AzerothDataCollector_Main.toc + AzerothDataCollector_Main.lua (+ SavedVariables)
AzerothDataCollector_Meta/
AzerothDataCollector_Professions/
AzerothDataCollector_Quests/
AzerothDataCollector_Reputations/
AzerothDataCollector_Spells/
AzerothDataCollector_Stats/
AzerothDataCollector_Talents/
```

Oyunda **`_retail_/Interface/AddOns/`** altına istediğin modül klasörlerini kopyala; **mutlaka `AzerothDataCollector_Main`** da olsun. Her modül `.toc` içinde **`Dependencies: AzerothDataCollector_Main`** ile ana klasöre bağlıdır.

Etkinleştirdiğin her modül, **`AzerothDataCollector` global’ında** ilgili tarayıcıyı (`AC.Scanners[...]`) kaydeder.

Kayıtlı değişken dosyası (hesap düzeyi, örnek):

`World of Warcraft/_retail_/WTF/Account/<HesapAdı>/SavedVariables/AzerothDataCollector_Main.lua`

Eski sürümde ana klasör adı **`AzerothDataCollector`** idi ve SV dosyası çoğu kurulumda **`AzerothDataCollector.lua`** olurdu. Taşıdıysan içindeki **`AzerothDataCollectorDB = { ... }`** tablosunu yeni ada uygun dosyaya kopyalayabilir veya dosyayı doğrudan yeniden adlandırabilirsin (değişken adı `AzerothDataCollectorDB` olarak kalmalı).

## Komutlar

`/adc`, `/azerothdata`, `/acc` (tanım `AzerothDataCollector_Main/AzerothDataCollector_Main.lua` içinde)

## Git

`SampleAddon/` yerel referanstır; repoda yok (`.gitignore`).

## Gereksinim

Retail / mainline (`WOW_PROJECT_MAINLINE`).
