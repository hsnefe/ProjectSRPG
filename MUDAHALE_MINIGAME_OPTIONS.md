# Müdahale mini oyunu — tasarım seçenekleri

Mekanik henüz seçilmedi. Bu belge dört somut öneriyi, her birinin neye mal
olduğunu ve hangi mevcut kodun üstüne oturduğunu karşılaştırır. Karar verilince
bu belge silinir, seçilen mekanik `API_CONTRACT.md` §7.3'e ve
`career_engine/CONTRACT.md` §5.6'ya yazılır.

## Neyi doldurmaya çalışıyoruz

İki ayrı boşluk var ve ikisi de bugün boş duruyor:

| Boşluk | Nerede | Bugünkü hâli |
|---|---|---|
| **Maç müdahalesi** | `tackle_hard` (ayrıca `high_press`, `keeper_sweep`) | `resolution: "engine"` — motor zar atıyor, oyuncu yalnızca "müdahale et / vazgeç" diyor |
| **Antrenman kartı** | `catalog/training.py`'deki `mudahale` kartı | `"drill": None` — kart görünüyor, tıklanınca hiçbir şey açılmıyor |

Savunma tarafının **hiç** mini oyunu yok: kataloğun 14 aksiyonundan minigame'i
olan 7'sinin tamamı hücum (4 şut + 3 pas). Yani bu, eksik bir parça değil,
oyunun yarısı.

Seçilen mekanik ikisini birden beslemeli — `dribble_game.dart` bunu yeni yaptı
(aynı oyun hem `dribling` antrenman kartını hem ileride bir maç aksiyonunu
besliyor), aynı kalıbı izlemek gerekiyor.

## Ortak kısıtlar

Hangi seçenek seçilirse seçilsin bunlar değişmiyor:

- **Sonuç sözlüğü `graded`:** `great` / `good` / `bad`. `tackle_hard` şeması
  bu (`catalog/match_actions.py`, `API_CONTRACT.md` Ek B) ve üç değerli kalmalı —
  şut tarafındaki dördüncü değer (`asist`) savunmada karşılığı olmayan bir şey.
- **Motor tarafında tek satır:** `match_engine/api/config.py`'deki
  `MINIGAME_ACTION_KEYS` listesine `tackle_hard` eklenmeli, yoksa teklif
  `resolution: "engine"` gelmeye devam eder ve FE ekranı hiç açılmaz. Bu
  **kardeş repoda** bir değişiklik.
- **Süre:** müdahale teklifi açıkken hem motor hem oynatma kafası duruyor
  ([İ-36]) ama teklifin kendi sayacı işliyor (`timeout_seconds`, tipik 20 sn).
  Mini oyun bunun içine sığmalı — yani **tek deneme, 5-8 saniye**. Antrenman
  tarafında aynı oyun çok denemeli bir oturuma sarılabilir (`ShotGame`'in
  `attemptsPerSession = 3` kalıbı).
- **Konvansiyon:** `training_result.dart:1-18` — `onStateChanged` +
  `onFinished`, bütün kurallar `size` okumayan `advance(double dt)` içinde.
  Bu, oyunu widget'sız test edilebilir yapan şey ve pazarlık konusu değil.

---

## Seçenek A — Zamanlama penceresi

**Girdi:** tek dokunuş.

Rakip topla üstüne geliyor. Ekranın altında daralan bir pencere (ya da salınan
bir imleç) var; müdahale için doğru anda dokunuyorsun. Erken dokunmak "ayağın
açıkta kaldı", geç dokunmak "adamı geçirdin".

**Başarı ölçütü:** dokunuş anının pencere merkezine uzaklığı.
Merkez ±%12 → `great`, ±%35 → `good`, dışı → `bad`.

**Yeniden kullandığı kod:** `bench_press_game.dart` neredeyse birebir —
`PowerBarComponent` salınan bir imleç, `PressInputLayer` yalnızca
`TapCallbacks`. Sahne çizimi `pitch_projector.dart`'tan gelir.

**Maliyet:** en düşük. Yeni oyun ~250 satır, çoğu mevcut bileşenlerin yeniden
dizilmesi.

**Riski:** oyunda zaten iki tane zamanlama-tabanlı oyun var (güç, kondisyon).
Üçüncüsü savunmayı "bir tane daha ritim oyunu" yapar; hücum tarafı nişan alma
gibi mekanik olarak farklı bir şey sunarken savunma tarafı tekrar eder.

---

## Seçenek B — Yön okuma (çalım yeme riski)

**Girdi:** tek kaydırma, yön önemli.

Rakip önünde duruyor ve **çalım atıyor** — gövdesi bir yöne yalpalıyor, sonra
gerçek yönü belli oluyor. Sen gideceğini düşündüğün yöne kaydırıyorsun. Erken
kaydırırsan çalıma kanarsın; çok beklersen adam çoktan geçmiştir.

**Başarı ölçütü:** iki eksenli — (1) kaydırma yönü gerçek yönle uyuşuyor mu,
(2) ne kadar geç kaydırdın.
Doğru yön + erken → `great`, doğru yön + geç → `good`, yanlış yön → `bad`.

**Yeniden kullandığı kod:** yön okuma mantığı `dribble_game.dart`'ın
`swipe()`'ındaki nokta çarpımı hizalaması ile aynı ailede; sahne
`shot_game.dart`'ın `ActorsComponent`'i ve `pitch_projector.dart`.

**Maliyet:** orta. Çalım animasyonu ve gerçek-yön/aldatma zamanlaması ayarı
gerçek iş; ~400 satır.

**Neden cazip:** driblingin **aynası**. Dribling oyununda oyuncu kaydırarak
yön değiştiriyor; müdahalede o yönü okuyor. İki oyun birbirini öğretiyor ve
`dribbling` ile `tackling` nitelikleri anlamlı bir çift hâline geliyor.

---

## Seçenek C — Yaklaş ve dal (iki aşamalı)

**Girdi:** önce sürükleme, sonra dokunuş — `ShotGame`'in "nişan al, sonra vur"
ritminin savunma hâli.

Aşamalar: (1) **kapat** — sürükleyerek rakiple aranı daraltırsın, ama çok
yaklaşırsan çalım yeme riski artar, uzak durursan şut/pas atmasına izin
verirsin; (2) **dal** — bırakıp dokunduğunda o mesafeden müdahale edersin.

**Başarı ölçütü:** dalış anındaki mesafe × açı. Temiz mesafe + gövdenin doğru
tarafı → `great`, top kaçar ama adam da geçemez → `good`, faul ya da geçilme →
`bad`.

**Yeniden kullandığı kod:** en çok kodu paylaşan seçenek —
`shot_game.dart`'ın `InputLayer`'ı (`beginAim`/`updateAim`/`endAim`),
`AimComponent`, `pitch_projector.dart`'ın sözde-3B izdüşümü. `ShotScene`
şablonları savunma senaryolarına uyarlanabilir.

**Maliyet:** en yüksek. `ShotGame` 1889 satır ve savunma varyantı kendi
senaryo kataloğunu ister (`shot_scenarios.dart`'ın karşılığı).

**Riski:** müdahale teklifinin 20 saniyelik penceresine iki aşamalı bir oyun
sığdırmak dar. Antrenman kartında rahat, maç içinde acele hissettirebilir.

---

## Seçenek D — Baskı zinciri

**Girdi:** dönüşümlü dokunuşlar, sonunda tek bir zamanlama.

Presi kuruyorsun: sol/sağ dönüşümlü basarak rakibe koşuyorsun (kondisyon
antrenmanının ritmi), mesafe kapanınca kısa bir müdahale penceresi açılıyor.
Ritmi tutturmak pencereyi genişletiyor — yani iyi koşan kolay müdahale ediyor.

**Başarı ölçütü:** ritim tutarlılığı pencere genişliğini belirler, pencere
içindeki dokunuş dereceyi verir.

**Yeniden kullandığı kod:** `conditioning_game.dart` neredeyse olduğu gibi
(`RunSide`, cadence, `TreadmillComponent` → saha kayması).

**Maliyet:** düşük-orta.

**Neden ayrı duruyor:** bu aslında `tackle_hard`'dan çok **`high_press`**'in
oyunu. Üç savunma aksiyonunun üçüne birden tek mekanik uydurmaya çalışmak
yerine ayrı ayrı düşünmek gerekiyorsa, D press'in, A/B/C müdahalenin adayı
olur.

---

## Karşılaştırma

| | A · Zamanlama | B · Yön okuma | C · Yaklaş-dal | D · Baskı zinciri |
|---|---|---|---|---|
| Girdi | dokunuş | kaydırma | sürükle + dokunuş | ritim + dokunuş |
| Maliyet | düşük | orta | yüksek | düşük-orta |
| Yeni satır (tahmin) | ~250 | ~400 | ~700 | ~300 |
| Maçın 20 sn'sine sığar mı | rahat | rahat | dar | dar |
| Mevcut oyunlardan farkı | az | yüksek | orta | az |
| Hangi aksiyona uyar | hepsi | `tackle_hard` | `tackle_hard` | `high_press` |
| `mudahale` antrenman kartı | uyar | uyar | uyar | kısmen |

## Öneri

**B (yön okuma)**, ve gerekirse A'ya düşmek.

Gerekçe: dribling oyunu az önce yön kaydırmayı oyunun savunma-dışı yarısına
yerleştirdi. B, o mekaniği aynaya tutuyor — oyuncu top sürerken yön seçmeyi,
müdahale ederken yön okumayı öğreniyor, ve `dribbling`/`tackling` nitelikleri
mekanik olarak birbirinin karşıtı hâline geliyor. A daha ucuz ama oyundaki
üçüncü zamanlama oyunu olur; C doğru oyun ama maç içi pencereye dar ve bu
turun bütçesini tek başına yer.

Karar verilirse gereken dokunuşlar:

1. `match_engine/api/config.py` · `MINIGAME_ACTION_KEYS` += `tackle_hard`
2. `API_CONTRACT.md` §7.3 tablosu + `minigame` alanına ikinci değer
   (bugün tek değer var: `"shot"`)
3. `lib/game/<seçilen>_game.dart` + `lib/screens/` host ekranı
4. `lib/game/match_scenarios.dart` · `tackle_hard` → senaryo havuzu
5. `lib/screens/match_screen.dart:139` · `resolution == 'minigame'` dalı artık
   iki farklı ekran açacak, `offer.minigame` değerine göre
6. `career_engine/catalog/training.py` · `mudahale` kartının `drill`'i
7. `career_engine/CONTRACT.md` §5.6 · M2 doğrulama tablosu değişmez
   (`graded` zaten tanımlı) — yalnızca §7.3 referansı güncellenir
