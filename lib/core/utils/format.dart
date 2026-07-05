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

// ---- token base-unit conversion (lossless string math — token amounts can exceed native int range) ----

/// Human amount ("1.5") -> integer base-unit decimal string for [decimals] places (truncates extra fraction).
String toBaseUnits(String human, int decimals) {
  var s = human.trim();
  if (s.isEmpty || s == '.') return '0';
  final neg = s.startsWith('-');
  if (neg) s = s.substring(1);
  final dot = s.indexOf('.');
  var intPart = dot < 0 ? s : s.substring(0, dot);
  var frac = dot < 0 ? '' : s.substring(dot + 1);
  if (intPart.isEmpty) intPart = '0';
  frac = (frac + '0' * decimals).substring(0, decimals);
  var combined = (intPart + frac).replaceFirst(RegExp(r'^0+(?=\d)'), '');
  if (combined.isEmpty) combined = '0';
  return neg ? '-$combined' : combined;
}

/// Integer base units -> human decimal string with [decimals] places (trailing zeros trimmed).
String fromBaseUnits(String base, int decimals) {
  var s = base.trim();
  if (s.isEmpty) s = '0';
  final neg = s.startsWith('-');
  if (neg) s = s.substring(1);
  s = s.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  if (s.isEmpty) s = '0';
  if (decimals == 0) return neg ? '-$s' : s;
  s = s.padLeft(decimals + 1, '0');
  final intPart = s.substring(0, s.length - decimals);
  final frac = s.substring(s.length - decimals).replaceFirst(RegExp(r'0+$'), '');
  final out = frac.isEmpty ? intPart : '$intPart.$frac';
  return neg ? '-$out' : out;
}

/// Human, thousands-grouped token amount from integer base units.
String formatToken(String base, int decimals) => prettyAmount(fromBaseUnits(base, decimals));

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
