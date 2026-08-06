import 'package:flutter/material.dart';

/// Uygulama genel ölçeği (UI Scale) değiştiğinde, değişikliği aniden yapmak yerine
/// yumuşak bir geçiş (animasyon) ile uygulayan sarmalayıcı widget.
///
/// Kullanım:
/// main.dart dosyasında MaterialApp builder metodu içinde Transform.scale yerine kullanın.
class AnimatedUiScaler extends StatelessWidget {
  final double scale;
  final Widget? child;
  final Alignment alignment;
  final Duration duration;
  final Curve curve;

  const AnimatedUiScaler({
    super.key,
    required this.scale,
    this.child,
    this.alignment = Alignment.topLeft,
    this.duration = const Duration(milliseconds: 350),
    this.curve = Curves.easeOutQuint,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: scale, end: scale),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          alignment: alignment,
          child: child,
        );
      },
      child: child,
    );
  }
}