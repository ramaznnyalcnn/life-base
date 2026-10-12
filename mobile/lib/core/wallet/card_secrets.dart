import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// What is printed on a card. It never leaves this device: the server knows
/// only the last four digits.
@immutable
class CardSecrets {
  const CardSecrets({required this.number, this.expiry, this.cvv, this.holder, this.supportPhone});

  factory CardSecrets.fromJson(Map<String, Object?> json) => CardSecrets(
        number: json['number']! as String,
        expiry: json['expiry'] as String?,
        cvv: json['cvv'] as String?,
        holder: json['holder'] as String?,
        supportPhone: json['support_phone'] as String?,
      );

  /// Digits only.
  final String number;

  /// "MM/YY".
  final String? expiry;
  final String? cvv;
  final String? holder;
  final String? supportPhone;

  String get last4 => number.substring(number.length - 4);

  /// "4543 1234 5678 9012" (Amex: "3782 822463 10005").
  String get groupedNumber {
    final groups = number.length == 15 ? [4, 6, 5] : List.filled((number.length / 4).ceil(), 4);
    final out = <String>[];
    var at = 0;
    for (final size in groups) {
      if (at >= number.length) break;
      out.add(number.substring(at, (at + size).clamp(0, number.length)));
      at += size;
    }
    return out.join(' ');
  }

  Map<String, Object?> toJson() => {
        'number': number,
        'expiry': ?expiry,
        'cvv': ?cvv,
        'holder': ?holder,
        'support_phone': ?supportPhone,
      };

  @override
  bool operator ==(Object other) => other is CardSecrets && jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;
}

/// Card details kept in the Android Keystore-backed secure storage, by account id.
abstract interface class CardSecretsStore {
  /// False on the web and wherever secure storage is unavailable.
  bool get supported;
  Future<bool> has(String accountId);
  Future<CardSecrets?> read(String accountId);

  /// Null removes the details.
  Future<void> write(String accountId, CardSecrets? secrets);

  /// Removes every card's details, e.g. on sign-out.
  Future<void> clear();
}

class SecureCardSecretsStore implements CardSecretsStore {
  const SecureCardSecretsStore({FlutterSecureStorage storage = const FlutterSecureStorage(aOptions: AndroidOptions())})
      : _storage = storage;

  static const _prefix = 'card_secret.';
  final FlutterSecureStorage _storage;

  @override
  bool get supported => !kIsWeb;

  @override
  Future<bool> has(String accountId) async => supported && await _storage.containsKey(key: '$_prefix$accountId');

  @override
  Future<CardSecrets?> read(String accountId) async {
    if (!supported) return null;
    final raw = await _storage.read(key: '$_prefix$accountId');
    return raw == null ? null : CardSecrets.fromJson(Map<String, Object?>.from(jsonDecode(raw) as Map));
  }

  @override
  Future<void> write(String accountId, CardSecrets? secrets) async {
    if (!supported) return;
    if (secrets == null) {
      await _storage.delete(key: '$_prefix$accountId');
    } else {
      await _storage.write(key: '$_prefix$accountId', value: jsonEncode(secrets.toJson()));
    }
  }

  @override
  Future<void> clear() async {
    if (!supported) return;
    for (final key in (await _storage.readAll()).keys) {
      if (key.startsWith(_prefix)) await _storage.delete(key: key);
    }
  }
}

/// Asks the owner to prove it is them (fingerprint, face or screen lock).
abstract interface class CardUnlocker {
  /// Null when it worked; otherwise why not, to show the user.
  Future<String?> unlock(String reason);
}

class LocalAuthUnlocker implements CardUnlocker {
  LocalAuthUnlocker([LocalAuthentication? auth]) : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<String?> unlock(String reason) async {
    try {
      if (!await _auth.isDeviceSupported()) return 'Bu cihazda ekran kilidi yok; kart bilgileri açılamaz.';
      // Not biometric-only: the screen lock PIN works too.
      return await _auth.authenticate(localizedReason: reason) ? null : 'Doğrulanamadı.';
    } on LocalAuthException catch (error) {
      return switch (error.code) {
        LocalAuthExceptionCode.userCanceled || LocalAuthExceptionCode.systemCanceled => 'Vazgeçildi.',
        LocalAuthExceptionCode.temporaryLockout || LocalAuthExceptionCode.biometricLockout =>
          'Çok fazla deneme oldu; biraz sonra tekrar dene.',
        LocalAuthExceptionCode.noCredentialsSet => 'Önce telefonda bir ekran kilidi ayarla.',
        _ => error.description ?? 'Doğrulanamadı.',
      };
    }
  }
}

final cardSecretsStoreProvider = Provider<CardSecretsStore>((ref) => const SecureCardSecretsStore());
final cardUnlockerProvider = Provider<CardUnlocker>((ref) => LocalAuthUnlocker());

/// Whether this device holds the details of [accountId]'s card.
final hasCardSecretsProvider = FutureProvider.family<bool, String>(
  (ref, accountId) => ref.watch(cardSecretsStoreProvider).has(accountId).catchError((Object _) => false),
);
