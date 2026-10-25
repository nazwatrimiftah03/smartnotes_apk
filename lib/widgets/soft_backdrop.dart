import 'package:flutter/material.dart';

class SoftBackdrop extends StatelessWidget {
  final Widget child;

  const SoftBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primaryContainer;

    return Stack(
      children: [
        Positioned(
          top: -90,
          right: -70,
          child: _Blob(size: 240, color: color.withValues(alpha: 0.55)),
        ),
        Positioned(
          bottom: -120,
          left: -90,
          child: _Blob(size: 300, color: color.withValues(alpha: 0.35)),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final Color color;

  const _Blob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}