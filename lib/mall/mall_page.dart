import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'hardwear_frame_detail_page.dart';
import 'transparent_frame_video.dart';

const _bg = Color(0xFF100D25);
const _blue = Color(0xFF67D4FF);
const _gold = Color(0xFFFFD779);
const _mallApi = 'https://lovelysky.fastapicloud.dev';

class MallPage extends StatefulWidget {
  const MallPage({super.key});

  @override
  State<MallPage> createState() => _MallPageState();
}

class _MallPageState extends State<MallPage> {
  Map<String, dynamic> _progress = {};
  int _selectedTab = 0;
  bool get _isOwner => _progress['user_code']?.toString() == '1';
  bool get _showHardwear => _isOwner && _selectedTab == 1;

  Widget _mallTab(String label, int index) {
    final selected = _selectedTab == index;
    final accent = index == 0 ? _blue : _gold;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: .18)
                : const Color(0xFF201936),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? accent : Colors.white24),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? accent : Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('lovely_token');

      if (token == null || token.isEmpty) {
        throw Exception('Login required. Please sign in again.');
      }

      final response = await http.get(
        Uri.parse('$_mallApi/vip/wings/progress'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw Exception('Invalid server response.');
      }

      final data = Map<String, dynamic>.from(decoded);

      if (response.statusCode != 200 || data['success'] != true) {
        throw Exception(
          data['detail']?.toString() ?? 'VIP progress could not be loaded.',
        );
      }

      if (!mounted) return;
      setState(() {
        _progress = data;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadProgress,
          color: _blue,
          backgroundColor: const Color(0xFF201936),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _showHardwear ? 'HARDWEAR' : 'VIP WINGS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _loadProgress,
                      icon: const Icon(Icons.refresh, color: _blue),
                    ),
                  ],
                ),
              ),
              if (_isOwner)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                    child: Row(
                      children: [
                        _mallTab('VIP', 0),
                        const SizedBox(width: 10),
                        _mallTab('HARDWEAR', 1),
                      ],
                    ),
                  ),
                ),
              if (!_showHardwear) ...[
                const SliverToBoxAdapter(
                  child: SizedBox(height: 8),
                ),
              ] else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: InkWell(
                      onTap: () =>
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const HardwearFrameDetailPage(),
                            ),
                          ).then((_) {
                            if (mounted) _loadProgress();
                          }),
                      child: Container(
                        height: 235,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF201936),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: _gold, width: 1.5),
                        ),
                        child: Column(
                          children: [
                            Expanded(
                              child: const TransparentFrameVideo(),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'SUPER ADMIN',
                              style: TextStyle(
                                color: _gold,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'HARDWEAR FRAME  •  30 DAYS',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
