import 'package:intl/intl.dart';

/// Display formatting for on-chain amounts (which arrive as exact decimal strings like "1000.00000000").
/// Groups thousands and trims trailing zeros, keeping the value exact (no float rounding) up to 8 dp.
String prettyAmount(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return '0';
  final neg = value.startsWith('-');
  final t = neg ? value.substring(1) : value;
  final dot = t.indexOf('.');
  final intPart = dot < 0 ? t : t.substring(0, dot);
  var frac = dot < 0 ? '' : t.substring(dot + 1);
  // Trim trailing zeros in the fractional part.
  frac = frac.replaceFirst(RegExp(r'0+$'), '');
  final grouped = NumberFormat.decimalPattern('en').format(BigInt.parse(intPart.isEmpty ? '0' : intPart));
  final out = frac.isEmpty ? grouped : '$grouped.$frac';
  return neg ? '-$out' : out;
}

/// Shorten an address/key for compact display: 0x1234…abcd.
String shortHash(String s, {int head = 6, int tail = 4}) {
  if (s.length <= head + tail + 1) return s;
  return '${s.substring(0, head)}…${s.substring(s.length - tail)}';
}
