import 'package:flutter/widgets.dart';

enum FormFactor { mobile, tablet, desktop }

/// Breakpoint helper for mobile/tablet/desktop layouts.
class Responsive {
  static const double tabletMin = 600;
  static const double desktopMin = 1024;

  static FormFactor of(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < tabletMin) return FormFactor.mobile;
    if (w < desktopMin) return FormFactor.tablet;
    return FormFactor.desktop;
  }

  static bool isMobile(BuildContext c) => of(c) == FormFactor.mobile;
  static bool isDesktop(BuildContext c) => of(c) == FormFactor.desktop;

  /// Content width cap so forms/cards don't stretch on large screens.
  static double contentWidth(BuildContext c) => MediaQuery.sizeOf(c).width.clamp(0, 560).toDouble();
}

/// Centers + width-constrains page content (no-op visual on mobile, comfortable column on big screens).
class ContentColumn extends StatelessWidget {
  const ContentColumn({super.key, required this.child, this.maxWidth = 560});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
