import 'package:material_ui/material_ui.dart';

/// Animated decorative frame for Lovely Sky Mall.
/// Add the PNG assets under assets/lovely_sky_frames/ and register that
/// directory in pubspec.yaml before using this widget.
class LovelySkyAnimatedFrame extends StatefulWidget {
  const LovelySkyAnimatedFrame({
    super.key,
    required this.asset,
    required this.child,
    this.size = 116,
    this.glowColor = const Color(0xFF28C9FF),
    this.animate = true,
  });

  /// Example: assets/lovely_sky_frames/vip_1.png
  final String asset;
  final Widget child;
  final double size;
  final Color glowColor;
  final bool animate;

  @override
  State<LovelySkyAnimatedFrame> createState() => _LovelySkyAnimatedFrameState();
}

class _LovelySkyAnimatedFrameState extends State<LovelySkyAnimatedFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = widget.animate ? _controller.value : 0.45;
        final glow = 0.35 + (t * 0.55);
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Container(
                width: widget.size * 0.70,
                height: widget.size * 0.70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.glowColor.withValues(alpha: glow * 0.72),
                      blurRadius: 9 + (t * 17),
                      spreadRadius: 1 + (t * 3),
                    ),
                  ],
                ),
                child: ClipOval(child: widget.child),
              ),
              IgnorePointer(
                child: Image.asset(
                  widget.asset,
                  width: widget.size,
                  height: widget.size,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
