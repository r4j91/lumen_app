import 'package:flutter/material.dart';

/// Constrains content to a readable max-width and centers it horizontally.
/// All existing screens render as-is inside — no visual modification.
class DesktopContentArea extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const DesktopContentArea({
    super.key,
    required this.child,
    this.maxWidth = 920,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= maxWidth) return child;
        // Preserve tight height so scrollable screens fill the content area.
        // Without explicit height, Center + SizedBox gives loose constraints
        // and IndexedStack collapses to zero height (invisible grey rect).
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: (constraints.maxWidth - maxWidth) / 2,
            ),
            child: child,
          ),
        );
      },
    );
  }
}
