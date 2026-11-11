import 'package:material_ui/material_ui.dart';

class VipWingFrame extends StatefulWidget {
  const VipWingFrame({
    super.key,
    required this.child,
    required this.setNumber,
    required this.level,
    this.size = 116,
    this.animate = true,
    this.avatarScale = 0.43,
  }) : assert(setNumber == 1 || setNumber == 2),
       assert(level >= 1 && level <= 12);

  final Widget child;
  final int setNumber;
  final int level;
  final double size;
  final bool animate;
  final double avatarScale;

  String get asset =>
      'assets/vip_animated_combined10/set${setNumber}_vip${level.toString().padLeft(2, '0')}.gif';

  @override
  State<VipWingFrame> createState() => _VipWingFrameState();
}

class _VipWingFrameState extends State<VipWingFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _glow.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant VipWingFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_glow.isAnimating) {
      _glow.repeat(reverse: true);
    } else if (!widget.animate && _glow.isAnimating) {
      _glow.stop();
    }
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avatarSize = widget.size * widget.avatarScale;

    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _glow,
        builder: (context, _) {
          final pulse = widget.animate ? _glow.value : 0.5;

          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: avatarSize + 6,
                height: avatarSize + 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD27A)
                          .withValues(alpha: 0.20 + pulse * 0.24),
                      blurRadius: 12 + pulse * 10,
                      spreadRadius: 2 + pulse * 2,
                    ),
                    BoxShadow(
                      color: const Color(0xFFFFF2CC)
                          .withValues(alpha: 0.10 + pulse * 0.12),
                      blurRadius: 22,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: avatarSize,
                height: avatarSize,
                child: ClipOval(child: widget.child),
              ),
              Positioned.fill(
                child: Image.asset(
                  widget.asset,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
