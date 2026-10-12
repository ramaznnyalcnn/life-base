import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/add_page_scaffold.dart';
import '../../../core/design_system/neu.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/platform/platform_bridge.dart';
import '../../../core/providers.dart';
import '../../../core/wallet/card_secrets.dart';
import '../../../core/wallet/wallet_models.dart';
import '../../../core/wallet/wallet_outbox.dart';
import '../../../core/wallet/wallet_store.dart';
import '../data/wallet_repository.dart';
import 'card_face.dart';
import 'wallet_format.dart';

const _banks = ['Ziraat', 'İş Bankası', 'Garanti BBVA', 'Yapı Kredi', 'Akbank', 'QNB', 'Enpara', 'Halkbank', 'VakıfBank', 'DenizBank', 'TEB', 'ING'];

/// Add or edit an account, bank account or credit card.
class AccountEditPage extends ConsumerStatefulWidget {
  const AccountEditPage({super.key, this.initial, this.initialType});

  final WalletAccount? initial;
  final AccountType? initialType;

  @override
  ConsumerState<AccountEditPage> createState() => _AccountEditPageState();
}

class _AccountEditPageState extends ConsumerState<AccountEditPage> {
  late AccountType _type;
  late final TextEditingController _name;
  late final TextEditingController _bank;
  late final TextEditingController _balance;
  late final TextEditingController _limit;
  late final TextEditingController _last4;
  late final TextEditingController _iban;
  late String _color;
  String? _network;
  int? _statementDay;
  int? _dueDay;
  late bool _shared;
  late final String _id;
  late final String _snapshot;

  // Card details: only on this device. An existing card's are loaded after unlocking.
  final _number = TextEditingController();
  final _expiry = TextEditingController();
  final _cvv = TextEditingController();
  final _holder = TextEditingController();
  final _phone = TextEditingController();
  late bool _secretsOpen;
  CardSecrets? _storedSecrets;
  bool _secureScreen = false;
  // Read up front: ref is gone by dispose, when screenshots must be allowed again.
  late final PlatformBridge _bridge;

  WalletAccount? get _initial => widget.initial;
  bool get _isNew => _initial == null;
  bool get _isCard => _type == AccountType.creditCard;

  @override
  void initState() {
    super.initState();
    final a = _initial;
    _id = a?.id ?? ref.read(walletRepositoryProvider).newId();
    _type = a?.type ?? widget.initialType ?? AccountType.bank;
    _name = TextEditingController(text: a?.name ?? '');
    _bank = TextEditingController(text: a?.bank ?? '');
    // Cards are edited as "current debt", everything else as "current balance".
    final shown = a == null ? 0 : (a.isCard ? -a.balance : a.balance);
    _balance = TextEditingController(text: a == null ? '' : _plain(shown));
    _limit = TextEditingController(text: a?.limit == null ? '' : _plain(a!.limit!));
    _last4 = TextEditingController(text: a?.last4 ?? '');
    _iban = TextEditingController(text: a?.iban == null ? '' : formatIban(a!.iban!));
    _color = a?.color ?? 'aurora';
    _network = a?.network;
    _statementDay = a?.statementDay;
    _dueDay = a?.dueDay;
    _shared = a?.shared ?? false;
    _bridge = ref.read(platformBridgeProvider);
    _secretsOpen = a == null;
    for (final c in [_name, _bank, _balance, _limit, _last4, _iban, ..._secretFields]) {
      c.addListener(() => setState(() {}));
    }
    _number.addListener(_numberChanged);
    _snapshot = _signature;
  }

  @override
  void dispose() {
    for (final c in [_name, _bank, _balance, _limit, _last4, _iban, ..._secretFields]) {
      c.dispose();
    }
    if (_secureScreen) unawaited(_bridge.setSecure(false).catchError((Object _) {}));
    super.dispose();
  }

  List<TextEditingController> get _secretFields => [_number, _expiry, _cvv, _holder, _phone];

  String get _digits => _number.text.replaceAll(RegExp(r'\D'), '');

  /// The full number fills in the last four digits, and the screen stops
  /// allowing screenshots while card details are typed.
  void _numberChanged() {
    final digits = _digits;
    if (digits.length >= 12 && _last4.text != digits.substring(digits.length - 4)) {
      _last4.text = digits.substring(digits.length - 4);
    }
    if (digits.isNotEmpty) _hideFromScreenshots();
  }

  void _hideFromScreenshots() {
    if (_secureScreen) return;
    _secureScreen = true;
    unawaited(_bridge.setSecure(true).catchError((Object _) {}));
  }

  Future<void> _unlockSecrets() async {
    final problem = await ref.read(cardUnlockerProvider).unlock('${_initial!.name} kart bilgilerini düzenle');
    if (!mounted) return;
    if (problem != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    final secrets = await ref.read(cardSecretsStoreProvider).read(_id);
    if (!mounted) return;
    _hideFromScreenshots();
    setState(() {
      _storedSecrets = secrets;
      _secretsOpen = true;
      _number.text = secrets?.groupedNumber ?? '';
      _expiry.text = secrets?.expiry ?? '';
      _cvv.text = secrets?.cvv ?? '';
      _holder.text = secrets?.holder ?? '';
      _phone.text = secrets?.supportPhone ?? '';
    });
  }

  CardSecrets? get _typedSecrets {
    if (_digits.isEmpty) return null;
    String? optional(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    return CardSecrets(number: _digits, expiry: optional(_expiry), cvv: optional(_cvv), holder: optional(_holder), supportPhone: optional(_phone));
  }

  static String _plain(Cents cents) => decimalOf(cents).replaceAll('.', ',').replaceAll(RegExp(r',00$'), '');

  String get _signature =>
      [_type, _name.text, _bank.text, _balance.text, _limit.text, _last4.text, _iban.text, _color, _network, _statementDay, _dueDay, _shared,
        for (final c in _secretFields) c.text].join('|');

  String? get _problem {
    if (_name.text.trim().isEmpty) return 'Hesap adı gerekli';
    if (_balance.text.trim().isNotEmpty && parseCents(_balance.text) == null) return 'Bakiye bir sayı olmalı';
    if (_isCard) {
      if (_limit.text.trim().isNotEmpty && (parseCents(_limit.text) ?? -1) < 0) return 'Limit bir sayı olmalı';
      if (_last4.text.isNotEmpty && _last4.text.length != 4) return 'Son 4 hane eksik';
      if (_secretsOpen && _digits.isNotEmpty) {
        if (_digits.length < 12 || _digits.length > 19) return 'Kart numarası 12–19 hane olmalı';
        if (_expiry.text.isNotEmpty && !RegExp(r'^(0[1-9]|1[0-2])/\d{2}$').hasMatch(_expiry.text)) return 'SKT AA/YY biçiminde olmalı';
        if (_cvv.text.isNotEmpty && !RegExp(r'^\d{3,4}$').hasMatch(_cvv.text)) return 'CVV 3 ya da 4 hane olmalı';
      } else if (_secretsOpen && [_expiry, _cvv, _holder, _phone].any((c) => c.text.trim().isNotEmpty)) {
        return 'Kart bilgileri için kart numarasını da gir';
      }
    }
    final iban = _iban.text.replaceAll(' ', '');
    if (_type == AccountType.bank && iban.isNotEmpty && !RegExp(r'^TR\d{24}$').hasMatch(iban.toUpperCase())) {
      return 'IBAN TR ile başlayan 26 karakter olmalı';
    }
    return null;
  }

  AccountDraft get _draft {
    final entered = parseCents(_balance.text) ?? 0;
    final current = _isCard ? -entered : entered;
    // The typed figure is today's balance; keep history and move the opening.
    final opening = _initial == null ? current : _initial!.opening + (current - _initial!.balance);
    final iban = _iban.text.replaceAll(' ', '').toUpperCase();
    return AccountDraft(
      id: _id,
      name: _name.text,
      type: _type,
      bank: _bank.text.trim().isEmpty ? null : _bank.text.trim(),
      shared: _shared,
      opening: opening,
      limit: _isCard && _limit.text.trim().isNotEmpty ? parseCents(_limit.text) : null,
      statementDay: _isCard ? _statementDay : null,
      dueDay: _isCard ? _dueDay : null,
      last4: _isCard && _last4.text.length == 4 ? _last4.text : null,
      network: _isCard ? _network : null,
      color: _color,
      iban: _type == AccountType.bank && iban.isNotEmpty ? iban : null,
    );
  }

  Future<void> _save() async {
    final problem = _problem;
    if (problem != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    await ref.read(walletRepositoryProvider).saveAccount(_draft, expectedVersion: _initial?.version);
    final secrets = _typedSecrets;
    if (_isCard && _secretsOpen && secrets != _storedSecrets) {
      await ref.read(cardSecretsStoreProvider).write(_id, secrets);
      ref.invalidate(hasCardSecretsProvider(_id));
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _archive() async {
    final account = _initial!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(account.active ? 'Hesap arşivlensin mi?' : 'Hesap geri açılsın mı?'),
        content: Text(account.active ? '${account.name} listeden kalkar; geçmiş hareketleri korunur.' : account.name),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(account.active ? 'Arşivle' : 'Geri aç')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(walletRepositoryProvider).archiveAccount(account, archived: account.active);
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Widget _secretsSection(BuildContext context) {
    final t = LbTokens.of(context);
    final header = Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 4),
      child: Row(children: [
        Icon(Icons.lock_rounded, size: 16, color: t.muted),
        const SizedBox(width: 6),
        Flexible(child: Text('Kart bilgileri (sadece bu cihazda)', style: TextStyle(color: t.muted, fontWeight: FontWeight.w700))),
      ]),
    );
    if (!_secretsOpen) {
      final stored = ref.watch(hasCardSecretsProvider(_id)).value ?? false;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        header,
        Row(children: [
          Expanded(child: Text(stored ? 'Kayıtlı. Değiştirmek için kilidi aç.' : 'Kayıtlı değil.', style: TextStyle(color: t.muted))),
          TextButton.icon(
            icon: Icon(stored ? Icons.fingerprint_rounded : Icons.add_rounded),
            label: Text(stored ? 'Kilidi aç' : 'Ekle'),
            onPressed: stored ? _unlockSecrets : () => setState(() => _secretsOpen = true),
          ),
        ]),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      header,
      Text('Tam numara, SKT ve CVV telefonda şifreli durur, sunucuya gitmez. Kartın arka yüzünde parmak izinle görünür.',
          style: TextStyle(color: t.muted, fontSize: 12)),
      const SizedBox(height: 8),
      TextField(
        controller: _number,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')), LengthLimitingTextInputFormatter(23)],
        decoration: const InputDecoration(labelText: 'Kart numarası'),
      ),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: TextField(
            controller: _expiry,
            keyboardType: TextInputType.datetime,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')), LengthLimitingTextInputFormatter(5)],
            decoration: const InputDecoration(labelText: 'SKT', hintText: 'AA/YY'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _cvv,
            keyboardType: TextInputType.number,
            obscureText: true,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
            decoration: const InputDecoration(labelText: 'CVV'),
          ),
        ),
      ]),
      const SizedBox(height: 8),
      TextField(controller: _holder, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Kart sahibi')),
      const SizedBox(height: 8),
      TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Bankanın müşteri hizmetleri', hintText: '0850 …')),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final t = LbTokens.of(context);
    final me = ref.watch(walletMeProvider);
    final inHousehold = (ref.watch(walletScopeProvider).value ?? '').startsWith('h:');
    final notMine = _initial != null && me != 0 && _initial!.ownerId != me;
    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 8),
          child: Text(text, style: TextStyle(color: t.muted, fontWeight: FontWeight.w700)),
        );

    if (notMine) {
      final owner = (ref.watch(walletMembersProvider).value ?? const []).where((m) => m.userId == _initial!.ownerId).firstOrNull;
      return AddPageScaffold(
        title: _initial!.name,
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('Bu ortak hesap ${owner?.name ?? 'diğer üyeye'} ait; ayarlarını yalnızca o değiştirebilir. Harcama ekleyebilirsin.',
              style: TextStyle(color: t.muted)),
        ),
      );
    }

    return AddPageScaffold(
      title: _isNew ? 'Yeni hesap' : 'Hesabı düzenle',
      dirty: _signature != _snapshot,
      onSave: _save,
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 40), children: [
        if (_isNew) ...[
          SegmentedButton<AccountType>(
            showSelectedIcon: false,
            segments: [for (final type in AccountType.values) ButtonSegment(value: type, label: Text(type.label))],
            selected: {_type},
            onSelectionChanged: (value) => setState(() => _type = value.first),
          ),
          const SizedBox(height: 16),
        ],
        if (_isCard) ...[
          CardFace(
            card: WalletAccount(
              id: _id,
              ownerId: me,
              name: _name.text.trim().isEmpty ? 'Kart adı' : _name.text.trim(),
              type: AccountType.creditCard,
              bank: _bank.text.trim().isEmpty ? null : _bank.text.trim(),
              balance: -(parseCents(_balance.text) ?? 0),
              limit: parseCents(_limit.text),
              statementDay: _statementDay,
              dueDay: _dueDay,
              shared: _shared,
              last4: _last4.text.length == 4 ? _last4.text : null,
              network: _network,
              color: _color,
            ),
            wallet: const WalletData(),
            now: DateTime.now(),
          ),
          const SizedBox(height: 20),
        ],
        TextField(
          controller: _name,
          autofocus: _isNew,
          textCapitalization: TextCapitalization.sentences,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          decoration: InputDecoration(hintText: _isCard ? 'Kart adı (örn. Bonus)' : 'Hesap adı'),
        ),
        const SizedBox(height: 16),
        _Section(children: [
          if (_type != AccountType.cash) ...[
            TextField(controller: _bank, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Banka')),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final bank in _banks.where((b) => b != _bank.text).take(8))
                ActionChip(label: Text(bank), onPressed: () => _bank.text = bank),
            ]),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _balance,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,-]'))],
            decoration: InputDecoration(
              labelText: _isCard ? 'Güncel borç' : 'Güncel bakiye',
              suffixText: '₺',
              helperText: _isNew ? null : 'Değiştirirsen hareketler korunur, açılış bakiyesi düzeltilir.',
            ),
          ),
          if (_type == AccountType.bank) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _iban,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Za-z ]'))],
              decoration: const InputDecoration(labelText: 'IBAN (isteğe bağlı)', hintText: 'TR00 0000 0000 0000 0000 0000 00'),
            ),
          ],
          const SizedBox(height: 4),
        ]),
        if (_isCard) ...[
          const SizedBox(height: 16),
          _Section(children: [
            TextField(
              controller: _limit,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              decoration: const InputDecoration(labelText: 'Kart limiti', suffixText: '₺'),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _DayPicker(label: 'Kesim günü', value: _statementDay, onChanged: (v) => setState(() => _statementDay = v))),
              const SizedBox(width: 12),
              Expanded(child: _DayPicker(label: 'Son ödeme günü', value: _dueDay, onChanged: (v) => setState(() => _dueDay = v))),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _last4,
              keyboardType: TextInputType.number,
              maxLength: 4,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Son 4 hane', counterText: ''),
            ),
            if (ref.watch(cardSecretsStoreProvider).supported) _secretsSection(context),
            label('Kart ağı'),
            Wrap(spacing: 8, children: [
              for (final entry in networkLabels.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: _network == entry.key,
                  onSelected: (on) => setState(() => _network = on ? entry.key : null),
                ),
            ]),
            label('Renk'),
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (final entry in cardSchemes.entries)
                Semantics(
                  label: entry.value.$1,
                  selected: _color == entry.key,
                  button: true,
                  child: GestureDetector(
                    onTap: () => setState(() => _color = entry.key),
                    child: Container(
                      width: 44,
                      height: 30,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: LinearGradient(colors: entry.value.$2),
                        border: Border.all(color: _color == entry.key ? t.onBase : Colors.transparent, width: 2.5),
                      ),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 8),
          ]),
        ],
        const SizedBox(height: 16),
        _Section(children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ortak hesap'),
            subtitle: Text(inHousehold
                ? 'Hanedeki diğer kişi görür ve harcama ekleyebilir'
                : 'Önce Hesap ve ayarlar → Hane bölümünden bir haneye katıl'),
            value: _shared,
            onChanged: inHousehold || _shared ? (on) => setState(() => _shared = on) : null,
          ),
        ]),
        if (!_isNew) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _initial!.sync == SyncMark.confirmed || _initial!.sync == SyncMark.pending ? _archive : null,
            icon: Icon(_initial!.active ? Icons.archive_outlined : Icons.unarchive_outlined),
            label: Text(_initial!.active ? 'Hesabı arşivle' : 'Arşivden çıkar'),
          ),
        ],
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => NeuSurface(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );
}

class _DayPicker extends StatelessWidget {
  const _DayPicker({required this.label, required this.value, required this.onChanged});
  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<int?>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: [
          const DropdownMenuItem(value: null, child: Text('—')),
          for (var day = 1; day <= 31; day++) DropdownMenuItem(value: day, child: Text('$day')),
        ],
        onChanged: onChanged,
      );
}
