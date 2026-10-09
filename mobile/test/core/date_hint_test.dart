import 'package:flutter_test/flutter_test.dart';
import 'package:lifebase_mobile/core/notes/date_hint.dart';

void main() {
  // Friday 9 October 2026, 10:00.
  final now = DateTime(2026, 10, 9, 10);

  final cases = <String, (DateTime, bool)?>{
    'yarın 15:00 dişçi': (DateTime(2026, 10, 10, 15), true),
    'Yarına kadar faturayı öde': (DateTime(2026, 10, 10), false),
    'Cuma toplantı': (DateTime(2026, 10, 9), false),
    'cuma 9:00 toplantı': (DateTime(2026, 10, 16, 9), true),
    "cuma'ya kadar bitir": (DateTime(2026, 10, 9), false),
    'Pazartesi annemi ara': (DateTime(2026, 10, 12), false),
    'cumartesi pazar': (DateTime(2026, 10, 10), false),
    'pazartesi günü saat 14:15': (DateTime(2026, 10, 12, 14, 15), true),
    'haftaya salı': (DateTime(2026, 10, 13), false),
    'haftaya bakarız': (DateTime(2026, 10, 16), false),
    "12 ekim saat 3'te": (DateTime(2026, 10, 12, 15), true),
    '12 Ekim 2027 doğum günü': (DateTime(2027, 10, 12), false),
    '3 Mart vize': (DateTime(2027, 3, 3), false),
    '12/10/2026 14.30 kargo': (DateTime(2026, 10, 12, 14, 30), true),
    '12.10.2026 randevu': (DateTime(2026, 10, 12), false),
    '25/12 yılbaşı alışverişi': (DateTime(2026, 12, 25), false),
    'akşam 8 sinema': (DateTime(2026, 10, 9, 20), true),
    'sabah 9 koşu': (DateTime(2026, 10, 10, 9), true),
    'gece 11 nöbet': (DateTime(2026, 10, 9, 23), true),
    '5 gün sonra kontrol': (DateTime(2026, 10, 14), false),
    'öğlen yemek': (DateTime(2026, 10, 9, 12), true),
    'Bugün İlaç al': (DateTime(2026, 10, 9), false),
    'BUGÜN 18:45': (DateTime(2026, 10, 9, 18, 45), true),
    '16:00': (DateTime(2026, 10, 9, 16), true),
    '9:30 servis': (DateTime(2026, 10, 10, 9, 30), true),
    'süt ekmek yumurta': null,
    '2 tablet al': null,
    'saat 25 olmaz': null,
    '31 şubat': null,
    'cumartesiye kadar': (DateTime(2026, 10, 10), false),
  };

  for (final MapEntry(key: text, value: expected) in cases.entries) {
    test(text, () {
      final hint = findDateHint(text, now);
      if (expected == null) {
        expect(hint, isNull);
      } else {
        expect(hint, isNotNull);
        expect((hint!.start, hint.hasTime), expected);
      }
    });
  }

  test('the date words come out of an event title', () {
    String title(String text) => withoutHint(text, findDateHint(text, now)!);
    expect(title('yarın 15:00 dişçi'), 'dişçi');
    expect(title('Dişçi randevusu, cuma saat 3'), 'Dişçi randevusu');
    expect(title('Annemi ara pazartesi günü'), 'Annemi ara');
  });
}
