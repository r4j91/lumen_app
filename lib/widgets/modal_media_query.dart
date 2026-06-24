import 'package:flutter/material.dart';

/// A PageRoute that presents content as a bottom sheet without wrapping
/// it in MediaQuery.removePadding.
///
/// showModalBottomSheet internally calls MediaQuery.removePadding which creates
/// a modal-internal MediaQuery InheritedElement. In Flutter 3.44.x the modal
/// subtree is deactivated top-down, so that InheritedElement is torn down
/// BEFORE its dependents (TextField, etc.), tripping the assertion:
///   _dependents.isEmpty: is not true
///
/// This route avoids the problem entirely: buildPage() returns content directly,
/// so widgets depend on the app-level MediaQuery (at MaterialApp root) which is
/// never deactivated when a route pops.
class ModalSheetRoute<T> extends PageRoute<T> {
  final WidgetBuilder builder;

  ModalSheetRoute({required this.builder, super.settings});

  @override
  Color get barrierColor => Colors.black54;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  bool get opaque => false;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 240);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    // Align to bottom so the sheet appears at the bottom of the screen.
    // No MediaQuery.removePadding wrapper — content inherits app-level MediaQuery.
    return Align(
      alignment: Alignment.bottomCenter,
      child: builder(context),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      )),
      child: child,
    );
  }
}
