import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/appearance.dart';
import '../../../core/design_system/neu.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/providers.dart';
import '../data/session_controller.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outstanding = ref.watch(outstandingOperationsProvider).value ?? 0;
    final session = ref.watch(sessionControllerProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Hesap ve ayarlar')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person_rounded)),
          title: Text(session?.displayName ?? 'LifeBase'),
          subtitle: const Text('Bağlı hesap'),
        )),
        const SizedBox(height: 24),
        const _SectionLabel('Görünüm'),
        const _AppearanceCard(),
        const SizedBox(height: 24),
        const _SectionLabel('Eşitleme'),
        Card(child: Column(children: [
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            color: LbTokens.of(context).muted,
            letterSpacing: 1.3,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      );
}

class _AppearanceCard extends ConsumerWidget {
  const _AppearanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = LbTokens.of(context);
    final appearance = ref.watch(appearanceProvider);
    final controller = ref.read(appearanceProvider.notifier);
    return NeuSurface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Renk şeması', style: TextStyle(fontWeight: FontWeight.w700, color: t.onBase)),
        const SizedBox(height: 12),
        Row(children: [
          for (final palette in LbPalette.values)
            Expanded(
              child: _PaletteSwatch(
                palette: palette,
                selected: appearance.palette == palette,
                onTap: () => controller.setPalette(palette),
              ),
            ),
        ]),
        const SizedBox(height: 20),
        Text('Mod', style: TextStyle(fontWeight: FontWeight.w700, color: t.onBase)),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('Sistem')),
              ButtonSegment(value: ThemeMode.light, label: Text('Açık')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Koyu')),
            ],
            selected: {appearance.palette.darkOnly ? ThemeMode.dark : appearance.mode},
            onSelectionChanged: appearance.palette.darkOnly ? null : (value) => controller.setMode(value.first),
          ),
        ),
        if (appearance.palette.darkOnly)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Gece şeması her zaman koyu.', style: TextStyle(color: t.muted, fontSize: 12)),
          ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Animasyonları azalt', style: TextStyle(fontWeight: FontWeight.w700, color: t.onBase)),
          subtitle: Text('Geçişler kısa bir solmaya dönüşür', style: TextStyle(color: t.muted)),
          value: appearance.reduceMotion,
          onChanged: controller.setReduceMotion,
        ),
      ]),
    );
  }
}

class _PaletteSwatch extends StatelessWidget {
  const _PaletteSwatch({required this.palette, required this.selected, required this.onTap});

  final LbPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    final preview = LbTokens.resolve(palette, t.brightness);
    return Semantics(
      button: true,
      selected: selected,
      label: '${palette.label} renk şeması',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Column(children: [
          AnimatedContainer(
            duration: t.reduceMotion ? Duration.zero : LbTokens.motionShort,
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [preview.base, preview.accent],
                stops: const [.5, .5],
              ),
              border: Border.all(color: selected ? t.accent : t.shade, width: selected ? 3 : 1),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            palette.label,
            style: TextStyle(
              fontSize: 12,
              color: selected ? t.onBase : t.muted,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ]),
      ),
    );
  }
}
