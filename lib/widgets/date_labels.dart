/// Ortak tarih biçimlendiricileri (§1.3: BE ISO-8601 verir, cümleyi FE kurar).
///
/// Bunlar sekiz ekranda birbirinin kopyası olarak yaşıyordu — ay adları dört
/// kez, `+03:00` tuzağının açıklaması üç kez yazılmıştı. Takvim ekranı hepsine
/// birden ihtiyaç duyunca [`news_style.dart`](news_style.dart)'ın yanına,
/// aynı gerekçeyle taşındılar: `newsTimeAgo` de tam olarak böyle ortaklaşmıştı.
///
/// **Saat dilimi tuzağı — yalnız saat taşıyan dizelerde.** `DateTime.parse`
/// bir ofset gördüğünde UTC'ye çevirir ve `isUtc = true` işaretler; `.hour` ve
/// `.weekday` o andan itibaren dizedeki duvar saatini değil UTC alanlarını
/// okur. Kariyer dünyası tek saat dilimi kullandığı için (+03:00, career_engine
/// CONTRACT.md §5.0) `.toLocal()` cihazın kendi dilimine göre yanlış saat
/// üretebilirdi; doğru davranış UTC'ye +3 saat geri eklemektir.
///
/// Çıplak `YYYY-MM-DD` dizelerinde bu sorun **yoktur** — ofset olmadığı için
/// `DateTime.parse` yerel (UTC olmayan) bir değer döner. Bu yüzden
/// [fullDateLabel] ve [monthYearLabel] hiçbir düzeltme yapmaz, [kickoffDayLabel]
/// yapar. Yeni bir yardımcı yazarken ayrım budur: dizede saat var mı?
library;

const turkishMonths = [
  'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
  'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
];

const turkishWeekdays = [
  'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar',
];

/// Pazartesi'den başlayan iki harfli gün başlıkları — takvim gridinin sütun
/// başlıkları. `DateTime.weekday` 1..7 de Pazartesi'den başlar, yani indeksleme
/// `weekday - 1`.
const turkishWeekdayInitials = ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pa'];

/// 'YYYY-MM-DD' → '19 Ağustos 2026'.
String fullDateLabel(String isoDate) {
  final date = DateTime.tryParse(isoDate);
  if (date == null) return isoDate;
  return '${date.day} ${turkishMonths[date.month - 1]} ${date.year}';
}

/// 'YYYY-MM-DD' → '19.08.2026'.
String ddmmyyyy(String isoDate) {
  final date = DateTime.tryParse(isoDate);
  if (date == null) return isoDate;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.day)}.${two(date.month)}.${date.year}';
}

/// Bir ayın başlığı — 'Ağustos 2026'. Ayın kaçıncı günü olduğu önemsiz.
String monthYearLabel(DateTime month) =>
    '${turkishMonths[month.month - 1]} ${month.year}';

/// '2026-03-16T20:00:00+03:00' → 'Pazartesi, 20:00'.
String kickoffDayLabel(DateTime kickoffAt) {
  final wall = kickoffAt.isUtc
      ? kickoffAt.add(const Duration(hours: 3))
      : kickoffAt;
  final weekday = turkishWeekdays[wall.weekday - 1];
  final hh = wall.hour.toString().padLeft(2, '0');
  final mm = wall.minute.toString().padLeft(2, '0');
  return '$weekday, $hh:$mm';
}

/// [kickoffDayLabel]'ın dize alan hâli; ayrıştırılamayan girdiyi olduğu gibi
/// geri verir, böylece beklenmedik bir biçim ekranı boş bırakmaz.
String kickoffDayLabelFrom(String isoDateTime) {
  final parsed = DateTime.tryParse(isoDateTime);
  if (parsed == null) return isoDateTime;
  return kickoffDayLabel(parsed);
}
