import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/calendar/google_projection.dart';
import '../../../core/calendar/reminder_defaults.dart';
import '../../../core/calendar/reminder_picker.dart';
import '../../../core/notifications/reminder_sync.dart';
import '../../../core/design_system/appearance.dart';
import '../../../core/design_system/neu.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/platform/device_calendar.dart';
import '../../../core/providers.dart';
import '../../../core/sync/sync_controller.dart';
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
        const _SectionLabel('Bildirimler'),
        const Card(child: Column(children: [_DefaultRemindersTile(), Divider(height: 1), _ExactAlarmTile()])),
        const SizedBox(height: 24),
        const _SectionLabel('Eşitleme'),
        Card(child: Column(children: [
          const _GoogleCalendarTile(),
          const Divider(height: 1),
          const _LocalBackupTile(),
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
          onPressed: () => _logout(context, ref),
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Çıkış yap'),
        ),
      ]),
    );
  }

  /// Signing out removes this account's local data, so unsynced changes get
  /// one more sync attempt and then an explicit warning.
  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    if ((ref.read(localPendingCountProvider).value ?? 0) > 0) {
      await ref.read(syncControllerProvider.notifier).syncNow();
    }
    final pending = await ref.read(localPendingCountProvider.future);
    if (pending > 0 && context.mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Yedeklenmemiş kayıtlar var'),
          content: Text('$pending kayıt henüz sunucuya yedeklenmedi. Çıkış yaparsan bu cihazdan silinecek.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Yine de çık')),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await ref.read(sessionControllerProvider.notifier).logout();
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
        LayoutBuilder(
          builder: (context, constraints) => Wrap(
            runSpacing: 14,
            children: [
              for (final palette in LbPalette.values)
                SizedBox(
                  width: constraints.maxWidth / 4,
                  child: _PaletteSwatch(
                    palette: palette,
                    selected: appearance.palette == palette,
                    onTap: () => controller.setPalette(palette),
                  ),
                ),
            ],
          ),
        ),
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
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: selected ? t.accent : t.shade, width: selected ? 3 : 1),
            ),
            // Painted rather than a hard-stop gradient: animating a gradient
            // with duplicate stops trips a Flutter assertion.
            child: CustomPaint(painter: _SwatchPainter(preview)),
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

/// Half base colour, half accent.
class _SwatchPainter extends CustomPainter {
  _SwatchPainter(this.tokens);
  final LbTokens tokens;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawOval(rect, Paint()..color = tokens.base);
    canvas.drawArc(rect, -3.141592653589793 / 4, 3.141592653589793, true, Paint()..color = tokens.accent);
  }

  @override
  bool shouldRepaint(_SwatchPainter oldDelegate) => oldDelegate.tokens != tokens;
}

/// Connects the user's own Google calendar both ways: its events show in
/// LifeBase, and LifeBase events are written into its primary calendar.
class _GoogleCalendarTile extends ConsumerWidget {
  const _GoogleCalendarTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(googleCalendarStatusProvider).value?.account;
    return ListTile(
      minTileHeight: 64,
      leading: const Icon(Icons.event_available_rounded),
      title: const Text('Google takvimi'),
      subtitle: Text(account ?? 'Bağlı değil · iki yönlü eşitleme'),
      trailing: account == null ? const Icon(Icons.chevron_right) : const Icon(Icons.check_circle_rounded),
      onTap: () => _connect(context, ref),
    );
  }

  Future<void> _connect(BuildContext context, WidgetRef ref) async {
    final bridge = ref.read(platformBridgeProvider);
    final messenger = ScaffoldMessenger.of(context);
    if (!await bridge.requestCalendarAccess()) {
      messenger.showSnackBar(const SnackBar(content: Text('Takvim izni olmadan Google takvimi bağlanamaz.')));
      return;
    }
    final accounts = await bridge.googleAccounts();
    if (!context.mounted) return;
    if (accounts.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Telefonda Google hesabı bulunamadı.')));
      return;
    }
    final account = accounts.length == 1
        ? accounts.single
        : await showModalBottomSheet<String>(
            context: context,
            showDragHandle: true,
            builder: (sheetContext) => SafeArea(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('Google hesabı', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                ),
                for (final value in accounts)
                  ListTile(
                    leading: const Icon(Icons.account_circle_rounded),
                    title: Text(value),
                    onTap: () => Navigator.pop(sheetContext, value),
                  ),
                const SizedBox(height: 12),
              ]),
            ),
          );
    if (account == null) return;
    final connected = await bridge.connectGoogle(account);
    ref.invalidate(googleCalendarStatusProvider);
    ref.invalidate(deviceEventsProvider);
    // Write the local events into the newly connected calendar right away.
    ref.invalidate(googleProjectionProvider);
    messenger.showSnackBar(SnackBar(
      content: Text(connected ? '$account bağlandı.' : 'Bu hesapta yazılabilir takvim bulunamadı.'),
    ));
  }
}

/// Backup state of local-first data (calendar, medications, doses).
class _LocalBackupTile extends ConsumerWidget {
  const _LocalBackupTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncControllerProvider);
    final pending = ref.watch(localPendingCountProvider).value ?? 0;
    final last = status.lastSyncedAt;
    final subtitle = switch (status.phase) {
      SyncPhase.syncing => 'Eşitleniyor…',
      SyncPhase.offline => 'Çevrimdışı · $pending kayıt bekliyor',
      SyncPhase.unauthorized => 'Oturum yenilenmeli',
      SyncPhase.failed when status.statusCode == 404 => 'Sunucu bu sürümü desteklemiyor · güncellenmeli',
      SyncPhase.failed => 'Sunucu isteği reddetti (${status.statusCode})',
      SyncPhase.idle when pending > 0 => '$pending kayıt bekliyor',
      SyncPhase.idle when last != null =>
        'Yedeklendi · ${last.hour.toString().padLeft(2, '0')}:${last.minute.toString().padLeft(2, '0')}',
      SyncPhase.idle => 'Henüz eşitlenmedi',
    };
    return ListTile(
      minTileHeight: 64,
      leading: const Icon(Icons.cloud_sync_rounded),
      title: const Text('Takvim ve ilaç yedeği'),
      subtitle: Text(subtitle),
      trailing: status.phase == SyncPhase.syncing
          ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : pending == 0 && status.phase == SyncPhase.idle
              ? const Icon(Icons.check_circle_rounded)
              : Badge(label: Text('$pending')),
      onTap: () => ref.read(syncControllerProvider.notifier).syncNow(),
    );
  }
}

/// The reminder set new calendar events start with.
class _DefaultRemindersTile extends ConsumerWidget {
  const _DefaultRemindersTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminders = ref.watch(defaultRemindersProvider);
    return ListTile(
      minTileHeight: 64,
      leading: const Icon(Icons.notifications_active_outlined),
      title: const Text('Varsayılan hatırlatmalar'),
      subtitle: Text(reminders.isEmpty ? 'Yok' : reminders.map(reminderLabel).join(', ')),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => const _DefaultRemindersSheet(),
      ),
    );
  }
}

class _DefaultRemindersSheet extends ConsumerWidget {
  const _DefaultRemindersSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Varsayılan hatırlatmalar', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Yeni etkinlikler bu hatırlatmalarla başlar.', style: TextStyle(color: LbTokens.of(context).muted)),
            const SizedBox(height: 16),
            ReminderListEditor(
              reminders: ref.watch(defaultRemindersProvider),
              allowFixedTime: false,
              onChanged: ref.read(defaultRemindersProvider.notifier).set,
            ),
          ]),
        ),
      );
}

/// Without the exact-alarm grant Android may deliver reminders late.
class _ExactAlarmTile extends ConsumerWidget {
  const _ExactAlarmTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final port = ref.watch(notificationPortProvider).value;
    if (port == null) return const SizedBox.shrink();
    final exact = port.exactAlarms;
    return ListTile(
      minTileHeight: 64,
      leading: Icon(exact ? Icons.alarm_on_rounded : Icons.alarm_rounded),
      title: const Text('Tam zamanlı hatırlatma'),
      subtitle: Text(exact ? 'Açık · hatırlatmalar dakikasında gelir' : 'Kapalı · birkaç dakika gecikebilir'),
      trailing: exact ? const Icon(Icons.check_circle_rounded) : const Icon(Icons.chevron_right),
      onTap: exact
          ? null
          : () async {
              await port.requestExactAlarms();
              // Re-read the grant and re-plan reminders with the new mode.
              ref.invalidate(notificationPortProvider);
              ref.invalidate(calendarReminderSyncProvider);
            },
    );
  }
}
