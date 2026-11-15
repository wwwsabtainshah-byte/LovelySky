import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../auth_screen.dart';

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

class _AnimatedAssetPage extends StatefulWidget {
  final String title;
  final List<Map<String, String>> items;

  const _AnimatedAssetPage({required this.title, required this.items});

  @override
  State<_AnimatedAssetPage> createState() => _AnimatedAssetPageState();
}

class _AnimatedAssetPageState extends State<_AnimatedAssetPage> {
  final TextEditingController _userController = TextEditingController();
  int? _selectedIndex;
  bool _sending = false;

  String _code(String name) {
    const codes = {
      'ADMIN': 'admin',
      'AGENCY': 'agency',
      'BD ADMIN': 'bdadmin',
      'COIN SELLER': 'coinseller',
      'CS': 'cs',
      'HOST': 'host',
      'MANAGER': 'manager',
      'OFFICIAL': 'official',
      'SUPER ADMIN': 'superadmin',
      'SUPER ADMIN 2': 'superadmin_2',
      'OWNER': 'owner',
      'COUNTRY ASSISTANT': 'country_assistant',
      'COUNTRY SUPER ADMIN': 'country_super_admin',
    };
    return codes[name] ?? '';
  }

  Future<void> _send(bool remove) async {
    final userCode = _userController.text.trim();
    if (userCode.isEmpty || !RegExp(r'^\d+$').hasMatch(userCode)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valid User ID enter karein')),
      );
      return;
    }

    if (_selectedIndex == null) return;
    final item = widget.items[_selectedIndex!];
    final code = _code(item['name'] ?? '');
    if (code.isEmpty) return;

    setState(() => _sending = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('lovely_token');
      if (token == null || token.isEmpty) {
        throw Exception('Please login again');
      }

      final isBadge = widget.title == 'Badges';
      final endpoint = isBadge
          ? (remove
                ? '/owner/hardwear/badges/remove'
                : '/owner/hardwear/badges/grant')
          : (remove
                ? '/owner/hardwear/frames/remove'
                : '/owner/hardwear/frames/grant');

      final body = <String, dynamic>{
        'user_code': userCode,
        if (isBadge) 'badge_code': code else 'frame_code': code,
      };

      final response = await http.post(
        Uri.parse('$lovelyApi$endpoint'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          data is Map
              ? (data['detail'] ?? 'Request failed').toString()
              : 'Request failed',
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${item['name']} ${remove ? 'removed from' : 'sent to'} User $userCode',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _userController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: _bg,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: widget.items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.82,
              ),
              itemBuilder: (context, index) {
                final item = widget.items[index];
                final selected = _selectedIndex == index;
                return Material(
                  color: _surface,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => setState(() {
                      _selectedIndex = selected ? null : index;
                    }),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selected
                              ? Colors.amber
                              : _blue.withValues(alpha: 0.55),
                          width: selected ? 2 : 1,
                        ),
                      ),
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
                          const SizedBox(height: 5),
                          Text(
                            selected ? 'SELECTED' : 'TAP TO SELECT',
                            style: TextStyle(
                              color: selected ? Colors.amber : _blue,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_selectedIndex != null)
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                14,
                12,
                14,
                12 + MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: _surface,
                border: Border(top: BorderSide(color: _blue)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Selected: ${widget.items[_selectedIndex!]['name']}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _userController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Enter User ID',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: _bg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: _sending ? null : () => _send(false),
                          child: Text(_sending ? 'Please wait...' : 'Send'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                          ),
                          onPressed: _sending ? null : () => _send(true),
                          child: const Text('Remove'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
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
