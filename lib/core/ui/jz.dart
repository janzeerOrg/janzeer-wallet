import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../theme/jz_tokens.dart';
import '../utils/format.dart';

/// The wallet's component set, mirroring the explorer's CSS classes: `.card`, `.card-head`, `.btn-primary`,
/// `.btn-ghost`, `.stat-label`, `.tag`, `.mono`, `.wtab`. Every screen composes these; no bare Material `Card`.

/// `.card` — surface, 1 px border, radius 12. [hero] = the wallet hero gradient (`accent-weak → surface`).
class JzCard extends StatelessWidget {
  const JzCard({super.key, required this.child, this.padding = const EdgeInsets.all(JzSpace.s4), this.hero = false, this.onTap, this.margin});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool hero;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final c = JzColors.of(context);
    final box = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: hero ? null : c.surface,
        gradient: hero ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c.accentWeak, c.surface]) : null,
        borderRadius: JzRadius.rMd,
        border: Border.all(color: hero ? c.borderStrong : c.border),
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return box;
    return Material(color: Colors.transparent, child: InkWell(borderRadius: JzRadius.rMd, onTap: onTap, child: box));
  }
}

/// `.card-head` — a 14/600 title with an optional trailing widget and the bottom hairline.
class JzCardHead extends StatelessWidget {
  const JzCardHead(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final c = JzColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(JzSpace.s4, JzSpace.s3, JzSpace.s3, JzSpace.s3),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.border))),
      child: Row(children: [
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleSmall)),
        ?trailing,
      ]),
    );
  }
}

/// `.stat-label` — 11.5 px uppercase, faint, tracked.
class JzStatLabel extends StatelessWidget {
  const JzStatLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: TextStyle(fontSize: 11.5, color: JzColors.of(context).faint, letterSpacing: 0.6, fontWeight: FontWeight.w600));
}

/// A JNZ amount in mono with tabular figures and the unit in muted 600 (`.bal` / `.stat-value`).
class JzAmount extends StatelessWidget {
  const JzAmount(this.amount, {super.key, this.unit = 'JNZ', this.size = 22, this.color, this.weight = FontWeight.w700});
  final String amount;
  final String unit;
  final double size;
  final Color? color;
  final FontWeight weight;
  @override
  Widget build(BuildContext context) {
    final c = JzColors.of(context);
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: amount, style: TextStyle(fontFamily: kMono, fontFeatures: kTabular, fontSize: size, fontWeight: weight, color: color ?? c.text, height: 1.1)),
        TextSpan(text: ' $unit', style: TextStyle(fontSize: size * 0.5, fontWeight: FontWeight.w600, color: c.muted)),
      ]),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// `.mono` — a hash/address in the platform monospace.
class JzMono extends StatelessWidget {
  const JzMono(this.text, {super.key, this.size = 12.5, this.color, this.maxLines = 1});
  final String text;
  final double size;
  final Color? color;
  final int maxLines;
  @override
  Widget build(BuildContext context) => Text(text,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontFamily: kMono, fontFeatures: kTabular, fontSize: size, color: color ?? JzColors.of(context).muted));
}

/// `.addr-pill` — a shortened address, tap to copy.
class JzAddressPill extends StatelessWidget {
  const JzAddressPill(this.address, {super.key, this.head = 10, this.tail = 8, this.full = false});
  final String address;
  final int head, tail;
  final bool full;
  @override
  Widget build(BuildContext context) {
    final c = JzColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () {
          Clipboard.setData(ClipboardData(text: address));
          jzToast('copied'.tr);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(color: c.surface2, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(999)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(child: JzMono(full ? address : shortHash(address, head: head, tail: tail), color: c.text, size: 13)),
            const SizedBox(width: 8),
            Icon(Icons.copy_rounded, size: 14, color: c.muted),
          ]),
        ),
      ),
    );
  }
}

enum JzTagKind { ok, pending, danger, neutral, accent }

/// `.tag` — a status chip on a weak tint.
class JzTag extends StatelessWidget {
  const JzTag(this.text, {super.key, this.kind = JzTagKind.neutral, this.icon});
  final String text;
  final JzTagKind kind;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final c = JzColors.of(context);
    final (fg, bg) = switch (kind) {
      JzTagKind.ok => (c.ok, c.okWeak),
      JzTagKind.pending => (c.pending, c.pendingWeak),
      JzTagKind.danger => (c.danger, c.dangerWeak),
      JzTagKind.accent => (c.accent, c.accentWeak),
      JzTagKind.neutral => (c.muted, c.surface3),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 12, color: fg), const SizedBox(width: 4)],
        Text(text, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
      ]),
    );
  }
}

/// `.btn-primary` — crimson gradient, dark text, soft red shadow. [busy] swaps the icon for a spinner.
class JzPrimaryButton extends StatelessWidget {
  const JzPrimaryButton({super.key, required this.label, this.icon, this.onPressed, this.busy = false, this.expand = true});
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool busy;
  final bool expand;
  @override
  Widget build(BuildContext context) {
    final c = JzColors.of(context);
    final enabled = onPressed != null && !busy;
    final child = Row(mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
      if (busy)
        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: c.onAccent))
      else if (icon != null)
        Icon(icon, size: 18, color: c.onAccent),
      if (busy || icon != null) const SizedBox(width: 8),
      Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.onAccent, fontSize: 14.5, fontWeight: FontWeight.w700))),
    ]);
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Container(
        decoration: BoxDecoration(
          gradient: JzColors.grad,
          borderRadius: JzRadius.rSm,
          boxShadow: enabled ? [BoxShadow(color: JzColors.a1.withValues(alpha: 0.35), blurRadius: 22, offset: const Offset(0, 8), spreadRadius: -12)] : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: JzRadius.rSm,
            onTap: enabled ? onPressed : null,
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13), child: child),
          ),
        ),
      ),
    );
  }
}

/// `.btn-ghost` — surface-2 with a strong border.
class JzGhostButton extends StatelessWidget {
  const JzGhostButton({super.key, required this.label, this.icon, this.onPressed, this.expand = true, this.danger = false});
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool expand;
  final bool danger;
  @override
  Widget build(BuildContext context) {
    final c = JzColors.of(context);
    final fg = danger ? c.danger : c.text;
    return Opacity(
      opacity: onPressed == null ? 0.55 : 1,
      child: Material(
        color: danger ? c.dangerWeak : c.surface2,
        borderRadius: JzRadius.rSm,
        child: InkWell(
          borderRadius: JzRadius.rSm,
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(borderRadius: JzRadius.rSm, border: Border.all(color: danger ? Colors.transparent : c.borderStrong)),
            child: Row(mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
              if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 8)],
              Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg, fontSize: 14.5, fontWeight: FontWeight.w600))),
            ]),
          ),
        ),
      ),
    );
  }
}

/// A big square action (Send / Receive / Scan) — icon on a tinted disc, label under it.
class JzActionTile extends StatelessWidget {
  const JzActionTile({super.key, required this.icon, required this.label, required this.onTap, this.primary = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;
  @override
  Widget build(BuildContext context) {
    final c = JzColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: JzRadius.rMd,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(color: c.surface, borderRadius: JzRadius.rMd, border: Border.all(color: c.border)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: primary ? JzColors.grad : null, color: primary ? null : c.accentWeak),
              child: Icon(icon, size: 21, color: primary ? c.onAccent : c.accent),
            ),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.text)),
          ]),
        ),
      ),
    );
  }
}

/// `.wtabs` — underline tabs, accent when on.
class JzTabs extends StatelessWidget {
  const JzTabs({super.key, required this.tabs, required this.index, required this.onChanged});
  final List<(IconData, String)> tabs;
  final int index;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    final c = JzColors.of(context);
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.border))),
      child: Row(children: [
        for (var i = 0; i < tabs.length; i++)
          Expanded(
            child: InkWell(
              onTap: () => onChanged(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: i == index ? c.accent : Colors.transparent, width: 2))),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(tabs[i].$1, size: 16, color: i == index ? c.accent : c.muted),
                  const SizedBox(width: 6),
                  Flexible(child: Text(tabs[i].$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: i == index ? c.accent : c.muted))),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}

/// An empty state: a faint icon and one sentence.
class JzEmpty extends StatelessWidget {
  const JzEmpty({super.key, required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final c = JzColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(shape: BoxShape.circle, color: c.surface3),
          child: Icon(icon, color: c.faint, size: 24),
        ),
        const SizedBox(height: 12),
        Text(text, textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 13.5)),
        if (action != null) ...[const SizedBox(height: 14), action!],
      ]),
    );
  }
}

/// Skeleton line (`.skeleton`) for lists while loading — never a spinner in a list.
class JzSkeleton extends StatelessWidget {
  const JzSkeleton({super.key, this.height = 14, this.width, this.radius = 6});
  final double height;
  final double? width;
  final double radius;
  @override
  Widget build(BuildContext context) => Container(
        height: height,
        width: width,
        decoration: BoxDecoration(color: JzColors.of(context).surface3, borderRadius: BorderRadius.circular(radius)),
      );
}

/// Three skeleton rows in a card.
class JzSkeletonList extends StatelessWidget {
  const JzSkeletonList({super.key, this.rows = 3});
  final int rows;
  @override
  Widget build(BuildContext context) => JzCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          for (var i = 0; i < rows; i++)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                const JzSkeleton(height: 36, width: 36, radius: 18),
                const SizedBox(width: 12),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [JzSkeleton(width: 120), SizedBox(height: 8), JzSkeleton(width: 180, height: 10)])),
                const JzSkeleton(width: 56, height: 18, radius: 9),
              ]),
            ),
        ]),
      );
}

/// The brand mark (P2), gradient on surfaces, white on the crimson.
class JzMark extends StatelessWidget {
  const JzMark({super.key, this.size = 40, this.white = false});
  final double size;
  final bool white;
  @override
  Widget build(BuildContext context) => Image.asset(white ? 'assets/brand/mark_white.png' : 'assets/brand/mark.png', width: size, height: size, filterQuality: FilterQuality.medium);
}

/// A labelled field group (`.field` + label).
class JzField extends StatelessWidget {
  const JzField({super.key, required this.label, required this.child, this.trailing});
  final String label;
  final Widget child;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final c = JzColors.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: 12.5, color: c.muted, fontWeight: FontWeight.w500))),
        ?trailing,
      ]),
      const SizedBox(height: 6),
      child,
    ]);
  }
}

/// A key/value row inside a review sheet or a detail card.
class JzKv extends StatelessWidget {
  const JzKv(this.label, this.value, {super.key, this.mono = false, this.valueColor});
  final String label;
  final String value;
  final bool mono;
  final Color? valueColor;
  @override
  Widget build(BuildContext context) {
    final c = JzColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 110, child: Text(label, style: TextStyle(color: c.muted, fontSize: 13))),
        Expanded(
          child: Text(value,
              textAlign: TextAlign.end,
              style: TextStyle(color: valueColor ?? c.text, fontSize: 13.5, fontWeight: FontWeight.w600, fontFamily: mono ? kMono : null, fontFeatures: kTabular)),
        ),
      ]),
    );
  }
}

/// A sheet with the standard padding, title and bottom safe area.
Future<T?> showJzSheet<T>(BuildContext context, {required Widget child, String? title, bool dismissible = true}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: dismissible,
    enableDrag: dismissible,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + MediaQuery.viewInsetsOf(ctx).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (title != null) ...[Text(title, style: Theme.of(ctx).textTheme.titleLarge), const SizedBox(height: 14)],
        child,
      ]),
    ),
  );
}

/// One toast style for the whole app (the explorer's floating snackbar).
void jzToast(String message, {bool error = false}) {
  Get.rawSnackbar(
    messageText: Text(message, style: TextStyle(color: error ? JzColors.dark.danger : const Color(0xFFEAEEF6), fontSize: 13.5, fontWeight: FontWeight.w500)),
    backgroundColor: const Color(0xFF1A2130),
    borderColor: error ? const Color(0x66F26D6D) : const Color(0x26FFFFFF),
    borderWidth: 1,
    borderRadius: JzRadius.sm,
    margin: const EdgeInsets.all(12),
    snackPosition: SnackPosition.BOTTOM,
    duration: const Duration(seconds: 3),
    animationDuration: const Duration(milliseconds: 220),
  );
}

/// Section spacing helpers.
const gap4 = SizedBox(height: JzSpace.s1);
const gap8 = SizedBox(height: JzSpace.s2);
const gap12 = SizedBox(height: JzSpace.s3);
const gap16 = SizedBox(height: JzSpace.s4);
const gap24 = SizedBox(height: JzSpace.s5);
const gap32 = SizedBox(height: JzSpace.s6);
