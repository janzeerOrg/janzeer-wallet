/// App-wide constants. Fee/deposit mirror the node's enforced `consensus.*` values (a promoter tx is
/// rejected if its fee or deposit doesn't match exactly).
class AppConfig {
  // ChainSpec.networkId — must equal the node's `consensus.network-id`; bound into every signed tx preimage
  // (cross-chain replay protection, §16.2). Change per network (mainnet / testnet / devnet).
  static const String networkId = 'janzeer';
  static const String minimumFee = '0.01';
  static const String promoterFee = '3'; // fee-promoter-tx
  static const String promoterDeposit = '2000'; // amount-promoter-tx — NON-REFUNDABLE registration deposit (§5, §10)
  static const String tokenCreateFee = '5'; // fee-create-token-tx — exact flat fee a validator pays to CREATE a token
  static const int maxMemo = 256; // TransferTransactionValidator.MAX_DATA_SIZE
  /// JZT-1 token screens (Tokens tab, token operations page, token balance reads). OFF for the launch builds
  /// (owner, 2026-10-01: not tested enough yet); the code stays, flip this to bring them back.
  static const bool tokensEnabled = false;
  static const String unit = 'JNZ'; // native-coin ticker (display only)

  /// Default node REST base URL (overridable in Settings): the public mainnet API. A first-time user must not
  /// see a dead localhost node (online test 2026-09-23, Flutter pass). For a local dev net set Settings → Node URL to
  /// `http://10.0.2.2:7019/api/v1/` (Android emulator → host loopback) or `http://127.0.0.1:7019/api/v1/` (desktop).
  static const String defaultNodeUrl = 'https://onion.janzeer.org/api/v1/';
  /// Earlier defaults (the same node under its old name, still served). A stored value equal to one of these is the
  /// default, not a "custom node": 1.2.1 and older shipped `node1`.
  static const List<String> legacyDefaultNodeUrls = ['https://node1.janzeer.org/api/v1/'];
  static const String localNodeUrl = 'http://127.0.0.1:7019/api/v1/';
  /// Shown in Settings → About and in the download rows; keep equal to pubspec.yaml `version`.
  static const String appVersion = '1.2.4';
  static const String explorerUrl = 'https://explorer.janzeer.org';
  /// Where the app looks for a newer release (`latest.json`, see core/update): the project's downloads host first,
  /// the wallet's latest GitHub release as the fallback.
  static const List<String> updateManifestUrls = [
    'https://downloads.janzeer.org/wallet/latest.json',
    'https://github.com/janzeerOrg/janzeer-wallet/releases/latest/download/latest.json',
  ];
  static const String walletPageUrl = 'https://janzeer.org/wallet';
  /// The project's announcement channel (releases, payouts, network notices).
  static const String channelUrl = 'https://t.me/janzeerorg';
}
