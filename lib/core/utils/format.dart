/// Display formatting for on-chain amounts (which arrive as exact decimal strings like "1000.00000000").
/// Groups thousands and trims trailing zeros, keeping the value exact (no float rounding) up to 8 dp.
///
/// NOTE: this deliberately does NOT use intl's NumberFormat — passing a BigInt to
/// NumberFormat.format() throws `int is not a subtype of BigInt` in intl 0.20.2 (its `_floor` does
/// `number ~/ 1`), which crashed the wallet home screen for any balance. We group digits with a pure
/// string regex instead, which is both crash-free and exact.
String prettyAmount(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return '0';
  final neg = value.startsWith('-');
  final t = neg ? value.substring(1) : value;
  final dot = t.indexOf('.');
  var intPart = dot < 0 ? t : t.substring(0, dot);
  if (intPart.isEmpty) intPart = '0';
  var frac = dot < 0 ? '' : t.substring(dot + 1);
  // Trim trailing zeros in the fractional part.
  frac = frac.replaceFirst(RegExp(r'0+$'), '');
  // Insert thousands separators into the integer part (e.g. 1234567 -> 1,234,567).
  final grouped = intPart.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  final out = frac.isEmpty ? grouped : '$grouped.$frac';
  return neg ? '-$out' : out;
}

/// Shorten an address/key for compact display: 0x1234…abcd.
String shortHash(String s, {int head = 6, int tail = 4}) {
  if (s.length <= head + tail + 1) return s;
  return '${s.substring(0, head)}…${s.substring(s.length - tail)}';
}

/// Compact relative age from an epoch-millis timestamp: "12s" / "3m" / "2h" / "1d". Unit letters read fine
/// under both LTR and RTL, so no localization needed for this compact form.
String timeAgo(dynamic ms) {
  if (ms == null) return '';
  final t = (ms as num).toInt();
  final s = ((DateTime.now().millisecondsSinceEpoch - t) / 1000).floor();
  if (s < 5) return 'now';
  if (s < 60) return '${s}s';
  if (s < 3600) return '${(s / 60).floor()}m';
  if (s < 86400) return '${(s / 3600).floor()}h';
  return '${(s / 86400).floor()}d';
}
