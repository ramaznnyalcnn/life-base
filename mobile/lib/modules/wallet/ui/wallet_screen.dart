import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';

import '../../../core/design_system/module_scaffold.dart';
import '../../../core/design_system/neu.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/sync/sync_controller.dart';
import '../../../core/wallet/wallet_models.dart';
import '../../../core/wallet/wallet_outbox.dart';
import '../../../core/wallet/wallet_store.dart';
import '../data/wallet_repository.dart';
import 'account_detail_page.dart';
import 'account_edit_page.dart';
import 'all_entries_page.dart';
import 'entry_detail_page.dart';
import 'entry_page.dart';
import 'outbox_issues_page.dart';
import 'payment_edit_page.dart';
import 'secure_card.dart';
import 'spending_summary_section.dart';
import 'wallet_analysis_page.dart';
import 'wallet_format.dart';

enum WalletFilter { all, personal, shared }

final walletFilterProvider = StateProvider<WalletFilter>((ref) => WalletFilter.all);

bool _passes(WalletAccount account, WalletFilter filter) => switch (filter) {
      WalletFilter.all => true,
      WalletFilter.personal => !account.shared,
      WalletFilter.shared => account.shared,
    };

/// One line of the movements list: an expense/income or a transfer.
class WalletEntry {
  WalletEntry.tx(WalletTransaction this.tx)
      : transfer = null,
        at = tx.occurredAt,
        sync = tx.sync;
  WalletEntry.transfer(WalletTransfer this.transfer)
      : tx = null,
        at = transfer.occurredAt,
        sync = transfer.sync;

  final WalletTransaction? tx;
  final WalletTransfer? transfer;
  final DateTime at;
  final SyncMark sync;
  String get id => tx?.id ?? transfer!.id;
}

/// Movements touching [accountIds], newest first, up to today (later
/// installments are listed under their card's statements).
List<WalletEntry> entriesOf(WalletData wallet, Set<String> accountIds, DateTime now) {
  final endOfToday = DateTime(now.year, now.month, now.day + 1);
  return [
    for (final tx in wallet.transactions.values)
      if (accountIds.contains(tx.accountId) && tx.occurredAt.isBefore(endOfToday)) WalletEntry.tx(tx),
    for (final transfer in wallet.transfers.values)
      if (accountIds.contains(transfer.fromAccountId) || accountIds.contains(transfer.toAccountId)) WalletEntry.transfer(transfer),
  ]..sort((a, b) => b.at.compareTo(a.at));
}

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    final walletValue = ref.watch(walletProvider);
    final filter = ref.watch(walletFilterProvider);
    final issues = (ref.watch(walletOutboxProvider).value ?? const <WalletOp>[])
        .where((op) => op.state == OutboxState.conflict || op.state == OutboxState.failed)
        .length;
    final now = DateTime.now();

    return ModuleScaffold(
      module: LbModule.wallet,
      title: 'Cüzdan',
      addLabel: 'Hareket',
      addPageBuilder: (context) => const EntryPage(),
      body: walletValue.when(
        // The local mirror opens in a moment; no spinner for that.
        loading: () => const SizedBox.shrink(),
        error: (error, _) => Center(child: Text('Cüzdan açılamadı.', style: TextStyle(color: t.muted))),
        data: (wallet) {
          final all = wallet.accounts.values.where((a) => a.active).toList()..sort(_byTypeThenName);
          final accounts = all.where((a) => _passes(a, filter)).toList();
          final cards = accounts.where((a) => a.isCard).toList();
          final others = accounts.where((a) => !a.isCard).toList();
          final ids = {for (final a in accounts) a.id};
          final entries = entriesOf(wallet, ids, now);
          final anyShared = all.any((a) => a.shared);

          return RefreshIndicator(
            onRefresh: () => ref.read(syncControllerProvider.notifier).syncNow(),
            child: ListView(padding: moduleListPadding(context, hasAddButton: true), children: [
              if (issues > 0) _IssuesBanner(count: issues),
              if (all.isEmpty)
                _EmptyWallet(onAdd: () => _openAccountEditor(context))
              else ...[
                if (anyShared) _FilterChips(filter: filter),
                _Totals(accounts: accounts, wallet: wallet, now: now),
                if (cards.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _Cards(cards: cards, wallet: wallet, now: now),
                ],
                _Payments(
                  payments: wallet.payments.values
                      .where((p) => !p.completed && accounts.any((a) => a.id == p.accountId))
                      .toList()
                    ..sort((a, b) => a.dueAt.compareTo(b.dueAt)),
                  wallet: wallet,
                  now: now,
                ),
                _SectionHeader(
                  title: 'Hesaplar',
                  action: IconButton(
                    tooltip: 'Hesap veya kart ekle',
                    onPressed: () => _openAccountEditor(context),
                    icon: const Icon(Icons.add_card_rounded),
                  ),
                ),
                for (final account in others) _AccountTile(account: account),
                if (others.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('Banka veya nakit hesabı yok.', style: TextStyle(color: t.muted)),
                  ),
                _SectionHeader(
                  title: 'Son hareketler',
                  action: entries.isEmpty ? null : TextButton(onPressed: () => _openEntries(context, ids), child: const Text('Tümünü gör')),
                ),
                if (entries.isEmpty)
                  Text('Henüz hareket yok. Sağ alttan ekleyebilirsin.', style: TextStyle(color: t.muted))
                else
                  _RecentEntries(entries: entries, wallet: wallet, onMore: () => _openEntries(context, ids)),
                _SectionHeader(title: 'Analiz'),
                SpendingTeaser(
                  accountIds: ids,
                  wallet: wallet,
                  now: now,
                  onOpen: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => WalletAnalysisPage(accountIds: ids))),
                ),
              ],
            ]),
          );
        },
      ),
    );
  }

  static int _byTypeThenName(WalletAccount a, WalletAccount b) {
    final byType = a.type.index.compareTo(b.type.index);
    return byType != 0 ? byType : a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }
}

void _openEntries(BuildContext context, Set<String> accountIds) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AllEntriesPage(accountIds: accountIds)));

/// The latest movements; the last few fade out, and tapping those (or
/// "Tümünü gör") opens every movement.
class _RecentEntries extends StatelessWidget {
  const _RecentEntries({required this.entries, required this.wallet, required this.onMore});

  final List<WalletEntry> entries;
  final WalletData wallet;
  final VoidCallback onMore;

  static const _fade = [1.0, 1.0, 1.0, .6, .35, .15];

  @override
  Widget build(BuildContext context) {
    final shown = entries.take(_fade.length).toList();
    final fades = shown.length == entries.length ? 0 : 3;
    return Column(children: [
      for (var i = 0; i < shown.length; i++)
        if (i < shown.length - fades)
          EntryTile(entry: shown[i], wallet: wallet)
        else
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onMore,
            child: IgnorePointer(
              child: ExcludeSemantics(child: Opacity(opacity: _fade[i], child: EntryTile(entry: shown[i], wallet: wallet))),
            ),
          ),
    ]);
  }
}

void _openAccountEditor(BuildContext context, [WalletAccount? account]) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AccountEditPage(initial: account)));

class _EmptyWallet extends StatelessWidget {
  const _EmptyWallet({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    return NeuSurface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.account_balance_wallet_rounded, color: t.module(LbModule.wallet), size: 32),
          const SizedBox(width: 14),
          Expanded(child: Text('Banka hesaplarını, kartlarını ve nakdini ekle; harcamaların hesaplarına işlesin.', style: TextStyle(color: t.muted))),
        ]),
        const SizedBox(height: 14),
        FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add_card_rounded), label: const Text('Hesap veya kart ekle')),
      ]),
    );
  }
}

class _FilterChips extends ConsumerWidget {
  const _FilterChips({required this.filter});
  final WalletFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SegmentedButton<WalletFilter>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: WalletFilter.all, label: Text('Hepsi')),
            ButtonSegment(value: WalletFilter.personal, label: Text('Kişisel')),
            ButtonSegment(value: WalletFilter.shared, label: Text('Ortak')),
          ],
          selected: {filter},
          onSelectionChanged: (value) => ref.read(walletFilterProvider.notifier).state = value.first,
        ),
      );
}

class _Totals extends StatelessWidget {
  const _Totals({required this.accounts, required this.wallet, required this.now});
  final List<WalletAccount> accounts;
  final WalletData wallet;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    final net = accounts.fold<Cents>(0, (sum, a) => sum + a.balance);
    final debt = accounts.fold<Cents>(0, (sum, a) => sum + a.debt);
    final ids = {for (final a in accounts) a.id};
    final monthStart = DateTime(now.year, now.month);
    final spent = wallet.transactions.values
        .where((tx) => ids.contains(tx.accountId) && tx.kind == TxKind.expense && !tx.occurredAt.isBefore(monthStart) && !tx.occurredAt.isAfter(now))
        .fold<Cents>(0, (sum, tx) => sum + tx.amount);
    final estimated = accounts.any((a) => a.sync != SyncMark.confirmed);
    final label = TextStyle(letterSpacing: 1.2, fontWeight: FontWeight.w800, fontSize: 11, color: t.module(LbModule.wallet));

    return NeuSurface(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('NET VARLIK', style: label),
          if (estimated) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: 'Gönderilmeyi bekleyen işlemlerle hesaplandı',
              child: Text('tahmini', style: TextStyle(color: t.muted, fontSize: 12, fontStyle: FontStyle.italic)),
            ),
          ],
        ]),
        const SizedBox(height: 6),
        Text(formatMoney(net),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, color: net < 0 ? t.expense : t.onBase)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _Figure(label: 'Kart borcu', value: formatMoney(debt))),
          Expanded(child: _Figure(label: 'Bu ay gider', value: formatMoney(spent))),
        ]),
      ]),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: t.muted, fontSize: 12, fontWeight: FontWeight.w600)),
      Text(value, style: TextStyle(color: t.onBase, fontWeight: FontWeight.w800, fontSize: 16)),
    ]);
  }
}

class _Cards extends StatefulWidget {
  const _Cards({required this.cards, required this.wallet, required this.now});
  final List<WalletAccount> cards;
  final WalletData wallet;
  final DateTime now;

  @override
  State<_Cards> createState() => _CardsState();
}

class _CardsState extends State<_Cards> {
  final _controller = PageController(viewportFraction: .9);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width - 40;
    final height = width * .9 * 54 / 85.6;
    return Column(children: [
      SizedBox(
        height: height + 16,
        child: PageView.builder(
          controller: _controller,
          padEnds: false,
          itemCount: widget.cards.length,
          onPageChanged: (page) => setState(() => _page = page),
          itemBuilder: (context, index) {
            final card = widget.cards[index];
            return Padding(
              padding: const EdgeInsets.only(right: 12, bottom: 16),
              // Tap turns the card over; the pencil edits it.
              child: SecureCard(
                card: card,
                wallet: widget.wallet,
                now: widget.now,
                onEdit: () => _openAccountEditor(context, card),
              ),
            );
          },
        ),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          icon: const Icon(Icons.receipt_long_rounded, size: 18),
          label: Text('${widget.cards[_page.clamp(0, widget.cards.length - 1)].name} · ekstre ve hareketler'),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => AccountDetailPage(accountId: widget.cards[_page.clamp(0, widget.cards.length - 1)].id),
          )),
        ),
      ),
      if (widget.cards.length > 1)
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < widget.cards.length; i++)
            AnimatedContainer(
              duration: LbTokens.motionShort,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == _page ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == _page ? LbTokens.of(context).module(LbModule.wallet) : LbTokens.of(context).shade,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ]),
    ]);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action});
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 8),
        child: Row(children: [
          Expanded(
            child: Text(title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: LbTokens.of(context).onBase)),
          ),
          ?action,
        ]),
      );
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.account});
  final WalletAccount account;

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AccountDetailPage(accountId: account.id))),
        child: NeuSurface(
          depth: 4,
          radius: LbTokens.radiusSmall + 4,
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(children: [
            Icon(account.type == AccountType.cash ? Icons.payments_rounded : Icons.account_balance_rounded, color: t.module(LbModule.wallet)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(account.name, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: t.onBase))),
                  if (account.shared) Padding(padding: const EdgeInsets.only(left: 6), child: Icon(Icons.group_rounded, size: 16, color: t.muted)),
                ]),
                Text(
                  [account.bank ?? account.type.label, if (account.iban != null) formatIban(account.iban!)].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: t.muted, fontSize: 12),
                ),
              ]),
            ),
            Text(formatMoney(account.balance), style: TextStyle(fontWeight: FontWeight.w800, color: account.balance < 0 ? t.expense : t.onBase)),
            if (account.iban != null)
              IconButton(
                tooltip: 'IBAN kopyala',
                icon: const Icon(Icons.copy_rounded, size: 18),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: account.iban!.replaceAll(' ', '')));
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('IBAN kopyalandı')));
                },
              )
            else
              const SizedBox(width: 8),
          ]),
        ),
      ),
    );
  }
}

/// One movement: category, why, which account, how much, who entered it.
class EntryTile extends ConsumerWidget {
  const EntryTile({super.key, required this.entry, required this.wallet});
  final WalletEntry entry;
  final WalletData wallet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = LbTokens.of(context);
    final members = {for (final m in ref.watch(walletMembersProvider).value ?? const <HouseholdMember>[]) m.userId: m};
    final tx = entry.tx;
    final transfer = entry.transfer;
    final IconData icon;
    final String title;
    final String subtitle;
    final Cents signed;
    final int createdBy;
    final bool shared;
    if (tx != null) {
      final account = wallet.accounts[tx.accountId];
      icon = categoryIcon(tx.category, tx.kind);
      title = tx.kind == TxKind.payment ? 'Kart ödemesi' : categoryLabel(tx.category);
      subtitle = [
        if (tx.note != null) tx.note!,
        account?.name ?? 'Hesap',
        if (tx.installmentCount != null) '${tx.installmentIndex}/${tx.installmentCount} taksit',
      ].join(' · ');
      signed = tx.kind.effect(tx.amount);
      createdBy = tx.createdBy;
      shared = account?.shared ?? false;
    } else {
      final from = wallet.accounts[transfer!.fromAccountId];
      final to = wallet.accounts[transfer.toAccountId];
      final cardPayment = to?.isCard ?? false;
      icon = cardPayment ? Icons.credit_score_rounded : Icons.swap_horiz_rounded;
      title = cardPayment ? 'Kart ödemesi' : 'Transfer';
      subtitle = [if (transfer.note != null) transfer.note!, '${from?.name ?? 'Diğer hesap'} → ${to?.name ?? 'Diğer hesap'}'].join(' · ');
      signed = 0;
      createdBy = transfer.createdBy;
      shared = (from?.shared ?? false) || (to?.shared ?? false);
    }
    final author = shared && members.length > 1 ? members[createdBy] : null;
    final amountColor = signed > 0 ? t.income : t.onBase;

    return Opacity(
      opacity: entry.sync == SyncMark.pending ? .6 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(LbTokens.radiusSmall),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => EntryDetailPage(entryId: entry.id))),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            Stack(clipBehavior: Clip.none, children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: t.module(LbModule.wallet).withValues(alpha: .14), shape: BoxShape.circle),
                child: Icon(icon, color: t.module(LbModule.wallet), size: 22),
              ),
              if (author != null)
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Tooltip(
                    message: '${author.name} girdi',
                    child: CircleAvatar(
                      radius: 10,
                      backgroundColor: t.base,
                      child: CircleAvatar(
                        radius: 9,
                        backgroundColor: author.isMe ? t.module(LbModule.wallet) : t.accent,
                        child: Text(author.initials, style: TextStyle(fontSize: 8, color: t.onAccent, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                ),
            ]),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: t.onBase)),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.muted, fontSize: 12)),
              ]),
            ),
            const SizedBox(width: 8),
            syncBadge(context, entry.sync),
            const SizedBox(width: 4),
            Text(
              tx == null ? formatMoney(transfer!.amount) : '${signed > 0 ? '+' : '−'}${formatMoney(tx.amount)}',
              style: TextStyle(fontWeight: FontWeight.w800, color: amountColor, fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Planned payments still to pay, soonest (or most overdue) first.
class _Payments extends ConsumerWidget {
  const _Payments({required this.payments, required this.wallet, required this.now});
  final List<ScheduledPayment> payments;
  final WalletData wallet;
  final DateTime now;

  void _open(BuildContext context, [ScheduledPayment? payment]) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PaymentEditPage(initial: payment)));

  Future<void> _pay(BuildContext context, WidgetRef ref, ScheduledPayment payment) async {
    final from = wallet.accounts[payment.accountId]?.name ?? 'hesap';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${payment.title} ödendi mi?'),
        content: Text(
          '${formatMoney(payment.amount)} $from hesabından ${payment.isTransfer ? 'karta ödeme' : 'gider'} olarak kaydedilir.'
          '${payment.repeatMonthly ? ' Sonraki ödeme ${DateFormat('d MMMM', 'tr_TR').format(addMonths(payment.dueAt, 1))}.' : ''}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Ödendi')),
        ],
      ),
    );
    if (confirmed == true) await ref.read(walletRepositoryProvider).completePayment(payment);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = LbTokens.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _SectionHeader(
        title: 'Ödemeler',
        action: IconButton(tooltip: 'Planlı ödeme ekle', onPressed: () => _open(context), icon: const Icon(Icons.event_repeat_rounded)),
      ),
      if (payments.isEmpty)
        Text('Kira, fatura gibi düzenli ödemeleri ekle; zamanı gelince hatırlatırım.', style: TextStyle(color: t.muted)),
      for (final payment in payments)
        Opacity(
          opacity: payment.sync == SyncMark.pending ? .6 : 1,
          child: InkWell(
            borderRadius: BorderRadius.circular(LbTokens.radiusSmall),
            onTap: () => _open(context, payment),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: t.module(LbModule.wallet).withValues(alpha: .14), shape: BoxShape.circle),
                  child: Icon(payment.isTransfer ? Icons.credit_score_rounded : Icons.event_repeat_rounded, color: t.module(LbModule.wallet), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(payment.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: t.onBase)),
                    Text(
                      [dueLabel(payment.dueAt, now), formatMoney(payment.amount), if (payment.repeatMonthly) 'her ay'].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: payment.dueAt.isBefore(DateUtils.dateOnly(now)) ? t.expense : t.muted,
                        fontSize: 12,
                        fontWeight: payment.dueAt.isBefore(DateUtils.dateOnly(now)) ? FontWeight.w700 : null,
                      ),
                    ),
                  ]),
                ),
                syncBadge(context, payment.sync),
                const SizedBox(width: 4),
                FilledButton.tonal(onPressed: () => _pay(context, ref, payment), child: const Text('Ödendi')),
              ]),
            ),
          ),
        ),
    ]);
  }
}

class _IssuesBanner extends StatelessWidget {
  const _IssuesBanner({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NeuSurface(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFE09B2D)),
          const SizedBox(width: 12),
          Expanded(child: Text('$count işlem senin kararını bekliyor', style: TextStyle(color: t.onBase, fontWeight: FontWeight.w600))),
          TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const OutboxIssuesPage())),
            child: const Text('Gör'),
          ),
        ]),
      ),
    );
  }
}
