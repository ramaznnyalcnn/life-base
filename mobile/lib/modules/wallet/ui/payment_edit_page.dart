import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/design_system/add_page_scaffold.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/wallet/payment_reminders.dart';
import '../../../core/wallet/statements.dart';
import '../../../core/wallet/wallet_models.dart';
import '../../../core/wallet/wallet_outbox.dart';
import '../../../core/wallet/wallet_store.dart';
import '../data/wallet_repository.dart';
import 'entry_page.dart';
import 'wallet_format.dart';

/// Add or edit a planned payment (rent, a bill, a card's statement).
class PaymentEditPage extends ConsumerStatefulWidget {
  const PaymentEditPage({super.key, this.initial});

  final ScheduledPayment? initial;

  @override
  ConsumerState<PaymentEditPage> createState() => _PaymentEditPageState();
}

class _PaymentEditPageState extends ConsumerState<PaymentEditPage> {
  final _title = TextEditingController();
  final _amount = TextEditingController();
  bool _cardPayment = false;
  String? _accountId;
  String? _toAccountId;
  int? _categoryId;
  late DateTime _due;
  bool _monthly = true;
  late final String _id;
  late final String _snapshot;

  ScheduledPayment? get _initial => widget.initial;

  String get _signature => [_title.text, _amount.text, _cardPayment, _accountId, _toAccountId, _categoryId, _due, _monthly].join('|');

  @override
  void initState() {
    super.initState();
    final p = _initial;
    final now = DateTime.now();
    if (p != null) {
      _id = p.id;
      _title.text = p.title;
      _amount.text = decimalOf(p.amount).replaceAll('.', ',').replaceAll(RegExp(r',00$'), '');
      _cardPayment = p.isTransfer;
      _accountId = p.accountId;
      _toAccountId = p.toAccountId;
      _categoryId = p.categoryId;
      _due = p.dueAt;
      _monthly = p.repeatMonthly;
    } else {
      _id = ref.read(walletRepositoryProvider).newId();
      _due = DateTime(now.year, now.month, now.day + 1, paymentReminderHour);
    }
    _snapshot = _signature;
    _title.addListener(() => setState(() {}));
    _amount.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  Cents get _cents => parseCents(_amount.text) ?? 0;

  String? _problem(WalletData wallet) {
    if (_title.text.trim().isEmpty) return 'Ödemeye bir ad ver';
    if (_cents <= 0) return 'Tutar gir';
    if (_accountId == null || wallet.accounts[_accountId] == null) return 'Hangi hesaptan ödeneceğini seç';
    if (_cardPayment && _toAccountId == null) return 'Ödenecek kartı seç';
    return null;
  }

  Future<void> _save(WalletData wallet) async {
    final problem = _problem(wallet);
    if (problem != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    await ref.read(walletRepositoryProvider).savePayment(
          id: _id,
          title: _title.text,
          accountId: _accountId!,
          toAccountId: _cardPayment ? _toAccountId : null,
          categoryId: _cardPayment ? null : _categoryId,
          amount: _cents,
          dueAt: _due,
          repeatMonthly: _monthly,
          previous: _initial,
        );
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Planlı ödeme silinsin mi?'),
        content: const Text('Geçmişte yapılan ödemeler hareketlerde kalır.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Sil')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(walletRepositoryProvider).deletePayment(_initial!);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    final wallet = ref.watch(walletProvider).value ?? const WalletData();
    final accounts = wallet.accounts.values.where((a) => a.active).toList()..sort((a, b) => a.name.compareTo(b.name));
    final sources = _cardPayment ? accounts.where((a) => !a.isCard).toList() : accounts;
    final cards = accounts.where((a) => a.isCard).toList();
    _accountId ??= sources.firstOrNull?.id;
    final categories = (ref.watch(walletCategoriesProvider).value ?? const <WalletCategory>[])
        .where((c) => c.kind == TxKind.expense)
        .toList();

    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 8),
          child: Text(text, style: TextStyle(color: t.muted, fontWeight: FontWeight.w700)),
        );

    return AddPageScaffold(
      title: _initial == null ? 'Planlı ödeme' : 'Ödemeyi düzenle',
      dirty: _signature != _snapshot,
      onSave: accounts.isEmpty ? null : () => _save(wallet),
      body: accounts.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Önce Cüzdan ekranından bir hesap veya kart ekle.', style: TextStyle(color: t.muted)),
            )
          : ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 40), children: [
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: false, label: Text('Gider'), icon: Icon(Icons.receipt_long_rounded)),
                  ButtonSegment(value: true, label: Text('Kart ödemesi'), icon: Icon(Icons.credit_score_rounded)),
                ],
                selected: {_cardPayment},
                onSelectionChanged: (value) => setState(() {
                  _cardPayment = value.first;
                  if (_cardPayment && (wallet.accounts[_accountId]?.isCard ?? false)) _accountId = null;
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _title,
                maxLength: 120,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: 'Ne ödenecek?', hintText: _cardPayment ? 'örn. Bonus ekstresi' : 'örn. Kira, elektrik', counterText: ''),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Tutar', prefixText: '₺ '),
              ),
              if (_cardPayment && _toAccountId != null) _dueSuggestion(wallet),
              label(_cardPayment ? 'Hangi kart' : 'Kategori (isteğe bağlı)'),
              if (_cardPayment)
                AccountChips(accounts: cards, selected: _toAccountId, onSelected: (id) => setState(() => _toAccountId = id))
              else
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final category in categories)
                    ChoiceChip(
                      avatar: Icon(categoryIcon(category.name, category.kind), size: 18),
                      label: Text(categoryLabel(category.name)),
                      selected: _categoryId == category.id,
                      onSelected: (on) => setState(() => _categoryId = on ? category.id : null),
                    ),
                ]),
              label('Nereden ödenecek'),
              AccountChips(accounts: sources, selected: _accountId, onSelected: (id) => setState(() => _accountId = id)),
              label('Son ödeme günü'),
              OutlinedButton.icon(
                icon: const Icon(Icons.event_rounded, size: 18),
                label: Text(DateFormat('d MMMM y, EEEE', 'tr_TR').format(_due)),
                onPressed: () async {
                  final picked = await showDatePicker(context: context, initialDate: _due, firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (picked != null) setState(() => _due = DateTime(picked.year, picked.month, picked.day, paymentReminderHour));
                },
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Her ay'),
                subtitle: Text(_monthly ? 'Ödendi deyince bir sonraki aya geçer' : 'Bir kerelik ödeme'),
                value: _monthly,
                onChanged: (on) => setState(() => _monthly = on),
              ),
              Text('Bir gün önce ve son gün saat 09:00\'da hatırlatılır.', style: TextStyle(color: t.muted, fontSize: 12)),
              if (_initial != null) ...[
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Planlı ödemeyi sil'),
                  style: OutlinedButton.styleFrom(foregroundColor: t.expense),
                  onPressed: _delete,
                ),
              ],
            ]),
    );
  }

  Widget _dueSuggestion(WalletData wallet) {
    final card = wallet.accounts[_toAccountId];
    final due = card == null ? null : upcomingDue(card, wallet, DateTime.now());
    if (due == null || due.remaining <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(spacing: 8, children: [
        ActionChip(
          label: Text('Dönem borcu ${formatMoney(due.remaining)}'),
          onPressed: () => setState(() {
            _amount.text = decimalOf(due.remaining).replaceAll('.', ',');
            _due = DateTime(due.due!.year, due.due!.month, due.due!.day, paymentReminderHour);
          }),
        ),
      ]),
    );
  }
}
