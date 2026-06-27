import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import 'popover_style.dart';
import 'package:hugeicons/hugeicons.dart';

// ── Data model ────────────────────────────────────────────────────────────────

class AnchoredMenuItem {
  final String id;
  final String label;
  final IconData? icon;
  final Color? iconColor;
  final bool selected;

  const AnchoredMenuItem({
    required this.id,
    required this.label,
    this.icon,
    this.iconColor,
    this.selected = false,
  });
}

class AnchoredMultiSelectItem {
  final String id;
  final String label;
  final Color? dotColor;

  const AnchoredMultiSelectItem({
    required this.id,
    required this.label,
    this.dotColor,
  });
}

// ── Public API ─────────────────────────────────────────────────────────────────

/// Shows an anchored multi-select popover next to [anchorKey].
/// Returns the new selected Set<String>, or null if dismissed without confirming.
///
/// Uses Overlay directly (no Navigator.pop) to avoid conflicts when opened
/// from inside a ModalRoute (bottom sheet / dialog).
Future<Set<String>?> showAnchoredMultiSelectMenu({
  required BuildContext context,
  required GlobalKey anchorKey,
  required List<AnchoredMultiSelectItem> items,
  required Set<String> selectedIds,
  double menuWidth = 260,
  double maxHeight = 320,
  String confirmLabel = 'Concluído',
}) async {
  final box = anchorKey.currentContext?.findRenderObject() as RenderBox?;
  if (box == null) return null;

  final screen     = MediaQuery.of(context).size;
  final safeTop    = MediaQuery.of(context).viewPadding.top;
  final safeBottom = MediaQuery.of(context).viewPadding.bottom;
  final anchorOffset = box.localToGlobal(Offset.zero);
  final anchorSize   = box.size;

  final rawView   = WidgetsBinding.instance.platformDispatcher.views.first;
  final keyboardH = rawView.viewInsets.bottom / rawView.devicePixelRatio;
  final keyboardTop = screen.height - keyboardH;

  // Safety margin between the menu's bottom edge and the keyboard top, so the
  // bottom border-radius is never clipped flush against the keyboard.
  const kbSafeMargin = 10.0;
  final naturalBottomAbove = anchorOffset.dy - 4;
  final bottomAbove = keyboardH > 0
      ? math.min(naturalBottomAbove, keyboardTop - kbSafeMargin)
      : naturalBottomAbove;

  final availableAbove = bottomAbove - safeTop - 12;
  final clampedMax = math.min(maxHeight, math.max(availableAbove, 80.0));
  final estimatedH = math.min(clampedMax, items.length * 52.0 + 16);

  final spaceBelow = keyboardTop - anchorOffset.dy - anchorSize.height - safeBottom;
  final showAbove  = spaceBelow < estimatedH;

  double left = anchorOffset.dx;
  if (left + menuWidth > screen.width - 8) left = screen.width - menuWidth - 8;
  left = math.max(8, left);

  final double top = showAbove
      ? bottomAbove - estimatedH
      : anchorOffset.dy + anchorSize.height + 4;

  final completer = Completer<Set<String>?>();
  late OverlayEntry entry;

  void close(Set<String>? result) {
    if (completer.isCompleted) return;
    entry.remove();
    completer.complete(result);
  }

  entry = OverlayEntry(
    builder: (_) => _AnchoredMultiSelectOverlay(
      items: items,
      initialSelectedIds: Set.from(selectedIds),
      confirmLabel: confirmLabel,
      left: left,
      top: top,
      menuWidth: menuWidth,
      maxHeight: clampedMax, // use clamped value, not original maxHeight
      showAbove: showAbove,
      onConfirm: (ids) => close(ids),
      onDismiss: () => close(null),
    ),
  );

  Overlay.of(context, rootOverlay: true).insert(entry);
  return completer.future;
}

/// Shows an anchored selection popover next to [anchorKey].
/// Returns the [AnchoredMenuItem.id] of the selected item, or null if dismissed.
///
/// The menu:
/// - Anchors to the bottom-left of the anchor widget, with automatic flip when
///   there is not enough space below.
/// - Has no header, title, or drag handle.
/// - Highlights the full row for the selected item.
/// - Animates in/out with scale+fade in ~150ms.
/// - Closes on tap-outside, Esc, or selection.
Future<String?> showAnchoredSelectMenu({
  required BuildContext context,
  required GlobalKey anchorKey,
  required List<AnchoredMenuItem> items,
  double menuWidth = 260,
  double maxHeight = 320,
}) async {
  final box = anchorKey.currentContext?.findRenderObject() as RenderBox?;
  if (box == null) return null;

  final screen     = MediaQuery.of(context).size;
  final safeTop    = MediaQuery.of(context).viewPadding.top;
  final safeBottom = MediaQuery.of(context).viewPadding.bottom;
  final anchorOffset = box.localToGlobal(Offset.zero);
  final anchorSize   = box.size;

  final rawView   = WidgetsBinding.instance.platformDispatcher.views.first;
  final keyboardH = rawView.viewInsets.bottom / rawView.devicePixelRatio;
  final keyboardTop = screen.height - keyboardH;

  // Safety margin between the menu's bottom edge and the keyboard top, so the
  // bottom border-radius is never clipped flush against the keyboard.
  const kbSafeMargin = 10.0;
  final naturalBottomAbove = anchorOffset.dy - 4;
  final bottomAbove = keyboardH > 0
      ? math.min(naturalBottomAbove, keyboardTop - kbSafeMargin)
      : naturalBottomAbove;

  final availableAbove = bottomAbove - safeTop - 12;
  final clampedMax = math.min(maxHeight, math.max(availableAbove, 80.0));
  final estimatedH = math.min(clampedMax, items.length * 52.0 + 16);

  final spaceBelow = keyboardTop - anchorOffset.dy - anchorSize.height - safeBottom;
  final showAbove  = spaceBelow < estimatedH;

  // Horizontal: left-align to anchor, clamp to screen edges
  double left = anchorOffset.dx;
  if (left + menuWidth > screen.width - 8) left = screen.width - menuWidth - 8;
  left = math.max(8, left);

  final double top = showAbove
      ? bottomAbove - estimatedH
      : anchorOffset.dy + anchorSize.height + 4;

  // Use Overlay (not showGeneralDialog/Navigator) so the software keyboard
  // stays open — pushing a Navigator route causes FocusScope.unfocus() which
  // dismisses the keyboard, producing inconsistent behavior vs. the multi-
  // select overlay that already used this pattern.
  //
  // OLD (showGeneralDialog — commented for revert):
  // return showGeneralDialog<String>(
  //   context: context,
  //   barrierDismissible: true,
  //   barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
  //   barrierColor: Colors.transparent,
  //   transitionDuration: const Duration(milliseconds: 150),
  //   pageBuilder: (ctx, animation, secondaryAnimation) {
  //     return _AnchoredMenuOverlay(
  //       items: items, left: left, top: top, menuWidth: menuWidth,
  //       maxHeight: maxHeight, showAbove: showAbove, animation: animation,
  //     );
  //   },
  // );

  final completer = Completer<String?>();
  late OverlayEntry entry;

  void close(String? result) {
    if (completer.isCompleted) return;
    entry.remove();
    completer.complete(result);
  }

  entry = OverlayEntry(
    builder: (_) => _AnchoredMenuOverlay(
      items: items,
      left: left,
      top: top,
      menuWidth: menuWidth,
      maxHeight: clampedMax,
      showAbove: showAbove,
      onSelect: (id) => close(id),
      onDismiss: () => close(null),
    ),
  );

  Overlay.of(context, rootOverlay: true).insert(entry);
  return completer.future;
}

// ── Overlay widget ─────────────────────────────────────────────────────────────
//
// Converted from StatelessWidget (with external Animation) to StatefulWidget
// with its own AnimationController so it can be used via Overlay.insert()
// without requiring a Navigator route — which was causing keyboard dismissal.
// OLD StatelessWidget version commented below for revert reference.

class _AnchoredMenuOverlay extends StatefulWidget {
  final List<AnchoredMenuItem> items;
  final double left;
  final double top;
  final double menuWidth;
  final double maxHeight;
  final bool showAbove;
  final void Function(String) onSelect;
  final VoidCallback onDismiss;

  const _AnchoredMenuOverlay({
    required this.items,
    required this.left,
    required this.top,
    required this.menuWidth,
    required this.maxHeight,
    required this.showAbove,
    required this.onSelect,
    required this.onDismiss,
  });

  @override
  State<_AnchoredMenuOverlay> createState() => _AnchoredMenuOverlayState();
}

class _AnchoredMenuOverlayState extends State<_AnchoredMenuOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    )..forward();
    _fade  = CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.65));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alignment =
        widget.showAbove ? Alignment.bottomLeft : Alignment.topLeft;

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          widget.onDismiss();
        }
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.onDismiss,
              behavior: HitTestBehavior.translucent,
            ),
          ),
          Positioned(
            left: widget.left,
            top: widget.top,
            width: widget.menuWidth,
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.90, end: 1.0).animate(_scale),
                alignment: alignment,
                child: _MenuCard(
                  items: widget.items,
                  maxHeight: widget.maxHeight,
                  onSelect: widget.onSelect,
                  onDismiss: widget.onDismiss,
                  showAbove: widget.showAbove,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// OLD StatelessWidget version (showGeneralDialog era) — kept for revert:
// class _AnchoredMenuOverlay extends StatelessWidget {
//   final List<AnchoredMenuItem> items;
//   final double left;
//   final double top;
//   final double menuWidth;
//   final double maxHeight;
//   final bool showAbove;
//   final Animation<double> animation;
//   const _AnchoredMenuOverlay({required this.items, required this.left,
//     required this.top, required this.menuWidth, required this.maxHeight,
//     required this.showAbove, required this.animation});
//   @override
//   Widget build(BuildContext context) {
//     final scaleAnim = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
//     final fadeAnim  = CurvedAnimation(parent: animation, curve: const Interval(0.0, 0.65));
//     final alignment = showAbove ? Alignment.bottomLeft : Alignment.topLeft;
//     return Stack(children: [
//       Positioned.fill(child: GestureDetector(
//         onTap: () => Navigator.of(context).pop(),
//         behavior: HitTestBehavior.translucent)),
//       Positioned(left: left, top: top, width: menuWidth,
//         child: FadeTransition(opacity: fadeAnim,
//           child: ScaleTransition(scale: Tween<double>(begin: 0.90, end: 1.0).animate(scaleAnim),
//             alignment: alignment,
//             child: _MenuCard(items: items, maxHeight: maxHeight)))),
//     ]);
//   }
// }

// ── Menu card ─────────────────────────────────────────────────────────────────

class _MenuCard extends StatelessWidget {
  final List<AnchoredMenuItem> items;
  final double maxHeight;
  final void Function(String) onSelect;
  final VoidCallback onDismiss;
  // Kept so callers/animation alignment still work; corners are always fully
  // rounded now (previously flattened to 0 when showAbove=true, which made the
  // menu appear cut off when anchored close to the keyboard — see kbSafeMargin
  // in showAnchoredSelectMenu/showAnchoredMultiSelectMenu for the real fix).
  final bool showAbove;

  const _MenuCard({
    required this.items,
    required this.maxHeight,
    required this.onSelect,
    required this.onDismiss,
    required this.showAbove,
  });

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(PopoverStyle.radius);

    return Material(
        color: Colors.transparent,
        child: CustomPaint(
          foregroundPainter: const PopoverBorderPainter(),
          child: Container(
            decoration: BoxDecoration(borderRadius: br, boxShadow: PopoverStyle.shadows),
            child: ClipRRect(
              borderRadius: br,
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: PopoverStyle.blurSigma,
                  sigmaY: PopoverStyle.blurSigma,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: PopoverStyle.bg,
                    borderRadius: br,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxHeight),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: items
                            .map((item) => _MenuItemRow(
                                  item: item,
                                  onSelect: onSelect,
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
  }
}

// ── Individual row ─────────────────────────────────────────────────────────────

class _MenuItemRow extends StatefulWidget {
  final AnchoredMenuItem item;
  final void Function(String) onSelect;
  const _MenuItemRow({required this.item, required this.onSelect});

  @override
  State<_MenuItemRow> createState() => _MenuItemRowState();
}

class _MenuItemRowState extends State<_MenuItemRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    Color bg;
    if (item.selected) {
      bg = AppColors.accent.withValues(alpha: 0.14);
    } else if (_hovered) {
      bg = AppColors.textPrimary.withValues(alpha: 0.06);
    } else {
      bg = Colors.transparent;
    }

    final labelColor = item.selected
        ? AppColors.textPrimary
        : AppColors.textPrimary.withValues(alpha: 0.85);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        // OLD: onTap: () => Navigator.of(context).pop(item.id),
        onTap: () => widget.onSelect(item.id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          height: 52, // was 48 — increased for comfortable touch target on iPhone
          color: bg,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              if (item.icon != null) ...[
                Icon(
                  item.icon,
                  size: 18,
                  color: item.iconColor ??
                      (item.selected
                          ? AppColors.accent
                          : AppColors.textSecondary),
                ),
                const SizedBox(width: 11),
              ],
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        item.selected ? FontWeight.w600 : FontWeight.w400,
                    color: labelColor,
                  ),
                ),
              ),
              if (item.selected)
                HugeIcon(icon: HugeIcons.strokeRoundedTick01, size: 16, color: AppColors.accent),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Multi-select overlay ───────────────────────────────────────────────────────

class _AnchoredMultiSelectOverlay extends StatefulWidget {
  final List<AnchoredMultiSelectItem> items;
  final Set<String> initialSelectedIds;
  final String confirmLabel;
  final double left;
  final double top;
  final double menuWidth;
  final double maxHeight;
  final bool showAbove;
  final void Function(Set<String>) onConfirm;
  final VoidCallback onDismiss;

  const _AnchoredMultiSelectOverlay({
    required this.items,
    required this.initialSelectedIds,
    required this.confirmLabel,
    required this.left,
    required this.top,
    required this.menuWidth,
    required this.maxHeight,
    required this.showAbove,
    required this.onConfirm,
    required this.onDismiss,
  });

  @override
  State<_AnchoredMultiSelectOverlay> createState() =>
      _AnchoredMultiSelectOverlayState();
}

class _AnchoredMultiSelectOverlayState extends State<_AnchoredMultiSelectOverlay>
    with SingleTickerProviderStateMixin {
  late final Set<String> _selected;
  late final FocusNode _focusNode;
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.initialSelectedIds);
    _focusNode = FocusNode();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    )..forward();
    _fade  = CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.65));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) _selected.remove(id);
      else _selected.add(id);
    });
    // Part 5: close immediately after each toggle — no "Concluído" button.
    // User reopens the menu to toggle additional items; state persists via
    // initialSelectedIds in quick_add_task_sheet (rebuilt each open).
    _confirm();
  }

  void _dismiss() => widget.onDismiss();
  void _confirm() => widget.onConfirm(Set.from(_selected));

  @override
  Widget build(BuildContext context) {
    final alignment =
        widget.showAbove ? Alignment.bottomLeft : Alignment.topLeft;

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          _dismiss();
        }
      },
      child: Stack(
        children: [
          // Barrier: tap-outside → dismiss
          Positioned.fill(
            child: GestureDetector(
              onTap: _dismiss,
              behavior: HitTestBehavior.opaque,
            ),
          ),
          Positioned(
            left: widget.left,
            top: widget.top,
            width: widget.menuWidth,
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.90, end: 1.0).animate(_scale),
                alignment: alignment,
                child: _MultiSelectCard(
                  items: widget.items,
                  selected: _selected,
                  onToggle: _toggle,
                  maxHeight: widget.maxHeight,
                  showAbove: widget.showAbove,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// OLD _MultiSelectCard with footer "Concluído" button — commented for revert:
// onConfirm / confirmLabel params removed (Part 5: immediate close on toggle).
// showAbove added (Part 4: flat bottom corners when above anchor).
// maxHeight - 52 → maxHeight (Part 5: no footer height reservation).
class _MultiSelectCard extends StatelessWidget {
  final List<AnchoredMultiSelectItem> items;
  final Set<String> selected;
  final void Function(String id) onToggle;
  final double maxHeight;
  final bool showAbove;

  const _MultiSelectCard({
    required this.items,
    required this.selected,
    required this.onToggle,
    required this.maxHeight,
    required this.showAbove,
  });

  @override
  Widget build(BuildContext context) {
    // Corners are always fully rounded now — previously flattened to 0 when
    // showAbove=true, which made the menu look cut off near the keyboard.
    // See kbSafeMargin in showAnchoredMultiSelectMenu for the real fix.
    final br = BorderRadius.circular(PopoverStyle.radius);

    return Material(
      color: Colors.transparent,
      child: CustomPaint(
        foregroundPainter: const PopoverBorderPainter(),
        child: Container(
          decoration: BoxDecoration(borderRadius: br, boxShadow: PopoverStyle.shadows),
          child: ClipRRect(
            borderRadius: br,
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: PopoverStyle.blurSigma,
                sigmaY: PopoverStyle.blurSigma,
              ),
              child: Container(
                decoration: BoxDecoration(color: PopoverStyle.bg, borderRadius: br),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: items
                          .map((item) => _MultiSelectItemRow(
                                item: item,
                                selected: selected.contains(item.id),
                                onTap: () => onToggle(item.id),
                              ))
                          .toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MultiSelectItemRow extends StatefulWidget {
  final AnchoredMultiSelectItem item;
  final bool selected;
  final VoidCallback onTap;

  const _MultiSelectItemRow({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_MultiSelectItemRow> createState() => _MultiSelectItemRowState();
}

class _MultiSelectItemRowState extends State<_MultiSelectItemRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    Color bg;
    if (widget.selected) {
      bg = (item.dotColor ?? AppColors.accent).withValues(alpha: 0.12);
    } else if (_hovered) {
      bg = AppColors.textPrimary.withValues(alpha: 0.06);
    } else {
      bg = Colors.transparent;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          height: 52, // was 48 — increased for comfortable touch target
          color: bg,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: item.dotColor ?? AppColors.textTertiary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: widget.selected
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: AppColors.textPrimary
                        .withValues(alpha: widget.selected ? 1.0 : 0.85),
                  ),
                ),
              ),
              if (widget.selected)
                HugeIcon(icon: HugeIcons.strokeRoundedTick01,
                  size: 16,
                  color: item.dotColor ?? AppColors.accent,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Border painter ─────────────────────────────────────────────────────────────
// Migrated to PopoverBorderPainter in popover_style.dart.
// Kept below for manual revert if needed.

/*
class _BorderPainter extends CustomPainter {
  static const double _radius = 20.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(_radius));

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x4DFFFFFF), // topo  ~30% white
          Color(0x26FFFFFF), // meio  ~15% white
          Color(0x1FFFFFFF), // base  ~12% white
        ],
        stops: [0.0, 0.45, 1.0],
      ).createShader(rect);

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_BorderPainter oldDelegate) => false;
}
*/
