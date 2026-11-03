import 'package:flutter/material.dart';

/// A shared-controller thumb for the long asset page. The caller retains the
/// controller so rebuilds and searches keep the current page position.
class AssetPageScrollFrame extends StatelessWidget {
  const AssetPageScrollFrame({
    super.key,
    required this.controller,
    required this.compact,
    required this.child,
  });

  final ScrollController controller;
  final bool compact;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: Scrollbar(
        key: const Key('asset_page_scrollbar'),
        controller: controller,
        thumbVisibility: !compact,
        trackVisibility: !compact,
        interactive: true,
        thickness: compact ? 4 : 8,
        child: child,
      ),
    );
  }
}
