import 'package:flutter/material.dart';

class ScanBeam extends StatefulWidget {
  final bool active; // whether to animate
  final double topPadding;
  final double bottomPadding;
  final Duration duration;

  const ScanBeam({
    super.key,
    required this.active,
    this.topPadding = 80,
    this.bottomPadding = 340,
    this.duration = const Duration(seconds: 1),
  });

  @override
  State<ScanBeam> createState() => _ScanBeamState();
}

class _ScanBeamState extends State<ScanBeam>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.linear,
    );

    if (widget.active) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant ScanBeam oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.active != oldWidget.active) {
      if (widget.active) {
        _controller
          ..reset()
          ..repeat(reverse: true);
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final availableHeight = height - widget.topPadding - widget.bottomPadding;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final beamY = widget.topPadding + _animation.value * availableHeight;

        return Stack(
          children: [
            // Main green beam
            Positioned(
              top: beamY,
              left: 0,
              right: 0,
              child: Container(
                height: 4,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.greenAccent,
                      Colors.lightGreenAccent,
                      Colors.greenAccent,
                      Colors.transparent,
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
            ),

            // Faint side lines
            Positioned(
              top: beamY - 8,
              left: 0,
              right: 0,
              child: Container(
                height: 1,
                color: Colors.greenAccent.withOpacity(0.3),
              ),
            ),
            Positioned(
              top: beamY + 8,
              left: 0,
              right: 0,
              child: Container(
                height: 1,
                color: Colors.greenAccent.withOpacity(0.3),
              ),
            ),
          ],
        );
      },
    );
  }
}
