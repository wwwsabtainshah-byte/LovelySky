import 'package:material_ui/material_ui.dart';
import 'package:flutter_svga/flutter_svga.dart';

class HardwearFrameOverlay extends StatelessWidget {
  final String frameCode;
  final Widget child;
  final double size;

  const HardwearFrameOverlay({
    super.key,
    required this.frameCode,
    required this.child,
    this.size = 92,
  });

  @override
  Widget build(BuildContext context) {
    final code = frameCode.trim().toLowerCase();
    if (code.isEmpty) return child;

    final asset = 'assets/hardwear/role_frames/role_$code.svga';

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: SizedBox(
              width: size * 0.66,
              height: size * 0.66,
              child: ClipOval(child: child),
            ),
          ),
          IgnorePointer(
            child: SVGAEasyPlayer(
              key: ValueKey(asset),
              assetsName: asset,
              loops: true,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}
