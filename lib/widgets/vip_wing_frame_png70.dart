import 'package:material_ui/material_ui.dart';

/// New 70x62 PNG seat frame renderer.
/// The original animated GIF VipWingFrame remains unchanged.
class VipWingFramePng70 extends StatelessWidget {
  final int setNumber;
  final int level;
  final Widget child;

  const VipWingFramePng70({
    super.key,
    required this.setNumber,
    required this.level,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final set = setNumber == 2 ? 2 : 1;
    final safeLevel = level.clamp(1, 12).toString().padLeft(2, '0');

    // Approximate transparent center opening measured from the PNG assets.
    final left = set == 1 ? 23.0 : 20.0;
    final top = set == 1 ? 15.0 : 15.0;
    final openingWidth = set == 1 ? 25.0 : 31.0;
    final openingHeight = set == 1 ? 23.0 : 26.0;

    return SizedBox(
      width: 70,
      height: 62,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: left,
            top: top,
            width: openingWidth,
            height: openingHeight,
            child: ClipOval(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: child,
                ),
              ),
            ),
          ),
          Image.asset(
            'assets/vip_new_preview/set${set}_vip$safeLevel.png',
            width: 70,
            height: 62,
            fit: BoxFit.fill,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
