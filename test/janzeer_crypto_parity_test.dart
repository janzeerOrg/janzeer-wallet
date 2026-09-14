// The wallet ships the official SDK's crypto (janzeer_sdk); the SDK's own suite reproduces every conformance
// vector. This smoke test pins that the app's vendored vectors copy is the one the SDK was tested against and
// that the compat API the controller calls still derives the canonical wallet and signs the reference transfer.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:janzeer_sdk/crypto.dart' as jc;
import 'package:janzeer_sdk/janzeer_sdk.dart';

void main() {
  final v = jsonDecode(File('test/wallet-parity-vectors.json').readAsStringSync()) as Map<String, dynamic>;
  final hd = v['hd'] as Map<String, dynamic>;
  final t = v['transferTx'] as Map<String, dynamic>;

  test('vectors are the format the SDK targets', () {
    expect(v['vectorsVersion'], SpecVersion.vectors);
  });

  test('canonical mnemonic → address (typed and compat APIs agree)', () {
    expect(Account.fromMnemonic(hd['mnemonic'] as String).address, hd['address']);
    expect(jc.deriveAccountIsolate(hd['mnemonic'] as String)['address'], hd['address']);
  });

  test('reference transfer signs byte-identically through the compat API the controller uses', () {
    final body = jc.buildSignedTransferIsolate({
      'timestamp': t['timestamp'], 'fee': t['fee'], 'nonce': t['nonce'], 'senderAddress': t['senderAddress'],
      'publicKey': t['publicKey'], 'recipientAddress': t['recipientAddress'], 'amount': t['amount'], 'data': t['data'],
      'privHex': (v['rawKey'] as Map<String, dynamic>)['privHex'],
    });
    expect(body['hash'], t['hash']);
    expect(body['senderSignature'], t['signature']);
  });
}
