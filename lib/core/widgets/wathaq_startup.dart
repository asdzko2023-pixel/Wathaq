import 'dart:async';
import 'package:flutter/material.dart';

/// A short, calm four-second branded intro shown on every cold app launch.
class WathaqStartupGate extends StatefulWidget {
  const WathaqStartupGate({super.key, required this.child});
  final Widget child;

  @override
  State<WathaqStartupGate> createState() => _WathaqStartupGateState();
}

class _WathaqStartupGateState extends State<WathaqStartupGate> {
  bool _showIntro = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showIntro = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 450),
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    child: _showIntro ? const _WathaqIntro(key: ValueKey('intro')) : widget.child,
  );
}

class _WathaqIntro extends StatelessWidget {
  const _WathaqIntro({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF211342),
    body: Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: .88, end: 1),
        duration: const Duration(milliseconds: 2200),
        curve: Curves.easeOutCubic,
        builder: (context, scale, child) => Opacity(
          opacity: ((scale - .88) / .12).clamp(0.0, 1.0),
          child: Transform.scale(scale: scale, child: child),
        ),
        child: Image.asset(
          'assets/brand/logo-horizontal-transparent.png',
          width: 250,
          height: 130,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Text(
            'وثاق',
            style: TextStyle(color: Colors.white, fontSize: 46, fontWeight: FontWeight.w900),
          ),
        ),
      ),
    ),
  );
}
