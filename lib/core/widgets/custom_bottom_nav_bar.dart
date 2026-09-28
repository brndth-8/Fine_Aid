import 'package:flutter/material.dart';

/// Describes one destination in [CustomBottomNavBar].
class BottomNavItem {
  final IconData icon;
  final String label;

  const BottomNavItem({required this.icon, required this.label});
}

/// The app's bottom navigation bar: a dark red bar with rounded top
/// corners, holding 3 identical white-bordered circular icon buttons (each
/// poking slightly above the bar), with a label under each.
///
/// The active item's circle turns solid white (its white border blending
/// into the fill) with the icon flipping to the bar's red for contrast;
/// inactive items stay dark red with a visible white ring. Tapping any
/// button plays a short lift + bounce animation before [onItemTap] fires,
/// so the tap feels responsive without delaying navigation.
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
  static const double _barHeight = 78;
  static const double _circleDiameter = 56;
  static const double _circleRaise =
      20; // how far the circles poke above the bar
  static const Color _barColor = Color(0xFFA00000);

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
            end: 0.8,
          ).chain(CurveTween(curve: Curves.easeOut)),
          weight: 30,
        ),
        TweenSequenceItem(
          tween: Tween(
            begin: 0.8,
            end: 1.0,
          ).chain(CurveTween(curve: Curves.easeOutBack)),
          weight: 70,
        ),
      ]).animate(controller);
    }).toList();
    // A short upward slide/lift layered on top of the scale bounce, so a
    // tap feels like it "moves" rather than just shrinking in place.
    _liftAnims = _controllers.map((controller) {
      return TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween(
            begin: 0.0,
            end: -10.0,
          ).chain(CurveTween(curve: Curves.easeOut)),
          weight: 30,
        ),
        TweenSequenceItem(
          tween: Tween(
            begin: -10.0,
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
      height: _barHeight + _circleRaise + bottomInset,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The red bar itself — fixed, always the same size.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: _barHeight + bottomInset,
            child: Container(
              decoration: const BoxDecoration(
                color: _barColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
            ),
          ),

          // The 3 circular buttons, evenly spaced, each poking slightly
          // above the bar's top edge.
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomInset,
            height: _barHeight + _circleRaise,
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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _circleDiameter,
              height: _circleDiameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? Colors.white : _barColor,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: isSelected ? 0.3 : 0.2,
                    ),
                    blurRadius: isSelected ? 8 : 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: Icon(
                  item.icon,
                  key: ValueKey(isSelected),
                  color: isSelected ? _barColor : Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: Theme.of(context).textTheme.labelSmall!.copyWith(
              color: Colors.white,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              height: 1.15,
            ),
            textAlign: TextAlign.center,
            child: Text(item.label, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
