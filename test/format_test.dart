import 'package:flutter_test/flutter_test.dart';
import 'package:wallet/core/utils/format.dart';

/// Money-input helpers (review 2026-11-11): exact decimals only, exact arithmetic, one whole address.
void main() {
  test('isValidAmount accepts plain decimals within the precision only', () {
    expect(isValidAmount('1.5', 8), isTrue);
    expect(isValidAmount('20', 0), isTrue);
    expect(isValidAmount('0.00000001', 8), isTrue);
    for (final bad in ['', '.', '1,5', '1e3', '-1', '+1', '1.', '.5', ' ', '1.999999999', '0', '0.0', '١٠']) {
      expect(isValidAmount(bad, 8), isFalse, reason: bad);
    }
    expect(isValidAmount('1.999', 2), isFalse, reason: 'extra digits must be refused, not truncated');
    expect(isValidAmount('0', 8, allowZero: true), isTrue);
  });

  test('scaled8 arithmetic is exact where doubles are not', () {
    expect(0.14 + 0.01 > 0.15, isTrue, reason: 'the float trap this replaces');
    expect(scaled8('0.14') + scaled8('0.01') > scaled8('0.15'), isFalse);
    expect(fromBaseUnits((scaled8('0.15') - scaled8('0.01')).toString(), 8), '0.14');
  });

  test('extractAddress takes one whole, well-cased address', () {
    const lower = '0x06e1c0fa9955a700876f8cb0acc7f13fba9fb8ba';
    expect(extractAddress(lower), lower);
    expect(extractAddress('janzeer:pay?to=$lower&amount=1.5'), lower);
    expect(extractAddress('${lower}0'), isNull, reason: '41 hex digits are not an address');
    expect(extractAddress('0x${'ab' * 32}'), isNull, reason: 'a 64-digit hash is not an address');
    expect(extractAddress('hello'), isNull);
    final miscased = '0x06E1c0fa9955a700876f8cb0acc7f13fba9fb8ba';
    expect(extractAddress(miscased), isNull, reason: 'a mixed-case address needs a valid checksum');
  });
}
