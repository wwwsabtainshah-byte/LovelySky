import 'package:material_ui/material_ui.dart';
import 'package:flutter_svga/flutter_svga.dart';

const Color _bg = Color(0xFF071426);
const Color _surface = Color(0xFF102944);
const Color _blue = Color(0xFF268CF4);

class MallPage extends StatelessWidget {
  const MallPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('Mall'),
        backgroundColor: _bg,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _mallButton(
                context,
                'VIP Frames',
                Icons.auto_awesome,
                const VipFramesPage(),
              ),
              _mallButton(
                context,
                'Hardware',
                Icons.memory,
                const HardwarePage(),
              ),
              _mallButton(
                context,
                'Badges',
                Icons.workspace_premium,
                const BadgesPage(),
              ),
              _mallButton(
                context,
                'Ride',
                Icons.directions_car,
                const RidePage(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mallButton(
    BuildContext context,
    String title,
    IconData icon,
    Widget page,
  ) {
    return Container(
      width: 112,
      height: 54,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _blue.withValues(alpha: 0.65)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => page));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: _blue, size: 19),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 10 ORIGINAL ANIMATED ROLE FRAMES
const List<Map<String, String>> _hardwareFrames = [
  {'name': 'ADMIN', 'asset': 'assets/hardwear/role_frames/role_admin.svga'},
  {'name': 'AGENCY', 'asset': 'assets/hardwear/role_frames/role_agency.svga'},
  {
    'name': 'BD ADMIN',
    'asset': 'assets/hardwear/role_frames/role_bdadmin.svga',
  },
  {
    'name': 'COIN SELLER',
    'asset': 'assets/hardwear/role_frames/role_coinseller.svga',
  },
  {'name': 'CS', 'asset': 'assets/hardwear/role_frames/role_cs.svga'},
  {'name': 'HOST', 'asset': 'assets/hardwear/role_frames/role_host.svga'},
  {'name': 'MANAGER', 'asset': 'assets/hardwear/role_frames/role_manager.svga'},
  {
    'name': 'OFFICIAL',
    'asset': 'assets/hardwear/role_frames/role_official.svga',
  },
  {
    'name': 'SUPER ADMIN',
    'asset': 'assets/hardwear/role_frames/role_superadmin.svga',
  },
  {
    'name': 'SUPER ADMIN 2',
    'asset': 'assets/hardwear/role_frames/role_superadmin_2.svga',
  },
];

// 7 ORIGINAL ANIMATED BADGES
const List<Map<String, String>> _badges = [
  {'name': 'ADMIN', 'asset': 'assets/hardwear/role_badges/badge_admin.svga'},
  {'name': 'AGENCY', 'asset': 'assets/hardwear/role_badges/badge_agency.svga'},
  {
    'name': 'OFFICIAL',
    'asset': 'assets/hardwear/role_badges/badge_official.svga',
  },
  {'name': 'OWNER', 'asset': 'assets/hardwear/role_badges/badge_owner.svga'},
  {
    'name': 'SUPER ADMIN',
    'asset': 'assets/hardwear/role_badges/badge_superadmin.svga',
  },
  {
    'name': 'COUNTRY ASSISTANT',
    'asset': 'assets/hardwear/role_badges/country_assistant_badge.svga',
  },
  {
    'name': 'COUNTRY SUPER ADMIN',
    'asset': 'assets/hardwear/role_badges/country_super_admin_badge.svga',
  },
];

class HardwarePage extends StatelessWidget {
  const HardwarePage({super.key});

  @override
  Widget build(BuildContext context) =>
      const _AnimatedAssetPage(title: 'Hardware', items: _hardwareFrames);
}

class BadgesPage extends StatelessWidget {
  const BadgesPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const _AnimatedAssetPage(title: 'Badges', items: _badges);
}

class _AnimatedAssetPage extends StatelessWidget {
  final String title;
  final List<Map<String, String>> items;

  const _AnimatedAssetPage({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: _bg,
        foregroundColor: Colors.white,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.82,
        ),
        itemBuilder: (context, index) {
          final item = items[index];

          return Container(
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _blue.withValues(alpha: 0.55)),
            ),
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: SVGAEasyPlayer(
                      assetsName: item['asset']!,
                      loops: true,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item['name']!,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class VipFramesPage extends StatelessWidget {
  const VipFramesPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const _EmptyMallPage(title: 'VIP Frames');
}

class RidePage extends StatelessWidget {
  const RidePage({super.key});

  @override
  Widget build(BuildContext context) => const _EmptyMallPage(title: 'Ride');
}

class _EmptyMallPage extends StatelessWidget {
  final String title;

  const _EmptyMallPage({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: _bg,
        foregroundColor: Colors.white,
      ),
      body: const SizedBox.expand(),
    );
  }
}
