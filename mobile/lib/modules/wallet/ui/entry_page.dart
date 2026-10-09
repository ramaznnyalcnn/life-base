import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/design_system/add_page_scaffold.dart';
import '../../../core/design_system/neu.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/wallet/statements.dart';
import '../../../core/wallet/wallet_models.dart';
import '../../../core/wallet/wallet_outbox.dart';
import '../../../core/wallet/wallet_store.dart';
import '../data/wallet_repository.dart';
import 'wallet_format.dart';

enum EntryType {
  expense('Gider'),
  income('Gelir'),
  transfer('Transfer'),
  cardPayment('Kart ödemesi');

  const EntryType(this.label);
  final String label;
}

/// The wallet's own add/edit flow: amount on a big keypad, then the details.
class EntryPage extends ConsumerStatefulWidget {
  const EntryPage({super.key, this.initialTx, this.initialTransfer, this.initialType, this.initialAccountId});

  final WalletTransaction? initialTx;
  final WalletTransfer? initialTransfer;
  final EntryType? initialType;
  final String? initialAccountId;

  @override
  ConsumerState<EntryPage> createState() => _EntryPageState();
}

class _EntryPageState extends ConsumerState<EntryPage> {
  late EntryType _type;
  String _amount = '';
  int _step = 0;
  String? _accountId;
  String? _toAccountId;
  int? _categoryId;
  DateTime _at = DateTime.now();
  int _installments = 1;
  final _note = TextEditingController();
  late final String _id;
  late final String _snapshot;

  String get _signature => [_type, _amount, _accountId, _toAccountId, _categoryId, _at, _installments, _note.text].join('|');

  bool get _editing => widget.initialTx != null || widget.initialTransfer != null;
  bool get _isTransfer => _type == EntryType.transfer || _type == EntryType.cardPayment;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(walletRepositoryProvider);
    final tx = widget.initialTx;
    final transfer = widget.initialTransfer;
    final wallet = ref.read(walletProvider).value;
    if (tx != null) {
      final parts = wallet?.transactions.values.where((t) => t.groupId == tx.groupId).toList() ?? [tx];
      _id = tx.groupId;
      _type = tx.kind == TxKind.income ? EntryType.income : EntryType.expense;
      _amount = _plain(parts.fold<Cents>(0, (sum, t) => sum + t.amount));
      _accountId = tx.accountId;
      _categoryId = tx.categoryId;
      _at = parts.map((t) => t.occurredAt).reduce((a, b) => a.isBefore(b) ? a : b);
      _installments = tx.installmentCount ?? 1;
      _note.text = tx.note ?? '';
      _step = 1;
    } else if (transfer != null) {
      _id = transfer.id;
      final toCard = wallet?.accounts[transfer.toAccountId]?.isCard ?? false;
      _type = toCard ? EntryType.cardPayment : EntryType.transfer;
      _amount = _plain(transfer.amount);
      _accountId = transfer.fromAccountId;
      _toAccountId = transfer.toAccountId;
      _at = transfer.occurredAt;
      _note.text = transfer.note ?? '';
      _step = 1;
    } else {
      _id = repo.newId();
      _type = widget.initialType ?? EntryType.expense;
      _accountId = widget.initialAccountId;
      if (_type == EntryType.cardPayment) _toAccountId = widget.initialAccountId;
    }
    _snapshot = _editing ? _signature : '';
    _note.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  static String _plain(Cents cents) => decimalOf(cents).replaceAll('.', ',').replaceAll(RegExp(r',00$'), '');

  Cents get _cents => parseCents(_amount) ?? 0;

  void _key(String key) {
    HapticFeedback.selectionClick();
    setState(() {
      if (key == '⌫') {
        if (_amount.isNotEmpty) _amount = _amount.substring(0, _amount.length - 1);
        return;
      }
      if (key == ',') {
        if (!_amount.contains(',')) _amount = _amount.isEmpty ? '0,' : '$_amount,';
        return;
      }
      final decimals = _amount.contains(',') ? _amount.length - _amount.indexOf(',') - 1 : 0;
      if (decimals >= 2 || (_amount.replaceAll(',', '').length >= 10)) return;
      _amount = _amount == '0' ? key : _amount + key;
    });
  }

  /// Sensible defaults once the accounts are known.
  void _defaults(WalletData wallet, List<WalletAccount> accounts) {
    if (_accountId != null && wallet.accounts[_accountId] != null && !(_type == EntryType.cardPayment && _accountId == _toAccountId)) return;
    final sources = _type == EntryType.cardPayment ? accounts.where((a) => !a.isCard) : accounts;
    final recent = wallet.transactions.values.toList()..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final last = recent.where((t) => sources.any((a) => a.id == t.accountId)).firstOrNull?.accountId;
    _accountId = last ?? sources.firstOrNull?.id;
  }

  String? _problem(WalletData wallet) {
    if (_cents <= 0) return 'Tutar gir';
    if (_accountId == null || wallet.accounts[_accountId] == null) return 'Hesap seç';
    if (_isTransfer) {
      if (_toAccountId == null) return _type == EntryType.cardPayment ? 'Ödenecek kartı seç' : 'Hedef hesabı seç';
      if (_toAccountId == _accountId) return 'Kaynak ve hedef aynı olamaz';
    }
    return null;
  }

  Future<void> _save(WalletData wallet) async {
    final problem = _problem(wallet);
    if (problem != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    final repo = ref.read(walletRepositoryProvider);
    final account = wallet.accounts[_accountId]!;
    if (_isTransfer) {
      await repo.saveTransfer(
        id: _id,
        fromAccountId: _accountId!,
        toAccountId: _toAccountId!,
        amount: _cents,
        occurredAt: _at,
        note: _note.text,
        previous: widget.initialTransfer,
      );
    } else {
      await repo.saveTransaction(
        id: _id,
        accountId: _accountId!,
        kind: _type == EntryType.income ? TxKind.income : TxKind.expense,
        amount: _cents,
        occurredAt: _at,
        categoryId: _categoryId,
        note: _note.text,
        installments: account.isCard && _type == EntryType.expense ? _installments : 1,
        previous: widget.initialTx,
      );
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider).value ?? const WalletData();
    final accounts = wallet.accounts.values.where((a) => a.active).toList()..sort((a, b) => a.name.compareTo(b.name));
    _defaults(wallet, accounts);
    final dirty = _editing ? _signature != _snapshot : _amount.isNotEmpty;
    return AddPageScaffold(
      title: _editing ? 'Hareketi düzenle' : 'Yeni hareket',
      dirty: dirty,
      onSave: _step == 1 ? () => _save(wallet) : null,
      body: accounts.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Önce Cüzdan ekranından bir hesap veya kart ekle.', style: TextStyle(color: LbTokens.of(context).muted)),
            )
          : _step == 0
              ? _amountStep(context)
              : _details(context, wallet, accounts),
    );
  }

  Widget _typeChips() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(children: [
          for (final type in EntryType.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(type.label),
                selected: _type == type,
                onSelected: _editing && (type == EntryType.transfer || type == EntryType.cardPayment) != _isTransfer
                    ? null
                    : (_) => setState(() {
                          _type = type;
                          _categoryId = null;
                          if (type == EntryType.cardPayment) _toAccountId = null;
                        }),
              ),
            ),
        ]),
      );

  Widget _amountStep(BuildContext context) {
    final t = LbTokens.of(context);
    return Column(children: [
      const SizedBox(height: 8),
      _typeChips(),
      Expanded(
        child: Center(
          child: Semantics(
            liveRegion: true,
            label: 'Tutar ${formatMoney(_cents)}',
            child: FittedBox(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _amount.isEmpty ? '₺0' : '₺$_amount',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: _amount.isEmpty ? t.muted : (_type == EntryType.income ? t.income : t.onBase),
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Column(children: [
          for (final row in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
            [',', '0', '⌫'],
          ])
            Row(children: [
              for (final key in row)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: NeuButton(
                      semanticLabel: key == '⌫' ? 'Sil' : (key == ',' ? 'Virgül' : key),
                      radius: 18,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      onPressed: () => _key(key),
                      child: Center(
                        child: key == '⌫'
                            ? const Icon(Icons.backspace_outlined)
                            : Text(key, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ),
            ]),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                backgroundColor: t.module(LbModule.wallet),
                foregroundColor: t.onAccent,
              ),
              onPressed: _cents > 0 ? () => setState(() => _step = 1) : null,
              child: const Text('Devam', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ),
          SizedBox(height: MediaQuery.paddingOf(context).bottom),
        ]),
      ),
    ]);
  }

  Widget _details(BuildContext context, WalletData wallet, List<WalletAccount> accounts) {
    final t = LbTokens.of(context);
    final account = wallet.accounts[_accountId];
    final categories = (ref.watch(walletCategoriesProvider).value ?? const <WalletCategory>[])
        .where((c) => c.kind == (_type == EntryType.income ? TxKind.income : TxKind.expense))
        .toList();
    final sources = _type == EntryType.cardPayment ? accounts.where((a) => !a.isCard).toList() : accounts;
    final targets = _type == EntryType.cardPayment
        ? accounts.where((a) => a.isCard).toList()
        : accounts.where((a) => a.id != _accountId).toList();
    final reasons = _recentReasons(wallet);
    final canSplit = !_isTransfer && _type == EntryType.expense && (account?.isCard ?? false);

    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 8),
          child: Text(text, style: TextStyle(color: t.muted, fontWeight: FontWeight.w700)),
        );

    return ListView(padding: const EdgeInsets.fromLTRB(0, 8, 0, 40), children: [
      _typeChips(),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(LbTokens.radiusSmall),
            onTap: () => setState(() => _step = 0),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Text(formatMoney(_cents),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: _type == EntryType.income ? t.income : t.onBase,
                        )),
                const SizedBox(width: 8),
                Icon(Icons.edit_rounded, size: 18, color: t.muted),
              ]),
            ),
          ),
          label(_isTransfer ? 'Nereden' : 'Hesap / kart'),
          _AccountChips(accounts: sources, selected: _accountId, onSelected: (id) => setState(() => _accountId = id)),
          if (_isTransfer) ...[
            label(_type == EntryType.cardPayment ? 'Hangi kart' : 'Nereye'),
            _AccountChips(accounts: targets, selected: _toAccountId, onSelected: (id) => setState(() => _toAccountId = id)),
            if (_type == EntryType.cardPayment && _toAccountId != null) _paymentSuggestions(wallet),
          ],
          if (!_isTransfer) ...[
            label('Kategori'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final category in categories)
                ChoiceChip(
                  avatar: Icon(categoryIcon(category.name, category.kind), size: 18),
                  label: Text(categoryLabel(category.name)),
                  selected: _categoryId == category.id,
                  onSelected: (on) => setState(() => _categoryId = on ? category.id : null),
                ),
              if (categories.isEmpty) Text('Kategoriler ilk eşitlemeden sonra gelir.', style: TextStyle(color: t.muted)),
            ]),
          ],
          label('Ne zaman'),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today_rounded, size: 18),
                label: Text(DateFormat('d MMMM y', 'tr_TR').format(_at)),
                onPressed: () async {
                  final picked = await showDatePicker(context: context, initialDate: _at, firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (picked != null) setState(() => _at = DateTime(picked.year, picked.month, picked.day, _at.hour, _at.minute));
                },
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.schedule_rounded, size: 18),
              label: Text(DateFormat('HH:mm').format(_at)),
              onPressed: () async {
                final picked = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_at));
                if (picked != null) setState(() => _at = DateTime(_at.year, _at.month, _at.day, picked.hour, picked.minute));
              },
            ),
          ]),
          label(_isTransfer ? 'Not (isteğe bağlı)' : 'Neden? (isteğe bağlı)'),
          TextField(
            controller: _note,
            maxLength: 500,
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: _isTransfer ? 'örn. Kira payı' : 'örn. Haftalık alışveriş', counterText: ''),
          ),
          if (reasons.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                for (final reason in reasons)
                  ActionChip(label: Text(reason), onPressed: () => _note.text = reason),
              ]),
            ),
          if (canSplit) ...[
            label('Taksit'),
            Row(children: [
              IconButton.filledTonal(
                tooltip: 'Azalt',
                onPressed: _installments > 1 ? () => setState(() => _installments--) : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              Expanded(
                child: Text(
                  _installments == 1 ? 'Tek çekim' : '$_installments taksit · ${formatMoney(splitCents(_cents, _installments).last)} / ay',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w800, color: t.onBase),
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Artır',
                onPressed: _installments < 36 ? () => setState(() => _installments++) : null,
                icon: const Icon(Icons.add_rounded),
              ),
            ]),
            if (_installments > 1)
              Text('Her taksit sonraki ekstrelere ayrı kayıt olarak düşer.', style: TextStyle(color: t.muted, fontSize: 12)),
          ],
        ]),
      ),
    ]);
  }

  /// Reasons used before in this category (or account, for transfers), newest first.
  List<String> _recentReasons(WalletData wallet) {
    final seen = <String>{};
    final source = _isTransfer
        ? (wallet.transfers.values.toList()..sort((a, b) => b.occurredAt.compareTo(a.occurredAt))).map((t) => t.note)
        : (wallet.transactions.values.where((t) => _categoryId == null || t.categoryId == _categoryId).toList()
              ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt)))
            .map((t) => t.note);
    for (final note in source) {
      if (note != null && note.trim().isNotEmpty && note != _note.text) seen.add(note.trim());
      if (seen.length == 5) break;
    }
    return seen.toList();
  }

  Widget _paymentSuggestions(WalletData wallet) {
    final card = wallet.accounts[_toAccountId]!;
    final due = upcomingDue(card, wallet, DateTime.now());
    final options = <(String, Cents)>[
      if (due != null) ('Dönem borcu', due.remaining),
      if (card.debt > 0) ('Toplam borç', card.debt),
    ];
    if (options.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(spacing: 8, children: [
        for (final (label, cents) in options)
          ActionChip(label: Text('$label ${formatMoney(cents)}'), onPressed: () => setState(() => _amount = _plain(cents))),
      ]),
    );
  }
}

class _AccountChips extends StatelessWidget {
  const _AccountChips({required this.accounts, required this.selected, required this.onSelected});
  final List<WalletAccount> accounts;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final account in accounts)
          ChoiceChip(
            avatar: Icon(
              account.isCard ? Icons.credit_card_rounded : (account.type == AccountType.cash ? Icons.payments_rounded : Icons.account_balance_rounded),
              size: 18,
            ),
            label: Text(account.last4 == null ? account.name : '${account.name} ·${account.last4}'),
            selected: selected == account.id,
            onSelected: (_) => onSelected(account.id),
          ),
        if (accounts.isEmpty) Text('Uygun hesap yok.', style: TextStyle(color: LbTokens.of(context).muted)),
      ]);
}
