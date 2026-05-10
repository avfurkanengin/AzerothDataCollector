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

**Normal kullanım:** Slash veya `/run` gerekmez. Oturum açınca (`PLAYER_LOGIN` ve dünya yüklemesi sonrası) eklenti arka planda taramayı dener; **`AzerothDataCollectorDB` diske yazılır** Blizzard’ın kuralına göre: karakter seçip dünyadayken yüklemeden sonra **`/reload` veya tam çıkış`** ile dosyanın oluşması/güncellenmesi beklenir (DataStore ile aynı model).

İsteğe bağlı olarak herhangi bir zamanda güncelleme için aşağıdaki slash komutları kullanılabilir.

**Güncelleme:** Daha önce ana klasör **`AzerothDataCollector_Main`** kullandıysan: eski klasörü AddOns’tan kaldırıp yeni **`AzerothDataCollector`** klasörünü koy. Eski **`AzerothDataCollector_Main.lua`** dosyasını **`AzerothDataCollector.lua`** olarak yeniden adlandır veya içindeki **`AzerothDataCollectorDB = { ... }`** bloğunu yeni dosyaya taşı (global adı değişmez).

## Komutlar (isteğe bağlı, manuel yenileme)

- `/adc`, `/azerothdata`, `/azdatacollect`, `/azadc`, `/acc`

Tanım: [`AzerothDataCollector/AzerothDataCollector.lua`](AzerothDataCollector/AzerothDataCollector.lua). Geliştirici teşhisinde chat’te `ADC_DEBUG = true` atanırsa otomatik taramadan sonra da onay mesajı basılır.

## Git

`SampleAddon/` yerel referanstır; repoda yok (`.gitignore`).

## Gereksinim

Retail / mainline (`WOW_PROJECT_MAINLINE`).
