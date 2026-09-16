String normalizeServerAddress(String input) {
  final value = input.trim();
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !uri.hasScheme ||
      uri.host.isEmpty ||
      !const {'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      (uri.path.isNotEmpty && uri.path != '/')) {
    throw const FormatException('Geçerli bir sunucu adresi girin.');
  }

  final scheme = uri.scheme.toLowerCase();
  if (scheme == 'http' && !_isPrivateHost(uri.host)) {
    throw const FormatException(
      'HTTP yalnızca emülatör, yerel ağ veya Tailscale adreslerinde kullanılabilir.',
    );
  }

  return uri.replace(scheme: scheme, path: '').toString();
}

bool _isPrivateHost(String host) {
  final normalized = host.toLowerCase();
  if (normalized == 'localhost' ||
      normalized.endsWith('.localhost') ||
      normalized.endsWith('.ts.net') ||
      !normalized.contains('.')) {
    return true;
  }

  if (normalized == '::1' ||
      normalized.startsWith('fc') ||
      normalized.startsWith('fd') ||
      normalized.startsWith('fe8') ||
      normalized.startsWith('fe9') ||
      normalized.startsWith('fea') ||
      normalized.startsWith('feb')) {
    return true;
  }

  final octets = normalized.split('.').map(int.tryParse).toList();
  if (octets.length != 4 ||
      octets.any((octet) => octet == null || octet < 0 || octet > 255)) {
    return false;
  }

  final first = octets[0]!;
  final second = octets[1]!;
  return first == 10 ||
      first == 127 ||
      (first == 172 && second >= 16 && second <= 31) ||
      (first == 192 && second == 168) ||
      (first == 100 && second >= 64 && second <= 127);
}
