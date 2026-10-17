import 'package:flutter/material.dart';

/// Describes one destination in [CustomBottomNavBar].
class BottomNavItem {
  final IconData icon;
  final String label;

  /// Short text drawn on top of [icon] (eg "AI" inside the scan frame).
  final String? badge;

  const BottomNavItem({required this.icon, required this.label, this.badge});
}

/// The app's bottom navigation bar: a white bar with rounded top corners and
/// 3 destinations, each an icon with its label underneath. The middle one is
/// the main action — a larger maroon circle with a grey ring that rises above
/// the bar.
///
/// The active destination is drawn in maroon. Tapping any item plays a short
/// lift + bounce animation before [onItemTap] fires, so the tap feels
/// responsive without delaying navigation.
class CustomBottomNavBar extends StatefulWidget {
  final List<BottomNavItem> items;
  final int? selectedIndex;
  final ValueChanged<int> onItemTap;

  /// Optional per-item `GlobalKey`s (same order as [items]), so callers
  /// (eg, the Help Tour) can locate and spotlight an individual button.
  final List<GlobalKey>? itemKeys;

  const CustomBottomNavBar({
    super.key,
    required this.items,
    required this.onItemTap,
    this.selectedIndex,
    this.itemKeys,
  }) : assert(
         items.length == 3,
         'CustomBottomNavBar is designed for exactly 3 items',
       );

  @override
  State<CustomBottomNavBar> createState() => _CustomBottomNavBarState();
}

class _CustomBottomNavBarState extends State<CustomBottomNavBar>
    with TickerProviderStateMixin {
  // Tune the look of the bar here.
  static const double _barHeight = 70;
  static const double _centerDiameter = 60; // the maroon circle
  static const double _centerRing = 5; // the grey ring around it
  static const double _centerRaise = 38; // how far the circle rises above
  static const Color _maroon = Color(0xFF780000);
  static const Color _inactive = Color(0xFF4A4A4A);
  static const Color _ring = Color(0xFFCCCCCC);

  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _scaleAnims;
  late final List<Animation<double>> _liftAnims;

  // Total duration kept inside the requested ~150-300ms window. The dip
  // gets the smaller share of it (a fast, snappy jolt right at tap time,
  // before a page transition has any chance to cover the bar) and the
  // settle gets the rest.
  static const Duration _tapAnimDuration = Duration(milliseconds: 220);

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.items.length,
      (_) => AnimationController(vsync: this, duration: _tapAnimDuration),
    );
    _scaleAnims = _controllers.map((controller) {
      // A quick dip then a slightly overshooting settle — a restrained
      // "press" bounce rather than an exaggerated one.
      return TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween(
            begin: 1.0,
            end: 0.85,
          ).chain(CurveTween(curve: Curves.easeOut)),
          weight: 30,
        ),
        TweenSequenceItem(
          tween: Tween(
            begin: 0.85,
            end: 1.0,
          ).chain(CurveTween(curve: Curves.easeOutBack)),
          weight: 70,
        ),
      ]).animate(controller);
    }).toList();
    // A short upward slide/lift layered on top of the scale bounce.
    _liftAnims = _controllers.map((controller) {
      return TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween(
            begin: 0.0,
            end: -8.0,
          ).chain(CurveTween(curve: Curves.easeOut)),
          weight: 30,
        ),
        TweenSequenceItem(
          tween: Tween(
            begin: -8.0,
            end: 0.0,
          ).chain(CurveTween(curve: Curves.easeOutBack)),
          weight: 70,
        ),
      ]).animate(controller);
    }).toList();
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _handleTap(int index) {
    // Always replays, even if this same button was just tapped. The
    // animation is purely cosmetic and doesn't gate onItemTap, so
    // navigation never waits on it.
    _controllers[index]
      ..reset()
      ..forward();
    widget.onItemTap(index);
  }

  GlobalKey? _keyFor(int index) {
    final keys = widget.itemKeys;
    if (keys == null || index >= keys.length) return null;
    return keys[index];
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return SizedBox(
      height: _barHeight + _centerRaise + bottomInset,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The white bar itself — fixed, always the same size.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: _barHeight + bottomInset,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
            ),
          ),

          // The 3 destinations, evenly spaced; the middle one rises above.
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomInset,
            height: _barHeight + _centerRaise,
            child: Row(
              children: List.generate(
                widget.items.length,
                (i) => Expanded(key: _keyFor(i), child: _buildItem(i)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(int index) {
    final item = widget.items[index];
    final isSelected = widget.selectedIndex == index;
    final isCenter = index == widget.items.length ~/ 2;
    final color = isSelected ? _maroon : _inactive;

    final Widget visual = isCenter
        ? Container(
            width: _centerDiameter + _centerRing * 2,
            height: _centerDiameter + _centerRing * 2,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: _ring,
            ),
            alignment: Alignment.center,
            child: Container(
              width: _centerDiameter,
              height: _centerDiameter,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _maroon,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(item.icon, color: Colors.white, size: 44),
                  if (item.badge != null)
                    Text(
                      item.badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 19,
                        height: 1,
                      ),
                    ),
                ],
              ),
            ),
          )
        : Icon(item.icon, color: color, size: 34);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _handleTap(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          AnimatedBuilder(
            animation: _controllers[index],
            builder: (context, child) => Transform.translate(
              offset: Offset(0, _liftAnims[index].value),
              child: Transform.scale(
                scale: _scaleAnims[index].value,
                child: child,
              ),
            ),
            child: visual,
          ),
          const SizedBox(height: 4),
          Flexible(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: Theme.of(context).textTheme.labelMedium!.copyWith(
                color: isCenter ? _inactive : color,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                height: 1.15,
              ),
              textAlign: TextAlign.center,
              child: Text(
                item.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
