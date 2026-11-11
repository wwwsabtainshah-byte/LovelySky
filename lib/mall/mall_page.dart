import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'vip_wing_detail_page.dart';

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
  bool _loading = true;
  String? _error;
  final Set<String> _claiming = {};

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

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
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _claimFrame(int setNumber, int level) async {
    final key = '$setNumber-$level';
    if (_claiming.contains(key)) return;

    setState(() => _claiming.add(key));

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('lovely_token');

      if (token == null || token.isEmpty) {
        throw Exception('Login required.');
      }

      final response = await http.post(
        Uri.parse('$_mallApi/vip/wings/claim'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'set_number': setNumber, 'level': level}),
      );

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw Exception('Invalid server response.');
      }

      final data = Map<String, dynamic>.from(decoded);

      if (response.statusCode != 200 || data['success'] != true) {
        throw Exception(data['detail']?.toString() ?? 'VIP claim failed.');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('VIP $level, Set $setNumber claimed!')),
      );
      await _loadProgress();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _claiming.remove(key));
      }
    }
  }

  int get _weeklyCoins =>
      (_progress['weekly_verified_coins'] as num?)?.toInt() ?? 0;

  Map<String, dynamic> _frameData(int setNumber, int level) {
    final sets = _progress['sets'];
    if (sets is! Map) return {};

    final levels = sets['$setNumber'];
    if (levels is! List) return {};

    for (final item in levels) {
      if (item is Map && item['level'] == level) {
        return Map<String, dynamic>.from(item);
      }
    }
    return {};
  }

  String _formatCoins(int value) {
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(1)}B';
    }
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toString();
  }

  String _expiryLabel(dynamic value) {
    if (value == null) return '';
    final date = DateTime.tryParse(value.toString());
    if (date == null) return '';

    final remaining = date.difference(DateTime.now());
    if (remaining.isNegative) return 'Expired';

    if (remaining.inDays >= 1) {
      return 'Expires in ${remaining.inDays}d';
    }
    if (remaining.inHours >= 1) {
      return 'Expires in ${remaining.inHours}h';
    }
    return 'Expires soon';
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
                    const Expanded(
                      child: Text(
                        'VIP WINGS',
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
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF29204B), Color(0xFF17152F)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _blue.withValues(alpha: .65)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'LAST 7 DAYS VERIFIED PURCHASES',
                        style: TextStyle(
                          color: _blue,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          const Icon(
                            Icons.monetization_on,
                            color: _gold,
                            size: 25,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _loading
                                  ? 'Loading...'
                                  : '${_formatCoins(_weeklyCoins)} Coins',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 23,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (_loading)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _blue,
                              ),
                            ),
                        ],
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: Color(0xFFFF9B9B),
                            fontSize: 11,
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _loadProgress,
                            child: const Text(
                              'RETRY',
                              style: TextStyle(color: _blue),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              for (int set = 1; set <= 2; set++) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 28,
                          decoration: BoxDecoration(
                            color: set == 1 ? _blue : _gold,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'SET $set',
                          style: TextStyle(
                            color: set == 1 ? _blue : _gold,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '12 WINGS',
                          style: TextStyle(
                            color: set == 1 ? _blue : _gold,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final level = index + 1;
                      final number = level.toString().padLeft(2, '0');
                      final accent = set == 1 ? _blue : _gold;
                      final data = _frameData(set, level);
                      final required =
                          (data['required_coins'] as num?)?.toInt() ?? 0;
                      final eligible = data['eligible'] == true;
                      final owned = data['owned'] == true;
                      final ratio = required <= 0
                          ? 0.0
                          : (_weeklyCoins / required).clamp(0.0, 1.0);
                      final key = '$set-$level';
                      final claiming = _claiming.contains(key);

                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          if (claiming) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => VipWingDetailPage(
                                setNumber: set,
                                level: level,
                                frameData: data,
                                weeklyCoins: _weeklyCoins,
                              ),
                            ),
                          ).then((_) {
                            if (mounted) _loadProgress();
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF201936),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: owned
                                  ? const Color(0xFF69E6A5)
                                  : accent.withValues(alpha: .65),
                              width: owned ? 1.6 : 1,
                            ),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            children: [
                              Expanded(
                                child: Image.asset(
                                  'assets/vip_animated_combined10/set${set}_vip$number.gif',
                                  width: double.infinity,
                                  fit: BoxFit.contain,
                                  gaplessPlayback: true,
                                  errorBuilder: (_, _, _) => Icon(
                                    Icons.broken_image_outlined,
                                    color: accent,
                                    size: 35,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'VIP $level',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                'SET $set  •  ${_formatCoins(required)} Coins',
                                style: TextStyle(
                                  color: accent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 5),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(5),
                                child: LinearProgressIndicator(
                                  value: ratio,
                                  minHeight: 5,
                                  backgroundColor: Colors.white12,
                                  color: owned
                                      ? const Color(0xFF69E6A5)
                                      : accent,
                                ),
                              ),
                              const SizedBox(height: 5),
                              if (owned)
                                Text(
                                  _expiryLabel(data['expires_at']).isEmpty
                                      ? 'OWNED'
                                      : _expiryLabel(data['expires_at']),
                                  style: const TextStyle(
                                    color: Color(0xFF69E6A5),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                )
                              else if (eligible)
                                SizedBox(
                                  height: 27,
                                  child: ElevatedButton(
                                    onPressed: claiming
                                        ? null
                                        : () => _claimFrame(set, level),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: accent,
                                      foregroundColor: _bg,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      minimumSize: const Size(0, 27),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: claiming
                                        ? const SizedBox(
                                            width: 13,
                                            height: 13,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text(
                                            'CLAIM',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                  ),
                                )
                              else
                                const Text(
                                  'LOCKED',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }, childCount: 12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: .88,
                        ),
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
          ),
        ),
      ),
    );
  }
}
