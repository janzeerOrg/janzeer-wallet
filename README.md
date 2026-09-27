# Janzeer Wallet

The official non-custodial wallet for the [Janzeer](https://janzeer.org) blockchain — Android, Linux, Windows and
macOS from one Flutter code base. English and Arabic (right-to-left), dark and light.

**Your keys never leave the device.** The wallet creates the recovery phrase locally, signs every transaction locally
and sends only the signed transaction to a node. There is no account, no server-side key and no recovery service: the
12 or 24 words are the wallet.

## Download

Signed builds with their SHA-256 are listed on <https://janzeer.org/wallet> and in this repository's
[Releases](../../releases). Verify the hash before installing. Android builds are signed with the project's release
key; its certificate SHA-256 is

```
f3c92989881a4ad9a33e0733ee4a4ba2520c6885c0ee719b67f264ed3b35e9f1
```

(`apksigner verify --print-certs janzeer-wallet-<version>-android.apk`).

## What it does

- Create a wallet (12 or 24 words) or restore one from its recovery phrase
- Send and receive JNZ, with a memo; review before signing; speed up a pending transfer with a higher fee
- Scan a QR code with the camera or from a picture (with a crop step when the code is small)
- JZT-1 tokens: balances, create, mint, burn, transfer
- Validator registration and exit
- App lock with PIN or biometrics; hide balances; recovery phrase shown only after the password
- Works against any Janzeer node: mainnet by default, a custom node URL in Settings

## Build from source

Requirements: Flutter 3.44+ (Dart 3.12+). The wallet uses the official Dart SDK
[`janzeer_sdk`](https://github.com/janzeerorg/janzeer-sdk-dart) through a path dependency, so clone it next to this
repository under the name `sdk_dart`:

```bash
git clone https://github.com/janzeerorg/janzeer-sdk-dart sdk_dart
git clone https://github.com/janzeerorg/janzeer-wallet wallet
cd wallet
flutter pub get
flutter run -d linux            # or: -d android, -d windows, -d macos
```

Release archives, named and hashed like the published ones:

```bash
./release/build-wallet.sh linux                       # build/release/janzeer-wallet-<version>-linux-x64.tar.gz
ALLOW_DEBUG_KEY=1 ./release/build-wallet.sh android   # your own build: signed with your debug key
```

An APK you build yourself is signed with **your** key, so it cannot update an installed official build (Android refuses
a different signer). Uninstall the official app first — after writing down the recovery phrase.

## Tests

```bash
flutter analyze
flutter test                                          # includes the crypto parity vectors
flutter test --run-skipped --tags screenshots --update-goldens test/screenshots_test.dart   # renders every screen to test/goldens/
```

`test/janzeer_crypto_parity_test.dart` proves that key derivation, addresses and transaction signatures are
byte-identical to the node's reference vectors (`test/wallet-parity-vectors.json`).

## Security

- The recovery phrase is stored only as a vault encrypted with your password (PBKDF2-HMAC-SHA256, 250,000 rounds →
  AES-256-GCM). The password cannot be recovered.
- With an app lock enabled, the unlocked keys are kept in the platform's encrypted storage and released by PIN or
  biometrics.
- Found a vulnerability? Please write to **janzeeer@proton.me** before disclosing it publicly.

## Licence

Apache License 2.0 — see [LICENSE](LICENSE).
