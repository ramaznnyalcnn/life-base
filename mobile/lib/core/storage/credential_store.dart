import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CredentialStore {
  const CredentialStore({
    FlutterSecureStorage secure = const FlutterSecureStorage(
      aOptions: AndroidOptions(),
    ),
  }) : _secure = secure;

  static const _serverKey = 'server_url';
  static const _tokenKey = 'access_token';
  static const _nameKey = 'display_name';
  final FlutterSecureStorage _secure;

  Future<String?> readServerUrl() async =>
      (await SharedPreferences.getInstance()).getString(_serverKey);

  Future<String?> readToken() => _secure.read(key: _tokenKey);
  Future<String?> readDisplayName() async =>
      (await SharedPreferences.getInstance()).getString(_nameKey);

  Future<void> saveSession({required String serverUrl, required String token, required String displayName}) async {
    final normalized = serverUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_serverKey, normalized);
    await preferences.setString(_nameKey, displayName);
    await _secure.write(key: _tokenKey, value: token);
  }

  Future<void> clearToken() => _secure.delete(key: _tokenKey);
}
