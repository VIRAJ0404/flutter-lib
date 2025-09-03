// File: lib/ui/fx3d.dart
// 3D-look helpers using inner-shadow painter + blur glass.
// Migrated to Color.withValues(...) per wide-gamut Color changes.

import 'dart:ui' show ImageFilter, MaskFilter, BlurStyle;
import 'package:flutter/material.dart';

class NeoContainer extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final bool pressed; // false=raised, true=pressed
  final Color? baseColor;

  const NeoContainer({
    super.key,
    required this.child,
    this.radius = 16,
    this.padding = const EdgeInsets.all(12),
    this.margin = EdgeInsets.zero,
    this.pressed = false,
    this.baseColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    final bg = baseColor ??
        Color.lerp(theme.surface, theme.surfaceContainerHighest, 0.5)!;

    final shadowLight = Colors.white.withValues(alpha: 0.75);
    final shadowDark = Colors.black.withValues(alpha: 0.20);

    final List<BoxShadow> raised = [
      BoxShadow(color: shadowDark, offset: const Offset(6, 6), blurRadius: 14),
      BoxShadow(
          color: shadowLight, offset: const Offset(-6, -6), blurRadius: 14),
    ];

    final core = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: pressed ? [] : raised,
        gradient: pressed
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(bg, Colors.white, 0.04)!,
                  Color.lerp(bg, Colors.black, 0.04)!,
                ],
              )
            : null,
      ),
      child: child,
    );

    if (!pressed) return core;

    return Stack(
      children: [
        core,
        IgnorePointer(
          child: CustomPaint(
            painter: _InnerShadowPainter(
              radius: radius,
              colorTopLeft: Colors.white.withValues(alpha: 0.35),
              colorBottomRight: Colors.black.withValues(alpha: 0.25),
              blur: 12,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}

class _InnerShadowPainter extends CustomPainter {
  final double radius;
  final Color colorTopLeft;
  final Color colorBottomRight;
  final double blur;

  _InnerShadowPainter({
    required this.radius,
    required this.colorTopLeft,
    required this.colorBottomRight,
    required this.blur,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rrect =
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));

    canvas.save();
    canvas.clipRRect(rrect);

    // Top-left inner glow
    final Paint tl = Paint()
      ..blendMode = BlendMode.srcATop
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.center,
        colors: [
          colorTopLeft,
          colorTopLeft.withValues(alpha: 0),
        ],
      ).createShader(Offset.zero & size)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
    canvas.drawRRect(rrect, tl);

    // Bottom-right inner shadow
    final Paint br = Paint()
      ..blendMode = BlendMode.srcATop
      ..shader = LinearGradient(
        begin: Alignment.bottomRight,
        end: Alignment.center,
        colors: [
          colorBottomRight,
          colorBottomRight.withValues(alpha: 0),
        ],
      ).createShader(Offset.zero & size)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
    canvas.drawRRect(rrect, br);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _InnerShadowPainter old) =>
      old.radius != radius ||
      old.colorTopLeft != colorTopLeft ||
      old.colorBottomRight != colorBottomRight ||
      old.blur != blur;
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final double blurSigma;
  final Color overlay;

  const GlassCard({
    super.key,
    required this.child,
    this.radius = 20,
    this.padding = const EdgeInsets.all(12),
    this.margin = EdgeInsets.zero,
    this.blurSigma = 16,
    this.overlay = const Color(0x66FFFFFF),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: Container(),
          ),
          Container(
            padding: padding,
            margin: margin,
            decoration: BoxDecoration(
              color: overlay,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.28),
                  Colors.white.withValues(alpha: 0.08),
                ],
              ),
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}
