/// Oyunun para birimi: **Kredi (₭)**.
///
/// §1.3 — backend sayıyı verir, etiketi FE yazar. Bu dosya o etiketin tek
/// sahibidir: sembol ve binlik ayracı beş ayrı yerde kopyalanmıştı
/// (`CareerState.moneyLabel`, `PlayerState.moneyLabel`, `contract_screen`,
/// `shop_item_card`, `value_scatter_chart`) ve `lifestyle_screen` altıncı
/// olarak ham `'₺${cost}'` yazıyordu — para birimi değiştiğinde altısını da
/// tek tek bulmak gerekiyordu. Artık tek yer burası.
///
/// `lib/net` altında duruyor çünkü hem modeller (`career_models.dart`) hem
/// widget'lar okuyor; ters yön (net → widgets) hiç yok, yani içe aktarma
/// grafiği çevrimsiz kalıyor.
library;

/// Sembol oyuncuya görünen tek biçim; ayrı bir sabit çünkü font desteği
/// olmayan bir ortamda tek satır değiştirerek `KR`'ye düşülebilsin.
const String kCurrencySymbol = '₭';

/// '48.200 ₭' — binlik ayracı nokta (Türkçe), sembol sonda ve boşlukla
/// ayrılmış. Negatif değerlerde işaret en başta kalır: '-1.200 ₭'.
String formatMoney(int value) => '${thousands(value)} $kCurrencySymbol';

/// Sembolsüz binlik ayraçlı biçim — tutarın yanında zaten bir sembol/etiket
/// olan yerler için.
String thousands(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return (value < 0 ? '-' : '') + buffer.toString();
}

/// '4,2 M ₭' / '450 B ₭' — dar eksenler için kısaltılmış biçim, Türkçe
/// ondalık ayracı virgül. Grafik ekseni gibi yerlerde tam sayı okunmaz,
/// büyüklük sırası yeter.
String formatMoneyCompact(num value) {
  if (value >= 1000000) {
    final text = (value / 1000000).toStringAsFixed(1);
    return '${text.replaceAll('.', ',')} M $kCurrencySymbol';
  }
  if (value >= 1000) return '${(value / 1000).round()} B $kCurrencySymbol';
  return '${value.round()} $kCurrencySymbol';
}
