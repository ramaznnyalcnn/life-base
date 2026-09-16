import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/providers.dart';
import '../auth/session_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final outstanding = ref.watch(outstandingOperationsProvider).value ?? 0;
    final session = ref.watch(sessionControllerProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person_rounded)),
          title: Text(session?.displayName ?? 'LifeBase'),
          subtitle: const Text('Bağlı hesap'),
        )),
        const SizedBox(height: 12),
        Card(child: Column(children: [
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_rounded),
            title: const Text('OLED koyu tema'),
            subtitle: const Text('Siyah arka plan ve düşük parlaklık'),
            value: dark,
            onChanged: (value) => ref.read(themeModeProvider.notifier).state = value ? ThemeMode.dark : ThemeMode.light,
          ),
          const Divider(height: 1),
          ListTile(
            minTileHeight: 64,
            leading: const Icon(Icons.calendar_month_rounded),
            title: const Text('Android takvimi'),
            subtitle: const Text('LifeBase kayıtlarını cihaz takvimine eşitle'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final granted = await ref.read(platformBridgeProvider).requestCalendarAccess();
              if (!context.mounted) return;
              if (!granted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Takvim izni istendi. İzin verdikten sonra yeniden seç.')));
                return;
              }
              final calendars = await ref.read(platformBridgeProvider).writableCalendars();
              if (!context.mounted) return;
              await showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                builder: (sheetContext) => SafeArea(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Eşitlenecek takvim', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    ...calendars.map((calendar) => ListTile(
                      title: Text(calendar['name'] as String? ?? 'Takvim'),
                      subtitle: Text(calendar['account'] as String? ?? ''),
                      trailing: calendar['selected'] == true ? const Icon(Icons.check_circle_rounded) : null,
                      onTap: () async {
                        await ref.read(platformBridgeProvider).selectCalendar(calendar['id'] as int);
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                      },
                    )),
                    const SizedBox(height: 16),
                  ],
                )),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            minTileHeight: 64,
            leading: const Icon(Icons.sync_rounded),
            title: const Text('Eşitleme kuyruğu'),
            subtitle: Text(outstanding == 0 ? 'Tüm işlemler eşitlendi' : '$outstanding işlem bekliyor'),
            trailing: outstanding == 0 ? const Icon(Icons.check_circle_rounded) : Badge(label: Text('$outstanding')),
            onTap: () async {
              await ref.read(syncServiceProvider)?.flush();
            },
          ),
          if (outstanding > 0) ...[
            const Divider(height: 1),
            ListTile(
              minTileHeight: 64,
              leading: Icon(Icons.merge_type_rounded, color: Theme.of(context).colorScheme.error),
              title: const Text('Çakışmaları çöz'),
              subtitle: const Text('Sunucu veya cihaz değişikliğini seç'),
              onTap: () => _showConflicts(context, ref),
            ),
          ],
        ])),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () async {
            await ref.read(sessionControllerProvider.notifier).logout();
            if (context.mounted) Navigator.of(context).pop();
          },
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Çıkış yap'),
        ),
      ]),
    );
  }

  Future<void> _showConflicts(BuildContext context, WidgetRef ref) async {
    final database = ref.read(databaseProvider);
    final rows = await database.conflicts();
    if (!context.mounted) return;
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Çakışan işlem yok.')));
      return;
    }
    final row = rows.first;
    final body = jsonDecode(row.conflictPayload ?? '{}') as Map<String, Object?>;
    final detail = Map<String, Object?>.from(body['detail'] as Map? ?? const {});
    final current = Map<String, Object?>.from(detail['current'] as Map? ?? const {});
    final keepLocal = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Kayıt değişmiş'),
        content: Text('${row.operationKey}\nSunucudaki sürüm: ${current['entity_version'] ?? '?'}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Sunucuyu kullan')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Benim değişikliğim')),
        ],
      ),
    );
    if (keepLocal == null) return;
    if (keepLocal) {
      final version = current['entity_version'];
      if (version is int) await database.retryWithVersion(row.requestId, version);
      await ref.read(syncServiceProvider)?.flush();
    } else {
      await database.acceptServer(row.requestId);
    }
  }
}
