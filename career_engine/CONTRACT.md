# CAREER ENGINE — API CONTRACT (v1.1)

**Taraflar:** Kariyer Back-end (`career_engine`, FastAPI) ↔ Front-end (`ProjectSRPG`, Flutter)
**Komşu servis:** Maç Motoru (`match_engine`, FastAPI) — bkz. [`API_CONTRACT.md`](../../API_CONTRACT.md) v1.1

---

## İMZA BLOĞU

| | |
|---|---|
| **Sürüm** | **v1.1** — §13 eklendi. Karar kaydı §0 + §11.10 + §12 + §13.7, açık maddeler §10 |
| **Tarih** | 2026-09-17 |
| **Back-end** | ✅ imzalandı — §13 uygulandı: 017/018 migration'ları, T5/T6, 580 test geçiyor |
| **Front-end** | ✅ imzalandı — §13 uygulandı: iki antrenman sekmesi, aktivite olayı ekranı, pasif fayda rozeti |

> **v1.0 gövdesi (§1-§12) imzalıydı ve imzalı kalır.** Sürüm v1.1'e çıkıyor
> çünkü §13 §10'un üç eşiğini birden aşıyor: alan **ekliyor** (`state`,
> `passive_bonus`, `effective_value`, `event`, `relationships_reset`), alan
> **kaldırıyor** (beş `kişi` antrenman kalemi) ve bir alanın **anlamını
> değiştiriyor** (`level` artık `effective_value`'dan türüyor, D74). §13
> §1-§12 yürürlükte kalır; §13.0 neyi geçersiz kıldığını tek tek sayar.

**Dayandığı bağlayıcı kararlar:** **78 karar** (D1-D78) — §0'da D1-D43,
§11.10'da D44-D57, §12'de D58-D67, §13.7'de **D68-D78**.
**Garantiler:** **63 invariant** (INV-1 … INV-64, INV-38 kullanılmıyor) —
§8'de INV-1…INV-32, §11.11/§12.6'da INV-33…INV-55, §13.8'de **INV-56…INV-64**.

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
| T5 | `GET` | `/careers/{cid}/activity-events` | Açık aktivite olayı (§13.4) |
| T6 | `POST` | `/careers/{cid}/activity-events/{eid}/choose/{option_id}` | Olayın seçeneğini uygular |
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

**Durumu değiştiren her uç** (T2, T3, T4, T6, R3, M2, M3) yanıtında tam
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
      "player_age":   16,
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

  "player": { "name": "Efe Kaan", "position": "Orta saha", "age": 16,
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
  "birth_date":  "2010-08-19",
  "age":         16,                    // türetilmiş
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
görünür. BE bu string'i doğrulamaz — tek kaynağı FE enum'ı olduğu için buraya
ikinci bir nüsha konmadı; yazım hatası kartı sessizce "Yakında" yapar.

v1.6 itibarıyla yedi `saha` kartının yedisinin de mini-oyunu var; `mudahale`
kartı `tackling` drill'ini açıyor (baskı zinciri — `lib/game/tackle_game.dart`).
Aynı oyun maç içinde de oynanıyor: `tackle_hard` ve `high_press` teklifleri
`resolution:"minigame"`, `minigame:"tackle"` geliyor (`../API_CONTRACT.md` §7.3).
`null` kalan tek aile artık `kişi`.

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
| ~~B-3~~ | ~~**Kişi antrenmanlarının sekmesi**~~ | **KAPANDI** — ikinci sekme `_tactical`'dan `personal`/"Kişisel"e yeniden adlandırıldı; üçüncü bir sekme (`tactical`/"Taktik") §12.11'in kartlarıyla gerçek anlamıyla açıldı | §12.11 · FE |
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
| ⟦AÇIK-13⟧ | §12.11 | Taktik yeterliliğinin maça nasıl yansıyacağı — D37'nin ayırdığı "gelecekteki mini-oyun-zorluk kancası" |
| ⟦AÇIK-15⟧ | §12.13 | Altın/fon'un gerçek oynaklığı (fiyat dalgalanması, satış eylemi) — bugün üçü de sabit haftalık oran |
| ⟦AÇIK-16⟧ | §13.3 `passive_effects` | Hangi eşyanın hangi kişi niteliğine kaç puan verdiği (§13.3'ün tablosu öneridir) |
| ⟦AÇIK-17⟧ | §13.5 · `catalog/dialogue.py` `requires` | Kişi antrenmanı kalkınca diyalog eşiklerinin yeniden dengelenmesi |
| ⟦AÇIK-18⟧ | §13.2 `courting` | Tanışma ile ilişkinin kurulması arasındaki adım sayısı, yeniden tanışma sıklığı |
| ⟦B-1⟧ | §5.2 P3 sözleşme kalemleri | v1 başlangıç sözleşmesinin tier 2 ölçeği |

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
| §6.3 D54 | "Süre yok; geldiği gün cevaplanır" | Yalnızca `plan_days_ahead` alanı olmayan şablonlar için geçerli kalır; bu alanı taşıyan bir şablonun kabulü anında çözülmez, ileri tarihli bir `social_plan` randevusu yazar (§12.8) |
| §6.3 INV-39 | "Aynı anda en fazla bir açık teklif" | En fazla bir açık teklif **ya da bir çakışma çifti**; çift tek bir kararla açılıp tek bir kararla kapanır (§12.9) |

**D4 kaldırılmadı.** Bir kariyerde hâlâ tam olarak bir `player` satırı vardır
(`is_user = 1`); 32 takımın kadrosu, NPC oyuncuları ve derinliği yoktur ve
§12 bunların hiçbirini getirmez. Değişen tek şey **kullanıcının o maçtaki
durumu**nın artık sabit varsayılmaması — bu, kadro modeli değil, `fixture`
satırında tek bir kolon.

### 12.1 M4 · Maç öncesi antrenör konuşması

#### M4 · `POST /careers/{cid}/matches/{fid}/coach-talk`

```jsonc
// İstek
{ "topic": "philosophy_accept",   // yedi değerden biri, aşağıdaki tablo
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
  "player": null,                 // talep kabul edildiyse {position, role}
  "coach_instruction": null }     // §12.10 — yalnızca talimat gerçekten
                                   // değiştiyse {focus, label} dolu gelir
```

| `topic` | Ne yapar | `value` |
|---|---|---|
| `philosophy_accept` / `philosophy_reject` | Antrenörün oyun anlayışını kabul/ret | yok |
| `style_accept` / `style_reject` | Oyun tarzını kabul/ret | yok |
| `request_position` | Pozisyon değişikliği talebi | pozisyon adı |
| `request_role` | Rol değişikliği talebi | `role_id` |
| `request_instruction` | Bugünkü maç talimatını değiştirme talebi (§12.10) | `'attack'\|'defend'\|'tactical'\|'any'` |

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

**Rol/pozisyon değişince talimat da yeniden türer (§12.10).** Kabul edilen
bir `request_role`/`request_position`, o fikstürün donmuş talimatını yeni
rolden yeniden hesaplayıp üzerine yazar — aksi halde antrenör seni Mezzala
oynatmayı kabul edip hâlâ geride durmanı isterdi. Bu durumda da yanıtın
`coach_instruction` alanı dolu gelir.

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

> Şartnamenin hiçbir yerinde geçmiyor. 3065 satırlık belgede "sponsor"
> kelimesi **bir kez** geçiyor (§10, ⟦AÇIK-9⟧'un şöhret tartışmasında,
> şöhretin *olası bir tüketicisi* olarak) ve orada bir spec değil, açık bir
> soru. Bu bölüm sıfırdan yazıldı.

Bir anlaşma iki şeyi birden taşır ve mekanik tam olarak ikisinin
gerilimidir: **kazanılmadan gelen haftalık para**, ve bazılarında
**oyuncuya ait olmaktan çıkan günler**. Yükümlülüğü olmayan anlaşma daha
az öder; dosyadaki en büyük çek üç haftada bir öğleden sonrasına mal olur.

**Faz kapısı yok.** Transferden farklı olarak sezonun her döneminde
imzalanabilir: marka transfer penceresi beklemez.

#### Şema — `011_sponsorship.sql`

İki tablo: `sponsorship_deal` (teklif/anlaşma) ve `sponsorship_obligation`
(takvime yazılmış zorunlu etkinlikler). Satırda yalnızca `template_id`
durur — getiriler ve yükümlülük ritmi `content/sponsorships.py`'de
yazarlanmış veridir (009'un gerekçesiyle aynı).

**İstisna `weekly_income`:** imza anındaki rakamla donuyor. Şablonu sonradan
düzenlemek uçuştaki bir anlaşmanın gelirini değiştirmemeli — `inventory`'nin
`price_paid`'i dondurmasıyla aynı gerekçe.

#### Uçlar

| Metot | Yol |
|---|---|
| `GET` | `/careers/{cid}/sponsorships` — teklifler + aktif anlaşmalar + bekleyen yükümlülükler |
| `POST` | `/careers/{cid}/sponsorships/{did}/accept` |
| `POST` | `/careers/{cid}/sponsorships/{did}/decline` |
| `POST` | `/careers/{cid}/sponsorships/obligations/{oid}/attend` |
| `POST` | `/careers/{cid}/sponsorships/obligations/{oid}/skip` |

**Yükümlülükler imza anında topluca takvime yazılır**, teker teker değil:
oyuncu neye imza attığını görebilsin, ve hiç koşmamış bir gün döngüsü
sessizce bir etkinlik üretmeyi atlayamasın.

**Bekleyen bir yükümlülük `advance`'ı kapıda reddeder**
(`409 sponsorship_obligation_pending`) — D53'ün sosyal tekliflere koyduğu
kilidin aynısı: orada olacağına söz verdiysen o gün atlanacak bir gün
değil. Çıkış kapısı `skip`: anlaşma **bozulur**, gelir kesilir, o
anlaşmanın bütün diğer randevuları düşer ve `media` ilişkisi düşer —
yokluk bir haberdir. Oyuncu asla kilitlenmez, yalnızca bedel öder.

**Gelir maaşla aynı Pazartesi, `wallet.apply(kind='sponsorship')` ile**
(INV-17 korunur) ve düzenli giderden **önce**: gelir gelmesi giderin
karşılanabilir olmasına bağlı değil, üstelik onu karşılanabilir kılan
şeyin ta kendisi olabilir.

**`requires` kapısı (D42) kişi niteliklerine bakıyor** — marka kameranın
karşısında duramayan birine adını vermez. §11.13 kişi ailesini transfer
pazarlığının dışında tuttuğu için, para sisteminde gerçek iş yaptığı tek
yer burası.

Anlaşma da bir sözleşme gibi **sezon sınırında** biter (D50'nin okuması):
rastgele bir salı günü biten bir reklam anlaşması takvimi boşuna
okunmaz kılardı.

#### Yeni olay türleri ve hata kodları

`events[].kind`: `sponsorship_offer` (`ref_id` = `deal_id`),
`sponsorship_obligation` (`ref_id` = `obligation_id`, ayrıca `due_on`).
İkisi de `advance`'ı durduran türlerden.

| HTTP | `code` | Ne zaman |
|---|---|---|
| 404 | `sponsorship_not_found` | Bilinmeyen `deal_id`/`obligation_id` |
| 409 | `sponsorship_not_open` | Teklif/yükümlülük zaten cevaplanmış |
| 409 | `sponsorship_obligation_pending` | Bekleyen randevu varken `advance` çağrıldı |

`LEDGER_KINDS`'a `sponsorship` eklendi.

### 12.4 Sözleşme yenileme — karşı teklif

§11.7 yalnızca **kabul**'ü tanımlıyor (S4). Tek seçeneği kabul olan bir
teklif listesi bir görüşme değil, bir duyurudur; mevcut kulübün teklifi
bu yüzden **bir kez** geri itilebiliyor.

#### `POST /careers/{cid}/transfer/offers/{oid}/counter`

```jsonc
// İstek — gövde yok

// Yanıt
{ "career_state": { /* CareerState */ },
  "accepted": true,                    // kulüp yükseltti mi
  "offer":    { /* TransferOffer — counter_used artık true */ } }
```

Başarılıysa haftalık ücret **%25** artar ve primlerle serbest kalma bedeli
onunla birlikte yeniden hesaplanır — eski ölçekte kalmış bir prim, yükseltilmiş
bir maaşın yanında tutarsız durur. Başarısızsa şartlar aynen kalır.

Kulübün cevabı antrenör ilişkisinden, `trust`'tan (§12.1) ve geçen sezonun
gollerinden çıkar — seni oynatan neyse, sana zam veren de o. Atış `offer_id`
üzerine zırlanmış, yani cevap yeniden atılamaz; zaten `counter_used` her iki
durumda da kapanıyor.

**Yalnızca yenileme tekliflerinde.** Rakip kulüp pazarlık etmiyor: `is_renewal`
false olan bir teklifte `counter_used` başlangıçta 0 kalır ama uç onu
`409 offer_not_open` ile reddeder.

#### `POST /careers/{cid}/transfer/offers/{oid}/decline`

Reddetmek hiçbir gereksinim kontrol etmez, hiçbir bütçe harcamaz ve
başarısız olamaz — INV-40'ın sosyal tekliflere verdiği okumanın aynısı.

#### Şema eki

`007_season_rollover.sql`'in `transfer_offer` tablosu §11.3'ün DDL'ine iki
kolon ekliyor:

```sql
  is_renewal       INTEGER NOT NULL DEFAULT 0,
  counter_used     INTEGER NOT NULL DEFAULT 0,
```

`is_renewal` olmadan "mevcut kulübün teklifi hangisi" sorusu `team_id`'yi
oyuncunun kulübüyle karşılaştırmakla cevaplanırdı — ki teklif kabul edilip
kulüp değiştikten sonra o karşılaştırma yalan söyler.

### 12.5 §11.7'nin uygulamasında kapatılan üç hata

Üçü de yalnızca bir sözleşme gerçekten bitebildiğinde ortaya çıkıyor,
yani §11 öncesi erişilemez durumlardı:

1. **Süresi geçmiş sözleşme maaş ödemeye devam ediyordu.** Sorgu
   `signed_at`'e göre sıralıyor, `expires_at`'e hiç bakmıyordu; §11.7'nin
   "serbest oyuncu" durumu = **aktif sözleşme satırı yok**, o sorgunun
   soramadığı soru. `domain/contracts.py` artık iki ayrı soruyu ayrı ayrı
   cevaplıyor: yürürlükteki sözleşme (maaş için) ve en son imzalananı
   (gösterim için).
2. **`player_contract` PK'ı aynı gün iki imzada çakışıyordu.** Anahtar
   `(career_id, player_id, signed_at)`; eskisinin bittiği gün yenisini
   imzalamak istisna değil normal durum. `INSERT OR REPLACE` — oyuncu iki
   sözleşme taşımaz, geçerli olan son imzadır.
3. **P3 `days_until_expiry`'yi duvar saatinden sayıyordu.** İki sezon dönmüş
   bir kariyer makinenin takviminden yıllarca uzakta; artık `game_date`'ten.

P3 yanıtına `status` (`active` | `expired`) eklendi: serbest oyuncuda son
sözleşme yine gösterilir, çünkü `null` dönmek FE'ye "sözleşmen bitti" ile
"kariyer yok"u ayırt ettirmiyor.

### 12.6 Yeni invariant'lar

> ⚠️ **INV-38 şartnamede hiç yok.** §11.11'in listesi INV-37'den INV-39'a
> atlıyor. Boşluk kasıtlı mıydı bilinmiyor; doldurulmuyor, numaralar olduğu
> gibi bırakılıyor.

| # | Garanti |
|---|---|
| INV-42 | `relationship.traits` yalnızca `relationships.apply_trait_delta()` ile yazılır; tohumlama (`onboarding._seed_relationships`) tek istisnadır ve o da `validate_traits()`'ten geçer |
| INV-43 | Bir fikstür öncesi en fazla **bir** antrenör konuşması kaydedilir |
| INV-44 | Bir fikstürün `user_squad_status`'ı bir kez yazılır ve değişmez; T1 ile M1 aynı maç için daima aynı cevabı verir |
| INV-45 | `user_squad_status = 'out'` olan bir fikstür arka plan simülasyonuna düşer; hiçbir fikstür `scheduled` olarak asılı kalmaz |
| INV-46 | Bir teklif en fazla **bir** kez karşı teklife konu olur (`counter_used`) |
| INV-47 | Bir teklif kabul edildiğinde aynı kariyerin diğer bütün `status='open'` teklifleri `expired` olur |
| INV-48 | Bir kariyerde aynı anda en fazla **bir** `status='offered'` sponsorluk bulunur (INV-39'un okuması) |
| INV-49 | Bir yükümlülük kaçırıldığında anlaşma `broken` olur ve o anlaşmanın bekleyen bütün randevuları `missed` yazılır |

### 12.5 Yeni hata kodları

| HTTP | `code` | Ne zaman |
|---|---|---|
| 409 | `coach_talk_already_done` | M4 ikinci kez çağrıldı (INV-43) |

### 12.8 Sosyal plan (ileri tarihli teklif)

> Numaralandırma notu: bu bölümden önce `§12`'de iki farklı yer `12.5`
> başlığını taşıyor (yukarıdaki "üç hata" ve "yeni hata kodları" altbölümleri)
> — şartnamenin kendi önceki hatası, burada düzeltilmiyor. `12.7` de
> `domain/sponsorship.py`'nin kendi yorumlarında (yanlışlıkla, gerçek başlığı
> `12.3`'tür) kendine atıfta bulunduğu bir numara; karışıklığı büyütmemek için
> bu bölüm doğrudan bir sonraki temiz numarayı, `12.8`'i alıyor.

D54 "süre yok, geldiği gün cevaplanır" bütün sosyal teklifler için doğruydu —
ta ki bir teklifin metni gerçekten bir sonraki günü vaat edene kadar
(`coach_extra_session`: "yarın sabah"). Böyle bir şablon artık kabul anında
çözülmüyor; `relationship_delta` yine anında uygulanır (D53'ün ruhu
korunuyor: bir cevap yine anında bir şey değiştiriyor) ama `costs` ve
`effects` o günün yerine planın günü için ayrılan bir `social_plan`
satırına ertelenir. Oyuncu o gün gelince ya gider (`attend`) ya da gitmez
(`skip`) — sponsorluk randevusunun (§12.3) attend/skip'iyle birebir aynı
kapı.

#### Şema — `012_social_plans.sql`

```sql
CREATE TABLE social_plan (
  career_id       TEXT NOT NULL REFERENCES career(career_id) ON DELETE CASCADE,
  plan_id         TEXT NOT NULL,          -- 'spl_' + 12 hex
  offer_id        TEXT NOT NULL,
  template_id     TEXT NOT NULL,
  relationship_id TEXT NOT NULL,
  due_on          TEXT NOT NULL,
  status          TEXT NOT NULL,          -- 'pending' | 'done' | 'missed'
  PRIMARY KEY (career_id, plan_id)
);
```

#### Şablon alanı

`content/social_offers.py`'de bir şablonun `plan_days_ahead: int` alanı
(pozitif tam sayı) varsa, o şablonun kabulü bu bölümdeki davranışı alır.
Alan yoksa hiçbir şey değişmez — mevcut sekiz şablondan yedisi bugün olduğu
gibi anında çözülmeye devam eder; yalnızca `coach_extra_session`
`plan_days_ahead: 1` taşır.

#### Uçlar

| # | Yöntem | Yol | Açıklama |
|---|---|---|---|
| — | `GET` | `/careers/{cid}/social/plans` | Bugün (veya daha önce) vadesi gelmiş bekleyen planlar |
| — | `POST` | `/careers/{cid}/social/plans/{plan_id}/attend` | Git: `costs` düşer, `effects` uygulanır, `status='done'` |
| — | `POST` | `/careers/{cid}/social/plans/{plan_id}/skip` | Gitme: hiçbir maliyet yok, `status='missed'`, ilişkiye §12.8's `MISSED_PLAN_RELATIONSHIP_DELTA` (-12) yazılır |

R5/R6'nın kabul yanıtı artık ek bir `plan` alanı taşır: `plan_days_ahead`
olmayan bir şablonda veya reddedilen bir teklifte `null`, olan bir şablonun
kabulünde oluşturulan `social_plan`'ın genel görünümü. `attend`/`skip`
yanıtları da aynı R5/R6 zarfını (`career_state` + `relationship_changes` +
`attribute_changes` + `ledger_entries` + `plan`) kullanır (INV-18).

#### Gün döngüsü kapısı

`list_events()` bekleyen her planı `{"kind": "social_plan_due", ...}` olarak
ekler ve bu tür `STOP_EVENT_KINDS`'tadır — sponsorluk randevusu gibi
**kenar-tetikli değil**: cevaplanana kadar her gün `POST /advance`'ı
`409 social_plan_pending` ile kapıda durdurur.

#### Yeni karar

| # | Konu | Karar | Gerekçe |
|---|---|---|---|
| D58 | Sosyal teklifin zamanlaması | **`plan_days_ahead` alanı olan şablonlar ileri tarihli randevu yazar; yoksa mevcut anında çözüm** | Bir teklifin metni "yarın sabah" diyorsa mekanik onu "şimdi" gibi davranmamalı; alanın yokluğu geri uyumluluğu bozmadan geri kalan altı şablonu olduğu gibi bırakır |

#### Yeni invariant'lar

| # | Garanti |
|---|---|
| INV-50 | Bir `social_plan` satırı yalnızca `plan_days_ahead` taşıyan bir şablonun kabulünden doğar; bu alanı olmayan hiçbir şablon `social_plan` üretmez (D58) |
| INV-51 | Bekleyen (`pending`) bir `social_plan`, bir sponsorluk yükümlülüğü gibi `POST /advance`'ı kapıda durdurur; kaçırılan (`missed`) bir planın ilişki cezası aynı şablonun `decline` deltasından daha büyüktür |

#### Yeni hata kodları

| HTTP | `code` | Ne zaman |
|---|---|---|
| 404 | `social_plan_not_found` | Bilinmeyen `plan_id` |
| 409 | `social_plan_not_open` | Plan zaten `done`/`missed` iken tekrar `attend`/`skip` çağrıldı |
| 409 | `social_plan_pending` | Cevaplanmamış bir sosyal plan varken `advance` çağrıldı; mesaj `plan_id` taşır |

---

### 12.9 Çakışan sosyal planlar (iki taraflı seçim)

§12.8 bir akşamı ileriye taşıdı ama hâlâ tek bir akşamdı. Aynı güne iki davet
düşebilir ve oyuncu ikisinde birden olamaz. Bu bölüm o ikilemi mekanikleştiriyor:
iki taraf, tek bir seçim, tek bir işlem.

Çakışma **iki kaynaktan** doğuyor ve ikisi bilerek eşit değil:

- **Planlı çakışma — kesin.** Aynı güne vadesi gelen iki `social_plan` varsa
  çakışma zar atmadan kurulur. İkisine de söz verilmişti; biri mutlaka
  kırılacak, o yüzden elenen taraf `MISSED_PLAN_RELATIONSHIP_DELTA`'nın tamamını
  (−12) yer. Seçilen tarafın şablon deltası kabul günü zaten ödenmişti (§12.8),
  bu yüzden ona sabit bir "geldin" artısı yazılır
  (`CHOSEN_CONFLICT_RELATIONSHIP_DELTA`, +4) — yoksa ekranın bir barı yükselmez,
  yalnızca biri düşerdi.
- **Kendiliğinden çakışma — düşük ihtimalli.** Hiç plan olmayan bir gün
  `SOCIAL_CONFLICT_DAILY_CHANCE` ile tek teklif yerine **iki** teklif açabilir:
  iki kişi birbirinden habersiz aynı akşamı istemiştir. Kimseye söz
  verilmediği için elenen taraf yalnızca kendi şablonunun `decline` deltasını
  (−1…−5) alır. Zar `SOCIAL_OFFER_DAILY_CHANCE`'in dörtte biri kadardır ve
  kendi ad alanından (`{seed}:social_conflict:{on_date}`) türer — tekli teklif
  akışına bir çekiliş eklemek mevcut her zırlanmış seçimi kaydırırdı (INV-7).

İki taraf daima **farklı ilişkilerdir**; aynı kişiyle aynı kişi arasında seçim
bir ikilem değil, bir hatadır.

Karar **tembel ve yapışkan** kurulur (§12.2'nin kadro kararıyla aynı gerekçe):
ilk soran yazar, sonrakiler okur. T1'in olay listesi ile T3'ün kapısı aynı akşam
hakkında anlaşmak zorunda; her çağrıda yeniden karar verilse takvim ile kapı
ayrışırdı.

#### Şema — `013_social_conflicts.sql`

```sql
CREATE TABLE social_conflict (
  career_id   TEXT NOT NULL REFERENCES career(career_id) ON DELETE CASCADE,
  conflict_id TEXT NOT NULL,          -- 'scf_' + 12 hex
  source      TEXT NOT NULL,          -- 'plan' | 'offer'
  due_on      TEXT NOT NULL,          -- 'YYYY-MM-DD'
  left_ref    TEXT NOT NULL,          -- social_plan.plan_id | social_offer.offer_id
  right_ref   TEXT NOT NULL,
  status      TEXT NOT NULL,          -- 'open' | 'resolved'
  chosen_ref  TEXT                    -- çözülünce seçilen taraf; açıkken NULL
);
```

Taraflar kendi tablolarında kalır; `source` hangisi olduğunu söyler. `left_ref`
ve `right_ref` koşullu olarak iki farklı tabloyu gösterdiği için FK yoktur —
`social_plan.offer_id` ve `sponsorship_obligation.deal_id` ile aynı gerekçe.

#### Uçlar

| # | Yöntem | Yol | Açıklama |
|---|---|---|---|
| — | `GET` | `/careers/{cid}/social/conflicts` | Açık çakışma (en fazla bir tane); sorulması planlı çakışmayı oluşturur |
| — | `POST` | `/careers/{cid}/social/conflicts/{conflict_id}/choose/{ref_id}` | Tarafı seç; diğer taraf aynı işlemde kapanır |

Seçim gövdede değil yolda — R5/R6'nın `accept`/`decline`'ı ile aynı gerekçe
(§5.4): router'ın zaten imkânsız olduğunu bildiği üçüncü bir değeri reddetmek
için şema gerekmesin.

Yanıt yine R3/R5/R6 zarfıdır (`career_state` + `relationship_changes` +
`attribute_changes` + `ledger_entries`, INV-18) ve `offer`/`plan` yerine
`conflict` taşır. **`relationship_changes` tam iki eleman taşır** — biri artı,
biri eksi; ekranın iki barı doğrudan bu `before`/`after` çiftlerinden oynar.

`GET /conflicts`'in taraf satırları `ref_id`, `relationship_id`, `title`, `body`
ve `relationship` blokunu taşır. **Ne deltalar ne `costs` gönderilir.** Deltalar
§5.7'nin ve §5.4 R4'ün gerekçesiyle dışarıda: ödül tablosunu yayınlamak
sürprizi bozar, üstelik bu ekran onu okumanın en kolay yeri olurdu. `costs`
dışarıda çünkü çakışma hiçbir şey harcamıyor (D60); harcanmayacak bir bütçeyi
kartta yazmak arayüzün sunucu adına söylediği bir yalan olurdu.

#### Gün döngüsü kapısı

`list_events()` açık çakışmayı `{"kind": "social_conflict_due", ...}` olarak
ekler ve bu tür `STOP_EVENT_KINDS`'tadır — `social_plan_due` gibi seviye
tetiklidir, cevaplanana kadar her gün durdurur. Çakışmanın **iki üyesi için
kendi `social_offer`/`social_plan_due` olayları listeye konmaz**: aynı akşam iki
kez bildirilirse gün iki kez durur ve `stop_reason` hangi ekranın açılacağını
söyleyemez.

`POST /advance` kapısında `social_conflict_pending`, `social_offer_pending` ve
`social_plan_pending`'den **önce** gelir. Çakışmanın tarafları zaten açık bir
teklif ya da vadesi gelmiş bir plandır; alttaki kapılar önce tetiklenirse oyuncu
karar iki akşam hakkındayken tek akşam gösteren ekrana yönlendirilir.

#### Yeni kararlar

| # | Konu | Karar | Gerekçe |
|---|---|---|---|
| D59 | Çakışmanın doğuşu | **Aynı güne düşen iki plan kesin çakışma; plansız gün `SOCIAL_CONFLICT_DAILY_CHANCE` ile düşük ihtimalli çakışma** | Söz verilmiş iki randevu zaten çakışmıştır, zara bırakılacak bir şey yok. Plansız gündeki çakışma ise dünyanın oyuncudan habersiz işlediğinin kanıtı — ama nadir olmalı, ve kimseye söz verilmediği için elenen tarafın cezası kendi `decline` deltasıyla sınırlı kalmalı |
| D60 | Çakışmanın bedeli | **Çözüm gün bütçesinden hiçbir şey harcamaz ve `requires` kontrol etmez** | Cevap zorunlu (D53). INV-40 "ret her zaman mümkün olmalı" derken tek çıkışın bedelsiz olmasını kastediyordu; burada **iki** çıkış da bedelli olsaydı, günü bitmiş bir oyuncu ikisini de veremez ve kariyer kapının arkasında kilitlenirdi |

#### Yeni invariant'lar

| # | Garanti |
|---|---|
| INV-52 | Bir çakışma tek işlemde çözülür: tam olarak bir taraf seçilir, iki taraf da aynı transaction'da kapanır ve yanıtın `relationship_changes`'i tam iki eleman taşır |
| INV-53 | Açık bir çakışmanın üyeleri kendi başlarına `attend`/`skip`/`accept`/`decline` edilemez; plan çakışmasında elenen tarafın cezası teklif çakışmasınınkinden daima ağırdır |

#### Yeni hata kodları

| HTTP | `code` | Ne zaman |
|---|---|---|
| 404 | `social_conflict_not_found` | Bilinmeyen `conflict_id` |
| 409 | `social_conflict_not_open` | Çakışma zaten çözülmüşken tekrar `choose` çağrıldı |
| 409 | `social_conflict_pending` | Cevaplanmamış bir çakışma varken `advance` çağrıldı; mesaj `conflict_id` taşır |
| 409 | `social_conflict_member` | Açık bir çakışmanın bir tarafı tek başına cevaplanmak istendi (INV-53) |

Tarafı olmayan bir `ref_id` için yeni kod yok: mevcut `422 invalid_request`,
mesajında işe yarayacak iki ref'i sayar (§1.3).

### 12.10 Taktik uyum

`CoachTraits.tactical_fit` bu bölüme kadar **ölü veriydi** — §3.4
tanımlıyordu, R1/R2 döndürüyordu, hiçbir kod yolu yazmıyordu. `trust`'ın
§12.1'de kapatıldığı boşluğun aynısı, `CoachTraits`'in ikinci yarısı. Döngü
şöyle kapanıyor:

```text
rol -> talimat -> maç -> uyum -> antrenör ilişkisi + tactical_fit
```

Antrenörün bir beklentisi vardı (`coach_talk_screen.dart`'ın açılış cümlesi
bunu yıllardır söylüyordu: *"senden de o çerçevede oynamanı bekliyorum"*)
ama karşılığında hiçbir mekanik yoktu. Bu bölüm üçünü ekliyor: beklentinin
kendisi (talimat), ne kadar karşılandığının ölçümü (uyum) ve buna verilen
tepki (antrenör ilişkisi + `tactical_fit`).

#### Talimat nereden gelir

Her rolün varsayılan bir talimatı var (`worlddata/positions.py`'nin
`instruction` alanı) — API_CONTRACT §6.1'in `focus`'uyla aynı dört değer,
`'any'` = "farketmez":

| Grup | Rol | Talimat |
|---|---|---|
| DC | Stoper (`stoper`) | Savunma |
| DC | İleri Çıkan Stoper (`ileri_cikan_stoper`) | Savunma |
| DC | Libero (`libero`) | Taktik |
| DL/DR | Bek (`bek`) | Savunma |
| DL/DR | Kanat Bek (`kanat_bek`) | Savunma |
| DL/DR | Oyun Kuran Kanat Bek (`oyun_kuran_kanat_bek`) | Taktik |
| DL/DR | Yaratıcı Kanat Bek (`yaratici_kanat_bek`) | Hücum |
| DM | Defansif Orta Saha (`defansif_orta_saha`) | Savunma |
| DM | Yarı Bek (`yari_bek`) | Savunma |
| DM | Regista (`regista`) | Taktik |
| MC | Merkez Orta Saha (`merkez_orta_saha`) | Taktik |
| MC | Oyun Kurucu (`oyun_kurucu`) | Taktik |
| MC | Box-to-Box Orta Saha (`box_to_box`) | **Farketmez** |
| MC | Mezzala (`mezzala`) | Hücum |
| AMC | Ofansif Orta Saha (`ofansif_orta_saha`) | Hücum |
| AMC | Gelişmiş Oyun Kurucu (`gelismis_oyun_kurucu`) | Taktik |
| AMC | Shadow Striker (`shadow_striker`) | Hücum |
| Kanat | Kanat (`kanat`) | Hücum |
| Kanat | İç Kanat (`ic_kanat`) | Hücum |
| ST | Forvet (`forvet`) | Hücum |
| ST | Hedef Adam (`hedef_adam`) | Hücum |
| ST | Fırsatçı Forvet (`firsatci_forvet`) | Hücum |
| ST | Pres Yapan Forvet (`pres_yapan_forvet`) | Savunma |
| ST | Derine Gelen Forvet (`derine_gelen_forvet`) | Taktik |

Eşleme **`group` değil `role_id` üzerinden**: aynı grubun iki rolü gerçekten
farklı iş yapıyor (DM'de `regista` oyun kurar, `defansif_orta_saha` kurmaz)
ve `group` üzerinden anahtarlansaydı §12.1'in `request_role`'ü maç gününde
hiçbir şey değiştirmeyebilirdi — bedeli ödenen bir talebin sonucu olmazdı.
`box_to_box → Farketmez` bilinçli: "farketmez" gerçek bir talimat ve tam
olarak bir rolün ona düşmesi, o dalın yalnızca testte değil üretimde de
çalıştığını garanti eder.

#### Şema — `014_match_instruction.sql`

```sql
ALTER TABLE fixture ADD COLUMN user_match_instruction TEXT;   -- 'attack'|'defend'|'tactical'|'any'
```

`010_squad_status.sql` ile aynı gerekçe: karar bir fikstüre birebir bağlı ve
kullanıcı başına tek (D4 korunuyor), ayrı bir tablo değil tek kolon. **SQL
`NULL` = "henüz sorulmadı"**, `'any'` string'i = "farketmez" — ikisi farklı
şeyler ve aynı hücreye sığmazlar; `'any'`, §6.1'in kendi alias listesinde
zaten tanımlı bir değer.

#### Karar tembel ve yapışkan — ama §12.2'den bir farkla

Kadro durumu gibi (§12.2) ilk soran hesaplar, yazar; sonrakiler okur. Farkı:
kadro durumu **bir kez yazılır ve asla değişmez** (INV-44). Bir fikstürün
talimatı da yapışkandır ama **tam olarak bir şey** onu ezebilir: kabul
edilmiş bir M4 talebi (`request_instruction`, ya da rolü değiştiren bir
`request_role`/`request_position` — §12.1). INV-54 bu farkı yazıyor.

#### M1 değişikliği

Yanıta `coach_instruction` bloğu eklendi:

```jsonc
"coach_instruction": {
  "focus": "defend",        // "attack"|"defend"|"tactical"|null — null = farketmez
  "label": "Savunma",
  "role_id": "stoper",
  "role_name": "Stoper",
  "position": "Defans",
  "source": "role"          // "role" | "coach_talk"
}
```

`engine_payload`'ın **dışında**, `formation_id` ile aynı gerekçeyle: motor
rol kavramını bilmiyor, gövde motora olduğu gibi POST'lanıyor.
`role_name`/`position`, FE'nin bugüne kadar yalnızca bunun için ikinci bir
istek (C3/hub) atmasını gerektiren alanlardı — artık M1'de geliyor, o ikinci
istek gereksiz hâle geliyor. `source` yazılmıyor, **türetiliyor**: donmuş
talimat, oyuncunun **güncel** rolünden türeyecek varsayılanla karşılaştırılır
— eşleşmiyorsa tek açıklaması kabul edilmiş bir M4 talebidir, çünkü
`domain/instructions.py` dondurulmuş bir değeri kendiliğinden değiştirmez.

#### M4 değişikliği

§12.1'in konu tablosuna üçüncü bir talep eklendi: `request_instruction`
(bkz. §12.1). En ucuzu (25 zaman / 3 enerji, `request_position`'ın 35/4'üne
ve `request_role`'ün 30/4'üne karşı) — istediği şey de en küçük: seni
taşımasını değil, bugün farklı oynamanı istiyorsun. `_success_chance`'a özel
bir bonus **yok**; fonksiyon üç talep arasında paylaşılıyor, daha iyi bir
sonuç yine güven ya da ilişkiden kazanılıyor.

Bu, aynı zamanda üçüncü talebin INV-43'ün maç başına bir konuşma bütçesini
hak ettiği yer: menü artık üç gerçek seçenek sunuyor — güven satın al
(kabul), kim olduğunu değiştir (rol/pozisyon, kalıcı), bugün ne yapacağını
değiştir (talimat, tek maçlık). Dürüst karşı-argüman: saf beklenen değer
açısından `request_instruction` etkisi maç sonunda bittiği için
`request_role`'ün gölgesinde kalır — bu, bir başarı bonusuyla değil
gün-bütçesi indirimiyle (25/3, geri kalan gün payını daha çok bırakır)
fiyatlanmıştır.

#### M2 değişikliği

Gövde bir opsiyonel alan daha alır:

| Alan | Kural |
|---|---|
| `tactical_compliance` | `0.0`–`1.0` ondalık; `minutes_played > 0` gerektirir |

| Durum | `tactical_compliance` |
|---|---|
| §12.10 öncesi yazılmış bir gövde | alan yok — geçerli, eski anlamıyla (ölçülmedi) |
| Sahaya hiç çıkmadı | alan yok |
| Talimat "farketmez" | alan yok |
| Aksi hâl | `0.0`–`1.0` |

Geçersiz bileşim: `tactical_compliance` ile birlikte `minutes_played`
etkin değeri (yoksa `started ? 95 : 0`) `0` → `422`. Alan opsiyonel olduğu
için §12.10 öncesi yazılmış bir gövde hâlâ geçerli — `started`/
`minutes_played`'in §12.2'de aldığı yolun aynısı.

#### Uyum nasıl ölçülür (FE)

Ölçüm motorun bildirdiği tick'in `directives.focus`'undandır, **FE'nin
gönderdiğinden değil**: E4 toleranslı bir uçtur (§6.1) — tanınmayan bir
`focus` sessizce eskisinde bırakılır — ve FE bir direktif POST'unun sonucunu
iyimser uygulamaz. Gönderdiğiyle ölçmek, sunucunun reddettiği bir direktifle
uyum kazanmak olurdu.

İki tick arasındaki her aralık **önceki** tick'in bildirdiği focus'a
yazılır: E4'ün `effective_from_minute`'ı `current + 1`'dir, yani 34'te
gönderilen bir direktif 35'ten itibaren geçerli. Sahada olma durumu da aynı
pencereden okunur — `minutes_played` (§12.2) ile aynı — bu yüzden bir yedek
yalnızca kendi oynadığı dakikalardan sorumlu tutulur, kulüpte geçirdiği
dakikalardan değil.

#### Antrenör delta'sı

`_match_relationship_deltas`'ın `coach` teriminde üç bant var (sürekli bir
eğri değil):

| `tactical_compliance` | Terim |
|---|---|
| Ölçülmedi (`null`) | 0 |
| `≥ 0.80` | +1 |
| `0.50–0.80` | 0 |
| `< 0.50` | −2 |

**+1, `+1 if goal_count >= 1` ile aynı büyüklükte** — söylenene tam uymak,
antrenör gözünde gol atmakla eşdeğer. **−2, `-2 if reds >= 1` ile aynı** —
maçın yarısını görmezden gelerek geçirmek, kırmızı kartla aynı sınıf bir
disiplin sorunu. −2/+1 asimetrisi §12.1'in kendi asimetrisinin
(`GRANTED_TRUST -5.0` / `REFUSED_TRUST -2.0`) yankısı.

Clamp öncesi aralık artık **[−7, +5]** (kayıp −2, kırmızı −2, iki sarı −1,
uyumsuzluk −2), iyi uç tam +5'e ulaşıyor (galibiyet 3 + gol 1 + uyum 1).
±5 clamp'i **ilk kez** kötü uçta gerçekten dokunulan bir sınır oluyor.
**Yalnızca `coach`** — taraftar bir taktik talimat görmez, medyanın bireysel
oyuncu katmanı yok (İmza maddesi 1); takım arkadaşı tartışılabilir ama bu
özellik ilk turunda ikinci bir tüketici büyütmüyor.

#### `tactical_fit`

Her maç sonrası `tactical_fit`, o maçın uyum oranına **çeyrek yol**
çekilir: `yeni = eski + 0.25 × (uyum − eski)`. Sabit bir delta değil —
`trust`'ın bir konuşmadan aldığı sabit değişim gibi — çünkü bir konuşma bir
olay, bir "fit" bir ortalama; sabit bir delta birkaç maçta 0/1'de doyar ve
bilgi taşımayı bırakırdı. Sınırlar zaten `relationships.TRAIT_BOUNDS`'ta.

#### Uyumun bedeli

Uyumu **raporlamak** bedava — ama **uymak** değil. `focus`, motorun hangi
aksiyonu teklif edeceğini `role_fit` çarpanıyla ([0.35, 1.75], API_CONTRACT
§6.2) eğiyor: "savunma" denen bir forvet gerçekten daha az şut fırsatı
görür. Bu paragraf olmadan özellik bedava bir +1'e indirgenir — bedel
burada, motorun kendi teklif dağılımında yaşıyor, career_engine'de değil.

#### Kapsam dışı

Yalnızca `focus` ölçülür — bkz. **D61**.

#### Yeni kararlar

| # | Konu | Karar | Gerekçe |
|---|---|---|---|
| D61 | Uyumun kapsamı | **Yalnızca `focus` ölçülür; `effort`/`aggression` ölçülmez** | API_CONTRACT §6.2: *"`effort` başarı şansını ve hangi aksiyonun teklif edildiğini DEĞİŞTİRMEZ"* — kondisyon/frekans kadranı, taktik kadranı değil, ve bedeli zaten `final_condition` → gelecek haftanın kadro seçiminde ödeniyor. `aggression`'ın taktik okuması `_match_relationship_deltas`'ın kart terimlerinde zaten fiyatlanmış; ikinci kez ölçmek aynı davranışı tek fonksiyon içinde iki kez saymak olurdu |
| D62 | `tactical_fit`'in kadro seçimindeki yeri | **Bu turda `squad.selection_score`'a girmez** | `selection_score`'un üç ağırlığı (0.45/0.35/0.20) taze bir kariyerin 76.5'e oturup ilk 11'de başlamasına göre kalibre edilmiş (§12.2). Nötr değeri 0.5 olan dördüncü bir girdi eklemek dördünün de yeniden türetilmesini gerektirir — bu, uyumu *ölçmekten* ayrı bir değişiklik ve onunla aynı turda gelmemeli |

#### Yeni invariant'lar

| # | Garanti |
|---|---|
| INV-54 | Bir fikstürün `user_match_instruction`'ı ilk soruluşta oyuncunun **o anki** rolünden türetilir ve yazılır. Sonrasında yalnızca kabul edilmiş bir M4 talebi (`request_instruction`, ya da rolü değiştiren bir `request_position`/`request_role`) onu değiştirebilir; M2'nin uyum ölçümü daima fikstürdeki **son** değere göre değerlendirilir. Kasıtlı olarak INV-44'ten (kadro durumu: bir kez yazılır, asla değişmez) farklı — bu değer yapışkan ama kalıcı olarak dondurulmuş değil |

#### Notlar

§12.0'ın "Geçersiz kılananlar" tablosuna **yeni satır eklenmedi**: §3.4'ün
traits notu zaten §12.1'in satırıyla kapsanıyor, ve §5.6 M2'nin gövde
şeklinde hiç satır yok (§12.2 de `started`/`minutes_played`'i satırsız
ekledi) — §12.10'un aynı deseni izlemesi tutarlı, satır eklemek yanlış bir
emsal olurdu. **Yeni hata kodu yok** — `invalid_match_result` (422) ve
`invalid_request` (422) her durumu kapsıyor. **`API_CONTRACT.md`'de
değişiklik yok** — `tactical_compliance` bir career_engine M2 alanı;
`focus` semantiği (§6.1/§6.2) zaten tam olarak ölçülen şey, motor teline
hiçbir şey eklenmiyor.

---

### 12.11 Taktiksel antrenman

Antrenman ekranının üçüncü ailesi: `saha`/`kişi`'nin yanına `taktik`
katılıyor — Gegenpress, Pozisyonel Oyun, Derin Blok, her biri 0-100 arası
bir yeterlilik. §5.7 N3'ün geri kalanından iki yönde ayrılıyor: kartların
hiçbirinin `drill`'i yok (mini-oyun değil, bir çalışma seansı) ve hiçbiri
`requires` taşımıyor (bilinçli olarak kilitsiz, kapsam dar tutuldu).

#### Şema — `015_player_tactics.sql`

```sql
CREATE TABLE player_tactics (
  career_id  TEXT NOT NULL REFERENCES career(career_id) ON DELETE CASCADE,
  player_id  TEXT NOT NULL,
  tactic_key TEXT NOT NULL,
  value      REAL NOT NULL DEFAULT 0,
  PRIMARY KEY (career_id, player_id, tactic_key)
);
```

`player_attribute` ile aynı şekil ama ayrı tablo: `ATTRIBUTE_KEYS` INV-21'in
kapalı 12'li kümesi, `level()`/`requires`'a bağlı; taktik yeterliliğinin
ikisi de yok. `config.TACTIC_KEYS = ("gegenpress", "pozisyonel_oyun",
"derin_blok")` yeni, ayrı bir sabit küme (D63).

#### P1'e eklenen alan

`GET /careers/{cid}/player` artık bir `tactics[]` de döndürüyor —
`attributes[]`'la aynı "her zaman N satır" şekli:

```jsonc
"tactics": [
  { "key": "gegenpress", "value": 12.0 },
  { "key": "pozisyonel_oyun", "value": 0.0 },
  { "key": "derin_blok", "value": 4.8 }
]
```

Hiç antrenman yapılmamış bir anahtar `0.0` olarak döner, satır hiç
eksilmez (INV-55).

#### T2'ye eklenen alan

`POST /careers/{cid}/actions`'ın yanıtı, `attribute_changes`'in yanına bir
`tactic_changes[]` ekliyor — aynı şekil (`key`/`before`/`after`), seviye
alanı yok çünkü taktik yeterliliğinin bir seviye ölçeği yok:

```jsonc
"tactic_changes": [
  { "key": "gegenpress", "before": 11.2, "after": 12.0 }
]
```

#### Kartın doğrudan uygulanması

`drill: null` olan bir `kişi` kalemi FE'de bugün "Yakında" görünüyor ve
tıklanamaz (mini-oyunu yok, uygulaması da yok) — ama bir `taktik` kalemi
`drill: null` olsa da tıklanabilir: FE kartı doğrudan `POST
/careers/{cid}/actions`'a gönderiyor, hiçbir mini-oyun ekranı açmadan. BE
tarafında bu fark yok — `post_action` zaten `body.result`'ı hiç okumadan
(`None` de olsa) `item["effects"]`'i uygular; ayrım tamamen FE'nin hangi
kartı hangi butona bağladığında yaşıyor.

#### Kapsam dışı

Yeterliliğin maça nasıl yansıyacağı bu turda **yazılmıyor** — ⟦AÇIK-13⟧.
D37/INV-26 zaten oyuncu niteliklerinin hiçbirinin motora giden rating'e
girmediğini ve tek planlanan kanalın "gelecekteki bir mini-oyun-zorluk
kancası" olduğunu söylüyor (AÇIK-1, §5.6); taktik yeterliliği de aynı
kancayı bekleyecek, §12.10'un taze `tactical_compliance`/`tactical_fit`
hattına bu turda dokunmuyor.

#### Yeni kararlar

| # | Konu | Karar | Gerekçe |
|---|---|---|---|
| D63 | `player_tactics`'in ayrı bir tablo/modül olması | **`player_attribute`'a eklenmedi; kendi tablosu, kendi `domain/tactics.py`'si var** | `ATTRIBUTE_KEYS` INV-21'in kapalı kümesi, `level()`/`requires` onun üzerine kurulu; taktik yeterliliğinin ikisi de yok. Oraya eklemek ya kümeyi 15'e genişletip üç ölü hücre bırakırdı ya da aynı satırlardan ikinci bir invariant çıkarmayı gerektirirdi. `domain/tactics.py`, `attributes.py`'nin `apply_delta` şeklini birebir izliyor (kayıt yok — CONTRACT.md kişi başına bir denetim izi istemiyor, `attributes.py` da aynı gerekçeyle izlemiyor) |

#### Yeni invariant'lar

| # | Garanti |
|---|---|
| INV-55 | P1'in `tactics[]`'i her zaman tam `len(TACTIC_KEYS)` (3) satır taşır, hiç antrenman yapılmamış bir anahtar için bile — `attributes[]`'in INV-21'iyle aynı şekil |

---

### 12.12 Ürün faydaları

§6.6'nın `daily_effects` mekanizması ("sahip olmak mekaniğin tamamı") tek bir
anahtar taşıyordu: `condition`. 14 dükkân kaleminden yalnızca ikisi
(`home-treadmill`, `estate-villa`) gerçekten bir şey yapıyordu; geri kalanı,
`note`/`description`'ı bazen bir fayda ima etse de ("Islak zeminde fark
ediyor", "kahve kuyruğunda beklemeye son"), koda hiç dökülmemiş vitrin
metniydi. Bu bölüm `daily_effects`'i iki anahtar daha ekleyerek genişletiyor
ve dört kalemi gerçek, hissedilir bir faydaya bağlıyor.

#### Genişleyen küme

`catalog/__init__.KNOWN_DAILY_EFFECT_KEYS` artık `{"condition", "energy",
"fame:overall"}`. Dosyanın kendi yorumu bunu zaten şart koşuyordu: "widen
this set only in the same commit that teaches the day loop to apply the new
key" — bu commit tam olarak o.

| Kalem | Yeni `daily_effects` | Gerekçe |
|---|---|---|
| `home-espresso` | `{"energy": 3}` | "kahve kuyruğunda beklemeye son" |
| `estate-studio` | `{"energy": 2}` | "Tesise on beş dakika" |
| `estate-flat` | `{"condition": 1}` | geniş, konforlu kat (villa'nın küçük hâli) |
| `personal-watch` | `{"fame:overall": 0.3}` | "Röportajlarda ve sponsor çekimlerinde" |

`home-tv`, `home-console`, `personal-boots`, `personal-suit`,
`personal-headphones` kasıtlı olarak dokunulmadı — `daily_effects`'in bir
pasif-nitelik kavramı yok (INV-21 bilinçli olarak kapalı), bu yüzden bir
konsola ya da kramponlara uydurma bir mekanik eklemek onları vitrin metni
olarak dürüst bırakmaktan daha kötü olurdu.

#### Uygulama noktası — enerji, kondisyondan farklı bir yol izliyor

`domain/daytime.py::process_day()`, `condition.daily_recovery()`'nin hemen
yanında `fame:overall` bonusunu da doğrudan uyguluyor (`fame.apply`, aynı T2
tek seferlik etkisiyle aynı çağrı şekli). `energy` **aynı yerde
uygulanmıyor**: T3'ün çağıran tarafı (`api/routers/time.py::post_advance`)
`process_day()`'den hemen sonra `day_budget.refill()` çağırıyor, bu da
`remaining`'i **toptan** güne özgü sabit değere sıfırlıyor (toplamsal değil).
`process_day()` içinde uygulanan bir enerji bonusu bir satır sonra sessizce
silinirdi. Çözüm: bonus miktarı `process_day()`'in dönüş değerinde
(`energy_bonus`) dışarı taşınıyor, çağıran taraf `refill()`'den **sonra**
`day_budget.add(conn, career_id, "energy", bonus)` çağırıyor — **tavansız**:
T2'nin tek seferlik enerji etkisi (`ceiling=DAY_BUDGET_DEFAULTS["energy"]`)
kaybedilen enerjiyi güne özgü tavana kadar geri getiriyor, ama burada amaç
tam tersi — günü normalden **daha yüksek** bir enerjiyle başlatmak; aynı
tavanı kullanmak `refill()` zaten `remaining`'i o tavana oturttuğu için
bonusu anında etkisiz kılardı.

#### FE — rozetin canlanması

`note` (§5.8, FE sunumu) bugüne kadar sahip olunan bir kalemin gerçekte ne
yaptığına dair hiçbir canlı bağlantı taşımıyordu — salt vitrin metniydi.
`training_screen.dart`'ın P1 tabanlı ilerleme çubukları gibi, dükkân
ekranındaki "Sahip" rozetinin yanına, `daily_effects`'ten türetilen ayrı ve
belirgin (yeşil) bir "gerçek fayda" rozeti eklendi — sahip olunan bir kalemin
pazarlama metniyle gerçek mekaniği artık görsel olarak ayrışıyor.

#### Yeni kararlar

| # | Konu | Karar | Gerekçe |
|---|---|---|---|
| D64 | `energy` bonusunun uygulanma noktası | **`process_day()` içinde değil, çağıranın `day_budget.refill()`'den SONRAKİ adımında, tavansız `day_budget.add`** | `refill()` `remaining`'i toptan sıfırlıyor; `process_day()` içinde uygulansa aynı turda silinirdi. Tavan konursa da `refill()` zaten `remaining`'i o tavana oturttuğu için bonus sıfıra düşerdi — bu satır D64'ün asıl gerekçesi |

---

### 12.13 Yatırım getirisi

`investment` ailesinin üç kalemi ("Yıllık %28 getiri" gibi) bir getiri vaat
ediyordu ama hiçbir ödeme mekanizması yoktu — saf vitrin metni. Bu bölüm
`domain/sponsorship.py::pay_weekly()`'nin doğrudan bir aynası: aynı Pazartesi
kapısı, aynı `wallet.apply()` şekli, gelir yönünde (upkeep'in gideri yerine).

#### Şema — `016_investment_returns.sql`

```sql
ALTER TABLE inventory ADD COLUMN weekly_return INTEGER NOT NULL DEFAULT 0;
```

`upkeep_weekly`'nin birebir aynı şekli: satın alma anında donduruluyor,
katalogda yeniden fiyatlandırma zaten sahip olunan bir satırı etkilemiyor
(D27'nin ikizi).

#### `weekly_return_rate` → `weekly_return`

`catalog/shop.py`'de yalnızca `investment` kalemleri `weekly_return_rate`
taşıyor — `effects`/`daily_effects` gibi bir çapa-anahtar haritası değil, düz
bir oran (`upkeep_weekly` gibi doğrulanmamış bir üst-seviye alan).
`api/routers/time.py::post_purchase()`, satın alma anında `round(price *
weekly_return_rate)`'i hesaplayıp `inventory.weekly_return`'e yazıyor.

| Kalem | Fiyat (yeniden fiyatlandırıldı) | Oran | Haftalık |
|---|---|---|---|
| `invest-bond` | 80→2000 ₭ | %28/yıl (değişmedi) | ~11 ₭ |
| `invest-gold` | 110→3000 ₭ | %6/yıl | ~3 ₭ |
| `invest-fund` | 260→5000 ₭ | %20/yıl | ~19 ₭ |

Yeniden fiyatlandırma bilinçli: eski fiyatlarda (80-260 ₭) bu oranlar
yuvarlanınca 0 ₭/hafta verirdi — mekanik görünmez olurdu. `catalog/shop.py`
zaten "Amounts are authored... ⟦AÇIK-5⟧ still covers whether this scale is
right" diyor; bu değişiklik o iznin kapsamında.

#### Ödeme — `domain/investments.py::pay_returns()`

`sponsorship.pay_weekly()`'nin yapısal kopyası: `weekly_return > 0` olan her
`inventory` satırı için bir `wallet.apply(..., "investment",
f"investment:{item_id}:{on_date}", ...)`. `domain/daytime.py`'nin sponsorluk
çağrısının **her iki** noktasına da (`resolve_pending_monday` ve
`process_day`'in Pazartesi bloğu) sponsorluktan hemen sonra, upkeep'ten önce
eklendi — aynı "gelir önce, koşulsuz" sırası (§12.7'nin zaten belirttiği
gerekçe: bir çek nakde çevrilmeden bir villa geri alınmamalı).

#### Kapsam dışı

Altın/fon'un "gerçek" oynaklığı (fiyat dalgalanması, bir satış eylemi)
bilinçli olarak yazılmadı — ⟦AÇIK-15⟧. Bu turda üçü de aynı sabit haftalık
oranla çalışıyor; `invest-fund`'ın "dalgalı" vitrin metni bugün yalnızca
metin. D37'nin kendi AÇIK-1 notuyla aynı desen: daha derin bir simülasyon,
istendiğinde ayrı bir artış olarak gelecek.

#### Yeni kararlar

| # | Konu | Karar | Gerekçe |
|---|---|---|---|
| D65 | Yatırım getirisinin şekli | **Sabit haftalık tutar, satın almada donduruluyor — `upkeep_weekly`/`weekly_income` ile aynı desen** | Üç kalemin de (tahvil/altın/fon) farklı bir simülasyon modeli (sabit oran, fiyat dalgalanması, rastgele getiri) hak ettiği tartışılabilir, ama üçü de TEK bir mekanizmadan (haftalık Pazartesi ödemesi) geçirmek hem test yüzeyini hem riski küçük tutuyor; fon'un "iddialı" karakteri bugün yalnızca daha yüksek bir sabit orana (%20 vs %6/%28) yansıyor |

### 12.14 Mevki bazlı maç senaryoları

**Geçersiz kılananlar:** yok. Bu bölüm §12.10'un `coach_instruction` bloğuna
tek bir alan ekler; blokta bugün var olan hiçbir alanın anlamı değişmez.

Maç içi müdahale teklifleri (API_CONTRACT §7.2) bugüne kadar oyuncunun
mevkisinden bağımsız seçiliyordu: motor takım seviyesinde çalışıyor ve rol
kavramını bilmiyor, dolayısıyla bir stoper de bir santrafor da aynı aksiyon
havuzunu görüyordu. §12.10'un `focus`'u tek dolaylı bağdı, ama üç kovalı
(`attack`/`defend`/`tactical`) ve oyuncu maç içinde değiştirebiliyor.

#### M1 değişikliği

`coach_instruction` bloğuna bir alan eklendi:

```jsonc
"coach_instruction": {
  "focus": "defend",
  "label": "Savunma",
  "role_id": "stoper",
  "role_name": "Stoper",
  "position": "Defans",
  "position_group": "dc",   // YENİ — §12.14
  "source": "role"
}
```

`position_group`, rol katalogundaki `group` alanının wire karşılığıdır
(`worlddata/positions.py`): `"dc" | "fb" | "dm" | "mc" | "amc" | "wing" | "st"`.
Rolü olmayan bir kariyerde (onboarding öncesi) `null`.

`group` doğrudan gönderilmiyor, çünkü o alan görüntüleme amaçlı yazıldı ve
`"DL/DR"` gibi slash taşıyan bir değer içeriyor — bir enum'da taşınacak şekle
uygun değil. Çeviri tablosu (`GROUP_WIRE`) `worlddata/positions.py`'ın kendi
içinde, `ROLES`'un yanında duruyor; dosyanın açılış docstring'indeki "iki elle
senkron tuple" uyarısının aynısı burada da geçerli, tabloyu ayrı bir modüle
taşımak o hatayı yeniden doğururdu. Bir assert her `group`'un `GROUP_WIRE`'da
karşılığı olduğunu import anında doğruluyor.

Kaleci (`gk`) tabloda **yok**: §5.1'in kendi gerekçesiyle kaleci v1'de
seçilebilir bir mevki değil. motor tarafı o anahtarı tanıyor (API_CONTRACT
§6.8), yani kaleci açıldığında bu dosyaya tek satır eklemek yetiyor.

#### Motorun bunu ne yaptığı

FE bu değeri E2 `POST /matches/{id}/start`'ın `position` alanına olduğu gibi
iletiyor; motor onu bir teklif ağırlığı çarpanına çeviriyor (API_CONTRACT
§6.8). Teklif **sıklığı** değişmiyor, yalnızca hangi aksiyonun teklif
edildiği eğiliyor.

#### Yeni kararlar

| # | Konu | Karar | Gerekçe |
|---|---|---|---|
| D66 | `position_group` nereden gider | **`coach_instruction` bloğunda, `engine_payload`'ın dışında; motora E2 `/start` ile FE üzerinden ulaşır** | `engine_payload` motora olduğu gibi POST'lanan gövdedir ve motorun E1'i (`POST /matches`) taşıdığı alanları E2'ye aktarmıyor — `user_condition` bile `PendingMatchup`'ta düşüyor. Alanı oraya koymak motorun oturum kurulumunu büyütürdü. E2 ise zaten `effort`/`aggression`/`focus`'u, yani "bu oyuncu bu maçı nasıl oynuyor" bilgisini taşıyan uç; mevki de aynı cinsten ve `focus`'un tam yanına oturuyor. §12.10'un `focus` için verdiği gerekçe (motor rol kavramını bilmiyor, blok `engine_payload`'ın dışında durur) burada da aynen geçerli |
| D67 | Ayrıntı seviyesi | **Mevki grubu (7), hat (3) ya da `role_id` (22) değil** | Hat, stoper ile kanat beki ya da defansif orta saha ile ofansif orta sahayı ayıramıyor — istenen ayrımın tam ortasından geçiyor. `role_id` ise motorda 22 × 13 = 286 elle ayarlanacak katsayı demek; roller eklendikçe bakımı motorun değil kariyerin hızına bağlanırdı. `group` zaten `ROLES`'ta tanımlı ve yedi değerin her biri sahada gerçekten farklı bir iş yapıyor |

---

## 13. EK: İLİŞKİ ÖMRÜ, PASİF FAYDALAR VE AKTİVİTE OLAYLARI

Beş düzenleme, tek tur. Üçü ilişki modelinin ömrüne dokunuyor (kulüp bazlı
ilişkiler, partnerin sonradan edinilmesi, aktivite olayları), ikisi gelişim
yollarına (sahip olunan eşyanın pasif faydası, antrenmanın iki aileye inmesi).
Beşi aynı turda duruyor çünkü birbirlerinin boşluğunu dolduruyorlar: §13.5 kişi
antrenmanını kaldırıyor, §13.3 ile §13.4 onun yerine geçen iki kaynağı getiriyor;
§13.4'ün olay makinesi de §13.2'nin partnerle tanışma kapısı.

### 13.0 Geçersiz kılınanlar

§11.0 ve §12.0'ın aynı disiplini: bu bölüm **yalnızca aşağıda adı geçen**
hükümleri geçersiz kılar. Listede olmayan her madde yürürlüktedir.

| Nerede | Bugünkü hüküm | §13'ün hükmü |
|---|---|---|
| §3.4 · `worlddata/relationships.py` | Altı ilişki de kariyer boyu tek satır | Üçü (`coach`/`team`/`fans`) **kulüp kapsamlı**; transferde sıfırlanır (§13.1) |
| §3.4 seed notu | `partner` satırı 0 skorla ilk günden yazılır ve listelenir | Satır yazılmaya devam eder ama `state='absent'` doğar ve **R1'de dönmez** (§13.2) |
| §5.4 R1 | "Altı kategori döner" | **Beş veya altı**: `absent` bir ilişki listelenmez |
| §5.4 R3 | Yanıt skor / nitelik / defter değişimi taşır | Yanıt ayrıca `relationship_state_changes[]` taşır |
| §11.7 S4 | Yanıt kulüp + sözleşme taşır | Yanıt ayrıca `relationships_reset[]` taşır |
| §5.2 P1 · D43 | `level` = `floor(value / 10)` | `level` = `floor(effective_value / 10)` — **anlamı değişti** (§13.3, D74) |
| §12.12 | "`daily_effects`'in bir pasif-nitelik kavramı yok" | `passive_effects` **ayrı bir harita** olarak gelir; `daily_effects`'in kendisi hiç değişmez |
| §12.11 | Antrenman aileleri: `saha` · `kişi` · `taktik` | **İki aile**: `saha` · `taktik` |
| §12.11 | `drill: null` iki anlama gelir (kişi → "Yakında", taktik → doğrudan uygula) | `drill: null` **tek** anlama gelir: doğrudan uygulanan taktik kartı |
| §5.7 N3 `training` | 15 kalem | **10 kalem** (7 `saha` + 3 `taktik`) |
| §5.5 T2 | Yanıt yalnızca uygulanan maliyet ve etkileri taşır | Yanıt opsiyonel bir `event` bloğu da taşıyabilir (§13.4) |

**Geçersiz kılınmayan, özellikle belirtilmesi gereken üç madde:** D4 (kadro yok,
tek oyuncu satırı), D23 (diyalog **ağaçları** FE'de kalır), INV-21
(`ATTRIBUTE_KEYS` kapalı 12'li küme — §13.5 bir aileyi değil, o ailenin
**antrenman yolunu** kaldırır).

---

### 13.1 Kulüp bazlı ilişkiler

Antrenör, takım arkadaşları ve taraftarlar bir **kulübe** aittir; medya, partner
ve aile kariyere. Bugün altısı da kariyer boyu tek satır: bir oyuncu transfer
olduğunda eski kulüpte kazandığı güveni, soyunma odası itibarını ve tribün
sevgisini yeni kulübe taşıyor. §12.2'nin kadro seçimi bunu doğrudan tüketiyor
(antrenörün `trust`'ı ağırlığın %35'i), yani yanlış olan yalnızca hikâye değil,
mekanik.

#### Kimlik sabit kalır, kapsam kolona taşınır (D68)

`relationship_id` FE'de yalnızca bir anahtar değil, **sunum anahtarıdır**. Beş
ayrı yerde sabit olarak yazılı:

| Nerede | Ne yapıyor |
|---|---|
| [`character_portrait.dart:43-58`](../lib/widgets/character_portrait.dart) | Portreyi `relationship_id`'yi hash'leyerek türetiyor — "aynı id her açılışta aynı yüz" |
| [`relationship_presentation.dart:52-105`](../lib/widgets/relationship_presentation.dart) | Rozet kodu, sol etiket, diyalog kimliği, sahne |
| [`relationships_screen.dart:20-145`](../lib/screens/relationships_screen.dart) | Diyalog ağaçları, id'ye göre anahtarlı |
| [`request_screen.dart:336-342`](../lib/screens/request_screen.dart) | Maç sonrası delta çubuklarının sırası |
| [`social_offer_screen.dart:407-425`](../lib/screens/social_offer_screen.dart) | Teklifin kapanış cümlesi |

Bu yüzden kimliğe kulüp eklemek (`coach@t_ykz` gibi) **seçenek değildir**: beş
yerde birden varsayılana düşer, NPC'nin yüzü değişir, "ARA" düğmesi sessizce
ölür. **Altı sabit kimlik korunur**; kapsam ayrı bir kolonda yaşar.

```sql
-- 017_relationship_scope.sql
ALTER TABLE relationship ADD COLUMN scope   TEXT NOT NULL DEFAULT 'career';  -- 'career'|'club'
ALTER TABLE relationship ADD COLUMN team_id TEXT;                            -- scope='club' iken dolu
```

| `relationship_id` | `scope` | Gerekçe |
|---|---|---|
| `coach` · `team` · `fans` | `club` | Kulüple gelir, kulüple gider |
| `media` · `partner` · `family` | `career` | Ülke basını ve hayatındaki insanlar; transfer bunları değiştirmez |

`scope` koddaki bir sabitten türetilmiyor, kolon olarak saklanıyor: satır zaten
hangi kulübe ait olduğunu (`team_id`) taşımak zorunda ve ikisini ayrı yerlerde
tutmak onları bir gün ayrı düşürürdü.

#### Sıfırlamanın üç katmanı (D69)

Tetikleyici **yalnızca `player.team_id`'nin değişmesidir**, yani §11.7'nin S4
transfer kabulü. Aynı transaction içinde, kulüp yazıldıktan hemen sonra:

**1 · Skor** → `worlddata/relationships.STARTING_SCORES` (`coach` 70 · `team` 50 ·
`fans` 40). Doğrudan `UPDATE` **değil**, `relationships.apply_delta(rid,
varsayılan − mevcut, reason=f"transfer_reset:{team_id}")`. Bu bir üslup tercihi
değil, INV-15'in koşulu: §3.4 "bir test olay günlüğünü baştan oynatıp skoru
yeniden hesaplar ve tutmazsa kırılır" diyor. Günlükten geçmeyen bir sıfırlama o
testi ilk transferde kırardı.

**2 · `traits`** → o `kind`'ın model varsayılanına döner; antrenör için
`CoachTraits.trust = 50.0` ([`domain/relationships.py:26`](domain/relationships.py)).
Yazma yolu INV-42'nin tek kapısı, `apply_trait_delta()`. Sonucu §12.2'de
ölçülebilir: kadro ağırlığının %35'i `trust`, %20'si antrenör ilişkisi, %45'i
kondisyon. Sıfırlanmış bir kariyer taze kariyerin 76.5'ine döner — yeni kulüpte
yer yeniden kazanılır.

**3 · Kimlik** → `person_name`, `contact_name`, `age`, `occupation`, `bio`,
`hobbies` yeni kulübün havuzundan yeniden yazılır. Havuz
`worlddata/relationships.py`'e `CLUB_STAFF` olarak eklenir; satırı olmayan takım
için seçim `career.seed` + `team_id`'den deterministik yapılır, böylece INV-7
(aynı seed → aynı dünya) korunur.

Üçünün birlikte olmasının gerekçesi: ikisi tek başına tutarsız bir dünya bırakır.
Yalnızca skor sıfırlanırsa antrenör değişmemiş görünürken güveni yerinde kalır;
skor ve `traits` sıfırlanıp kimlik kalırsa "Mert Çalışkan yeni kulübünde de seni
bekliyordu ama seni tanımıyor" çıkar.

#### Sıfırlama YAPMAYAN olaylar

Üçü de kulübe dair bir şeyi değiştirdiği ve karıştırılmaya açık olduğu için
açıkça yazılıyor:

| Olay | Neden sıfırlamaz |
|---|---|
| Sezon devri (§11.5 S1) | Kulüp aynı; yalnızca sezon kimliği ilerliyor |
| Terfi / düşme (§11.4) | Kulüp aynı, lig değişiyor — antrenörün sana güveni ligle ilgili değil |
| Sözleşme bitişi · serbest oyunculuk (§11.7) | `player.team_id` mevcut kulüpte kalıyor; kimse gitmedi |

#### S4 yanıtına eklenen blok

```jsonc
{ "career_state": { /* CareerState */ },
  "team":         { /* TeamRef — yeni kulüp */ },
  "competition":  { /* CompetitionRef */ },
  "contract":     { /* … */ },

  "relationships_reset": [                        // YENİ · §13.1
    { "relationship_id": "coach", "before": 82, "after": 70,
      "person_name": "Kerem Tunç",   "contact_name": "Antrenör Kerem" },
    { "relationship_id": "team",  "before": 64, "after": 50,
      "person_name": "Onur Bilge",   "contact_name": "Takım grubu" },
    { "relationship_id": "fans",  "before": 71, "after": 40,
      "person_name": "Tribün Grubu", "contact_name": "Taraftar grubu" } ] }
```

`before`/`after` R3'ün `relationship_changes` şeklini izler; kimlik alanları
eklidir çünkü FE'nin yeni ismi öğrenmesinin başka yolu R1'i yeniden çekmektir ve
transfer ekranı bugün onu çekmiyor (§13.11).

---

### 13.2 Partner ilişkisinin ömrü

Partner bugün ilk günden listede duruyor, skoru 0 ve `partner_01` ağacı açık.
`worlddata/relationships.py`'nin kendi yorumu bunun bilinçli bir uzlaşma
olduğunu söylüyor: *"ilişki modelinin nullable/absent bir durumu yok"*, bu yüzden
satır 0 skorla yazılıyor. §13.2 tam olarak o eksik durumu ekliyor — partner
artık **sonradan tanışılan** biri.

#### Durum makinesi (D71)

```sql
-- 017_relationship_scope.sql (aynı dosyada)
ALTER TABLE relationship ADD COLUMN state TEXT NOT NULL DEFAULT 'active';
-- 'absent' | 'courting' | 'active'
```

```
absent ──(aktivite olayı · §13.4 seçeneği)──► courting
courting ──(partner_01'de ilişkiyi kuran yaprak)──► active
courting ──(reddeden yaprak · skor 0)──► absent
active ──(skor 0)──► absent          kart listeden düşer
```

Diğer beş ilişkinin `state`'i **daima** `active`'dir (INV-59) — durum makinesi
yalnızca `kind='partner'` için çalışır. Bu bilinçli bir daraltma: "antrenörle
tanışmak" diye bir şey yok, antrenör kulüple birlikte gelir (§13.1).

Satır `absent` iken de **var olmaya devam eder**. `worlddata/relationships.py`'nin
"satır hep var, yoksa `get_score()` döneceği bir şey bulamaz" gerekçesi aynen
korunuyor; değişen tek şey satırın **listelenip listelenmediği**.

#### R1 davranışı

`state='absent'` bir ilişki **dönmez** (INV-58). Kart sayısı beş veya altıdır; FE
R1'i zaten dinamik çiziyor (`relationships_screen.dart`'ın `_toCardData()`'sı),
bu yüzden eksik kart bir kırılma değil.

`courting` bir ilişki **döner** ve yeni alanı taşır:

```jsonc
{ "relationship_id": "partner",
  "kind":            "partner",
  "category":        "Partner",
  "state":           "courting",        // YENİ · §13.2
  "score":           8,
  "person_name":     "Elif Demir",
  "contact_name":    "Elif",
  "last_contact_at": "2026-09-04",
  "has_pending_request": false,
  "traits":          { "met_on": "2026-09-02" } }
```

`state` **her** karta eklenir, yalnızca partnere değil — FE'nin bir alanın kime
uygulandığını `kind`'dan çıkarmak zorunda kalmaması için. Beş ilişki için değeri
hep `"active"`.

#### R3 davranışı — diyalog durumu değiştirebilir (D72)

`absent` bir ilişkiye `interact` çağrısı **hiçbir şey yazmadan** reddedilir:
`409 relationship_absent`. Kontrol, D42'nin yeterlilik kapısından da **önce**
yapılır — tanımadığın birine kibar olamazsın.

Yaprak tablosu (`catalog/dialogue.py`) opsiyonel bir anahtar kazanır:

```python
"partner_01": {
  # courting'deyken: ilişkiyi kuran yaprak
  "r0": {"relationship_delta": 4, "sets_state": "active",
         "requires": {"charisma": 6}, "costs": {"time": 60.0, "energy": 4.0}},
  "r1": {"relationship_delta": -3, "sets_state": "absent",
         "costs": {"time": 15.0, "energy": 1.0}},
}
```

`sets_state` **yalnızca `courting` durumundaki bir ilişkide** uygulanır; `active`
bir ilişkide sessizce yok sayılır. Böylece aynı ağaç iki fazda da kullanılabilir
ve bir yaprak yanlışlıkla kurulmuş bir ilişkiyi "yeniden kurmaz".

`sets_state` **`GET /catalog/dialogue`'da gönderilmez** — o uç `requires` ve
başka hiçbir şey servis ediyor (§5.7). Hangi cevabın ilişkiyi başlattığını
önceden bilmek konuşmanın kendisini bozardı.

R3 yanıtı yeni bir liste kazanır:

```jsonc
{ "career_state": { /* CareerState */ },
  "relationship_changes":       [ { "relationship_id": "partner", "before": 4, "after": 8, "delta": 4 } ],
  "relationship_state_changes": [ { "relationship_id": "partner",             // YENİ · §13.2
                                    "before": "courting", "after": "active" } ],
  "attribute_changes": [ … ],
  "condition_after":   null,
  "ledger_entries":    [] }
```

Liste boş dizidir, durum değişmediğinde `null` değil — `relationship_changes`'in
kendi kalıbı.

#### Ayrılma

`apply_delta()` bir `partner` satırının skorunu **0'a indirdiğinde** satır
otomatik `absent`'a düşer. Üç kaynak da aynı kapıdan geçtiği için ayrı bir kural
gerekmiyor: ilgisizlik (§3.4'ün `decay` tick'i), kötü diyalog seçimleri,
kaçırılan sosyal plan (§12.8). Geçiş `relationship_event`'e
`reason='partner_ended'` satırı düşürür ve o satır INV-15'in yeniden oynatma
testinde de görünür.

Ayrılmış bir partnerle **yeniden tanışmak** için yeni bir aktivite olayı gerekir;
kimlik (isim, yaş, meslek, bio) yeniden üretilir — dönen eski partner değil, yeni
biridir.

> **Neden tek yönlü değil:** tek yönlü bir makine (bir kez kuruldu mu kalıcı)
> test yüzeyini küçültürdü, ama skoru 0'a düşmüş bir partnerin kartta durmaya
> devam etmesi §3.4'ün `decay` mekanizmasını anlamsız kılardı — hiçbir şey
> kaybedilemeyen bir ilişkinin skoru bir kaynak değildir.

#### Onboarding

`worlddata/relationships.py` `partner` satırını yazmaya devam eder: skor
`STARTING_SCORES["partner"] = 0`, `state = 'absent'`. `family` **değişmez** —
skoru 0 ama `state = 'active'`; aileyi aramamış olmakla ailen olmaması aynı şey
değil.

---

### 13.3 Pasif nitelik bonusları

§12.12 dükkânın "sahip olmak mekaniğin tamamı" kuralını `daily_effects` ile
genişletmiş, ama pasif bir **nitelik** kavramını bilinçli olarak açmamıştı:
*"bir konsola ya da kramponlara uydurma bir mekanik eklemek onları vitrin metni
olarak dürüst bırakmaktan daha kötü olurdu."* §13.5 kişi antrenmanını kaldırınca
o boşluk gerçek bir soruya dönüşüyor: kibarlık nereden gelecek? Cevap şu:
**yaşadığın hayattan** — ne giydiğinden, nerede oturduğundan.

#### Şema değişikliği yok

Bonus türetilir: `inventory` satırları × `catalog/shop.py`. Saklanan hiçbir yeni
değer yok, bu yüzden migration da yok. Bu, D24/D25'in "saklanan değer + tek yazma
noktası" kalıbından **bilinçli bir ayrılıştır**: saklanan bir bonus, eşya elden
çıktığında (satış, D29 haczi) geri alınmak zorunda kalırdı ve o geri alma yolu
INV-22'yi ("hiçbir nitelik kendiliğinden azalmaz") ihlal eden tek yol olurdu.
Türetilmiş bonus o sorunu hiç doğurmaz.

#### Katalog — `passive_effects` (D73)

```python
{"catalog_id": "personal-suit", "title": "Takım elbise", "category": "personal",
 "price": 60, "note": "Ismarlama",
 "passive_effects": {"attribute:politeness": 2.0}}
```

`daily_effects`'ten **ayrı** bir harita, çünkü ikisi farklı şey yapıyor:

| | Ne yapar | Ne zaman |
|---|---|---|
| `daily_effects` (§12.12) | Bir değeri **yazar** (kondisyon, enerji, şöhret) | Gün döngüsünde, günde bir kez |
| `passive_effects` (§13.3) | Hiçbir şey yazmaz; **okuma anında** tabanın üstüne biner | Her okumada |

`catalog/__init__.py` yeni bir uzay ve doğrulayıcı kazanır:
`KNOWN_PASSIVE_EFFECT_KEYS` = `attribute:<kişi ailesi anahtarı>` (beş anahtar),
`validate_passive_effects()`. INV-28'in kalıbı: tanınmayan anahtar taşıyan kalem
import anında patlar.

Uzay bilinçli olarak **yalnızca kişi ailesi**. Bir kol saatinin şut isabetini
artırmasının hiçbir açıklaması yok; `saha` ailesi antrenmanla kazanılır ve
§13.5'ten sonra da öyle kalır.

#### Okuma yolu — `domain/attributes.py`

| Fonksiyon | Ne döner |
|---|---|
| `get_value()` | **taban** — bugünkü davranış, hiç değişmez |
| `passive_bonus(conn, career_id, key)` | sahip olunan eşyaların o anahtardaki toplamı — **YENİ** |
| `effective_value(conn, career_id, player_id, key)` | `clamp(0, 100, taban + bonus)` — **YENİ** |

`apply_delta()` **yalnızca tabana yazar** (INV-60). Bonus hiçbir zaman
kalıcılaşmaz; eşya elden çıkınca etki kendiliğinden geri gider ve taban değere
bir kez bile dokunulmamış olur.

#### Kilitler etkin değeri okur

`domain/requirements.py`'nin üç fonksiyonu da (`unmet()`, `met()`, `check()`)
`get_value` yerine `effective_value` kullanır. Maddenin asıl amacı budur: takım
elbise gerçekten kapıyı açar. Etkilenen bütün kapılar tek listede:

| Kapı | Nerede |
|---|---|
| Diyalog yaprağı | `catalog/dialogue.py` `requires` (D42) |
| Katalog kalemi | `catalog/lifestyle.py`, `catalog/training.py` `requires` |
| Sosyal teklif | `content/social_offers.py` |
| Sponsorluk | `content/sponsorships.py` |
| Aktivite olayı seçeneği | `content/activity_events.py` (§13.4) |

#### P1 yanıtı — `attributes[]` iki alan kazanır (D74)

```jsonc
{ "key": "politeness", "family": "kişi",
  "value":           58.0,   // taban — aktivite, diyalog, sosyal teklif bunu oynatır
  "passive_bonus":    2.0,   // YENİ · sahip olunan eşyalardan türetilmiş
  "effective_value": 60.0,   // YENİ · value + passive_bonus, 0-100'e sıkışmış
  "level":              6 }  // ANLAMI DEĞİŞTİ · floor(effective_value / 10)
```

`level`'ın etkin değerden türemesi **kırıcıdır ve bilinçlidir**. D43 bugün
`floor(value / 10)` diyor ve `level`'ın gönderilme sebebi olarak "FE o kuralı
kopyalamak zorunda kalmasın" gerekçesini veriyor. O gerekçe §13.3'ten sonra daha
da güçlü: FE artık kuralı kopyalayamaz bile, çünkü bonusu hesaplamak için envanteri
ve dükkân kataloğunu birleştirmesi gerekirdi. Kapıda sunucunun okuduğu sayı ile
ekranda kullanıcının gördüğü sayının **aynı** olması INV-61'in tek maddesi.

`value` ile `level` arasındaki `floor(value/10)` özdeşliği **kalkar**; D43'ün o
cümlesi §13.0'da geçersiz kılınanlar arasında.

#### Değişen diğer yanıtlar

`attribute_changes[]` satırları da `passive_bonus` taşır (T2, T4, R3, R5/R6, T6 ve
§12'nin sosyal uçları) — FE yerel kopyasını yeniden hesaplayabilsin diye.
`level_before`/`level_after` zaten var ve artık etkin değerden türüyor.

#### Ölçek ⟦AÇIK-16⟧

Hangi eşyanın hangi niteliğe kaç puan verdiği bu turda **yazılmıyor**; §13.3
mekanizmayı ve uzayı bağlar, sayıyı değil. İlk aday eşleştirme — **öneri,
bağlayıcı değil**:

| Kalem | Aday `passive_effects` | Vitrin metnindeki karşılığı |
|---|---|---|
| `personal-suit` | `attribute:politeness` | "Ismarlama" |
| `personal-watch` | `attribute:charisma` | "Röportajlarda ve sponsor çekimlerinde" (bugün `fame:overall`) |
| `personal-headphones` | `attribute:confidence` | "Gürültü engelleyici" |
| `home-console` | `attribute:resourcefulness` | "İki kollu" — soyunma odası dili |
| `estate-flat` · `estate-villa` | `attribute:confidence` | Oturduğun yer |

§12.12'nin kasıtlı olarak boş bıraktığı beş "vitrin" kalemi (`home-tv`,
`home-console`, `personal-boots`, `personal-suit`, `personal-headphones`) tam
olarak burada hayat buluyor — o bölümün "uydurma mekanik eklemektense dürüst
bırak" itirazı artık geçerli değil, çünkü ortada uydurma olmayan bir mekanik var.

---

### 13.4 Aktivite olayları

Yaşam aktiviteleri bugün atomik: `POST /actions` maliyeti düşer, etkiyi uygular,
biter. Bir akşam dışarı çıkmakla evde uyumak arasındaki tek fark bir sayı
tablosu. §13.4 aktiviteye **olay** ekliyor: kafede biri seni tanıyabilir,
konserde bir fotoğraf çekilebilir, ailen bir şey isteyebilir — ve bunların bir
kısmı karar ister.

#### Yazarlanma yeri — BE (D75)

Kalıp §5.4 R4'ün (sosyal teklif) aynısı: **BE'de yazarlanmış bir paragraf +
butonlar**, FE'de ağaç yok. R4'ün kendi gerekçesi burada da geçerli — dallanmayan
bir olayın metnini FE'de tutmak, yeni bir şablon eklemeyi iki depoda düzenleme
yapmaya çevirirdi. Diyalog **ağaçları** FE'de kalmaya devam ediyor (D23), çünkü
onların dallanması bir arayüz yapısıdır; bir aktivite olayı ise bir paragraf ve
iki-üç seçenektir.

`content/activity_events.py`, `content/social_offers.py`'nin ikizi:

```python
{"template_id": "kafe-taniyan-birisi",
 "catalog_ids": ["sos-kafe", "sos-arkadas"],       # hangi aktivitelerde çıkabilir
 "weight": 3,
 "requires": {},                                   # D42 · etkin seviyeden okunur (§13.3)
 "title": "Tanıdık bir yüz",
 "body":  "Yan masadaki biri seni tanıdı; geçen haftaki maçtan konuşuyor.",
 "options": [
   {"option_id": "masasina_git", "label": "Masasına git",
    "requires": {"confidence": 5},
    "costs":    {"time": 45.0, "energy": 5.0},
    "effects":  {"attribute:charisma": 0.4},
    "starts_relationship": "partner"},             # §13.2'nin courting kapısı
   {"option_id": "gulumse", "label": "Gülümseyip geç",
    "effects":  {"condition": 1}},
 ]}
```

`effects` uzayı T2'nin kendi uzayıdır (§5.7): `attribute:<key>` · `condition` ·
`energy` · `money` · `fame:<scope>` · `relationship:<rid>`. INV-28 aynı şekilde
import anında doğrular.

`starts_relationship` yalnızca `partner` değeri alabilir ve yalnızca ilişki
`absent` iken etkilidir; `courting` veya `active` bir partnerde sessizce yok
sayılır (§13.2). Bu, iki mekanizmanın tek bağlantı noktasıdır.

#### Havuz — her yaşam aktivitesi olay üretebilir

Hangi aktivitenin hangi olayı üretebileceği **şablon tarafında** (`catalog_ids`)
tanımlanır, katalog tarafında değil: bir şablon birden çok aktiviteye
bağlanabilsin ve yeni bir olay yazmak iki dosyaya dokunmasın diye. Katalog
kalemi yalnızca **sıklığı** taşır:

```jsonc
// GET /catalog/lifestyle
{ "catalog_id": "sos-konser", "title": "Konser", …,
  "event_chance": 0.35 }         // YENİ · §13.4 · yoksa ACTIVITY_EVENT_DEFAULT_CHANCE
```

"Aktivitenin türüne bağlı" tam olarak budur: ev aktivitelerinin havuzu dar ve
sıklığı düşük, sosyal aktivitelerinki geniş ve yüksek. `ev-uyku` ile
`sos-konser` aynı zardan geçmez. Varsayılan sıklık `api/config.py`'de
(`ACTIVITY_EVENT_DEFAULT_CHANCE`), tıpkı `SOCIAL_OFFER_DAILY_CHANCE` gibi.

#### Şema — `018_activity_events.sql`

```sql
CREATE TABLE activity_event (
  career_id     TEXT NOT NULL REFERENCES career(career_id) ON DELETE CASCADE,
  event_id      TEXT NOT NULL,              -- 'ae_' + 12 hex
  template_id   TEXT NOT NULL,
  catalog_id    TEXT NOT NULL,              -- olayı doğuran aktivite
  opened_on     TEXT NOT NULL,
  status        TEXT NOT NULL,              -- 'open' | 'resolved' | 'expired'
  chosen_option TEXT,
  resolved_on   TEXT,
  PRIMARY KEY (career_id, event_id)
);
```

Tablo zorunlu, çünkü olay T2 yanıtıyla doğar ama o yanıtta yaşayamaz: kullanıcı
uygulamayı kapatıp açabilir ve seçim sunucuda doğrulanmak zorundadır (ödül tablosu
BE'de kalır).

#### Akış

**1 · T2 olayı doğurur.** Aktivitenin **temel etkileri bugünkü gibi uygulanır** —
INV-3 bozulmaz, aktivite kendi başına tamamlanmış bir aksiyondur. Ardından zar
atılır; olay çıkarsa yanıta eklenir:

```jsonc
{ "career_state":    { /* CareerState */ },
  "applied_costs":   { "time": 60.0 },
  "applied_effects": { "condition": 1, "attribute:politeness": 0.1 },
  "attribute_changes":   [ … ],
  "tactic_changes":      [],
  "relationship_changes":[],
  "ledger_entries":      [ … ],

  "event": {                                    // YENİ · §13.4 · olay yoksa null
    "event_id":    "ae_7c31f0a99b2d",
    "template_id": "kafe-taniyan-birisi",
    "catalog_id":  "sos-kafe",
    "title":       "Tanıdık bir yüz",
    "body":        "Yan masadaki biri seni tanıdı; geçen haftaki maçtan konuşuyor.",
    "opened_on":   "2026-09-17",
    "status":      "open",
    "options": [
      { "option_id": "masasina_git", "label": "Masasına git",
        "requires": { "confidence": 5 }, "costs": { "time": 45.0, "energy": 5.0 } },
      { "option_id": "gulumse", "label": "Gülümseyip geç",
        "requires": {}, "costs": {} } ] } }
```

`options[].requires` ve `costs` **gönderilir** — oyuncu seçmeden önce kapıyı
görmeye hak kazanır (D42, R4'ün aynı kuralı). `effects` **gönderilmez**, aynı
gerekçeyle: ödül tablosu sunucuda kalır.

**2 · T5 · `GET /careers/{cid}/activity-events`** — açık olayı yeniden çeker.

```jsonc
{ "events": [ { /* T2'nin `event` bloğuyla aynı şekil */ } ] }
```

Açık olay yoksa boş dizi; hata değil. Uygulamayı kapatıp açan kullanıcı için tek
kurtarma yolu bu uçtur.

**3 · T6 · `POST /careers/{cid}/activity-events/{eid}/choose/{option_id}`** —
gövdesiz. Kontrol sırası T2'nin tablosunun aynısıdır:

| Sıra | Kontrol | Hata |
|---|---|---|
| 1 | Olay var mı | `404 activity_event_not_found` |
| 2 | Açık mı | `409 activity_event_not_open` |
| 3 | Seçenek o olaya ait mi | `422 invalid_request` |
| 4 | `requires` (etkin seviye, §13.3) | `409 requirement_not_met` |
| 5 | Bütçe | `409 insufficient_budget` |
| 6 | Bakiye | `409 insufficient_funds` |

Reddedilen bir seçim **hiçbir şey yazmaz** ve olay açık kalır — kullanıcı başka
bir seçenek seçebilir (INV-30'un kalıbı). Yanıt R3'ün şeklidir, artı çözümlenmiş
olay:

```jsonc
{ "career_state": { /* CareerState */ },
  "event": { "event_id": "ae_7c31f0a99b2d", "status": "resolved",
             "chosen_option": "masasina_git", "resolved_on": "2026-09-17",
             /* … T2'deki alanlar */ },
  "applied_costs":   { "time": 45.0, "energy": 5.0 },
  "applied_effects": { "attribute:charisma": 0.4 },
  "attribute_changes":         [ … ],
  "relationship_changes":      [ … ],
  "relationship_state_changes":[ { "relationship_id": "partner",
                                   "before": "absent", "after": "courting" } ],
  "ledger_entries":            [ … ] }
```

#### Gün akışı kilitlenmez (D76)

`POST /advance` açık bir aktivite olayı yüzünden **409 dönmez**. Geçilen günde
açık kalan olay `expired` olur ve **hiçbir etki yazmaz** (INV-63).

Bu, §12.8/§12.9'un sosyal plan ve çakışma kilitlerinden bilinçli bir ayrılıştır ve
gerekçesi kavramsal: bir plan bir **randevudur** — karşı taraf seni bekliyor,
gitmemek bir seçimdir ve bedeli vardır, o yüzden gün onsuz kapanamaz. Bir kafe
sohbeti ise o anın içinde yaşar; kaçırılmışsa kaçırılmıştır ve kimse gücenmez.
Üstelik kullanıcı olayın doğduğu anda **zaten aktivite ekranındadır**, yani
kilidin çözdüğü sorun (kullanıcı ekranı hiç görmeden günü kapatır) burada yok.

Yan fayda: `career_center_screen.dart`'ın 409 zinciri (§12.9'un sırası:
`season_rollover_required` → `sponsorship_obligation_pending` →
`social_conflict_pending` → `social_plan_pending` → `match_day_unplayed` →
`social_offer_pending`) hiç uzamıyor. O zincir her yeni halkada bir sıralama
kararı isteyen türden bir yer.

#### Aynı anda tek olay (INV-62)

Açık bir olay varken yeni bir olay **üretilmez** — INV-39'un (aynı anda en fazla
bir açık sosyal teklif) ikizi. Zar atılmadan önce açık olay sorgulanır; varsa T2
`event: null` döner ve aktivite normal şekilde tamamlanır.

---

### 13.5 İki antrenman ailesi

Antrenman ekranı üç aileye ayrılmıştı: `saha` (7 kalem, hepsi mini-oyunlu),
`kişi` (5 kalem, hepsi `drill: null` ve FE'de "Yakında"), `taktik` (3 kalem,
§12.11, doğrudan uygulanıyor). §13.5 bunu ikiye indiriyor: **fiziksel ve
taktiksel**.

#### Silinenler (D77)

`catalog/training.py`'den beş `kişi` kalemi **tamamen kalkar**:
`medya-egitimi`, `gorgu-dersleri`, `ozguven-koclugu`, `satranc-kulubu`,
`kriz-simulasyonu`. Katalog 15 → **10 kalem** (7 `saha` + 3 `taktik`).

`TRAINING_FAMILIES = ("saha", "taktik")` yeni bir sabit olarak `api/config.py`'ye
girer ve `validate_catalog()` `kişi` ailesi taşıyan bir antrenman kalemini import
anında reddeder (INV-64) — INV-28'in kalıbı.

**`ATTRIBUTE_KEYS`'in `kişi` ailesi kalır.** Beş nitelik, radar ekseni
([`relationships_radar_screen.dart:15-19`](../lib/screens/relationships_radar_screen.dart))
ve bütün `requires` kapıları olduğu gibi durur. Kalkan şey niteliğin **antrenman
yolu**dur, kendisi değil. INV-21 hiç değişmez.

Beşi bir arada gitmesinin gerekçesi: ikisi kalsaydı sekme de kalırdı ve "iki
antrenman türü" kararı uygulanmamış olurdu. Kısmi silme, ekranı boş bir sekmeyle
bırakmaktan daha kötü bir sonuç verirdi — bugünkü hâlin ta kendisi o.

#### `drill: null` artık tek anlama gelir

§12.11 iki anlam taşıyordu: `kişi` kaleminde "Yakında" (tıklanamaz), `taktik`
kaleminde "doğrudan uygula". Kişi kalemleri gidince ikinci anlam tek anlam olur.
FE'de `'Yakında'` dalı ve onun disabled buton yolu ölür
([`training_screen.dart:353-361`](../lib/screens/training_screen.dart)).

#### Kişi nitelikleri bundan sonra nereden gelişir (D78)

Dört kaynak; üçü bugün zaten çalışıyor, dördüncüsü §13.3 ile geliyor:

| Kaynak | Nerede | Bugünkü örnek |
|---|---|---|
| Yaşam aktiviteleri | `catalog/lifestyle.py` | `sos-arkadas` +0.3 `charisma`, `sos-konser` +0.4 `confidence` |
| Sosyal teklifler | `content/social_offers.py` | `media_interview_request` |
| Diyalog sonuçları | `catalog/dialogue.py` | `media_01:r0` +0.2 `charisma` |
| **Aktivite olayları** | `content/activity_events.py` (§13.4) | `masasina_git` +0.4 `charisma` |
| **Pasif eşya bonusu** | `catalog/shop.py` (§13.3) | takım elbise +2 `politeness` |

Kavramsal olarak bu, kararın asıl gerekçesi: kişi nitelikleri **yaşayarak**
gelişir, salonda değil. Bir spor kulübünde "kibarlık antrenmanı" diye bir şey
yok; kibarlık ailene daha sık uğramaktan, doğru röportajı vermekten ve doğru
takımı giymekten gelir.

#### ⟦AÇIK-17⟧ — eşiklerin yeniden dengelenmesi

D42'nin kilit zinciri şuydu: `ozguven-koclugu` → özgüven 6 → `medya-egitimi` →
cazibe 8 → `media_01:r0`. İlk iki halka siliniyor.

Taze bir kariyer `charisma` 74 (seviye 7) ile başlıyor
([`worlddata/attributes.py:49-53`](worlddata/attributes.py)) ve `media_01:r0`
seviye 8 istiyor. Kalan kaynaklarla (aktivite başına +0.1…+0.5, pasif bonus +2)
o eşiğin **makul sürede** açıldığı sayıyla gösterilmeli; aynı kontrol beş kişi
niteliğinin hepsi için gerekiyor, özellikle `resourcefulness` (29 → seviye 2) ve
`confidence` (51 → seviye 5) için.

Bu bir **sayı** işidir, şema işi değil: eşik değerleri `catalog/dialogue.py` ve
`content/*.py`'de, pasif bonus ölçeği ⟦AÇIK-16⟧'da. §10'un kuralı gereği ikisi de
**sürüm numarasını değiştirmez**.

---

### 13.6 Mevcut uçlardaki değişiklikler (FE'yi ilgilendiren kısım)

§11.8'in aynı tablosu: §13'ün imzalı uçlarda ne değiştirdiği, tek yerde.

| Uç | Değişiklik | Kırıcı mı |
|---|---|---|
| §5.4 R1/R2 | Her karta `state` eklenir; `absent` bir ilişki **listelenmez** | Hayır — FE listeyi dinamik çiziyor, alan eklemek §5.0'ın kuralı |
| §5.4 R3 | Yanıta `relationship_state_changes[]` eklenir; `absent` ilişkide `409 relationship_absent` | Hayır — yeni alan, yeni hata yolu |
| §5.2 P1 | `attributes[]`'a `passive_bonus` ve `effective_value` eklenir; **`level`'ın anlamı değişir** (D74) | **Evet** — `level` artık `floor(value/10)` değil |
| §5.5 T2 | Yanıta opsiyonel `event` bloğu eklenir (olay yoksa `null`) | Hayır — FE tanımadığı alanı yok sayar |
| §5.5 T2 | Yanıta `relationship_state_changes[]` eklenir | Hayır — bir `relationship:` etkisi partneri 0'a düşürüp ilişkiyi bitirebiliyor; onsuz kart bir sonraki R1'de sessizce kaybolurdu |
| §5.5 T2/T4 ve §12'nin sosyal uçları | `attribute_changes[]` satırları `passive_bonus` taşır | Hayır |
| §5.7 N3 `training` | 15 → **10 kalem**; `kişi` ailesi hiç dönmez | **Evet** — FE'nin üçüncü sekmesi boşalır (§13.11) |
| §5.7 N3 `lifestyle` | Kalemler `event_chance` taşıyabilir | Hayır |
| §5.7 N3 `shop` | Kalemler `passive_effects` taşıyabilir | Hayır |
| §5.7 N3 `dialogue` | Değişmez — `sets_state` **gönderilmez** (§13.2) | Hayır |
| §11.7 S4 | Yanıta `relationships_reset[]` eklenir | Hayır — ama FE'nin R1'i yeniden çekmesi gerekir (§13.11) |
| §4 tablosu | **T5**, **T6** eklenir | Hayır |

> ⚠️ **§4'ün tablosu zaten geride.** §11.8 "S1–S4 eklenir" demişti ama tablo
> düzenlenmedi; §12'nin sosyal plan (§12.8) ve çakışma (§12.9) uçları da tabloda
> yok. §13 T5/T6'yı tabloya ekliyor ama eksik satırları tamamlamıyor — o ayrı bir
> düzeltme ve bu bölümün kapsamı değil. Uçların doğruluk kaynağı daima kendi
> şartname bölümüdür (§5, §11.5-11.7, §12.1-12.9, §13.4).

#### Yeni uçlar

| # | Metot | Yol | Ne yapar |
|---|---|---|---|
| T5 | `GET` | `/careers/{cid}/activity-events` | Açık aktivite olayını çeker (§13.4) |
| T6 | `POST` | `/careers/{cid}/activity-events/{eid}/choose/{option_id}` | Seçeneği uygular |

İkisi de **Zaman** ailesinde, çünkü olay bir aktivitenin (T2) devamı ve günün
bütçesinden yiyor — sosyal teklifin (R4-R6) ilişki ailesinde durmasıyla aynı
mantık, farklı kök.

**Durumu değiştiren her uç** kuralına (D28, INV-18) **T6** da dahildir: yanıtı
tam `CareerState` bloğunu taşır.

#### Uygulamada çıkan tek ek karar

`relationship_state_changes` **tek bir yazma yolundan değil, bir fark'tan**
üretiliyor: çağıran taraf yazmadan önce `relationships.state_snapshot()`
alıyor, yazdıktan sonra `state_diff()` ile karşılaştırıyor.

Gerekçe uygulama sırasında ortaya çıktı: tek bir R3 çağrısı durumu **iki ayrı
yoldan** oynatabiliyor — yaprağın `sets_state`'i, ve `apply_delta`'nın skoru
0'a düşürüp partneri kendiliğinden bitirmesi (§13.2). Her yolun kendi kaydını
raporladığı bir tasarımda flörtü reddeden yaprak (`c1`, delta −4, skor zaten
0) ilişkiyi `absent` yapıyor ama **hiçbir şey raporlamıyordu**: `sets_state`
sırası geldiğinde durum çoktan değişmiş oluyor ve no-op'a düşüyordu. Fark
almak FE'nin sorduğu tek soruyu soruyor: bu kişi listemde şimdi var mı, önce
var mıydı?

### 13.7 Yeni kararlar

On birinci turda (ilişki ömrü, pasif faydalar, aktivite olayları) alınanlar:

| # | Konu | Karar | Gerekçe |
|---|---|---|---|
| D68 | İlişkinin kapsamı | **Altı sabit `relationship_id` korunur; kapsam `scope`/`team_id` kolonlarında taşınır** | Kimliğe kulüp eklemek (`coach@t_ykz`) FE'de beş ayrı sabit tabloyu birden düşürürdü: portre hash'i, sunum tablosu, diyalog ağaçları, maç sonrası çubuk sırası, teklif kapanış cümlesi. Kimlik FE'de bir **sunum anahtarı**; kapsam ise bir veri sorusu ve veri sorusu kolona yazılır |
| D69 | Transferde ne sıfırlanır | **Skor + `traits` + kimlik — üçü birlikte** | İkisi tek başına tutarsız bir dünya bırakıyor: yalnızca skor sıfırlanırsa antrenörün güveni (§12.2'nin ağırlığının %35'i) eski kulüpten taşınır; kimlik kalırsa aynı antrenör yeni kulüpte seni tanımadan bekliyor olur |
| D70 | Yeni kulübün kimliği nereden gelir | **`worlddata/relationships.CLUB_STAFF` havuzu; havuzda satırı olmayan takım için `career.seed` + `team_id`'den deterministik seçim** | Otuz iki takımın hepsine elle antrenör yazmak bugünün işi değil, ama INV-7 (aynı seed → aynı dünya) rastgele bir isimle bozulur. Seed'li türetme ikisini birden karşılar: havuz dolduğu ölçüde elle yazılmış isim kazanır, dolmadığı yerde dünya yine tekrar edilebilir kalır |
| D71 | Partner ilişkisinin durumu | **`state` kolonu: `absent` → `courting` → `active` → `absent`; yalnızca `kind='partner'` için** | Satırı silmek `get_score()`'un dönecek bir şey bulamaması demekti (`worlddata/relationships.py`'nin kendi gerekçesi). Durum kolonu satırı yerinde bırakıp yalnızca **listelenmesini** kapatıyor. Makinenin diğer beş ilişkiye açılmaması bilinçli: antrenörle "tanışmak" diye bir şey yok, o kulüple gelir (§13.1) |
| D72 | İlişkiyi diyalog mu kurar | **Evet — yaprak `sets_state` taşır, ama yalnızca `courting` durumunda uygulanır** | İlişkinin başlaması bir **karardır**, bir eşik değil: skor 40'a ulaşınca kendiliğinden partner olmak, oyuncunun hiç vermediği bir kararı onun adına vermek olurdu. `active` durumda yok sayılması, aynı ağacın iki fazda da kullanılabilmesini sağlıyor |
| D73 | Eşyanın nitelik etkisi | **Sahipken pasif bonus — saklanmaz, okuma anında türetilir** | Saklanan bir bonus, eşya elden çıktığında (satış, D29 haczi) geri alınmak zorunda kalırdı; o geri alma INV-22'yi ("hiçbir nitelik kendiliğinden azalmaz") ihlal eden **tek** yol olurdu. Türetilmiş bonus o sorunu hiç doğurmaz ve şema değişikliği de istemez |
| D74 | `level` hangi değerden türer | **`effective_value`'dan (taban + pasif bonus)** | D43 `level`'ı "FE kuralı kopyalamak zorunda kalmasın" diye gönderiyordu; §13.3'ten sonra FE kuralı kopyalayamaz bile — bonusu hesaplamak için envanteri ve dükkân kataloğunu birleştirmesi gerekirdi. Kapıda sunucunun okuduğu sayı ile ekranda kullanıcının gördüğü sayının aynı olması bu maddenin tek şartı |
| D75 | Aktivite olayının metni nerede yazarlanır | **BE'de (`content/activity_events.py`), R4'ün sosyal teklifiyle aynı kalıpta** | Dallanmayan bir olayın metnini FE'de tutmak, yeni bir şablon eklemeyi iki depoda düzenleme yapmaya çevirirdi (§5.4 R4'ün kendi gerekçesi). Diyalog **ağaçları** FE'de kalmaya devam ediyor (D23): onların dallanması bir arayüz yapısı, bir aktivite olayı ise bir paragraf ve iki-üç seçenek |
| D76 | Çözülmemiş olay günü kilitler mi | **Hayır — `advance` sırasında `expired` olur, hiçbir etki yazmaz** | Sosyal plan bir **randevudur**: karşı taraf seni bekliyor, gitmemek bir seçim ve bedeli var, o yüzden gün onsuz kapanamaz (§12.8). Bir kafe sohbeti o anın içinde yaşar. Üstelik kullanıcı olayın doğduğu anda zaten aktivite ekranında — kilidin çözdüğü sorun burada yok. Yan fayda: `career_center_screen.dart`'ın altı halkalı 409 zinciri hiç uzamıyor |
| D77 | Antrenman aileleri | **İkiye iner: `saha` · `taktik`; beş `kişi` kalemi tamamen silinir** | Kısmi silme ekranı boş bir sekmeyle bırakırdı — bugünkü hâlin ta kendisi (`kişi` kalemlerinin beşi de `drill: null` ve "Yakında"). `ATTRIBUTE_KEYS`'in `kişi` ailesi kalıyor: kalkan nitelik değil, niteliğin antrenman yolu |
| D78 | Kişi niteliklerinin yeni kaynakları | **Yaşam aktiviteleri + sosyal teklifler + diyalog + aktivite olayları + pasif eşya bonusu** | Beşinin de bugün ya çalışan ya §13'le gelen bir yolu var, yani boşluk kapalı. Kavramsal gerekçe D77'nin kendisi: bir spor kulübünde "kibarlık antrenmanı" yok — kibarlık ailene uğramaktan, doğru röportajdan ve doğru takımı giymekten gelir |

### 13.8 Yeni invariant'lar

| # | Garanti |
|---|---|
| INV-56 | `scope='club'` olan her ilişkinin `team_id`'si daima `player.team_id`'ye eşittir; S4 ikisini aynı transaction'da günceller |
| INV-57 | Kulüp kapsamlı sıfırlama **daima** `relationships.apply_delta()` ve `apply_trait_delta()` üzerinden yazılır; olay günlüğü baştan oynatıldığında skor yine tutar (INV-15 ve INV-42 korunur) |
| INV-58 | `state='absent'` bir ilişki R1/R2'de **dönmez** ve R3 onu `409 relationship_absent` ile, hiçbir şey yazmadan reddeder |
| INV-59 | `kind != 'partner'` olan her ilişkinin `state`'i daima `'active'`'tir; durum makinesi yalnızca partner için çalışır |
| INV-60 | `player_attribute.value`'ye pasif bonus **asla** yazılmaz — `apply_delta()` yalnızca tabana yazar, bonus her okumada yeniden türetilir |
| INV-61 | `requires` kontrolü ve P1'in `level`'ı **daima** `effective_value`'dan türer: kapıda sunucunun okuduğu sayı ile ekranda kullanıcının gördüğü sayı aynıdır |
| INV-62 | Bir kariyerde aynı anda en fazla **bir** `status='open'` aktivite olayı bulunur (INV-39'un ikizi) |
| INV-63 | `advance` sırasında açık kalan aktivite olayı `expired` olur ve hiçbir etki, maliyet veya defter satırı yazmaz |
| INV-64 | Antrenman kataloğundaki her kalemin `family`'si `TRAINING_FAMILIES`'dendir; `kişi` taşıyan bir kalem yüklenmez (INV-28'in kalıbı, import anında) |

### 13.9 Yeni hata kodları

| HTTP | `code` | Ne zaman |
|---|---|---|
| 409 | `relationship_absent` | R3 `state='absent'` bir ilişkiye çağrıldı — kontrol D42'nin yeterlilik kapısından da önce yapılır |
| 404 | `activity_event_not_found` | Bilinmeyen `event_id` |
| 409 | `activity_event_not_open` | Olay zaten çözülmüş ya da `expired` |

`requirement_not_met`, `insufficient_budget`, `insufficient_funds` T6'da da aynen
kullanılır — yeni kod gerekmiyor, sıra T2'nin tablosunun aynısı (§13.4).

### 13.10 Yeni açık maddeler

| İşaret | Bölüm | Ne dolacak |
|---|---|---|
| ⟦AÇIK-16⟧ | §13.3 `passive_effects` | Hangi eşyanın hangi kişi niteliğine kaç puan verdiği. §13.3'ün tablosu **öneridir, bağlayıcı değildir** |
| ⟦AÇIK-17⟧ | §13.5 · `catalog/dialogue.py` `requires` | Kişi antrenmanı kalkınca eşiklerin yeniden dengelenmesi — `media_01:r0`'ın cazibe 8'i kalan kaynaklarla makul sürede açılmalı |
| ⟦AÇIK-18⟧ | §13.2 `courting` | Tanışma ile ilişkinin kurulması arasında kaç adım olacağı ve ayrılmış bir partnerle yeniden tanışma sıklığı. v1: tek adım (tanışma olayı → `partner_01`), yeniden tanışma normal olay havuzundan |

Üçü de §10'un kuralına tabidir: **şemayı, uç listesini ve yanıt gövdelerinin
şeklini bağlamazlar**; dolan yalnızca değerdir ve dolmaları sürüm numarasını
değiştirmez.

### 13.11 FE'de kırılan noktalar

§13 bunları çözmez, **adlandırır** — imza sonrası iş listesinin kendisidir.

| Dosya | Ne olacak | Kırıcı mı |
|---|---|---|
| [`training_screen.dart`](../lib/screens/training_screen.dart) | `_TrainingTab.personal` ve `'Yakında'` dalı silinir; üç segmentli pill ikiye iner (`segmentCount`, `segmentWidth`) | **Evet** — sekme ve buton durumu |
| [`player_state.dart`](../lib/state/player_state.dart) | `attributeLevel` artık `effective_value`'dan gelen `level`'ı okur; `passive_bonus` yerel kopyada tutulur | **Evet** — kilit karşılaştırmasının kaynağı |
| [`shop_screen.dart`](../lib/screens/shop_screen.dart) | `passive_effects` için ikinci bir fayda rozeti (`_benefitLabelFor`'un yanına). `upkeep_weekly` hâlâ hiç gösterilmiyor — **mevcut açık**, §13 kapsamı dışında | Hayır — ek rozet |
| [`lifestyle_screen.dart`](../lib/screens/lifestyle_screen.dart) | T2 yanıtındaki `event` bloğunu açan yol; ayrıca detay rozetleri bugün `attribute:*` / `relationship:*` / `fame:*` etkilerini hiç göstermiyor — **mevcut açık**, §13.3'ten sonra daha görünür | Hayır — ek yol |
| **yeni ekran** | Aktivite olayı ekranı — [`social_offer_screen.dart`](../lib/screens/social_offer_screen.dart)'ın ikizi: aynı `DeltaRow`, aynı maliyet çipleri, aynı kapanış kalıbı. Tek fark: iki buton değil, N seçenek ve kilitli seçenek gri görünür ([`dialog_screen.dart`](../lib/screens/dialog_screen.dart)'ın `locked_choice_*` kalıbı) | — |
| [`relationships_screen.dart`](../lib/screens/relationships_screen.dart) | Beş **veya** altı kart; `partner_01` ağacına ilişkiyi kuran ve reddeden yapraklar; `courting` durumunun kart üstünde bir işareti | Hayır — liste zaten dinamik |
| [`transfer_offers_screen.dart`](../lib/screens/transfer_offers_screen.dart) | S4'ten sonra R1 yeniden çekilmeli; `relationships_reset[]` kullanıcıya gösterilmeli | **Evet** — bugün hiç çekilmiyor |
| [`career_models.dart`](../lib/net/career_models.dart) | `RelationshipCard.state`, `AttributeChange.passiveBonus`, `PlayerAttribute.effectiveValue`, `ActionResult.event`, `ActivityEvent`/`ActivityEventOption`/`ActivityEventResult`, `TransferAcceptResult.relationshipsReset`, `InteractResult.relationshipStateChanges` | — |
| [`career_api_client.dart`](../lib/net/career_api_client.dart) | T5 `activityEvents()`, T6 `chooseActivityEvent()` | — |

**Bitişik mevcut açık:** `fans` kartının diyalog ağacı yok
([`relationship_presentation.dart`](../lib/widgets/relationship_presentation.dart)'ta
`dialogueId: ''`), bu yüzden "ARA" düğmesi sessiz bir no-op. §13.1 `fans`'ı kulüp
kapsamına aldığı için bu açık artık daha görünür — sıfırlanan bir ilişkiyi
konuşarak geri kazanamıyorsun. Çözümü §13'ün kapsamında değil (bir diyalog ağacı
yazılması gerekiyor, D23 gereği FE'de), ama imza sonrası iş listesine dahil.

### 13.12 Bu sürümün dışında kalanlar

| Konu | Neden dışarıda |
|---|---|
| NPC transferi, kadro derinliği | D4 korunuyor; §11.7'nin kendi sınırı |
| Partnerle evlilik, çocuk, ortak yaşam maliyeti | Durum makinesi üç durumla sınırlı tutuldu; dördüncü bir durum kendi ekonomisini ister |
| Kiralık (loan) transferi | `player.team_id` değişimi tek tetikleyici (D69); kiralık iki kulüplü bir kavram ve §11.7'de karşılığı yok |
| Kulüp bazlı **medya** ilişkisi | Medya ülke basınıdır, kulübün değil; §3.4'ün `outlet` trait'i tek bir kuruma bağlı |
| Aktivite olaylarının zincirlenmesi (bir olayın başka bir olayı doğurması) | v1'de tek adım; zincir §12.8'in `plan_days_ahead` kalıbını ister ve o kalıp gün kilidiyle geliyor (D76 onu reddetti) |
| Pasif bonusun `saha` ailesine açılması | Bir kol saatinin şut isabetini artırmasının açıklaması yok; `saha` antrenmanla kazanılır ve §13.5'ten sonra da öyle kalır |

---

## 14. EK: SOSYAL SKILL'LER, AKTİVİTE/İTEM/KONUT GENİŞLEMESİ

`sosyal-sistem-tasarim-dokumani.md`'nin uygulanması. §11, §12 ve §13 gibi imza
sonrası eklenmiştir; yalnızca kendi "Geçersiz kılananlar" tablosundakileri
geçersiz kılar. §14.1 (skill'ler) uygulanmıştır; §14.2–§14.6 **kararları**
kaydeder; §14.2–§14.6'nın hepsi uygulanmıştır, §14.7 bağlam etkilerini (uygulandı) ve bilinen eksikleri taşır — her alt
bölüm kendi fazıyla ayrıntılanır ve o fazın commit'inde "planlanan" etiketi kalkar.

### 14.0 Geçersiz kılananlar

| Eski hüküm | Nerede | Yeni durum |
|---|---|---|
| "hız, top kontrolü, **cesaret** gibi nitelikler yoktur" | D30, §3.2 | `courage` (Cesaret) artık bir niteliktir; `kişi` ailesinin üçüncü anahtarıdır |
| `politeness` · `confidence` · `resourcefulness` anahtarları ve Kibarlık · Özgüven · Beceriklilik etiketleri | §3.2 tablosu, §5, §13.3 | `empathy` (Empati) · `courage` (Cesaret) · `discipline` (Disiplin); §14.1 |
| Günlük kondisyon toparlanması `5 + eşya bonusu`, tavan 12 (INV-41) | §6.6, §12 | **Uygulandı (§14.4):** aktif konutun uykusu doğal +5'in yerini alır; tavan `MAX_CONDITION_RECOVERY_PER_DAY` = 20. INV-41'in *kuralı* (toparlanma bir tavanla kesilir) geçerlidir, yalnız sayı değişti |
| Aktivite olaylarının zincirlenmesi kapsam dışı | §13.12 | **Uygulandı (§14.6):** ertelenmiş sonuç tablosu zincire izin verir |
| Cevapsız kalan olay hiçbir etki yazmaz | INV-63 | **Uygulandı (§14.5):** kural olduğu gibi kalır, tek istisnayla — bir şablon `on_ignore` taşıyorsa görmezden gelmenin bedeli yazılır (annenin doğum gününü unutmak da bir seçimdir) |
| Kaynağı yalnız bir yaşam aktivitesi olan olay (`catalog_id` hep bir aktivite) | §13.4 | **Uygulandı (§14.5):** tetikleyiciden doğan olayın `catalog_id`'si `trigger:<tür>`'dür; aynı T5/T6 yolundan cevaplanır |
| `estate-*` mağaza itemleri (`realEstate` kategorisi) | §12.13, §13.3 | **Uygulandı (§14.4):** mağazadan kalktı (43 kalem), konut sistemine geçti; alan kariyerler tam iade alır (`legacy_items.reconcile`) |
| Haftalık `upkeep` ile ödenen gayrimenkul (D27) | §6.5 | **Uygulandı (§14.4):** konut `upkeep` değil aylık kira ya da bir kerelik satın alma ile ödenir; `upkeep` artık yalnız iki abonelik gear'ında (fotoğrafçı, medya ekibi) kalır |
| `inventory`'deki her satırın pasif bonus vermesi (§13.3) ve `personal-*` / `home-*` katalog kalemleri | §12.13, §13.3, INV-60 | **Uygulandı (§14.2):** yuvası olan satırlardan yalnız `equipped` olanlar sayılır; yuvasız satırlar (gayrimenkul, yatırım) eskisi gibi her zaman sayılır. Eski sekiz kalem katalogdan kalktı |

**Dokunulmayanlar** (yeni sistemler bunlara uymak zorundadır): INV-39 ve INV-62
(aynı anda tek açık teklif / tek açık aktivite olayı), D4 (ilişki listesi yok,
altı sabit tür), D29 (ödenemeyen `upkeep` → %50 iade), INV-3 (tek işlem),
INV-28 (bilinmeyen katalog anahtarı süreç başında patlar).

§1–§13'teki metin, örnek JSON ve tablolar eski adlarla **olduğu gibi kalır**;
okurken §14.1'deki eşleme uygulanır.

### 14.1 Beş sosyal skill (D79)

**D79.** `kişi` ailesi, tasarım dokümanının beş sosyal skill'idir. Anahtar
kümesi 12'de kalır (INV-21); yalnızca üç anahtar adını değiştirir, iki anahtar
(`charisma`, `intelligence`) aynı kalır:

| Eski anahtar | Yeni anahtar | Etiket |
|---|---|---|
| `charisma` | `charisma` | Karizma |
| `politeness` | `empathy` | Empati |
| `confidence` | `courage` | Cesaret |
| `intelligence` | `intelligence` | Zeka |
| `resourcefulness` | `discipline` | Disiplin |

- Başlangıç değerleri, seviye hesabı (`floor(değer/10)`), `requires` eşikleri ve
  pasif bonuslar **değişmez**: her eski eşik yeni adıyla aynı seviyeyi okur.
  Eşikler bilinçli olarak yeniden kalibre edilmemiştir; dokümanın yeni
  gate'leri (Empati ≥2 gibi) 0–10 ölçeğine çevrilerek kendi fazlarında yazılır.
- Kalıcı veride anahtar yalnızca `player_attribute.attribute_key`'de saklanır;
  `db/migrations/019_social_skill_keys.sql` mevcut kariyerlerdeki satırları
  yeniden adlandırır.
- **INV-65.** `ATTRIBUTE_KEYS` hâlâ kapalı 12'li kümedir ve `kişi` ailesi tam
  olarak `charisma`, `empathy`, `courage`, `intelligence`, `discipline`'dir.

### 14.2 İtemler: equip, derece, kazanılan itemler

- **D80.** `inventory`'ye `slot`, `grade` (1–5) ve `equipped` eklenir
  (`db/migrations/020_item_equip.sql`). `slot` ve `grade` alım anında katalogdan
  kopyalanıp **dondurulur** (`price_paid` ile aynı gerekçe). Bir satır, `slot`'u
  NULL ise (gayrimenkul, yatırım, 020'den önceki her satır) ya da kendi yuvasının
  `equipped` satırıysa **sayılır** (pasif + günlük etkiler). Tek okuyucu
  `domain/inventory.py::contributing_ids()`; nitelikler, kondisyon ve gün döngüsü
  `inventory` tablosunu kendileri okumaz. `upkeep` ise **her** sahip olunan
  satırdan ödenir: giyilmemiş bir palto da para tutar — aksi halde equip,
  ücretsiz satış olurdu.
- **Yuva ve kategori.** Doküman "aynı kategoriden tek item" diyor ama
  "Aksesuar"da saat, kolye ve cüzdan birlikte giyilebilmeli ("iki saat
  takılamaz"). Bu yüzden *kategori* yalnız mağaza gruplamasıdır (`clothing`,
  `accessory`, `tech`, `vehicle`, `living`, `special`); *yuva* (`shoes`, `top`,
  `outerwear`, `formal`, `watch`, `ring`, `vehicle`, `cinema`…) ince tanedir ve
  yuva başına tek aktif satır vardır. 40 giyilebilir kalem 28 yuvaya dağılır.
- **Derece → karizma.** Derece-N kalem pasif olarak `charisma`'ya
  `N × 0.5` ekler (`CHARISMA_PER_GRADE`). Dokümanın yan etkileri küçük ek pasifler
  olur: akıllı saat `discipline` +0.5, sanat eseri `intelligence` +0.5, vakıf
  `empathy` +1.5. Ölçek ⟦AÇIK-16⟧'nın (pasif bonus ölçeği) parçasıdır.
  Fiyatlar dereceyle büyür ve başlangıç maaşına (haftada 40) göre yazılmıştır:
  derece-1 birkaç haftalık maaş, derece-5 bir sezonun çoğu.
- **Satın alma ve giyme.** T4 yuva boşsa kalemi alır almaz giydirir; yuva
  doluysa kalem dolapta kalır (oyuncunun seçtiğini sessizce değiştirmemek için).
  `GET /careers/{cid}/inventory` envanteri listeler (daha önce böyle bir uç
  yoktu). `POST …/inventory/{id}/equip` ve `…/unequip` yuvayı devreder ya da
  boşaltır; tam `CareerState` döner (D28/INV-18), ayrıca `items`, kişi
  niteliklerinin yeni `passive_bonus`'u ve `condition_recovery`. Hatalar:
  `item_not_owned` (404), `item_not_equippable` (409, yuvasız kalem),
  `item_not_for_sale` (409).
- **D81.** Dokümanın §3.5'teki "Şehir manzaralı loft" (#36) ve "Deniz manzaralı
  villa" (#37) kalemleri **item olarak yoktur**: §4'te aynı adlarla gayrimenkul
  (#10, #13) oldukları için iki kez satın alınırlardı. Karizmaları konutun
  derecesi olarak §14.4'te aktif konuttan gelir. Mağaza 46 kalemdir: 40 gear, 3
  gayrimenkul, 3 yatırım. Eski `personal-*` / `home-*` sekiz kalem katalogdan
  kalktı; alan kariyerler `domain/legacy_items.py::reconcile()` ile açılışta
  çözülür (INV-17 gereği para hareketi SQL'de değil `wallet.apply()` ile
  olduğundan migration değil, başlangıç adımıdır; idempotent):

  | Eski kalem | Sonuç |
  |---|---|
  | `personal-watch` · `personal-suit` · `personal-headphones` · `home-tv` · `home-espresso` | En yakın yeni kaleme taşınır (`acc-smart-watch` · `cloth-tailored-suit` · `tech-earbuds` · `home-cinema` · `home-coffee-machine`), `price_paid` korunur, giydirilir |
  | `personal-boots` · `home-console` · `home-treadmill` | `price_paid` kadar tam iade (`money_ledger.kind = 'refund'`); koşu bandının işi §14.4'ün ev spor salonuna kalır |

  Günlük şöhret (+0.3) İsviçre saatine, günlük enerji (+3) kahve makinesine geçti.
- **D82.** Yeni `grant_item:<catalog_id>` effect anahtarı (değer 1) satın
  alınamayan kalemleri verir: #38 imzalı forma, #39 ilk gol topu, #40 krampon
  serisi, #42 hayır vakfı (`acquire: "grant"`, fiyat 0, satılamaz). Aynı
  dağıtım döngüsünün üç kopyasında çalışır (T2, T6, sosyal kabul/katılım); zaten
  sahip olunan kalem ikinci kez verilmez ve hata vermez. T2 ve T6 yanıtlarında `granted_items[]` döner (sosyal yanıtlar bunu
  henüz taşımaz). **Bu fazda hiçbir şablon bir kalem vermez**:
  kaynaklar sonraki fazlarla bağlanır (olay seçenekleri §14.5–§14.6, krampon
  serisi sponsorluk anlaşmasıyla, ilk gol topu maç sonrası tetikleyiciyle). #41
  lüks kulüp kartı satın alınır (derece 4).
- **Bağlam notları.** Dokümanın bağlam notlarının bir kısmı §14.7'de mekaniğe
  döndü (palto, spor araba, kamera ekibi, kanal, süper araba); kalanı hâlâ yalnız
  `note` metnidir ve §14.7'de listelidir.
- **INV-66.** Bir kariyerde aynı yuvada birden fazla `equipped = 1` satırı
  yoktur. Bu, sadece `domain/inventory.py`'de değil, veritabanında kısmi bir
  benzersiz indekstir (`idx_inventory_one_equipped_per_slot`); koddaki bir hata
  ikinci satırı yazamaz.

### 14.3 Sosyal aktiviteler, risk ve "biriyle" modu

- **D83.** Dokümanın 50 aktivitesi `catalog/lifestyle.py`'nin listesine girer
  (62 satır). 47'si yeni satırdır (`catalog/lifestyle_social.py`), üçü zaten
  vardı ve yerinde genişletildi: `ev-meditasyon` (#4, +Disiplin/Cesaret),
  `sos-kafe` (#11, +Zeka) ve `sos-taraftar` (#34, S/B, `fans`). Beş yeni grup:
  *Ev ve kişisel gelişim*, *Şehirde*, *Kulüp ve futbol çevresi*, *Medya ve
  dijital*, *Gece ve sosyal hayat*. Mevcut `sos-arkadas`, `sos-aile` ve
  `sos-konser` dokümanda karşılığı olmadığından dokunulmadı. Ana/yan skill
  ayrımı etkiler sözlüğündeki iki `attribute:` anahtarıdır; büyüklükleri
  süreden **türetilir** (ana skill `0.2 + dakika/600`, en çok 0.5; yan skill onun
  yarısı), böylece 47 satır birbirinden kopmaz. Bu rakamlar ⟦AÇIK-5⟧.
- **Alanlar.** Her satır `mode` (`S` · `B` · `S/B`) taşıyabilir; alanı
  olmayan eski satır tek başınadır. `B`/`S/B` satırı `with` (yapılabileceği ilişki
  türleri, altı sabit türün alt kümesi) ve `with_delta` (seçilen kişinin kazandığı
  puan, bugün 2–3) ister. Hepsi içe aktarmada doğrulanır
  (`validate_social_fields`, INV-28'in kardeşi): yazım hatalı bir tür ya da
  imkânsız bir şans ilk oyuncuya değil, süreç başlangıcına patlar.
- **D84.** T2 `ActionRequest.relationship_id` alır. `B` için zorunlu, `S/B` için
  isteğe bağlı (yoksa tek başına), `S` için reddedilir; `with` listesinde
  olmayan tür `422`, tanışılmamış kişi `409 relationship_absent` (INV-58). Kontrol
  D42'nin kapısı gibi **bütçeden önce** yapılır. Biriyle: skill kazancı yazıldığı
  gibi, artı `relationship:<rid>` (INV-15). Tek başına (yalnız `S/B`): skill
  kazancı `SOLO_SKILL_BONUS` (1.25) kat, ilişki yok — solo/partner takası budur.
  Çarpan ⟦AÇIK-20⟧. Altı türde tek NPC olduğundan dokümandaki kaptan, malzemeci,
  fizyoterapist ve yardımcı antrenör `team`/`coach` üzerinde *anlatım*dır (D4).
- **D85.** Riskli aktivite (`kulup-soyunma-saka`, `medya-paylasim`,
  `gece-poker`) `risk: {chance, fail_effects, mitigated_by?}` taşır. Zar, normal
  etkiler **uygulandıktan sonra** atılır ve kaybettirdiği şey onların *üstüne*
  biner: akşam yine yaşandı, yalnız daha pahalıya geldi. Tohum
  `Random(f"{seed}:activity_risk:{tarih}:{catalog_id}:{bugün kaç kez yapıldı}")`:
  aynı gün aynı aktiviteyi ikinci kez yapmak ikinci bir zardır, ama aynı tohumdan
  yeniden oynanan kariyer aynı kötü geceleri yaşar. `mitigated_by` bir
  niteliğin *etkin* seviyesi başına `per_level` kadar şansı düşürür (D74/INV-61),
  ama `MIN_RISK_CHANCE` (0.05) altına asla; hiçbir beceri riski sıfırlamaz. Para
  kaybı eldeki bakiyeyle sınırlanır: zar "ters gitti" dedikten sonra
  `insufficient_funds` ile yanıtlamak kötü geceyi reddedilmiş isteğe çevirirdi.
  Yanıt `risk: {chance, failed}` (güvenliyse `null`), `fail_effects` ve `with` taşır;
  `activity_log.applied_effects`'te ceza `fail:` önekiyle normal etkiden ayrı durur.
  Negatif `attribute:` etkisi yalnızca `fail_effects`'te bulunur (INV-22 bir
  niteliğin *kendiliğinden* düşmesini yasaklar, seçilmiş bir bedeli değil).
- **D86.** Seviye kilitli aktivite yeni mekanizma değil, mevcut `requires`'tır
  (D42): tek örnek `sehir-acik-mikrofon` (Cesaret 6; taze kariyer 5'ten başlar,
  yani gerçekten kilitli). **Yapılmayan:** dokümanın "bit pazarında pazarlık
  (#17) sözleşme görüşmelerinde ek diyalog seçeneği açar" notu. `catalog/dialogue.py`'de
  bir sözleşme-pazarlığı ağacı yok; Zeka 6 kapılı bir yaprak ancak o ağaç yazıldığında
  anlamlı olur (D23: ağaç FE'de).
- **Haber (§14.7 ilk adım).** Bir aktivite `news: {ok?, fail?}` taşıyabilir;
  `fail` başlığı yalnızca riski olan aktivitede bulunabilir. Bugün `medya-paylasim`
  (iyi ve kötü manşet), `medya-canli-yayin`, `medya-podcast` ve `medya-imza-gunu`
  (iyi manşet) yayımlar; kategori `Röportaj`, kaynak kendi alanından. Gelen yanıtta
  `news_id`. Dokümandaki "olumsuz manşet" bu yoldan yalnız paylaşımda çıkar.
- **Arayüz.** Yaşam Tarzı'nın boş duran "Grupsal" sekmesi bu alandan dolar:
  *Bireysel* tek başına yapılabilenleri (`S`, `S/B`), *Grupsal* biriyle
  yapılabilenleri (`B`, `S/B`) gösterir. Detay katmanında "Kiminle?" çipleri
  (tanışılmış ve izin verilen kişiler; `S/B`'de ilki "Tek başına", `B`'de ilk uygun kişi
  seçili), "Riskli" rozeti ve ters giden sonucun bildirimi vardır.

### 14.4 Konut, uyku ve kira

- **D87.** Bir kariyerin tek bir *aktif konutu* vardır (`residence` tablosu,
  `active = 1`); uykusu, yolculuk etkisi ve karizma derecesi yalnız ondan
  gelir. Katalog `catalog/housing.py`'dedir: 14 yaşanabilir konut (yurt, aile evi, paylaşımlı daire, stüdyo, 1+1, otel, 2+1,
  bahçeli ev, sahil dairesi, loft, akıllı daire, rezidans, deniz villası,
  rehabilitasyon villası), 4 tatil mülkü (köy evi, göl kulübesi, yazlık, dağ evi) ve
  6 ev geliştirmesi. Kariyer **Altyapı yurdu**nda açılır (migration 021 var olan
  kariyerlere de yazar). Yurt ve aile evi (`kind: start`) hep serbesttir: ücretsiz,
  her an geri dönülebilir. Konut iki adımda değişir: *edinmek* (`acquire`) ve
  *taşınmak* (`activate`); kira ve başlangıç konutu edinince zaten taşınılır, satın
  alınan konutta taşınma ayrı bir adımdır.
- **D88.** Günlük toparlanma = aktif konutun `sleep` değeri **+** konutun ve
  takılı geliştirmelerinin günlük düzeltmeleri **+** giyilen eşyaların
  `daily_effects.condition` payı, `MAX_CONDITION_RECOVERY_PER_DAY` (20) ile kesilir.
  `condition.daily_recovery()` hâlâ tek okuma yoludur (T1 önizlemesi ile gün
  uygulaması hiç ayrışmaz) ve `base` artık konutun uykusudur, sabit 5 değil.
  - **Ölçek.** Dokümanın uyku kazancı 0-100 ölçeğinde +20…+50'dir; bu oyunda bir
    maç ≈30 yakar ve günlük tavan 12'ydi. Değerler dokümanın **0,3 katı**, tam sayıya
    yuvarlanmış olarak alınır (yurt +20 → 6 … rehabilitasyon villası +45 → 14;
    tatil günü +50 → 15); böylece yurt, eski doğal 5'e yakın bir başlangıç verir ve
    konut yükseltmek bir hafta boyunca gerçekten hissedilir. Sayılar ⟦AÇIK-21⟧.
  - **Okunan ek etkiler:** yurtta oda arkadaşı gürültüsü (%20 şansla o günün uykusu
    yarıya iner; tohum `Random(f"{seed}:housing_noise:{tarih}")`, T1 yarınki günü
    önizlerken aynı zarı atar, yani önizleme ile uygulama aynıdır); aile evinde ev
    yemeği +2 ve tesise uzaklık −2; ortopedik yatak +1 uyku; karartma perdesi +1 uyku
    ve gürültüyü iptal eder; özel aşçı her sabah +2 (aylık ücretli).
  - **Karizma.** Aktif yaşanabilir konutun `grade` × `CHARISMA_PER_GRADE` kadar
    pasif `charisma` bonusu vardır (D73 okuma tarafı katmanı; `attributes.passive_bonus`).
    Tatil mülklerinin derecesi yalnız gösterimdir (D87: yalnız aktif konut).
  - **`ev-uyku`** aktivitesi 14 → 8 kondisyona indi: gecelik dinlenme artık konuttan
    geldiği için aktivite "erken yat" ekidir, ikinci bir gece değil.
  - **Kayıtlı ama hiçbir şey okumaz** (`note` metni olarak katalogda durur, D88'in
    sakatlık cümlesi gibi): sakatlık süresi %10/%25/%5 kısalır, maç sonrası sauna +5
    ve sahil yürüyüşü +10, ev spor salonunun haftalık antrenmanı, stüdyonun gece
    kaybı azaltması, loft'un ev partisi bonusu ve maç öncesi gece −3, akıllı evin
    kondisyon tahmini (T1 zaten gösterir), bahçeli evin koşusu, site salonu, dağ
    evinin "tavan +5"i (kondisyon tavanı zaten 100), ev arkadaşı ve takım ağırlama
    olayları (§14.5–§14.6'nın işi).
- **D89.** Kira **gerçek aylık**tır: ayın 1'inde, haftanın günü fark etmeksizin,
  Pazartesi bloğundan ayrı ve onun *ardından* tahsil edilir (gelir önce gelir,
  D29'un sırası). Yeni kira sözleşmesinde taşınma günü ayın kalan günleri kadar
  **orantılı** kira ödenir (`kira × kalan_gün / ay_günü`, en az 1); aksi hâlde
  ayın 2'sinde taşınıp 1'inde çıkan oyuncu hiç kira ödemezdi. Sözleşmenin kirası
  taşınırken donar (`price_paid` gibi). Ödenemeyen kira konutu kaybettirir: sözleşme
  biter ve oyuncu **aile evine** döner (D29'un %50 iadesi uygulanmaz, sahip olunan bir
  şey yoktur). Özel aşçının aylık ücreti aynı günde alınır; ödenemezse aşçı gider,
  konut gitmez. `LEDGER_KINDS`'e `rent` eklenir (kira, otel ve aşçı).
- **D90.** *Otel.* Transferden sonra (`transfer.accept`, aynı işlemde) sahip
  olunan bir konutta oturmayan oyuncu, `HOTEL_STAY_DAYS` (14) günlük otel odasına
  taşınır: günlük ücret her gün alınır (ödenemezse ya da süre dolunca aile evi).
  Sahip olunan konutta oturan oyuncu olduğu yerde kalır; kiralık sözleşmeler şehir
  değiştirince biter. Otel elle edinilemez. *Tatil mülkleri* yaşanamaz;
  yalnız `winter_break` ve `summer_transfer_window` fazlarında `rest` ile
  kullanılır: günün bütün süresi harcanır (bu yüzden günde bir kez), konutun
  `rest.condition` kazancı ve küçük nitelik/ilişki etkileri `_apply_effects` ile
  uygulanır. Faz dışında `409 rest_out_of_season`.
- **D95.** Satın alma peşinatsız, tek seferlik ve tam bedeldir (`price`; ipotek
  yok) ve satılamaz; geliştirmeler yalnız *sahip olunan yaşanabilir* konuta
  takılır ve konutla kalır. Kiralık konuta geliştirme takılamaz (dokümanın kuralı).
  Bir konutu değiştirmek kiralık sözleşmeyi ve otel odasını bitirir; sahip
  olunan konut listede kalır.
- **INV-67.** Bir kariyerin aynı anda en fazla bir aktif konutu vardır — bu
  `residence`'ta kısmi benzersiz bir indekstir (`idx_residence_one_active`), INV-66
  gibi veritabanı garantisidir.
- **INV-69.** Bir `rented` ya da `hotel` satırı her zaman aktif satırdır: ayrılmak
  onu siler. Boşta duran bir sözleşme yoktur, dolayısıyla kimse oturmadığı bir
  daire için kira ödemez.
- **Uçlar.** `GET /careers/{cid}/housing` (katalog + durum), `POST …/housing/{id}/acquire`,
  `…/activate`, `…/upgrades/{upgrade_id}`, `…/rest`. Hepsi `career_state` döner
  (D28). Hatalar: `residence_not_held` (404), `residence_already_held`,
  `residence_not_available`, `upgrade_already_installed`, `rest_out_of_season` (409),
  artı mevcut `insufficient_funds`. `T3` yanıtı `residence_moves[]` taşır ve zorunlu
  bir taşınma (çıkarılma, otelin bitişi) `residence_moved` olayıyla günü durdurur.

### 14.5 Tetikleyiciler ve olay kuyruğu

- **D91.** Tek bir tetikleyici altyapısı (`domain/triggers.py`), `career_engine`'in
  gerçekten görebildiği dört girdiyle: *takvim* (`daytime.process_day`: doğum günü,
  yıl dönümü, sözleşmeye 182 gün kala, derbiye 3 gün kala, sabit bir gala günü, artı
  tohumlu günlük zarlar), *biten maç* (`matches.apply_result`: galibiyet, mağlubiyet,
  kırmızı kartlı mağlubiyet, yedek kalmak, golsüz kalmak, erken oyundan çıkmak, üç
  mağlubiyetlik seri, eski kulübe gol, özel gün, ilk gol), *ters giden aktivite* (T2:
  soyunma odası şakası) ve *vadesi gelen sonuç* (§14.6). Tetikleyici olay **açmaz**,
  `event_candidate`'e aday yazar. Şablonlar `content/relationship_events.py`'de:
  dokümanın 40 olayı ve zincirlerin ihtiyaç duyduğu ikisi (`rel-gruplasma-rakip`,
  `rel-ilk-gol-topu`), toplam 42. Tetikleyici sözlüğü kapalıdır ve içe aktarmada
  doğrulanır (INV-28'in kardeşi). Dönen değerler:
  - `daily` bir kez/sezon anahtarlıdır; `needs` kapalı kümesi: `partner_active`,
    `sponsor_active`, `offer_open`, `window_open`, `low_condition` (<45).
  - Doğum günü ve yıl dönümü tarihleri veri olmadığı için kariyer tohumundan
    türetilir (`Random(f"{seed}:calendar:…")`, günler 1-28); derbi rakipleri kendi
    liginden tohumla seçilen iki takımdır (`triggers.rivals`). Bayram gezici
    olduğundan "özel gün" sabit bir tarihtir (`SPECIAL_DAYS`).
  - `post_match` tetikleyicisi isteğe bağlı `chance` taşır (fikstür başına
    tohumlu zar): "galibiyet" iki haftada bir doğru olur ve her seferinde bir
    tribün sahnesi açmamalıdır.
  - Hepsinin ana anahtarı `config.TRIGGERS_ENABLED`'dır; test paketi varsayılan
    olarak kapatır (`SOCIAL_OFFER_DAILY_CHANCE`'in gerekçesiyle).
- **D92.** Öncelikli bekleme kuyruğu. `promote()` açık olay yoksa (INV-62) ve son
  tetikleyici olayı `TRIGGER_EVENT_MIN_GAP_DAYS` (2) günden eskiyse, en yüksek
  `priority`'li (eşitte en eski, sonra `template_id`) adayı bir `activity_event`'e
  çevirir. Aday `expires_in_days` (varsayılan 3; doğum günü 2, sözleşme görüşmesi 14)
  sonra yazmadan düşer (`expired`); geçerliliğini yitirmiş aday (ayrılmış partnerin
  yıl dönümü) atlanır. Olay gün döngüsünde açıldıysa `relationship_event` günü
  durdurur — aksi hâlde INV-63 olayı kimse görmeden ertesi gün kapatırdı. M2 yanıtı
  ve T2 yanıtı aynı olayı `event` alanında taşır. INV-39 ve INV-62 **olduğu gibi**
  korunur: kuyruk ikisini de aşmaz, yalnız onların önünde bekler.
- **D93.** Doküman eşlemesi (yeni ilişki türü yok, D4): yönetim → `coach`; menajer →
  `family`; sponsor → mevcut sponsorluk sistemi (`fame:overall`, `money`,
  `sponsorship:end`). Gate'ler dokümanın ≥2/≥3'ünün 0-10 ölçeğine ×2-3 ile
  çevrilmiş hâlidir: doküman 2 → seviye 7, doküman 3 → seviye 8 (karizma 7, empati
  5, cesaret 5, zeka 6, disiplin 2'den başlar) — ⟦AÇIK-5⟧. Her olayın kapısız bir
  çıkışı vardır (INV-32'nin kardeşi, içe aktarmada doğrulanır).
- **Maç içi olaylar.** Dokümandaki #2 (kırmızı kart), #4 (gol pozisyonu) ve #13
  (oyundan alınma) gerçek zamanlı değil, **sonuçtan** uyarlanmıştır: kırmızı kartlı
  mağlubiyet, golsüz ama takımın gol attığı maç, 60. dakikadan önce oyundan çıkma.
  Gerçek hâli ⟦AÇIK-19⟧'dur (§14.7).
- **`on_ignore`.** Şablon, görmezden gelmenin bedelini yazabilir (annenin doğum günü
  −14, takım arkadaşının doğum günü −6, yıl dönümü −20, kaptanlık −3). Bu, INV-63'ün
  tek istisnasıdır ve para kaybı bakiyeyle sınırlanır (`clamp_money`).
- **INV-70.** Bir kariyerde aynı `dedupe_key` iki kez aday olmaz (veritabanında
  benzersiz kısıt), bekleyen bir şablon ikinci kez kuyruğa girmez. Bir tetikleyici
  iki kez ateşlenirse — yeniden denenen bir ilerleme, tekrar okunan bir maç — sonuç
  aynıdır.
- **Uygulanmayanlar.** Doküman #28 "medya ilişkiyi soruyor" ve #26 "paparazzi" için
  partnerin açık olması şarttır (`partner_active`); yeni bir tanışma yolu yoktur.
  Olayların sahne görünümleri (arka planlar) FE'nin işidir.

### 14.6 Ertelenmiş sonuç

- **D94.** `deferred_consequence`: bir şablon seçeneği `defer: [{days, effects,
  followup?, news?}]` taşıyabilir; T6 seçimi işlerken (aynı işlemde, INV-3) satırı
  yazar. Gün döngüsü, vadesi gelen satırları **tetikleyicilerden önce** uygular
  (sonucu bir takip olayı kuyruğa yazıyorsa o sabah açılabilsin): etkiler
  `domain/effects.py` ile, para kaybı bakiyeyle sınırlı (bir ilerlemeyi
  `insufficient_funds` ile patlatmamak için), başlık varsa haber, takip şablonu
  varsa `deferred` türünde bir aday. `plan_days_ahead` gibi günü kilitlemez
  (D76'nın gerekçesi). Kullanıldığı yerler: #5 borç geri gelir ya da gelmez, #6 sır
  35 gün sonra ya güven ya skandal, #7 → #8 zinciri (görmezden gelinen yeni transfer
  21 gün sonra rakip klikte çıkar), #12 bahane yakalanır, #23 bir yardım bir sonraki
  talebe zemin hazırlar (şablon kendi takibidir), #26 sessizlik 3 gün sonra patlar,
  #31 ve #39 (sponsor 14 gün sonra bırakır).
- **INV-68.** Vadesi gelen `deferred_consequence` tam bir kez uygulanır: satır,
  etkileriyle aynı işlemde `applied`'a geçer ve yalnız `pending` satırlar okunur.
- **Yeni effect anahtarı `sponsorship:end`.** En eski etkin sponsorluk anlaşmasını
  bozar (yükümlülükleri geçersiz kalır, medya cezası yok — olayın kendisi onu
  seçimle zaten yazdı). INV-28 kümesine eklendi. Uygulayan: `domain/effects.py`,
  ki `api/routers/time.py::_apply_effects` bunun eski adıdır.
- **Hikâye kalemlerinin kaynakları (D82'nin bağlanması).** `special-signed-jersey`:
  #21 kardeşin maçına gitmek. `special-first-goal-ball`: ilk golden sonra açılan
  `rel-ilk-gol-topu` olayı. `special-signature-boots`: Vento krampon sözleşmesini
  imzalamak (`content/sponsorships.py::boot_brand.grant_item`). `special-foundation`
  hâlâ kaynaksızdır (§14.7'ye yazıldı).

### 14.7 Bilinen eksikler ve açık değerler

**Bağlam etkileri (D96, INV-71).** Dokümanın bazı itemleri, derecelerinin ötesinde
bir anlam taşır; `catalog/shop.py::ITEM_CONTEXT` bunu satırların yanında tutar
(`domain/context.py` tek okuyucusudur, içe aktarmada doğrulanır) ve yalnız **giyilen**
item sayılır:

| Item | Bağlam | Mekanik |
|---|---|---|
| `cloth-cashmere-coat` | `months` | Pasif karizması yalnız Kasım–Mart'ta sayılır, diğer aylarda 0 |
| `veh-sports-car` · `veh-custom-supercar` | `bad_form` | Üç maçlık mağlubiyet serisinde pasif karizması **işaret değiştirir** (+2 → −2); seri bozulunca (beraberlik/galibiyet) geri döner. Seriyi süren her yenilgi M2'de bir manşet yazar (`"Maçları bırakmış, araba alıyor"`) |
| `veh-custom-supercar` | `news_on_acquire` | Satın almak manşet olur (T4 yanıtı `news_id` taşır) |
| `tech-stream-kit` · `tech-photographer` · `cloth-luxury-outfit` · `cloth-leather-jacket` | `boosts` | Giyilirken, ilgili aktivitenin (kimlikle ya da `group:`la) **pozitif** `attribute:` kazancı ×1,3–1,5; kayıp ve para çarpılmaz. Aktivite yanıtının `applied_effects`'i çarpılmış hâli taşır |
| `tech-youtube-team` | `weekly_news` | Her Pazartesi tohumlu bir "Röportaj" haberi |

- **D96.** "Kötü form" tek yerde tanımlıdır (`domain/form.py`): kullanıcı takımının son
  3 maçı üst üste yenilgi. Maç sonrası tetikleyicisi (`losing_streak`, §14.5) ve
  araba bağlamı aynı tanımı okur; biri değişirse öteki ayrışmaz.
- **INV-71.** Bağlam **türetilir, saklanmaz** (INV-60'ın gerekçesi): palto yazın geri
  alınacak bir şey yazmaz, seri bozulunca iade edilecek bir değer yoktur. Bu yüzden
  INV-22 ("bir nitelik kendiliğinden düşmez") bozulmaz — değişen taban değil okuma
  katmanıdır; etkin değer ve bütün `requires` kapıları (INV-61) bunu görür.
- **Yapılmayanlar (bağlam notu olarak durur):** telefonun sosyal medya aktivitelerini
  "açması", kulüp kartının gece mekânlarını "açması", sinema/plak çalarla açılan
  seçenekler, gençlerde hoodie, basın toplantısında saat, galada takım elbise, parfümün
  yakın diyalog etkisi, retro motosiklet–kulüp yasağı çatışması, kibirli bulan
  karakterler, sahne görünümü (arka plan). Bunlar bir aktivitenin ya da diyaloğun
  *kapısını* değiştirir; kapı kilidi için aktivite satırında item şartı ve FE'de kilit
  gösterimi gerekir (⟦AÇIK-24⟧).

**Maç içi tetikleyiciler bu sürümde yoktur.** Kırmızı kart, oyundan alınma ve
gol pozisyonunda pas/şut kararı (dokümandaki #2, #4, #13) `match_engine`'in
olay akışına ve client'ın `MatchController`'ına bağlıdır; `career_engine` bugün
kullanıcının kartlarını da görmez (`user_cards` hep 0, `domain/matches.py`).
Bu olaylar maç sonrası tetikleyicilere uyarlanır; gerçek maç içi tetikleyici
`API_CONTRACT.md`'nin ve `match_engine`'in değişmesini gerektirir.

| Kimlik | Yer | Açık |
|---|---|---|
| ⟦AÇIK-19⟧ | §14.5 maç içi tetikleyiciler | Kırmızı kart, oyundan alınma ve gol pozisyonu olaylarının `match_engine` → `career_engine` taşınması; bu sürümde yok |
| ⟦AÇIK-20⟧ | §14.3 "biriyle" çarpanı | Solo ile partnerli aktivite arasındaki skill/ilişki takasının sayıları |
| ⟦AÇIK-24⟧ | §14.7 item kapıları | "Açar" diyen itemlerin (telefon, kulüp kartı, sinema…) bir aktivite/diyalog kapısı olması; `requires_item` ve FE kilit gösterimi gerekir, bu sürümde yok |
| ⟦AÇIK-22⟧ | §14.5 tetikleyici olasılıkları ve kuyruk sayıları | Günlük zarların şansları, post-match `chance`'lar, 2 günlük aralık, `expires_in_days`'ler ve `on_ignore` bedelleri yer tutucudur |
| ⟦AÇIK-23⟧ | §14.6 `special-foundation` kaynağı | "Kendi adına hayır vakfı" (#42) hiçbir olayın/ödülün sonucu değil; bugün ne satılır ne verilir |
| ⟦AÇIK-21⟧ | §14.4 konut katalog değerleri | 0,3 katı kondisyon ölçeği, günlük tavan 20, kira/fiyat/otel ücreti tutarları, otelin 14 günü ve gürültünün %20'si yer tutucudur |
