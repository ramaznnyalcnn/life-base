import 'package:flutter_test/flutter_test.dart';
import 'package:lifebase_mobile/core/network/server_address.dart';

void main() {
  test('allows HTTPS and private cleartext hosts', () {
    expect(normalizeServerAddress('https://life.example.com/'), 'https://life.example.com');
    expect(normalizeServerAddress('http://10.0.2.2:8000'), 'http://10.0.2.2:8000');
    expect(normalizeServerAddress('http://100.80.20.4:8000'), 'http://100.80.20.4:8000');
    expect(normalizeServerAddress('http://lifeos:8000'), 'http://lifeos:8000');
  });

  test('rejects public cleartext and unsupported schemes', () {
    expect(() => normalizeServerAddress('http://example.com'), throwsFormatException);
    expect(() => normalizeServerAddress('ftp://10.0.0.2'), throwsFormatException);
  });
}
