// SCROLL-FADE-V1
import 'package:flutter/material.dart';

/// Aplica um gradiente de fade na borda inferior de um widget scrollável,
/// simulando o efeito do Todoist onde o conteúdo dissolve antes da navbar.
///
/// Uso:
///   ScrollFadeOverlay(
///     fadeHeight: 80,
///     child: ListView(...),
///   )
///
/// Sem efeito em desktop (breakpoint >= 1024, igual ResponsiveLayout) —
/// lá não há navbar flutuante por baixo da qual o conteúdo precise dissolver.
class ScrollFadeOverlay extends StatelessWidget {
  const ScrollFadeOverlay({
    super.key,
    required this.child,
    // SCROLL-FADE-OLD: this.fadeHeight = 80.0,
    // SCROLL-FADE-OLD: this.fadeHeight = 120.0,
    // SCROLL-FADE-V3
    this.fadeHeight = 150.0,
  });

  final Widget child;

  /// Altura em pixels do gradiente de fade na borda inferior.
  /// Deve ser próximo à altura da navbar + safe area.
  final double fadeHeight;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).size.width >= 1024) return child;

    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          // SCROLL-FADE-OLD
          // colors: const [
          //   Colors.white,
          //   Colors.white,
          //   Colors.transparent,
          // ],
          // stops: [
          //   0.0,
          //   1.0 - (fadeHeight / bounds.height).clamp(0.0, 0.6),
          //   1.0,
          // ],
          // SCROLL-FADE-V2
          colors: const [
            Colors.white,
            Colors.white,
            Color(0x55FFFFFF),
            Colors.transparent,
          ],
          stops: [
            0.0,
            1.0 - (fadeHeight / bounds.height).clamp(0.0, 0.55),
            1.0 - (fadeHeight / bounds.height * 0.35).clamp(0.0, 0.25),
            1.0,
          ],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: child,
    );
  }
}
