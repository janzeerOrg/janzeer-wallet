/// App-wide constants. Fee/deposit mirror the node's enforced `consensus.*` values (a promoter tx is
/// rejected if its fee or deposit doesn't match exactly).
class AppConfig {
  // ChainSpec.networkId — must equal the node's `consensus.network-id`; bound into every signed tx preimage
  // (cross-chain replay protection, §16.2). Change per network (mainnet / testnet / devnet).
  static const String networkId = 'janzeer';
  static const String minimumFee = '0.01';
  static const String promoterFee = '3'; // fee-promoter-tx
  static const String promoterDeposit = '2000'; // amount-promoter-tx — NON-REFUNDABLE registration deposit (§5, §10)
  static const int maxMemo = 256; // TransferTransactionValidator.MAX_DATA_SIZE
  static const String unit = 'JNZ'; // native-coin ticker (display only)

  /// Default node REST base URL (overridable in Settings). `10.0.2.2` is the host loopback from the Android
  /// emulator; desktop/web use `localhost`.
  static const String defaultNodeUrl = 'http://127.0.0.1:7019/api/v1/';
}
