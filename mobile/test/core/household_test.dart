import 'package:flutter_test/flutter_test.dart';
import 'package:lifebase_mobile/core/household/household.dart';
import 'package:lifebase_mobile/modules/account/data/session_controller.dart';

void main() {
  test('a phone reminds about items for everyone or for its own user', () {
    expect(remindsMe(notifyAll, 3), isTrue);
    expect(remindsMe('3', 3), isTrue);
    expect(remindsMe('2', 3), isFalse);
    // Before the first sync names this user, nothing is dropped.
    expect(remindsMe('2', 0), isTrue);
    expect(remindedHere(['all', '2', '3'], (n) => n, 3), ['all', '3']);
  });

  test('a username signs in as its lifebase.local address', () {
    expect(loginEmail(' Ali '), 'ali@lifebase.local');
    expect(loginEmail('ayse'), 'ayse@lifebase.local');
    expect(loginEmail('owner@lifeos.local'), 'owner@lifeos.local');
  });
}
