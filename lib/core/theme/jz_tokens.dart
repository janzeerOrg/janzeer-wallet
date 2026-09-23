import 'package:flutter/material.dart';

/// Janzeer design tokens — a mirror of the explorer's `app.css` (`j_frontend/src/assets/app.css`) and the Telegram
/// wallet, so the three wallets look like one product (owner, 2026-09-23: "use the same theme as web/telegram").
/// Colours live in a [ThemeExtension] so every widget reads them from the active theme: `JzColors.of(context)`.
class JzColors extends ThemeExtension<JzColors> {
  const JzColors({
    required this.bg,
    required this.bg2,
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.muted,
    required this.faint,
    required this.accent,
    required this.accentWeak,
    required this.ok,
    required this.okWeak,
    required this.pending,
    required this.pendingWeak,
    required this.danger,
    required this.dangerWeak,
    required this.onAccent,
  });

  final Color bg, bg2, surface, surface2, surface3, border, borderStrong, text, muted, faint;
  final Color accent, accentWeak, ok, okWeak, pending, pendingWeak, danger, dangerWeak, onAccent;

  /// Brand crimson pair — the primary button gradient everywhere (`--a1 → --a2`).
  static const a1 = Color(0xFFC1121F);
  static const a2 = Color(0xFFE23B47);
  static const emerald = Color(0xFF34D399);
  static const grad = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [a1, a2]);

  static const dark = JzColors(
    bg: Color(0xFF080A10),
    bg2: Color(0xFF0B0E16),
    surface: Color(0xFF0F131D),
    surface2: Color(0xFF141926),
    surface3: Color(0xFF1A2130),
    border: Color(0x14FFFFFF),
    borderStrong: Color(0x26FFFFFF),
    text: Color(0xFFEAEEF6),
    muted: Color(0xFF98A2B7),
    faint: Color(0xFF667085),
    accent: Color(0xFFE04651),
    accentWeak: Color(0x24E04651),
    ok: emerald,
    okWeak: Color(0x2434D399),
    pending: Color(0xFFF5A623),
    pendingWeak: Color(0x26F5A623),
    danger: Color(0xFFF26D6D),
    dangerWeak: Color(0x26F26D6D),
    onAccent: Color(0xFF06070B),
  );

  static const light = JzColors(
    bg: Color(0xFFF4F6FB),
    bg2: Color(0xFFEAEEF6),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF5F7FC),
    surface3: Color(0xFFEEF1F8),
    border: Color(0x1A0C142D),
    borderStrong: Color(0x2E0C142D),
    text: Color(0xFF0E1424),
    muted: Color(0xFF55607A),
    faint: Color(0xFF8892A6),
    accent: Color(0xFFA50E1A),
    accentWeak: Color(0x1AA50E1A),
    ok: Color(0xFF15925F),
    okWeak: Color(0x2434D399),
    pending: Color(0xFFB9760A),
    pendingWeak: Color(0x26F5A623),
    danger: Color(0xFFC53B3B),
    dangerWeak: Color(0x26F26D6D),
    onAccent: Color(0xFFFFFFFF),
  );

  static JzColors of(BuildContext context) => Theme.of(context).extension<JzColors>() ?? dark;

  @override
  JzColors copyWith() => this;

  @override
  JzColors lerp(ThemeExtension<JzColors>? other, double t) {
    if (other is! JzColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return JzColors(
      bg: l(bg, other.bg), bg2: l(bg2, other.bg2), surface: l(surface, other.surface), surface2: l(surface2, other.surface2),
      surface3: l(surface3, other.surface3), border: l(border, other.border), borderStrong: l(borderStrong, other.borderStrong),
      text: l(text, other.text), muted: l(muted, other.muted), faint: l(faint, other.faint), accent: l(accent, other.accent),
      accentWeak: l(accentWeak, other.accentWeak), ok: l(ok, other.ok), okWeak: l(okWeak, other.okWeak),
      pending: l(pending, other.pending), pendingWeak: l(pendingWeak, other.pendingWeak), danger: l(danger, other.danger),
      dangerWeak: l(dangerWeak, other.dangerWeak), onAccent: l(onAccent, other.onAccent),
    );
  }
}

/// Spacing scale (`--sp-1 … --sp-6`).
abstract final class JzSpace {
  static const double s1 = 4, s2 = 8, s3 = 12, s4 = 16, s5 = 24, s6 = 32;
}

/// Radii (`--radius-sm / --radius / --radius-lg`).
abstract final class JzRadius {
  static const double sm = 8, md = 12, lg = 18;
  static final BorderRadius rSm = BorderRadius.circular(sm);
  static final BorderRadius rMd = BorderRadius.circular(md);
  static final BorderRadius rLg = BorderRadius.circular(lg);
}

/// Monospace for hashes and numbers (`--mono` + tabular figures).
const List<FontFeature> kTabular = [FontFeature.tabularFigures()];
const String kMono = 'monospace';
