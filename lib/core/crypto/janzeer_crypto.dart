// Janzeer wallet crypto — byte-for-byte parity with the node (com.zg.crypto.janzeer) and the web wallet
// (j_frontend/src/wallet/janzeerCrypto.js). Non-custodial: keys are derived and txs are signed on-device;
// the node only verifies. The scheme is BIP39/BIP32-SHAPED but uses CUSTOM constants, so stock bip32/web3
// will NOT match — every primitive mirrors a specific backend source. Verified byte-for-byte by
// test/janzeer_crypto_parity_test.dart against the committed vectors. Do not "modernize" without
// regenerating + re-checking vectors.
import 'dart:convert';
import 'dart:typed_data';

import 'package:bip39/bip39.dart' as bip39;
import 'package:pointycastle/export.dart';

const String _hdSalt = '@_Janzeer_Blockchain_@'; // PBKDF2 salt base AND BIP32 root HMAC key (SeedConstant.SALT)
// ChainSpec.networkId — prepended to every signed tx preimage (cross-chain replay protection, §16.2). Must
// equal the node's `consensus.network-id`; override per-network by passing `networkId` to transactionBytes/build*.
const String kNetworkId = 'janzeer';
final BigInt _scale = BigInt.from(100000000); // 10^8 (Constants.BIG_DECIMAL_SCALE = 8)
final ECDomainParameters _secp256k1 = ECDomainParameters('secp256k1');
final BigInt _n = _secp256k1.n;

/// A derived account: private key (hex), compressed public key (hex), and node address.
class Account {
  final String privHex;
  final String pubHex;
  final String address;
  const Account(this.privHex, this.pubHex, this.address);
}

// ---------------- hex / byte helpers ----------------

const _hexChars = '0123456789abcdef';

String bytesToHex(List<int> bytes) {
  final sb = StringBuffer();
  for (final b in bytes) {
    sb.write(_hexChars[(b >> 4) & 0x0f]);
    sb.write(_hexChars[b & 0x0f]);
  }
  return sb.toString();
}

Uint8List hexToBytes(String hex) {
  final h = hex.startsWith('0x') ? hex.substring(2) : hex;
  final out = Uint8List(h.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(h.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

Uint8List _utf8(String s) => Uint8List.fromList(utf8.encode(s));

Uint8List _concat(List<Uint8List> parts) {
  final total = parts.fold<int>(0, (n, p) => n + p.length);
  final out = Uint8List(total);
  var o = 0;
  for (final p in parts) {
    out.setRange(o, o + p.length, p);
    o += p.length;
  }
  return out;
}

/// 8-byte big-endian (java ByteBuffer.putLong).
Uint8List _i64be(BigInt value) {
  final out = Uint8List(8);
  var v = value;
  for (var i = 7; i >= 0; i--) {
    out[i] = (v & BigInt.from(0xff)).toInt();
    v = v >> 8;
  }
  return out;
}

/// 4-byte big-endian (BIP32 ser32 / java ByteBuffer.putInt).
Uint8List _ser32(int i) => Uint8List.fromList([(i >> 24) & 0xff, (i >> 16) & 0xff, (i >> 8) & 0xff, i & 0xff]);

BigInt _bytesToBigInt(Uint8List b) {
  var r = BigInt.zero;
  for (final x in b) {
    r = (r << 8) | BigInt.from(x);
  }
  return r;
}

Uint8List _bigIntToBytes(BigInt v, int len) {
  final out = Uint8List(len);
  var x = v;
  for (var i = len - 1; i >= 0; i--) {
    out[i] = (x & BigInt.from(0xff)).toInt();
    x = x >> 8;
  }
  return out;
}

// ---------------- digests ----------------

Uint8List _sha256(Uint8List data) => SHA256Digest().process(data);
Uint8List _keccak256(Uint8List data) => KeccakDigest(256).process(data);
Uint8List _doubleSha256(Uint8List data) => _sha256(_sha256(data));

Uint8List _hmacSha512(Uint8List key, Uint8List msg) {
  final mac = HMac(SHA512Digest(), 128)..init(KeyParameter(key));
  return mac.process(msg);
}

/// secp256k1 compressed public key (33 bytes) for a private scalar.
Uint8List _compressedPub(BigInt d) => (_secp256k1.G * d)!.getEncoded(true);

// ---------------- amount scaling (ByteUtils.toScaledLong) ----------------

/// BigDecimal.setScale(8, HALF_UP).unscaledValue() — decimal string/number → scaled BigInt.
BigInt toScaledLong(Object amount) {
  final s = amount.toString().trim();
  final neg = s.startsWith('-');
  final t = neg ? s.substring(1) : s;
  final dot = t.indexOf('.');
  final intPart = dot < 0 ? t : t.substring(0, dot);
  final fracPart = dot < 0 ? '' : t.substring(dot + 1);
  final frac8 = (fracPart.length >= 8 ? fracPart.substring(0, 8) : fracPart.padRight(8, '0'));
  var scaled = BigInt.parse(intPart.isEmpty ? '0' : intPart) * _scale + BigInt.parse(frac8);
  // HALF_UP on the first dropped (9th) fractional digit.
  if (fracPart.length > 8) {
    final ninth = fracPart.codeUnitAt(8) - 48;
    if (ninth >= 5) scaled += BigInt.one;
  }
  return neg ? -scaled : scaled;
}

// ---------------- address (ECKey.getAddress / AddressUtils) ----------------

/// CANONICAL address = "0x" + hex(keccak256(compressedPubkey)[0:20]), all-lowercase. This is what the node
/// stores and hashes and what every signed `senderAddress` must be — so it MUST stay lowercase for parity.
/// The EIP-55 mixed-case form (toChecksumAddress) is a display/validation overlay only (proposal §9).
String publicKeyToAddress(Uint8List compressedPub) {
  return '0x${bytesToHex(_keccak256(compressedPub).sublist(0, 20))}';
}

/// AddressUtils.toChecksumAddress — real EIP-55: uppercase each hex LETTER whose keccak256(lowercase-hex-body)
/// nibble is >= 8. Presentational only (canonical storage stays lowercase); catches ~99.99% of typos (§9).
String toChecksumAddress(String address) {
  final body = (address.startsWith('0x') ? address.substring(2) : address).toLowerCase();
  final h = bytesToHex(_keccak256(_utf8(body)));
  final sb = StringBuffer('0x');
  for (var i = 0; i < body.length; i++) {
    final c = body[i];
    final isLetter = c.codeUnitAt(0) >= 0x61 && c.codeUnitAt(0) <= 0x66; // a-f
    sb.write(isLetter && int.parse(h[i], radix: 16) >= 8 ? c.toUpperCase() : c);
  }
  return sb.toString();
}

/// AddressUtils.isChecksumValid — accept all-lowercase (back-compat) or a correct EIP-55 mixed-case address.
bool isChecksumValid(String address) {
  if (!RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(address)) return false;
  final body = address.substring(2);
  if (body == body.toLowerCase() || body == body.toUpperCase()) return true;
  return toChecksumAddress(address) == (address.startsWith('0x') ? address : '0x$address');
}

// ---------------- mnemonic (standard BIP39 English wordlist) ----------------

/// Generate a BIP39 mnemonic. strength 128 → 12 words, 256 → 24 words.
String generateMnemonic({int strength = 128}) => bip39.generateMnemonic(strength: strength);

bool validateMnemonic(String mnemonic) => bip39.validateMnemonic(mnemonic.trim());

// ---------------- HD derivation (SeedCalculator + ExtendedKey + m/0/0/0) ----------------

/// SeedCalculator.calculateSeed — PBKDF2-HMAC-SHA512, 2048 iters, 64 bytes, salt = HD_SALT + passphrase.
Uint8List mnemonicToSeed(String mnemonic, {String passphrase = ''}) {
  final pw = _utf8(mnemonic); // NFKD: bip39 mnemonics are ASCII; passphrase normalization handled by caller if needed
  final salt = _utf8(_hdSalt + passphrase);
  final derivator = PBKDF2KeyDerivator(HMac(SHA512Digest(), 128))..init(Pbkdf2Parameters(salt, 2048, 64));
  return derivator.process(pw);
}

class _Node {
  final Uint8List priv;
  final Uint8List chainCode;
  const _Node(this.priv, this.chainCode);
}

/// ExtendedKey.root — I = HMAC-SHA512(key = HD_SALT, msg = seed); IL=priv, IR=chainCode.
_Node _seedToMasterKey(Uint8List seed) {
  final i = _hmacSha512(_utf8(_hdSalt), seed);
  return _Node(Uint8List.sublistView(i, 0, 32), Uint8List.sublistView(i, 32, 64));
}

/// ExtendedKey.getChild (non-hardened) — standard BIP32 CKDpriv.
_Node _deriveChild(_Node node, int index) {
  final pub = _compressedPub(_bytesToBigInt(node.priv));
  final i = _hmacSha512(node.chainCode, _concat([pub, _ser32(index)]));
  final childNum = (_bytesToBigInt(Uint8List.sublistView(i, 0, 32)) + _bytesToBigInt(node.priv)) % _n;
  return _Node(_bigIntToBytes(childNum, 32), Uint8List.sublistView(i, 32, 64));
}

/// Full default path m/0/0/0.
_Node _deriveDefault(Uint8List seed) {
  var node = _seedToMasterKey(seed);
  for (final idx in const [0, 0, 0]) {
    node = _deriveChild(node, idx);
  }
  return node;
}

// ---------------- accounts ----------------

Account accountFromSeed(Uint8List seed) {
  final node = _deriveDefault(seed);
  final pub = _compressedPub(_bytesToBigInt(node.priv));
  return Account(bytesToHex(node.priv), bytesToHex(pub), publicKeyToAddress(pub));
}

Account accountFromMnemonic(String mnemonic, {String passphrase = ''}) =>
    accountFromSeed(mnemonicToSeed(mnemonic.trim(), passphrase: passphrase));

Account accountFromPrivateKey(String privHex) {
  final pub = _compressedPub(_bytesToBigInt(hexToBytes(privHex)));
  return Account(privHex, bytesToHex(pub), publicKeyToAddress(pub));
}

// ---------------- transactions (Transaction.bytes + doubleSha256 + SignatureUtils.sign) ----------------

/// Transaction.bytes(): networkId + timestamp + toScaledLong(fee) + nonce + senderAddress.utf8 + payload.
Uint8List transactionBytes({
  String networkId = kNetworkId,
  required int timestamp,
  required Object fee,
  required int nonce,
  required String senderAddress,
  required Uint8List payload,
}) =>
    _concat([
      _utf8(networkId),
      _i64be(BigInt.from(timestamp)),
      _i64be(toScaledLong(fee)),
      _i64be(BigInt.from(nonce)),
      _utf8(senderAddress),
      payload,
    ]);

Uint8List transferPayload({required Object amount, required String recipientAddress, String? data}) =>
    _concat([_i64be(toScaledLong(amount)), _utf8(recipientAddress), _utf8(data ?? '')]);

Uint8List promoterPayload({required Object amount, required String promoterKey}) =>
    _concat([_i64be(toScaledLong(amount)), _utf8(promoterKey)]);

/// ExitPromoterTx.payload(): promoterKey.utf8 (no amount — the deposit is non-refundable).
Uint8List exitPromoterPayload({required String promoterKey}) => _utf8(promoterKey);

/// HashUtils.doubleSha256 -> lowercase hex (the tx `hash`).
String hashBytes(Uint8List bytes) => bytesToHex(_doubleSha256(bytes));

/// SignatureUtils.sign: ECDSA secp256k1, RFC-6979 (deterministic k via HMAC-SHA256), canonical low-S,
/// DER, Base64 — over the RAW 32-byte digest. Mirrors the node's BouncyCastle ECKey.sign exactly.
String signHash(String hashHex, String privHex) {
  final d = _bytesToBigInt(hexToBytes(privHex));
  final signer = ECDSASigner(null, HMac(SHA256Digest(), 64))
    ..init(true, PrivateKeyParameter(ECPrivateKey(d, _secp256k1)));
  final sig = signer.generateSignature(hexToBytes(hashHex)) as ECSignature;
  var s = sig.s;
  final halfN = _n >> 1;
  if (s.compareTo(halfN) > 0) s = _n - s; // canonical low-S (Audit C8)
  return base64.encode(_derEncode(sig.r, s));
}

/// Minimal big-endian magnitude of a positive BigInt (no leading zero bytes; one byte for zero).
Uint8List _minimalBE(BigInt v) {
  if (v == BigInt.zero) return Uint8List.fromList([0]);
  final bytes = <int>[];
  var x = v;
  while (x > BigInt.zero) {
    bytes.insert(0, (x & BigInt.from(0xff)).toInt());
    x = x >> 8;
  }
  return Uint8List.fromList(bytes);
}

/// DER INTEGER (0x02 len magnitude), prepending 0x00 when the high bit is set (keep it positive).
Uint8List _derInt(BigInt v) {
  var mag = _minimalBE(v);
  if ((mag[0] & 0x80) != 0) {
    final tmp = Uint8List(mag.length + 1)..[0] = 0x00;
    tmp.setRange(1, tmp.length, mag);
    mag = tmp;
  }
  final out = Uint8List(2 + mag.length)
    ..[0] = 0x02
    ..[1] = mag.length;
  out.setRange(2, out.length, mag);
  return out;
}

/// DER SEQUENCE of two INTEGERs (r, s). ECDSA secp256k1 sigs are < 128 bytes, so the length is one byte.
Uint8List _derEncode(BigInt r, BigInt s) {
  final ri = _derInt(r);
  final si = _derInt(s);
  final out = Uint8List(2 + ri.length + si.length)
    ..[0] = 0x30
    ..[1] = ri.length + si.length;
  out.setRange(2, 2 + ri.length, ri);
  out.setRange(2 + ri.length, out.length, si);
  return out;
}

Map<String, Object?> _sign(String networkId, int timestamp, Object fee, int nonce, String senderAddress, String privHex, Uint8List payload) {
  final hash = hashBytes(transactionBytes(networkId: networkId, timestamp: timestamp, fee: fee, nonce: nonce, senderAddress: senderAddress, payload: payload));
  return {'hash': hash, 'signature': signHash(hash, privHex)};
}

/// Build a fully-signed transfer (caller supplies the current nonce + a timestamp).
Map<String, Object?> buildSignedTransfer({
  String networkId = kNetworkId,
  required int timestamp,
  required Object fee,
  required int nonce,
  required String senderAddress,
  required String publicKey,
  required String recipientAddress,
  required Object amount,
  String? data,
  required String privHex,
}) {
  final s = _sign(networkId, timestamp, fee, nonce, senderAddress, privHex, transferPayload(amount: amount, recipientAddress: recipientAddress, data: data));
  return {
    'timestamp': timestamp, 'fee': '$fee', 'nonce': nonce, 'hash': s['hash'],
    'senderAddress': senderAddress, 'senderSignature': s['signature'], 'senderPublicKey': publicKey,
    'amount': '$amount', 'recipientAddress': recipientAddress, 'data': data,
  };
}

/// Build a signed promoter-registration: DEPOSITS amount (2000, non-refundable) to register promoterKey.
Map<String, Object?> buildSignedPromoter({
  String networkId = kNetworkId,
  required int timestamp,
  required Object fee,
  required int nonce,
  required String senderAddress,
  required String publicKey,
  required Object amount,
  required String promoterKey,
  required String privHex,
}) {
  final s = _sign(networkId, timestamp, fee, nonce, senderAddress, privHex, promoterPayload(amount: amount, promoterKey: promoterKey));
  return {
    'timestamp': timestamp, 'fee': '$fee', 'nonce': nonce, 'senderAddress': senderAddress,
    'amount': '$amount', 'promoterKey': promoterKey, 'hash': s['hash'],
    'senderSignature': s['signature'], 'senderPublicKey': publicKey,
  };
}

/// Build a signed graceful validator exit (removes promoterKey next epoch; deposit stays non-refundable).
Map<String, Object?> buildSignedExitPromoter({
  String networkId = kNetworkId,
  required int timestamp,
  required Object fee,
  required int nonce,
  required String senderAddress,
  required String publicKey,
  required String promoterKey,
  required String privHex,
}) {
  final s = _sign(networkId, timestamp, fee, nonce, senderAddress, privHex, exitPromoterPayload(promoterKey: promoterKey));
  return {
    'timestamp': timestamp, 'fee': '$fee', 'nonce': nonce, 'senderAddress': senderAddress,
    'promoterKey': promoterKey, 'hash': s['hash'],
    'senderSignature': s['signature'], 'senderPublicKey': publicKey,
  };
}
