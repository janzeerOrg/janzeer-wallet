import 'package:flutter/material.dart';

import '../theme/jz_tokens.dart';
import 'responsive.dart';

class AdaptiveDestination {
  final IconData icon;
  final String label;
  const AdaptiveDestination(this.icon, this.label);
}

/// Responsive navigation shell: a bottom [NavigationBar] on mobile, a [NavigationRail] on tablet, and an
/// extended rail on desktop. Body content is width-capped + centered on large screens via [ContentColumn].
/// The bar is flat on the page background with a hairline under it, like the explorer's top bar.
class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({
    super.key,
    required this.title,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelect,
    required this.body,
    this.actions,
    this.leading,
  });

  final String title;
  final List<AdaptiveDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final Widget body;
  final List<Widget>? actions;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final factor = Responsive.of(context);
    final c = JzColors.of(context);
    final content = SafeArea(child: ContentColumn(child: body));
    final bar = AppBar(
      title: Text(title),
      actions: actions,
      leading: leading,
      leadingWidth: leading == null ? null : 48,
      titleSpacing: leading == null ? null : 10,
      bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: c.border)),
    );
    if (factor == FormFactor.mobile) {
      return Scaffold(
        appBar: bar,
        body: content,
        bottomNavigationBar: Container(
          decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
          child: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: onSelect,
            destinations: [
              for (final d in destinations) NavigationDestination(icon: Icon(d.icon), label: d.label),
            ],
          ),
        ),
      );
    }
    final extended = factor == FormFactor.desktop;
    return Scaffold(
      appBar: bar,
      body: Row(
        children: [
          NavigationRail(
            extended: extended,
            minExtendedWidth: 180,
            selectedIndex: selectedIndex,
            onDestinationSelected: onSelect,
            labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
            destinations: [
              for (final d in destinations) NavigationRailDestination(icon: Icon(d.icon), label: Text(d.label)),
            ],
          ),
          VerticalDivider(width: 1, color: c.border),
          Expanded(child: content),
        ],
      ),
    );
  }
}
