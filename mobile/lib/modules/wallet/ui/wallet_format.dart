import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/wallet/wallet_models.dart';

/// Server category names are ASCII; show them in Turkish.
const _categoryNames = {
  'Yeme Icmek': 'Yeme İçme',
  'Ulasim': 'Ulaşım',
  'Saglik': 'Sağlık',
  'Diger Gider': 'Diğer gider',
  'Maas': 'Maaş',
  'Serbest Gelir': 'Serbest gelir',
  'Iade': 'İade',
  'Diger Gelir': 'Diğer gelir',
};

String categoryLabel(String? name) => name == null ? 'Kategorisiz' : _categoryNames[name] ?? name;

IconData categoryIcon(String? name, TxKind kind) {
  final key = (name ?? '').toLowerCase();
  if (key.contains('market')) return Icons.shopping_basket_rounded;
  if (key.contains('yeme')) return Icons.restaurant_rounded;
  if (key.contains('ulas')) return Icons.directions_bus_rounded;
  if (key.contains('fatura')) return Icons.receipt_long_rounded;
  if (key.contains('abone')) return Icons.subscriptions_rounded;
  if (key.contains('sagl') || key.contains('sağl')) return Icons.local_hospital_rounded;
  if (key.contains('kira') || key.contains('ev')) return Icons.home_rounded;
  if (key.contains('maas') || key.contains('maaş')) return Icons.payments_rounded;
  if (key.contains('iade')) return Icons.undo_rounded;
  return kind == TxKind.income ? Icons.south_west_rounded : Icons.north_east_rounded;
}

/// Card colours, one solid colour each: (label, colour, text colour).
const cardSchemes = <String, (String, Color, Color)>{
  'gece': ('Gece', Color(0xFF1F2937), Colors.white),
  'okyanus': ('Okyanus', Color(0xFF1E5BA8), Colors.white),
  'zumrut': ('Zümrüt', Color(0xFF1F7A5A), Colors.white),
  'yakut': ('Yakut', Color(0xFFB0303F), Colors.white),
  'altin': ('Altın', Color(0xFFD9B865), Color(0xFF2B2111)),
  'lavanta': ('Lavanta', Color(0xFF7E64C8), Colors.white),
  'aurora': ('Pembe', Color(0xFFF2B5D4), Color(0xFF2A1424)),
  'gumus': ('Gümüş', Color(0xFFD5D9DE), Color(0xFF1F2328)),
  'turuncu': ('Turuncu', Color(0xFFE9803A), Colors.white),
};

(Color, Color) schemeOf(String? key) {
  final scheme = cardSchemes[key] ?? cardSchemes['gece']!;
  return (scheme.$2, scheme.$3);
}

const networkLabels = {'visa': 'Visa', 'mastercard': 'Mastercard', 'troy': 'Troy', 'amex': 'Amex'};

/// A small type-set network mark (no brand artwork).
class NetworkMark extends StatelessWidget {
  const NetworkMark({super.key, required this.network, required this.color});
  final String? network;
  final Color color;

  @override
  Widget build(BuildContext context) {
    switch (network) {
      case 'mastercard':
        return Semantics(
          label: 'Mastercard',
          child: SizedBox(
            width: 38,
            height: 24,
            child: Stack(children: [
              Positioned(left: 0, child: _dot(const Color(0xFFEB001B))),
              Positioned(right: 0, child: _dot(const Color(0xFFF79E1B).withValues(alpha: .9))),
            ]),
          ),
        );
      case null:
        return const SizedBox.shrink();
      default:
        return Text(
          network == 'visa' ? 'VISA' : (networkLabels[network] ?? network!).toUpperCase(),
          style: TextStyle(color: color, fontWeight: FontWeight.w900, fontStyle: network == 'visa' ? FontStyle.italic : null, letterSpacing: 1),
        );
    }
  }

  static Widget _dot(Color color) => Container(width: 24, height: 24, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

String dayLabel(DateTime day, DateTime today) {
  final d = DateUtils.dateOnly(day);
  if (d == today) return 'Bugün';
  if (d == today.subtract(const Duration(days: 1))) return 'Dün';
  if (d.isAfter(today)) return DateFormat('d MMMM EEEE', 'tr_TR').format(d);
  return DateFormat(d.year == today.year ? 'd MMMM EEEE' : 'd MMMM y', 'tr_TR').format(d);
}

/// "TR12 3456 …" in groups of four.
String formatIban(String iban) {
  final clean = iban.replaceAll(' ', '').toUpperCase();
  return [for (var i = 0; i < clean.length; i += 4) clean.substring(i, i + 4 > clean.length ? clean.length : i + 4)].join(' ');
}

Widget syncBadge(BuildContext context, SyncMark mark) => switch (mark) {
      SyncMark.pending => Tooltip(message: 'Gönderilmeyi bekliyor', child: Icon(Icons.schedule_rounded, size: 16, color: Theme.of(context).hintColor)),
      SyncMark.conflict => const Tooltip(message: 'Çakışma: seçim bekliyor', child: Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFE09B2D))),
      SyncMark.failed => Tooltip(message: 'Gönderilemedi', child: Icon(Icons.error_outline_rounded, size: 18, color: Theme.of(context).colorScheme.error)),
      SyncMark.confirmed => const SizedBox.shrink(),
    };

/// "Bugün son gün", "Yarın", "5 gün sonra", "2 gün gecikti".
String dueLabel(DateTime due, DateTime now) {
  final days = DateUtils.dateOnly(due).difference(DateUtils.dateOnly(now)).inDays;
  return switch (days) {
    0 => 'Bugün son gün',
    1 => 'Yarın',
    < 0 => '${-days} gün gecikti',
    < 7 => '$days gün sonra',
    _ => DateFormat('d MMMM', 'tr_TR').format(due),
  };
}
