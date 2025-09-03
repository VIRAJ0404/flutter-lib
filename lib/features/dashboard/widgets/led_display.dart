// File: lib/features/dashboard/widgets/led_display.dart
import 'package:flutter/material.dart';
import '../../../services/vpin_service.dart';
import '../models.dart';

class LedDisplay extends StatelessWidget {
  final DashWidget dw;
  const LedDisplay({super.key, required this.dw});

  String _format(dynamic v) {
    if (v == null) return '--';
    if (v is num) return v.toStringAsFixed(2);
    if (v is Map && v.containsKey('value')) {
      final dyn = v['value'];
      if (dyn is num) return dyn.toStringAsFixed(2);
      return '$dyn';
    }
    return '$v';
  }

  @override
  Widget build(BuildContext context) {
    final Color glow =
        (dw.color == Colors.transparent ? Colors.limeAccent : dw.color);
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.80),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: glow.withValues(alpha: 0.25), width: 1.2),
        boxShadow: [
          BoxShadow(
              color: glow.withValues(alpha: 0.30),
              blurRadius: 28,
              spreadRadius: 1),
          BoxShadow(
              color: glow.withValues(alpha: 0.12),
              blurRadius: 8,
              spreadRadius: 4),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.black.withValues(alpha: 0.85),
            base.withValues(alpha: 0.04)
          ],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb,
                  size: 18, color: glow.withValues(alpha: 0.9)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dw.title.isEmpty ? 'LED Display' : dw.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: glow.withValues(alpha: 0.90),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    shadows: [
                      Shadow(
                          color: glow.withValues(alpha: 0.55), blurRadius: 8),
                      Shadow(
                          color: glow.withValues(alpha: 0.35), blurRadius: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: ValueListenableBuilder<Map<String, dynamic>>(
                valueListenable: VPinService.I.values,
                builder: (_, map, __) {
                  final String pin = dw.vpin ?? '';
                  final dynamic raw = pin.isNotEmpty ? map[pin] : null;
                  final String text = _format(raw);
                  return FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      text,
                      maxLines: 1,
                      style: TextStyle(
                        color: glow.withValues(alpha: 0.95),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        shadows: const [
                          Shadow(color: Color(0xAA00FF88), blurRadius: 18),
                          Shadow(color: Color(0x6600FF88), blurRadius: 36),
                          Shadow(color: Color(0x3300FF88), blurRadius: 64),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          if (dw.unit.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              dw.unit,
              style: TextStyle(
                color: glow.withValues(alpha: 0.70),
                fontSize: 12,
                letterSpacing: 0.6,
                shadows: [
                  Shadow(color: glow.withValues(alpha: 0.32), blurRadius: 6)
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
