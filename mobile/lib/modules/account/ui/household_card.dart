import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/design_system/tokens.dart';
import '../../../core/providers.dart';
import '../../../core/sync/sync_controller.dart';

/// The household as the server sees it (online only).
final householdProvider = FutureProvider.autoDispose<Map<String, Object?>?>((ref) async {
  final api = ref.watch(apiClientProvider);
  if (api == null) return null;
  final body = await api.household();
  return body['household'] as Map<String, Object?>?;
});

String _error(Object error) {
  if (error is DioException) {
    final detail = error.response?.data is Map ? (error.response!.data as Map)['detail'] : null;
    if (detail is String) return detail;
    if (error.response == null) return 'İnternet bağlantısı gerekli.';
  }
  return 'İşlem yapılamadı.';
}

/// Members, invite code, join with a code, leave.
class HouseholdCard extends ConsumerWidget {
  const HouseholdCard({super.key});

  Future<void> _run(BuildContext context, WidgetRef ref, Future<void> Function() action) async {
    try {
      await action();
      ref.invalidate(householdProvider);
      // The wallet's scope changed: pull it again.
      await ref.read(syncControllerProvider.notifier).syncNow();
    } on Object catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_error(error))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = LbTokens.of(context);
    final api = ref.watch(apiClientProvider);
    final household = ref.watch(householdProvider);
    if (api == null) return const SizedBox.shrink();

    return Card(
      child: household.when(
        loading: () => const ListTile(minTileHeight: 64, leading: Icon(Icons.home_rounded), title: Text('Hane'), subtitle: Text('Yükleniyor…')),
        error: (error, _) => ListTile(
          minTileHeight: 64,
          leading: const Icon(Icons.home_rounded),
          title: const Text('Hane'),
          subtitle: Text(_error(error)),
          trailing: IconButton(tooltip: 'Yenile', onPressed: () => ref.invalidate(householdProvider), icon: const Icon(Icons.refresh_rounded)),
        ),
        data: (data) {
          final members = ((data?['members'] as List?) ?? const []).cast<Map>();
          return Column(children: [
            ListTile(
              minTileHeight: 64,
              leading: const Icon(Icons.home_rounded),
              title: Text(data == null ? 'Hane yok' : 'Hane · ${members.length} kişi'),
              subtitle: Text(data == null
                  ? 'Biriyle ortak hesap ve kart kullanmak için davet kodu oluştur ya da koda katıl.'
                  : 'Ortak işaretlediğiniz hesaplar ikinizde de görünür.'),
            ),
            for (final member in members)
              ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: t.module(LbModule.wallet),
                  child: Text('${member['name']}'.isEmpty ? '?' : '${member['name']}'.substring(0, 1).toUpperCase(),
                      style: TextStyle(color: t.onAccent, fontWeight: FontWeight.w800, fontSize: 12)),
                ),
                title: Text('${member['name']}${member['is_me'] == true ? ' (sen)' : ''}'),
                subtitle: Text('${member['email'] ?? ''}'),
              ),
            const Divider(height: 1),
            ListTile(
              minTileHeight: 56,
              leading: const Icon(Icons.qr_code_rounded),
              title: const Text('Davet kodu oluştur'),
              onTap: () => _run(context, ref, () async {
                final invite = await api.createHouseholdInvite();
                if (context.mounted) await _showCode(context, '${invite['code']}', DateTime.parse('${invite['expires_at']}'));
              }),
            ),
            if (data == null)
              ListTile(
                minTileHeight: 56,
                leading: const Icon(Icons.login_rounded),
                title: const Text('Koda katıl'),
                onTap: () async {
                  final code = await _askCode(context);
                  if (code != null && context.mounted) await _run(context, ref, () => api.joinHousehold(code));
                },
              )
            else
              ListTile(
                minTileHeight: 56,
                leading: Icon(Icons.logout_rounded, color: t.danger),
                title: Text('Haneden ayrıl', style: TextStyle(color: t.danger)),
                onTap: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Haneden ayrılınsın mı?'),
                      content: const Text('Ortak işaretlediğin hesaplar sende kişisel olarak kalır; diğer kişinin ortak hesaplarını artık görmezsin.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
                        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Ayrıl')),
                      ],
                    ),
                  );
                  if (ok == true && context.mounted) await _run(context, ref, api.leaveHousehold);
                },
              ),
          ]);
        },
      ),
    );
  }

  static Future<void> _showCode(BuildContext context, String code, DateTime expires) => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Davet kodu'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            SelectableText(code, style: Theme.of(dialogContext).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 6)),
            const SizedBox(height: 8),
            Text('Diğer kişi kendi telefonunda Hesap ve ayarlar → Hane → Koda katıl ile girer. '
                '${DateFormat('d MMM HH:mm', 'tr_TR').format(expires.toLocal())} tarihine kadar, bir kez geçerli.'),
          ]),
          actions: [
            TextButton(
              onPressed: () => Clipboard.setData(ClipboardData(text: code)),
              child: const Text('Kopyala'),
            ),
            FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Tamam')),
          ],
        ),
      );

  static Future<String?> _askCode(BuildContext context) async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Koda katıl'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          maxLength: 12,
          decoration: const InputDecoration(labelText: 'Davet kodu'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Katıl')),
        ],
      ),
    );
    controller.dispose();
    return code == null || code.isEmpty ? null : code;
  }
}
