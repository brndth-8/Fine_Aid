import 'package:flutter/material.dart';

/// One stop of the Help Tour. [targetKey] is the `GlobalKey` of the real
/// UI element to spotlight; leave it null for an intro/centered step.
class HelpTourStep {
  final GlobalKey? targetKey;
  final String title;
  final String description;
  final IconData icon;

  const HelpTourStep({
    this.targetKey,
    required this.title,
    required this.description,
    this.icon = Icons.info_outline,
  });
}

/// A full-screen, animated coach-mark tour: dims everything except the
/// current step's target widget (cut out via a spotlight hole that glides
/// between steps), with a tooltip card carrying Next/Back/Skip controls.
///
/// Meant to be placed as the top layer of a `Stack` above the screen it
/// tours, so the target widgets' `GlobalKey`s resolve to real, still-
/// mounted `RenderBox`es underneath.
class HelpTourOverlay extends StatefulWidget {
  final List<HelpTourStep> steps;
  final VoidCallback onFinished;

  const HelpTourOverlay({
    super.key,
    required this.steps,
    required this.onFinished,
  });

  @override
  State<HelpTourOverlay> createState() => _HelpTourOverlayState();
}

class _HelpTourOverlayState extends State<HelpTourOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _index = 0;
  Rect? _displayRect;
  VoidCallback? _activeListener;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _displayRect = _targetRect(widget.steps[_index].targetKey));
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Rect? _targetRect(GlobalKey? key) {
    if (key == null) return null;
    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) return null;
    final topLeft = renderObject.localToGlobal(Offset.zero);
    return topLeft & renderObject.size;
  }

  void _goTo(int newIndex) {
    final newRect = _targetRect(widget.steps[newIndex].targetKey);
    final tween = RectTween(begin: _displayRect, end: newRect);

    if (_activeListener != null) _controller.removeListener(_activeListener!);
    _activeListener = () {
      setState(() {
        _displayRect = tween.lerp(
          Curves.easeInOutCubic.transform(_controller.value),
        );
      });
    };
    _controller
      ..addListener(_activeListener!)
      ..reset();
    setState(() => _index = newIndex);
    _controller.forward();
  }

  void _next() {
    if (_index >= widget.steps.length - 1) {
      widget.onFinished();
    } else {
      _goTo(_index + 1);
    }
  }

  void _back() {
    if (_index > 0) _goTo(_index - 1);
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_index];
    final screenSize = MediaQuery.of(context).size;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {}, // swallow taps on the dimmed backdrop
              child: CustomPaint(painter: _SpotlightPainter(_displayRect)),
            ),
          ),
          _buildTooltipCard(context, step, screenSize),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 12,
            child: TextButton(
              onPressed: widget.onFinished,
              style: TextButton.styleFrom(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('Skip Tour'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTooltipCard(BuildContext context, HelpTourStep step, Size screenSize) {
    final theme = Theme.of(context);
    final cardWidth = screenSize.width < 360 ? screenSize.width - 32 : 300.0;
    final rect = _displayRect;

    final left = ((rect?.center.dx ?? screenSize.width / 2) - cardWidth / 2)
        .clamp(16.0, (screenSize.width - cardWidth - 16).clamp(16.0, double.infinity));

    double top;
    if (rect == null) {
      top = screenSize.height / 2 - 110;
    } else {
      final spaceBelow = screenSize.height - rect.bottom;
      if (spaceBelow > 240) {
        top = rect.bottom + 20;
      } else {
        top = (rect.top - 20 - 220).clamp(
          MediaQuery.of(context).padding.top + 60,
          screenSize.height - 240,
        );
      }
    }

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOutCubic,
      left: left,
      top: top,
      width: cardWidth,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.05),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: Container(
          key: ValueKey(_index),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(color: Colors.black38, blurRadius: 16, offset: Offset(0, 6)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(step.icon, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      step.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(step.description, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_index + 1} / ${widget.steps.length}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                  Row(
                    children: [
                      if (_index > 0)
                        TextButton(onPressed: _back, child: const Text('Back')),
                      const SizedBox(width: 4),
                      ElevatedButton(
                        onPressed: _next,
                        child: Text(
                          _index == widget.steps.length - 1 ? 'Done' : 'Next',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect? rect;
  _SpotlightPainter(this.rect);

  @override
  void paint(Canvas canvas, Size size) {
    final barrierPaint = Paint()..color = Colors.black.withValues(alpha: 0.72);
    final fullPath = Path()..addRect(Offset.zero & size);

    if (rect == null || rect!.width <= 0 || rect!.height <= 0) {
      canvas.drawPath(fullPath, barrierPaint);
      return;
    }

    final padded = rect!.inflate(10);
    final holeRRect = RRect.fromRectAndRadius(padded, const Radius.circular(18));
    final holePath = Path()..addRRect(holeRRect);
    final combined = Path.combine(PathOperation.difference, fullPath, holePath);
    canvas.drawPath(combined, barrierPaint);

    final ringPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(holeRRect, ringPaint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.rect != rect;
}
