import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

class LovelyProfileFrame {
  final String code;
  final String name;
  final String label;
  final int color;

  const LovelyProfileFrame(this.code, this.name, this.label, this.color);
}

const List<LovelyProfileFrame> lovelyProfileFrames = [
  LovelyProfileFrame('spring_day', 'Spring Day', '', 0xFF69C987),
  LovelyProfileFrame('blade_warrior', 'Blade of the Warrior', '', 0xFF388BD8),
  LovelyProfileFrame('pk', 'PK', 'PK', 0xFFDB65CE),
  LovelyProfileFrame('burning_flame', 'Burning Flame', '', 0xFFFF8B22),
  LovelyProfileFrame('blue_gold_star', 'Blue Gold Star', 'HOST', 0xFF22A9E8),
  LovelyProfileFrame('shining_brightly', 'Shining Brightly', '', 0xFFFFB52E),
  LovelyProfileFrame(
    'recharge_agent',
    'Recharge Agent',
    'Recharge Agent',
    0xFFFFA52A,
  ),
  LovelyProfileFrame('vip1', 'VIP1', 'VIP1', 0xFFB8B8C5),
  LovelyProfileFrame('lily_valley', 'Lily of the Valley', '', 0xFF39D9B2),
  LovelyProfileFrame('cool_summer_day', 'Cool Summer Day', '', 0xFF62CBEA),
  LovelyProfileFrame('summer_surfing', 'Summer Surfing', '', 0xFF26BDEB),
  LovelyProfileFrame('future_machinery', 'Future Machinery', '', 0xFF9A79E8),
  LovelyProfileFrame('vip5', 'VIP5', 'VIP5', 0xFFFF642D),
  LovelyProfileFrame(
    'super_admin_caps',
    'SUPER ADMIN',
    'SUPER ADMIN',
    0xFFFFB52E,
  ),
  LovelyProfileFrame('eid_adha', 'Eid al-Adha', '', 0xFFB68BE9),
  LovelyProfileFrame('eid_adha_lv4', 'Eid al-Adha LV4', '', 0xFF36C78A),
  LovelyProfileFrame('vip3', 'VIP3', 'VIP3', 0xFF24C9D0),
  LovelyProfileFrame('superadmin', 'superadmin', 'ADMIN', 0xFF9A54E8),
  LovelyProfileFrame('philippines', 'the Philippines', 'AGENCY', 0xFFFFB52E),
  LovelyProfileFrame('vip4', 'VIP4', 'VIP4', 0xFF4D9DEB),
  LovelyProfileFrame('test_super_admin', 'Test Super Admin', 'BD', 0xFF49C7D9),
  LovelyProfileFrame('eid_adha_lv3', 'Eid al-Adha LV3', '', 0xFFE8A34C),
  LovelyProfileFrame('vip2', 'VIP2', 'VIP2', 0xFF43C98A),
  LovelyProfileFrame('eid_adha_rituals', 'Eid al-Adha rituals', '', 0xFF4DC7A2),
  LovelyProfileFrame('vip6', 'VIP6', 'VIP6', 0xFFFF9A45),
  LovelyProfileFrame('vip7', 'VIP7', 'VIP7', 0xFF9B70EF),
  LovelyProfileFrame('vip8', 'VIP8', 'VIP8', 0xFF35C9F0),
  LovelyProfileFrame('vip9', 'VIP9', 'VIP9', 0xFFE879C5),
  LovelyProfileFrame('vip10', 'VIP10', 'VIP10', 0xFF65D99A),
  LovelyProfileFrame('vip11', 'VIP11', 'VIP11', 0xFF9B83F5),
  LovelyProfileFrame('vip12', 'VIP12', 'VIP12', 0xFFFFB85C),
];

LovelyProfileFrame? lovelyFrameByCode(String code) {
  for (final frame in lovelyProfileFrames) {
    if (frame.code == code) return frame;
  }
  return null;
}

class AnimatedProfileFrame extends StatefulWidget {
  final String frameCode;
  final Widget child;
  final double size;
  final bool animate;

  const AnimatedProfileFrame({
    super.key,
    required this.frameCode,
    required this.child,
    this.size = 100,
    this.animate = true,
  });

  @override
  State<AnimatedProfileFrame> createState() => _AnimatedProfileFrameState();
}

class _AnimatedProfileFrameState extends State<AnimatedProfileFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    if (widget.animate) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant AnimatedProfileFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frame = lovelyFrameByCode(widget.frameCode);
    if (frame == null) {
      return SizedBox.square(
        dimension: widget.size,
        child: ClipOval(child: widget.child),
      );
    }

    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            foregroundPainter: _LovelyFramePainter(
              color: Color(frame.color),
              label: frame.label,
              progress: _controller.value,
            ),
            child: Padding(
              padding: EdgeInsets.all(widget.size * 0.235),
              child: ClipOval(child: widget.child),
            ),
          );
        },
      ),
    );
  }
}

class _LovelyFramePainter extends CustomPainter {
  final Color color;
  final String label;
  final double progress;

  _LovelyFramePainter({
    required this.color,
    required this.label,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final center = Offset(s / 2, s / 2);
    final rect = Rect.fromCenter(
      center: center,
      width: s * 0.83,
      height: s * 0.83,
    );

    final glow = Paint()
      ..color = color.withValues(
        alpha: 0.35 + 0.25 * math.sin(progress * math.pi * 2).abs(),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.10
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.045);

    canvas.drawOval(rect, glow);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.055
      ..shader = SweepGradient(
        transform: GradientRotation(progress * math.pi * 2),
        colors: [
          color.withValues(alpha: 0.25),
          Colors.white,
          color,
          color.withValues(alpha: 0.35),
          Colors.white,
          color,
        ],
      ).createShader(rect);

    canvas.drawOval(rect, ring);

    final inner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.018
      ..color = Colors.white.withValues(alpha: 0.8);

    canvas.drawOval(
      Rect.fromCenter(center: center, width: s * 0.73, height: s * 0.73),
      inner,
    );

    final ornament = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 24; i++) {
      final angle = (i / 24) * math.pi * 2;
      final radiusX = s * 0.415;
      final radiusY = s * 0.415;
      final point = Offset(
        center.dx + math.cos(angle) * radiusX,
        center.dy + math.sin(angle) * radiusY,
      );
      canvas.drawCircle(point, s * 0.018, ornament);
      if (i % 3 == 0) {
        _drawSparkle(canvas, point, s * 0.035, progress + i);
      }
    }

    // Crown ornament at the top.
    final crown = Path()
      ..moveTo(s * 0.35, s * 0.14)
      ..lineTo(s * 0.30, s * 0.045)
      ..lineTo(s * 0.43, s * 0.105)
      ..lineTo(s * 0.50, s * 0.025)
      ..lineTo(s * 0.57, s * 0.105)
      ..lineTo(s * 0.70, s * 0.045)
      ..lineTo(s * 0.65, s * 0.14)
      ..close();

    canvas.drawPath(crown, ornament);
    canvas.drawPath(
      crown,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.012,
    );

    // Animated moving sparkles.
    for (int i = 0; i < 5; i++) {
      final angle = progress * math.pi * 2 + i * math.pi * 0.4;
      final point = Offset(
        center.dx + math.cos(angle) * s * 0.39,
        center.dy + math.sin(angle) * s * 0.39,
      );
      _drawSparkle(canvas, point, s * 0.045, progress * 5 + i);
    }

    // Frame title plate.
    if (label.isNotEmpty) {
      final plate = RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.25, s * 0.79, s * 0.50, s * 0.13),
        Radius.circular(s * 0.035),
      );
      canvas.drawRRect(plate, Paint()..color = color);
      canvas.drawRRect(
        plate,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.009,
      );

      final text = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: Colors.white,
            fontSize: s * (label.length > 9 ? 0.055 : 0.075),
            fontWeight: FontWeight.w900,
            shadows: const [Shadow(color: Colors.black54, blurRadius: 2)],
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: s * 0.46);

      text.paint(canvas, Offset((s - text.width) / 2, s * 0.805));
    }
  }

  void _drawSparkle(Canvas canvas, Offset point, double radius, double phase) {
    final opacity = (0.35 + 0.65 * (0.5 + 0.5 * math.sin(phase * math.pi * 2)))
        .clamp(0.0, 1.0);

    final paint = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..strokeWidth = radius * 0.30
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(point.dx - radius, point.dy),
      Offset(point.dx + radius, point.dy),
      paint,
    );
    canvas.drawLine(
      Offset(point.dx, point.dy - radius),
      Offset(point.dx, point.dy + radius),
      paint,
    );
    canvas.drawCircle(point, radius * 0.22, paint);
  }

  @override
  bool shouldRepaint(covariant _LovelyFramePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.label != label;
  }
}
