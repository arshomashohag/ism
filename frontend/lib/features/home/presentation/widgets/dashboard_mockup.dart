/// Decorative dashboard mockup widget for the hero section.
library;

import 'package:flutter/material.dart';

/// A purely decorative widget that renders a fake dashboard preview.
///
/// Used in the hero section to visually communicate the product's UI.
/// Contains no real data and makes no network calls.
class DashboardMockup extends StatelessWidget {
  /// Creates a [DashboardMockup].
  const DashboardMockup({super.key, this.isDesktop = true});

  /// Whether to render in desktop (fixed 340px) or mobile (full-width) mode.
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      width: isDesktop ? 340 : double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TitleBar(cs: cs, tt: tt),
            ColoredBox(
              color: cs.surface,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _KpiRow(cs: cs, tt: tt),
                    const SizedBox(height: 12),
                    _SparklineChart(cs: cs),
                    const SizedBox(height: 12),
                    _StockBadgeRow(cs: cs, tt: tt),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar({required this.cs, required this.tt});

  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: cs.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            _MacDot(color: const Color(0xFFFF5F57)),
            const SizedBox(width: 6),
            _MacDot(color: const Color(0xFFFFBD2E)),
            const SizedBox(width: 6),
            _MacDot(color: const Color(0xFF28C840)),
            const SizedBox(width: 12),
            Text(
              'Dashboard',
              style: tt.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MacDot extends StatelessWidget {
  const _MacDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.cs, required this.tt});

  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MockKpi(
          label: 'Revenue',
          value: r'$12.4k',
          tint: cs.primaryContainer,
          onTint: cs.onPrimaryContainer,
          cs: cs,
          tt: tt,
        ),
        const SizedBox(width: 8),
        _MockKpi(
          label: 'Sales',
          value: '248',
          tint: cs.secondaryContainer,
          onTint: cs.onSecondaryContainer,
          cs: cs,
          tt: tt,
        ),
        const SizedBox(width: 8),
        _MockKpi(
          label: 'Alerts',
          value: '12',
          tint: cs.errorContainer,
          onTint: cs.onErrorContainer,
          cs: cs,
          tt: tt,
        ),
      ],
    );
  }
}

class _MockKpi extends StatelessWidget {
  const _MockKpi({
    required this.label,
    required this.value,
    required this.tint,
    required this.onTint,
    required this.cs,
    required this.tt,
  });

  final String label;
  final String value;
  final Color tint;
  final Color onTint;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: tt.labelSmall?.copyWith(color: onTint),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: tt.titleMedium?.copyWith(
                color: onTint,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SparklineChart extends StatelessWidget {
  const _SparklineChart({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: CustomPaint(
        painter: _SparklinePainter(cs: cs),
        size: const Size(double.infinity, 80),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.cs});

  final ColorScheme cs;

  static const List<double> _points = [
    0.4,
    0.5,
    0.35,
    0.6,
    0.55,
    0.75,
    0.65,
    0.8,
    0.7,
    0.9,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = cs.primary
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          cs.primary.withValues(alpha: 0.3),
          cs.primary.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    final step = size.width / (_points.length - 1);
    final padding = 12.0;
    final chartHeight = size.height - padding * 2;

    for (var i = 0; i < _points.length; i++) {
      final x = i * step;
      final y = padding + chartHeight * (1 - _points[i]);
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        final prevX = (i - 1) * step;
        final prevY = padding + chartHeight * (1 - _points[i - 1]);
        final cpX = (prevX + x) / 2;
        path.cubicTo(cpX, prevY, cpX, y, x, y);
        fillPath.cubicTo(cpX, prevY, cpX, y, x, y);
      }
    }

    final lastX = (_points.length - 1) * step;
    fillPath.lineTo(lastX, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()
      ..color = cs.primary
      ..style = PaintingStyle.fill;

    final lastY = padding + chartHeight * (1 - _points.last);
    canvas.drawCircle(Offset(lastX, lastY), 4, dotPaint);

    final innerDotPaint = Paint()
      ..color = cs.surface
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(lastX, lastY), 2, innerDotPaint);
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) => false;
}

class _StockBadgeRow extends StatelessWidget {
  const _StockBadgeRow({required this.cs, required this.tt});

  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StockBadge(
          label: '142 In Stock',
          color: const Color(0xFF2E7D32),
          bg: const Color(0xFFE8F5E9),
          tt: tt,
        ),
        const SizedBox(width: 6),
        _StockBadge(
          label: '8 Low',
          color: const Color(0xFFE65100),
          bg: const Color(0xFFFFF3E0),
          tt: tt,
        ),
        const SizedBox(width: 6),
        _StockBadge(
          label: '2 Out',
          color: const Color(0xFFC62828),
          bg: const Color(0xFFFFEBEE),
          tt: tt,
        ),
      ],
    );
  }
}

class _StockBadge extends StatelessWidget {
  const _StockBadge({
    required this.label,
    required this.color,
    required this.bg,
    required this.tt,
  });

  final String label;
  final Color color;
  final Color bg;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: tt.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
