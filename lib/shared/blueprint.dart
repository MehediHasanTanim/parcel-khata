import 'package:flutter/material.dart';

/// Hairline frame with "+" registration marks, the Industry design system's
/// wireframe object. Marks sit on the top-left and bottom-right corners.
class Blueprint extends StatelessWidget {
  const Blueprint({
    required this.child,
    this.borderColor,
    this.allCorners = false,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final Widget child;
  final Color? borderColor;
  final bool allCorners;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final line = borderColor ?? scheme.outlineVariant;
    final mark = borderColor ?? scheme.onSurface.withValues(alpha: 0.5);
    return CustomPaint(
      foregroundPainter: _MarksPainter(mark, allCorners: allCorners),
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border.all(color: line)),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class _MarksPainter extends CustomPainter {
  _MarksPainter(this.color, {required this.allCorners});

  final Color color;
  final bool allCorners;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    const r = 4.0;
    void plus(Offset c) {
      canvas
        ..drawLine(c.translate(-r, 0), c.translate(r, 0), p)
        ..drawLine(c.translate(0, -r), c.translate(0, r), p);
    }

    plus(Offset.zero);
    plus(Offset(size.width, size.height));
    if (allCorners) {
      plus(Offset(size.width, 0));
      plus(Offset(0, size.height));
    }
  }

  @override
  bool shouldRepaint(_MarksPainter old) => old.color != color || old.allCorners != allCorners;
}
