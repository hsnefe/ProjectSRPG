# CAREER ENGINE — API CONTRACT (v1.0)

**Taraflar:** Kariyer Back-end (`career_engine`, FastAPI) ↔ Front-end (`ProjectSRPG`, Flutter)
**Komşu servis:** Maç Motoru (`match_engine`, FastAPI) — bkz. [`API_CONTRACT.md`](../../API_CONTRACT.md) v1.1

---

## İMZA BLOĞU

| | |
|---|---|
| **Sürüm** | **v1.0** — uygulanabilir. Karar kaydı §0, açık maddeler §10 |
| **Tarih** | 2026-08-19 |
| **Back-end** | ⏳ imza bekliyor — `career_engine` henüz yazılmadı |
| **Front-end** | ⏳ okunmadı |

**Dayandığı bağlayıcı kararlar:** §0'da **41 karar** (D1-D41), üç ayrı tur.
**Garantiler:** §8'de **29 invariant** (INV-1 … INV-29).

> **Kaynak kuralı:** `API_CONTRACT.md`'deki disiplinin hafif hâli. Her alanın
> yanında ya bir FE `dosya:satır` referansı (alanın *neden* var olduğunu
> gösterir) ya da **"türetilmiş"** notu vardır. Kaynaksız alan yoktur.

> **Açık maddeler imzayı engellemez.** §10'daki üç madde (AÇIK-5, AÇIK-8,
> AÇIK-9) **bilinçli olarak ertelenmiştir**; hiçbiri şemayı, uç listesini veya
> bir yanıt gövdesinin şeklini bağlamaz. Üçü de tek fonksiyonun içi ya da tek
> veri dosyası satırıdır.
>
> Ertelenmiş her değerin geçtiği yer metinde **⟦AÇIK-n⟧** işaretiyle
> gösterilmiştir. Karar verildiğinde düzenlenecek noktalar
> `grep "⟦AÇIK" CONTRACT.md` ile bulunur; tam liste §10.2'dedir.
> **Bu düzenlemeler sürüm numarasını değiştirmez** — alan zaten şemadadır,
> dolan yalnızca değeridir.

---

## 0. KARAR KAYDI

2026-08-19 tarihli karar turunda alınanlar:

| # | Karar | Seçilen | Gerekçe |
|---|---|---|---|
| D1 | Dil / framework | **Python + FastAPI** | `match_engine` ile aynı yığın: aynı envelope/hata idiomu, aynı pytest disiplini |
| D2 | Kalıcı depo | **SQLite** | Yerel tek oyunculu oyun; kurulum yok, transaction var, kariyer = dosya |
| D3 | Topoloji | **FE ikisiyle ayrı konuşur** | İmzalı `API_CONTRACT.md` korunur; motor tek başına çalışabilir kalır |
| D4 | Dünya derinliği | **Kullanıcı bireysel + takım rating** | Motorun 1. müşteri kararıyla ("sen takımsın") uyumlu |
| D5 | Zaman | **Gün bazlı + sonraki olaya atla** | Beş ekran da günlük seçim mantığında; takvim `kickoff_at`'a kaynak olur |
| D6 | Kullanıcı → maç köprüsü | **ERTELENDİ** | §10 AÇIK-1. Şema kararı beklemez; `compute_team_rating()` tek geçit noktasıdır |
| D7 | Takım verisini motora geçirme | **Motora yeni `POST /matches`** | Saf ekleme; imzalı hiçbir uç değişmez |
| D8 | Ligin diğer maçları | **Motorda `POST /simulate/batch`** | Aynı motor, aynı dağılım → tutarlı lig tablosu |
| D9 | Dünya üretimi | **Sabit takımlar + seed'li fikstür** | FE zaten isimli bir dünya varsayıyor; tekrar oynanabilirlik seed'den gelir |
| D10 | Kayıt modeli | **Tek `.db`, `career_id` ile çoklu** | Kariyer listesi tek sorgu; silme tek transaction |
| D11 | Şema yönetimi | **Ham `sqlite3` + numaralı `.sql`** | Okuma ağırlıklı domain, basit sorgular; mevcut kod tabanının düz üslubu |
| D12 | Süreç | **Önce hafif contract** | Şema hatasını veri yazılmadan yakalamak |

İkinci turda (taslak okunduktan sonra) alınanlar:

| # | Karar | Seçilen | Gerekçe |
|---|---|---|---|
| D13 | Bireysel istatistik kaynağı | **Yalnızca minigame** | Motorda başka bireysel sinyal yok; uydurulmuş sayı üretilmez |
| D14 | Lig ölçeği | **18 takım, çift devreli, 34 hafta** | Şampiyonluk yarışı ve düşme hattı anlam kazansın |
| D15 | Kondisyon | **Tek kavram, tavanlı** | FE'de tek etiket; antrenman tavanı yükseltir, günlük yaşam değeri oynatır |
| D16 | Katalog sahipliği | **Veri BE'de, sunum FE'de** | Denge sayıları tek yerde ve doğrulanabilir |

Üçüncü turda (kapsam artışı) alınanlar:

| # | Karar | Seçilen | Gerekçe |
|---|---|---|---|
| D17 | Takım renkleri | **2 renk, ham hex, BE'de** | Renk *kimlik*tir, tema değil — FE hiçbir yerden türetemez |
| D18 | Çoklu müsabaka | **Piramit + paralel + lig/kupa/uluslararası** | Üçü de `competition` soyutlamasında yaşar |
| D19 | Diğer müsabakaların simülasyonu | ~~Amortize tembel simülasyon~~ → **D40 ile kaldırıldı** | Gerekçesi olan bekleme riski ölçümle çürüdü (AÇIK-7) |
| D20 | v1 dünyası | **Tek ülke, 2 kademe + kupa** | Şema üçünü taşır; veri dosyası küçük başlar, sonra büyür |
| D21 | Başlangıç kademesi | **Daima alt kademe** | Yükseliş oyunun ana yayı |
| D22 | Uluslararası format | **Grup + eleme (16 takım)** | v1'de kapalı; şema ve üreteç hazır |
| D23 | İlişki modülü ve deposu | **Aynı SQLite + JSON kolonu; ayrı paket, ayrı servis değil** | Ayrı süreç INV-3/INV-9'u kırar; şema esnekliği `traits` ile zaten sağlanıyor |
| D24 | İlişki skoru | **Saklanır** (türetilmez) | Okuma hızlı, formül serbest; sapma tek yazma noktasıyla engellenir (INV-15) |

Dördüncü turda (para) alınanlar:

| # | Karar | Seçilen | Gerekçe |
|---|---|---|---|
| D25 | Para modeli | **Saklanan bakiye + kasa defteri, tek yazma noktası** | "Tek kavram": her hareket tek defterden geçer; D24 kalıbının aynısı |
| D26 | Maaş ritmi | **Haftalık, her Pazartesi** | Sözleşme ekranı zaten haftalık; atlama sırasında da doğru işler |
| D27 | Düzenli gider | **Satın alınanlara bağlı** | Satın alma kararı uzun vadeli taahhüde dönüşür |
| D28 | Mutasyon yanıtları | **Tam `career_state` bloğu** | FE'nin paylaşılan state'i tek atışta tazelenir, ayıklama mantığı gerekmez |
| D29 | Gider ödenemezse | **Eşya elden çıkar** (%50 iade) | INV-5 korunur, yeni durum alanı gerekmez; sertliği önceden uyarı dengeler |

Beşinci turda (nitelikler) alınanlar:

| # | Karar | Seçilen | Gerekçe |
|---|---|---|---|
| D30 | Nitelik modeli | **Radar = model, 11 nitelik** | Ekranda ne görülüyorsa model o; gizli nitelik yok |
| D31 | Kişi niteliklerinin gelişimi | **Aksiyonla** (antrenman gibi) | Fiziksel tarafla simetrik, kullanıcı kontrolü net |
| D32 | Yaş eğrisi | **Yok** | Nitelikler yalnızca kazanılır; azalma mekaniği v1'de yok |

Altıncı turda (motor iletişimi) alınanlar:

| # | Karar | Seçilen | Gerekçe |
|---|---|---|---|
| D33 | Kullanıcının maçında veri kanalı | **FE taşır** — D3 yeniden değerlendirildi ve korundu | Kariyer BE motora yalnızca toplu simülasyon için bağlanır; en az bağımlılık |
| D34 | Müdahale/minigame sonuçları | **FE raporlar** | Motora ek uç gerekmez; doğruluk FE'nin defter tutmasına bağlı, katı doğrulamayla telafi edilir |

Yedinci turda (şöhret) alınanlar:

| # | Karar | Seçilen | Gerekçe |
|---|---|---|---|
| D35 | Şöhret — depolama | **Anahtarlı tablo + olay günlüğü, tek yazma noktası** | Tek skalar sonradan boyut kazanırsa migrasyon ister; anahtarlı tablo bugün tek satır, yarın N satır |
| D36 | Şöhret — anlamı | **ERTELENDİ** | §10 AÇIK-9. Depolama kararı beklemez; tanım geldiğinde tek fonksiyon dolar |

Sekizinci turda (kullanıcı ↔ maç bağı) alınanlar — **AÇIK-1 kapandı**:

| # | Karar | Seçilen | Gerekçe |
|---|---|---|---|
| D37 | Nitelik → takım rating bağı | **Bağ yok** | Oyuncunun rating'i hiçbir takım rating'ine dokunmaz, maç akışını etkilemez. Tek kanal ileride minigame zorluğudur |
| D38 | Kondisyon sürekliliği | **Maç kariyerden başlar, biter, geri yazılır** | Maç ekranındaki kondisyon oyuncunun kendi kondisyonudur; "takım kondisyonu" diye bir kavram yoktur |
| D39 | Kondisyonun maça etkisi | **Yok — paralel sayı** | Motorun `Team.stamina`'sına girmez; erime hızı yalnızca `effort`'a bağlıdır |
| D40 | Arka plan simülasyonu | **Hepsi anında koşar** — D19 kaldırıldı | Ölçüm 1,86 ms/maç çıktı (AÇIK-7); erteleme makinesi kazandırdığından fazlasını karmaşıklık olarak geri alıyordu |
| D41 | Aksiyon maliyet/getiri modeli | **Haritalar + kaynak-anahtarlı günlük bütçe** | Her aksiyonun kendine özel götürüsü ve getirisi var; sabit alan seti bunu taşıyamaz |

> **D39, D38'in mekanizmasını belirler ve kapsamını daraltır.** Kondisyon
> motorun `Team.stamina`'sına **hiç girmez** — o alan tanımıyla
> (*"kadro ortalama tazeliği"*, **[İ-6]**) ve davranışıyla yerinde kalır,
> kalibrasyon hiç etkilenmez. Değişen tek imzalı madde **[İ-23]**: maç
> ekranındaki çubuk artık zarfa eklenen yeni `player.condition` alanını
> gösterir. Kapsam §7.3'tedir; **FE'nin teyidi gerekir ama dardır.**

**Varsayılan olarak alınan küçük kararlar (itiraza açık):**
Klasör `career_engine/`, `match_engine` ile kardeş · ayrı git deposu · port **8001** ·
kimlik doğrulama **yok** (motorla aynı) · tarih/saat **ISO-8601 TEXT**, tek saat dilimi `+03:00`.

---

## 1. KAPSAM

### 1.1 Bu servis neyin sahibi

| Alan | İçerik |
|---|---|
| **Kariyer** | Kayıt oluşturma/listeleme/silme, seed, oyuncu künyesi |
| **Zaman** | Takvim, gün ilerletme, aksiyon bütçesi, sezon sınırları |
| **Oyuncu** | Nitelikler, kondisyon, para, sezon istatistikleri, sözleşme |
| **Dünya** | Müsabakalar (lig piramidi, paralel ligler, kupa, uluslararası), takımlar, güçler, renkler, fikstür, puan durumu, terfi/düşme |
| **İlişki** | Beş ilişki kategorisi, skorlar, kişi künyeleri, etkileşim geçmişi |
| **İçerik** | Haber akışı, katalog (antrenman / yaşam / dükkân) |
| **Maç kaydı** | Biten maçın sonucu, istatistikleri ve kullanıcı katkısı |

### 1.2 Bu servisin KAPSAMADIĞI — açıkça dışarıda

| Konu | Nerede |
|---|---|
| Maç simülasyonu, tick, SSE, müdahale, minigame | `match_engine` — `API_CONTRACT.md` |
| Diğer takımların isimli kadroları | **v1'de yok** (D4). Rakip takım = isim + 4 rating |
| Transfer pazarı, sakatlık sistemi, gençlik akademisi | v2 |
| Kimlik doğrulama, çok kullanıcı, bulut kayıt | v2 |
| Ekran görselleri: ikon, tema tonu, animasyon | FE'nin — §5.8 |
| LLM üretimli haber/diyalog metni | v2. v1'de şablon + veri |
| **Paralel ligler (yabancı ülkeler)** | **Şema taşır, v1 veri dosyasında yok** — D20 |
| **Uluslararası müsabaka** | **Şema ve üreteç hazır, v1'de kapalı** — D20, D22 |

**D20 — "küçük başla" ne demek:** §3.3'teki şema piramidi, paralel ligleri ve üç
müsabaka türünü **bugünden** taşır; migrasyon gerekmeyecek. Kısıtlanan yalnızca
başlangıç **veri dosyası**: v1'de tek ülke, iki kademe (18 + 14 takım) ve bir
kupa. Üçüncü kademe, yabancı lig veya uluslararası müsabaka eklemek, veri
dosyasına satır eklemekten ibarettir — kod ve şema değişmez.

### 1.3 Sınır kuralı

**Bu servis çizime hazır METİN üretmez, VERİ üretir.**
`API_CONTRACT.md` §4.1'de motor için tersi karar alınmıştı (motor hazır satır taşır),
çünkü maç anlatımı akış hâlinde ve zamana bağlıydı. Burada durum farklı: kariyer
verisi durağan ve FE onu zaten kendi biçimlendiriyor
([`player_state.dart:29`](../lib/state/player_state.dart) `moneyLabel`,
[`player_profile_screen.dart:118`](../lib/screens/player_profile_screen.dart) `passAccuracyLabel`).
**Sayıyı BE verir, etiketi FE yazar.** Tek istisna §5.7'deki katalog metinleri ve
haber gövdeleri — onlar zaten içeriktir.

**Renk için ayrım (D17):** kural "renk FE'de kalır" değil, **tema rengi FE'de,
kimlik rengi BE'de**. Kartın gövde tonu bir tasarım kararıdır — FE'nin. Deniz
SK'nın lacivert olması ise bir *veri*dir: FE onu hiçbir şeyden türetemez, tıpkı
takımın adını türetemediği gibi. Bu yüzden `team.color_primary` /
`color_secondary` BE'den gelir; ekranın zemini, gölgesi, vurgu tonu gelmez.

---

## 2. TOPOLOJİ

```
                    ┌──────────────────────────┐
                    │  ProjectSRPG (Flutter)   │
                    └───┬──────────────────┬───┘
              :8001     │                  │     :8000
        kariyer/dünya   │                  │  tek maç, SSE
                        ▼                  ▼
            ┌───────────────────┐   ┌──────────────────┐
            │  career_engine    │   │   match_engine   │
            │  (SQLite)         │   │   (bellekte)     │
            └─────────┬─────────┘   └──────────────────┘
                      │                       ▲
                      └───────────────────────┘
                       POST /simulate/batch
                       (kullanıcının oynamadığı maçlar — D8, D19)
```

**Akış — kullanıcının maçı:**

1. FE → `GET /careers/{id}/matches/next` → kariyer BE maç kurulumunu döner
   (iki takımın rating'i, `user_side`, `fixture_id`).
2. FE → `POST /matches` (**motor**, yeni uç, D7) → `match_id`.
3. FE → `POST /matches/{match_id}/start` + SSE — **mevcut imzalı akış, değişiklik yok**.
4. Maç bitince FE → `POST /careers/{id}/matches/{fixture_id}/result` → kariyer BE
   sonucu yazar, **kullanıcının içinde olduğu müsabakaların** o haftasını
   `POST /simulate/batch` ile koşar, puan durumunu ve haberleri günceller.

**Akış — diğer müsabakalar:** `POST /advance` her gün ilerlettiğinde, o güne
düşen bütün fikstürler bütün müsabakalarda hemen koşar (§6.7, D40) — bir maç
haftasının tamamı ~32 ms. Sunucu-sunucu tek çağrı.

### 2.1 Neden kullanıcının maçını FE taşıyor (D33)

Bu karar **iki kez alındı**: D3'te (topoloji turu) ve D33'te, D7/D8 motora zaten
iki uç eklendikten sonra yeniden değerlendirilerek. Alternatif — kurulumu ve
sonuç çekimini sunucu-sunucu yapmak — tartışıldı ve **reddedildi**: kariyer BE'yi
motora iki noktada daha bağımlı kılıyor, `502 engine_unavailable` yüzeyini
büyütüyordu.

Kabul edilen üç bedel, gizlenmeden:

| Bedel | Ne demek | Hafifletme |
|---|---|---|
| **Veri iki kez tanımlı** | 13 anahtarlık istatistik bloğu motorda, FE'de ve kariyer BE'de ayrı ayrı yaşar | M2 gövdesi **katı doğrulanır** (§5.6): eksik veya tanınmayan anahtar `422` verir, sapma sessiz kalmaz |
| **Kurtarma FE'ye bağlı** | Kariyer BE `match_id`'yi ancak sonuç yazılırken öğrenir; maç yarım kalırsa motordan kendi çekemez | §6.4 — `abandon` ile fikstür `scheduled`'a döner ve yeniden oynanır |
| **Bireysel istatistik FE defterine bağlı** | Gol sayısı (D13) FE'nin tuttuğu müdahale kaydından gelir | `action_key` ve `outcome_key` motorun kataloğuna göre doğrulanır (§5.6) |

> ⚠️ **Kalan risk:** 4. adım FE'ye bağlıdır. Uygulama maç bitip sonuç yazılmadan
> kapanırsa fikstür `in_progress` kalır. Telafi §6.4'tedir ve **bu, tasarımın
> bilinen sınırıdır** — kapatmanın yolu D33'ü tersine çevirmekten geçer.

---

## 3. VERİ MODELİ

SQLite. Bütün tarihler `TEXT` ISO-8601. Bütün tablolar `career_id` taşır (D10).
`PRAGMA foreign_keys = ON`.

### 3.1 Kariyer ve durum

```sql
CREATE TABLE career (
  career_id     TEXT PRIMARY KEY,          -- 'car_' + 12 hex
  created_at    TEXT NOT NULL,
  seed          INTEGER NOT NULL,          -- D9: fikstür ve başlangıç formu bundan türer
  schema_version INTEGER NOT NULL
);

-- Kolon adı bilerek 'current_date' DEĞİL: SQLite bu ismi CURRENT_DATE
-- yerleşik anahtar sözcüğüyle karıştırır — SELECT/WHERE'de niteliksiz
-- kullanılırsa saklanan değil, gerçek bugünün tarihini döner (yalnızca
-- INSERT kolon listesi ve UPDATE...SET hedefi güvenli kalır; bu, gerçek
-- bir implementasyon hatasıyla yakalandı). Dış sözleşimdeki JSON alanı
-- yine `"current_date"` (aşağıdaki CareerState örneği) — eşleme yalnızca
-- API katmanındadır.
CREATE TABLE career_state (
  career_id     TEXT PRIMARY KEY REFERENCES career(career_id) ON DELETE CASCADE,
  game_date     TEXT NOT NULL,             -- D5: dünyanın "bugün"ü
  season_id     TEXT NOT NULL,
  money         INTEGER NOT NULL,          -- player_state.dart:7  (₺, tam sayı)
  condition     INTEGER NOT NULL           -- player_state.dart:6  (0-100)
);

-- D41: günün bütçesi. Kaynaklar AÇIK-5'te belirlenecek ('time', 'energy', …)
CREATE TABLE day_budget (
  career_id    TEXT NOT NULL REFERENCES career(career_id) ON DELETE CASCADE,
  resource_key TEXT NOT NULL,
  remaining    REAL NOT NULL,
  PRIMARY KEY (career_id, resource_key)
);
```

| Alan | FE kaynağı |
|---|---|
| `money` | [`player_state.dart:7`](../lib/state/player_state.dart) `_money = 48200` |
| `condition` | [`player_state.dart:6`](../lib/state/player_state.dart) `_condition = 72` |
| `day_budget.*` | türetilmiş — D41, §6.2. Her gün başında yeniden doldurulur |

> **Kondisyon tek kavramdır (D15).** İki sayıyla temsil edilir ama FE'de tek
> etiket taşır:
> - `career_state.condition` — **bugünkü değer**. Uyku, yemek, maç, antrenman
>   yorgunluğu bunu oynatır. Kariyer merkezindeki çubuk budur
>   ([`career_center_screen.dart:213`](../lib/screens/career_center_screen.dart)).
> - `player_attribute['condition']` — **tavan**. Yalnızca "Kondisyon Koşusu"
>   antrenmanı yükseltir, gündelik aktiviteyle değişmez. Radar grafiğindeki
>   eksen budur ([`training_radar_screen.dart:16`](../lib/screens/training_radar_screen.dart)).
>
> Bağ: `condition ≤ attribute['condition']` (INV-10). Böylece "bir ay koştum,
> 3 arttı" ile "uyudum, 14 arttı" aynı çubukta boğuşmaz — biri tavanı, diğeri
> tavanın altındaki değeri hareket ettirir.

**Maç bu değeri harcar (D38).** `career_state.condition` maça girer, maç boyunca
erir, biten değer geri yazılır — döngü §6.6'da. Yani kondisyon kariyer ile maç
arasında paylaşılan **tek bir kaynaktır**: "maç ekranındaki kondisyon" ile
"kariyer merkezindeki kondisyon" aynı sayıdır, iki ayrı kavram değildir.

### 3.2 Oyuncu

```sql
CREATE TABLE player (
  career_id   TEXT NOT NULL REFERENCES career(career_id) ON DELETE CASCADE,
  player_id   TEXT NOT NULL,
  name        TEXT NOT NULL,               -- player_state.dart:12  'Efe Kaan'
  position    TEXT NOT NULL,               -- player_state.dart:17  'Orta saha'
  birth_date  TEXT NOT NULL,               -- yaş türetilir, sabit tutulmaz
  team_id     TEXT NOT NULL,
  is_user     INTEGER NOT NULL DEFAULT 0,  -- v1'de tam olarak 1 satır 1
  PRIMARY KEY (career_id, player_id)
);

CREATE TABLE player_attribute (
  career_id     TEXT NOT NULL,
  player_id     TEXT NOT NULL,
  attribute_key TEXT NOT NULL,             -- 'condition','strength','flexibility','shooting','passing','dribbling'
  value         REAL NOT NULL,             -- 0-100
  PRIMARY KEY (career_id, player_id, attribute_key),
  FOREIGN KEY (career_id, player_id) REFERENCES player(career_id, player_id) ON DELETE CASCADE
);
```

**On bir nitelik — radar neyse model o (D30).** Gizli nitelik yoktur: her anahtar
FE'nin iki radarından birinin ekseninde karşılığını bulur. **Türkçe etiketler
FE'de kalır** (§1.3).

| Aile | `attribute_key` | Eksen | Kaynak |
|---|---|---|---|
| **saha** | `condition` | Kondisyon | [`training_radar_screen.dart:16`](../lib/screens/training_radar_screen.dart) |
| saha | `strength` | Güç | " |
| saha | `flexibility` | Esneklik | " |
| saha | `shooting` | Şut | " |
| saha | `passing` | Pas | " |
| saha | `dribbling` | Dribling | " |
| **kişi** | `charisma` | Cazibe | [`relationships_radar_screen.dart:14`](../lib/screens/relationships_radar_screen.dart) |
| kişi | `politeness` | Kibarlık | " |
| kişi | `confidence` | Özgüven | " |
| kişi | `intelligence` | Zeka | " |
| kişi | `resourcefulness` | Beceriklilik | " |

**İki aile, iki tüketici.** Ayrım keyfi değil, yapısal:

| Aile | Kim tüketiyor | Nereye gider |
|---|---|---|
| **saha** | `compute_team_rating()` (AÇIK-1), minigame zorluğu | Maça |
| **kişi** | İlişki deltaları, diyalog seçeneği kilidi, medya tepkisi, sözleşme pazarlığı | Kariyere |

`family` veritabanında **saklanmaz** — 11 anahtar sabit olduğu için kod
içindeki katalogdan okunur (INV-21).

`condition` anahtarı burada **tavanı** tutar (D15, §3.1 notu); günlük değer
`career_state.condition`'dır. Eksen adı "Kondisyon" olarak kaldı.

> **Kapsam sınırı (D30):** hız, top kontrolü, cesaret gibi nitelikler **yoktur**.
> "Radar = model" kararının bilinçli bedeli budur; eklemek için önce radar bir
> eksen kazanmalıdır — o da bir FE kararıdır ve şemayı bozmaz
> (`player_attribute` anahtar-değer olduğu için yeni anahtar migrasyon istemez).

#### Şöhret (D35 — anlamı AÇIK-9)

```sql
CREATE TABLE player_fame (
  career_id TEXT NOT NULL,
  player_id TEXT NOT NULL,
  scope     TEXT NOT NULL,                -- v1'de yalnızca 'overall'
  value     REAL NOT NULL,
  PRIMARY KEY (career_id, player_id, scope)
);

-- Sürrogat anahtar: (career_id, player_id, scope, happened_at, reason)
-- bileşiği aynı gün aynı sebeple ikinci bir olay geldiğinde çakışır
-- (ör. aynı diyalog gün içinde tekrar tetiklenirse). money_ledger zaten
-- aynı gerekçeyle sürrogat anahtar kullanıyordu.
CREATE TABLE fame_event (
  event_id    INTEGER PRIMARY KEY AUTOINCREMENT,
  career_id   TEXT NOT NULL,
  player_id   TEXT NOT NULL,
  scope       TEXT NOT NULL,
  happened_at TEXT NOT NULL,
  delta       REAL NOT NULL,
  reason      TEXT NOT NULL              -- 'match:goal', 'lifestyle:sos-taraftar' ...
);
```

**FE'de bugün karşılığı yoktur** — `şöhret`, `reputation`, `popülerlik` için
kod tabanında sıfır eşleşme. Eklenecektir; tanımı AÇIK-9'dadır.

**Neden `scope` anahtarı var (D35):** şöhret ileride boyut kazanabilir —
yerel/ulusal/uluslararası, ya da sportif ün / magazin ünü. Tek kolon o gün
migrasyon isterdi; anahtarlı tablo v1'de tek satır (`'overall'`) tutar ve
boyut eklemek satır eklemekten ibaret kalır. Bugünkü maliyeti sıfır.

**Yazma yolu D24/D25 ile aynı:** değer saklanır, `fame_event` geçmişi tutar,
ikisi tek fonksiyondan — `fame.apply(scope, delta, reason)` — aynı transaction'da
yazılır (INV-24). Aşınma, eşik, tavan gibi kurallar AÇIK-9 ile gelecek; şema
hepsini karşılar.

> **Bekleyen kanca:** [`lifestyle_screen.dart:216`](../lib/screens/lifestyle_screen.dart)
> "Taraftar Etkinliği" kaleminin açıklaması *"Tribünün gözünde değerin artar"*
> diyor ama tek etkisi `conditionDelta: -2`. Şöhret tanımlandığında bu kalemin
> ilk müşterisi odur. Katalog şeması (§5.7) bu yüzden `effects` haritasında bir
> `fame:<scope>` anahtarı taşıyabilir; AÇIK-9 kapanana kadar daima `null`.

#### Piyasa değeri

```sql
CREATE TABLE player_value_history (
  career_id  TEXT NOT NULL,
  player_id  TEXT NOT NULL,
  measured_on TEXT NOT NULL,              -- anlık görüntü tarihi
  value      INTEGER NOT NULL,            -- ₺
  PRIMARY KEY (career_id, player_id, measured_on)
);
```

[`player_profile_screen.dart:214`](../lib/screens/player_profile_screen.dart)
`_valueHistory` bunu bekliyor (`ValuePoint(label, value)`); etiket
(`'Oca 24'`) `measured_on`'dan **türetilir** (§1.3). Geçmiş eğri saklanmadan
çizilemeyeceği için bu tablo anlık görüntü tutar — sezon başı ve sezon ortası,
yılda iki kez yazılır.

**Güncel değer türetilmiştir**, saklanmaz: nitelikler, yaş, form ve sözleşme
süresinden hesaplanır. Formül **AÇIK-8**'dir — girdileri D30'un nitelik listesine
bağlı olduğu için ancak o oturunca yazılabilir. D32 gereği yaş bir **azaltıcı
değildir**; değer düşüşü yalnızca kötü formdan gelebilir.

> ⚠️ FE'de bu değerler bugün iki yerde ayrı ayrı sabit —
> `training_screen.dart:53`'teki yorum bunu zaten not etmiş: *"İkisi PlayerState
> bağlantısı gelince tek kaynağa katlanacak."* Bu servis o tek kaynaktır.

```sql
CREATE TABLE player_season_stat (
  career_id         TEXT NOT NULL,
  player_id         TEXT NOT NULL,
  season_id         TEXT NOT NULL,         -- '25/26'
  competition_id    TEXT NOT NULL,         -- D18: hangi müsabaka (lig kademesi dahil)
  appearances       INTEGER NOT NULL DEFAULT 0,
  starts            INTEGER NOT NULL DEFAULT 0,
  goals             INTEGER NOT NULL DEFAULT 0,
  assists           INTEGER NOT NULL DEFAULT 0,
  minutes           INTEGER NOT NULL DEFAULT 0,
  passes_completed  INTEGER NOT NULL DEFAULT 0,
  passes_attempted  INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (career_id, player_id, season_id, competition_id)
);
```

Kolonlar [`player_profile_screen.dart:46-67`](../lib/screens/player_profile_screen.dart)
`_SeasonStats`'tan birebir. Anahtar `(sezon, müsabaka)` kesiti — FE toplama işini
kendi yapıyor (`_StatTotals.of`), BE kesitleri verir.

> **D18 sonrası kırılım:** FE'nin müsabaka filtresi üç değer üzerinden çalışıyor
> ([`player_profile_screen.dart:10`](../lib/screens/player_profile_screen.dart)
> `enum _Competition { lig, kupa, uluslararasi }`). Şema artık `competition_id`
> saklıyor — çünkü "Süper Lig'deki sezonum" ile "1. Lig'deki sezonum" ayrılabilmeli.
> P2 yanıtı **her iki alanı da** taşır: `competition_id` (kesin) ve
> `competition_kind` (`competition.kind`'dan türetilmiş, FE'nin bugünkü filtresini
> bozmadan besler). `'continental'` → `'uluslararasi'` eşlemesi API katmanındadır.

**Kolonların doldurulma kaynağı (D13 — yalnızca minigame):**

| Kolon | v1'de kaynak |
|---|---|
| `appearances` | Oynanan her maç için +1 |
| `starts` | `appearances` ile aynı — v1'de kullanıcı daima ilk 11'de |
| `minutes` | +95 (motorun sabit maç uzunluğu, [`API_CONTRACT.md` §8.2](../../API_CONTRACT.md)) |
| `goals` | Golle sonuçlanan şut minigame'i sayısı (§5.6 `interventions`) |
| `assists` | **v1'de daima 0** — motorda karşılığı yok |
| `passes_completed` / `passes_attempted` | **v1'de daima 0** — motorda karşılığı yok |

> Motorda bireysel oyuncu katmanı yok (`API_CONTRACT.md` müşteri kararı 1) ve
> tek bireysel sinyal kullanıcının müdahaleleridir. Bu servis **uydurulmuş sayı
> üretmez**: dayanağı olmayan kolon 0 kalır.
>
> ✅ **FE bu duruma bugünden hazır.** `passes_attempted == 0` iken
> [`player_profile_screen.dart:118`](../lib/screens/player_profile_screen.dart)
> zaten `'Başarılı pas: —'` yazıyor. Kolonlar şemada duruyor: motora bir gün
> `Player` katmanı gelirse (`API_CONTRACT.md` §12) migrasyon gerekmez, yalnızca
> yazan kod eklenir.

```sql
CREATE TABLE player_contract (
  career_id        TEXT NOT NULL,
  player_id        TEXT NOT NULL,
  team_id          TEXT NOT NULL,
  signed_at        TEXT NOT NULL,
  expires_at       TEXT NOT NULL,
  weekly_wage      INTEGER NOT NULL,
  appearance_bonus INTEGER NOT NULL,
  goal_bonus       INTEGER NOT NULL,
  release_clause   INTEGER NOT NULL,
  PRIMARY KEY (career_id, player_id, signed_at)
);
```

Beş kalem [`contract_screen.dart:28-40`](../lib/screens/contract_screen.dart)'tan.
`aylık maaş` **türetilmiş** (`weekly_wage × 4`), saklanmaz. FE bugün "₺180.000" gibi
biçimlenmiş literal tutuyor ([`contract_screen.dart:16` yorumu](../lib/screens/contract_screen.dart));
§1.3 gereği BE tam sayı gönderir, biçimlendirme FE'ye geçer.

### 3.3 Dünya

#### Takım

```sql
CREATE TABLE team (
  career_id       TEXT NOT NULL,
  team_id         TEXT NOT NULL,
  name            TEXT NOT NULL,           -- ≤24 karakter (motorun sınırı, API_CONTRACT §8.1)
  short_name      TEXT NOT NULL,           -- 3 harf, rozet için
  country         TEXT NOT NULL,           -- paralel ligler için (D18)
  attack          REAL NOT NULL,           -- 0-100, motorun Team alanları (models.py:13-16)
  midfield        REAL NOT NULL,
  defense         REAL NOT NULL,
  goalkeeper      REAL NOT NULL,
  mentality       TEXT NOT NULL,           -- motorun 5 değeri (config.py VALID_MENTALITIES)
  color_primary   TEXT NOT NULL,           -- '#1E6FD9' — kimlik rengi (D17)
  color_secondary TEXT NOT NULL,           -- '#FFFFFF'
  PRIMARY KEY (career_id, team_id)
);
```

**Renkler (D17):** `#RRGGBB` biçiminde, sabit veri dosyasından, **ham hâliyle**.
FE `Color(0xFF + hex)` ile okur. Koyu zeminde okunabilirlik düzeltmesi FE'nin
işidir — neyin üstüne çizildiğini o bilir (§1.3).
[`_TeamBadge`](../lib/screens/career_center_screen.dart) bugün zaten
`background` + `iconColor` diye iki renk alıyor; bu ikisi onları besler.

> ⚠️ `team`'de **lig kolonu yoktur.** Takımın hangi müsabakada oynadığı sezona
> bağlıdır (düşme-çıkma), o yüzden `competition_entry`'de tutulur.

#### Müsabaka — piramit, paralel ve kupa tek soyutlamada (D18)

```sql
CREATE TABLE competition (
  career_id      TEXT NOT NULL,
  competition_id TEXT NOT NULL,
  kind           TEXT NOT NULL,            -- 'league' | 'cup' | 'continental'
  name           TEXT NOT NULL,            -- 'Süper Lig', '1. Lig', 'Ulusal Kupa'
  country        TEXT,                     -- paralel ligler; 'continental'de NULL
  tier           INTEGER,                  -- piramit seviyesi (1 = en üst); lig dışında NULL
  format         TEXT NOT NULL,            -- 'double_round_robin' | 'single_elimination'
                                           -- | 'group_then_knockout'
  team_count     INTEGER NOT NULL,
  PRIMARY KEY (career_id, competition_id)
);

-- Hangi takım, hangi sezonda, hangi müsabakada. Düşme-çıkmanın yaşadığı yer.
CREATE TABLE competition_entry (
  career_id      TEXT NOT NULL,
  season_id      TEXT NOT NULL,
  competition_id TEXT NOT NULL,
  team_id        TEXT NOT NULL,
  PRIMARY KEY (career_id, season_id, competition_id, team_id)
);

-- Terfi/düşme kuralları. Yalnızca kind='league' için dolu.
CREATE TABLE competition_rule (
  career_id                  TEXT NOT NULL,
  competition_id             TEXT NOT NULL,
  promote_count              INTEGER NOT NULL DEFAULT 0,
  relegate_count             INTEGER NOT NULL DEFAULT 0,
  promotes_to_competition_id TEXT,         -- NULL = en üst kademe
  relegates_to_competition_id TEXT,        -- NULL = en alt kademe
  PRIMARY KEY (career_id, competition_id)
);
```

**Neden `competition_entry` ayrı tablo:** düşme-çıkma istendiği an
`team.competition_id` diye sabit bir alan yanlış olur — takım her sezon başka
kademede olabilir. Bu ayrım bedavaya bir şey daha getiriyor: geçmiş sezonların
puan durumu doğru kalır, çünkü o sezonun katılımcı listesi saklıdır.

**Kapsamı tek lige özgü değildir.** Bir takım aynı sezonda birden fazla
`competition_entry` satırına sahip olabilir — v1'de her takım hem kendi
lig kademesine hem Ulusal Kupa'ya kayıtlıdır (32 takım × 2 = 64 satır).
Bu tablo "takım bu sezon hangi müsabakalarda oynuyor" sorusunun **tek**
doğruluk kaynağıdır; yalnızca lig üyeliği değil. W1'in `user_participates`'i
ve W4'ün "bu sezon oynadığı lig" çözümlemesi ikisi de buna dayanır — W4
`kind='league'` filtresiyle sorgular, çünkü aksi hâlde bir takımın kupa
satırıyla lig satırı ayrışmaz.

#### Sezon, tur ve fikstür

```sql
CREATE TABLE season (
  career_id  TEXT NOT NULL,
  season_id  TEXT NOT NULL,                -- '25/26'
  starts_on  TEXT NOT NULL,
  ends_on    TEXT NOT NULL,
  PRIMARY KEY (career_id, season_id)
);

-- Tur TAKVİMİ baştan bellidir; kupada EŞLEŞME sonradan çekilir.
CREATE TABLE competition_round (
  career_id      TEXT NOT NULL,
  season_id      TEXT NOT NULL,
  competition_id TEXT NOT NULL,
  round_no       INTEGER NOT NULL,
  stage          TEXT NOT NULL,            -- 'regular'|'group'|'r32'|'r16'|'qf'|'sf'|'final'
  scheduled_on   TEXT NOT NULL,
  drawn          INTEGER NOT NULL DEFAULT 0,  -- kura çekildi mi
  PRIMARY KEY (career_id, season_id, competition_id, round_no)
);

CREATE TABLE fixture (
  career_id      TEXT NOT NULL,
  fixture_id     TEXT NOT NULL,
  season_id      TEXT NOT NULL,
  competition_id TEXT NOT NULL,            -- D18
  round_no       INTEGER NOT NULL,
  leg            INTEGER,                  -- çift maçlı eleme (1|2); tek maçlıkta NULL
  kickoff_at     TEXT NOT NULL,            -- API_CONTRACT ÇÖZÜLMEDİ-4 burada kapanır
  home_team_id   TEXT NOT NULL,
  away_team_id   TEXT NOT NULL,
  status         TEXT NOT NULL,            -- 'scheduled' | 'in_progress' | 'played'
  home_score     INTEGER,
  away_score     INTEGER,
  match_id       TEXT,                     -- motorun ürettiği id, iz sürme için
  PRIMARY KEY (career_id, fixture_id)
);

CREATE TABLE fixture_team_stat (
  career_id   TEXT NOT NULL,
  fixture_id  TEXT NOT NULL,
  side        TEXT NOT NULL,               -- 'home' | 'away'
  goals INTEGER, shots INTEGER, shots_on_target INTEGER, corners INTEGER,
  dangerous_attacks INTEGER, total_attacks INTEGER, yellow_cards INTEGER,
  red_cards INTEGER, penalties INTEGER, penalty_goals INTEGER, fouls INTEGER,
  substitutions INTEGER, possession_ticks INTEGER,
  PRIMARY KEY (career_id, fixture_id, side)
);
```

**Ligde fikstür sezon başında bir kerede üretilir; kupada üretilemez** — 3. turun
rakibi 2. turun sonucuna bağlıdır. Bu yüzden takvim (`competition_round`) ile
eşleşme (`fixture`) ayrıldı: kullanıcı "3 Kasım'da kupa maçın var" satırını
sezon başında görür, rakibini kura çekilince öğrenir. `drawn = 1` olduğunda o
turun `fixture` satırları oluşmuştur.

`fixture_team_stat`'ın 13 kolonu motorun `_blank_stats()`
([`models.py:82-88`](../../match_engine/models.py)) anahtarlarıyla **birebir aynıdır** —
`/summary` yanıtı ([`API_CONTRACT.md` §8.3](../../API_CONTRACT.md)) doğrudan buraya yazılır.

#### Puan durumu

**Tablo değildir, VIEW'dır.** Tek doğruluk kaynağı `fixture` (INV-2):

```sql
CREATE VIEW standing AS
WITH sides AS (
  SELECT career_id, season_id, competition_id, home_team_id AS team_id,
         home_score AS gf, away_score AS ga,
         CASE WHEN home_score > away_score THEN 1 ELSE 0 END AS won,
         CASE WHEN home_score = away_score THEN 1 ELSE 0 END AS drawn,
         CASE WHEN home_score < away_score THEN 1 ELSE 0 END AS lost
  FROM fixture WHERE status = 'played'
  UNION ALL
  SELECT career_id, season_id, competition_id, away_team_id AS team_id,
         away_score AS gf, home_score AS ga,
         CASE WHEN away_score > home_score THEN 1 ELSE 0 END AS won,
         CASE WHEN away_score = home_score THEN 1 ELSE 0 END AS drawn,
         CASE WHEN away_score < home_score THEN 1 ELSE 0 END AS lost
  FROM fixture WHERE status = 'played'
)
SELECT career_id, season_id, competition_id, team_id,
       COUNT(*) AS played,
       SUM(won) AS won, SUM(drawn) AS drawn, SUM(lost) AS lost,
       SUM(gf) AS goals_for, SUM(ga) AS goals_against,
       SUM(won) * 3 + SUM(drawn) AS points
FROM sides
GROUP BY career_id, season_id, competition_id, team_id;
```

Kolonlar [`league_table_screen.dart:3-22`](../lib/screens/league_table_screen.dart)
`_StandingRow`'dan (`rank`, `played`, `won`, `drawn`, `lost`, `points`).
`rank` ve `isPlayerTeam` **türetilmiş**, saklanmaz.
`competition_id` boyutu D18 ile eklendi: her müsabakanın kendi tablosu var.
`kind='cup'` için anlamsızdır, `'continental'`de yalnızca `stage='group'`
turlarını kapsar.

#### v1 dünyası (D20, D21)

Şema yukarıdakinin tamamını taşır; **başlangıç veri dosyası** şunu içerir:

| Müsabaka | `kind` | `tier` | Takım | Format | Hafta |
|---|---|---|---|---|---|
| Süper Lig | `league` | 1 | 18 | çift devreli | 34 |
| 1. Lig | `league` | 2 | 14 | çift devreli | 26 |
| Ulusal Kupa | `cup` | — | 32 | tek maç eleme | 5 tur |

Terfi/düşme: 1. Lig'den **2 takım çıkar**, Süper Lig'den **2 takım düşer**.
Kullanıcı daima **tier 2**'de başlar (D21) — yükselmek oyunun ana yayıdır.
Uluslararası müsabaka (16 takım, 4'lü gruplar + eleme — D22) ve yabancı ülke
ligleri şemada tanımlı ama v1 veri dosyasında yoktur; eklemek satır eklemekten
ibarettir.

> ✅ FE tarafı ölçeğe hazır: lig tablosu bugün 8 sabit satır gösteriyor ama
> `ListView.builder` + `itemCount` ile yazılmış
> ([`league_table_screen.dart:136`](../lib/screens/league_table_screen.dart)).
>
> ⚠️ FE'nin bugünkü sabit lig verisi (Deniz SK · Anadolu FC · FK Yıldız …) tek
> bir ligi anlatıyor ve kullanıcının kulübü FK Yıldız. D21 gereği bu tablo **1.
> Lig (tier 2)** olarak yerleşir; Süper Lig'in 18 takımı yeni isimlerdir.
> FE'de değişen tek şey ekran başlığının artık veriden gelmesi.

### 3.4 İlişkiler

**Modül sınırı (D23).** İlişkiler ayrı bir bounded context'tir ama **ayrı servis
değildir** — `career_engine/relationships/` paketi kendi repository'si ve kendi
arayüzüyle yaşar; başka modüller bu tablolara SQL join'le değil yalnızca o
arayüzden erişir. Ayrı süreç yapmamanın gerekçesi INV-3 ve INV-9: bir diyalog
seçimi aynı anda kondisyonu, süreyi ve ilişkiyi değiştiren **tek bir aksiyondur**
ve tek transaction'da yazılmalıdır. Sınır bu yüzden süreç sınırı değil, paket
sınırı. Bir gün gerçekten ayrılması gerekirse ayrılacak yer zaten belli.

```sql
CREATE TABLE relationship (
  career_id       TEXT NOT NULL,
  relationship_id TEXT NOT NULL,           -- 'coach','team','media','partner','family'
  kind            TEXT NOT NULL,           -- traits'i hangi modelin doğrulayacağı
  category        TEXT NOT NULL,           -- FE'nin kart başlığı: 'Antrenör' vb.
  score           INTEGER NOT NULL,        -- 0-100, SAKLANIR (D24)
  person_name     TEXT NOT NULL,
  contact_name    TEXT NOT NULL,           -- rehberdeki kısa ad
  age             INTEGER,
  occupation      TEXT,
  bio             TEXT,
  last_contact_at TEXT,
  traits          TEXT NOT NULL DEFAULT '{}',  -- JSON, türe özel alanlar (D23)
  PRIMARY KEY (career_id, relationship_id)
);

-- Sürrogat anahtar: aynı gerekçeyle fame_event'te de kullanılan çözüm —
-- aynı gün aynı sebeple ikinci bir etkileşim (diyalog tekrarı, bir decay
-- tick'i) bileşik anahtarda çakışırdı.
CREATE TABLE relationship_event (
  event_id INTEGER PRIMARY KEY AUTOINCREMENT,
  career_id TEXT NOT NULL, relationship_id TEXT NOT NULL,
  happened_at TEXT NOT NULL,
  delta INTEGER NOT NULL,                  -- skora etki
  reason TEXT NOT NULL                     -- 'dialogue:coach_01:choice_2', 'match:win' ...
);
```

Alanlar [`relationships_screen.dart:396-435`](../lib/screens/relationships_screen.dart)
`_RelationshipData`'dan. **Beş kategori** [`relationships_screen.dart:31,90,135,191,236`](../lib/screens/relationships_screen.dart):
Antrenör · Takım Arkadaşları · Medya · Partner · Aile/Sosyal Çevre.
`status` ("Güven seviyesi yüksek") ve `dateLabel` ("2 gün önce") **türetilmiştir** —
BE `score` ve `last_contact_at` verir, cümleyi FE kurar (§1.3).

`icon`, `tint`, `badgeCode` **gönderilmez** — FE'nin sunum katmanı (§5.8).

#### `traits` — türe özel alanlar (D23)

Her ilişki türünün gereklilikleri farklı: Partner'ın "birlikte geçen süre"si,
Medya'nın "manşet tonu"su, Antrenör'ün "oynama süresi vaadi" var. Bunları beş
ayrı tabloya bölmek de tek geniş tabloya doldurmak da yanlış olurdu.

Çözüm ayrı bir veritabanı değil, **JSON kolonu**: ortak olan alanlar (kimlik,
skor, son temas, olay günlüğü) ilişkisel kalır; değişen alanlar `traits`
içinde yaşar. SQLite'ın `json_extract()`'i sorgulamayı karşılar. Şema
doğrulaması **kod tarafındadır**: her `kind` için ayrı bir Pydantic modeli.

```jsonc
// kind='partner'
{ "together_since": "2025-11-02", "gift_count": 3, "mood": "özlemiş" }
// kind='media'
{ "outlet": "Spor Manşet", "tone": "olumlu", "interviews_given": 7 }
// kind='coach'
{ "trust": 74, "promised_minutes": 60, "tactical_fit": 0.8 }
```

> ⚠️ `json_extract()` SQLite'ın JSON1 uzantısını gerektirir (3.38+'da varsayılan
> olarak derli). Kurulumda tek satırlık sürüm kontrolü yapılacak.

`relationship_hobby` tablosu **kaldırıldı** — hobiler bir liste ve `traits`
içinde doğal yeri var; ayrı tabloyu hak edecek bir sorgusu yok.

#### Skor saklanır, günlük iz sürer (D24)

`score` doğrudan yazılan bir kolondur; `relationship_event` geçmiş görünümü ve
denetim izidir, doğruluk kaynağı değil. Bu, contract'ın başka yerlerindeki
türetme tercihinden (puan durumu `fixture`'dan — INV-2) **bilinçli bir
ayrılıştır**: okuma en hızlı yoldan olur ve aşınma/eşik gibi formüller serbest
kalır.

İki kaynağın sapma riski **yapısal olarak** kapatılır (INV-15): skor ve olay
**tek bir fonksiyondan**, tek transaction içinde yazılır —
`relationships.apply_delta(rid, delta, reason)`. Başka hiçbir yer `score`
kolonuna yazmaz. Ayrıca bir test, olay günlüğünü baştan oynatıp skoru yeniden
hesaplar ve tutmazsa kırılır; sapma sessizce yaşayamaz.

Zamanla aşınma (uzun süre temas edilmezse skorun düşmesi) bu modelde kolaydır:
`POST /advance` sırasında aynı fonksiyondan negatif bir delta yazılır, günlükte
`reason = 'decay'` olarak görünür.

### 3.5 İçerik ve günlük

```sql
CREATE TABLE news (
  career_id  TEXT NOT NULL, news_id TEXT NOT NULL,
  published_at TEXT NOT NULL,
  category   TEXT NOT NULL,                -- 'Transfer','Maç','Röportaj','Analiz'
  title      TEXT NOT NULL,
  source     TEXT NOT NULL,                -- 'Spor Manşet','Lig Ajansı' ...
  body       TEXT NOT NULL,                -- \n\n ile ayrılmış paragraflar
  fixture_id TEXT,                         -- maç haberiyse ilişkili fikstür
  PRIMARY KEY (career_id, news_id)
);

-- Sürrogat anahtar: aynı gün aynı catalog_id ikinci kez yapılırsa (bunu
-- engelleyen bir kural yok — day_budget yalnızca kalan havuzu izler)
-- bileşik anahtar çakışırdı; relationship_event/fame_event/money_ledger'la
-- aynı gerekçe.
CREATE TABLE activity_log (
  activity_id   INTEGER PRIMARY KEY AUTOINCREMENT,
  career_id     TEXT NOT NULL,
  happened_at   TEXT NOT NULL,
  kind          TEXT NOT NULL,             -- 'training' | 'lifestyle' | 'relationship' | 'purchase'
  catalog_id    TEXT NOT NULL,             -- 'ev-uyku', 'sut' ...
  applied_costs   TEXT NOT NULL,           -- JSON: gerçekte harcanan bütçe (D41)
  applied_effects TEXT NOT NULL,           -- JSON: gerçekte uygulanan etkiler (D41)
  payload       TEXT                       -- JSON: minigame skoru gibi girdi verisi
);

CREATE TABLE inventory (
  career_id TEXT NOT NULL, item_id TEXT NOT NULL,
  purchased_at   TEXT NOT NULL,
  price_paid     INTEGER NOT NULL,
  upkeep_weekly  INTEGER NOT NULL DEFAULT 0,   -- D27: alım anındaki gider, dondurulur
  PRIMARY KEY (career_id, item_id)
);
```

`activity_log.money_delta` **kaldırıldı** (D25) — para hareketinin tek evi
`money_ledger`. Aktivite kaydı ne yapıldığını, defter ne ödendiğini tutar.

`inventory.upkeep_weekly` alım anında katalogdan kopyalanır ve **dondurulur**;
`price_paid` ile aynı gerekçe: katalog sonradan değişse de geçmiş kayıt bozulmaz.

#### Kasa defteri (D25)

```sql
CREATE TABLE money_ledger (
  career_id   TEXT NOT NULL,
  ledger_id   INTEGER PRIMARY KEY AUTOINCREMENT,
  happened_at TEXT NOT NULL,
  amount      INTEGER NOT NULL,            -- + gelir, − gider
  kind        TEXT NOT NULL,               -- 'wage'|'appearance_bonus'|'goal_bonus'
                                           -- |'purchase'|'upkeep'|'lifestyle'|'sale'
  reason      TEXT NOT NULL,               -- 'wage:2026-W11', 'purchase:ev-daire' ...
  balance_after INTEGER NOT NULL           -- denetim izi
);

CREATE INDEX idx_ledger_career_date ON money_ledger (career_id, happened_at);
```

**"Para tek kavram" bunun için var (D25).** Maaş, prim, alışveriş, yaşam
masrafı, düzenli gider — hepsi aynı defterden geçer. `career_state.money`
saklanan bakiyedir; defter hareket geçmişidir.

İkisi D24'teki kalıbın aynısıyla tutarlı tutulur: **tek yazma noktası** —
`wallet.apply(amount, kind, reason)`. Bakiyeyi ve defter satırını aynı
transaction'da yazar, `balance_after`'ı doldurur, INV-5'i (negatife düşmez)
orada uygular. Başka hiçbir yer `career_state.money`'ye dokunmaz (INV-17).
Defteri baştan toplayıp bakiyeyle karşılaştıran bir test sapmayı yakalar.

`news` alanları [`career_center_screen.dart:593-640`](../lib/screens/career_center_screen.dart)
`NewsItem`'dan; `timeAgo` **türetilmiş** (`published_at` − `current_date`).
`inventory`, [`player_state.dart:46`](../lib/state/player_state.dart)'daki
`_owned` kümesinin kalıcı hâli.
`activity_log`, antrenman kartlarındaki `lastDone` ("2 gün önce yapıldı",
[`training_screen.dart:59`](../lib/screens/training_screen.dart)) satırının kaynağıdır.

**Katalog tabloları yoktur.** Antrenman/yaşam/dükkân katalogları kod içinde veri
dosyasıdır, kariyere kopyalanmaz — yalnızca *yapılanlar* ve *alınanlar* loglanır.
Katalog fiyatı sonradan değişirse geçmiş kayıt `price_paid` ile korunur.

---

## 4. ENDPOINT TABLOSU

Taban: `http://127.0.0.1:8001`

| # | Metot | Yol | Ne yapar |
|---|---|---|---|
| **Kariyer** ||||
| C0 | `GET` | `/careers/options` | Yeni kariyerde seçilebilir kulüpler ve pozisyonlar |
| C1 | `POST` | `/careers` | Yeni kariyer: seed, oyuncu adı, pozisyon, kulüp seçimi |
| C2 | `GET` | `/careers` | Kariyer listesi (kayıt ekranı) |
| C3 | `GET` | `/careers/{cid}` | Kariyer merkezi özeti — tek çağrıda hub verisi |
| C4 | `DELETE` | `/careers/{cid}` | Kariyeri sil |
| **Oyuncu** ||||
| P1 | `GET` | `/careers/{cid}/player` | Künye + altı nitelik + kondisyon + para |
| P2 | `GET` | `/careers/{cid}/player/stats` | `?season=&competition=` → kesit listesi |
| P3 | `GET` | `/careers/{cid}/player/contract` | Sözleşme kalemleri |
| **Dünya** ||||
| W1 | `GET` | `/careers/{cid}/competitions` | Müsabaka listesi: piramit, paralel ligler, kupalar |
| W2 | `GET` | `/careers/{cid}/standings` | `?competition=&season=` → puan durumu (D18) |
| W3 | `GET` | `/careers/{cid}/fixtures` | `?competition=&round=&team_id=&status=` |
| W4 | `GET` | `/careers/{cid}/teams/{tid}` | Takım künyesi + renkler |
| **İlişki** ||||
| R1 | `GET` | `/careers/{cid}/relationships` | Beş kart |
| R2 | `GET` | `/careers/{cid}/relationships/{rid}` | Profil künyesi + son etkileşimler |
| R3 | `POST` | `/careers/{cid}/relationships/{rid}/interact` | Diyalog sonucunu uygular |
| **Zaman** ||||
| T1 | `GET` | `/careers/{cid}/day` | Bugün: tarih, kalan aksiyon, bugünkü olaylar |
| T2 | `POST` | `/careers/{cid}/actions` | Antrenman / yaşam aktivitesi uygular |
| T3 | `POST` | `/careers/{cid}/advance` | `{to: "next_day"\|"next_event"}` |
| T4 | `POST` | `/careers/{cid}/purchases` | Dükkândan satın alır |
| **Maç** ||||
| M1 | `GET` | `/careers/{cid}/matches/next` | Maç kurulumu — motora verilecek payload dahil |
| M2 | `POST` | `/careers/{cid}/matches/{fid}/result` | Sonucu yazar + haftayı simüle eder |
| M3 | `POST` | `/careers/{cid}/matches/{fid}/abandon` | Yarım kalan maçı kurtarır (§6.4) |
| **İçerik** ||||
| N1 | `GET` | `/careers/{cid}/news` | `?limit=&before=` |
| N2 | `GET` | `/careers/{cid}/news/{nid}` | Tam gövde |
| N3 | `GET` | `/catalog/{kind}` | `training` \| `lifestyle` \| `shop` — kariyerden bağımsız |

**Her ucun istek ve yanıt gövdesi §5'tedir.** Ortak nesneler (`CareerState`,
`TeamRef`, `CompetitionRef`, `LedgerEntry`), kimlik biçimleri, sayfalama ve
zarf kuralları §5.0'da bir kez tanımlanır.

**Zarf ve hata biçimi** `match_engine` ile aynıdır
([`envelope.py`](../../match_engine/api/envelope.py), [`errors.py`](../../match_engine/api/errors.py)):
`{"code": "...", "message": "..."}` — düz, `"error"` sarmalayıcısı yok.

**Durumu değiştiren her uç** (T2, T3, T4, R3, M2, M3) yanıtında tam
`CareerState` bloğunu taşır (D28, INV-18).

---

## 5. UÇ ŞARTNAMESİ

Bu bölüm §4'teki her ucun istek ve yanıt gövdesini tanımlar. Tekrarı önlemek
için ortak nesneler §5.0'da bir kez tanımlanır ve aşağıda adlarıyla anılır.

> **⟦AÇIK-n⟧ işareti**, değeri veya davranışı henüz kararlaştırılmamış bir
> noktayı gösterir (§10). İşaretin bulunduğu alan **şemada vardır ve tipi
> kesindir**; belirsiz olan yalnızca üretilen değerdir. Gelecekte düzenlenecek
> yerler `grep "⟦AÇIK" CONTRACT.md` ile bulunur.

---

### 5.0 Ortak nesneler

#### `CareerState` — durumu değiştiren **her** yanıtta bulunur (D28, INV-18)

```jsonc
{ "current_date": "2026-03-14",
  "season_id":    "25/26",
  "money":        48200,
  "condition":    72,
  "day_budget":   { "time": 330, "energy": 62 }   // D41 · anahtarlar ⟦AÇIK-5⟧
}
```

FE'nin paylaşılan state'i ([`PlayerState`](../lib/state/player_state.dart))
bu bloktan tazelenir. Alanların hangi ekranda göründüğü BE'yi ilgilendirmez.

#### `TeamRef` — takım gösterilen her yerde

```jsonc
{ "team_id":         "t_ykz",
  "name":            "FK Yıldız",     // ≤24 karakter (motorun sınırı)
  "short_name":      "YKZ",
  "color_primary":   "#1E6FD9",       // D17 · kimlik rengi, ham
  "color_secondary": "#FFFFFF"
}
```

#### `CompetitionRef`

```jsonc
{ "competition_id": "c_lig2",
  "kind":           "league",          // 'league' | 'cup' | 'continental'
  "name":           "1. Lig",
  "country":        "TR",              // 'continental'de null
  "tier":           2                  // lig dışında null
}
```

#### `LedgerEntry` — para hareketi olan yanıtlarda (D25)

```jsonc
{ "happened_at": "2026-03-14T09:00:00+03:00",
  "amount":      -250,                 // + gelir, − gider
  "kind":        "lifestyle",          // §3.5'teki kind kataloğu
  "reason":      "lifestyle:ev-yemek",
  "balance_after": 48200 }
```

#### Ortak kurallar

| Konu | Kural |
|---|---|
| **Kimlikler** | `car_` kariyer · `t_` takım · `c_` müsabaka · `f_` fikstür · `n_` haber · `p_` oyuncu. Hepsi opak string; FE ayrıştırmaz |
| **Tarih/saat** | ISO-8601. Yalnız gün taşıyanlar `YYYY-MM-DD`, an taşıyanlar `+03:00` ofsetli |
| **Para** | Tam sayı, ₺, kuruş yok. Biçimlendirme FE'de (§1.3) |
| **Sayfalama** | `?limit=` (varsayılan 20, en fazla 100) + `?before=` imleci. Yanıt `next_before` döner; `null` ise liste bitti |
| **Bilinmeyen alan** | FE tanımadığı alanı **yok sayar**. Yanıta alan eklemek kırıcı değildir; alan kaldırmak kırıcıdır |
| **Hata gövdesi** | `{"code": "...", "message": "..."}` — `match_engine` ile aynı, düz gövde ([`errors.py`](../../match_engine/api/errors.py)) |
| **Kimlik doğrulama** | Yok (motorla aynı karar) |

---

### 5.1 Kariyer

#### C0 · `GET /careers/options` — yeni kariyer seçenekleri

```jsonc
{ "positions": ["Kaleci", "Defans", "Orta saha", "Forvet"],
  "clubs": [                                   // D21: yalnızca alt kademe
    { "team": { /* TeamRef */ },
      "competition": { /* CompetitionRef */ },
      "strength_hint": "orta" }                // 'zayıf' | 'orta' | 'güçlü'
  ] }
```

`clubs` **yalnızca `tier` en alt olan müsabakanın takımlarını** taşır (D21 —
kullanıcı daima alt kademede başlar). `strength_hint` takım rating'lerinden
türetilmiş kaba bir etikettir; ham rating gönderilmez.

#### C1 · `POST /careers` — yeni kariyer

```jsonc
// İstek
{ "player_name": "Efe Kaan",
  "position":    "Orta saha",
  "team_id":     "t_ykz",
  "seed":        918273 }              // opsiyonel; yoksa rastgele üretilir

// Yanıt 201 — C3 ile aynı gövde
```

`seed` fikstür sırasını ve başlangıç formunu belirler (D9). Aynı seed + aynı
kulüp → aynı dünya (INV-7). `team_id` C0'ın listesinde olmalıdır, yoksa
`422 invalid_request`.

#### C2 · `GET /careers` — kariyer listesi

```jsonc
{ "careers": [
    { "career_id":    "car_9f2a71c4e0b8",
      "player_name":  "Efe Kaan",
      "team":         { /* TeamRef */ },
      "competition":  { /* CompetitionRef */ },
      "season_id":    "25/26",
      "current_date": "2026-03-14",
      "created_at":   "2026-01-02T10:11:00+03:00",
      "standing_rank": 3 }
] }
```

#### C3 · `GET /careers/{cid}` — kariyer merkezi

Tek çağrıda hub verisi. FE'nin ana ekranı bununla dolar.

```jsonc
{ "career_id":    "car_9f2a71c4e0b8",
  "career_state": { /* CareerState */ },

  "player": { "name": "Efe Kaan", "position": "Orta saha", "age": 21,
              "team": { /* TeamRef */ } },

  "next_fixture": {
    "fixture_id":  "f_25_26_c_lig2_r13_ykz_dnz",
    "competition": { /* CompetitionRef */ },
    "round_no":    13,
    "kickoff_at":  "2026-03-16T20:00:00+03:00",
    "home":        { /* TeamRef */ },
    "away":        { /* TeamRef */ },
    "user_side":   "home",
    "days_until":  2 },

  "standing_summary": { "competition_id": "c_lig2", "rank": 3,
                        "played": 12, "points": 24,
                        "promotion_slots": 2, "relegation_slots": 2 },

  "news_preview": [ { "news_id": "n_0142", "category": "Transfer",
                      "title": "…", "source": "Spor Manşet",
                      "published_at": "2026-03-14T09:00:00+03:00" } ]
}
```

`next_fixture` sezon bittiyse `null`.

#### C4 · `DELETE /careers/{cid}`

Yanıt **204**, gövde yok. Kariyere ait hiçbir satır kalmaz (INV-9).

---

### 5.2 Oyuncu

#### P1 · `GET /careers/{cid}/player`

```jsonc
{ "player_id":   "p_user",
  "name":        "Efe Kaan",
  "position":    "Orta saha",
  "birth_date":  "2004-08-19",
  "age":         21,                    // türetilmiş
  "team":        { /* TeamRef */ },
  "career_state": { /* CareerState */ },

  "attributes": [                        // D30 · tam 11 anahtar, eksiksiz
    { "key": "condition",       "family": "saha", "value": 64.0 },
    { "key": "strength",        "family": "saha", "value": 38.0 },
    { "key": "flexibility",     "family": "saha", "value": 92.0 },
    { "key": "shooting",        "family": "saha", "value": 50.0 },
    { "key": "passing",         "family": "saha", "value": 80.0 },
    { "key": "dribbling",       "family": "saha", "value": 25.0 },
    { "key": "charisma",        "family": "kişi", "value": 74.0 },
    { "key": "politeness",      "family": "kişi", "value": 58.0 },
    { "key": "confidence",      "family": "kişi", "value": 51.0 },
    { "key": "intelligence",    "family": "kişi", "value": 63.0 },
    { "key": "resourcefulness", "family": "kişi", "value": 29.0 }
  ],

  "fame": [ { "scope": "overall", "value": 0.0 } ],   // D35 · anlamı ⟦AÇIK-9⟧

  "market_value": { "current": 4200000,               // ⟦AÇIK-8⟧ formül
                    "measured_on": "2026-01-01" }
}
```

`attributes` **daima 11 satır** döner; değeri değişmemiş anahtar da bulunur
(INV-21). `family` veritabanında saklanmaz, kod kataloğundan gelir.
`condition` anahtarı **tavanı**, `career_state.condition` **bugünkü değeri**
taşır (D15) — ikisi aynı kavramın iki yüzüdür.

#### P2 · `GET /careers/{cid}/player/stats`

Sorgu: `?season=25/26|all&competition=<competition_id>|all`

```jsonc
{ "rows": [
    { "season_id":         "25/26",
      "competition_id":    "c_lig2",
      "competition_kind":  "league",       // FE'nin lig/kupa/uluslararası filtresi
      "competition_name":  "1. Lig",
      "appearances":       12,
      "starts":            12,
      "goals":             3,
      "assists":           0,              // D13 · v1'de daima 0
      "minutes":           1140,
      "passes_completed":  0,              // D13 · v1'de daima 0
      "passes_attempted":  0 }
  ],
  "value_history": [                        // profil ekranının değer eğrisi
    { "measured_on": "2024-01-15", "value": 450000 },
    { "measured_on": "2024-07-01", "value": 900000 }
  ] }
```

BE **kesitleri** verir, toplamayı FE yapar
([`player_profile_screen.dart:86`](../lib/screens/player_profile_screen.dart)
`_StatTotals.of`). `competition_kind` eşlemesi API katmanındadır:
`league → lig`, `cup → kupa`, `continental → uluslararasi`.

**D13 gereği dayanaksız kolon 0 kalır** (INV-11). FE bu duruma hazırdır:
`passes_attempted == 0` iken `'Başarılı pas: —'` yazar.

#### P3 · `GET /careers/{cid}/player/contract`

```jsonc
{ "team":             { /* TeamRef */ },
  "signed_at":        "2025-07-01",
  "expires_at":       "2027-06-30",
  "weekly_wage":      12000,      // ⟦B-1⟧ v1 ölçeği tier 2'ye göre ayarlanacak
  "appearance_bonus": 1500,
  "goal_bonus":       2500,
  "release_clause":   750000,
  "days_until_expiry": 472 }      // türetilmiş
```

**Aylık maaş gönderilmez** — `weekly_wage × 4`, türetilmiştir (§1.3).

---

### 5.3 Dünya

#### W1 · `GET /careers/{cid}/competitions`

```jsonc
{ "competitions": [
    { "competition_id": "c_lig1", "kind": "league", "name": "Süper Lig",
      "country": "TR", "tier": 1, "format": "double_round_robin",
      "team_count": 18, "user_participates": false },
    { "competition_id": "c_lig2", "kind": "league", "name": "1. Lig",
      "country": "TR", "tier": 2, "format": "double_round_robin",
      "team_count": 14, "user_participates": true },
    { "competition_id": "c_kupa", "kind": "cup", "name": "Ulusal Kupa",
      "country": "TR", "tier": null, "format": "single_elimination",
      "team_count": 32, "user_participates": true }
] }
```

v1 veri dosyası bu üçünü içerir (D20). Paralel ligler ve uluslararası müsabaka
şemada tanımlıdır ama v1'de listede yoktur — eklemek veri dosyasına satır
eklemekten ibarettir.

#### W2 · `GET /careers/{cid}/standings`

Sorgu: `?competition=<competition_id>` (zorunlu) `&season=25/26` (varsayılan: güncel)

```jsonc
{ "competition": { /* CompetitionRef */ },
  "season_id":   "25/26",
  "rows": [
    { "rank": 1, "team": { /* TeamRef */ },
      "played": 12, "won": 9, "drawn": 2, "lost": 1,
      "goals_for": 26, "goals_against": 11, "goal_difference": 15,
      "points": 29, "is_user_team": false }
  ],
  "promotion_slots": 2, "relegation_slots": 2 }
```

`rank`, `goal_difference` ve `is_user_team` **türetilmiştir**, saklanmaz.
Tablo daima `fixture`'dan hesaplanır (INV-2). `kind='cup'` için
`409 no_standings` döner — eleme usulünde puan durumu yoktur.

#### W3 · `GET /careers/{cid}/fixtures`

Sorgu: `?competition=&round=&team_id=&status=&season=` (hepsi opsiyonel) + sayfalama

```jsonc
{ "fixtures": [
    { "fixture_id":  "f_25_26_c_lig2_r13_ykz_dnz",
      "competition": { /* CompetitionRef */ },
      "round_no":    13,
      "leg":         null,             // çift maçlı elemede 1|2
      "kickoff_at":  "2026-03-16T20:00:00+03:00",
      "home":        { /* TeamRef */ },
      "away":        { /* TeamRef */ },
      "status":      "scheduled",      // 'scheduled'|'in_progress'|'played'
      "score":       null,             // oynanmışsa { "home": 2, "away": 1 }
      "is_user_match": true }
  ],
  "rounds": [                           // takvim — kupada eşleşmeden önce de dolu
    { "round_no": 5, "stage": "r32",
      "scheduled_on": "2026-11-03", "drawn": false }
  ],
  "next_before": null }
```

`rounds`, `competition_round` tablosundan gelir ve **kupanın kurası çekilmeden
önce de** doludur (§3.3): kullanıcı "3 Kasım'da kupa maçın var" satırını görür,
rakibini `drawn: true` olunca öğrenir.

#### W4 · `GET /careers/{cid}/teams/{tid}`

```jsonc
{ "team":    { /* TeamRef */ },
  "country": "TR",
  "mentality": "balanced",
  "ratings": { "attack": 68.4, "midfield": 71.0,
               "defense": 64.2, "goalkeeper": 66.0 },
  "competition": { /* CompetitionRef */ },     // bu sezon oynadığı lig
  "standing":    { "rank": 3, "played": 12, "points": 24 } }
```

`ratings` bugün FE'de tüketen bir ekran **yoktur**; takım künyesinin tamlığı
için gönderilir. `competition`, `competition_entry`'den o sezona göre çözülür —
takım geçen sezon başka kademede olabilir (§3.3).

---

### 5.4 İlişki

#### R1 · `GET /careers/{cid}/relationships`

```jsonc
{ "relationships": [
    { "relationship_id": "coach",
      "kind":            "coach",
      "category":        "Antrenör",
      "score":           74,
      "person_name":     "Mert Aydın",
      "contact_name":    "Mert Hoca",
      "last_contact_at": "2026-03-12",
      "has_pending_request": false,
      "traits": { "trust": 74, "promised_minutes": 60, "tactical_fit": 0.8 } }
] }
```

Beş kategori döner (§3.4). `traits` içeriği `kind`'a göre değişir; FE tanıdığı
anahtarı okur, tanımadığını yok sayar — **yeni trait eklemek FE'yi bozmaz**.

`status` ("Güven seviyesi yüksek") ve `dateLabel` ("2 gün önce") **gönderilmez**;
`score` ve `last_contact_at`'tan FE türetir (§1.3, §5.7).

#### R2 · `GET /careers/{cid}/relationships/{rid}`

```jsonc
{ /* R1'deki bütün alanlar */
  "age":        44,
  "occupation": "Baş antrenör",
  "bio":        "…",
  "hobbies":    ["satranç", "koşu"],       // traits içinde saklanır
  "recent_events": [
    { "happened_at": "2026-03-12T18:00:00+03:00",
      "delta": 3, "reason": "dialogue:coach_01:choice_2" }
  ] }
```

`recent_events` en yeni 20 kayıt. Bu **geçmiş görünümüdür**; skorun doğruluk
kaynağı `score` kolonudur (D24).

#### R3 · `POST /careers/{cid}/relationships/{rid}/interact`

```jsonc
// İstek
{ "dialogue_id":  "coach_01",
  "choice_path":  ["n1", "c2"] }        // geçilen düğüm ve seçenek kimlikleri

// Yanıt
{ "career_state": { /* CareerState */ },
  "relationship_changes": [
    { "relationship_id": "coach", "before": 71, "after": 74, "delta": 3 } ],
  "attribute_changes": [
    { "key": "politeness", "before": 58.0, "after": 58.6 } ],
  "ledger_entries": [] }
```

Diyalog **ağacı** BE'de tutulmaz — o katalog içeriğidir (§3.4). BE yalnızca
`dialogue_id` + `choice_path` çiftini tanır ve karşılığındaki etkiyi uygular.
Skor ve olay günlüğü tek fonksiyondan yazılır (INV-15).

---

### 5.5 Zaman

#### T1 · `GET /careers/{cid}/day`

```jsonc
{ "career_state": { /* CareerState */ },
  "is_match_day": false,
  "events": [
    { "kind": "cup_draw",        "ref_id": "c_kupa",  "round_no": 5 },
    { "kind": "upkeep_warning",  "ref_id": null,      "shortfall": 800 }
  ] }
```

`events[].kind`: `match` · `cup_draw` · `contract_expiring` · `upkeep_warning` ·
`relationship_low` · `season_end`. **Cümle gönderilmez** — FE `kind` ve `ref_id`
ile kendi metnini kurar (§1.3).

#### T2 · `POST /careers/{cid}/actions`

```jsonc
// İstek
{ "catalog_id": "sut",
  "result": { "minigame_score": 0.72 } }   // yalnızca drill'i olan kalemlerde

// Yanıt
{ "career_state": { /* CareerState */ },
  "applied_costs":   { "time": 60, "energy": 18 },
  "applied_effects": { "attribute:shooting": 1.4 },
  "attribute_changes": [ { "key": "shooting", "before": 50.0, "after": 51.4 } ],
  "relationship_changes": [],
  "ledger_entries": [] }
```

`kind` alanı **istekte yoktur** — `catalog_id` zaten hangi katalogdan geldiğini
belirler. Bütçe yetmezse `409 insufficient_budget`, para yetmezse
`409 insufficient_funds`; her iki durumda da **hiçbir maliyet düşülmez ve
hiçbir etki uygulanmaz** (INV-3, INV-4).

#### T3 · `POST /careers/{cid}/advance`

```jsonc
// İstek
{ "to": "next_day" }                       // "next_day" | "next_event"

// Yanıt
{ "career_state":  { /* CareerState */ },
  "days_advanced": 3,
  "stopped_on":    "2026-03-16",
  "stop_reason":   "match_day",            // T1'deki events[].kind ile aynı küme
  "simulated":     { "fixtures": 51, "competitions": 3 },
  "ledger_entries": [ /* geçilen Pazartesilerin maaş ve gider satırları */ ],
  "news_created":  ["n_0143", "n_0144"],
  "repossessed":   [] }                    // D29 · elden çıkan eşyalar
```

Atlanan **her** Pazartesi için ayrı maaş ve gider satırı yazılır — tek toplu
satır değil, geçmiş okunabilir kalsın diye (§6.5). Geçilen her günün fikstürleri
bütün müsabakalarda anında koşar (§6.7, D40).

Sezon bittiyse `409 season_finished`; terfi/düşme o çağrının içinde hesaplanır
ve `stop_reason: "season_end"` döner.

#### T4 · `POST /careers/{cid}/purchases`

```jsonc
// İstek
{ "catalog_id": "daire-merkez" }

// Yanıt
{ "career_state": { /* CareerState */ },
  "item": { "catalog_id": "daire-merkez", "purchased_at": "2026-03-14",
            "price_paid": 250000, "upkeep_weekly": 1800 },
  "ledger_entries": [ { /* LedgerEntry, kind: "purchase" */ } ] }
```

Alışveriş **günün bütçesinden yemez** (§6.2) — para bir `cost` değil, negatif
bir `effect`'tir. `upkeep_weekly` alım anında katalogdan kopyalanır ve
dondurulur (D27). Zaten sahip olunan ürün `409 already_owned`.

---

### 5.6 Maç

#### M1 · `GET /careers/{cid}/matches/next`

```jsonc
{ "fixture_id":  "f_25_26_c_lig2_r13_ykz_dnz",
  "competition": { /* CompetitionRef */ },
  "kickoff_at":  "2026-03-16T20:00:00+03:00",
  "user_side":   "home",

  "engine_payload": {                  // doğrudan motorun POST /matches gövdesi
    "teams": {
      "home": { "name": "FK Yıldız", "attack": 68.4, "midfield": 71.0,
                "defense": 64.2, "goalkeeper": 66.0, "mentality": "balanced" },
      "away": { "name": "Deniz SK",  "attack": 74.1, "midfield": 70.3,
                "defense": 69.8, "goalkeeper": 72.5, "mentality": "attacking" }
    },
    "user_side":      "home",
    "user_condition": 72,              // D38/D39 · paralel sayı, motora girmez
    "client_seed":    918273
  } }
```

`engine_payload` **olduğu gibi** motora iletilir; FE içeriğini yorumlamaz.

**Rating'ler kulüp gücüdür, başka hiçbir şey değil (D37).** Kullanıcının
nitelikleri buraya girmez (INV-26). `user_condition` takım bloklarının **içinde
değil**, gövdenin tepesindedir — motorun `Team.stamina`'sına yazılmadığı için
(D39).

Yarım kalan maç varsa `409 match_in_progress` ve `fixture_id` bildirilir (§6.4).

#### M2 · `POST /careers/{cid}/matches/{fid}/result`

```jsonc
// İstek — FE, motorun /summary yanıtını ve kendi müdahale kaydını gönderir
{ "match_id": "m_20260316_ykz_dnz",
  "score":    { "home": 2, "away": 1 },
  "stats":    { "home": { /* 13 anahtar */ }, "away": { /* 13 anahtar */ } },
  "final_possession_home": 53.1,
  "final_condition": 54,               // D38 · son tick'in player.condition'ı
  "interventions": [                   // D13/D34 · bireysel istatistik kaynağı
    { "minute": 63, "action_key": "finish_power", "outcome_key": "goal" },
    { "minute": 78, "action_key": "long_shot",    "outcome_key": "save" }
  ] }

// Yanıt 200
{ "career_state": { /* CareerState */ },
  "fixture": { "fixture_id": "f_…", "status": "played",
               "score": { "home": 2, "away": 1 } },
  "other_results": [ { "fixture_id": "f_…", "score": { "home": 0, "away": 0 } } ],
  "standing_delta": { "rank_before": 3, "rank_after": 2 },
  "player_stat_delta": { "appearances": 1, "goals": 1, "minutes": 95 },
  "ledger_entries": [ /* maç primi + gol primi */ ],
  "news_created": ["n_0143"] }
```

**Katı doğrulama (D33/D34'ün hafifletmesi).** Gövde FE'den geldiği için olduğu
gibi kabul edilmez (INV-23):

| Alan | Kural |
|---|---|
| `stats.{home,away}` | **Tam olarak 13 anahtar** ([`models.py:82-88`](../../match_engine/models.py)); eksik veya fazla kabul edilmez |
| `score.*` | `stats.*.goals` ile tutarlı olmalı |
| `interventions[].action_key` | Motorun 11 aksiyonluk kataloğundan (`API_CONTRACT.md` Ek B) |
| `interventions[].outcome_key` | O aksiyon için geçerli dallardan (`API_CONTRACT.md` §7.3) |
| `interventions[].minute` | 1-95, artan sırada |
| `final_condition` | 35-100 ve maç öncesi kondisyondan büyük olamaz |

İhlalde `422 invalid_match_result`; hiçbir tabloya yazılmaz.

Bu doğrulama hile önlemeye çalışmaz — tek oyunculu bir oyunda kullanıcı yalnızca
kendini aldatır. Amacı **sapmayı erken yakalamak**: motorda bir anahtar
değişirse ya da FE'nin defteri bozulursa sessiz veri bozulması yerine anında
hata alınır.

#### M3 · `POST /careers/{cid}/matches/{fid}/abandon`

```jsonc
// İstek — gövde yok
// Yanıt 200
{ "career_state": { /* CareerState */ },
  "fixture": { "fixture_id": "f_…", "status": "scheduled" } }
```

Motor oturumu kaybolmuş yarım maçı kurtarır: fikstür `scheduled`'a döner ve
yeniden oynanır (§6.4). `status != 'in_progress'` ise `409 fixture_not_in_progress`.

---

### 5.7 İçerik

#### N1 · `GET /careers/{cid}/news`

Sorgu: `?limit=20&before=<published_at>&category=`

```jsonc
{ "items": [
    { "news_id":      "n_0142",
      "published_at": "2026-03-14T09:00:00+03:00",
      "category":     "Transfer",
      "title":        "Deniz SK, orta saha transferi için…",
      "source":       "Spor Manşet",
      "excerpt":      "Deniz SK yönetimi, sezon ortası transfer penceresinde…",
      "fixture_id":   null } ],
  "next_before": "2026-03-09T09:00:00+03:00" }
```

`excerpt` gövdenin ilk paragrafıdır — içerik olduğu için gönderilir (§1.3).
`timeAgo` ("2 saat önce") **gönderilmez**, `published_at`'tan FE türetir.

#### N2 · `GET /careers/{cid}/news/{nid}`

```jsonc
{ /* N1'deki bütün alanlar */
  "body": "…\n\n…\n\n…" }        // \n\n ile ayrılmış paragraflar
```

#### N3 · `GET /catalog/{kind}` — katalog (D16, D41)

`kind`: `training` | `lifestyle` | `shop`. **Kariyerden bağımsız**, salt okunur.

```jsonc
// GET /catalog/training
{ "items": [
    { "catalog_id": "kondisyon-kosusu", "title": "Kondisyon Koşusu",
      "description": "…", "family": "saha", "drill": "conditioning",
      "costs":   { "time": 90, "energy": 15 },        // ⟦AÇIK-5⟧ sayılar
      "effects": { "attribute:condition": 1.2 } },

    { "catalog_id": "medya-egitimi", "title": "Medya Eğitimi",
      "family": "kişi", "drill": null,
      "costs":   { "time": 60, "energy": 5 },
      "effects": { "attribute:charisma": 0.8, "money": -1500 } }
] }

// GET /catalog/lifestyle
{ "items": [
    { "catalog_id": "ev-uyku", "title": "Uyku", "description": "…",
      "duration_label": "Tüm gece", "group": "EV AKTİVİTELERİ",
      "costs":   { "time": 540 },
      "effects": { "condition": 14, "energy": 100 } },

    { "catalog_id": "sos-taraftar", "title": "Taraftar Etkinliği",
      "duration_label": "2 saat", "group": "SOSYAL",
      "costs":   { "time": 120 },
      "effects": { "condition": -2, "fame:overall": null } }   // ⟦AÇIK-9⟧
] }

// GET /catalog/shop
{ "items": [
    { "catalog_id": "daire-merkez", "title": "…", "description": "…",
      "category": "housing", "price": 250000,
      "upkeep_weekly": 1800,                    // D27
      "note": "3+1, 120 m²" } ] }
```

**`costs` günü kapatır, `effects` dünyayı değiştirir** (§6.2). Para bir `cost`
değil, negatif bir `effect`'tir.

`effects` anahtar uzayı: `attribute:<key>` · `condition` · `energy` · `money` ·
`fame:<scope>` · `relationship:<rid>`. Tanınmayan anahtar taşıyan katalog kalemi
**yüklenmez** (INV-28) — serbest haritanın bedeli yazım hatasının sessizce
geçmesidir, bu doğrulama onu kapatır.

`drill` alanı [`training_screen.dart:22`](../lib/screens/training_screen.dart)'deki
`TrainingDrill?` enum'ının string karşılığıdır; `null` olan kart FE'de "Yakında"
görünür.

> ℹ️ Kişi antrenmanları için FE'de hazır bir yer var: antrenman ekranının ikinci
> sekmesi ([`training_screen.dart:111`](../lib/screens/training_screen.dart)
> `_tactical`) tanımlı ama boş. Adı "Taktik" olduğu için bir isimlendirme kararı
> gerekecek — ⟦B-3⟧, FE tarafı.

---

### 5.8 Sunum sınırı — BE'nin GÖNDERMEDİĞİ alanlar

| Alan | Nerede kalır | Neden |
|---|---|---|
| `icon` (`IconData`) | FE | Flutter tipi; JSON'da anlamı yok |
| `tint`, `barColor` (`Color`) | FE | **Tema** kararı, veri değil |
| Takım renkleri | **BE** — istisna | **Kimlik** verisi; FE türetemez (D17, §1.3) |
| `badgeCode` | FE | Kart görselinin parçası |
| `status` ("Güven seviyesi yüksek") | FE | `score`'dan türer |
| `dateLabel` / `timeAgo` / `lastDone` | FE | Tarihten türer, dile bağlı |
| `moneyLabel` ("₺48.200") | FE | [`player_state.dart:29`](../lib/state/player_state.dart) zaten biçimliyor |
| `imageAsset` | FE | Dosya yolu, FE paketinin içinde |
| Aylık maaş | FE | `weekly_wage × 4`, türetilmiş |
| `rank`, `goal_difference` | **BE gönderir** | Sıralama tabloya bağlı; FE tek satırdan hesaplayamaz |

---

## 6. ZAMAN MODELİ (D5)

### 6.1 Gün

Dünyanın tek saati `career_state.current_date`. Bir gün:
kullanıcı günün bütçesi elverdiğince aksiyon harcar (§6.2) → `POST /advance`
günü kapatır ve bütçeyi yeniden doldurur.

### 6.2 Günün bütçesi (D41)

**Sabit sayıda aksiyon yoktur.** Her aksiyonun kendine özel bir götürüsü vardır;
bir günde kaç aksiyon yapılabildiği **hangi aksiyonların seçildiğine** bağlıdır.
Gün, aksiyonların farklı miktarlarda çektiği bir **havuzdur**.

```
day_budget:  time = 720 dk,  energy = 100        ← gün başında dolar
   ├── "Uyku"            costs { time: 540 }     → geriye 180 dk
   ├── "Kondisyon Koşusu" costs { time: 90, energy: 15 }
   └── "Medya Eğitimi"    costs { time: 60,  energy: 5 }
```

**İki ayrım vardır ve karıştırılmamalıdır:**

| | Ne yapar | Yetmezse |
|---|---|---|
| `costs` | Günün havuzundan çeker — günü **kapatan** şey budur | `409 insufficient_budget` |
| `effects` | Dünyayı değiştirir: para, kondisyon, nitelik, şöhret, ilişki | Paraya özel: `409 insufficient_funds` (INV-5) |

Yani para bir `cost` değil, negatif bir `effect`'tir: bakiyeyi düşürür ama günü
tüketmez.

**Kaynakların ne olacağı AÇIK-5'tedir.** Şema `resource_key` ile anahtarlı
olduğu için tek boyutlu ("sadece zaman") da, iki boyutlu ("zaman + enerji") da,
daha fazlası da migrasyon gerektirmeden karşılanır.

> **FE'de iki boyutun izi zaten var:** yaşam aktiviteleri `duration` taşıyor
> ("Tüm gece", "2 saat" — [`activity_card.dart:27`](../lib/widgets/activity_card.dart)),
> antrenman kartları `energy` taşıyor (15, 20, 8… —
> [`training_screen.dart:19`](../lib/screens/training_screen.dart)).
> Bunlar farklı şeyler: uyku **zaman** harcar ama **enerji** kazandırır.
> AÇIK-5'in cevaplaması gereken asıl soru budur.

### 6.3 Atlama

`POST /advance {to: "next_event"}` — bir sonraki "olaylı" güne kadar günleri
otomatik kapatır. Olaylı gün: maç günü, **kupa kurası günü** (`competition_round.
drawn` 0→1 olduğu gün), sözleşme bitişine 30 gün kala, ilişki skoru eşiğin altına
düştüğünde, **düzenli gider karşılanamayacak görünüyorsa** (§6.5, D29), sezon
sonu (terfi/düşme). Atlanan her gün için doğal kondisyon
toparlanması ve maaş yatışı uygulanır; yanıt atlanan günlerin özetini döner.

### 6.4 Yarım kalan maç (D3 riskinin telafisi)

`fixture.status = 'in_progress'` iken yeni bir `GET /matches/next` gelirse BE
`409 match_in_progress` döner ve `fixture_id`'yi bildirir. FE iki seçenekten
birini çağırır:
- `POST /matches/{fid}/result` — maç aslında bitmişse sonucu yazar,
- `POST /matches/{fid}/abandon` — motor oturumu kaybolmuşsa fikstür `scheduled`'a
  döner ve yeniden oynanır.

### 6.5 Para akışı — sözleşmeden ödemeye (D25, D26, D27)

Sözleşme kalemleri ([`contract_screen.dart:28-40`](../lib/screens/contract_screen.dart))
artık gerçekten ödenir. Her biri `wallet.apply()` üzerinden defterle birlikte yazılır.

| Kalem | Ne zaman | `kind` | Kaynak |
|---|---|---|---|
| Haftalık maaş | **Her Pazartesi** (D26) | `wage` | `player_contract.weekly_wage` |
| Maç başı primi | M2, maç sonucu yazılırken | `appearance_bonus` | `appearance_bonus` |
| Gol primi | M2, aynı anda | `goal_bonus` | `goal_bonus` × o maçtaki gol (D13) |
| Yaşam / dükkân harcaması | T2, T4 | `lifestyle`, `purchase` | Katalog (D16) |
| **Düzenli gider** | **Her Pazartesi, maaştan sonra** (D27) | `upkeep` | `SUM(inventory.upkeep_weekly)` |

**Aylık maaş türetilmiştir** (`weekly_wage × 4`), ayrı bir ödeme değildir —
sözleşme ekranındaki satır yalnızca gösterim.

**Atlama sırasında da işler.** `POST /advance` kaç gün atlarsa atlasın, aradan
geçen her Pazartesi için bir maaş ve bir gider satırı yazılır (§6.3). Beş hafta
atlanırsa defterde beş maaş, beş gider satırı olur — tek toplu satır değil, ki
geçmiş okunabilir kalsın.

**Sıra önemlidir:** önce maaş girer, sonra gider düşer. Tersi olsaydı bakiyesi
düşük bir oyuncu maaşı yattığı hâlde gideri ödeyemez görünürdü.

#### Gider ödenemezse (D29)

Düzenli gider, kullanıcının o an vermediği bir karardır — reddedilecek bir istek
yoktur. Bu yüzden `409 insufficient_funds` yolu burada işlemez ve INV-5'i
korumak için ayrı bir kural gerekir:

1. Maaş yatar, gider düşülmeye çalışılır.
2. Bakiye yetmiyorsa **haftalık gideri en yüksek eşya elden çıkarılır**:
   `inventory`'den silinir, `price_paid`'in **%50'si** iade edilir, deftere
   `kind='sale'` satırı düşer ve bir haber üretilir.
3. Hâlâ yetmiyorsa 2. adım tekrarlanır — gider karşılanana kadar.

**Uyarı önce gelir.** `POST /advance` her Pazartesi'yi işlemeden önce projeksiyon
yapar: `bakiye + maaş < gider` ise o gün bir uyarı haberi düşer ve **olaylı gün**
sayılır (§6.3) — yani `next_event` atlaması orada durur. Kullanıcı eşyasını
hazırlıksız kaybetmez; bir hafta önce görür ve satmayı ya da harcamayı kısmayı
seçebilir.

> Bu kural INV-5'i (bakiye negatife düşmez) bozmadan D27'yi mümkün kılar ve
> `inventory`'ye durum alanı eklemez — eşya ya vardır ya yoktur.

> ⚠️ **v1 sözleşme ölçeği.** FE'nin bugünkü sabit değerleri üst düzey bir
> oyuncuya ait (haftalık ₺180.000, serbest kalma ₺12.000.000) ama D21 gereği
> kullanıcı **tier 2'de** başlıyor ve başlangıç bakiyesi ₺48.200. Başlangıç
> sözleşmesi bu kademeye göre ölçeklenmelidir; veri dosyası ayarıdır, şema değil.

### 6.6 Kondisyon döngüsü (D38)

Kondisyon **tek bir kaynaktır** ve kariyer ile maç arasında dolaşır. "Takım
kondisyonu" diye ayrı bir kavram yoktur — maç ekranındaki çubuk oyuncunun kendi
kondisyonudur.

**Kondisyon maç sonucuna asla etki etmez (D39).** Motorun `Team.stamina` alanına
**girmez** — o alan motorun kendi görünmez iç mekaniğidir ve bugünkü gibi
çalışmaya devam eder. Kullanıcının kondisyonu **paralel bir sayıdır**: maç
boyunca erir, ekranda görünür, kariyere geri yazılır, ama hiçbir olasılığı
değiştirmez.

```
career_state.condition ──► POST /matches gövdesi: user_condition   (maç başlar)
                              │
                              ▼  API katmanı her tick'te eritir;
                              │   hız yalnızca `effort` direktifine bağlı
                              ▼  tick zarfı: player.condition  ──► ekran çubuğu
                              │
        M2: final_condition ──► career_state.condition            (maç biter)
                              │
                              ▼  uyku, dinlenme, yemek geri kazandırır
                              └──► (bir sonraki maça kadar)

   [ motorun kendi Team.stamina'sı bu akışın DIŞINDA, dokunulmadan çalışır ]
```

| Adım | Kim yapar | Nerede |
|---|---|---|
| Maça giriş değeri | Kariyer BE → `user_condition` | §5.6 |
| Maç içi erime | **API katmanı**, `effort`'a bağlı hızla | §7.3 |
| Ekranda gösterim | Tick zarfının yeni `player.condition` alanı | §7.3 |
| Geri yazma | FE `final_condition` raporlar → kariyer BE yazar | §5.6 |
| Toparlanma | Yaşam aktiviteleri ve atlanan günler | §6.2, §6.3 |

**Erime hızı yalnızca `effort`'a bağlıdır (D39).** Formül yeni değil: imzalı
contract'ın §6.4'ündeki `EFFORT_STAMINA_SWING` eğrisi ve
`directive_options.effort[].projected_end_stamina` tablosu aynen kullanılır —
tek fark başlangıcın 100 değil `user_condition` olması, ve sonucun motora değil
paralel sayıya uygulanması.

**Sınırlar korunur:** geri yazılan değer motorun tabanı (35) ile kullanıcının
tavanı (`player_attribute['condition']`, D15) arasına sıkıştırılır — INV-10 ve
INV-25 birlikte uygulanır.

> **Bu döngü D15'i tamamlıyor.** O turda kondisyonu günlük yönetilen gerçek bir
> kaynak yapmıştık ama harcandığı bir yer yoktu; uyku ile antrenman aynı sayıyı
> oynatıyor, sonra hiçbir şeye yaramıyordu. Artık maç onu harcıyor.

### 6.7 Arka plan simülasyonu (D40 — D19'un yerine)

**Kural tek cümle: dünyanın bugününe kadarki her fikstür oynanmıştır** (INV-12).

`POST /advance` bir gün ilerlettiğinde, o güne düşen bütün fikstürler **bütün
müsabakalarda** hemen koşar — kullanıcının ligi, üst kademe, kupa, hepsi.
Erteleme, imleç, tetikleyici yoktur.

> **D19 neden kaldırıldı.** Amortize tembel simülasyon, haftada 2-3 saniyelik
> bir bekleme riskine karşı kurulmuştu. AÇIK-7'nin ölçümü o riskin olmadığını
> gösterdi: ham motor **1,86 ms/maç**, yani bir maç haftasının tamamı
> (~17 maç) **~32 ms**. 32 ms'lik bir iş için erteleme makinesi kurmak
> kazandırdığından fazlasını karmaşıklık olarak geri alıyordu.
>
> Düşenler: `competition_progress` tablosu · `simulated_through_round` imleci ·
> `advance` ve `standings` tetikleyicileri · "kullanıcının müsabakası geride
> bırakılamaz" özel kuralı (artık hiçbir müsabaka geride kalmadığı için
> kendiliğinden doğru).

**Kupa kurası bu sadeleşmeden faydalanır.** Bir turun eşleşmesi önceki turun
sonucuna bağlıydı (§3.3) ve amortize modelde bu, "kullanıcının müsabakaları
geride bırakılamaz" diye ayrı bir kural gerektiriyordu. Her şey anında koştuğu
için kura daima zamanında çekilebilir durumda olur.

Sezon sonu terfi/düşme hesabı da aynı sebeple güvenlidir (INV-13): o tarihe
gelindiğinde sezonun bütün maçları çoktan oynanmıştır.

---

## 7. `match_engine` v1.2 EKİ (D7, D8)

İmzalı contract'a **iki uç eklenir; mevcut hiçbir uç değişmez.**

### E11 — `POST /matches`

```jsonc
// İstek
{ "teams": { "home": {…6 alan + stamina}, "away": {…6 alan + stamina} },
  "user_side": "home", "client_seed": 918273 }
// Yanıt 201
{ "match_id": "m_…" }
```

`stamina` alanı D38 ile geldi ve **motorda zaten mevcut** — `Team.stamina`
([`models.py:22`](../../match_engine/models.py)), varsayılanı 100.0. Bugün
[`teams.py:29`](../../match_engine/api/teams.py) her maçta 100.0 yazıyor; E11 bunu
gövdeden alacak.

Motorun `Team` doğrulaması ([`teams.py:47`](../../match_engine/api/teams.py) `validate_team`)
aynen uygulanır. Dönen `match_id` mevcut `/start`, `/stream`, `/summary` akışına
girer. `/matches/next` demo yolu olarak yerinde kalır.

> ⚠️ `DevProbabilityEngine._side_of` kimlik karşılaştırması yapıyor
> ([`API_CONTRACT.md` §8.2](../../API_CONTRACT.md) uyarısı) — bu uç da **her çağrıda taze
> `Team` nesneleri** üretmelidir.

### E12 — `POST /simulate/batch`

```jsonc
// İstek
{ "matches": [ { "ref": "f_…", "teams": {…}, "seed": 123 } ] }
// Yanıt 200
{ "results": [ { "ref": "f_…", "score": {"home":1,"away":1},
                 "stats": {…13×2}, "final_possession_home": 48.7 } ] }
```

SSE yok, tempo yok, müdahale yok, registry'ye yazmaz. Tam maçı senkron koşar ve
`HistoryManager.summary()` çıktısını döner.

**Performans — ölçüldü (AÇIK-7 kapandı).**

Ham motor, API katmanı olmadan **1,86 ms/maç** (200 maçlık koşu, `batch_runner.
run_batch`). v1 dünyasında (D20):

| | Maç / sezon | Süre |
|---|---|---|
| Süper Lig (18 takım, 34 hafta) | 306 | 0,57 sn |
| 1. Lig — kullanıcının ligi (14 takım, 26 hafta) | 182 | 0,34 sn |
| Ulusal Kupa (32 takım, tek maç eleme) | 31 | 0,06 sn |
| **Toplam** | **519** | **~0,97 sn** |

Bir maç haftası (bütün müsabakalar, ~17 maç) ≈ **32 ms**. D20'nin çok ötesindeki
en büyük senaryo bile (3 ülke, ~1600 maç) sezon başına ~3 sn.

> **Contract §0'daki `~0,26 sn/maç` neden bu kadar farklıydı:** o gözlem API
> katmanının `run_loop`'undan geçen bir maçtı — her tick'te zarf kurma, olayları
> Türkçe satırlara çevirme, müdahale kapısı kontrolü, async döngü. E12 bunların
> hiçbirini yapmaz (SSE yok, tempo yok, metin yok), o yüzden doğru taban ham
> motor hızıdır. Sayı yanlış değildi, **farklı bir şeyi ölçüyordu.**

Bu ölçüm **D19'u kaldırdı** (→ D40, §6.7).

### 7.3 Tick zarfına `player.condition` eklenir (D38, D39)

Motorun `Team.stamina`'sı **hiç değişmez** — tanımı, davranışı, kalibrasyonu,
`effort` bağı, hepsi yerinde kalır ve oyunu bugünkü gibi etkilemeye devam eder.
Eklenen şey **paralel bir alandır**.

| | |
|---|---|
| **Ne ekleniyor** | Tick zarfına `player.condition` (int 0-100) — kullanıcının kendi kondisyonu |
| **Kim hesaplıyor** | **API katmanı.** `POST /matches` gövdesindeki `user_condition`'dan başlar, her tick'te `effort` direktifine bağlı hızla erir |
| **Motora etkisi** | **Yok.** Hiçbir `effective_*` formülüne girmez, hiçbir olasılığı değiştirmez (INV-27) |
| **Ne değişiyor (FE)** | Kondisyon çubuğu artık `team.stamina`'yı değil `player.condition`'ı gösterir |

**Erime formülü yeni değil.** İmzalı contract §6.4'ün `EFFORT_STAMINA_SWING`
eğrisi ve §8.1'in `directive_options.effort[].projected_end_stamina` tablosu
aynen kullanılır; tek fark başlangıcın 100 değil `user_condition` olması. Bu
yüzden `projected_end_stamina` değerleri **başlangıç kondisyonuna göre yeniden
hesaplanmalıdır** — formül aynı, girdi değişiyor.

**Motorda gereken değişiklik:** yok. `simulation_engine.py` bu alandan haberdar
bile olmaz; API katmanı kendi sayacını tutar.

#### İmzalı maddelere etkisi

| Madde | Durum |
|---|---|
| **[İ-6]** — `team.stamina` = "kadro ortalama tazeliği" | ✅ **Değişmiyor.** Alan, tanımı ve davranışıyla yerinde |
| **[İ-23]** — ekran etiketi "Takım Kondisyonu" | ⚠️ **Değişiyor.** Çubuk artık `player.condition`'ı gösteriyor, etiketi sade "Kondisyon" |
| **1. müşteri kararı** — "bireysel oyuncu katmanı yok" | ✅ **Korunuyor.** Motora `Player` eklenmiyor; `player.condition` API katmanının taşıdığı bir kariyer sayısıdır, motorun bir kavramı değil |
| **3. müşteri kararı** — "efor kondisyonu gerçekten eritir" | ✅ **Güçleniyor.** Efor artık hem motorun stamina'sını (eskisi gibi) hem kullanıcının kondisyonunu eritiyor |

> **FE teyidi gerekir ama kapsam dar:** değişen tek şey kondisyon çubuğunun
> hangi alandan beslendiği. Zarfın şekli genişliyor, hiçbir alan kaldırılmıyor
> veya yeniden anlamlandırılmıyor.

---

## 8. INVARIANT'LAR

| # | Garanti |
|---|---|
| INV-1 | `career_id` bilinmeyen her istek `404 career_not_found` döner |
| INV-2 | Puan durumu **daima** `fixture` tablosundan türer; ayrı yazılan puan yoktur (§3.3) |
| INV-3 | Bir `POST /actions` çağrısı ya bütün etkileriyle uygulanır ya hiç — tek transaction |
| INV-4 | Bütçesi yetmeyen `POST /actions` → `409 insufficient_budget`; hiçbir maliyet düşülmez, hiçbir etki uygulanmaz (D41) |
| INV-5 | `money` asla negatife düşmez; yetersizse `409 insufficient_funds` |
| INV-6 | Aynı `fixture_id` için ikinci `POST /result` → `409 fixture_already_played` |
| INV-7 | Aynı `seed` + aynı karar dizisi → aynı fikstür ve aynı `other_results` |
| INV-8 | `condition` ve bütün `player_attribute` değerleri 0-100 aralığında kalır |
| INV-9 | Kariyer silinince ona ait hiçbir satır kalmaz (`ON DELETE CASCADE`) |
| INV-10 | `career_state.condition ≤ player_attribute['condition']` — günlük değer tavanı aşamaz (D15) |
| INV-11 | Dayanağı olmayan istatistik kolonu **0** kalır; tahminle doldurulmaz (D13) |
| INV-12 | Dünyanın bugününe kadarki **her** fikstür oynanmıştır — hiçbir müsabaka geride bırakılmaz (D40) |
| INV-13 | Terfi/düşme hesaplanmadan önce o sezonun bütün müsabakaları tamamlanmış olur |
| INV-14 | Bir takım aynı sezonda birden fazla lig'e (`kind='league'`) giremez |
| INV-15 | `relationship.score` yalnızca `relationships.apply_delta()` üzerinden yazılır; aynı transaction'da olay günlüğüne satır düşer (D24) |
| INV-16 | `relationship.traits` daima o `kind`'ın Pydantic modelini doğrular; tanınmayan alan yazılmaz (D23) |
| INV-17 | `career_state.money` yalnızca `wallet.apply()` üzerinden yazılır; aynı transaction'da `money_ledger` satırı düşer (D25) |
| INV-18 | Durumu değiştiren her yanıt tam `career_state` bloğunu taşır (D28) |
| INV-19 | `money_ledger` toplamı daima `career_state.money`'ye eşittir |
| INV-20 | Düzenli gider hiçbir zaman bakiyeyi negatife düşürmez; karşılanamıyorsa eşya elden çıkar (D29) |
| INV-21 | `player_attribute.attribute_key` daima §3.2'deki 11 anahtardan biridir; tanınmayan anahtar yazılmaz (D30) |
| INV-22 | Hiçbir nitelik kendiliğinden azalmaz — yaş, form veya zaman nitelik düşürmez (D32) |
| INV-23 | FE'den gelen maç sonucu katı doğrulamayı geçmeden hiçbir tabloya yazılmaz (D33, §5.6) |
| INV-24 | `player_fame.value` yalnızca `fame.apply()` üzerinden yazılır; aynı transaction'da `fame_event` satırı düşer (D35) |
| INV-25 | Maç sonrası geri yazılan kondisyon **35** (motorun tabanı) ile `player_attribute['condition']` (kullanıcının tavanı) arasına sıkıştırılır (D38) |
| INV-26 | Kullanıcının nitelikleri motora giden hiçbir rating'e girmez — `compute_team_rating()` kulüp gücünü değiştirmeden döner (D37) |
| INV-27 | Kullanıcının kondisyonu hiçbir maç olasılığını değiştirmez; motorun `Team.stamina`'sına yazılmaz (D39) |
| INV-28 | Katalogdaki her `costs` / `effects` anahtarı tanınan kataloğa aittir; bilinmeyen anahtar taşıyan kalem yüklenmez (D41) |
| INV-29 | `day_budget` her gün başında yeniden doldurulur ve hiçbir kaynak negatife düşmez (D41) |

**Garanti EDİLMEYEN:** kullanıcının maçı ile `simulate/batch` sonuçlarının
istatistiksel olarak birebir aynı dağılımdan geldiği — ikisi de aynı motoru
kullanır ama kullanıcının maçı müdahalelerle sapar.

---

## 9. HATA KODLARI

| HTTP | `code` | Ne zaman |
|---|---|---|
| 404 | `career_not_found` | Bilinmeyen `career_id` |
| 404 | `fixture_not_found` | Bilinmeyen `fixture_id` |
| 409 | `insufficient_budget` | Günün bütçesi (zaman/enerji…) aksiyona yetmiyor (D41) |
| 409 | `insufficient_funds` | Bakiye yetersiz |
| 409 | `already_owned` | Ürün zaten alınmış |
| 409 | `match_in_progress` | Yarım kalan maç var (§6.4) |
| 409 | `fixture_already_played` | Sonuç ikinci kez yazılmak isteniyor |
| 409 | `season_finished` | Sezon bitti, ilerletilemez |
| 409 | `fixture_not_in_progress` | M3 çağrıldı ama fikstür yarım kalmış değil |
| 409 | `no_standings` | Puan durumu istenen müsabaka `kind='cup'` — eleme usulünde tablo yoktur |
| 422 | `invalid_request` | Şema doğrulaması |
| 422 | `invalid_match_result` | M2 gövdesi katı doğrulamayı geçemedi (§5.6, D33) |
| 502 | `engine_unavailable` | `match_engine` erişilemez (M2 sırasında) |

---

## 10. AÇIK MADDELER

> **Bunlar contract'ın eksikleri değil, bilinçli erteleme noktalarıdır.**
> Üçü de şemayı, uç listesini ve yanıt gövdelerinin şeklini bağlamaz: alan
> zaten yerinde ve tipi kesin, dolan yalnızca değeri.
>
> **Kapananlar:** AÇIK-2, AÇIK-3, AÇIK-4, AÇIK-6 (D13-D16) · **AÇIK-1** (D37) ·
> **AÇIK-10**, **AÇIK-11** (D39 ile düştüler) · **AÇIK-7** (ölçüldü → D40).
>
> §10.1'de AÇIK numarası taşımayan **veri/FE ayarları**, §10.2'de her açık
> maddenin **düzenlenecek satırları** listelidir.

**AÇIK-9 — Şöhretin anlamı (D36, ertelendi).**
Depolama kuruldu (§3.2, D35); **tanım yazılmadı**. Kapatmak için altı sorunun
cevabı gerekiyor:

1. **Boyut** — tek skala mı, kapsam ayrımı mı (yerel/ulusal/uluslararası), tür
   ayrımı mı (sportif ün / magazin ünü)? Şema üçünü de taşır (`scope`).
2. **Aralık** — 0-100 mü, üst sınırsız mı? Doğrusal mı, logaritmik mi (ilk
   1000 taraftar son 1000'den daha mı değerli)?
3. **Kaynaklar** — hangi olaylar artırır, hangileri azaltır? Gol, galibiyet,
   röportaj, taraftar etkinliği, kötü performans, skandal…
4. **Aşınma** — zamanla kendiliğinden düşer mi? (D32 nitelikler için "azalma
   yok" dedi; şöhret o karara **tabi değildir**, ayrı bir kavramdır.)
5. **Tüketiciler** — sözleşme pazarlığı, piyasa değeri (AÇIK-8), transfer
   ilgisi, sponsor gelirleri, haber üretimi?
6. **Medya ilişkisinden farkı** — ⚠️ **en kritik olanı.** Ortada zaten
   `relationship['media'].score` var (§3.4). İkisinin sınırı çizilmezse iki
   sayı birbirini taklit eder ve hangisinin ne anlattığı belirsizleşir.
   Muhtemel ayrım: **şöhret** "kaç kişi tanıyor" (nicelik, kamuoyu),
   **medya ilişkisi** "basın seni seviyor mu" (nitelik, tek bir kuruma karşı
   duran ikili ilişki). Bu ayrım kabul edilirse ikisi birbirini besler ama
   çakışmaz — ünlü ama basınla arası kötü bir oyuncu tutarlı bir durumdur.

Şemaya etkisi yok: hangi cevap gelirse gelsin `player_fame` + `fame_event` +
`fame.apply()` üçlüsü karşılar.

**AÇIK-8 — Piyasa değeri formülü.**
`player_value_history` anlık görüntüleri saklıyor ama **güncel değeri hesaplayan
formül yazılmadı** (§3.2). Girdileri belli: 11 nitelik (D30), yaş, form,
sözleşme süresi ve muhtemelen şöhret (AÇIK-9). D32 gereği yaş bir azaltıcı değildir — değer düşüşü yalnızca
kötü formdan gelebilir. Tek fonksiyon, `compute_market_value()`; şemayı
bağlamaz.

**AÇIK-5 — Aksiyon ekonomisi (D41 ile daraltıldı, ertelendi).**
**Yapı kuruldu** (§6.2, D41): her aksiyonun kendine özel `costs` ve `effects`
haritası var, günlük bütçe kaynak-anahtarlı. **Sayılar ve kaynaklar yazılmadı.**
Kapatmak için üç soru:

1. **Bütçe kaç boyutlu?** Tek boyut ("sadece zaman") mı, iki boyut
   ("zaman + enerji") mı? FE'de ikisinin de izi var: yaşam aktivitelerinde
   `duration`, antrenman kartlarında `energy` (§6.2 notu). İki boyut daha
   zengin — uyku zaman harcayıp enerji kazandırabilir — ama dengelemesi zor.
2. **Günün havuzu ne kadar?** Zaman dakikaysa 720 mi (uyanık saatler), 1440 mü?
   Enerji varsa tavanı kaç, nasıl toparlanır?
3. **Maç günü ne olur?** Eski öneri "aksiyon 1'e düşer"di. Bütçe modelinde
   karşılığı: maç günün havuzundan sabit bir pay yer (§6.6'daki kondisyon
   erimesinden ayrı bir şey).

Şemaya etkisi yok: `day_budget` anahtarlı, `costs`/`effects` harita. Hangi cevap
gelirse gelsin veri dosyası ve `config.py` değişir, tablo değişmez.

### 10.1 AÇIK numarası taşımayan bekleyen maddeler

Bunlar tasarım kararı değil, **veri ve FE ayarları**. Şemayı bağlamazlar ama
uygulanabilir bir v1 için kapanmaları gerekir.

| # | Konu | Ne gerekiyor | Nerede |
|---|---|---|---|
| B-1 | **v1 sözleşme ölçeği** | FE'nin sabit değerleri üst düzey oyuncuya ait (haftalık ₺180.000, serbest kalma ₺12.000.000) ama kullanıcı tier 2'de ve ₺48.200 ile başlıyor. Başlangıç sözleşmesi bu kademeye ölçeklenmeli | §6.5 · veri dosyası |
| B-2 | **Ligin FE verisiyle eşlemesi** | FE'nin mevcut sabit ligi (Deniz SK · Anadolu FC · FK Yıldız) **1. Lig / tier 2** olarak yerleştirildi; Süper Lig'in 18 takımı yeni isim. **Bu bir varsayımdır, teyit bekliyor** | §3.3 · veri dosyası |
| B-3 | **Kişi antrenmanlarının sekmesi** | D31 kalemleri için FE'de boş bir sekme hazır (`_tactical`, [`training_screen.dart:111`](../lib/screens/training_screen.dart)) ama adı "Taktik". İsimlendirme kararı | §5.7 · FE |
| B-4 | **Lig tablosu başlığı** | Artık hangi müsabakanın tablosuna bakıldığı değişken; başlık veriden gelmeli | §3.3 · FE |
| B-5 | **Takım renkleri** | 18 + 14 takım için `color_primary` / `color_secondary` seçilecek (D17) | §3.3 · veri dosyası |
| B-6 | **SQLite JSON1 sürüm kontrolü** | `json_extract()` 3.38+ gerektiriyor; kurulumda tek satırlık kontrol | §3.4 |

### 10.2 Düzenleme noktaları — karar geldiğinde nereye dokunulacak

Metindeki **⟦AÇIK-n⟧** ve **⟦B-n⟧** işaretleri, ertelenmiş bir değerin geçtiği
yeri gösterir. `grep "⟦" CONTRACT.md` hepsini bulur.

| İşaret | Bölüm | Ne dolacak |
|---|---|---|
| ⟦AÇIK-5⟧ | §5.0 `CareerState.day_budget` | Bütçe kaynaklarının anahtarları (`time`? `energy`?) |
| ⟦AÇIK-5⟧ | §5.7 N3 `costs` | Her katalog kaleminin gerçek maliyet sayıları |
| ⟦AÇIK-8⟧ | §5.2 P1 `market_value.current` | `compute_market_value()` formülü |
| ⟦AÇIK-9⟧ | §5.2 P1 `fame[]` | Şöhretin boyutu, aralığı, kaynakları |
| ⟦AÇIK-9⟧ | §5.7 N3 `effects["fame:overall"]` | Katalog kalemlerinin şöhret getirisi (bugün `null`) |
| ⟦B-1⟧ | §5.2 P3 sözleşme kalemleri | v1 başlangıç sözleşmesinin tier 2 ölçeği |
| ⟦B-3⟧ | §5.7 N3 notu | FE'de kişi antrenmanlarının hangi sekmede duracağı |

**Kural:** bu noktaların doldurulması **sürüm numarasını değiştirmez** ve FE
deploy'u gerektirmez. Alan zaten şemada; FE onu bugün de okuyor, sadece değeri
`null` veya geçici. Sürüm ancak bir alan **eklenir, kaldırılır veya anlamı
değişirse** artar.

---

### Kapananlar

| # | Kapanış |
|---|---|
| AÇIK-2 | **D13** — yalnızca minigame; dayanaksız kolon 0 kalır (INV-11, §3.2) |
| AÇIK-3 | **D14** — 18 takım, çift devreli, 34 hafta. ⚠️ **D20 ile revize:** bu ölçek artık üst kademenindir; kullanıcının başladığı 1. Lig 14 takım / 26 hafta (§3.3) |
| AÇIK-4 | **D15** — tek kavram, tavanlı; `condition ≤ attribute['condition']` (INV-10, §3.1) |
| AÇIK-6 | **D16** — veri BE'de, sunum FE'de; `GET /catalog/{kind}` (§5.7) |
| AÇIK-1 | **D37** — bağ yok: nitelikler hiçbir takım rating'ine girmez (INV-26, §5.6). Tek gelecek kanal minigame zorluğudur, o da ertelendi |
| AÇIK-10 | **D39** ile düştü — kondisyon motorun `stamina`'sına girmediği için kalibrasyon hiç etkilenmiyor (§7.3) |
| AÇIK-11 | **D39** ile düştü — eşleme sorusu yok: kondisyon motora hiç eşlenmiyor. Rakip kondisyonu diye bir kavram da yoktur |
| AÇIK-7 | **Ölçüldü:** ham motor 1,86 ms/maç (200 maçlık koşu), varsayımın 140× altında. Sonuç D19'u kaldırdı → **D40** (§6.7, §7) |
