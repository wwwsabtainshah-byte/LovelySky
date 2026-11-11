import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _vipApi = 'https://lovelysky.fastapicloud.dev';
const _vipBg = Color(0xFF100D25);
const _vipBlue = Color(0xFF67D4FF);
const _vipGold = Color(0xFFFFD779);

dynamic _decodeVipResponse(http.Response response) {
  try {
    return jsonDecode(response.body);
  } on FormatException {
    final body = response.body.trim();
    final detail = body.isEmpty
        ? 'Empty server response'
        : body.substring(0, body.length > 180 ? 180 : body.length);
    throw Exception('Server error (${response.statusCode}): $detail');
  }
}

class VipWingDetailPage extends StatefulWidget {
  final int setNumber;
  final int level;
  final Map<String, dynamic> frameData;
  final int weeklyCoins;

  const VipWingDetailPage({
    super.key,
    required this.setNumber,
    required this.level,
    required this.frameData,
    required this.weeklyCoins,
  });

  @override
  State<VipWingDetailPage> createState() => _VipWingDetailPageState();
}

class _VipWingDetailPageState extends State<VipWingDetailPage> {
  String _userCode = '';
  String? _token;
  String _status = '';
  bool _loading = true;
  bool _working = false;
  bool _owned = false;

  final _targetController = TextEditingController();

  Color get _accent => widget.setNumber == 1 ? _vipBlue : _vipGold;

  int get _required =>
      (widget.frameData['required_coins'] as num?)?.toInt() ?? 0;

  double get _progress => _required <= 0
      ? 0
      : (widget.weeklyCoins / _required).clamp(0.0, 1.0);

  String get _expiry {
    final value = widget.frameData['expires_at'];
    if (value == null) return '';
    final date = DateTime.tryParse(value.toString());
    if (date == null) return '';
    final remaining = date.difference(DateTime.now());
    if (remaining.isNegative) return 'Expired';
    if (remaining.inDays > 0) return 'Expires in ${remaining.inDays}d';
    if (remaining.inHours > 0) return 'Expires in ${remaining.inHours}h';
    return 'Expires soon';
  }

  @override
  void initState() {
    super.initState();
    _owned = widget.frameData['owned'] == true;
    _loadIdentity();
  }

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _loadIdentity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('lovely_token');
      if (token == null || token.isEmpty) {
        throw Exception('Login required.');
      }

      final response = await http.get(
        Uri.parse('$_vipApi/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      final decoded = _decodeVipResponse(response);
      if (response.statusCode != 200 || decoded is! Map) {
        throw Exception('Could not verify account.');
      }

      if (!mounted) return;
      setState(() {
        _token = token;
        _userCode = decoded['user_code']?.toString() ?? '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _status = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _ownerAction(String action) async {
    if (_working) return;

    final code = _targetController.text.trim();
    if (!RegExp(r'^\d+$').hasMatch(code)) {
      _message('Enter a valid User ID.');
      return;
    }
    if (_token == null) {
      _message('Login required.');
      return;
    }

    setState(() {
      _working = true;
      _status = '';
    });

    try {
      final response = await http.post(
        Uri.parse('$_vipApi/owner/vip/wings/$action'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'user_code': code,
          'set_number': widget.setNumber,
          'level': widget.level,
        }),
      ).timeout(const Duration(seconds: 20));

      final decoded = _decodeVipResponse(response);
      if (decoded is! Map) {
        throw Exception('Invalid server response.');
      }
      if (response.statusCode != 200 || decoded['success'] != true) {
        throw Exception(decoded['detail']?.toString() ?? 'Request failed.');
      }

      _message(action == 'grant'
          ? 'VIP granted to User ID $code for 7 days.'
          : 'VIP removed from User ID $code.');
    } catch (e) {
      _message(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _claim() async {
    if (_working || _token == null) return;

    setState(() => _working = true);
    try {
      final response = await http.post(
        Uri.parse('$_vipApi/vip/wings/claim'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'set_number': widget.setNumber,
          'level': widget.level,
        }),
      ).timeout(const Duration(seconds: 20));

      final decoded = _decodeVipResponse(response);
      if (decoded is! Map ||
          response.statusCode != 200 ||
          decoded['success'] != true) {
        throw Exception(decoded is Map
            ? decoded['detail']?.toString() ?? 'VIP claim failed.'
            : 'Invalid server response.');
      }

      if (!mounted) return;
      setState(() => _owned = true);
      _message('VIP ${widget.level}, Set ${widget.setNumber} claimed.');
    } catch (e) {
      _message(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value)),
    );
  }

  Widget _infoCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF201936),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: _accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title, style: const TextStyle(color: Colors.white70)),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ownerControls() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF201936),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _vipGold.withValues(alpha: .6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'OWNER VIP MANAGEMENT',
            style: TextStyle(
              color: _vipGold,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _targetController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter User ID',
              hintStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: _vipBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _working ? null : () => _ownerAction('grant'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _vipBlue,
                    foregroundColor: _vipBg,
                  ),
                  child: const Text('SEND'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _working ? null : () => _ownerAction('remove'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB83E58),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('REMOVE / END VIP'),
                ),
              ),
            ],
          ),
          if (_working)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: LinearProgressIndicator(color: _vipBlue),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final number = widget.level.toString().padLeft(2, '0');
    final eligible = widget.frameData['eligible'] == true;

    return Scaffold(
      backgroundColor: _vipBg,
      appBar: AppBar(
        backgroundColor: _vipBg,
        foregroundColor: Colors.white,
        title: Text('VIP ${widget.level} • SET ${widget.setNumber}'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _vipBlue))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  height: 235,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF201936),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _accent.withValues(alpha: .7)),
                  ),
                  child: Image.asset(
                    'assets/vip_animated_combined10/set${widget.setNumber}_vip$number.gif',
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Icon(
                      Icons.broken_image_outlined,
                      color: _accent,
                      size: 55,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'VIP ${widget.level} • SET ${widget.setNumber}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _accent,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                _infoCard('Required verified Coins', '$_required',
                    Icons.monetization_on),
                const SizedBox(height: 9),
                _infoCard('Last 7 days verified purchases',
                    '${widget.weeklyCoins}', Icons.account_balance_wallet),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 9,
                    backgroundColor: Colors.white12,
                    color: _accent,
                  ),
                ),
                const SizedBox(height: 12),
                _infoCard('VIP status', _owned ? 'ACTIVE' : 'NOT OWNED',
                    Icons.verified),
                if (_expiry.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  _infoCard('Expiry', _expiry, Icons.timer_outlined),
                ],
                if (!_owned && eligible) ...[
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: _working ? null : _claim,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: _vipBg,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('CLAIM VIP'),
                  ),
                ],
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: const Color(0xFF201936),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BENEFITS',
                        style: TextStyle(
                          color: _vipBlue,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      SizedBox(height: 9),
                      Text(
                        'Benefits will be added later.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                if (_userCode == '1') ...[
                  const SizedBox(height: 18),
                  _ownerControls(),
                ],
                if (_status.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(_status,
                      style: const TextStyle(color: Colors.redAccent)),
                ],
              ],
            ),
    );
  }
}
