import 'package:flutter/material.dart';

class SpinningLogo extends StatefulWidget {
  final double size;
  final Duration duration;

  const SpinningLogo({
    super.key,
    this.size = 24.0,
    this.duration = const Duration(seconds: 2),
  });

  @override
  State<SpinningLogo> createState() => _SpinningLogoState();
}

class _SpinningLogoState extends State<SpinningLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);

    _controller.repeat(); // Make it spin indefinitely
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _animation,
      child: Image.asset(
        'assets/images/logo2.jpg',
        width: widget.size,
        height: widget.size,
      ),
    );
  }
}
