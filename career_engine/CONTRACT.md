# CAREER ENGINE — API CONTRACT (v1.0)

**Taraflar:** Kariyer Back-end (`career_engine`, FastAPI) ↔ Front-end (`ProjectSRPG`, Flutter)
**Komşu servis:** Maç Motoru (`match_engine`, FastAPI) — bkz. [`API_CONTRACT.md`](../../API_CONTRACT.md) v1.1

---

## İMZA BLOĞU

| | |
|---|---|
| **Sürüm** | **v1.0** — uygulanabilir. Karar kaydı §0, açık maddeler §10 |
| **Tarih** | 2026-08-19 |
| **Back-end** | ✅ imzalandı — `career_engine` §4'teki 25 ucun tamamını uyguluyor, test paketi geçiyor |
| **Front-end** | ✅ imzalandı — `ProjectSRPG` okundu, kabul edildi; W1/W2 bağlı, kalan uçların bağlanması sürüyor |

**Dayandığı bağlayıcı kararlar:** §0'da **43 karar** (D1-D43), dokuz ayrı tur.
**Garantiler:** §8'de **32 invariant** (INV-1 … INV-32).

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
| D21 | Başlangıç kademesi | **Daima alt kademe**, kulüp milliyete göre atanır | Yükseliş oyunun ana yayı |
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
| D30 | Nitelik modeli | **Radar = model, 12 nitelik** | Ekranda ne görülüyorsa model o; gizli nitelik yok |
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

Dokuzuncu turda (sosyal yeterlilik kapısı) alınanlar — **kişi ailesi ilk kez okunuyor**:

| # | Karar | Seçilen | Gerekçe |
|---|---|---|---|
| D42 | Nitelik yeterliliği | **`requires` haritası — sunucu-otoriter, BE hem servis eder hem doğrular** | §3.2'nin "diyalog seçeneği kilidi" vaadinin karşılığı. Eşiği FE'ye vermek kilidi önceden göstermeyi (gri seçenek) mümkün kılar; çağrıda yeniden doğrulamak istemcinin kilidi atlamasını imkânsız kılar. İkisi birden gerekir: biri UX, diğeri güvenlik |
| D43 | Yeterlilik ölçeği | **Seviye = `floor(value/10)`, 0-10** | Eşik "cazibe 60" değil "cazibe 6" diye yazılır — içerik yazarı için okunur, oyuncu için anlaşılır. Türetme kuralının tek sahibi BE'dir; P1 ham `value` ile birlikte `level`'ı da gönderdiği için FE formülü kopyalamaz |

> **`requires` üçüncü haritadır — `costs`/`effects`'in kardeşi, ikizi
> değil.** `costs` günü kapatır (§6.2), `effects` dünyayı değiştirir,
> `requires` **kapıyı açar** — hiçbir şey harcamaz, hiçbir şey değiştirmez,
> yalnızca okur. Bu yüzden kontrolü her zaman en başta, hiçbir kaynak
> düşülmeden yapılır (INV-30).

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
| **İlişki** | Altı ilişki kategorisi, skorlar, kişi künyeleri, etkileşim geçmişi |
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
  money         INTEGER NOT NULL,          -- player_state.dart:7  (₭ Kredi, tam sayı)
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

**On iki nitelik — radar neyse model o (D30).** Gizli nitelik yoktur: her anahtar
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
| saha | `tackling` | Müdahale | §2 yetenek sınavı (radara eklenecek eksen) |
| **kişi** | `charisma` | Cazibe | [`relationships_radar_screen.dart:14`](../lib/screens/relationships_radar_screen.dart) |
| kişi | `politeness` | Kibarlık | " |
| kişi | `confidence` | Özgüven | " |
| kişi | `intelligence` | Zeka | " |
| kişi | `resourcefulness` | Beceriklilik | " |

**İki aile, iki tüketici.** Ayrım keyfi değil, yapısal:

| Aile | Kim tüketiyor | Nereye gider |
|---|---|---|
| **saha** | `compute_team_rating()` (AÇIK-1), minigame zorluğu | Maça |
| **kişi** | **Yeterlilik kapısı (D42)** — diyalog seçeneği kilidi, katalog kalemi kilidi; ileride medya tepkisi ve sözleşme pazarlığı | Kariyere |

`family` veritabanında **saklanmaz** — anahtar listesi sabit olduğu için kod
içindeki katalogdan okunur (INV-21).

`tackling` (Müdahale) yetenek sınavı sistemiyle geldi: Müdahale sınavının
düşeceği bir nitelik gerekiyordu ve ilk altısının hiçbiri top kapmayı
karşılamıyordu. `shooting`/`passing`/`dribbling` ile birlikte **pozisyon+rol'ün
uzmanlaşabildiği dört saha yeteneğinden** biridir (§5.1 C1).

`condition` anahtarı burada **tavanı** tutar (D15, §3.1 notu); günlük değer
`career_state.condition`'dır. Eksen adı "Kondisyon" olarak kaldı.

> **Kapsam sınırı (D30):** hız, top kontrolü, cesaret gibi nitelikler **yoktur**.
> "Radar = model" kararının bilinçli bedeli budur; eklemek için önce radar bir
> eksen kazanmalıdır — o da bir FE kararıdır ve şemayı bozmaz
> (`player_attribute` anahtar-değer olduğu için yeni anahtar migrasyon istemez).

#### Seviye — ham değerin okunur yüzü (D43)

Nitelikler 0-100 aralığında **REAL** saklanır; bu ölçek antrenmanın 0.8'lik
kazancını taşıyabilmek için gereklidir. Ama bir eşik yazarken "cazibe 60"
değil **"cazibe 6"** okunur. İkisini bağlayan tek kural:

```
level = floor(value / 10)          # 0-100  ->  0-10
```

Denklik tektir ve tersine çevrilebilir: **seviye N ⇔ `value >= 10 * N`**.
74.0 → 7 · 100.0 → 10 · 4.0 → 0. On birinci kova (seviye 0) kasıtlıdır:
0..9 aralığını seviye 1'e sıkıştırmak, eşik karşılaştırmasını bu denklikten
koparırdı.

**Formülün tek sahibi BE'dir.** FE kuralı kopyalamaz — P1 her nitelikte ham
`value` ile birlikte türetilmiş `level`'ı da gönderir (§5.2), FE yalnızca
tam sayı karşılaştırması yapar. Ölçek bir gün değişirse (0-20, 0-5…)
değişen tek yer bu satır olur, FE'de hiçbir şey.

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
  value      INTEGER NOT NULL,            -- ₭ (Kredi)
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
| `goals` | `interventions[]`'da bir gol üreten dalla sonuçlanmış müdahale sayısı — `catalog/match_actions.py`'nin `GOAL_OUTCOMES` tablosu: `finish_power`/`finish_finesse`/`long_shot`/`counter_attack`'te `outcome_key == "great"`, `set_piece`/`penalty_win`'de `outcome_key == "success"` (`API_CONTRACT.md` §7.4 — motorun hangi dalların gerçekten `Goal` olayı ürettiğiyle çapraz kontrol edilmiş) |
| `assists` | `interventions[]`'da `outcome_key == "asist"` sonuçlanmış müdahale sayısı — yalnızca 4 `graded4` (şut) aksiyonunda mümkün, `goals`'la karşılıklı dışlayıcı (`catalog/match_actions.py`'nin `is_assist()`'i) |
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
`aylık maaş` **türetilmiş** (`weekly_wage × 4`), saklanmaz. §1.3 gereği BE tam sayı
gönderir, biçimlendirme FE'ye geçer — FE tarafta tek sahibi
[`money.dart`](../lib/net/money.dart)'ın `formatMoney()`'si.

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
  relationship_id TEXT NOT NULL,           -- 'coach','team','media','fans','partner','family'
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

Alanlar [`worlddata/relationships.py`](../career_engine/worlddata/relationships.py)'nin
`RELATIONSHIP_SEED`'inden — FE artık bu kartları statik değil, R1'den dinamik
çekiyor (`relationships_screen.dart`'ın `_toCardData()`'sı). **Altı kategori**:
Antrenör · Takım Arkadaşları · Medya · Taraftarlar · Partner · Aile/Sosyal Çevre.
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
| C0 | `GET` | `/careers/options` | Yeni kariyerde milliyet, pozisyon+rol, hedef kulüp, sınav ve başlangıç değerleri |
| C1 | `POST` | `/careers` | Yeni kariyer: ad/soyad, milliyet, pozisyon+rol, hedef kulüp, seed |
| C2 | `GET` | `/careers` | Kariyer listesi (kayıt ekranı) |
| C3 | `GET` | `/careers/{cid}` | Kariyer merkezi özeti — tek çağrıda hub verisi |
| C4 | `DELETE` | `/careers/{cid}` | Kariyeri sil |
| C5 | `POST` | `/careers/{cid}/skill-exams` | Yetenek sınavı notlarını nitelik puanına çevirir |
| **Oyuncu** ||||
| P1 | `GET` | `/careers/{cid}/player` | Künye + altı nitelik + kondisyon + para |
| P2 | `GET` | `/careers/{cid}/player/stats` | `?season=&competition=` → kesit listesi |
| P3 | `GET` | `/careers/{cid}/player/contract` | Sözleşme kalemleri |
| **Dünya** ||||
| W1 | `GET` | `/careers/{cid}/competitions` | Müsabaka listesi: piramit, paralel ligler, kupalar |
| W2 | `GET` | `/careers/{cid}/standings` | `?competition=&season=` → puan durumu (D18) |
| W3 | `GET` | `/careers/{cid}/fixtures` | `?competition=&round=&team_id=&status=` |
| W4 | `GET` | `/careers/{cid}/teams/{tid}` | Takım künyesi + renkler |
| W5 | `GET` | `/careers/{cid}/calendar` | `?from=&to=` → takvim sayfası: fikstür + önemli günler |
| **İlişki** ||||
| R1 | `GET` | `/careers/{cid}/relationships` | Beş kart |
| R2 | `GET` | `/careers/{cid}/relationships/{rid}` | Profil künyesi + son etkileşimler |
| R3 | `POST` | `/careers/{cid}/relationships/{rid}/interact` | Diyalog sonucunu uygular |
| R4 | `GET` | `/careers/{cid}/social/offers` | Cevap bekleyen sosyal teklifler (§6.3 D53) |
| R5 | `POST` | `/careers/{cid}/social/offers/{oid}/accept` | Teklifi kabul eder |
| R6 | `POST` | `/careers/{cid}/social/offers/{oid}/decline` | Teklifi reddeder |
| **Zaman** ||||
| T1 | `GET` | `/careers/{cid}/day` | Bugün: tarih, kalan aksiyon, bugünkü olaylar |
| T2 | `POST` | `/careers/{cid}/actions` | Antrenman / yaşam aktivitesi uygular |
| T3 | `POST` | `/careers/{cid}/advance` | `{to: "next_day"\|"next_event"}` |
| T4 | `POST` | `/careers/{cid}/purchases` | Dükkândan satın alır |
| **Maç** ||||
| M1 | `GET` | `/careers/{cid}/matches/next` | Maç kurulumu — motora verilecek payload dahil |
| M2 | `POST` | `/careers/{cid}/matches/{fid}/result` | Sonucu yazar + haftayı simüle eder |
| M3 | `POST` | `/careers/{cid}/matches/{fid}/abandon` | Yarım kalan maçı kurtarır (§6.4) |
| M4 | `POST` | `/careers/{cid}/matches/{fid}/coach-talk` | Maç öncesi antrenör konuşması (§12.1) |
| **İçerik** ||||
| N1 | `GET` | `/careers/{cid}/news` | `?limit=&before=` |
| N2 | `GET` | `/careers/{cid}/news/{nid}` | Tam gövde |
| N3 | `GET` | `/catalog/{kind}` | `training` \| `lifestyle` \| `shop` \| `dialogue` — kariyerden bağımsız |

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
| **Para** | Tam sayı, **₭ (Kredi)**, kesir yok. Biçimlendirme FE'de (§1.3) — tek sahibi `lib/net/money.dart` |
| **Sayfalama** | `?limit=` (varsayılan 20, en fazla 100) + `?before=` imleci. Yanıt `next_before` döner; `null` ise liste bitti |
| **Bilinmeyen alan** | FE tanımadığı alanı **yok sayar**. Yanıta alan eklemek kırıcı değildir; alan kaldırmak kırıcıdır |
| **Hata gövdesi** | `{"code": "...", "message": "..."}` — `match_engine` ile aynı, düz gövde ([`errors.py`](../../match_engine/api/errors.py)) |
| **Kimlik doğrulama** | Yok (motorla aynı karar) |

---

### 5.1 Kariyer

#### C0 · `GET /careers/options` — yeni kariyer seçenekleri

```jsonc
{ "nationalities": [
    { "country_code": "TR", "name": "Türkiye", "nationality": "Türk" } ],
  "positions": [                               // Kaleci v1'de yok (rolü yok)
    { "position": "Defans",
      "roles": [
        { "role_id": "stoper", "name": "Stoper", "group": "DC",
          "attributes": ["tackling", "tackling"] } ] } ],
  "target_teams": [                            // hedef kulüp: her takım olabilir
    { "team": { /* TeamRef */ },
      "competition": { /* CompetitionRef */ },
      "strength_hint": "orta" }                // 'zayıf' | 'orta' | 'güçlü'
  ],
  "skill_exams": [
    { "exam_id": "shooting", "title": "Şut Sınavı", "attribute_key": "shooting",
      "points_per_level": 1.0, "min_level": 1, "max_level": 5, "max_value": 100.0 } ],
  "starting_values": {
    "money": 100, "condition": 100,
    "relationships": { "coach": 70, "team": 50, "media": 10, "fans": 40,
                       "partner": 0, "family": 0 },
    "base_skill_value": 20.0, "role_bonus_per_slot": 2.0 } }
```

`positions` her pozisyonun **kendi rollerini** taşır: rol seçenekleri pozisyona
göre değişir ve C1 uyumluluğu doğrular. `attributes` rolün uzmanlaştığı iki
yetenek yuvasıdır; aynı anahtar iki kez geçebilir (o zaman bonus o yeteneğe iki
kat biner). `target_teams` **hedeflenen** kulübün listesidir — oynanacak kulüp
seçilmez, §3'e göre atanır. `strength_hint` takım rating'lerinden türetilmiş
kaba bir etikettir; ham rating gönderilmez.

#### C1 · `POST /careers` — yeni kariyer

```jsonc
// İstek
{ "first_name":     "Efe",
  "last_name":      "Kaan",
  "nationality":    "TR",              // C0'ın country_code'u
  "position":       "Orta saha",
  "role":           "regista",         // pozisyona ait olmalı
  "target_team_id": "t_gal",           // hayalindeki kulüp, oynanan kulüp değil
  "seed":           918273 }           // opsiyonel; yoksa rastgele üretilir

// Yanıt 201 — C3 ile aynı gövde
```

`seed` fikstür sırasını, kupa kurasını **ve başlangıç kulübü atamasını**
belirler (D9); aynı seed → aynı dünya ve aynı kulüp (INV-7).

**Başlangıç kulübü istekte yoktur.** Oyuncunun `nationality`'sine ait ülkenin en
alt ligindeki uygun kulüplerden biri atanır (D21) — bkz. `domain/team_assignment.py`.
En alt lig `competition.tier`'ın en büyüğü olarak **sorgulanır**, sabit bir
lig kimliği ile değil; yeni bir ülke eklemek bu mantığı değiştirmez.

Doğrulama hataları `422 invalid_request` döner: boş ad/soyad, katalogda olmayan
`nationality`, tanınmayan `position` (Kaleci dahil — v1'de rolü yok), tanınmayan
`role`, **seçilen pozisyona ait olmayan `role`** (mesaj o pozisyonun geçerli
rollerini sayar), tanınmayan `target_team_id`.

#### C2 · `GET /careers` — kariyer listesi

```jsonc
{ "careers": [
    { "career_id":    "car_9f2a71c4e0b8",
      "player_name":  "Efe Kaan",
      "player_age":   21,
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

#### C5 · `POST /careers/{cid}/skill-exams` — yetenek sınavı sonuçları

```jsonc
// İstek
{ "results": [ { "exam_id": "shooting", "level": 5 },
               { "exam_id": "passing",  "level": 3 },
               { "exam_id": "tackling", "level": 1 } ] }

// Yanıt 200
{ "career_id": "car_9f2a71c4e0b8",
  "results": [
    { "exam_id": "shooting", "level": 5, "attribute_key": "shooting",
      "before": 24.0, "after": 29.0, "applied": 5.0 } ] }
```

Kariyer oluşturulduktan sonra çağrılır. Kazanılan puan `level * points_per_level`
olup niteliğin **mevcut** değerine (rol bonusu dahil) eklenir, sınavın kendi
`max_value`'sunda kesilir — `applied` bu yüzden ham kazanımdan küçük olabilir.
Hangi sınavın hangi niteliği, hangi oranda ve hangi tavana kadar etkilediği tek
bir yerden yönetilir: `catalog/skill_exams.py`.

Bir sınav **bir kez** verilir; tekrarında `409 skill_exam_already_taken`. Toplu
istek önce bütünüyle doğrulanır — geçersiz bir not veya daha önce girilmiş bir
sınav varsa **hiçbiri** uygulanmaz. Güç ve Esneklik sınavlardan etkilenmez.

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

  "attributes": [                        // D30 · tüm anahtarlar, eksiksiz
    { "key": "condition",       "family": "saha", "value": 100.0, "level": 10 },
    { "key": "strength",        "family": "saha", "value": 30.0,  "level": 3  },
    { "key": "flexibility",     "family": "saha", "value": 30.0,  "level": 3  },
    { "key": "shooting",        "family": "saha", "value": 20.0,  "level": 2  },
    { "key": "passing",         "family": "saha", "value": 24.0,  "level": 2  },
    { "key": "dribbling",       "family": "saha", "value": 20.0,  "level": 2  },
    { "key": "tackling",        "family": "saha", "value": 20.0,  "level": 2  },
    { "key": "charisma",        "family": "kişi", "value": 74.0,  "level": 7  },
    { "key": "politeness",      "family": "kişi", "value": 58.0,  "level": 5  },
    { "key": "confidence",      "family": "kişi", "value": 51.0,  "level": 5  },
    { "key": "intelligence",    "family": "kişi", "value": 63.0,  "level": 6  },
    { "key": "resourcefulness", "family": "kişi", "value": 29.0,  "level": 2  }
  ],

  "fame": [ { "scope": "overall", "value": 0.0 } ],   // D35 · anlamı ⟦AÇIK-9⟧

  "market_value": { "current": 4200000,               // ⟦AÇIK-8⟧ formül
                    "measured_on": "2026-01-01" }
}
```

`attributes` **daima §3.2'nin tüm anahtarlarını** döner; değeri değişmemiş
anahtar da bulunur (INV-21). `family` veritabanında saklanmaz, kod kataloğundan
gelir. Yukarıdaki örnek `regista` rolüyle (iki yuva da `passing`) açılmış, henüz
sınava girmemiş bir kariyerin başlangıcıdır: taban 20, rol bonusu pas'a 2x2.
`condition` anahtarı **tavanı**, `career_state.condition` **bugünkü değeri**
taşır (D15) — ikisi aynı kavramın iki yüzüdür.

`level` **türetilmiştir** — `floor(value / 10)`, §3.2'nin tek kuralı (D43).
Gönderilmesinin tek sebebi FE'nin o kuralı kopyalamak zorunda kalmamasıdır:
kilitli bir seçeneği veya katalog kartını göstermek için gereken karşılaştırma
(`level >= requires[key]`) böylece iki tam sayı arasında kalır.

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
      "assists":           1,              // D13 · interventions[] outcome_key=="asist" sayısı
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

#### W5 · `GET /careers/{cid}/calendar`

```jsonc
// GET …/calendar?from=2026-08-01&to=2026-08-31   (ikisi de opsiyonel)
{ "from": "2026-08-01", "to": "2026-08-31", "today": "2026-08-19",
  "season": { "season_id": "25/26", "starts_on": "2026-08-01", "ends_on": "2027-05-31" },
  "days": [
    { "date": "2026-08-08", "marks": [
        { "kind": "match", "ref_id": "f_2526_lig1_r1_ykz_gal",
          "competition": { /* CompetitionRef */ }, "round_no": 1,
          "kickoff_at": "2026-08-08T20:00:00+03:00",
          "home": { /* TeamRef */ }, "away": { /* TeamRef */ },
          "status": "scheduled", "score": null, "is_user_match": true } ] },
    { "date": "2026-08-10", "marks": [ { "kind": "wage", "ref_id": null } ] },
    { "date": "2026-08-19", "marks": [
        { "kind": "cup_round", "ref_id": "c_kupa", "round_no": 1,
          "stage": "r32", "drawn": false } ] }
  ] }
```

Varsayılan aralık `game_date`'in içinde bulunduğu **aydır** — sık kullanım
çıplak bir GET olsun diye. Aralık `MAX_CALENDAR_DAYS`'i (62) aşarsa
`422 invalid_request`.

**Yalnız işaretli günler döner.** 31 günlük bir ayın beş işaretli günü varsa
beş satır gelir; boş grid FE'nin işidir, zaten hafta başlangıcı kaymasını
hesaplamak için `from`/`to`'yu bilmek zorunda.

**`marks[].kind`, T1'in `events[].kind`'ından ayrı bir sözlüktür** ve olması
gereken de budur:

| | Soru | Kapsam |
|---|---|---|
| T1 `events[]` | "Bugün ne **doğru**?" | `upkeep_warning`, `relationship_low`, `social_offer` … |
| W5 `marks[]` | "Bu güne ne **planlanmış**?" | `match` · `wage` · `cup_round` · `contract_expiry` · `season_start` · `season_end` |

`upkeep_warning` gelecekteki bir bakiyenin projeksiyonudur — bir ay sonrası
için hesaplanamaz. `relationship_low` ise hiç tarihi olmayan bir durumdur.
Buna karşılık `wage` ve `cup_round`, T1'de karşılığı olmayan takvim
gerçekleridir: maaş günü `WAGE_WEEKDAY`'den türetilir (aynı sabit §6.5'te
ödemeyi yapar, böylece grid ile defter payday konusunda ayrışamaz) ve kupa
turları **kura çekilmeden önce de** tarihlidir, yani "3 Kasım'da kupa maçın
var" rakip belli olmadan çizilebilir. Kurası çekilmiş tur artık bir fikstürdür
ve `match` olarak görünür.

Takım renkleri `home`/`away`'in `TeamRef`'lerinin içinde zaten gelir; günü
boyayacak FE'nin ayrıca bir alan istemesine gerek yok.

**v1 yalnızca kullanıcının kendi maçlarını gösterir.** Her kulübün her maçını
taşıyan bir grid takvim değil fikstür listesidir; oyuncunun sorusu "ben ne
zaman oynuyorum". İleride `competition=` parametresiyle genişletilebilir,
şekli değişmeden.

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
      "has_pending_request": false,       // R4 · bu ilişkiden açık teklif var mı
      "traits": { "trust": 74, "promised_minutes": 60, "tactical_fit": 0.8 } }
] }
```

Altı kategori döner (§3.4). `traits` içeriği `kind`'a göre değişir; FE tanıdığı
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
    { "key": "politeness", "before": 58.0, "after": 58.6,
      "level_before": 5, "level_after": 5 } ],       // D43 · türetilmiş
  "ledger_entries": [] }
```

Diyalog **ağacı** BE'de tutulmaz — o katalog içeriğidir (§3.4). BE yalnızca
`dialogue_id` + `choice_path` çiftini tanır ve karşılığındaki etkiyi uygular.
Skor ve olay günlüğü tek fonksiyondan yazılır (INV-15).

**Kilitli seçenek (D42).** Bir yaprağın `requires` eşiği varsa, oyuncunun o
niteliklerdeki seviyesi (§3.2) yetmediğinde çağrı **hiçbir şey yazmadan**
reddedilir:

```jsonc
// POST … {"dialogue_id": "media_01", "choice_path": ["r0"]}
// media_01:r0 -> requires { "charisma": 8 }, oyuncunun charisma'sı 74.0 (seviye 7)

// 409
{ "code": "requirement_not_met",
  "message": "'charisma' level 7, needs 8" }
```

**Konuşmak günün bütçesinden yer (§6.2/D41).** R3 başlangıçta bedelsizdi;
bu, onu **fırsat maliyeti olmayan tek aksiyon** yapıyordu — herkesi her gün
aramamak için hiçbir sebep yoktu, ilişki skorları kendiliğinden yukarı
sürükleniyor ve günün bütçesi karara hiç girmiyordu. Artık her yaprak
kendi `costs`'unu taşıyor (`catalog/dialogue.py`; yazmayan yaprak için
`DIALOGUE_DEFAULT_COSTS`), bazıları ayrıca `condition` oynatıyor — eve telefon
dinlendirir, antrenörle tartışma yıpratır.

Ölçü **günün bütçesi, takvim değil.** D5'te saat bir tam gün ve `game_date`
yalnızca T3'ün `advance`'ı içinde ilerliyor; R3 içinde tarihi itmek bir
konuşmanın maç gününü atlaması anlamına gelirdi. Gün **içindeki** zamanın
geçme biçimi `day_budget`'tır (§6.2), yani konuşmak takvimi değil günü harcar.

Harcama, yeterlilik kapısından (D42) **sonra** ve ilk yazmadan **önce**
yapılır; `day_budget.spend()` hiçbirine dokunmadan önce bütün kaynakları
kontrol ettiği için iki 409 yolundan hangisi tetiklenirse tetiklensin geriye
hiçbir iz kalmaz (INV-4/INV-30). Yetmezse `409 insufficient_budget`.

Yanıta `condition_after` eklendi: yaprak kondisyon oynatmıyorsa `null`.

**Sunum notu (§5.8).** Konuşmanın **nerede** geçtiği ve karşıdaki kişinin
**nasıl göründüğü** BE'den gelmez, ikisi de FE'nin sunum kararı — ikon ve
renk gibi. FE sahneyi ilişki türünden (ya da sosyal olayın şablonundan)
seçiyor, portreyi `relationship_id`'den deterministik türetiyor
(`lib/widgets/character_portrait.dart`). Bu yüzden yeni bir sahne ya da yeni
bir portre şeması sözleşmeyi değiştirmez.

#### R4 · `GET /careers/{cid}/social/offers`

```jsonc
{ "offers": [
    { "offer_id":        "so_9f21c3",
      "template_id":     "coach_extra_session",
      "relationship_id": "coach",
      "relationship": { "relationship_id": "coach", "kind": "coach",
                        "category": "Antrenör", "score": 74,
                        "person_name": "Mert Çalışkan", "contact_name": "Antrenör Mert" },
      "title": "Fazladan idman",
      "body":  "Antrenör Mert, yarın sabah antrenmandan önce seninle bire bir çalışmak istiyor.",
      "accept_label": "Sahada olurum",
      "decline_label": "Bu hafta olmaz",
      "costs":    { "time": 120, "energy": 20 },
      "requires": {},
      "opened_on": "2026-08-19",
      "status":    "open",
      "resolved_on": null } ] }
```

**Metin BE'de yazarlanır, cümle BE'de kurulmaz.** İkisi aynı şey değil: §1.3'ün
yasakladığı şey verinin cümleye çevrilmesidir ("3 gün kaldı"), yazarlanmış
içeriğin kendisi değil — `news`'in `title`/`body`'si de aynı şekilde gelir.
Teklifin bir dalı olmadığı için (bir paragraf, iki buton) metni FE'de tutmak,
yeni bir şablon eklemeyi iki depoda düzenleme yapmaya çevirirdi; diyalog
**ağaçları** FE'de kalmaya devam ediyor (D23), çünkü onların dallanması bir
arayüz yapısıdır.

`costs` ve `requires` gönderilir — oyuncu seçmeden **önce** kapıyı görmeye
hak kazanır (D42). `accept`/`decline` ödülleri gönderilmez, aynı gerekçeyle
`GET /catalog/dialogue`'un yalnızca kilitleri servis etmesi gibi.

#### R5/R6 · `POST /careers/{cid}/social/offers/{oid}/accept` · `…/decline`

Gövdesiz. Yanıt R3'ün şeklidir, artı çözümlenmiş `offer`:

```jsonc
{ "career_state": { /* CareerState */ },
  "offer": { "offer_id": "so_9f21c3", "status": "accepted",
             "resolved_on": "2026-08-19", /* … R4'ün alanları */ },
  "relationship_changes": [
    { "relationship_id": "coach", "before": 70, "after": 75, "delta": 5 } ],
  "attribute_changes": [ /* şablonun `attribute:*` etkileri */ ],
  "ledger_entries":    [ /* şablonun `money` etkisi */ ] }
```

**Kabulün kontrol sırası T2'nin tablosunun aynısıdır** (§5.5): teklif var mı
(`404 social_offer_not_found`) → açık mı (`409 social_offer_not_open`) →
`requires` (`409 requirement_not_met`) → bütçe (`409 insufficient_budget`) →
bakiye (`409 insufficient_funds`). Reddedilen bir kabul **hiçbir şey yazmaz**
ve teklif açık kalır — oyuncu hâlâ reddedebilir.

**Reddetme bu sıranın hiçbir adımını çalıştırmaz ve başarısız olamaz (INV-40).**
Cevap zorunlu olduğu için (D53) çıkış kapısının koşulsuz olması gerekir: parası
ve günü bitmiş bir oyuncu teklifi temizleyemezse kariyer kilitlenir.

`relationship.score` değişmez, `relationship_event`'e satır düşmez, hiçbir
nitelik oynamaz (INV-30). Kontrol `choice_path` çözümlendikten **sonra**,
`apply_delta()`'dan **önce** yapılır.

Eşiklerin kendisi FE'ye **N3 üzerinden önceden** verilir (`GET /catalog/dialogue`,
§5.7) — bu yüzden 409 normal akışta görülmez, istemcinin kilidi atlamasına karşı
sunucu-otoriter emniyet kilididir. Kullanıcının gördüğü şey gri bir seçenektir,
bir hata değil.

Her ağaçta gereksinimsiz **en az bir yaprak** bulunur (INV-32): bir konuşma
tamamen kilitlenip oyuncuyu çıkmaza sokamaz.

---

### 5.5 Zaman

#### T1 · `GET /careers/{cid}/day`

```jsonc
{ "career_state": { /* CareerState */ },
  "is_match_day": false,
  "events": [
    { "kind": "cup_draw",        "ref_id": "c_kupa",  "round_no": 5 },
    { "kind": "upkeep_warning",  "ref_id": null,      "shortfall": 800 },
    { "kind": "social_offer",    "ref_id": "so_9f21", "relationship_id": "coach",
      "opened_on": "2026-08-19" }                // §6.3 D53
  ],
  "condition_recovery": {                      // §6.6 · bir sonraki günün değeri
    "base": 5, "bonus": 2, "total": 7, "capped": false,
    "sources": [ { "item_id": "home-treadmill", "title": "Koşu bandı", "amount": 2 } ] } }
```

`events[].kind`: `match` · `cup_draw` · `contract_expiring` · `upkeep_warning` ·
`relationship_low` · `season_end` · `social_offer`. **Cümle gönderilmez** — FE `kind` ve `ref_id`
ile kendi metnini kurar (§1.3).

`condition_recovery`, `advance`'ın **bir sonraki** günü için uygulayacağı
toparlanmanın önizlemesidir (§6.6). `sources[]` sahip olunan eşyalardan gelen
payı ayrıştırır ki FE "+7 (koşu bandı +2)" diyebilsin; `title` yazarlanmış
katalog metnidir, kurulmuş bir cümle değil. Sayıyı hesaplayan tek yer
`domain/condition.daily_recovery()`'dir — önizleme ile uygulama iki ayrı yerde
hesaplansaydı ayrışabilirlerdi.

#### T2 · `POST /careers/{cid}/actions`

```jsonc
// İstek
{ "catalog_id": "sut",
  "result": { "minigame_score": 0.72 } }   // yalnızca drill'i olan kalemlerde

// Yanıt
{ "career_state": { /* CareerState */ },
  "applied_costs":   { "time": 60, "energy": 18 },
  "applied_effects": { "attribute:shooting": 1.4 },
  "attribute_changes": [ { "key": "shooting", "before": 50.0, "after": 51.4,
                           "level_before": 5, "level_after": 5 } ],
  "relationship_changes": [],
  "ledger_entries": [] }
```

`kind` alanı **istekte yoktur** — `catalog_id` zaten hangi katalogdan geldiğini
belirler. Bütçe yetmezse `409 insufficient_budget`, para yetmezse
`409 insufficient_funds`; her iki durumda da **hiçbir maliyet düşülmez ve
hiçbir etki uygulanmaz** (INV-3, INV-4).

**Kontrol sırası — yeterlilik en başta (D42).** Kalemin `requires` eşiği (§5.7)
bütçeden **önce** bakılır ve karşılanmıyorsa `409 requirement_not_met` döner:

| Sıra | Kontrol | Hata |
|---|---|---|
| 1 | `catalog_id` tanınıyor mu | `422 invalid_request` |
| 2 | **`requires` eşiği** | `409 requirement_not_met` |
| 3 | Günün bütçesi | `409 insufficient_budget` |
| 4 | Bakiye (`effects.money` negatifse) | `409 insufficient_funds` |

Sıra keyfi değil: yeterlilik kontrolü hiçbir şey okumaz-yazmaz, en ucuz ve en
erken reddedebilendir. Böylece "eşiği tutmayan aksiyon zamanımı yedi" durumu
şemaca imkânsızdır (INV-30). Aynı sıra T4'te de geçerlidir — orada 2. adımdan
sonra `already_owned` gelir.

**`attribute_changes` seviyeyi de taşır (D43).** `level_before`/`level_after`
ham değerlerden türetilmiştir ve aynı sebeple gönderilir: FE bu yanıtla yerel
kopyasını güncellediğinde bir kapının açılıp açılmadığını **kendi hesaplamadan**
görür. Aksi halde P1 formülü BE'de, aksiyon sonrası tazeleme FE'de olurdu ve
kural iki yere dağılırdı. Deltaların çoğu seviyeyi değiştirmez; çağıran bunu da
bedavaya öğrenir. Aynı alanlar R3'te de vardır (§5.4).

> C5'in (`skill_exam_results`) gövdesi **değişmez** — orası `before`/`after`
> alanlarını tek tek seçer ve yetenek sınavının kendi `level` alanı (1-5 not)
> D43'ün seviyesiyle aynı kavram değildir.

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
  "repossessed":   [],                     // D29 · elden çıkan eşyalar
  "stopped_events": [ /* durulan günün T1 events[] listesi */ ],
  "condition_before": 72,                  // §6.6 · çağrı öncesi
  "condition_after":  80 }                 // §6.6 · = career_state.condition
```

`stopped_events`, durulan günün **T1 listesinin aynısıdır** — durdurucuların
süzülmüş hâli değil. `stop_reason` bir etikettir; bir şey açması gereken çağıran
(fikstür, teklif) onun `ref_id`'sine muhtaçtır ve bunu öğrenmek için T1'i ikinci
kez çağırmak, bu çağrının zaten elinde olan veriyi tekrar istemek olurdu.

`condition_before`/`after`, gün gün ilerleyen bir istemcinin çubuğu kendi kopya
durumunu tutmadan canlandırabilmesi içindir (D55).

Atlanan **her** Pazartesi için ayrı maaş ve gider satırı yazılır — tek toplu
satır değil, geçmiş okunabilir kalsın diye (§6.5). Geçilen her günün fikstürleri
bütün müsabakalarda anında koşar (§6.7, D40).

Sezon bittiyse `409 season_finished`; terfi/düşme o çağrının içinde hesaplanır
ve `stop_reason: "season_end"` döner.

Cevaplanmamış bir sosyal teklif varsa çağrı **hiç ilerlemeden**
`409 social_offer_pending` döner ve mesajda `offer_id`'yi taşır (D53). Doğru
tepki teklifi açmaktır, tekrar denemek değil.

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
  "formation_id": "4-2-3-1",           // kullanıcının takımının dizilişi

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

**`formation_id` `engine_payload`'ın dışındadır.** Diziliş bir kariyer
kavramı — motorun `POST /matches` gövdesinde karşılığı yok, oraya konsa motor
onu tanımaz. Değer `worlddata/teams.py`'de takıma atanır ve `worlddata/
formations.py`'nin `FORMATION_IDS` listesinden gelir; her kariyerde aynıdır
(D9). Slot koordinatları burada taşınmaz: şekiller `formation_creator` ile
çizilip FE'ye `lib/game/formations.g.dart` olarak gömülür, BE yalnızca hangi
şeklin oynandığını söyler. FE tanımadığı bir id görürse kendi varsayılan
dizilişine düşer.

**Rating'ler kulüp gücüdür, başka hiçbir şey değil (D37).** Kullanıcının
nitelikleri buraya girmez (INV-26). `user_condition` takım bloklarının **içinde
değil**, gövdenin tepesindedir — motorun `Team.stamina`'sına yazılmadığı için
(D39).

Yarım kalan maç varsa `409 match_in_progress` ve `fixture_id` bildirilir (§6.4).
Bugün kullanıcının maçı yoksa `409 not_match_day` döner ve sonraki kickoff
tarihiyle kaç gün kaldığını bildirir (§6.1) — maç kendi gününde oynanır.

#### M2 · `POST /careers/{cid}/matches/{fid}/result`

```jsonc
// İstek — FE, motorun /summary yanıtını ve kendi müdahale kaydını gönderir
{ "match_id": "m_20260316_ykz_dnz",
  "score":    { "home": 2, "away": 1 },
  "stats":    { "home": { /* 13 anahtar */ }, "away": { /* 13 anahtar */ } },
  "final_possession_home": 53.1,
  "final_condition": 54,               // D38 · son tick'in player.condition'ı
  "interventions": [                   // D13/D34 · bireysel istatistik kaynağı
    { "minute": 63, "action_key": "finish_power", "outcome_key": "great" },
    { "minute": 78, "action_key": "long_shot",    "outcome_key": "bad" }
  ] }

// Yanıt 200
{ "career_state": { /* CareerState */ },
  "fixture": { "fixture_id": "f_…", "status": "played",
               "score": { "home": 2, "away": 1 } },
  "other_results": [ { "fixture_id": "f_…", "score": { "home": 0, "away": 0 } } ],
  "standing_delta": { "rank_before": 3, "rank_after": 2 },
  "player_stat_delta": { "appearances": 1, "goals": 1, "assists": 0, "minutes": 95 },
  "relationship_changes": [
    { "relationship_id": "coach", "before": 70, "after": 74, "delta": 4 },
    { "relationship_id": "team",  "before": 50, "after": 53, "delta": 3 },
    { "relationship_id": "fans",  "before": 40, "after": 44, "delta": 4 },
    { "relationship_id": "media", "before": 10, "after": 12, "delta": 2 }
  ],
  "ledger_entries": [ /* maç primi + gol primi */ ],
  "news_created": ["n_0143"] }
```

**Katı doğrulama (D33/D34'ün hafifletmesi).** Gövde FE'den geldiği için olduğu
gibi kabul edilmez (INV-23):

| Alan | Kural |
|---|---|
| `stats.{home,away}` | **Tam olarak 13 anahtar** ([`models.py:82-88`](../../match_engine/models.py)); eksik veya fazla kabul edilmez |
| `score.*` | `stats.*.goals` ile tutarlı olmalı |
| `interventions[].action_key` | Motorun 14 aksiyonluk kataloğundan (`API_CONTRACT.md` Ek B; v1.5'te 3 pas aksiyonu eklendi) |
| `interventions[].outcome_key` | Aksiyonun şemasına uygun (`catalog/match_actions.py`, `API_CONTRACT.md` §7.3/Ek B ile birebir): `graded` → `{great,good,bad}` (3 savunma + 3 pas aksiyonu), `graded4` (4 şut-minigame aksiyonu: `finish_power`/`finish_finesse`/`long_shot`/`counter_attack`) → `{great,asist,good,bad}`, `binary` → `{success,failure}` — **`"goal"`/`"save"` gibi serbest metin değil**. `final_ball`/`great` bir **asisttir** (`ASSIST_OUTCOMES`): dal gol basar ama vuruşu arkadaşı yapar |
| `interventions[].minute` | 1-95, artan sırada |
| `user_cards` | **Opsiyonel**; varsa tam olarak `{yellow, red}`, `yellow` 0-2, `red` 0-1. Yoksa sıfır sayılır |
| `final_condition` | 35-100 ve maç öncesi kondisyondan büyük olamaz |

İhlalde `422 invalid_match_result`; hiçbir tabloya yazılmaz.

Bu doğrulama hile önlemeye çalışmaz — tek oyunculu bir oyunda kullanıcı yalnızca
kendini aldatır. Amacı **sapmayı erken yakalamak**: motorda bir anahtar
değişirse ya da FE'nin defteri bozulursa sessiz veri bozulması yerine anında
hata alınır.

**`player_stat_delta.assists`** — `outcome_key == "asist"` ile çözümlenen
müdahale sayısı (yalnızca `graded4` aksiyonlarda anlamlı). `goals` ile
karşılıklı dışlayıcıdır: aynı müdahale ikisine birden sayılmaz — `is_goal()`/
`is_assist()` (`catalog/match_actions.py`) aynı `(action_key, outcome_key)`
çiftini asla ikisine de eşlemez.

**`relationship_changes`** — bu maçın `coach`/`team`/`fans`/`media`
ilişkilerinde yarattığı, kalıcı olarak yazılmış (`relationships.apply_delta`)
değişim; her zaman tam 4 kayıt, sırası her zaman bu (coach → team → fans →
media), `delta` her zaman `-5..5` aralığında. `partner`/`family`'ye
dokunulmaz — bir maç sonucu onların tetikleyicisi değil, tek yolları hâlâ
diyalog etkileşimi (§5.4/R3). Formül `domain/matches.py`'deki
`_match_relationship_deltas()`'ta yaşıyor: sonuç (galibiyet/beraberlik/
mağlubiyet) + kişisel gol/asist katkısı + sarı/kırmızı kart disiplini —
antrenör disiplin ve katkıya en çok ağırlık verir, takım en az kişisel-odaklı,
taraftar sonuca/gole en sert tepki verir, medya kart/gol gibi "manşetlik"
olaylara en duyarlı. ⚠️ İlk taslak — oyun testiyle kalibre edilmesi gerekebilir.

**Disiplinin kaynağı `user_cards`, `stats` değil.** Yukarıdaki "kart
disiplini" terimi bu maddenin en başından beri **oyuncunun kendi** kartını
kastediyordu, ama ilk uygulama `stats[user_side]` okuyordu — o blok
(`_STATS_KEYS`, motordan birebir kopyalanan 13 anahtar) **takımın tamamına**
ait. Sonuç: bir takım arkadaşı atıldığında kullanıcı tertemiz oynadığı hâlde
coach −2 / team −1 / fans −1 / media −2 yiyordu, üstelik takımın üçüncü
sarısı neredeyse her maç dolduğu için sarı cezası da rutin olarak tetikleniyordu.
Ayrıca çift sayımdı: kırmızı kart motorda zaten savunmayı 15 puan kırıyor
(`match_engine/models.py`), yani bedeli bu deltaların hesaplandığı skorda
ödenmiş oluyor.

Eşikler artık kişisel ölçekte: bir oyuncu en fazla iki sarı görebilir
(ikincisi zaten atılmadır), o yüzden eski takım-biçimli 3/2 kesme noktaları
sırasıyla erişilemez ve hep-erişilir hâldeydi.

v1'de `user_cards` **daima sıfırdır ve doğrusu budur** — motor kartı isimsiz
bir savunmacıya yazıp kimin gördüğünü tel üzerinde taşımadığı için kullanıcı
kart göremez. Alan, motor kartı sahiplendirdiği gün FE'nin gerçek sayıyı
yazacağı yer olarak duruyor; o güne kadar sunucu tarafında eksikliği sıfır
sayılır, yani eski gövdeler kırılmaz.

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

`kind`: `training` | `lifestyle` | `shop` | `dialogue`. **Kariyerden bağımsız**,
salt okunur — kariyere göre değişen tek şey eşiğin karşılanıp karşılanmadığıdır ve
onu FE, P1'in `level` alanıyla kendisi hesaplar (D42).

```jsonc
// GET /catalog/training
{ "items": [
    { "catalog_id": "kondisyon-kosusu", "title": "Kondisyon Koşusu",
      "description": "…", "family": "saha", "drill": "conditioning",
      "costs":   { "time": 90, "energy": 15 },        // ⟦AÇIK-5⟧ sayılar
      "effects": { "attribute:condition": 1.2 } },

    { "catalog_id": "medya-egitimi", "title": "Medya Eğitimi",
      "family": "kişi", "drill": null,
      "costs":    { "time": 60, "energy": 5 },
      "effects":  { "attribute:charisma": 0.8, "money": -1500 },
      "requires": { "confidence": 6 } }              // D42 · seviye eşiği
] }

// GET /catalog/lifestyle
{ "items": [
    { "catalog_id": "ev-uyku", "title": "Uyku", "description": "…",
      "duration_label": "Tüm gece", "group": "EV AKTİVİTELERİ",
      "costs":   { "time": 540 },
      "effects": { "condition": 14, "energy": 100 } },

    { "catalog_id": "sos-taraftar", "title": "Taraftar Etkinliği",
      "duration_label": "2 saat", "group": "SOSYAL",
      "costs":    { "time": 120 },
      "effects":  { "condition": -2, "attribute:charisma": 0.5,
                    "fame:overall": null },                    // ⟦AÇIK-9⟧
      "requires": { "charisma": 7 } }
] }

// GET /catalog/shop
{ "items": [
    { "catalog_id": "daire-merkez", "title": "…", "description": "…",
      "category": "housing", "price": 250000,
      "upkeep_weekly": 1800,                    // D27
      "daily_effects": { "condition": 1 },      // D51 · opsiyonel, pasif
      "note": "3+1, 120 m²" } ] }

// GET /catalog/dialogue — yalnızca kilitler, ödüller DEĞİL
{ "items": [
    { "dialogue_id": "coach_01", "relationship_id": "coach",
      "leaves": [
        { "leaf_id": "r0", "requires": { "politeness": 6 } },
        { "leaf_id": "r1", "requires": {} },
        { "leaf_id": "r2", "requires": { "intelligence": 6 } } ] } ] }
```

**`costs` günü kapatır, `effects` dünyayı değiştirir** (§6.2). Para bir `cost`
değil, negatif bir `effect`'tir.

`effects` anahtar uzayı: `attribute:<key>` · `condition` · `energy` · `money` ·
`fame:<scope>` · `relationship:<rid>`. Tanınmayan anahtar taşıyan katalog kalemi
**yüklenmez** (INV-28) — serbest haritanın bedeli yazım hatasının sessizce
geçmesidir, bu doğrulama onu kapatır.

#### `requires` — üçüncü harita (D42)

Her `kind` için **isteğe bağlıdır**; yokluğu boş sözlükle eşdeğerdir. Anahtarı
§3.2'nin nitelik kataloğundan bir `attribute_key`, değeri **0-10 arası bir tam
sayı** (seviye, D43). Anahtarı veya değeri geçersiz olan kalem, `costs`/`effects`
ile aynı sertlikte **yüklenmez** (INV-31, INV-28'in kardeşi).

```jsonc
"requires": { "charisma": 8, "confidence": 6 }   // hepsi birden sağlanmalı
```

Eşiği karşılanmayan kalem T2/T4'te `409 requirement_not_met` ile reddedilir ve
**hiçbir maliyet düşülmez** (INV-30) — `insufficient_budget`'la aynı "ya hep ya
hiç" okuması, sırası ondan da öncedir.

**`dialogue` kataloğu `relationship_delta` ve `attribute_effects` göndermez.**
FE'nin bir seçeneği kilitli göstermek için ihtiyacı olan tek şey `requires`'tır;
ödül tablosunu yayınlamak hem konuşmanın sürprizini bozar hem de sunucu-otoriter
olmasının sebebini (D23: istemci kendine puan yazdıramaz) anlamsızlaştırır.

`drill` alanı [`training_result.dart:23`](../lib/game/training_result.dart)'teki
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
| `moneyLabel` ("48.200 ₭") | FE | [`player_state.dart:29`](../lib/state/player_state.dart) zaten biçimliyor |
| `imageAsset` | FE | Dosya yolu, FE paketinin içinde |
| Aylık maaş | FE | `weekly_wage × 4`, türetilmiş |
| `rank`, `goal_difference` | **BE gönderir** | Sıralama tabloya bağlı; FE tek satırdan hesaplayamaz |

---

## 6. ZAMAN MODELİ (D5)

### 6.1 Gün

Dünyanın tek saati `career_state.current_date`. Bir gün:
kullanıcı günün bütçesi elverdiğince aksiyon harcar (§6.2) → `POST /advance`
günü kapatır ve bütçeyi yeniden doldurur.

**Maç yalnızca kendi gününde oynanır.** M1 (`GET /matches/next`) tarihi
`current_date` olan fikstürü verir; başka bir gün `409 not_match_day` döner ve
sonraki kickoff tarihini bildirir. Bu kapı olmadan tasarımda `POST /advance`'i
çağırmaya zorlayan hiçbir şey yoktu: kullanıcı bütün sezonu tek bir oyun günü
içinde oynayabiliyor, maçlar arasındaki hafta — bu servisin var oluş sebebi
olan gün döngüsü — hiç yaşanmıyordu.

Takvim bunu taşıyacak şekilde kurulur: lig turları 7 gün arayla ve daima
cumartesi, kupa turları 14 gün arayla ve daima çarşamba (§3.3 v1 dünyası), bir
takım aynı güne iki fikstürle düşmez. Kariyer sezon açılışından **bir hafta
önce** başlar, yani ilk maçtan önce oynanacak tam bir hazırlık haftası vardır.

**Maç günü zorunludur (D57).** Kullanıcının kendi fikstürü `current_date`'te
hâlâ `'scheduled'`sa, `POST /advance` **hiç ilerlemeden**
`409 match_day_unplayed` döner ve mesajda `fixture_id`'yi taşır. Tek çıkış
yolu maçı oynamaktır (M1 → M2); `POST /matches/{fid}/abandon` (M3) yarım
kalmış bir oturumu `'scheduled'`'a döndürüp yeniden denemeyi mümkün kılar.

> **Eski "kaçırılan maç" kaldırıldı.** v1'de bu kapı yerine ilerlemeye izin
> verilir, fikstür arka planda oynanırdı (müsabaka/prim/gol yazılmadan) —
> gerekçe motor erişilemezken kariyeri kilitleme korkusuydu. Geri bildirim
> bunun tam tersini istedi: maç atlanamamalı. Risk kabul edildi, çünkü
> zaten maç oynamak motora muhtaç — bu kural motora yeni bir bağımlılık
> eklemiyor, yalnızca "bedava atlama" yolunu kapatıyor.

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

**Durma ölçütü kenar-tetiklidir.** T1 bugün doğru olan **her** koşulu
`events[]`'te bildirir; T3 yalnızca gerçekten *olay* olanlarda durur. Ayrım
şurada yatıyor: "ilişki skoru eşiğin altında" bir **durum**dur, kullanıcı bir
şey yapana kadar sürer — durma sebebi sayılırsa her gün olaylı olur ve takvim
bir daha asla sonraki maça ulaşamaz. Bu yüzden `relationship_low` durdurmaz
(T1 göstermeye devam eder) ve `contract_expiring` yalnızca pencerenin açıldığı
gün durdurur. Yukarıdaki cümlenin kendi ifadesi de zaten böyleydi: "eşiğin
altına **düştüğünde**", "30 gün **kala**".

**Sosyal teklif de kenar-tetiklidir (D53).** T3 teklifin *geldiği* gün durur;
sonraki günlerde T1 onu bildirmeye devam eder ama durma ölçütü sayılmaz —
sayılsaydı takvim, `relationship_low` için anlatılan tuzağın aynısına düşerdi.
Cevap zorunluluğunu sağlayan şey durma değil, çağrının **kapıdaki** reddidir:
açık teklif varken `POST /advance` `409 social_offer_pending` atar. Böylece
"sıfır gün ilerledi, sebep yok" gibi sessiz bir durum hiç oluşmaz, ve
uygulama teklif ekrandayken kapansa bile durum kurtarılabilir kalır.

Teklif üretimi günlük bir zar atışıdır (`SOCIAL_OFFER_DAILY_CHANCE`), kariyerin
kendi seed'inden türetilir (INV-7) ve aynı anda en fazla bir teklif açık olabilir
(INV-39). Havuz `content/social_offers.py`'dir; yeni bir şablon eklemek yalnız o
dosyayı düzenlemektir.

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

> **v1 sözleşme ölçeği — ₭ (Kredi).** Para birimi ₺ değil **Kredi**;
> `api/config.py` başlangıç sözleşmesini tier 2'ye (D21) göre yazıyor:
> maaş **40 ₭/hafta** (çapa), maç primi 6, gol primi 12, serbest kalma 900,
> başlangıç bakiyesi 60.
>
> Ölçek düz bir bölme değil: ₺ değerlerini 1000'e bölmek ucuz uçtaki her şeyi
> (yaşam tarzı, kişi antrenmanı) 0-2 aralığına çökertip aralarındaki farkı
> siliyordu. Ekonomi ₭ üzerinde yeniden katmanlandı — yaşam tarzı 1-8,
> kişi antrenmanı 3-10, dükkân 40-9.000, haftalık gider 0/4/12/30.
> Veri dosyası ayarıdır, şema değil (§10.1 B-1 bununla kapandı).

### 6.6 Kondisyon döngüsü (D38)

**Günlük toparlanma taban + eşya bonusudur (D51/D52).** Atlanan her gün
`NATURAL_CONDITION_RECOVERY_PER_DAY` tabanını, artı sahip olunan her eşyanın
`daily_effects.condition` payını öder; toplam `MAX_CONDITION_RECOVERY_PER_DAY`
ile kesilir (INV-41) ve sonra her zamanki gibi nitelik tavanına sıkışır
(INV-10). Bonus **delta'nın boyunu** değiştirir, tavanı değil: tavandaki bir
oyuncu bütün rafı almış olsa da tavanda kalır.

Bonus tablosu `catalog/shop.py`'ın kendi satırlarından türetilir; yeni bir kalem
eklemek yalnız o dosyayı düzenlemek demektir — toplama, tavan ve önizleme
zaten veriden okur.

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
| Toparlanma | Yaşam aktiviteleri, atlanan günler ve sahip olunan eşyalar | §6.2, §6.3 |

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
| INV-12 | Dünyanın bugününe kadarki **her** fikstür oynanmıştır — hiçbir müsabaka geride bırakılmaz. Diğer takımlarınki arka planda anında koşar (D40); kullanıcının kendisininki oynanana kadar `advance`'i kapıda durdurur (D57) |
| INV-13 | Terfi/düşme hesaplanmadan önce o sezonun bütün müsabakaları tamamlanmış olur |
| INV-14 | Bir takım aynı sezonda birden fazla lig'e (`kind='league'`) giremez |
| INV-15 | `relationship.score` yalnızca `relationships.apply_delta()` üzerinden yazılır; aynı transaction'da olay günlüğüne satır düşer (D24) |
| INV-16 | `relationship.traits` daima o `kind`'ın Pydantic modelini doğrular; tanınmayan alan yazılmaz (D23) |
| INV-17 | `career_state.money` yalnızca `wallet.apply()` üzerinden yazılır; aynı transaction'da `money_ledger` satırı düşer (D25) |
| INV-18 | Durumu değiştiren her yanıt tam `career_state` bloğunu taşır (D28) |
| INV-19 | `money_ledger` toplamı daima `career_state.money`'ye eşittir |
| INV-20 | Düzenli gider hiçbir zaman bakiyeyi negatife düşürmez; karşılanamıyorsa eşya elden çıkar (D29) |
| INV-21 | `player_attribute.attribute_key` daima §3.2'deki anahtar kataloğundan biridir; tanınmayan anahtar yazılmaz (D30) |
| INV-22 | Hiçbir nitelik kendiliğinden azalmaz — yaş, form veya zaman nitelik düşürmez (D32) |
| INV-23 | FE'den gelen maç sonucu katı doğrulamayı geçmeden hiçbir tabloya yazılmaz (D33, §5.6) |
| INV-24 | `player_fame.value` yalnızca `fame.apply()` üzerinden yazılır; aynı transaction'da `fame_event` satırı düşer (D35) |
| INV-25 | Maç sonrası geri yazılan kondisyon **35** (motorun tabanı) ile `player_attribute['condition']` (kullanıcının tavanı) arasına sıkıştırılır (D38) |
| INV-26 | Kullanıcının nitelikleri motora giden hiçbir rating'e girmez — `compute_team_rating()` kulüp gücünü değiştirmeden döner (D37) |
| INV-27 | Kullanıcının kondisyonu hiçbir maç olasılığını değiştirmez; motorun `Team.stamina`'sına yazılmaz (D39) |
| INV-28 | Katalogdaki her `costs` / `effects` anahtarı tanınan kataloğa aittir; bilinmeyen anahtar taşıyan kalem yüklenmez (D41) |
| INV-29 | `day_budget` her gün başında yeniden doldurulur ve hiçbir kaynak negatife düşmez (D41) |
| INV-30 | `requires` eşiği karşılanmayan hiçbir aksiyon, satın alma veya diyalog seçimi **hiçbir** maliyet düşmez ve **hiçbir** etki uygulamaz → `409 requirement_not_met` (D42) |
| INV-31 | Her `requires` anahtarı §3.2'nin nitelik kataloğundan, her değeri 0-10 aralığında bir tam sayıdır; ihlal eden kalem yüklenmez (D42/D43) |
| INV-32 | Her diyalog ağacında gereksinimsiz **en az bir** yaprak bulunur — hiçbir konuşma tamamen kilitlenemez (D42) |

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
| 409 | `requirement_not_met` | Kalemin/yaprağın `requires` eşiği karşılanmıyor (D42); mesaj hangi nitelik, mevcut ve gereken seviyeyi taşır |
| 409 | `already_owned` | Ürün zaten alınmış |
| 409 | `skill_exam_already_taken` | Yetenek sınavı bu kariyerde zaten verilmiş (C5) |
| 409 | `match_in_progress` | Yarım kalan maç var (§6.4) |
| 409 | `not_match_day` | M1 çağrıldı ama bugün kullanıcının maçı yok (§6.1); mesaj sonraki kickoff tarihini ve kaç gün kaldığını taşır |
| 409 | `fixture_already_played` | Sonuç ikinci kez yazılmak isteniyor |
| 409 | `season_finished` | Sezon bitti, ilerletilemez |
| 409 | `match_day_unplayed` | Kullanıcının bugünkü maçı hâlâ `'scheduled'`ken `advance` çağrıldı (D57); mesaj `fixture_id` taşır |
| 409 | `social_offer_pending` | Cevaplanmamış sosyal teklif varken `advance` çağrıldı (D53); mesaj `offer_id` taşır |
| 409 | `social_offer_not_open` | Teklif zaten cevaplanmış |
| 404 | `social_offer_not_found` | Bilinmeyen `offer_id` |
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
| ~~B-1~~ | ~~**v1 sözleşme ölçeği**~~ | **KAPANDI** — para birimi ₺'den **₭ (Kredi)**'ye geçti ve bütün ekonomi tek ölçekte yeniden katmanlandı (§6.5). FE'nin sabitleriyle çelişki kalmadı | §6.5 · `api/config.py` |
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

---

## 11. SEZON DEVRİ

> Bu bölüm **v1.0 imzalandıktan sonra** eklendi. Yukarıdaki metne dokunulmadı;
> çelişen noktalar §11.0'da tek tek sayıldı. Çelişki gördüğün her yerde
> **§11 kazanır**.
>
> Kapatılan boşluk: servis bugüne kadar sezonu **başlatabiliyor ama
> bitiremiyordu**. `POST /advance` sezon sınırında `409 season_finished` atıp
> kariyeri kilitliyordu — terfi/düşme, yeni sezon, sözleşme devri hiç yoktu.

### 11.0 Geçersiz kılınanlar

| Nerede | v1.0'da | §11'de |
|---|---|---|
| §5.5 T3 | "terfi/düşme **o çağrının içinde** hesaplanır" | `advance` devir **yapmaz**; devir ayrı bir uçtur (S1 · D46) |
| §9 | `409 season_finished` | **Emekli.** Yerine `409 season_rollover_required` (§11.9) |
| §3.3 D20 | Süper Lig'den 2 düşer, 1. Lig'den 2 çıkar | **3 düşer / 3 çıkar** (§11.4) |
| §5.2 P3 | Sözleşme süresi gün cinsinden (730) | Süre **sezon** cinsinden; bitiş daima sezon sınırı (§11.7 · D50) |
| §3.3 | Sezon `2026-08-01 → 2027-05-31`, devre arası yok | §11.1'in takvimi — **1. sezon dahil** |

`match_engine` eki (§7) **etkilenmez**: devir hiçbir maç simülasyonu tetiklemez,
yalnızca oynanmış fikstürleri okur.

---

### 11.1 Sezon takvimi (D44)

Sezon **Ağustos sonu – Haziran başı**. İki tatil dönemi vardır; ikisi de birer
transfer penceresidir.

| Dönem | Lig maçı | Transfer |
|---|---|---|
| Ağustos sonu – Aralık (ilk yarı) | **var** | yok |
| Ocak (devre arası) | yok | **var** |
| Şubat – Haziran başı (ikinci yarı) | **var** | yok |
| Haziran başı – Ağustos sonu (sezonlar arası) | yok | **var** |

Sınırlar **türetilir**; `Y` sezonun açıldığı takvim yılıdır:

| Sabit | Kural | 26/27 |
|---|---|---|
| `league_starts_on` | `Y` Ağustos'unun **son Cumartesi**si | `2026-08-29` |
| `starts_on` | `league_starts_on − 7 gün` (hazırlık haftası) | `2026-08-22` |
| `cup_starts_on` | `league_starts_on + 4 gün` (Çarşamba) | `2026-09-02` |
| `winter_break_from` | `Y+1` 1 Ocak | `2027-01-01` |
| `winter_break_to` | `Y+1` 31 Ocak | `2027-01-31` |
| `ends_on` | `Y+1` Haziran'ının **ilk Cumartesi**si | `2027-06-05` |

`season_id` `starts_on`'un yılından türer: `2026-08-22` → `"26/27"`.

> ⚠️ v1.0'ın `SEASON_ID = "25/26"` sabiti `2026-08-01` başlangıcıyla **zaten
> tutarsızdı** (25/26 sezonu Ağustos 2025'te açılırdı). Türetme bunu düzeltir;
> `"25/26"` bekleyen mevcut testler güncellenir.

#### Fikstür yerleşimi

- Lig turları haftalık, Cumartesi. Bir tur tatil aralığına düşerse **bir sonraki
  uygun haftaya kayar** — tatile lig maçı konmaz (INV-33).
- Kupa turları 14 günde bir, Çarşamba: lig Cumartesilerine çakışmaz (v1.0'ın
  `CUP_STARTS_ON` gerekçesi aynen geçerli — bir takım aynı güne iki fikstüre
  düşerse M1'in "bugünkü maç" sorgusunun seçme yolu yoktur).
- Bir takım **3'ten fazla** arka arkaya iç saha veya deplasman oynamaz.

**Sığma denetimi (18 takım · 34 tur):** r1 = 29 Ağu · r18 = 26 Ara · Ocak boş ·
r19 = 6 Şub · r34 = **22 May** → `ends_on`'dan (5 Haz) önce biter. 14 takımlı
1. Lig 26 turla rahat sığar.

---

### 11.2 Sezon durumu (D45)

```text
PRE_SEASON → FIRST_HALF → WINTER_BREAK → SECOND_HALF → SEASON_END
     ↑                                                      ↓
     └───────────── SUMMER_TRANSFER_WINDOW ←──────── S1 (devir)
```

API'de küçük harf taşınır: `pre_season` · `first_half` · `winter_break` ·
`second_half` · `season_end` · `summer_transfer_window`.

**Faz SAKLANMAZ — türetilir.** `career_state`'e kolon eklenmez. Gerekçe D43'ün
kurduğu örüntüdür: nitelik `level`'ı da saklanmaz, ham değerden türetilir ve
yanıta türetilmiş hâliyle konur. Faz da aynı cinstendir — `game_date` ile
`season` satırından tek okumada çıkar. Saklamak, "kolon ile takvim ayrışmasın"
diye bir senkron invariant'ı borçlanmak olurdu; türetmenin bedeli ise bir satır
`SELECT`'tir.

Türetme üç adımdır:

| Adım | Koşul | Sonuç |
|---|---|---|
| 1 | `game_date` bir sezonun `[starts_on, ends_on]` aralığında | aşağıdaki iç tablo |
| 2 | Değilse, `starts_on > game_date` olan bir sezon **var** | `summer_transfer_window` |
| 3 | Değilse (sonraki sezon yok) | `season_end` |

2. ve 3. adımın ayrımı bu bölümün mantığını taşır: **devir yapılmışsa** ileride
duran bir sezon satırı vardır ve oyuncu yazdadır; **yapılmamışsa** yoktur ve
kariyer sezon sonunda bekler. Ayrı bir bayrağa gerek kalmaz.

Sezonun içi:

| Koşul | Faz |
|---|---|
| `starts_on ≤ d < league_starts_on` | `pre_season` |
| `league_starts_on ≤ d < winter_break_from` | `first_half` |
| `winter_break_from ≤ d ≤ winter_break_to` | `winter_break` |
| `winter_break_to < d ≤ ends_on` | `second_half` |
| `d ≤ ends_on` ama sezonun **tüm** fikstürleri `played` | `season_end` |

`league_starts_on` sabitten değil **veriden** okunur: o sezonun `kind='league'`
turlarının `MIN(scheduled_on)`'u. Böylece takvim kuralı bir gün değişse bile faz
türetmesi fikstürle uyumlu kalır.

Son satır sezonu **erken** bitirebilir: takvim Haziran'ı gösterse de son maç
Mayıs'ta oynandıysa faz `season_end`'dir ve devir hemen yapılabilir.

Faz her değiştiğinde T1/T3 bir `season_phase_change` olayı üretir ve bu olay
**durdurucudur**: `advance` devre arasına ve sezon sonuna kendiliğinden park eder.

---

### 11.3 Şema eki — `007_season_rollover.sql`

```sql
-- Devre arası sezonun kendi verisidir, kod sabiti değil: season tablosu zaten
-- starts_on/ends_on'u türetmek yerine SAKLIYOR, tatil sınırı da aynı cinsten.
-- Eski kariyerlerin satırları NULL kalır ve "devre arası yok" diye okunur.
ALTER TABLE season ADD COLUMN winter_break_from TEXT;
ALTER TABLE season ADD COLUMN winter_break_to   TEXT;

-- Ligin kıta turnuvası kontenjanını belirleyen puan. kind='league' dışında NULL.
ALTER TABLE competition ADD COLUMN international_score INTEGER;   -- ⟦AÇIK-12⟧

-- Sezon sonu defteri. Nihai sıralama fixture'dan yeniden TÜRETİLEBİLİR (INV-2),
-- ama sonuçlar türetilemez: kontenjan sayısı ve terfi/düşme kuralı zamanla
-- değişebilir, geçmiş sezonun kararı ise değişmemelidir.
--
-- Dört bayrak, tek 'outcome' enum'u değil: 1. sıradaki takım aynı anda HEM
-- şampiyon HEM kıta katılımcısıdır; tek kolon ikisini taşıyamaz.
CREATE TABLE season_result (
  career_id      TEXT NOT NULL REFERENCES career(career_id) ON DELETE CASCADE,
  season_id      TEXT NOT NULL,
  competition_id TEXT NOT NULL,
  team_id        TEXT NOT NULL,
  final_rank     INTEGER NOT NULL,
  is_champion    INTEGER NOT NULL DEFAULT 0,
  continental    INTEGER NOT NULL DEFAULT 0,
  promoted       INTEGER NOT NULL DEFAULT 0,
  relegated      INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (career_id, season_id, competition_id, team_id)
);

-- Kullanıcıya açılan sözleşme teklifleri (§11.7). Kadro yoktur (D4 korunur) —
-- bu tablonun tek öznesi kullanıcının kendisidir.
CREATE TABLE transfer_offer (
  career_id        TEXT NOT NULL REFERENCES career(career_id) ON DELETE CASCADE,
  offer_id         TEXT NOT NULL,            -- 'o_' + 12 hex
  opened_on        TEXT NOT NULL,
  window           TEXT NOT NULL,            -- 'winter' | 'summer'
  team_id          TEXT NOT NULL,
  weekly_wage      INTEGER NOT NULL,
  appearance_bonus INTEGER NOT NULL,
  goal_bonus       INTEGER NOT NULL,
  release_clause   INTEGER NOT NULL,
  length_seasons   INTEGER NOT NULL,
  expires_at       TEXT NOT NULL,            -- kabul edilirse sözleşmenin bitişi
  status           TEXT NOT NULL,            -- 'open' | 'accepted' | 'expired'
  PRIMARY KEY (career_id, offer_id)
);
```

`career_state`'e **dokunulmaz** (D45). `fixture.status` da değişmez: şartname iki
durum sayıyor ama §6.4'ün yarım kalan maç kurtarması `in_progress`'e muhtaç.
Sezon tamamlanma koşulu ikisini birden kapsar — `scheduled` **ve** `in_progress`
satır kalmamalıdır.

`o_` ön eki §5.0'ın kimlik tablosuna eklenir.

---

### 11.4 Sıralama, şampiyonluk, kontenjan, terfi/düşme

#### Puanlama
Galibiyet **3** · beraberlik **1** · mağlubiyet **0**. `standing` VIEW bunu zaten
uyguluyor; değişiklik yok, INV-2 geçerli.

#### Eşitlik bozma (W2'nin sıralaması)
**puan → averaj → atılan gol → yenilen gol → ikili averaj → galibiyet sayısı**.
Hepsi eşitse `team_id` (kararlılık için; anlamlı değil).

> **Ölü ölçüt — 4. sıra hiçbir zaman ayırt etmez.** Averaj = atılan − yenilen
> olduğundan, puan + averaj + atılan golü eşit iki takımın yenilen golü
> **zorunlu olarak** eşittir. Ölçüt sırada tutulur (şartnamenin niyetini
> belgeler, zararı yok) ama ayırıcı gücü sıfırdır; sıralamayı fiilen **ikili
> averaj** kırar.

**İkili averaj tek SQL'de çıkmaz.** `standing` satır başına toplar; ikili averaj
yalnız eşit puanlı **alt grubun kendi arasındaki** fikstürlerden hesaplanır.
Sıralama bu yüzden iki aşamalıdır: SQL ilk dört ölçütü verir, eşit kalan grup
API katmanında kendi mini tablosuyla ayrıştırılır.

#### Şampiyonluk
Nihai sıralamada 1. olan takım şampiyondur. Ayrı hesap yoktur.

#### Kıta turnuvası kontenjanı (D49)
**v1'de yalnızca kontenjan hesaplanır.** Fikstür üretilmez, maç oynanmaz,
`kind='continental'` satırı açılmaz. "Şu takımlar gitti" bilgisi
`season_result.continental`'e yazılır ve özette/haberde döner.

Kontenjan ligin `international_score`'undan gelir — ⟦AÇIK-12⟧:

| `international_score` | Kontenjan |
|---|---|
| `< 20` | 0 |
| `20-39` | 1 |
| `40-59` | 2 |
| `60-79` | 3 |
| `≥ 80` | 4 |

v1 dünyası: Süper Lig **45** → 2 · 1. Lig **5** → 0. İkisi de placeholder;
gerçek ölçek ⟦AÇIK-12⟧ ile gelir ve **sürüm numarasını değiştirmez** (§10 kuralı).

#### Terfi ve küme düşme
- **3 çıkar, 3 düşer.** `competition_rule`'un sayıları 2'den 3'e çekilir.
- En üst kademede (`promotes_to_competition_id IS NULL`) terfi **yok**; en alt
  kademede (`relegates_to_competition_id IS NULL`) düşme **yok**.
- Terfi sayısı = düşme sayısı olduğundan mevcut korunur (INV-34): Süper Lig 18,
  1. Lig 14 sabit.
- Hareket `competition_entry`'de yaşar. Eski sezonun satırları **silinmez** —
  `season_id` ile ayrışırlar, geçmiş sezonun tablosu okunabilir kalır.

---

### 11.5 S1 · `POST /careers/{cid}/season/rollover` (D46, D47)

Sezon devrinin **tek** giriş noktası.

**Ön koşul sırası** (§5.5 T2'nin kontrol tablosuyla aynı disiplin — en ucuz ret
en başta, hiçbir şey yazılmadan):

| Sıra | Kontrol | Hata |
|---|---|---|
| 1 | Kariyer tanınıyor mu | `404 career_not_found` |
| 2 | Faz `season_end` mi | `409 season_not_finished` |
| 3 | `scheduled`/`in_progress` fikstür kaldı mı (INV-13) | `409 season_not_finished` |

2. ve 3. aynı kodu döner çünkü kullanıcı için tek durumdur ("sezon daha bitmedi");
mesaj kaç maçın kaldığını taşır.

**Tek transaction** (INV-36), sırayla:

1. Nihai sıralama → her lig için `season_result` (şampiyon · kontenjan · terfi ·
   düşme bayrakları)
2. Terfi/düşme uygulanır → **yeni sezonun** `competition_entry` satırları
3. Sözleşme kontrolü (§11.7): `expires_at` bu sezonun `ends_on`'u olan sözleşme
   kapanır, kullanıcı serbest kalır, teklifler üretilir
4. Yeni `season` satırı + her lig için tam fikstür + kupa takvimi (§11.1)
5. Şampiyonluk / terfi / düşme haberleri

**`game_date` DEĞİŞMEZ** (D47). Kullanıcı Haziran–Ağustos günlerini normal
`advance` ile yaşar: antrenman yapar, para harcar, ilişki yürütür, teklif
değerlendirir. Faz o anda kendiliğinden `summer_transfer_window`'a düşer —
§11.2'nin 2. adımı artık ileride bir sezon satırı bulur.

```jsonc
// İstek — gövde yok

// Yanıt
{ "career_state": { /* CareerState — season_phase: "summer_transfer_window" */ },
  "previous_season_id": "26/27",
  "new_season_id":      "27/28",
  "summary": { /* §11.6'nın SeasonSummary bloğu */ },
  "user": {
    "team":            { /* TeamRef */ },
    "competition":     { /* CompetitionRef — YENİ sezondaki ligi */ },
    "final_rank":      7,
    "outcomes":        [],            // 'champion'|'continental'|'promoted'|'relegated'
    "contract_status": "expired",     // 'active' | 'expired'
    "moved_with_team": false          // takımı düştü/çıktı mı
  },
  "offers":       [ /* TransferOffer[] — §11.7 */ ],
  "news_created": ["n_0210", "n_0211"] }
```

---

### 11.6 S2 · `GET /careers/{cid}/season/summary`

Sorgu: `?season=26/27` (varsayılan: **en son tamamlanmış** sezon). Devri kaçıran
ya da geçmişe bakan FE için. Tamamlanmamış sezon istenirse
`409 season_not_finished`.

```jsonc
// SeasonSummary
{ "season_id": "26/27",
  "leagues": [
    { "competition": { /* CompetitionRef */ },
      "champion":    { /* TeamRef */ },
      "rows": [
        { "team": { /* TeamRef */ }, "final_rank": 1,
          "outcomes": ["champion", "continental"],
          "played": 34, "won": 24, "drawn": 6, "lost": 4,
          "goals_for": 71, "goals_against": 30,
          "goal_difference": 41, "points": 78 }
      ] }
  ],
  "continental_slots": { "c_lig1": 2, "c_lig2": 0 } }
```

**Cümle yok** (§1.3): `outcomes` bir enum dizisidir, "Şampiyon oldu!" metnini FE
kurar. Kupa (`kind='cup'`) `leagues` dizisinde **yer almaz** — eleme usulünde
tablo yoktur (`409 no_standings`'in aynı gerekçesi).

---

### 11.7 Transfer ve sözleşme (D48, D50)

**Kadro yoktur.** D4 korunur: bir kariyerde hâlâ tam olarak bir oyuncu satırı
vardır (`is_user = 1`). Şartname §12'nin "oyuncular başka takımlara transfer
olabilir" maddesi v1'de **yalnızca kullanıcı** için geçerlidir; NPC transferi ve
kadro derinliği bu sürümde yoktur.

#### Pencereler
Pencere = `winter_break` **veya** `summer_transfer_window` fazı. Başka fazda
kabul denemesi `409 no_transfer_window`.

#### Sözleşme bitişi (D50)
Bir sözleşme **yalnızca iki tarihten birinde** biter (INV-35):
1. Devre arasının ilk günü (`winter_break_from`)
2. Sezonun son günü (`ends_on`)

Süre bu yüzden **gün değil sezon** cinsindendir (`length_seasons`); v1.0'ın
`CONTRACT_LENGTH_DAYS = 730` sabiti emekli olur — 730 gün rastgele bir Salı'ya
düşer ve iki bitiş tarihinin hiçbirini tutturamaz.

Sözleşme kapandığında kullanıcı **serbest oyuncu** olur: `player.team_id` mevcut
kulüpte kalır ama aktif `player_contract` satırı yoktur → maaş ödenmez (§6.5'in
`wage` satırı düşmez). Mevcut kulüp de teklif verenler arasındadır.

#### Teklif üretimi
Girdiler: **saha** niteliklerinin ortalaması, `player_fame`, geçen sezonun
`player_season_stat`'ı. **Kişi ailesi bu sürümde okunmaz** — §3.2'nin "sözleşme
pazarlığı" vaadi ayrı bir sürümün işidir. Ücret ölçeği `STARTING_WEEKLY_WAGE`
üzerinden kademe çarpanıyla kurulur; gerçek formül **⟦AÇIK-8⟧**'e (piyasa değeri)
bağlıdır ve o kapanana kadar placeholder çalışır. Değer değişimi sürüm numarasını
değiştirmez.

#### S3 · `GET /careers/{cid}/transfer/offers`

```jsonc
{ "window":    "summer",         // 'winter' | 'summer' | null (pencere kapalı)
  "closes_on": "2027-08-28",     // pencerenin son günü; kapalıysa null
  "offers": [
    { "offer_id":         "o_3f9a01bc22de",
      "team":             { /* TeamRef */ },
      "competition":      { /* CompetitionRef */ },
      "weekly_wage":        5200,
      "appearance_bonus":    700,
      "goal_bonus":         1400,
      "release_clause":   400000,
      "length_seasons":        2,
      "expires_at":       "2029-06-02",   // kabul edilirse sözleşme bu gün biter
      "status":           "open" }
  ] }
```

Pencere kapalıyken `offers` **boş dizidir** — hata değil.

#### S4 · `POST /careers/{cid}/transfer/offers/{oid}/accept`

Gövde yok. Tek transaction'da: `player.team_id` güncellenir, yeni
`player_contract` satırı yazılır, teklif `accepted`, **diğer bütün açık teklifler
`expired`** olur.

```jsonc
{ "career_state": { /* CareerState */ },
  "team":         { /* TeamRef — yeni kulüp */ },
  "competition":  { /* CompetitionRef — yeni kulübün ligi */ },
  "contract": { "signed_at": "2027-07-04", "expires_at": "2029-06-02",
                "weekly_wage": 5200, "appearance_bonus": 700,
                "goal_bonus": 1400, "release_clause": 400000 } }
```

Bilinmeyen `offer_id` → `404 offer_not_found`. Zaten `accepted`/`expired` teklif
→ `409 offer_not_open`.

---

### 11.8 Mevcut uçlardaki değişiklikler (FE'yi ilgilendiren kısım)

| Uç | Değişiklik | Kırıcı mı |
|---|---|---|
| §5.0 `CareerState` | **`season_phase`** alanı eklenir (türetilmiş, D45) | Hayır — §5.0'ın "alan eklemek kırıcı değildir" kuralı |
| §5.0 kimlikler | `o_` teklif ön eki | Hayır |
| §4 tablosu | S1–S4 eklenir | Hayır |
| T1 `events[].kind` | `season_phase_change` · `contract_expired` · `transfer_offer` | Hayır — FE tanımadığı `kind`'ı yok sayar |
| T3 `stop_reason` | aynı küme genişler | Hayır |
| T3 davranış | `season_end` fazında `409 season_rollover_required` (eski: `season_finished`) | **Evet** — FE'nin yakaladığı kod değişir |
| W2 sıralama | ölçüt sırası §11.4'e genişler | Hayır — alanlar aynı |

`season_phase_change`'in `ref_id`'si **yeni fazın adıdır** (`"winter_break"`,
`"season_end"`, …); `transfer_offer`'ınki `offer_id`, `contract_expired`'ınki
`null`.

`CareerState`'in yeni hâli — `season_phase` `level` ile aynı cinsten, **türetilmiş
ve saklanmayan** bir alandır (D43/D45):

```jsonc
{ "current_date":  "2027-06-05",
  "season_id":     "26/27",
  "season_phase":  "season_end",        // §11.2 · YENİ · türetilmiş
  "money":         48200,
  "condition":     72,
  "day_budget":    { "time": 330, "energy": 62 } }
```

---

### 11.9 Yeni hata kodları

| HTTP | `code` | Ne zaman |
|---|---|---|
| 409 | `season_rollover_required` | Faz `season_end`; devir yapılmadan `advance` çağrıldı |
| 409 | `season_not_finished` | S1/S2 çağrıldı ama sezonun oynanmamış maçı var (INV-13) |
| 409 | `no_transfer_window` | S4 çağrıldı ama faz bir transfer penceresi değil |
| 409 | `offer_not_open` | Teklif zaten kabul edilmiş ya da süresi geçmiş |
| 404 | `offer_not_found` | Bilinmeyen `offer_id` |

> **Bu iki kod sosyal tekliflerinkiyle karıştırılmamalıdır.** §5.4'ün
> `social_offer_not_found` / `social_offer_not_open` kodları ayrı tutuldu ki
> transfer teklifleri geldiğinde buradaki `offer_*` ailesi serbest kalsın —
> tek bir kod ailesini iki farklı ömre sahip iki mekaniğin paylaşması, ikisi
> birden var olduğu gün sözleşmenin birini yalancı çıkarırdı.

**Emekli:** `409 season_finished`.

---

### 11.10 Yeni kararlar

Onuncu turda (sezon devri) alınanlar:

| # | Karar | Seçilen | Gerekçe |
|---|---|---|---|
| D44 | Sezon takvimi | **Global ve sabit; sınırlar tarihten türetilir** | Şartname v1'i tek takvime bağlıyor. Türetme "Ağustos'un son Cumartesi'si" kuralını her sezon için elle yazmaktan kurtarır ve devir ile onboarding'in aynı fonksiyonu çağırmasını sağlar |
| D45 | Sezon fazı | **Türetilir, saklanmaz** | D43'ün `level` örüntüsünün aynısı: türetilmiş değerin sahibi BE'dir, yanıta konur ama kolona yazılmaz. Kolon, takvimle ayrışmasın diye bir senkron invariant'ı borçlanmak olurdu; türetmenin bedeli bir `SELECT` |
| D46 | Devrin tetiği | **Ayrı uç (S1)**, `advance` içinde değil | FE'ye sezon sonu ekranı imkânı verir: kullanıcı nihai tabloyu görür, devri kendisi başlatır. `advance`'ın içine gizlenen bir devir, kullanıcının göremediği bir sezon sonu demekti |
| D47 | Devrin kapsamı | **Tek çağrı; `game_date` ilerlemez** | Yaz günleri normal oynanır — antrenman, para ve ilişki döngüsü üç ay boşluk vermez. İki uca bölmek FE'ye ikinci bir ekran borcu yazardı |
| D48 | Transfer öznesi | **Yalnızca kullanıcı** | D4 (kadro yok) korunur. NPC transferi 32 takımlık kadro modeli ister; o, sezon mantığından büyük ayrı bir iştir |
| D49 | Kıta turnuvası | **v1'de yalnızca kontenjan** | Tek ülke (`TR`) var; 32 Türk takımıyla "Avrupa" turnuvası kurmak dünyayı bozardı. Kontenjan bilgisi bugünden doğru saklanır, turnuva sonra gelir |
| D50 | Sözleşme süresi | **Sezon cinsinden; bitiş daima sezon sınırı** | Şartname iki bitiş tarihi tanımlıyor (1 Ocak / sezon sonu); gün cinsinden süre bunu tutturamaz |
| D51 | Eşyanın günlük etkisi | **Ayrı `daily_effects` haritası, `effects` değil** | `effects` T2'nin haritası: bir kez, bir aksiyonla uygulanır. Eşyanın etkisi pasiftir — kimse koşu bandını "kullanmaz", sahip olmak mekaniğin tamamıdır. İkisini tek alana sıkıştırmak "bu satır ne zaman uygulanır" sorusunu okunamaz hâle getirirdi |
| D56 | FE'nin ilerleme biçimi | **Tekrarlanan `next_day` döngüsü, tek `next_event` değil** | Tek çağrıda sunucu kırk gün ileri gitmişken ekran üçüncü günü oynatıyor olur; "Durdur" o noktada yalan söyler. Gün gün gidince ekranın tarihi ile `game_date` her karede aynı sayıdır ve durma ölçütü yine sunucuda kalır — döngünün çıkış testi yalnızca `stop_reason != "none"` |
| D57 | Maç günü zorunluluğu | **"Kaçırılan maç" kalkar; kapıda kilit gelir** | Geri bildirim net: maç atlanamamalı. Eski tasarımın kaygısı (motor erişilemezken kilitlenme) kabul edilebilir bir risk — maç oynamak zaten motora muhtaç, bu kural yeni bir bağımlılık eklemiyor |
| D55 | Takvim görünümünün verisi | **Kendi ucu (W5), FE'de birleştirme değil** | Fikstür + sözleşme + sezondan istemcide kurmak, `WAGE_WEEKDAY`'i Dart'ta yeniden yazdırırdı (§1.3) ve sezon sınırlarını **hiçbir uç** döndürmüyor. Üstelik sayfa başına 3-4 çağrı ve 20'şerlik fikstür sayfalaması gerekirdi |
| D53 | Sosyal teklife cevap | **Zorunlu — açık teklif `advance`'ı kapıda reddeder** | "Sonra bakarım" seçeneği teklifi bir bildirime çevirirdi; ilişkinin karşı taraftan bir şey isteyebilmesi mekaniğin tamamı. Kapıda reddetmek, döngü içinde her gün durmaktan da açıktır: sıfır gün ilerleyip "none" diyen bir çağrı, hata gibi görünmeyen bir hatadır |
| D54 | Teklifin ömrü | **Süre yok; geldiği gün cevaplanır** | D53 açık teklifle zamanı durdurduğu için "süresi doldu" ancak cevap vermeyi reddederek ulaşılabilirdi — cevap vermemek imkânsızken. Ulaşılamayan durum, test edilemeyen durumdur |
| D52 | Günlük toparlanma tavanı | **Taban + eşya toplamı, sabit tavanla kesilir (INV-41)** | Tavansız, dükkânın yeterince büyük bir kısmını alan oyuncu bir maçı iki sakin günde geri öder ve kondisyon yönetilen bir kaynak olmaktan çıkar — §6.6'nın tüm varlık sebebi bu |

---

### 11.11 Yeni invariant'lar

| # | Garanti |
|---|---|
| INV-33 | Hiçbir `kind='league'` fikstürü bir tatil aralığına (devre arası veya sezonlar arası) düşmez |
| INV-34 | Bir ligin `competition_entry` mevcudu sezondan sezona **değişmez** — terfi sayısı düşme sayısına eşittir |
| INV-35 | `player_contract.expires_at` daima ya bir sezonun `ends_on`'u ya da bir `winter_break_from` tarihidir (D50) |
| INV-36 | Devir tek transaction'dır; kısmen uygulanmış bir devir (girişler yazılmış ama fikstür üretilmemiş gibi) oluşamaz |
| INV-37 | Devir sonrası her takım yeni sezonda **tam olarak bir** lige girer — INV-14'ün ("birden fazlasına giremez") tamamlayıcısı |
| INV-39 | Bir kariyerde aynı anda `status='open'` olan **en fazla bir** `social_offer` satırı bulunur (D53) |
| INV-40 | Bir sosyal teklifi **reddetmek** hiçbir gereksinim kontrol etmez, hiçbir bütçe/para harcamaz ve başarısız olamaz — zorunlu cevabın çıkış kapısı budur |
| INV-41 | Bir günün doğal kondisyon toparlanması (taban + sahip olunan eşyaların `daily_effects.condition` toplamı) `MAX_CONDITION_RECOVERY_PER_DAY`'i aşmaz; aşsa da INV-10'un tavanı ayrıca geçerlidir (D52) |

**Garanti EDİLMEYEN:** sezonların fikstür sırasının birbirinden bağımsızlığı —
devir kariyerin kendi `seed`'ini kullanmayı sürdürür, dolayısıyla INV-7 (aynı
seed + aynı karar dizisi → aynı dünya) sezonlar boyunca geçerlidir.

---

### 11.12 Yeni açık madde

| # | Nerede | Ne kararlaştırılacak |
|---|---|---|
| ⟦AÇIK-12⟧ | §11.4 `competition.international_score` | Uluslararası puanın gerçek ölçeği ve kontenjan eşiği. v1: Süper Lig 45 → 2, 1. Lig 5 → 0 (placeholder) |

⟦AÇIK-8⟧ (piyasa değeri) §11.7'de **ikinci bir müşteri** kazandı: teklif ücret
ölçeği o formüle bağlanacak. §10'un kuralı geçerli — bu noktalar dolduğunda sürüm
numarası **artmaz**.

---

### 11.13 Bu sürümün dışında kalanlar

- **Kadro modeli ve NPC transferleri** — D4/D48 korunuyor
- **Oynanabilir kıta turnuvası** — D49; yalnızca kontenjan hesaplanıyor
- **Teklifin kişi ailesine bağlanması** — §3.2'nin "sözleşme pazarlığı" vaadi;
  bu sürümde teklif yalnızca saha tarafına bakar
- **Play-off, lig bazında farklı kural/puanlama/sezon uzunluğu** — şartnamenin
  kendi "ilerleyen versiyonlarda" listesi
- **Flutter FE kodu** — bu bölüm FE'yi yalnızca **sözleşme** düzeyinde bağlar
  (§11.8); ekran ve istemci değişiklikleri ayrı bir sürümün işidir


---

## 12. EK: ANTRENÖR, KADRO VE SPONSORLUK

> Bu bölüm de §11 gibi **imza sonrası** eklendi. §11 kendi alanında (sezon
> devri, transfer, sözleşme) son sözü söylemeye devam eder; §12 yalnızca
> aşağıda açıkça saydığı maddeleri geçersiz kılar.

### 12.0 Geçersiz kılananlar

| Nerede | Önceden | §12'de |
|---|---|---|
| §3.2 | "`starts` = `appearances`; v1'de kullanıcı daima ilk 11'de" | Kullanıcı **ilk 11 / yedek / kadro dışı** olabilir (§12.2) |
| §3.4 | `relationship.traits` yalnızca tohumlamada yazılır | `relationships.apply_trait_delta()` tek yazma yolu olarak eklendi (§12.1) |
| §11.13 | "Kadro modeli ve NPC transferleri" kapsam dışı | **Yalnızca NPC transferi** kapsam dışı kalır |

**D4 kaldırılmadı.** Bir kariyerde hâlâ tam olarak bir `player` satırı vardır
(`is_user = 1`); 32 takımın kadrosu, NPC oyuncuları ve derinliği yoktur ve
§12 bunların hiçbirini getirmez. Değişen tek şey **kullanıcının o maçtaki
durumu**nın artık sabit varsayılmaması — bu, kadro modeli değil, `fixture`
satırında tek bir kolon.

### 12.1 M4 · Maç öncesi antrenör konuşması

#### M4 · `POST /careers/{cid}/matches/{fid}/coach-talk`

```jsonc
// İstek
{ "topic": "philosophy_accept",   // altı değerden biri, aşağıdaki tablo
  "value": null }                 // yalnızca talep konularında dolu

// Yanıt
{ "career_state": { /* CareerState — day_budget ve condition oynamış olabilir */ },
  "topic":   "philosophy_accept",
  "granted": null,                // talep değilse null; talepse true/false
  "relationship_changes": [ { "relationship_id": "coach",
                              "before": 70, "after": 72, "delta": 2 } ],
  "trait_changes":        [ { "key": "trust",
                              "before": 50.0, "after": 56.0, "delta": 6.0 } ],
  "condition_after": null,        // konu kondisyon oynatmıyorsa null
  "player": null }                // talep kabul edildiyse {position, role}
```

| `topic` | Ne yapar | `value` |
|---|---|---|
| `philosophy_accept` / `philosophy_reject` | Antrenörün oyun anlayışını kabul/ret | yok |
| `style_accept` / `style_reject` | Oyun tarzını kabul/ret | yok |
| `request_position` | Pozisyon değişikliği talebi | pozisyon adı |
| `request_role` | Rol değişikliği talebi | `role_id` |

**İki sayı var ve aynı şey değiller.** `relationship.score` (§3.4) antrenörün
seni **sevmesi**; `CoachTraits.trust` senin okumanı kendi planının önüne
koymaya ne kadar hazır olduğu. Birlikte hareket ederler ama aynı değildirler
ve mekaniğin tamamı bu farkta: planı kabul etmek güveni **ucuza** alır, güven
ise bir şey isterken **harcadığın** şeydir. Bir antrenör seni sevip yine de
istediğin yerde oynatmayabilir.

`trust` bu bölüme kadar **ölü veriydi**: §3.4 tanımlıyordu, R1/R2 döndürüyordu,
hiçbir kod yolu yazmıyordu. Artık `domain/squad.py`'nin (§12.2) ilk 11 kararını
verirken okuduğu girdi — döngü şöyle kapanıyor:

```text
konuş -> güven -> kadro -> maç -> ilişki -> konuş
```

**Kapılar** (sırasıyla, hiçbiri yazmıyor):

| Sıra | Kontrol | Hata |
|---|---|---|
| 1 | Kariyer tanınıyor mu | `404 career_not_found` |
| 2 | Fikstür var mı | `404 fixture_not_found` |
| 3 | Fikstür **bugünün** mi | `409 not_match_day` |
| 4 | Bu maç öncesi konuşuldu mu | `409 coach_talk_already_done` |
| 5 | Günün bütçesi yetiyor mu (§6.2) | `409 insufficient_budget` |

**Maç başına bir konuşma.** Kilit ayrı bir tabloda değil: `apply_delta` her
konuşmada `reason = "coach_talk:{fixture_id}:{topic}"` ile bir
`relationship_event` satırı yazıyor, denetim izi kilidin kendisi oluyor ve
ikisinin çelişebileceği ikinci bir yer olmuyor.

**Talep sonucu zırlanmış (seeded) bir atıştan çıkar** — `(seed, fixture_id,
topic)`. Aynı talep aynı maçta daima aynı sonucu verir (INV-7) ve bu, 4. kapı
zaten ikinci denemeyi engellediği için ayrıca korunması gerekmeyen bir özellik.
Başarı olasılığı `trust`'a ilişkinin kabaca iki katı ağırlık verir; iki uç da
kesinlik değildir (0.05 taban, 0.90 tavan).

**Pozisyon değişirse rol onunla taşınır.** Roller tam olarak bir pozisyona
aittir (`worlddata/positions.py`), dolayısıyla kabul edilen bir pozisyon
talebi rolü öksüz bırakır; rol yeni pozisyonun ilk rolüne taşınır ve yanıt
bunu `player` bloğunda söyler. İmkânsız bir çifti sessizce tutmak
`role_belongs_to_position`'ı her sonraki okuyucu için bozardı.

### 12.2 Kadro durumu

Kullanıcı artık her maç sahaya çıkmıyor. Üç durum var:

| `user_squad_status` | Anlamı |
|---|---|
| `first_eleven` | İlk on birde başlar |
| `bench` | Kadroda ama yedek; antrenör kulübeye dönerse oyuna girer |
| `out` | Kadro dışı; maç arka plan simülasyonuna düşer |

**Şema** — `010_squad_status.sql`:

```sql
ALTER TABLE fixture ADD COLUMN user_squad_status TEXT;   -- 'first_eleven'|'bench'|'out'
```

Ayrı bir tablo değil tek kolon: durum bir fikstüre birebir bağlı ve kullanıcı
başına tek (D4 korunuyor). NULL = henüz karar verilmedi ya da kullanıcının
takımı o maçta yok.

**Karar tembel ve yapışkan.** İlk soran hesaplar, sonuç yazılır, sonrakiler
onu okur. İki çağrı aynı maç hakkında anlaşmak zorunda (T1'in olay listesi ve
T3'ün maç günü kapısı — `user_match_today`'in var olma sebebi bu); her
çağrıda yeniden atılan bir zar, kapıyla ekran arasında cevabı değiştirebilirdi.

Girdiler ve ağırlıklar (`domain/squad.py`): kondisyon **0.45**, antrenörün
`trust`'ı **0.35** (§12.1), antrenör ilişkisi **0.20**, üstüne ±10'luk
zırlanmış bir salınım (INV-7 korunur). Eşikler: ≥55 ilk 11, ≥30 yedek, altı
kadro dışı. Taze bir kariyer 76.5 ile başlar — kariyerin açılışı eskisi gibi
görünmeli; yerini kaybetmek başına gelen bir şey olmalı, ilk gün atılan bir
yazı tura değil.

**M1 değişikliği.** Yanıta `squad_status` eklendi (`first_eleven` | `bench`).
`out` olduğunda fikstür **hiç teklif edilmez**: M1 `409 not_match_day` döner ve
maç `_simulate_day_fixtures`'a düşer. Bu zorunlu — aksi halde fikstür sonsuza
kadar `scheduled` kalır, D57'nin maç günü kilidi kariyeri dondurur ve sezon
hiç bitmez.

**M2 değişikliği.** Gövde iki opsiyonel alan alır:

| Alan | Kural |
|---|---|
| `started` | Boolean, varsayılan `true` |
| `minutes_played` | 0-95 tam sayı; yoksa `started ? 95 : 0` |

Geçersiz bileşim: `started: true` + `minutes_played: 0` → `422`. Alanların
ikisi de opsiyonel olduğu için §12.2 öncesi yazılmış bir gövde hâlâ geçerli
ve eski anlamını (tam maç başlangıç) taşıyor.

`player_season_stat`'ta **`starts` artık `appearances`'e eşit değil** (§3.2'nin
aksine): oyuna hiç girmeyen bir yedek görünüm alır (kadrodaydı) ama başlangıç
ve dakika almaz. `player_stat_delta` yanıtına `starts` eklendi.

**Maç başı primi yalnızca `minutes_played > 0` iken ödenir.** Prim sahaya
çıkmak içindir; doksan dakika kulübede oturmak maddenin ödediği şey değil.

**Oyuna girme ve çıkma FE'de karara bağlanır.** Motorun `substitution` olayı
**isimsiz** (`API_CONTRACT.md` §4.5): kimin girip çıktığını değil yalnızca hangi
tarafın değişiklik yaptığını taşıyor, çünkü motorda kadro yok. O yüzden
"bu değişiklik kullanıcıyı ilgilendiriyor mu" sorusunu `MatchController`
yanıtlıyor:

* yedekteyken kendi tarafının **ilk** değişikliği oyuncuyu sahaya alır;
* sahadayken bir değişiklik ancak kondisyon 45'in altındaysa oyuncuyu alır —
  aksi halde her değişiklik oyuncuyu çıkarırdı.

Sahada olmayan bir oyuncuya **müdahale teklifi gösterilmez**; motor kadroyu
bilmediği için teklif üretmeyi sürdürür, süzgeç FE'dedir.

### 12.3 Sponsorluk

*(Commit 10 ile yazılacak.)*

### 12.4 Yeni invariant'lar

> ⚠️ **INV-38 şartnamede hiç yok.** §11.11'in listesi INV-37'den INV-39'a
> atlıyor. Boşluk kasıtlı mıydı bilinmiyor; doldurulmuyor, numaralar olduğu
> gibi bırakılıyor.

| # | Garanti |
|---|---|
| INV-42 | `relationship.traits` yalnızca `relationships.apply_trait_delta()` ile yazılır; tohumlama (`onboarding._seed_relationships`) tek istisnadır ve o da `validate_traits()`'ten geçer |
| INV-43 | Bir fikstür öncesi en fazla **bir** antrenör konuşması kaydedilir |
| INV-44 | Bir fikstürün `user_squad_status`'ı bir kez yazılır ve değişmez; T1 ile M1 aynı maç için daima aynı cevabı verir |
| INV-45 | `user_squad_status = 'out'` olan bir fikstür arka plan simülasyonuna düşer; hiçbir fikstür `scheduled` olarak asılı kalmaz |

### 12.5 Yeni hata kodları

| HTTP | `code` | Ne zaman |
|---|---|---|
| 409 | `coach_talk_already_done` | M4 ikinci kez çağrıldı (INV-43) |
