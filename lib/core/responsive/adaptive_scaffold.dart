import 'package:flutter/material.dart';

import 'responsive.dart';

class AdaptiveDestination {
  final IconData icon;
  final String label;
  const AdaptiveDestination(this.icon, this.label);
}

/// Responsive navigation shell: a bottom [NavigationBar] on mobile, a [NavigationRail] on tablet, and an
/// extended rail on desktop. Body content is width-capped + centered on large screens via [ContentColumn].
class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({
    super.key,
    required this.title,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelect,
    required this.body,
    this.actions,
  });

  final String title;
  final List<AdaptiveDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final Widget body;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final factor = Responsive.of(context);
    final content = SafeArea(child: ContentColumn(child: body));

    if (factor == FormFactor.mobile) {
      return Scaffold(
        appBar: AppBar(title: Text(title), actions: actions),
        body: content,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onSelect,
          destinations: [
            for (final d in destinations) NavigationDestination(icon: Icon(d.icon), label: d.label),
          ],
        ),
      );
    }

    final extended = factor == FormFactor.desktop;
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: Row(
        children: [
          NavigationRail(
            extended: extended,
            minExtendedWidth: 180,
            selectedIndex: selectedIndex,
            onDestinationSelected: onSelect,
            labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
            destinations: [
              for (final d in destinations)
                NavigationRailDestination(icon: Icon(d.icon), label: Text(d.label)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: content),
        ],
      ),
    );
  }
}
