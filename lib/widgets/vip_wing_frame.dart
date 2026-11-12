import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
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
    this.innerSize,
  }) : assert(setNumber == 1 || setNumber == 2),
       assert(level >= 1 && level <= 12);

  final Widget child;
  final int setNumber;
  final int level;
  final double size;
  final bool animate;
  final double avatarScale;
  final double? innerSize;

  String get asset =>
      'assets/vip_animated_combined10/set${setNumber}_vip${level.toString().padLeft(2, '0')}.gif';

  @override
  State<VipWingFrame> createState() => _VipWingFrameState();
}

class _VipWingFrameState extends State<VipWingFrame>
    with SingleTickerProviderStateMixin {
  static final Map<String, Future<ui.Rect?>> _openingCache = {};

  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );

  ui.Rect? _opening;

  @override
  void initState() {
    super.initState();
    if (widget.animate) _glow.repeat(reverse: true);
    _loadOpening();
  }

  @override
  void didUpdateWidget(covariant VipWingFrame oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.animate && !_glow.isAnimating) {
      _glow.repeat(reverse: true);
    } else if (!widget.animate && _glow.isAnimating) {
      _glow.stop();
    }

    if (oldWidget.asset != widget.asset) {
      _opening = null;
      _loadOpening();
    }
  }

  Future<ui.Rect?> _detectOpening(String asset) async {
    try {
      final data = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final width = image.width;
      final height = image.height;
      final pixels = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );

      if (pixels == null) {
        image.dispose();
        codec.dispose();
        return null;
      }

      final bytes = pixels.buffer.asUint8List(
        pixels.offsetInBytes,
        pixels.lengthInBytes,
      );

      // The transparent DP opening is near the centre of these GIFs.
      final startX = width ~/ 2;
      final startY = (height * 0.455).round().clamp(0, height - 1);
      final startIndex = startY * width + startX;

      bool transparent(int index) => bytes[index * 4 + 3] <= 20;

      if (!transparent(startIndex)) {
        image.dispose();
        codec.dispose();
        return null;
      }

      final visited = Uint8List(width * height);
      final queue = Int32List(width * height);
      var head = 0;
      var tail = 0;

      queue[tail++] = startIndex;
      visited[startIndex] = 1;

      var minX = startX;
      var maxX = startX;
      var minY = startY;
      var maxY = startY;

      while (head < tail) {
        final current = queue[head++];
        final x = current % width;
        final y = current ~/ width;

        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;

        void visit(int next) {
          if (next < 0 ||
              next >= width * height ||
              visited[next] == 1 ||
              !transparent(next)) {
            return;
          }
          visited[next] = 1;
          queue[tail++] = next;
        }

        if (x > 0) visit(current - 1);
        if (x < width - 1) visit(current + 1);
        if (y > 0) visit(current - width);
        if (y < height - 1) visit(current + width);
      }

      image.dispose();
      codec.dispose();

      if (maxX - minX < 40 || maxY - minY < 40) return null;

      // Right and bottom are exclusive.
      return ui.Rect.fromLTRB(
        minX.toDouble(),
        minY.toDouble(),
        (maxX + 1).toDouble(),
        (maxY + 1).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadOpening() async {
    final future = _openingCache.putIfAbsent(
      widget.asset,
      () => _detectOpening(widget.asset),
    );

    final result = await future;
    if (!mounted) return;

    setState(() {
      _opening = result;
    });
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSuperAdminFrame = widget.setNumber == 1 && widget.level == 1;
    final gifWidth = isSuperAdminFrame ? 1254.0 : 384.0;
    final gifHeight = isSuperAdminFrame ? 1254.0 : 341.0;

    final opening = _opening;

    // Keep the complete GIF inside the seat's available frame size.
    final scale = widget.size / gifWidth;
    final frameWidth = gifWidth * scale;
    final frameHeight = gifHeight * scale;

    final openingWidth = opening?.width ?? 135.0;
    final openingHeight = opening?.height ?? 122.0;
    final openingDiameter = openingWidth < openingHeight
        ? openingWidth
        : openingHeight;

    // Fit the avatar to the detected transparent opening.
    final avatarSize =
        widget.innerSize ?? openingDiameter * scale * 0.78;

    final centerX = opening != null
        ? (opening.left + opening.right) / 2 * scale
        : gifWidth / 2;

    final centerY = opening != null
        ? (opening.top + opening.bottom) / 2 * scale
        : gifHeight / 2;

    return SizedBox.square(
      dimension: widget.size,
      child: OverflowBox(
        alignment: Alignment.center,
        minWidth: 0,
        minHeight: 0,
        maxWidth: frameWidth + 2,
        maxHeight: frameHeight + 2,
        child: SizedBox(
          width: frameWidth,
          height: frameHeight,
          child: AnimatedBuilder(
            animation: _glow,
            builder: (context, _) {
              final pulse = widget.animate ? _glow.value : 0.5;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: centerX - avatarSize / 2,
                    top: centerY - avatarSize / 2,
                    width: avatarSize,
                    height: avatarSize,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFD27A)
                                .withValues(alpha: 0.35 + pulse * 0.45),
                            blurRadius: 16 + pulse * 22,
                            spreadRadius: 3 + pulse * 5,
                          ),
                          BoxShadow(
                            color: const Color(0xFFFFF2CC)
                                .withValues(alpha: 0.18 + pulse * 0.25),
                            blurRadius: 28 + pulse * 12,
                            spreadRadius: 5 + pulse * 3,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: centerX - avatarSize / 2,
                    top: centerY - avatarSize / 2,
                    width: avatarSize,
                    height: avatarSize,
                    child: ClipOval(child: widget.child),
                  ),
                  Positioned.fill(
                    child: Image.asset(
                      widget.asset,
                      fit: BoxFit.fill,
                      gaplessPlayback: true,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
