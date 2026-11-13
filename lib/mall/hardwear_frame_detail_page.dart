import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _api = 'https://lovelysky.fastapicloud.dev';
const _bg = Color(0xFF100D25);
const _gold = Color(0xFFFFD779);

dynamic _decodeResponse(http.Response response) {
  try {
    return jsonDecode(response.body);
  } on FormatException {
    final body = response.body.trim();
    throw Exception(
      'Server error (${response.statusCode}): '
      '${body.isEmpty ? "Empty response" : body.substring(0, body.length > 180 ? 180 : body.length)}',
    );
  }
}

class HardwearFrameDetailPage extends StatefulWidget {
  const HardwearFrameDetailPage({super.key});

  @override
  State<HardwearFrameDetailPage> createState() =>
      _HardwearFrameDetailPageState();
}

class _HardwearFrameDetailPageState extends State<HardwearFrameDetailPage> {
  final _targetController = TextEditingController();
  String? _token;
  String _userCode = '';
  String _status = '';
  bool _loading = true;
  bool _working = false;
  WebViewController? _videoController;
  String? _videoError;

  Future<void> _initTransparentVideo() async {
    try {
      final bytes = await rootBundle.load(
        'assets/live_room_seat_frame_transparent.webm',
      );
      final videoData = base64Encode(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );

      final controller = WebViewController();
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setBackgroundColor(const Color(0x00000000));

      await controller.loadHtmlString('''
        <!DOCTYPE html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <style>
            html, body {
              margin: 0; padding: 0; width: 100%; height: 100%;
              overflow: hidden; background: transparent !important;
            }
            video {
              width: 100%; height: 100%;
              object-fit: contain; background: transparent;
            }
          </style>
        </head>
        <body>
          <video autoplay muted loop playsinline>
            <source src="data:video/webm;base64,$videoData"
                    type="video/webm">
          </video>
        </body>
        </html>
      ''');

      if (!mounted) return;
      setState(() => _videoController = controller);
    } catch (e) {
      if (!mounted) return;
      setState(() => _videoError = e.toString());
    }
  }

  @override
  void initState() {
    super.initState();
    _loadIdentity();
    _initTransparentVideo();
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

      final response = await http
          .get(
            Uri.parse('$_api/me'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));

      final data = _decodeResponse(response);
      if (response.statusCode != 200 || data is! Map) {
        throw Exception('Could not verify account.');
      }

      if (!mounted) return;
      setState(() {
        _token = token;
        _userCode = data['user_code']?.toString() ?? '';
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
      final response = await http
          .post(
            Uri.parse('$_api/owner/hardwear/frames/$action'),
            headers: {
              'Authorization': 'Bearer $_token',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'user_code': code, 'frame_code': 'super_admin'}),
          )
          .timeout(const Duration(seconds: 20));

      final data = _decodeResponse(response);
      if (data is! Map ||
          response.statusCode != 200 ||
          data['success'] != true) {
        throw Exception(
          data is Map
              ? data['detail']?.toString() ?? 'Request failed.'
              : 'Invalid server response.',
        );
      }

      _message(
        action == 'grant'
            ? 'SUPER ADMIN sent to User ID $code for 30 days.'
            : 'SUPER ADMIN removed from User ID $code.',
      );
    } catch (e) {
      _message(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Widget _ownerControls() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF201936),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _gold.withValues(alpha: .6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'OWNER HARDWEAR MANAGEMENT',
            style: TextStyle(
              color: _gold,
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
              fillColor: _bg,
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
                    backgroundColor: _gold,
                    foregroundColor: _bg,
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
                  child: const Text('REMOVE'),
                ),
              ),
            ],
          ),
          if (_working) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(color: _gold),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: Colors.white,
        title: const Text('HARDWEAR • SUPER ADMIN'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _gold))
          : _userCode != '1'
          ? Center(
              child: Text(
                _status.isNotEmpty ? _status : 'Owner access only.',
                style: const TextStyle(color: Colors.white70),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  height: 235,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF201936),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _gold.withValues(alpha: .7)),
                  ),
                  child: _videoController != null
                      ? WebViewWidget(controller: _videoController!)
                      : Center(
                          child: _videoError != null
                              ? Text(
                                  'Video error: $_videoError',
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                  ),
                                )
                              : const CircularProgressIndicator(color: _gold),
                        ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'SUPER ADMIN',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _gold,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),
                _info('Frame validity', '30 DAYS', Icons.timer_outlined),
                const SizedBox(height: 10),
                _info('Backpack', 'Added to receiver', Icons.backpack),
                const SizedBox(height: 18),
                _ownerControls(),
                if (_status.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    _status,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _info(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF201936),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: _gold),
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
}
