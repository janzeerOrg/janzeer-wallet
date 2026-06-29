/// App-wide constants. Fees/stake mirror the node's enforced `consensus.*` values (a vote/promoter tx is
/// rejected if its fee or stake doesn't match exactly).
class AppConfig {
  static const String minimumFee = '0.01';
  static const String voteFeeFor = '3'; // fee-vote-tx-for (delegate)
  static const String voteFeeAgainst = '1'; // fee-vote-tx-against (undelegate)
  static const String promoterFee = '3'; // fee-promoter-tx
  static const String promoterStake = '10'; // amount-promoter-tx (required stake)
  static const int voteForId = 1; // VoteType.FOR
  static const int voteAgainstId = 2; // VoteType.AGAINST
  static const int maxMemo = 256; // TransferTransactionValidator.MAX_DATA_SIZE
  static const String unit = 'JNZ'; // native-coin ticker (display only)

  /// Default node REST base URL (overridable in Settings). `10.0.2.2` is the host loopback from the Android
  /// emulator; desktop/web use `localhost`.
  static const String defaultNodeUrl = 'http://10.0.2.2:7019/api/v1/';
}
