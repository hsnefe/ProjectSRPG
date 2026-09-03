import 'package:flutter_test/flutter_test.dart';
import 'package:project_srpg/widgets/date_labels.dart';

void main() {
  test('fullDateLabel bir ISO tarihi Türkçe yazar', () {
    expect(fullDateLabel('2026-08-19'), '19 Ağustos 2026');
    expect(fullDateLabel('2027-01-01'), '1 Ocak 2027');
  });

  test('ddmmyyyy tek haneli gün ve ayı sıfırla doldurur', () {
    expect(ddmmyyyy('2026-08-09'), '09.08.2026');
    expect(ddmmyyyy('2026-12-31'), '31.12.2026');
  });

  test('monthYearLabel ayın kaçıncı günü olduğuna bakmaz', () {
    expect(monthYearLabel(DateTime(2026, 8, 1)), 'Ağustos 2026');
    expect(monthYearLabel(DateTime(2026, 8, 31)), 'Ağustos 2026');
  });

  test('kickoffDayLabel +03:00 dizesindeki duvar saatini korur', () {
    // DateTime.parse bir ofset görünce UTC'ye çevirir (17:00Z); yardımcı
    // +3 saati geri ekleyerek dizede yazan 20:00'ı verir. Cihazın yerel
    // dilimi devreye girmez — testin farklı makinelerde aynı sonucu
    // vermesinin sebebi bu.
    final kickoff = DateTime.parse('2026-08-08T20:00:00+03:00');
    expect(kickoff.isUtc, isTrue);
    expect(kickoffDayLabel(kickoff), 'Cumartesi, 20:00');
  });

  test('kickoffDayLabelFrom ayrıştıramadığını olduğu gibi geri verir', () {
    expect(kickoffDayLabelFrom('2026-08-08T20:00:00+03:00'), 'Cumartesi, 20:00');
    expect(kickoffDayLabelFrom('yakında'), 'yakında');
  });

  test('çıplak tarihlerde saat düzeltmesi uygulanmaz', () {
    // Ofsetsiz dize yerel bir DateTime verir; gün kayması olmamalı.
    expect(fullDateLabel('2026-08-08'), '8 Ağustos 2026');
  });

  test('gün başlıkları DateTime.weekday ile aynı sırada başlar', () {
    expect(turkishWeekdayInitials.length, 7);
    expect(turkishWeekdayInitials.first, 'Pt');
    final monday = DateTime(2026, 8, 3);
    expect(monday.weekday, DateTime.monday);
    expect(turkishWeekdayInitials[monday.weekday - 1], 'Pt');
    expect(turkishWeekdays[monday.weekday - 1], 'Pazartesi');
  });
}
