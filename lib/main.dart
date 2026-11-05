import 'package:flutter/services.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:firebase_core/firebase_core.dart';

import 'auth_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const LovelySkyApp());
}

const blue = Color(0xFF168FFF);
const sky = Color(0xFF67D4FF);
const pale = Color(0xFFEAF8FF);
const ink = Color(0xFF183B59);

class LovelySkyApp extends StatelessWidget {
  const LovelySkyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lovely Sky',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5FBFF),
        colorScheme: ColorScheme.fromSeed(seedColor: blue),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF5FBFF),
          foregroundColor: ink,
          elevation: 0,
        ),
      ),
      home: const AuthGate(home: MainScreen()),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int selected = 0;

  final pages = const [
    HomePage(),
    VideoPage(),
    VoicePage(),
    ChatPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: selected, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        backgroundColor: Colors.white,
        indicatorColor: pale,
        onDestinationSelected: (i) => setState(() => selected = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.video_library_rounded),
            label: 'Video',
          ),
          NavigationDestination(icon: Icon(Icons.mic_rounded), label: 'Voice'),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_rounded),
            label: 'Chat',
          ),
          NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Me'),
        ],
      ),
    );
  }
}

Widget pageTitle(String title, {String? subtitle, Widget? trailing}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blueGrey.shade500,
                  ),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

Widget roundIcon(IconData icon, {VoidCallback? onTap}) {
  return Material(
    color: Colors.white,
    shape: const CircleBorder(),
    child: IconButton(
      onPressed: onTap ?? () {},
      icon: Icon(icon, color: blue),
    ),
  );
}

Widget blueBanner(String title, String subtitle, IconData icon) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF168FFF), Color(0xFF67D4FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: blue.withValues(alpha: 0.16),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ),
        Icon(icon, size: 54, color: Colors.white.withValues(alpha: 0.95)),
      ],
    ),
  );
}

Widget sectionTitle(String title, {String action = 'See All'}) {
  return Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          action,
          style: const TextStyle(
            color: blue,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [blue, sky]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Colors.white,
                  size: 27,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lovely Sky',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: ink,
                      ),
                    ),
                    Text(
                      'Your world, your people',
                      style: TextStyle(fontSize: 11, color: Colors.blueGrey),
                    ),
                  ],
                ),
              ),
              roundIcon(Icons.notifications_none_rounded),
              const SizedBox(width: 8),
              roundIcon(Icons.account_circle_outlined),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF087BEA), Color(0xFF55C8F5)],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: blue.withValues(alpha: 0.20),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                const Positioned(
                  right: 0,
                  top: 0,
                  child: Icon(
                    Icons.cloud_rounded,
                    color: Color(0x55FFFFFF),
                    size: 76,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'WELCOME TO',
                      style: TextStyle(
                        color: Color(0xFFDDF5FF),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'Lovely Sky 💙',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Connect, share moments and make\nbeautiful memories together.',
                      style: TextStyle(
                        color: Colors.white,
                        height: 1.5,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Text(
                        'Explore now  →',
                        style: TextStyle(
                          color: blue,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: const Color(0xFFE3F1FA)),
            ),
            child: Row(
              children: [
                Icon(Icons.search_rounded, color: Colors.blueGrey.shade400),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Search people, rooms and more',
                    style: TextStyle(
                      color: Colors.blueGrey.shade400,
                      fontSize: 12,
                    ),
                  ),
                ),
                Icon(Icons.tune_rounded, color: blue),
              ],
            ),
          ),
          const SizedBox(height: 25),
          const Text(
            'Explore Lovely Sky',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: ink,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: const [
              Expanded(
                child: _HomeFeature(
                  icon: Icons.video_library_rounded,
                  title: 'Videos',
                  color: Color(0xFF168FFF),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _HomeFeature(
                  icon: Icons.mic_rounded,
                  title: 'Voice Rooms',
                  color: Color(0xFF12B9C9),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _HomeFeature(
                  icon: Icons.camera_alt_rounded,
                  title: 'Moments',
                  color: Color(0xFFE18BCB),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _HomeFeature(
                  icon: Icons.chat_bubble_rounded,
                  title: 'Chats',
                  color: Color(0xFF6688E8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Your Lovely Space',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: ink,
                  ),
                ),
              ),
              Text(
                'Discover',
                style: TextStyle(
                  color: blue,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE3F1FA)),
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: pale,
                  child: Icon(Icons.people_alt_rounded, color: blue, size: 27),
                ),
                SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Meet your community',
                        style: TextStyle(
                          color: ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Find people and make new friends.',
                        style: TextStyle(color: Colors.blueGrey, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, color: blue, size: 16),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF8FF),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: blue, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Share kindness, spread good vibes and enjoy your Lovely Sky.',
                    style: TextStyle(
                      color: ink,
                      fontSize: 12,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeFeature extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _HomeFeature({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 58,
          width: double.infinity,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(19),
          ),
          child: Icon(icon, color: color, size: 27),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: ink,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class QuickTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const QuickTile({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 54,
          width: 58,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, color: color, size: 27),
        ),
        const SizedBox(height: 7),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: ink,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class RoomCard extends StatelessWidget {
  final String title, subtitle, count;
  final IconData icon;
  const RoomCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE1F2FF)),
      ),
      child: Row(
        children: [
          Container(
            height: 62,
            width: 62,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [blue, sky]),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(icon, color: Colors.white, size: 31),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.blueGrey.shade400,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '● $count',
                  style: const TextStyle(
                    color: Color(0xFF14B88A),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
            decoration: BoxDecoration(
              color: blue,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Text(
              'Join',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class UserRow extends StatelessWidget {
  final String name, detail, avatar;
  const UserRow({
    super.key,
    required this.name,
    required this.detail,
    required this.avatar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: pale,
            child: Text(avatar, style: const TextStyle(fontSize: 25)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: TextStyle(
                    color: Colors.blueGrey.shade400,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: pale,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Follow',
              style: TextStyle(
                color: blue,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VideoPage extends StatefulWidget {
  const VideoPage({super.key});

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> {
  String selectedTab = 'Popular';
  List<Map<String, dynamic>> rooms = [];
  bool loading = true;
  bool creating = false;
  bool openingRoom = false;
  String? loadError;

  Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('lovely_token');
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final token = await _token();
    if (token == null || token.isEmpty) {
      throw Exception('Please login again.');
    }

    final uri = Uri.parse('$lovelyApi$path');
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    late http.Response response;
    if (method == 'POST') {
      response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(body ?? {}),
      );
    } else {
      response = await http.get(uri, headers: headers);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid server response.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(decoded['detail']?.toString() ?? 'Request failed.');
    }
    return decoded;
  }

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    if (mounted) {
      setState(() {
        loading = true;
        loadError = null;
      });
    }
    try {
      final tab = selectedTab.toLowerCase();
      final result = await _request('GET', '/video/rooms?tab=$tab');
      final items = (result['rooms'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (mounted) {
        setState(() {
          rooms = items;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          loadError = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _createRoom() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    final values = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Start a live room'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              maxLength: 60,
              decoration: const InputDecoration(
                labelText: 'Room title',
                hintText: 'Give your live room a name',
              ),
            ),
            TextField(
              controller: descriptionController,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'What are you sharing?',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final title = titleController.text.trim();
              if (title.isEmpty) return;
              Navigator.pop(dialogContext, [
                title,
                descriptionController.text.trim(),
              ]);
            },
            child: const Text('Create room'),
          ),
        ],
      ),
    );

    titleController.dispose();
    descriptionController.dispose();
    if (values == null || !mounted) return;

    setState(() => creating = true);
    try {
      final result = await _request(
        'POST',
        '/video/rooms',
        body: {'title': values[0], 'description': values[1]},
      );
      final roomId = result['room_id'];
      if (roomId == null) throw Exception('Room ID missing.');

      final room = <String, dynamic>{
        'id': roomId,
        'title': values[0],
        'description': values[1],
        'viewer_count': 0,
      };

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => VideoRoomPage(room: room)),
      );
      await _loadRooms();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => creating = false);
    }
  }

  Future<void> _openRoom(Map<String, dynamic> room) async {
    if (openingRoom || creating) return;
    setState(() => openingRoom = true);
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => VideoRoomPage(room: room)),
      );
    } finally {
      if (mounted) {
        setState(() => openingRoom = false);
        await _loadRooms();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadRooms,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF168FFF), Color(0xFF69C9FF)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: Colors.white,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Love Streaming',
                        style: TextStyle(
                          color: ink,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Share moments. Feel connected.',
                        style: TextStyle(color: Colors.black54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                roundIcon(Icons.search_rounded),
              ],
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF087FE8), Color(0xFF63C8FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF168FFF).withValues(alpha: 0.20),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '♡  LOVELY SKY LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Your moment\nto shine!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      height: 1.15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a room and connect with your audience.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 17),
                  FilledButton.icon(
                    onPressed: creating ? null : _createRoom,
                    icon: creating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF087FE8),
                            ),
                          )
                        : const Icon(Icons.videocam_rounded),
                    label: Text(creating ? 'PLEASE WAIT' : 'GO LIVE'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF087FE8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Discover Live Rooms',
              style: TextStyle(
                color: ink,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Find a live stream and join the conversation.',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 15),
            Row(
              children: ['Following', 'Popular', 'Visit'].map((tab) {
                final active = selectedTab == tab;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: GestureDetector(
                      onTap: () {
                        if (selectedTab == tab) return;
                        setState(() => selectedTab = tab);
                        _loadRooms();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          color: active
                              ? const Color(0xFF168FFF)
                              : const Color(0xFFEAF6FF),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          tab,
                          style: TextStyle(
                            color: active ? Colors.white : ink,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            if (loading)
              const Padding(
                padding: EdgeInsets.all(30),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (loadError != null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4F4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      size: 36,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 8),
                    Text(loadError!, textAlign: TextAlign.center),
                    TextButton(
                      onPressed: _loadRooms,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              )
            else if (rooms.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 28,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F9FF),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFDCEFFF)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDFF1FF),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: const Icon(
                        Icons.videocam_outlined,
                        color: Color(0xFF168FFF),
                        size: 39,
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'No Live Rooms Yet',
                      style: TextStyle(
                        color: ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      selectedTab == 'Following'
                          ? 'Rooms hosted by people you follow will appear here.'
                          : selectedTab == 'Visit'
                          ? 'Rooms you have visited will appear here.'
                          : 'Live rooms will appear here when creators go live.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...rooms.map((room) {
                final title = room['title']?.toString() ?? 'Live Room';
                final host =
                    room['host_name']?.toString() ?? 'Lovely Sky creator';
                final count = room['viewer_count'] ?? 0;
                final photo = room['host_photo']?.toString() ?? '';
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: Color(0xFFDCEFFF)),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _openRoom(room),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 27,
                            backgroundColor: const Color(0xFFDFF1FF),
                            backgroundImage: photo.isNotEmpty
                                ? NetworkImage(photo)
                                : null,
                            child: photo.isEmpty
                                ? const Icon(
                                    Icons.person,
                                    color: Color(0xFF168FFF),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: ink,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  host,
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '$count watching',
                                  style: const TextStyle(
                                    color: Color(0xFF168FFF),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.play_circle_fill_rounded,
                            color: Color(0xFF168FFF),
                            size: 34,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE5F1FC)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.chat_bubble_rounded,
                    color: Color(0xFF168FFF),
                    size: 25,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Watch, Chat & Connect',
                          style: TextStyle(
                            color: ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Room chat is connected. Live video needs streaming server setup.',
                          style: TextStyle(color: Colors.black54, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> openLovelyCasinoGames(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const LovelyCasinoGamesSheet(),
  );
}

class LovelyCasinoGamesSheet extends StatefulWidget {
  const LovelyCasinoGamesSheet({super.key});

  @override
  State<LovelyCasinoGamesSheet> createState() => _LovelyCasinoGamesSheetState();
}

class _LovelyCasinoGamesSheetState extends State<LovelyCasinoGamesSheet> {
  List<Map<String, dynamic>> games = [];
  List<Map<String, dynamic>> recentGames = [];
  int coins = 0;
  bool loading = true;
  bool launching = false;
  String message = 'Loading provider games...';
  Map<String, dynamic>? selectedGame;
  WebViewController? gameController;

  Future<Map<String, dynamic>> api(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('lovely_token');
    if (token == null || token.isEmpty) {
      throw Exception('Please login again.');
    }

    final uri = Uri.parse('$lovelyApi$path');
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final response = method == 'POST'
        ? await http.post(uri, headers: headers, body: jsonEncode(body ?? {}))
        : await http.get(uri, headers: headers);

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid server response.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded['detail'];
      if (detail is Map) {
        throw Exception(detail['message']?.toString() ?? detail.toString());
      }
      throw Exception(
        detail?.toString() ??
            decoded['error']?.toString() ??
            'Request failed (${response.statusCode}).',
      );
    }
    return decoded;
  }

  @override
  void initState() {
    super.initState();
    _loadRecentGames();
    _loadGames();
  }

  Future<void> _loadRecentGames() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('lovely_recent_games') ?? [];
      final loaded = <Map<String, dynamic>>[];
      for (final item in saved) {
        try {
          final decoded = jsonDecode(item);
          if (decoded is Map) {
            loaded.add(Map<String, dynamic>.from(decoded));
          }
        } catch (_) {}
      }
      if (mounted) setState(() => recentGames = loaded);
    } catch (_) {}
  }

  Future<void> _loadGames() async {
    setState(() {
      loading = true;
      message = 'Loading provider games...';
    });

    try {
      final results = await Future.wait([
        api('GET', '/games/wallet'),
        api('GET', '/games/provider/catalog'),
      ]);

      final wallet = results[0];
      final catalog = results[1];
      final rawGames = catalog['games'] as List? ?? [];

      if (!mounted) return;
      setState(() {
        coins = (wallet['coins'] as num?)?.toInt() ?? 0;
        games = rawGames
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .where((item) => item['id'] != null && item['slug'] != null)
            .toList();
        message = games.isEmpty
            ? 'No games are available in your provider catalogue.'
            : '';
      });
    } catch (e) {
      if (mounted) setState(() => message = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _openGame(Map<String, dynamic> game) async {
    if (launching) return;

    setState(() {
      launching = true;
      message = 'Creating secure game session...';
    });

    try {
      final data = await api(
        'POST',
        '/games/provider/session',
        body: {'game_id': game['slug'].toString()},
      );

      final launchUrl = data['launch_url']?.toString() ?? '';
      final uri = Uri.tryParse(launchUrl);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host != 'games.casinoapipro.com') {
        throw Exception('Provider returned an invalid game link.');
      }

      final controller = WebViewController();
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setBackgroundColor(const Color(0xFF071A2D));
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (error) {
            if (mounted && error.isForMainFrame == true) {
              setState(() {
                message = 'Game loading error: ${error.description}';
              });
            }
          },
        ),
      );
      await controller.loadRequest(uri);
      await _rememberGame(game);

      if (!mounted) return;
      setState(() {
        selectedGame = game;
        gameController = controller;
        message = '';
      });
    } catch (e) {
      if (mounted) setState(() => message = e.toString());
    } finally {
      if (mounted) setState(() => launching = false);
    }
  }

  Future<void> _rememberGame(Map<String, dynamic> game) async {
    final slug = game['slug']?.toString() ?? '';
    if (slug.isEmpty) return;

    final item = <String, dynamic>{
      'slug': slug,
      'name': game['name']?.toString() ?? slug,
      'thumbnail_url': game['thumbnail_url']?.toString() ?? '',
      'enabled': true,
      'status': 'ACTIVE',
    };

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('lovely_recent_games') ?? [];
    final updated = <String>[jsonEncode(item)];

    for (final entry in saved) {
      try {
        final old = jsonDecode(entry);
        if (old is Map &&
            old['slug']?.toString() != slug &&
            updated.length < 8) {
          updated.add(jsonEncode(old));
        }
      } catch (_) {}
    }

    await prefs.setStringList('lovely_recent_games', updated);
    if (mounted) {
      setState(() {
        recentGames = updated
            .map((e) => Map<String, dynamic>.from(jsonDecode(e)))
            .toList();
      });
    }
  }

  void _backToGames() {
    setState(() {
      selectedGame = null;
      gameController = null;
      message = '';
    });
  }

  String _formatCoins(int value) => value.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => ',',
  );

  Widget _gameTile(Map<String, dynamic> game) {
    final imageUrl = game['thumbnail_url']?.toString() ?? '';
    final name = game['name']?.toString() ?? game['slug']?.toString() ?? 'Game';
    final enabled =
        game['enabled'] == true &&
        game['status']?.toString().toUpperCase() == 'ACTIVE';

    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: launching || !enabled ? null : () => _openGame(game),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFFD6EDFC)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: imageUrl.startsWith('https://')
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.casino_rounded,
                        size: 42,
                        color: Color(0xFF168FFF),
                      ),
                    )
                  : const Icon(
                      Icons.casino_rounded,
                      size: 42,
                      color: Color(0xFF168FFF),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF183B59),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = selectedGame;
    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.94,
        decoration: const BoxDecoration(
          color: Color(0xFFF2FAFF),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 10, 10),
              child: Row(
                children: [
                  if (game != null)
                    IconButton(
                      onPressed: _backToGames,
                      icon: const Icon(Icons.arrow_back),
                    ),
                  Expanded(
                    child: Text(
                      game?['name']?.toString() ?? 'Lovely Sky Games',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF183B59),
                      ),
                    ),
                  ),
                  if (game == null)
                    Text(
                      '🪙 ${_formatCoins(coins)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF168FFF),
                      ),
                    ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            if (game != null && gameController != null)
              Expanded(child: WebViewWidget(controller: gameController!))
            else if (loading || launching)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (game == null &&
                (games.isNotEmpty || recentGames.isNotEmpty))
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (recentGames.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 10, 16, 8),
                        child: Text(
                          'Played Recently',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF183B59),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 145,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          scrollDirection: Axis.horizontal,
                          itemCount: recentGames.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 10),
                          itemBuilder: (_, index) => SizedBox(
                            width: 145,
                            child: _gameTile(recentGames[index]),
                          ),
                        ),
                      ),
                    ],
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: Text(
                        'All Games',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF183B59),
                        ),
                      ),
                    ),
                    Expanded(
                      child: games.isEmpty
                          ? const Center(
                              child: Text('No games available right now.'),
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.all(14),
                              itemCount: games.length,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 1.15,
                                  ),
                              itemBuilder: (_, index) =>
                                  _gameTile(games[index]),
                            ),
                    ),
                  ],
                ),
              )
            else
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.casino_rounded,
                          size: 58,
                          color: Color(0xFF168FFF),
                        ),
                        const SizedBox(height: 12),
                        Text(message, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _loadGames,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class VideoRoomPage extends StatefulWidget {
  final Map<String, dynamic> room;
  const VideoRoomPage({super.key, required this.room});

  @override
  State<VideoRoomPage> createState() => _VideoRoomPageState();
}

class _VideoRoomPageState extends State<VideoRoomPage> {
  final TextEditingController messageController = TextEditingController();
  List<Map<String, dynamic>> messages = [];
  Timer? refreshTimer;
  bool joined = false;
  bool isHost = false;
  bool busy = false;
  String? error;
  Room? liveKitRoom;
  EventsListener<RoomEvent>? liveKitListener;
  VideoTrack? videoTrack;
  bool liveConnecting = false;
  int _connectionGeneration = 0;
  bool _joiningRoom = false;
  bool _loadingMessages = false;
  bool cameraEnabled = false;
  bool microphoneEnabled = false;

  int get roomId => (widget.room['id'] as num).toInt();

  Future<void> _connectLiveKit() async {
    if (liveConnecting || liveKitRoom != null || !mounted) return;

    final generation = ++_connectionGeneration;
    liveConnecting = true;
    Room? lkRoom;
    EventsListener<RoomEvent>? listener;

    try {
      final access = await _request('POST', '/video/rooms/$roomId/token');
      final url = access['url']?.toString() ?? '';
      final token = access['token']?.toString() ?? '';

      if (url.isEmpty || token.isEmpty) {
        throw Exception('Live video access details are missing.');
      }
      if (!mounted || generation != _connectionGeneration) return;

      lkRoom = Room();
      listener = lkRoom.createListener();

      listener.on<TrackSubscribedEvent>((event) {
        if (generation == _connectionGeneration &&
            identical(liveKitRoom, lkRoom) &&
            event.track is VideoTrack &&
            mounted) {
          setState(() => videoTrack = event.track as VideoTrack);
        }
      });

      listener.on<TrackUnsubscribedEvent>((event) {
        if (generation == _connectionGeneration &&
            identical(liveKitRoom, lkRoom) &&
            identical(videoTrack, event.track) &&
            mounted) {
          setState(() => videoTrack = null);
        }
      });

      liveKitRoom = lkRoom;
      liveKitListener = listener;

      await lkRoom.connect(url, token);

      if (!mounted ||
          generation != _connectionGeneration ||
          !identical(liveKitRoom, lkRoom)) {
        await listener.cancelAll();
        await lkRoom.disconnect();
        return;
      }

      if (isHost) {
        await lkRoom.localParticipant?.setCameraEnabled(true);
        await lkRoom.localParticipant?.setMicrophoneEnabled(true);
        cameraEnabled = true;
        microphoneEnabled = true;

        for (final pub
            in lkRoom.localParticipant?.videoTrackPublications ?? []) {
          if (pub.track is VideoTrack) {
            videoTrack = pub.track as VideoTrack;
            break;
          }
        }
      } else {
        for (final participant in lkRoom.remoteParticipants.values) {
          for (final pub in participant.videoTrackPublications) {
            if (pub.track is VideoTrack) {
              videoTrack = pub.track as VideoTrack;
              break;
            }
          }
          if (videoTrack != null) break;
        }
      }

      if (mounted &&
          generation == _connectionGeneration &&
          identical(liveKitRoom, lkRoom)) {
        setState(() {});
      }
    } catch (e) {
      if (mounted && generation == _connectionGeneration) {
        setState(() {
          error = 'Live video: ${e.toString().replaceFirst('Exception: ', '')}';
        });
      }
      if (lkRoom != null && !identical(liveKitRoom, lkRoom)) {
        try {
          await listener?.cancelAll();
          await lkRoom.disconnect();
        } catch (_) {}
      }
    } finally {
      if (generation == _connectionGeneration) {
        liveConnecting = false;
        if (mounted) setState(() {});
      }
    }
  }

  Future<void> _toggleCamera() async {
    final room = liveKitRoom;
    if (room == null) return;
    try {
      final enabled = !cameraEnabled;
      await room.localParticipant?.setCameraEnabled(enabled);
      cameraEnabled = enabled;
      if (!enabled) {
        videoTrack = null;
      } else {
        for (final pub in room.localParticipant?.videoTrackPublications ?? []) {
          if (pub.track != null) {
            videoTrack = pub.track;
            break;
          }
        }
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> _toggleMicrophone() async {
    final room = liveKitRoom;
    if (room == null) return;
    try {
      final enabled = !microphoneEnabled;
      await room.localParticipant?.setMicrophoneEnabled(enabled);
      if (mounted) setState(() => microphoneEnabled = enabled);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> _disconnectLiveKit() async {
    // Invalidate callbacks from this room before disconnecting it.
    _connectionGeneration++;

    final listener = liveKitListener;
    final room = liveKitRoom;

    liveKitListener = null;
    liveKitRoom = null;
    videoTrack = null;
    liveConnecting = false;
    cameraEnabled = false;
    microphoneEnabled = false;

    try {
      await listener?.cancelAll();
    } catch (_) {}

    try {
      await room?.disconnect();
    } catch (_) {}
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('lovely_token');
    if (token == null || token.isEmpty) throw Exception('Please login again.');

    final uri = Uri.parse('$lovelyApi$path');
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
    final response = method == 'POST'
        ? await http.post(uri, headers: headers, body: jsonEncode(body ?? {}))
        : await http.get(uri, headers: headers);
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) throw Exception('Invalid response.');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(decoded['detail']?.toString() ?? 'Request failed.');
    }
    return decoded;
  }

  @override
  void initState() {
    super.initState();
    _joinRoom();
  }

  Future<void> _joinRoom() async {
    if (_joiningRoom || joined || !mounted) return;
    _joiningRoom = true;

    try {
      final result = await _request('POST', '/video/rooms/$roomId/join');

      if (!mounted) {
        await _request(
          'POST',
          '/video/rooms/$roomId/leave',
        ).catchError((_) => <String, dynamic>{});
        return;
      }

      setState(() {
        joined = true;
        isHost = result['role'] == 'host';
      });

      await _loadMessages();
      if (!mounted || !joined) return;

      await _connectLiveKit();

      if (mounted && joined) {
        refreshTimer?.cancel();
        refreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
          if (mounted && joined) _loadMessages();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      _joiningRoom = false;
    }
  }

  Future<void> _loadMessages() async {
    if (!joined || _loadingMessages || !mounted) return;
    _loadingMessages = true;

    try {
      final result = await _request('GET', '/video/rooms/$roomId/messages');
      final items = (result['messages'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      if (mounted && joined) setState(() => messages = items);
    } catch (_) {
    } finally {
      _loadingMessages = false;
    }
  }

  Future<void> _sendMessage() async {
    final message = messageController.text.trim();
    if (message.isEmpty || busy || !joined) return;
    messageController.clear();
    setState(() => busy = true);
    try {
      await _request(
        'POST',
        '/video/rooms/$roomId/messages',
        body: {'message': message},
      );
      await _loadMessages();
    } catch (e) {
      if (mounted) {
        messageController.text = message;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _endRoom() async {
    try {
      await _request('POST', '/video/rooms/$roomId/end');
      await _disconnectLiveKit();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    unawaited(_disconnectLiveKit());
    messageController.dispose();
    if (joined && !isHost) {
      _request(
        'POST',
        '/video/rooms/$roomId/leave',
      ).catchError((_) => <String, dynamic>{});
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.room['title']?.toString() ?? 'Live Room';
    final hostName =
        widget.room['host_name']?.toString() ?? 'Lovely Sky Creator';
    final hostPhoto = widget.room['host_photo']?.toString() ?? '';
    final viewerCount = widget.room['viewer_count']?.toString() ?? '0';

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-screen live video
          if (videoTrack != null)
            VideoTrackRenderer(videoTrack!, fit: VideoViewFit.cover)
          else
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF071B35),
                    Color(0xFF087FE8),
                    Color(0xFF020817),
                  ],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      liveConnecting
                          ? Icons.hourglass_top_rounded
                          : Icons.videocam_off_rounded,
                      color: Colors.white,
                      size: 65,
                    ),
                    const SizedBox(height: 15),
                    Text(
                      liveConnecting
                          ? 'Connecting to LIVE...'
                          : 'Waiting for live video',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 25),
                        child: Text(
                          error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // Dark overlays for readable controls
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 155,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xCC000000), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 370,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xE6000000), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top creator information
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: blue,
                        backgroundImage: hostPhoto.isNotEmpty
                            ? NetworkImage(hostPhoto)
                            : null,
                        child: hostPhoto.isEmpty
                            ? const Icon(Icons.person, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hostName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '● LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.visibility,
                              color: Colors.white,
                              size: 15,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              viewerCount,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          if (isHost) {
                            _endRoom();
                          } else {
                            Navigator.pop(context);
                          }
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 27,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Right-side LIVE action rail
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _liveActionIcon(
                          Icons.favorite_rounded,
                          'Like',
                          const Color(0xFFFF4D79),
                        ),
                        const SizedBox(height: 20),
                        _liveActionIcon(
                          Icons.card_giftcard_rounded,
                          'Gift',
                          const Color(0xFFFFC857),
                          onTap: () => openLovelyRoomGiftStore(context),
                        ),
                        const SizedBox(height: 20),
                        _liveGamesAction(),
                        const SizedBox(height: 20),
                        _liveActionIcon(
                          Icons.share_rounded,
                          'Share',
                          Colors.white,
                        ),
                        const SizedBox(height: 20),
                        _liveActionIcon(
                          Icons.people_alt_rounded,
                          'Viewers',
                          const Color(0xFF67D4FF),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // Live comments
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.77,
                    constraints: const BoxConstraints(maxHeight: 205),
                    margin: const EdgeInsets.only(left: 12, bottom: 8),
                    child: ListView.builder(
                      reverse: true,
                      shrinkWrap: true,
                      itemCount: messages.length > 6 ? 6 : messages.length,
                      itemBuilder: (context, index) {
                        final item = messages[messages.length - 1 - index];
                        final sender =
                            item['sender_code']?.toString() ?? 'Member';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.43),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 8,
                              ),
                              child: RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'ID $sender  ',
                                      style: const TextStyle(
                                        color: Color(0xFF75D5FF),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                      ),
                                    ),
                                    TextSpan(
                                      text: item['message']?.toString() ?? '',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Bottom message and LIVE controls
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
                  color: Colors.black.withValues(alpha: 0.25),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: messageController,
                              enabled: joined && !busy,
                              maxLength: 500,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                counterText: '',
                                hintText: 'Say something...',
                                hintStyle: const TextStyle(
                                  color: Colors.white70,
                                ),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.17),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 17,
                                  vertical: 11,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(28),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          CircleAvatar(
                            backgroundColor: blue,
                            child: IconButton(
                              onPressed: joined && !busy ? _sendMessage : null,
                              icon: const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 19,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          if (isHost) ...[
                            _liveControl(
                              cameraEnabled
                                  ? Icons.videocam_rounded
                                  : Icons.videocam_off_rounded,
                              cameraEnabled ? 'Camera' : 'Camera off',
                              _toggleCamera,
                            ),
                            _liveControl(
                              microphoneEnabled
                                  ? Icons.mic_rounded
                                  : Icons.mic_off_rounded,
                              microphoneEnabled ? 'Mic on' : 'Mic off',
                              _toggleMicrophone,
                            ),
                          ] else
                            const Text(
                              'WATCHING LIVE',
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          _liveControl(
                            Icons.chat_bubble_outline_rounded,
                            'Chat',
                            () =>
                                FocusScope.of(context)
                                    .requestFocus(FocusNode()),
                          ),
                          _liveControl(Icons.exit_to_app_rounded, 'Leave', () {
                            Navigator.pop(context);
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _liveGamesAction() {
    return InkWell(
      onTap: () => openLovelyCasinoGames(context),
      borderRadius: BorderRadius.circular(24),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.casino_rounded, color: Color(0xFF8DE4FF), size: 29),
          SizedBox(height: 4),
          Text(
            'Games',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _liveActionIcon(
    IconData icon,
    String label,
    Color color, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 29),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _liveControl(IconData icon, String label, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(15),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 23),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class VideoCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  const VideoCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF168FFF), Color(0xFF8BDEFF)],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 4,
            top: 2,
            child: Icon(
              icon,
              size: 100,
              color: Colors.white.withValues(alpha: 0.23),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(subtitle, style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 10),
                const Icon(Icons.favorite_border_rounded, color: Colors.white),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class VoicePage extends StatefulWidget {
  const VoicePage({super.key});

  @override
  State<VoicePage> createState() => _VoicePageState();
}

class _VoicePageState extends State<VoicePage> {
  List<Map<String, dynamic>> rooms = [];
  bool loading = false;
  bool creating = false;
  String selectedTab = 'popular';

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('lovely_token');
  }

  Future<void> _loadRooms() async {
    if (mounted) setState(() => loading = true);
    try {
      final token = await _token();
      if (token == null || token.isEmpty) {
        _message('Please log in first.');
        return;
      }

      final headers = {'Authorization': 'Bearer $token'};

      final response = await http
          .get(
            Uri.parse('$lovelyApi/voice/rooms?tab=$selectedTab'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        _message('Rooms load nahi huay (${response.statusCode}).');
        return;
      }

      final data = jsonDecode(response.body);
      if (data is! Map || data['rooms'] is! List) {
        _message('Room list ka response samajh nahi aaya.');
        return;
      }

      final loadedRooms = (data['rooms'] as List)
          .whereType<Map>()
          .map((r) => Map<String, dynamic>.from(r))
          .toList();

      // Apne rooms bhi load karo, taake Popular tab mein bhi nazar aa saken.
      try {
        final mineResponse = await http
            .get(Uri.parse('$lovelyApi/voice/rooms/mine'), headers: headers)
            .timeout(const Duration(seconds: 15));

        if (mineResponse.statusCode == 200) {
          final mineData = jsonDecode(mineResponse.body);
          if (mineData is Map && mineData['rooms'] is List) {
            final knownIds = loadedRooms.map((r) => '${r['id']}').toSet();
            for (final item in mineData['rooms'] as List) {
              if (item is Map) {
                final room = Map<String, dynamic>.from(item);
                if (room['is_active'] == 1 && knownIds.add('${room['id']}')) {
                  loadedRooms.insert(0, room);
                }
              }
            }
          }
        }
      } catch (_) {
        // Current tab ki room list phir bhi dikhao.
      }

      if (mounted) {
        setState(() => rooms = loadedRooms);
      }
    } catch (_) {
      _message('Connection failed. Backend deployment check karein.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _createRoom() async {
    final name = TextEditingController();
    final description = TextEditingController();

    final details = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Voice Room'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                maxLength: 60,
                decoration: const InputDecoration(
                  labelText: 'Room name',
                  hintText: 'Lovely Friends',
                  prefixIcon: Icon(Icons.mic_rounded),
                ),
              ),
              TextField(
                controller: description,
                maxLength: 200,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              Navigator.pop(ctx, {
                'name': name.text.trim(),
                'description': description.text.trim(),
              });
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    name.dispose();
    description.dispose();
    if (details == null || !mounted) return;

    setState(() => creating = true);
    try {
      final token = await _token();
      if (token == null || token.isEmpty) {
        _message('Please log in first.');
        return;
      }

      final response = await http
          .post(
            Uri.parse('$lovelyApi/voice/rooms'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(details),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final createdRoom = data is Map ? data['room'] : null;

        if (createdRoom is! Map) {
          setState(() => selectedTab = 'visit');
          await _loadRooms();
          _message(
            'Room ban gaya, lekin room details response mein nahi milin.',
          );
          return;
        }

        setState(() => selectedTab = 'visit');
        await _loadRooms();
        if (!mounted) return;

        await _joinRoom(Map<String, dynamic>.from(createdRoom));
      } else {
        var error = 'Room create nahi hua (${response.statusCode}).';
        try {
          final data = jsonDecode(response.body);
          if (data is Map && data['detail'] != null) {
            error = data['detail'].toString();
          }
        } catch (_) {}
        _message(error);
      }
    } catch (_) {
      _message('Connection failed. Backend deployment check karein.');
    } finally {
      if (mounted) setState(() => creating = false);
    }
  }

  Future<void> _joinRoom(Map<String, dynamic> room) async {
    final id = room['id'];
    if (id == null) {
      _message('Room ID missing hai.');
      return;
    }
    try {
      final token = await _token();
      if (token == null || token.isEmpty) {
        _message('Please log in first.');
        return;
      }
      final response = await http
          .post(
            Uri.parse('$lovelyApi/voice/rooms/$id/join'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        if (!mounted) return;
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => VoiceRoomScreen(room: room)));
        if (mounted) await _loadRooms();
      } else {
        _message('Room join nahi hua (${response.statusCode}).');
      }
    } catch (_) {
      _message('Room join karte waqt connection error aaya.');
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Widget _tab(String label, String value) {
    final active = selectedTab == value;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: FilledButton(
          onPressed: loading
              ? null
              : () {
                  setState(() => selectedTab = value);
                  _loadRooms();
                },
          style: FilledButton.styleFrom(
            backgroundColor: active ? blue : Colors.white,
            foregroundColor: active ? Colors.white : blue,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(color: blue.withValues(alpha: 0.2)),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadRooms,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            pageTitle(
              'Voice Rooms',
              subtitle: 'Talk • Make Friends • Have Fun',
              trailing: roundIcon(
                Icons.add_rounded,
                onTap: creating ? null : _createRoom,
              ),
            ),
            blueBanner(
              'Your Voice, Your World',
              'Join a room and meet new people',
              Icons.mic_rounded,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _tab('Following', 'following'),
                _tab('Popular', 'popular'),
                _tab('Visit', 'visit'),
              ],
            ),
            const SizedBox(height: 18),
            if (loading)
              const Padding(
                padding: EdgeInsets.all(28),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (rooms.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 35),
                child: Column(
                  children: [
                    Icon(
                      Icons.mic_none_rounded,
                      size: 48,
                      color: blue.withValues(alpha: 0.6),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      selectedTab == 'following'
                          ? 'Follow users to see their rooms here.'
                          : selectedTab == 'visit'
                          ? 'No visited rooms yet. Your own rooms will appear here.'
                          : 'Abhi koi active voice room nahi hai.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: ink),
                    ),
                    if (selectedTab == 'visit') ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _createRoom,
                        icon: const Icon(Icons.add),
                        label: const Text('Create your room'),
                      ),
                    ],
                  ],
                ),
              )
            else
              ...rooms.map((room) {
                final name = (room['name'] ?? 'Voice Room').toString();
                final description = (room['description'] ?? '').toString();
                final count = (room['participant_count'] ?? 0).toString();
                final owner = (room['owner_code'] ?? '').toString();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _joinRoom(room),
                      child: Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE1F2FF)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              height: 58,
                              width: 58,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [blue, sky],
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.mic_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      color: ink,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    description.isEmpty
                                        ? 'Room #${room['id']}'
                                        : description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.blueGrey.shade400,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    '● $count members${owner.isEmpty ? '' : '  •  Host #$owner'}',
                                    style: const TextStyle(
                                      color: Color(0xFF14B88A),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 13,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: blue,
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: const Text(
                                'Join',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    final people = [
      ['Ayesha 💕', 'Hey! How are you?', '3', '🌸'],
      ['Usman', 'Voice message', '1', '😎'],
      ['Lovely Family', 'Welcome to the group!', '5', '💙'],
      ['Sara 🌷', 'Typing...', '2', '🌷'],
      ['Ali Khan', 'Nice to meet you!', '0', '✨'],
    ];
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          pageTitle(
            'Messages',
            subtitle: 'Stay close to your friends',
            trailing: roundIcon(Icons.add_comment_rounded),
          ),
          TextField(
            decoration: InputDecoration(
              hintText: 'Search conversations',
              prefixIcon: const Icon(Icons.search, color: blue),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Wrap(
            spacing: 8,
            children: [
              Chip(label: Text('All'), backgroundColor: pale),
              Chip(label: Text('Friends')),
              Chip(label: Text('Groups')),
            ],
          ),
          const SizedBox(height: 10),
          ...people.map((p) => UserRow(name: p[0], detail: p[1], avatar: p[3])),
        ],
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

Future<Map<String, dynamic>> _roomGiftRequest(
  String method,
  String path, {
  Map<String, dynamic>? body,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('lovely_token');
  if (token == null || token.isEmpty) {
    throw Exception('Please login again.');
  }
  final headers = {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };
  final uri = Uri.parse('$lovelyApi$path');
  final response = method == 'POST'
      ? await http.post(uri, headers: headers, body: jsonEncode(body ?? {}))
      : await http.get(uri, headers: headers);
  final decoded = jsonDecode(response.body);
  if (decoded is! Map<String, dynamic>) {
    throw Exception('Invalid server response.');
  }
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception(decoded['detail']?.toString() ?? 'Request failed.');
  }
  return decoded;
}

Future<void> _openLovelyVoiceRoomGiftStore(
  BuildContext context,
  String roomId,
) async {
  try {
    final data = await Future.wait([
      _roomGiftRequest('GET', '/gifts/catalog'),
      _roomGiftRequest('GET', '/games/wallet'),
      _roomGiftRequest('GET', '/voice/rooms/$roomId/members'),
    ]);
    if (!context.mounted) return;

    final gifts = (data[0]['gifts'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final wallet = data[1]['wallet'] is Map
        ? Map<String, dynamic>.from(data[1]['wallet'] as Map)
        : data[1];
    var coins = int.tryParse('${wallet['coins'] ?? 0}') ?? 0;
    var members = (data[2]['members'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final selected = <String>{};
    var allSelected = false;
    String? giftCode;
    var sending = false;
    var quantity = 1;
    String selectedCategory = 'Gift';
    Timer? timer;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF170F35),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          timer ??= Timer.periodic(const Duration(seconds: 4), (_) async {
            try {
              final fresh = await Future.wait([
                _roomGiftRequest('GET', '/games/wallet'),
                _roomGiftRequest('GET', '/voice/rooms/$roomId/members'),
              ]);
              if (!sheetContext.mounted) return;
              final w = fresh[0]['wallet'] is Map
                  ? Map<String, dynamic>.from(fresh[0]['wallet'] as Map)
                  : fresh[0];
              final updated = (fresh[1]['members'] as List? ?? [])
                  .map((e) => Map<String, dynamic>.from(e as Map))
                  .toList();
              setSheetState(() {
                coins = int.tryParse('${w['coins'] ?? coins}') ?? coins;
                members = updated;
                final valid = members
                    .map((m) => '${m['user_code'] ?? ''}')
                    .where((v) => v.isNotEmpty)
                    .toSet();
                selected.removeWhere((v) => !valid.contains(v));
                if (allSelected) {
                  selected
                    ..clear()
                    ..addAll(valid);
                }
              });
            } catch (_) {}
          });

          Map<String, dynamic>? chosenGift;
          for (final item in gifts) {
            if ('${item['code']}' == giftCode) chosenGift = item;
          }
          final cost = chosenGift == null
              ? 0
              : (int.tryParse('${chosenGift['coin_cost']}') ?? 0);
          final total = cost * selected.length * quantity;
          final visibleGifts = gifts.where((gift) {
            final category = '${gift['category'] ?? 'Gift'}';
            return category == selectedCategory;
          }).toList();

          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(sheetContext).size.height * .90,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 40),
                        const Text(
                          'Lovely Gift Box',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFFE4FF),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFFEAD9FF),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 76,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: members.length + 1,
                        separatorBuilder: (_, __) => const SizedBox(width: 9),
                        itemBuilder: (ctx, index) {
                          if (index == members.length) {
                            final active =
                                allSelected &&
                                selected.length == members.length &&
                                members.isNotEmpty;
                            return GestureDetector(
                              onTap: () => setSheetState(() {
                                allSelected = !active;
                                selected
                                  ..clear()
                                  ..addAll(
                                    allSelected
                                        ? members
                                              .map(
                                                (m) =>
                                                    '${m['user_code'] ?? ''}',
                                              )
                                              .where((v) => v.isNotEmpty)
                                        : <String>{},
                                  );
                              }),
                              child: Column(
                                children: [
                                  Container(
                                    width: 45,
                                    height: 45,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: active
                                          ? const Color(0xFF438EDB)
                                          : const Color(0xFFE4F0FC),
                                      border: Border.all(
                                        color: const Color(0xFF438EDB),
                                      ),
                                    ),
                                    child: Text(
                                      'ALL',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: active
                                            ? Colors.white
                                            : const Color(0xFF2866A5),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Everyone',
                                    style: TextStyle(fontSize: 10),
                                  ),
                                ],
                              ),
                            );
                          }

                          final member = members[index];
                          final code = '${member['user_code'] ?? ''}';
                          final active = selected.contains(code);
                          final photo = '${member['profile_photo'] ?? ''}';
                          final hasPhoto = photo.startsWith('http');

                          return GestureDetector(
                            onTap: () => setSheetState(() {
                              allSelected = false;
                              selected
                                ..clear()
                                ..add(code);
                            }),
                            child: SizedBox(
                              width: 50,
                              child: Column(
                                children: [
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Container(
                                        width: 45,
                                        height: 45,
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: active
                                                ? const Color(0xFF438EDB)
                                                : Colors.transparent,
                                            width: 2.5,
                                          ),
                                        ),
                                        child: ClipOval(
                                          child: hasPhoto
                                              ? Image.network(
                                                  photo,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      const Icon(Icons.person),
                                                )
                                              : const ColoredBox(
                                                  color: Color(0xFFE4F0FC),
                                                  child: Icon(
                                                    Icons.person,
                                                    color: Color(0xFF438EDB),
                                                  ),
                                                ),
                                        ),
                                      ),
                                      Positioned(
                                        right: -3,
                                        top: -3,
                                        child: Container(
                                          width: 17,
                                          height: 17,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE5A5FF),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: const Color(0xFF170F35),
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Text(
                                            '${index + 1}',
                                            style: const TextStyle(
                                              color: Color(0xFF170F35),
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    code,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final tab in [
                            'Gift',
                            'CP',
                            'Lucky Gift',
                            'Flag',
                            'Exclusive',
                          ])
                            GestureDetector(
                              onTap: () => setSheetState(() {
                                selectedCategory = tab;
                                giftCode = null;
                              }),
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 15,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: selectedCategory == tab
                                      ? const Color(0xFF63358B)
                                      : const Color(0xFF281A45),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: selectedCategory == tab
                                        ? const Color(0xFFE5A5FF)
                                        : const Color(0xFF49345F),
                                  ),
                                ),
                                child: Text(
                                  tab,
                                  style: TextStyle(
                                    color: selectedCategory == tab
                                        ? Colors.white
                                        : const Color(0xFF9B8AAE),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const SizedBox(height: 6),
                    Text(
                      '${selected.length} member(s) selected',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF66809A),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: visibleGifts.isEmpty
                          ? Center(
                              child: Text(
                                'No $selectedCategory gifts available yet.',
                                style: const TextStyle(
                                  color: Color(0xFF9B8AAE),
                                ),
                              ),
                            )
                          : GridView.builder(
                              itemCount: visibleGifts.length,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 4,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                    childAspectRatio: 1.08,
                                  ),
                              itemBuilder: (ctx, index) {
                                final gift = visibleGifts[index];
                                final code = '${gift['code']}';
                                final price =
                                    int.tryParse('${gift['coin_cost']}') ?? 0;
                                final active = giftCode == code;
                                return InkWell(
                                  borderRadius: BorderRadius.circular(15),
                                  onTap: () =>
                                      setSheetState(() => giftCode = code),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: active
                                          ? const Color(0xFF63358B)
                                          : const Color(0xFF281A45),
                                      borderRadius: BorderRadius.circular(15),
                                      border: Border.all(
                                        color: active
                                            ? const Color(0xFF438EDB)
                                            : const Color(0xFF49345F),
                                        width: active ? 2 : 1,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          '${gift['emoji'] ?? '🎁'}',
                                          style: const TextStyle(fontSize: 28),
                                        ),
                                        Text(
                                          '${gift['name']}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFF4E9FF),
                                          ),
                                        ),
                                        Text(
                                          '$price Coins',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFFC9B5E8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text(
                          'Quantity',
                          style: TextStyle(color: Color(0xFFEAD9FF)),
                        ),
                        const Spacer(),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: quantity > 1
                              ? () => setSheetState(() => quantity--)
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                          color: const Color(0xFFE5A5FF),
                        ),
                        Text(
                          '$quantity',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: quantity < 99
                              ? () => setSheetState(() => quantity++)
                              : null,
                          icon: const Icon(Icons.add_circle),
                          color: const Color(0xFFE5A5FF),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Your Coins: $coins',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFEAD9FF),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 46,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF9B55C7),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 25,
                              ),
                            ),
                            onPressed:
                                sending ||
                                    giftCode == null ||
                                    selected.isEmpty ||
                                    total > coins
                                ? null
                                : () async {
                                    setSheetState(() => sending = true);
                                    try {
                                      final result = await _roomGiftRequest(
                                        'POST',
                                        '/voice/rooms/$roomId/gifts/send',
                                        body: {
                                          'receiver_codes': selected.toList(),
                                          'gift_code': giftCode,
                                          'quantity': quantity,
                                        },
                                      );
                                      if (!sheetContext.mounted) return;
                                      coins =
                                          int.tryParse(
                                            '${result['sender_coins'] ?? coins}',
                                          ) ??
                                          coins;
                                      setSheetState(() {});
                                      ScaffoldMessenger.of(
                                        sheetContext,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Gift sent to ${result['recipients_count']} member(s). '
                                            '${result['coins_spent']} Coins spent.',
                                          ),
                                        ),
                                      );
                                    } catch (e) {
                                      if (sheetContext.mounted) {
                                        ScaffoldMessenger.of(sheetContext)
                                            .showSnackBar(
                                              SnackBar(content: Text('$e')),
                                            );
                                      }
                                    } finally {
                                      if (sheetContext.mounted) {
                                        setSheetState(() => sending = false);
                                      }
                                    }
                                  },
                            child: Text(
                              sending ? 'SENDING...' : 'SEND • $total',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    timer?.cancel();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gift Box error: $e')));
    }
  }
}

Future<void> openLovelyRoomGiftStore(
  BuildContext context, {
  Object? roomId,
}) async {
  if (roomId != null) {
    await _openLovelyVoiceRoomGiftStore(context, roomId.toString());
    return;
  }
  try {
    final results = await Future.wait([
      _roomGiftRequest('GET', '/gifts/catalog'),
      _roomGiftRequest('GET', '/games/wallet'),
    ]);
    if (!context.mounted) return;

    final gifts = (results[0]['gifts'] as List? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final wallet = results[1]['wallet'] is Map
        ? Map<String, dynamic>.from(results[1]['wallet'] as Map)
        : results[1];
    int coins = int.tryParse('${wallet['coins'] ?? 0}') ?? 0;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            20,
            18,
            MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Lovely Gift Store',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text('Your Coins: $coins'),
              const SizedBox(height: 14),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: gifts.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (itemContext, index) {
                    final gift = gifts[index];
                    final cost = int.tryParse('${gift['coin_cost']}') ?? 0;
                    return ListTile(
                      leading: Text(
                        '${gift['emoji'] ?? '🎁'}',
                        style: const TextStyle(fontSize: 30),
                      ),
                      title: Text('${gift['name'] ?? 'Gift'}'),
                      subtitle: Text('$cost Coins each'),
                      trailing: const Icon(
                        Icons.send_rounded,
                        color: Color(0xFF438EDB),
                      ),
                      onTap: () async {
                        final receiverController = TextEditingController();
                        final receiverCode = await showDialog<String>(
                          context: sheetContext,
                          builder: (dialogContext) => AlertDialog(
                            title: Text('Send ${gift['name']}'),
                            content: TextField(
                              controller: receiverController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Receiver User ID',
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(
                                  dialogContext,
                                  receiverController.text.trim(),
                                ),
                                child: const Text('Send'),
                              ),
                            ],
                          ),
                        );
                        receiverController.dispose();
                        if (receiverCode == null ||
                            receiverCode.isEmpty ||
                            !sheetContext.mounted)
                          return;

                        try {
                          final result = await _roomGiftRequest(
                            'POST',
                            '/gifts/send',
                            body: {
                              'receiver_code': receiverCode,
                              'gift_code': gift['code'],
                              'quantity': 1,
                            },
                          );
                          if (!sheetContext.mounted) return;
                          coins =
                              int.tryParse(
                                '${result['sender_coins'] ?? coins}',
                              ) ??
                              coins;
                          setSheetState(() {});
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${gift['name']} sent! '
                                '${result['coins_spent']} Coins spent.',
                              ),
                            ),
                          );
                        } catch (e) {
                          if (sheetContext.mounted) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gift Store error: $e')));
    }
  }
}

class _ProfilePageState extends State<ProfilePage> {
  String displayName = 'Lovely User 💙';
  String userCode = '';
  String profilePhoto = '';
  bool profileLoading = true;
  bool databaseChecking = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('lovely_token');

      if (token == null || token.isEmpty) {
        if (mounted) setState(() => profileLoading = false);
        return;
      }

      final response = await http
          .get(
            Uri.parse('$lovelyApi/me'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          if (mounted) {
            setState(() {
              final name = decoded['display_name']?.toString().trim() ?? '';
              final code = decoded['user_code']?.toString().trim() ?? '';
              final photo = decoded['profile_photo']?.toString().trim() ?? '';

              if (name.isNotEmpty) displayName = name;
              if (code.isNotEmpty) userCode = code;
              if (photo.startsWith('https://') || photo.startsWith('http://')) {
                profilePhoto = photo;
              }
              profileLoading = false;
            });
          }
          return;
        }
      }
    } catch (_) {
      // Agar network temporary band ho to screen crash na ho.
    }

    if (mounted) setState(() => profileLoading = false);
  }

  Future<Map<String, dynamic>> _giftRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('lovely_token');
    if (token == null || token.isEmpty) {
      throw Exception('Please login again.');
    }

    final uri = Uri.parse('$lovelyApi$path');
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
    final response = method == 'POST'
        ? await http.post(uri, headers: headers, body: jsonEncode(body ?? {}))
        : await http.get(uri, headers: headers);

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid server response.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(decoded['detail']?.toString() ?? 'Request failed.');
    }
    return decoded;
  }

  Future<void> _openWallet() async {
    try {
      final data = await _giftRequest('GET', '/games/wallet');
      if (!mounted) return;

      int coins = int.tryParse('${data['coins'] ?? 0}') ?? 0;
      int diamonds = int.tryParse('${data['diamonds'] ?? 0}') ?? 0;
      List<Map<String, dynamic>> transactions =
          (data['transactions'] as List? ?? [])
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();

      final exchangeController = TextEditingController();
      bool exchanging = false;

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (sheetContext) => StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                22,
                20,
                MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Text(
                        'My Wallet',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF245A9A),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _walletBalanceCard(
                            'Coins',
                            coins,
                            Icons.monetization_on_rounded,
                            const Color(0xFFFFB938),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _walletBalanceCard(
                            'Diamonds',
                            diamonds,
                            Icons.diamond_rounded,
                            const Color(0xFF48B8E8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Exchange Diamonds to Coins',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      '2 Diamonds = 1 Coin',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: exchangeController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Enter Diamonds (e.g. 1000000)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixText: 'Diamonds',
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: exchanging
                            ? null
                            : () async {
                                final amount = int.tryParse(
                                  exchangeController.text.trim(),
                                );
                                if (amount == null ||
                                    amount < 2 ||
                                    amount % 2 != 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Even Diamonds amount enter karein.',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                if (amount > diamonds) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Not enough Diamonds.'),
                                    ),
                                  );
                                  return;
                                }

                                setSheetState(() => exchanging = true);
                                try {
                                  final result = await _giftRequest(
                                    'POST',
                                    '/games/wallet/exchange',
                                    body: {'diamonds': amount},
                                  );
                                  if (!mounted) return;

                                  final updated = await _giftRequest(
                                    'GET',
                                    '/games/wallet',
                                  );
                                  coins =
                                      int.tryParse(
                                        '${updated['coins'] ?? result['coins'] ?? 0}',
                                      ) ??
                                      0;
                                  diamonds =
                                      int.tryParse(
                                        '${updated['diamonds'] ?? result['diamonds'] ?? 0}',
                                      ) ??
                                      0;
                                  transactions =
                                      (updated['transactions'] as List? ?? [])
                                          .map(
                                            (item) => Map<String, dynamic>.from(
                                              item as Map,
                                            ),
                                          )
                                          .toList();
                                  exchangeController.clear();
                                  setSheetState(() {});
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${result['coins_received']} Coins added successfully!',
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(e.toString())),
                                    );
                                  }
                                } finally {
                                  if (sheetContext.mounted) {
                                    setSheetState(() => exchanging = false);
                                  }
                                }
                              },
                        child: Text(
                          exchanging ? 'Please wait...' : 'Exchange Now',
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Transaction History',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (transactions.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Center(child: Text('No transactions yet.')),
                      )
                    else
                      ...transactions.take(30).map((item) {
                        final currency =
                            item['currency']?.toString().toUpperCase() ?? '';
                        final amount = item['amount'] ?? 0;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            currency == 'DIAMONDS'
                                ? Icons.diamond_rounded
                                : Icons.monetization_on_rounded,
                            color: currency == 'DIAMONDS'
                                ? const Color(0xFF48B8E8)
                                : const Color(0xFFFFB938),
                          ),
                          title: Text(
                            item['description']?.toString() ??
                                item['transaction_type']?.toString() ??
                                'Transaction',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(
                            '$amount $currency',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            );
          },
        ),
      );
      exchangeController.dispose();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Wallet error: $e')));
      }
    }
  }

  Widget _walletBalanceCard(
    String label,
    int amount,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 8),
          Text(
            amount.toString(),
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
          ),
          Text(label, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }

  Future<void> _openGiftStore() async {
    try {
      final results = await Future.wait([
        _giftRequest('GET', '/gifts/catalog'),
        _giftRequest('GET', '/games/wallet'),
      ]);
      final gifts = (results[0]['gifts'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      final wallet = results[1]['wallet'] is Map
          ? Map<String, dynamic>.from(results[1]['wallet'] as Map)
          : results[1];
      if (!mounted) return;

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.38,
        ),
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (sheetContext) => StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            int coins = int.tryParse('${wallet['coins'] ?? 0}') ?? 0;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                20,
                18,
                MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Lovely Gift Store',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text('Your Coins: $coins'),
                  const SizedBox(height: 14),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: gifts.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final gift = gifts[index];
                        final cost = int.tryParse('${gift['coin_cost']}') ?? 0;
                        return ListTile(
                          leading: Text(
                            '${gift['emoji'] ?? '🎁'}',
                            style: const TextStyle(fontSize: 30),
                          ),
                          title: Text('${gift['name'] ?? 'Gift'}'),
                          subtitle: Text('$cost Coins each'),
                          trailing: const Icon(Icons.send_rounded, color: blue),
                          onTap: () async {
                            final receiverController = TextEditingController();
                            final receiverCode = await showDialog<String>(
                              context: sheetContext,
                              builder: (dialogContext) => AlertDialog(
                                title: Text('Send ${gift['name']}'),
                                content: TextField(
                                  controller: receiverController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Receiver User ID',
                                    hintText: 'Enter user ID',
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(
                                      dialogContext,
                                      receiverController.text.trim(),
                                    ),
                                    child: const Text('Continue'),
                                  ),
                                ],
                              ),
                            );
                            receiverController.dispose();
                            if (receiverCode == null || receiverCode.isEmpty)
                              return;

                            try {
                              final result = await _giftRequest(
                                'POST',
                                '/gifts/send',
                                body: {
                                  'receiver_code': receiverCode,
                                  'gift_code': gift['code'],
                                  'quantity': 1,
                                },
                              );
                              wallet['coins'] = result['sender_coins'];
                              if (!mounted) return;
                              setSheetState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${gift['name']} sent! '
                                    '${result['coins_spent']} Coins spent.',
                                  ),
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gift Store: $e')));
    }
  }

  Future<void> _openGiftBag() async {
    try {
      final results = await Future.wait([
        _giftRequest('GET', '/gifts/bag'),
        _giftRequest('GET', '/gifts/history'),
      ]);

      final gifts = (results[0]['gifts'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      final history = (results[1]['history'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      if (!mounted) return;

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (sheetContext) => SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.75,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'My Gift Bag',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Received Gifts',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  if (gifts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('Your Gift Bag is empty.'),
                    )
                  else
                    ...gifts.map(
                      (gift) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Text(
                          '${gift['emoji'] ?? '🎁'}',
                          style: const TextStyle(fontSize: 30),
                        ),
                        title: Text('${gift['name'] ?? 'Gift'}'),
                        trailing: Text('× ${gift['quantity'] ?? 0}'),
                      ),
                    ),
                  const Divider(height: 24),
                  const Text(
                    'Gift History',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: history.isEmpty
                        ? const Center(child: Text('No gift history yet.'))
                        : ListView.builder(
                            itemCount: history.length,
                            itemBuilder: (context, index) {
                              final item = history[index];
                              final sent =
                                  '${item['sender_code']}' ==
                                  userCode.toString();
                              final otherCode = sent
                                  ? item['receiver_code']
                                  : item['sender_code'];

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Text(
                                  '🎁',
                                  style: TextStyle(fontSize: 27),
                                ),
                                title: Text(
                                  '${sent ? 'Sent to' : 'Received from'} ID $otherCode',
                                ),
                                subtitle: Text(
                                  '${item['gift_name']} × ${item['quantity']}'
                                  ' • ${item['created_at']}',
                                ),
                                trailing: Text(
                                  sent
                                      ? '-${item['coins_spent']} Coins'
                                      : '+${item['diamonds_credited']} Diamonds',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: sent ? Colors.orange : Colors.green,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gift Bag: $e')));
    }
  }

  Future<void> _showOwnerCoinPanel() async {
    final idController = TextEditingController();
    const amounts = <int>[1000, 2000, 5000, 10000, 100000, 1000000, 5000000];
    const labels = <int, String>{
      1000: '1,000',
      2000: '2,000',
      5000: '5,000',
      10000: '10,000',
      100000: '1 Lakh',
      1000000: '10 Lakh',
      5000000: '50 Lakh',
    };

    int selectedAmount = 1000;
    bool lookingUp = false;

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (sheetContext) => StatefulBuilder(
          builder: (sheetContext, setSheetState) => Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              22,
              20,
              MediaQuery.of(sheetContext).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Owner Wallet',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text('Enter the recipient User ID'),
                const SizedBox(height: 12),
                TextField(
                  controller: idController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'User ID',
                    hintText: 'e.g. 1001',
                    prefixIcon: const Icon(Icons.person_search_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Select Coins',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: amounts.map((amount) {
                    return ChoiceChip(
                      label: Text(labels[amount]!),
                      selected: selectedAmount == amount,
                      onSelected: (selected) {
                        if (selected) {
                          setSheetState(() => selectedAmount = amount);
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: lookingUp
                        ? null
                        : () async {
                            final code = idController.text.trim();
                            if (code.isEmpty || int.tryParse(code) == null) {
                              if (!sheetContext.mounted || !mounted) return;
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                const SnackBar(
                                  content: Text('Enter a valid User ID'),
                                ),
                              );
                              return;
                            }

                            setSheetState(() => lookingUp = true);
                            try {
                              final prefs =
                                  await SharedPreferences.getInstance();
                              final token = prefs.getString('lovely_token');
                              if (token == null || token.isEmpty) {
                                throw Exception(
                                  'Login required. Please sign in again.',
                                );
                              }

                              final response = await http
                                  .get(
                                    Uri.parse(
                                      '$lovelyApi/owner/coins/lookup/$code',
                                    ),
                                    headers: {'Authorization': 'Bearer $token'},
                                  )
                                  .timeout(const Duration(seconds: 20));

                              final decoded = jsonDecode(response.body);
                              if (response.statusCode != 200 ||
                                  decoded is! Map<String, dynamic> ||
                                  decoded['user'] is! Map) {
                                final detail = decoded is Map
                                    ? decoded['detail']?.toString()
                                    : null;
                                throw Exception(detail ?? 'User lookup failed');
                              }

                              final recipient = Map<String, dynamic>.from(
                                decoded['user'] as Map,
                              );
                              final recipientName =
                                  recipient['display_name']?.toString() ??
                                  'Lovely User';
                              final recipientCode =
                                  recipient['user_code']?.toString() ?? code;
                              final photo =
                                  recipient['profile_photo']?.toString() ?? '';

                              if (!mounted) return;
                              if (!sheetContext.mounted) return;
                              Navigator.of(sheetContext).pop();

                              bool issuing = false;
                              await showDialog<void>(
                                context: context,
                                barrierDismissible: false,
                                builder: (dialogContext) => StatefulBuilder(
                                  builder: (dialogContext, setDialogState) => AlertDialog(
                                    title: const Text('Confirm Coin Issue'),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircleAvatar(
                                          radius: 34,
                                          backgroundImage:
                                              photo.startsWith('http')
                                              ? NetworkImage(photo)
                                              : null,
                                          child: photo.startsWith('http')
                                              ? null
                                              : const Icon(
                                                  Icons.person,
                                                  size: 34,
                                                ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          recipientName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                        Text('User ID: $recipientCode'),
                                        const SizedBox(height: 14),
                                        Text(
                                          '${labels[selectedAmount]} Coins',
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF087FE8),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'Coins will be issued by the system. '
                                          'Your personal wallet will not be debited.',
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: issuing
                                            ? null
                                            : () =>
                                                  Navigator.of(dialogContext)
                                                      .pop(),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: issuing
                                            ? null
                                            : () async {
                                                setDialogState(
                                                  () => issuing = true,
                                                );
                                                try {
                                                  final prefs =
                                                      await SharedPreferences.getInstance();
                                                  final token = prefs.getString(
                                                    'lovely_token',
                                                  );
                                                  if (token == null ||
                                                      token.isEmpty) {
                                                    throw Exception(
                                                      'Login required',
                                                    );
                                                  }

                                                  final issueResponse = await http
                                                      .post(
                                                        Uri.parse(
                                                          '$lovelyApi/owner/coins/issue',
                                                        ),
                                                        headers: {
                                                          'Authorization':
                                                              'Bearer $token',
                                                          'Content-Type': 'application/json',
                                                        },
                                                        body: jsonEncode({
                                                          'user_code':
                                                              recipientCode,
                                                          'amount':
                                                              selectedAmount,
                                                        }),
                                                      )
                                                      .timeout(
                                                        const Duration(
                                                          seconds: 20,
                                                        ),
                                                      );

                                                  final result = jsonDecode(
                                                    issueResponse.body,
                                                  );
                                                  if (issueResponse
                                                              .statusCode !=
                                                          200 ||
                                                      result is! Map ||
                                                      result['success'] !=
                                                          true) {
                                                    final detail = result is Map
                                                        ? result['detail']
                                                              ?.toString()
                                                        : null;
                                                    throw Exception(
                                                      detail ??
                                                          'Coin issue failed',
                                                    );
                                                  }

                                                  final newBalance =
                                                      result['new_balance'];
                                                  if (!mounted) return;
                                                  if (!dialogContext.mounted) {
                                                    return;
                                                  }
                                                  Navigator.of(dialogContext)
                                                      .pop();
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        '${labels[selectedAmount]} Coins added to ID $recipientCode. '
                                                        'New balance: $newBalance',
                                                      ),
                                                      duration: const Duration(
                                                        seconds: 4,
                                                      ),
                                                    ),
                                                  );
                                                } catch (e) {
                                                  setDialogState(
                                                    () => issuing = false,
                                                  );
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            e.toString(),
                                                          ),
                                                        ),
                                                      );
                                                }
                                              },
                                        child: issuing
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : const Text('Confirm & Issue'),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            } catch (e) {
                              if (!sheetContext.mounted) return;
                              setSheetState(() => lookingUp = false);
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                            }
                          },
                    child: lookingUp
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Continue'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      idController.dispose();
    }
  }

  Future<void> _checkCloudDatabase() async {
    if (databaseChecking) return;
    setState(() => databaseChecking = true);
    String message;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('lovely_token');
      if (token == null || token.isEmpty) {
        message = 'Login required. Please sign in again.';
      } else {
        final response = await http
            .get(
              Uri.parse('$lovelyApi/owner/database-diagnostic'),
              headers: {'Authorization': 'Bearer $token'},
            )
            .timeout(const Duration(seconds: 20));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is Map) {
            final roomDetails = data['room_details'];
            final roomText = roomDetails is List && roomDetails.isNotEmpty
                ? roomDetails
                      .map(
                        (room) =>
                            'ID: ${room['id']} | Owner: ${room['owner_code']}\n'
                            'Name: ${room['name']} | Active: ${room['is_active']}',
                      )
                      .join('\n\n')
                : 'No room details returned.';

            message =
                'Database file exists: ${data['database_file_exists']}\n'
                'Database readable: ${data['database_readable']}\n'
                'Database size: ${data['database_size_bytes']} bytes\n'
                'Users: ${data['users_count']}\n'
                'Voice rooms: ${data['voice_rooms_count']}\n\n'
                'ROOM DETAILS:\n$roomText\n\n'
                '${data['note'] ?? ''}';
          } else {
            message = 'Unexpected diagnostic response.';
          }
        } else {
          message =
              'Cloud check failed (${response.statusCode}): ${response.body}';
        }
      }
    } catch (e) {
      message = 'Cloud database check error: $e';
    }
    if (!mounted) return;
    setState(() => databaseChecking = false);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Lovely Sky Cloud Database'),
        content: SingleChildScrollView(child: Text(message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    void comingSoon(String name) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$name coming soon')));
    }

    Widget actionButton({
      required IconData icon,
      required String label,
      required Color color,
      VoidCallback? onTap,
      bool isNew = false,
    }) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 49,
                    height: 49,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color, color.withOpacity(0.72)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.24),
                          blurRadius: 9,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 29),
                  ),
                  if (isNew)
                    const Positioned(
                      right: -10,
                      top: -9,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0xFF13B96B),
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          child: Text(
                            'New',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.2,
                  color: Color(0xFF292238),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget walletItem({
      required IconData icon,
      required String title,
      required String value,
      required Color color,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 5),
            child: Row(
              children: [
                Icon(icon, color: color, size: 35),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF77768B),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF25152F),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.black54,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE0F4FF), Color(0xFFBDE5FF), Color(0xFFEAF7FF)],
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 28),
          children: [
            // Purple profile card
            Container(
              padding: const EdgeInsets.fromLTRB(19, 22, 19, 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF410078),
                    Color(0xFF7900D9),
                    Color(0xFF31005D),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(27),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6300A8).withOpacity(0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFFFD77A),
                            width: 2.5,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 43,
                          backgroundColor: Colors.white,
                          backgroundImage: profilePhoto.isNotEmpty
                              ? NetworkImage(profilePhoto)
                              : null,
                          child: profilePhoto.isEmpty
                              ? const Icon(
                                  Icons.person,
                                  size: 45,
                                  color: Color(0xFF7435A9),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Row(
                              children: [
                                Icon(
                                  Icons.diamond,
                                  color: Color(0xFF7DE5FF),
                                  size: 28,
                                ),
                                SizedBox(width: 13),
                                Icon(
                                  Icons.female,
                                  color: Color(0xFFFF8ACB),
                                  size: 25,
                                ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            GestureDetector(
                              onTap: () {
                                if (userCode.isNotEmpty) {
                                  Clipboard.setData(
                                    ClipboardData(text: userCode),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('User ID copied'),
                                    ),
                                  );
                                }
                              },
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      profileLoading
                                          ? 'ID: Loading...'
                                          : 'ID: ${userCode.isEmpty ? 'Not available' : userCode}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  const Icon(
                                    Icons.copy,
                                    color: Colors.white,
                                    size: 17,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: Colors.white,
                        size: 30,
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      StatItem(value: '0', label: 'Friend'),
                      StatItem(value: '0', label: 'Fans'),
                      StatItem(value: '0', label: 'Follow'),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 13),

            // Wallet and benefits
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(19),
              ),
              child: Row(
                children: [
                  walletItem(
                    icon: Icons.account_balance_wallet,
                    title: 'My Wallet',
                    value: 'View balance',
                    color: const Color(0xFFFFB900),
                    onTap: _openWallet,
                  ),
                  Container(width: 1, height: 42, color: Colors.black12),
                  walletItem(
                    icon: Icons.diamond,
                    title: 'My Benefits',
                    value: 'View benefits',
                    color: const Color(0xFFDA28E9),
                    onTap: () => comingSoon('My Benefits'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 15),

            // VIP banner
            InkWell(
              onTap: () => comingSoon('VIP privileges'),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                height: 69,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF8500FF),
                      Color(0xFFCB00DC),
                      Color(0xFFFF19BB),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.workspace_premium,
                      color: Color(0xFFFFE36B),
                      size: 43,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Gimme VIP',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'View exclusive privileges',
                        maxLines: 2,
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.white, size: 27),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Main profile buttons
            Container(
              padding: const EdgeInsets.fromLTRB(8, 7, 8, 9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 0.83,
                children: [
                  actionButton(
                    icon: Icons.workspace_premium,
                    label: 'Badge',
                    color: const Color(0xFFFF168E),
                    onTap: () => comingSoon('Badge'),
                  ),
                  actionButton(
                    icon: Icons.shopping_bag,
                    label: 'Mall',
                    color: const Color(0xFF268CF4),
                    onTap: () => comingSoon('Mall'),
                  ),
                  actionButton(
                    icon: Icons.favorite,
                    label: 'My invitation',
                    color: const Color(0xFFB500E8),
                    isNew: true,
                    onTap: () => comingSoon('My invitation'),
                  ),
                  actionButton(
                    icon: Icons.chat_bubble,
                    label: 'Chat price',
                    color: const Color(0xFF00C99A),
                    onTap: () => comingSoon('Chat price'),
                  ),
                  actionButton(
                    icon: Icons.star,
                    label: 'My level',
                    color: const Color(0xFFFF8B22),
                    onTap: () => comingSoon('My level'),
                  ),
                  actionButton(
                    icon: Icons.groups,
                    label: 'Agency',
                    color: const Color(0xFFFF6738),
                    onTap: () => comingSoon('Agency'),
                  ),
                  actionButton(
                    icon: Icons.bookmark,
                    label: 'Points Center',
                    color: const Color(0xFF00B88A),
                    onTap: () => comingSoon('Points Center'),
                  ),
                  actionButton(
                    icon: Icons.badge,
                    label: 'Pretty ID',
                    color: const Color(0xFF9500D9),
                    onTap: () => comingSoon('Pretty ID'),
                  ),
                  actionButton(
                    icon: Icons.favorite,
                    label: 'CP List',
                    color: const Color(0xFFEC00A9),
                    onTap: () => comingSoon('CP List'),
                  ),
                  actionButton(
                    icon: Icons.stars,
                    label: 'Daily tasks',
                    color: const Color(0xFF493BEE),
                    onTap: () => comingSoon('Daily tasks'),
                  ),
                  actionButton(
                    icon: Icons.receipt_long,
                    label: 'Material Records',
                    color: const Color(0xFFFF922E),
                    onTap: () => comingSoon('Material Records'),
                  ),
                  actionButton(
                    icon: Icons.card_giftcard,
                    label: 'Gift Store',
                    color: const Color(0xFFE000B9),
                    onTap: _openGiftStore,
                  ),
                  actionButton(
                    icon: Icons.card_giftcard_rounded,
                    label: 'Gift Bag',
                    color: const Color(0xFF7C42E8),
                    onTap: _openGiftBag,
                  ),
                  actionButton(
                    icon: Icons.account_balance_wallet,
                    label: 'Wallet',
                    color: const Color(0xFFFFB51B),
                    onTap: _openWallet,
                  ),
                  actionButton(
                    icon: Icons.emoji_events,
                    label: 'Rewards',
                    color: const Color(0xFF00AFCB),
                    onTap: () => comingSoon('Rewards'),
                  ),
                  actionButton(
                    icon: Icons.backpack,
                    label: 'Backpack',
                    color: const Color(0xFF22A6B9),
                    onTap: () => comingSoon('Backpack'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 17),

            // Feedback and settings
            Container(
              padding: const EdgeInsets.fromLTRB(8, 9, 8, 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: actionButton(
                      icon: Icons.help_outline,
                      label: 'Feedback',
                      color: const Color(0xFFEC4BB8),
                      onTap: () => comingSoon('Feedback'),
                    ),
                  ),
                  Expanded(
                    child: actionButton(
                      icon: Icons.settings,
                      label: 'Setting',
                      color: const Color(0xFF7652C9),
                      onTap: () => comingSoon('Settings'),
                    ),
                  ),
                  const Expanded(child: SizedBox()),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ),

            if (userCode == '1') ...[
              const SizedBox(height: 18),
              sectionTitle('Administration'),
              Card(
                color: Colors.white,
                child: ListTile(
                  leading: const Icon(
                    Icons.account_balance_wallet,
                    color: blue,
                  ),
                  title: const Text('Owner Wallet'),
                  subtitle: const Text('Issue coins to a user ID'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showOwnerCoinPanel,
                ),
              ),
              Card(
                color: Colors.white,
                child: ListTile(
                  leading: const Icon(Icons.storage, color: blue),
                  title: const Text('Cloud Database Check'),
                  subtitle: const Text('Owner-only server diagnostic'),
                  trailing: databaseChecking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: databaseChecking ? null : _checkCloudDatabase,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class StatItem extends StatelessWidget {
  final String value, label;
  const StatItem({super.key, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 21,
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
      ],
    );
  }
}

class MenuTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback? onTap;

  const MenuTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE4F3FF)),
          ),
          child: Row(
            children: [
              Icon(icon, color: blue, size: 25),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.blueGrey.shade400,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VoiceRoomScreen extends StatefulWidget {
  final Map<String, dynamic> room;

  const VoiceRoomScreen({super.key, required this.room});

  @override
  State<VoiceRoomScreen> createState() => _VoiceRoomScreenState();
}

class _RoomMemberBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _RoomMemberBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x665D3B91),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFB98BE8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFFFFD477), size: 12),
          const SizedBox(width: 3),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 9)),
        ],
      ),
    );
  }
}

class _AnimatedRoseGiftButton extends StatefulWidget {
  final VoidCallback onTap;
  const _AnimatedRoseGiftButton({required this.onTap});

  @override
  State<_AnimatedRoseGiftButton> createState() =>
      _AnimatedRoseGiftButtonState();
}

class _AnimatedRoseGiftButtonState extends State<_AnimatedRoseGiftButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Gift',
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value;
            return Transform.scale(
              scale: 0.96 + (t * 0.09),
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFFD5E5),
                      Color(0xFFFF4380),
                      Color(0xFF9D1455),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: const Color(0xFFFFE39A), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF347D)
                          .withValues(alpha: 0.35 + t * 0.3),
                      blurRadius: 9 + t * 7,
                      spreadRadius: 1,
                    ),
                    const BoxShadow(
                      color: Color(0x883A1030),
                      offset: Offset(0, 4),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Center(
                  child: CustomPaint(
                    size: const Size(34, 34),
                    painter: _RoseFacePainter(openAmount: t),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RoseFacePainter extends CustomPainter {
  final double openAmount;
  _RoseFacePainter({required this.openAmount});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2);

    final outer = [
      const Color(0xFFFF8AA8),
      const Color(0xFFFF315F),
      const Color(0xFFE90048),
      const Color(0xFFFF5578),
    ];

    for (int i = 0; i < 10; i++) {
      canvas.save();
      canvas.rotate(i * 3.1415926535 / 5);
      final paint = Paint()
        ..color = outer[i % outer.length]
        ..style = PaintingStyle.fill;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, -7.5 - openAmount * 1.5),
          width: 12 + openAmount * 2,
          height: 17 + openAmount * 3,
        ),
        paint,
      );
      canvas.restore();
    }

    for (int i = 0; i < 7; i++) {
      canvas.save();
      canvas.rotate(i * 3.1415926535 / 3.5);
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, -4), width: 8, height: 12),
        Paint()
          ..color = i.isEven
              ? const Color(0xFFFFA0B5)
              : const Color(0xFFDC174B),
      );
      canvas.restore();
    }

    canvas.drawCircle(
      Offset.zero,
      3.8,
      Paint()..color = const Color(0xFFFFD36A),
    );
    canvas.drawCircle(
      Offset.zero,
      1.7,
      Paint()..color = const Color(0xFFFFF1B0),
    );
  }

  @override
  bool shouldRepaint(covariant _RoseFacePainter oldDelegate) =>
      oldDelegate.openAmount != openAmount;
}

class _AnimatedGamepadButton extends StatefulWidget {
  final VoidCallback onTap;

  const _AnimatedGamepadButton({required this.onTap});

  @override
  State<_AnimatedGamepadButton> createState() => _AnimatedGamepadButtonState();
}

class _AnimatedGamepadButtonState extends State<_AnimatedGamepadButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_controller.value);
          return Transform.scale(
            scale: 0.98 + (t * 0.045),
            child: Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF24547D), Color(0xFF061B35)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: const Color(0xFFFFD83D), width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD21F)
                        .withValues(alpha: 0.22 + (t * 0.25)),
                    blurRadius: 12 + (t * 8),
                    spreadRadius: 1 + (t * 2),
                  ),
                  const BoxShadow(
                    color: Color(0xCC020B19),
                    blurRadius: 0,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.sports_esports_rounded,
                  color: Color(0xFFFFD83D),
                  size: 35,
                  shadows: [Shadow(color: Color(0xFFFFE98A), blurRadius: 9)],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AnimatedRoomToolbarButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _AnimatedRoomToolbarButton({required this.icon, required this.onTap});

  @override
  State<_AnimatedRoomToolbarButton> createState() =>
      _AnimatedRoomToolbarButtonState();
}

class _AnimatedRoomToolbarButtonState extends State<_AnimatedRoomToolbarButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_controller.value);
          return Transform.scale(
            scale: 0.98 + (t * 0.04),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF24547D), Color(0xFF061B35)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: const Color(0xFFFFD83D), width: 1.8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD21F)
                        .withValues(alpha: 0.20 + (t * 0.22)),
                    blurRadius: 8 + (t * 5),
                    spreadRadius: 1 + t,
                  ),
                  const BoxShadow(
                    color: Color(0xCC020B19),
                    blurRadius: 0,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  widget.icon,
                  color: const Color(0xFFFFD83D),
                  size: 24,
                  shadows: const [
                    Shadow(color: Color(0xFFFFE98A), blurRadius: 7),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AnimatedRoomActionButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;
  final double size;

  const _AnimatedRoomActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color = const Color(0xFF8DE4FF),
    this.size = 23,
  });

  @override
  State<_AnimatedRoomActionButton> createState() =>
      _AnimatedRoomActionButtonState();
}

class _AnimatedRoomActionButtonState extends State<_AnimatedRoomActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = Curves.easeInOut.transform(_controller.value);
            return Transform.translate(
              offset: Offset(0, -1.2 * t),
              child: Transform.scale(
                scale: 0.97 + (t * 0.05),
                child: Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF397BA9),
                        Color(0xFF153C64),
                        Color(0xFF06182E),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: widget.color.withValues(alpha: 0.85),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withValues(
                          alpha: 0.16 + (t * 0.24),
                        ),
                        blurRadius: 7 + (t * 6),
                        spreadRadius: 0.5 + t,
                      ),
                      const BoxShadow(
                        color: Color(0xCC020B19),
                        blurRadius: 0,
                        offset: Offset(0, 3),
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.16),
                        blurRadius: 3,
                        offset: const Offset(-1, -1),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      widget.icon,
                      color: widget.color,
                      size: widget.size,
                      shadows: [
                        Shadow(
                          color: widget.color.withValues(alpha: 0.8),
                          blurRadius: 7,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _VoiceRoomScreenState extends State<VoiceRoomScreen> {
  final TextEditingController messageController = TextEditingController();
  final List<Map<String, dynamic>> messages = [];

  bool micOn = true;
  bool moderationMuted = false;
  String roomRole = 'member';
  bool speakerOn = true;
  bool roomLiked = false;
  bool showSendingReport = false;
  bool showExitOptions = false;
  int sendingReportTab = 0;
  bool showGiftTab = false;
  List<Map<String, dynamic>> seats = [];
  bool seatsLoading = true;
  bool seatRequestInProgress = false;
  Timer? seatRefreshTimer;
  bool inviteDialogShowing = false;
  MediaStream? localAudioStream;
  WebSocket? signalSocket;
  final Map<String, RTCPeerConnection> peerConnections = {};
  final Map<String, List<RTCIceCandidate>> pendingCandidates = {};
  final Set<String> remoteDescriptionReady = {};
  final Map<String, bool> remoteMicStatus = {};
  Map<String, dynamic>? activeGiftEvent;
  Timer? giftOverlayTimer;
  int giftComboCount = 1;
  String? lastGiftComboKey;
  DateTime? lastGiftEventAt;

  static const Color pink = Color(0xFFFF4FA3);
  static const Color background = Color(0xFFE5F6FF);

  @override
  void initState() {
    super.initState();
    unawaited(_startVoice());
    _loadSeats();
    _loadMessages();
    seatRefreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _loadSeats();
      _loadMessages();
      _checkPendingInvites();
    });
  }

  Future<void> _startVoice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('lovely_token');

      if (token == null || token.isEmpty) {
        if (mounted) showMessage('Voice: login token nahi mila.');
        return;
      }

      localAudioStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });

      for (final track in localAudioStream!.getAudioTracks()) {
        track.enabled = micOn;
      }

      await Helper.setSpeakerphoneOn(speakerOn);

      final roomId = widget.room['id'];
      final socket = await WebSocket.connect(
        'wss://lovelysky.fastapicloud.dev/voice/rooms/$roomId/signal',
      ).timeout(const Duration(seconds: 15));

      signalSocket = socket;
      socket.listen(
        (event) => unawaited(_handleVoiceSignal(event)),
        onError: (Object error) {
          debugPrint('Voice socket error: $error');
          if (mounted) showMessage('Voice connection mein error aya.');
        },
        onDone: () {
          if (mounted) showMessage('Voice connection band ho gaya.');
        },
        cancelOnError: false,
      );

      socket.add(jsonEncode({'token': token}));
      socket.add(jsonEncode({'type': 'mic_status', 'payload': micOn}));

      if (mounted) {
        showMessage('Microphone ready; room se connect ho raha hai.');
      }
    } catch (e) {
      debugPrint('Voice startup failed: $e');
      if (mounted) {
        showMessage(
          'Voice start nahi hui. Mic permission aur server check karo.',
        );
      }
    }
  }

  void _sendVoiceSignal(
    String type,
    String targetUid,
    Map<String, dynamic> payload,
  ) {
    final socket = signalSocket;
    if (socket == null || socket.readyState != WebSocket.open) return;

    socket.add(
      jsonEncode({'type': type, 'target_uid': targetUid, 'payload': payload}),
    );
  }

  Future<RTCPeerConnection> _ensureVoicePeer(String uid) async {
    final existing = peerConnections[uid];
    if (existing != null) return existing;

    final pc = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    });

    peerConnections[uid] = pc;

    final stream = localAudioStream;
    if (stream != null) {
      for (final track in stream.getAudioTracks()) {
        await pc.addTrack(track, stream);
      }
    }

    pc.onIceCandidate = (candidate) {
      if (candidate.candidate == null) return;
      _sendVoiceSignal('candidate', uid, {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    return pc;
  }

  Future<void> _createVoiceOffer(String uid) async {
    try {
      final pc = await _ensureVoicePeer(uid);
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);

      _sendVoiceSignal('offer', uid, {'sdp': offer.sdp, 'type': offer.type});
    } catch (e) {
      debugPrint('Voice offer failed: $e');
    }
  }

  Future<void> _flushVoiceCandidates(String uid) async {
    final pc = peerConnections[uid];
    if (pc == null) return;

    final queued = pendingCandidates.remove(uid) ?? [];
    for (final candidate in queued) {
      await pc.addCandidate(candidate);
    }
  }

  void _showRoomGiftEvent(Map<String, dynamic> gift) {
    if (!mounted) return;

    final sender = (gift['sender_name'] ?? 'Member').toString();
    final giftName = (gift['gift_name'] ?? 'Gift').toString();
    final emoji = (gift['emoji'] ?? '🎁').toString();
    final quantity = int.tryParse('${gift['quantity'] ?? 1}') ?? 1;
    final receivers = (gift['receiver_codes'] as List? ?? [])
        .map((value) => value.toString())
        .toList();

    final comboKey =
        '${gift['sender_code']}: ${gift['gift_code']}:'
        '${receivers.join(',')}';
    final now = DateTime.now();

    if (lastGiftComboKey == comboKey &&
        lastGiftEventAt != null &&
        now.difference(lastGiftEventAt!).inSeconds <= 5) {
      giftComboCount++;
    } else {
      giftComboCount = 1;
    }
    lastGiftComboKey = comboKey;
    lastGiftEventAt = now;

    final receiverText = receivers.isEmpty
        ? 'room members'
        : receivers.map((code) => 'ID $code').join(', ');

    setState(() {
      activeGiftEvent = {
        ...gift,
        'sender_name': sender,
        'gift_name': giftName,
        'emoji': emoji,
        'quantity': quantity,
        'receiver_text': receiverText,
        'combo': giftComboCount,
      };
      messages.insert(0, {
        'text': '$sender sent $quantity x $giftName to $receiverText',
        'time':
            '${now.hour.toString().padLeft(2, '0')}:'
            '${now.minute.toString().padLeft(2, '0')}',
      });
      if (messages.length > 100) messages.removeLast();
    });

    giftOverlayTimer?.cancel();
    giftOverlayTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => activeGiftEvent = null);
      }
    });
  }

  Future<void> _handleVoiceSignal(dynamic event) async {
    try {
      final decoded = jsonDecode(event is String ? event : event.toString());
      if (decoded is! Map) return;

      final data = Map<String, dynamic>.from(decoded);
      final type = data['type'];

      if (type == 'gift_event') {
        final payload = data['payload'];
        if (payload is Map) {
          _showRoomGiftEvent(Map<String, dynamic>.from(payload));
        }
        return;
      }

      final senderUid = data['sender_uid']?.toString();

      if (type == 'existing_peers') {
        final payload = data['payload'];
        if (payload is Map) {
          final peers = payload['peers'];
          if (peers is List) {
            for (final item in peers) {
              if (item is Map && item['uid'] != null) {
                await _createVoiceOffer(item['uid'].toString());
              }
            }
          }
        }
        return;
      }

      if (senderUid == null || senderUid.isEmpty) return;

      if (type == 'peer_joined') {
        await _ensureVoicePeer(senderUid);
        return;
      }

      if (type == 'peer_left') {
        final pc = peerConnections.remove(senderUid);
        if (pc != null) await pc.close();
        pendingCandidates.remove(senderUid);
        remoteDescriptionReady.remove(senderUid);
        return;
      }

      if (type == 'moderation_mic') {
        final requestedMicOn = data['payload'];
        if (requestedMicOn is! bool) return;

        moderationMuted = !requestedMicOn;
        micOn = requestedMicOn;

        for (final track
            in localAudioStream?.getAudioTracks() ?? <MediaStreamTrack>[]) {
          track.enabled = requestedMicOn;
        }

        if (mounted) setState(() {});
        final socket = signalSocket;
        if (socket != null && socket.readyState == WebSocket.open) {
          socket.add(
            jsonEncode({'type': 'mic_status', 'payload': requestedMicOn}),
          );
        }

        showMessage(
          requestedMicOn
              ? 'Room owner/admin turned your mic on'
              : 'Your mic was muted by room owner/admin',
        );
        return;
      }

      if (type == 'mic_status') {
        final senderCode = data['sender_code']?.toString();
        final payload = data['payload'];
        if (senderCode == null || senderCode.isEmpty || payload is! bool) {
          return;
        }
        if (mounted) {
          setState(() => remoteMicStatus[senderCode] = payload);
        }
        return;
      }
      final pc = await _ensureVoicePeer(senderUid);
      final rawPayload = data['payload'];
      if (rawPayload is! Map) return;
      final payload = Map<String, dynamic>.from(rawPayload);

      if (type == 'offer') {
        await pc.setRemoteDescription(
          RTCSessionDescription(
            payload['sdp']?.toString(),
            payload['type']?.toString(),
          ),
        );

        remoteDescriptionReady.add(senderUid);
        await _flushVoiceCandidates(senderUid);

        final answer = await pc.createAnswer();
        await pc.setLocalDescription(answer);

        _sendVoiceSignal('answer', senderUid, {
          'sdp': answer.sdp,
          'type': answer.type,
        });
      } else if (type == 'answer') {
        await pc.setRemoteDescription(
          RTCSessionDescription(
            payload['sdp']?.toString(),
            payload['type']?.toString(),
          ),
        );

        remoteDescriptionReady.add(senderUid);
        await _flushVoiceCandidates(senderUid);
      } else if (type == 'candidate') {
        final value = payload['candidate'];
        if (value == null) return;

        final index = payload['sdpMLineIndex'];
        final candidate = RTCIceCandidate(
          value.toString(),
          payload['sdpMid']?.toString(),
          index is num ? index.toInt() : null,
        );

        if (remoteDescriptionReady.contains(senderUid)) {
          await pc.addCandidate(candidate);
        } else {
          pendingCandidates.putIfAbsent(senderUid, () => []).add(candidate);
        }
      }
    } catch (e) {
      debugPrint('Voice signaling message failed: $e');
    }
  }

  void _toggleMic() {
    if (moderationMuted) {
      showMessage('Your mic is muted by room owner/admin');
      return;
    }

    setState(() => micOn = !micOn);

    for (final track
        in localAudioStream?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = micOn;
    }

    final socket = signalSocket;
    if (socket != null && socket.readyState == WebSocket.open) {
      socket.add(jsonEncode({'type': 'mic_status', 'payload': micOn}));
    }
    showMessage(micOn ? 'Mic On' : 'Mic Off');
  }

  Future<void> _moderateMemberMic(String targetUid, bool turnMicOn) async {
    if (roomRole != 'owner' && roomRole != 'admin') {
      showMessage('Sirf room owner/admin mic control kar sakte hain.');
      return;
    }

    if (targetUid.isEmpty) {
      showMessage('Member ki ID nahi mili.');
      return;
    }

    final socket = signalSocket;
    if (socket == null || socket.readyState != WebSocket.open) {
      showMessage('Voice connection abhi available nahi hai.');
      return;
    }

    socket.add(
      jsonEncode({
        'type': 'moderator_mute',
        'target_uid': targetUid,
        'payload': turnMicOn,
      }),
    );
  }

  void _toggleSpeaker() {
    setState(() => speakerOn = !speakerOn);
    unawaited(Helper.setSpeakerphoneOn(speakerOn));
    showMessage(speakerOn ? 'Speaker On' : 'Speaker Off');
  }

  Future<void> _stopVoice() async {
    final socket = signalSocket;
    signalSocket = null;

    try {
      await socket?.close();
    } catch (_) {}

    for (final pc in peerConnections.values.toList()) {
      try {
        await pc.close();
      } catch (_) {}
    }

    peerConnections.clear();
    pendingCandidates.clear();
    remoteDescriptionReady.clear();

    final stream = localAudioStream;
    localAudioStream = null;

    if (stream != null) {
      for (final track in stream.getTracks()) {
        try {
          await track.stop();
        } catch (_) {}
      }

      try {
        await stream.dispose();
      } catch (_) {}
    }
  }

  Future<void> _loadSeats() async {
    if (seatRequestInProgress) return;
    seatRequestInProgress = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('lovely_token');
      if (token == null || token.isEmpty) return;

      final response = await http
          .get(
            Uri.parse('$lovelyApi/voice/rooms/${widget.room['id']}/seats'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 12));

      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final loaded = List<Map<String, dynamic>>.from(
          (data['seats'] as List).map(
            (item) => Map<String, dynamic>.from(item as Map),
          ),
        );
        setState(() {
          seats = loaded;
          roomRole = (data['room_role'] ?? 'member').toString();
          seatsLoading = false;
        });
      } else {
        setState(() => seatsLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => seatsLoading = false);
    } finally {
      seatRequestInProgress = false;
    }
  }

  Future<void> _checkPendingInvites() async {
    if (!mounted || inviteDialogShowing) return;
    inviteDialogShowing = true;

    try {
      final headers = await _roomHeaders();
      if (headers == null) return;

      final response = await http
          .get(
            Uri.parse(
              '$lovelyApi/voice/rooms/${widget.room['id']}/invites/pending',
            ),
            headers: headers,
          )
          .timeout(const Duration(seconds: 12));

      if (!mounted || response.statusCode != 200) return;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final invites = List<Map<String, dynamic>>.from(
        (data['invites'] as List? ?? []).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      );

      if (invites.isEmpty || !mounted) return;

      final invite = invites.first;
      final inviteId = invite['id'];
      if (inviteId == null) return;

      final accepted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Seat Invitation'),
          content: Text(
            '${invite['inviter_name'] ?? 'Room Admin'} ne aap ko seat '
            '${invite['seat_number'] ?? ''} par invite kiya hai.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Reject'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Accept'),
            ),
          ],
        ),
      );

      if (!mounted || accepted == null) return;

      final result = await http
          .post(
            Uri.parse(
              '$lovelyApi/voice/rooms/${widget.room['id']}/invites/$inviteId/respond',
            ),
            headers: {...headers, 'Content-Type': 'application/json'},
            body: jsonEncode({'accepted': accepted}),
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (result.statusCode == 200) {
        showMessage(accepted ? 'Invitation accepted!' : 'Invitation rejected.');
        if (accepted) await _loadSeats();
      } else {
        showMessage('Invitation response failed (${result.statusCode}).');
      }
    } catch (e) {
      debugPrint('Pending invite error: $e');
    } finally {
      inviteDialogShowing = false;
    }
  }

  Future<Map<String, String>?> _roomHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('lovely_token');
    if (token == null || token.isEmpty) return null;
    return {'Authorization': 'Bearer $token'};
  }

  Future<bool> _roomPost(String path, {Map<String, dynamic>? body}) async {
    final headers = await _roomHeaders();
    if (headers == null) {
      showMessage('Please log in first.');
      return false;
    }
    try {
      final response = await http
          .post(
            Uri.parse('$lovelyApi$path'),
            headers: {
              ...headers,
              if (body != null) 'Content-Type': 'application/json',
            },
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) return true;
      showMessage('Action failed (${response.statusCode}): ${response.body}');
    } catch (e) {
      showMessage('Connection error: $e');
    }
    return false;
  }

  Future<void> _inviteRoomMember(int seatNumber) async {
    final headers = await _roomHeaders();
    if (headers == null) return;

    try {
      final response = await http
          .get(
            Uri.parse('$lovelyApi/voice/rooms/${widget.room['id']}/members'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        showMessage('Room members load nahi huay (${response.statusCode}).');
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final members =
          List<Map<String, dynamic>>.from(
                (data['members'] as List).map(
                  (item) => Map<String, dynamic>.from(item as Map),
                ),
              )
              .where(
                (m) =>
                    (m['user_uid'] ?? '').toString().isNotEmpty &&
                    m['is_mine'] != true &&
                    m['seat_number'] == null,
              )
              .toList();

      if (!mounted) return;
      if (members.isEmpty) {
        showMessage('Invite ke liye koi available joined member nahi.');
        return;
      }

      final selected = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        backgroundColor: background,
        builder: (ctx) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Select room member',
                  style: TextStyle(color: Colors.white, fontSize: 17),
                ),
              ),
              ...members.map(
                (m) => ListTile(
                  leading: const Icon(Icons.person, color: pink),
                  title: Text(
                    (m['display_name'] ?? 'Room member').toString(),
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    'ID: ${(m['user_code'] ?? '').toString()}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  onTap: () => Navigator.pop(ctx, m),
                ),
              ),
            ],
          ),
        ),
      );

      if (selected == null || !mounted) return;

      final uid = (selected['user_uid'] ?? '').toString();
      final ok = await _roomPost(
        '/voice/rooms/${widget.room['id']}/seats/$seatNumber/invite',
        body: {'user_uid': uid},
      );
      if (ok) showMessage('Seat invitation sent.');
    } catch (e) {
      if (mounted) showMessage('Members load error: $e');
    }
  }

  Future<void> _onSeatTap(int number) async {
    final seat = seats.firstWhere(
      (item) => item['seat_number'] == number,
      orElse: () => <String, dynamic>{},
    );

    if (seat['is_mine'] == true) {
      await _showRoomMemberActions(number);
      return;
    }

    if (seat['is_occupied'] != true) {
      await _showRoomMemberActions(number);
      return;
    }

    await _showRoomMemberCard(number, seat);
  }

  Future<void> _showRoomMemberCard(
    int number,
    Map<String, dynamic> member,
  ) async {
    if (!mounted) return;

    final name = (member['display_name'] ?? member['name'] ?? 'Room Member')
        .toString();
    final code = (member['user_code'] ?? '').toString();
    final photo = (member['profile_photo'] ?? '').toString();
    final isMine = member['is_mine'] == true;
    final canManage = roomRole == 'owner' || roomRole == 'admin';

    Widget avatar() {
      if (photo.startsWith('http://') || photo.startsWith('https://')) {
        return ClipOval(
          child: Image.network(
            photo,
            width: 86,
            height: 86,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                const Icon(Icons.person, size: 48, color: Colors.white),
          ),
        );
      }

      if (photo.startsWith('data:image') && photo.contains(',')) {
        try {
          return ClipOval(
            child: Image.memory(
              base64Decode(photo.substring(photo.indexOf(',') + 1)),
              width: 86,
              height: 86,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.person, size: 48, color: Colors.white),
            ),
          );
        } catch (_) {}
      }

      return const Icon(Icons.person, size: 48, color: Colors.white);
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 13, 18, 22),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF55218B), Color(0xFF17113F)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(27)),
            border: Border(
              top: BorderSide(color: Color(0xFFDDA8FF), width: 1.2),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white54,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 94,
                    height: 94,
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFFFF72C6), Color(0xFFFFD477)],
                      ),
                    ),
                    child: CircleAvatar(
                      backgroundColor: const Color(0xFF32145F),
                      child: avatar(),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'ID: $code',
                          style: const TextStyle(
                            color: Color(0xFFE5C9FF),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Wrap(
                          spacing: 5,
                          children: const [
                            _RoomMemberBadge(
                              icon: Icons.verified,
                              label: 'Member',
                            ),
                            _RoomMemberBadge(
                              icon: Icons.favorite,
                              label: 'Lovely',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 19),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF83C7), Color(0xFFFFC0DE)],
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.card_giftcard, color: Color(0xFF70245D)),
                    SizedBox(width: 9),
                    Text(
                      'Gifts & Member Collection',
                      style: TextStyle(
                        color: Color(0xFF70245D),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Spacer(),
                    Icon(Icons.favorite, color: Color(0xFF70245D)),
                  ],
                ),
              ),
              const SizedBox(height: 17),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        messageController.text = '@$code ';
                        messageController.selection = TextSelection.collapsed(
                          offset: messageController.text.length,
                        );
                      },
                      icon: const Icon(Icons.alternate_email),
                      label: const Text('@Ta'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFFB98BE8)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        openLovelyRoomGiftStore(
                          context,
                          roomId: widget.room['id'],
                        );
                      },
                      icon: const Icon(Icons.card_giftcard),
                      label: const Text('Gift'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF83C7),
                        foregroundColor: const Color(0xFF42134E),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                ],
              ),
              if (canManage && !isMine) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showRoomMemberActions(number);
                    },
                    icon: const Icon(Icons.admin_panel_settings),
                    label: const Text('Manage Member'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFDDA8FF)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
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

  Future<void> _showRoomMemberActions(int number) async {
    final seat = seats.firstWhere(
      (item) => item['seat_number'] == number,
      orElse: () => <String, dynamic>{},
    );

    final canManage = roomRole == 'owner' || roomRole == 'admin';
    final occupied = seat['is_occupied'] == true;
    final locked = seat['is_locked'] == true;

    if (seat['is_mine'] == true) {
      await _tapSeat(number);
      return;
    }

    if (occupied && !canManage) {
      showMessage('Yeh seat pehle se occupied hai.');
      return;
    }

    if (!canManage) {
      if (locked) {
        showMessage('Yeh seat lock hai.');
        return;
      }
      if (!mounted) return;
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: background,
        builder: (sheetContext) => SafeArea(
          child: ListTile(
            leading: const Icon(Icons.event_seat, color: pink),
            title: const Text(
              'Turn on Seat',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(sheetContext);
              _tapSeat(number);
            },
          ),
        ),
      );
      return;
    }

    final targetUid = (seat['user_uid'] ?? '').toString();
    final memberCode = (seat['user_code'] ?? '').toString();
    final isMuted = seat['is_muted'] == true;

    if (occupied && targetUid.isEmpty) {
      showMessage('Member ki ID nahi mili.');
      return;
    }

    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: background,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.event_seat, color: pink),
              title: Text(
                occupied
                    ? 'Seat $number · Member $memberCode'
                    : 'Seat $number · ${locked ? 'Locked' : 'Available'}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            if (!occupied && !locked)
              ListTile(
                leading: const Icon(Icons.event_seat, color: pink),
                title: const Text(
                  'Turn on Seat',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _tapSeat(number);
                },
              ),
            if (occupied) ...[
              ListTile(
                leading: Icon(isMuted ? Icons.mic : Icons.mic_off, color: pink),
                title: Text(
                  isMuted ? 'Unmute microphone' : 'Mute microphone',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _moderateMemberMic(targetUid, isMuted);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_remove, color: pink),
                title: const Text(
                  'Remove from seat',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final ok = await _roomPost(
                    '/voice/rooms/${widget.room['id']}/members/$targetUid/seat/remove',
                  );
                  if (ok) {
                    showMessage('Member removed from seat.');
                    await _loadSeats();
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.block, color: Colors.redAccent),
                title: const Text(
                  'Block from room',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final ok = await _roomPost(
                    '/voice/rooms/${widget.room['id']}/members/block',
                    body: {'user_uid': targetUid},
                  );
                  if (ok) {
                    showMessage('Member blocked from room.');
                    await _loadSeats();
                  }
                },
              ),
            ],
            ListTile(
              leading: Icon(locked ? Icons.lock_open : Icons.lock, color: pink),
              title: Text(
                locked ? 'Unlock seat' : 'Lock seat',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () async {
                Navigator.pop(sheetContext);
                final action = locked ? 'unlock' : 'lock';
                final ok = await _roomPost(
                  '/voice/rooms/${widget.room['id']}/seats/$number/$action',
                );
                if (ok) {
                  showMessage(locked ? 'Seat unlocked.' : 'Seat locked.');
                  await _loadSeats();
                }
              },
            ),
            if (!occupied)
              ListTile(
                leading: const Icon(Icons.mail_outline, color: pink),
                title: const Text(
                  'Invite member to this seat',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _inviteRoomMember(number);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _tapSeat(int number) async {
    final seat = seats.firstWhere(
      (item) => item['seat_number'] == number,
      orElse: () => <String, dynamic>{},
    );

    if (seat['is_mine'] == true) {
      await _leaveSeat();
      return;
    }
    if (seat['is_occupied'] == true) {
      showMessage('Yeh seat pehle se occupied hai.');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('lovely_token');
    if (token == null || token.isEmpty) {
      showMessage('Please log in first.');
      return;
    }

    try {
      final response = await http
          .post(
            Uri.parse(
              '$lovelyApi/voice/rooms/${widget.room['id']}/seats/$number/sit',
            ),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      if (response.statusCode == 200) {
        showMessage('Aap seat $number par baith gaye.');
      } else if (response.statusCode == 409) {
        showMessage('Yeh seat available nahi hai.');
      } else {
        showMessage('Seat book nahi hui (${response.statusCode}).');
      }
      await _loadSeats();
    } catch (_) {
      if (mounted) showMessage('Seat book karte waqt connection error aaya.');
    }
  }

  Future<void> _leaveSeat() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('lovely_token');
    if (token == null || token.isEmpty) return;

    try {
      final response = await http
          .post(
            Uri.parse(
              '$lovelyApi/voice/rooms/${widget.room['id']}/seats/leave',
            ),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      if (response.statusCode == 200) {
        showMessage('Aap seat se uth gaye.');
        await _loadSeats();
      } else {
        showMessage('Seat khali nahi hui.');
      }
    } catch (_) {
      if (mounted) showMessage('Connection error aaya.');
    }
  }

  Widget _buildSeat(int number, {bool large = false}) {
    final seat = seats.firstWhere(
      (item) => item['seat_number'] == number,
      orElse: () => <String, dynamic>{},
    );
    final occupied = seat['is_occupied'] == true;
    final mine = seat['is_mine'] == true;
    final locked = seat['is_locked'] == true;
    final photo = (seat['profile_photo'] ?? '').toString();
    final code = (seat['user_code'] ?? '').toString();
    final remoteMic = remoteMicStatus[code] ?? true;
    final activeMic = occupied && (mine ? micOn : remoteMic);
    final size = large ? 76.0 : 60.0;
    final avatarSize = large ? 58.0 : 45.0;

    Widget avatar = const Icon(Icons.person_rounded, color: Colors.white70);
    if (photo.startsWith('http://') || photo.startsWith('https://')) {
      avatar = Image.network(
        photo,
        width: avatarSize,
        height: avatarSize,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            const Icon(Icons.person_rounded, color: Colors.white70),
      );
    } else if (photo.startsWith('data:image') && photo.contains(',')) {
      try {
        avatar = Image.memory(
          base64Decode(photo.substring(photo.indexOf(',') + 1)),
          width: avatarSize,
          height: avatarSize,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              const Icon(Icons.person_rounded, color: Colors.white70),
        );
      } catch (_) {}
    }

    return InkWell(
      onTap: () => _onSeatTap(number),
      borderRadius: BorderRadius.circular(50),
      child: SizedBox(
        width: size + 8,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: activeMic
                      ? const [Color(0xFF8DEBFF), Color(0xFF168DDB)]
                      : const [Color(0xFFB7DDFB), Color(0xFF547FAE)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: activeMic
                        ? const Color(0xFF35CFFF).withValues(alpha: 0.55)
                        : const Color(0xFF6CA8E8).withValues(alpha: 0.18),
                    blurRadius: activeMic ? 17 : 7,
                    spreadRadius: activeMic ? 3 : 1,
                  ),
                ],
              ),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF173B5C),
                ),
                padding: const EdgeInsets.all(2),
                child: ClipOval(
                  child: occupied
                      ? avatar
                      : locked
                      ? const Icon(
                          Icons.lock_rounded,
                          color: Colors.white70,
                          size: 21,
                        )
                      : Icon(
                          Icons.person_add_alt_1_rounded,
                          color: Colors.white.withValues(alpha: 0.65),
                          size: large ? 27 : 22,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              occupied ? (mine ? 'You' : code) : '$number',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: occupied ? Colors.white : Colors.white60,
                fontSize: large ? 10 : 9,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (occupied)
              Icon(
                activeMic ? Icons.graphic_eq_rounded : Icons.mic_off_rounded,
                color: activeMic ? const Color(0xFF70E5FF) : Colors.white54,
                size: 13,
              ),
          ],
        ),
      ),
    );
  }

  void showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _loadMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('lovely_token');
      if (token == null || token.isEmpty) return;
      final response = await http
          .get(
            Uri.parse('$lovelyApi/voice/rooms/${widget.room['id']}/messages'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 12));
      if (!mounted || response.statusCode != 200) return;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final rows = (data['messages'] as List<dynamic>? ?? []).map((item) {
        final row = Map<String, dynamic>.from(item as Map);
        return <String, dynamic>{
          'id': row['id'],
          'text': '${row['sender_code'] ?? ''}: ${row['message'] ?? ''}',
          'time': '${row['created_at'] ?? ''}',
        };
      }).toList();
      if (!mounted) return;
      setState(() {
        messages
          ..clear()
          ..addAll(rows);
      });
    } catch (_) {}
  }

  Future<void> sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('lovely_token');
    if (token == null || token.isEmpty) {
      showMessage('Please log in first.');
      return;
    }
    messageController.clear();
    try {
      final response = await http
          .post(
            Uri.parse('$lovelyApi/voice/rooms/${widget.room['id']}/messages'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'message': text}),
          )
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (response.statusCode == 200) {
        await _loadMessages();
      } else {
        messageController.text = text;
        showMessage(
          'Message send nahi hua (${response.statusCode}). Room join check karein.',
        );
      }
    } catch (_) {
      if (!mounted) return;
      messageController.text = text;
      showMessage('Chat connection error. Dobara send karein.');
    }
  }

  Future<void> _leaveRoom() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('lovely_token');

    if (token == null || token.isEmpty) {
      showMessage('Please log in first.');
      return;
    }

    try {
      final roomId = widget.room['id'];
      final response = await http
          .post(
            Uri.parse('$lovelyApi/voice/rooms/$roomId/leave'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        Navigator.of(context).pop();
      } else {
        showMessage('Room leave nahi hua (${response.statusCode}).');
      }
    } catch (_) {
      if (!mounted) return;
      showMessage('Room leave karte waqt connection error aaya.');
    }
  }

  @override
  void dispose() {
    seatRefreshTimer?.cancel();
    giftOverlayTimer?.cancel();
    unawaited(_stopVoice());
    messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.room['name'] ?? 'Voice Room').toString();
    final roomId = (widget.room['id'] ?? '').toString();
    final ownerPhoto =
        (widget.room['owner_photo'] ?? widget.room['profile_photo'] ?? '')
            .toString();
    final occupiedSeats = seats.where((e) => e['is_occupied'] == true).toList();
    final isOwner = roomRole == 'owner';

    Widget circleAction(
      IconData icon,
      String tip,
      VoidCallback action, {
      Color color = const Color(0xFF8DE4FF),
      double size = 23,
    }) {
      return _AnimatedRoomActionButton(
        icon: icon,
        tooltip: tip,
        onTap: action,
        color: color,
        size: size,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFE5F6FF),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 5, 5, 7),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => showMessage('Room owner profile'),
                        child: CircleAvatar(
                          radius: 23,
                          backgroundColor: const Color(0xFF287CB7),
                          backgroundImage: ownerPhoto.startsWith('http')
                              ? NetworkImage(ownerPhoto)
                              : null,
                          child: ownerPhoto.startsWith('http')
                              ? null
                              : const Icon(
                                  Icons.person,
                                  color: const Color(0xFF123B5A),
                                ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: const Color(0xFF123B5A),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Room ID: $roomId',
                              style: const TextStyle(
                                color: Color(0xFF9DDCFF),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isOwner)
                        circleAction(
                          Icons.settings_rounded,
                          'Room settings',
                          () => showMessage(
                            'Room settings baad mein connect honge.',
                          ),
                        ),
                      circleAction(
                        Icons.minimize_rounded,
                        'Minimize',
                        () => showMessage(
                          'Minimize/background audio abhi connect nahi hai.',
                        ),
                      ),
                      circleAction(
                        Icons.close_rounded,
                        'Exit room',
                        _leaveRoom,
                        color: const Color(0xFFFF8D9B),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.emoji_events_rounded,
                        color: Color(0xFFFFC84D),
                        size: 21,
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'Room',
                        style: TextStyle(
                          color: Color(0xFF123B5A),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.local_fire_department_rounded,
                        color: Color(0xFFFF7043),
                        size: 20,
                      ),
                      Text(
                        '${occupiedSeats.length}',
                        style: const TextStyle(
                          color: Color(0xFF123B5A),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 7),
                      SizedBox(
                        height: 38,
                        width: 145,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: occupiedSeats.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 5),
                          itemBuilder: (context, index) {
                            final member = occupiedSeats[index];
                            final photo = (member['profile_photo'] ?? '')
                                .toString();
                            return GestureDetector(
                              onTap: () => showMessage(
                                'Member ID: ${member['user_code'] ?? ''}',
                              ),
                              child: CircleAvatar(
                                radius: 17,
                                backgroundColor: const Color(0xFF286B9D),
                                backgroundImage: photo.startsWith('http')
                                    ? NetworkImage(photo)
                                    : null,
                                child: photo.startsWith('http')
                                    ? null
                                    : const Icon(
                                        Icons.person,
                                        color: Color(0xFF123B5A),
                                        size: 17,
                                      ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(8, 3, 8, 8),
                    children: [
                      if (occupiedSeats.isNotEmpty)
                        SizedBox(
                          height: 48,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: occupiedSeats.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 7),
                            itemBuilder: (context, index) {
                              final member = occupiedSeats[index];
                              final photo = (member['profile_photo'] ?? '')
                                  .toString();
                              return GestureDetector(
                                onTap: () => showMessage(
                                  'Member ID: ${member['user_code'] ?? ''}',
                                ),
                                child: CircleAvatar(
                                  radius: 19,
                                  backgroundColor: const Color(0xFF286B9D),
                                  backgroundImage: photo.startsWith('http')
                                      ? NetworkImage(photo)
                                      : null,
                                  child: photo.startsWith('http')
                                      ? null
                                      : const Icon(
                                          Icons.person,
                                          color: const Color(0xFF123B5A),
                                          size: 19,
                                        ),
                                ),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 5),
                      if (seatsLoading && seats.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(25),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF83D8FF),
                            ),
                          ),
                        )
                      else ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 13),
                              child: _buildSeat(1),
                            ),
                            _buildSeat(2, large: true),
                            Padding(
                              padding: const EdgeInsets.only(top: 13),
                              child: _buildSeat(3),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        for (final first in [4, 9, 14]) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              for (int i = 0; i < 5; i++) _buildSeat(first + i),
                            ],
                          ),
                          const SizedBox(height: 7),
                        ],
                      ],
                      const Divider(color: Color(0x335E9AC5), height: 14),
                      Row(
                        children: [
                          const Text(
                            'Room Chat',
                            style: TextStyle(
                              color: const Color(0xFF123B5A),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${messages.length} messages',
                            style: const TextStyle(
                              color: const Color(0xFF6D91A8),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      if (messages.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Center(
                            child: Text(
                              'Welcome to Lovely Sky!',
                              style: TextStyle(
                                color: const Color(0xFF6D91A8),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        )
                      else
                        ...messages.map(
                          (message) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.account_circle_rounded,
                                  color: Color(0xFF8DDCFF),
                                  size: 25,
                                ),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    message['text'].toString(),
                                    style: const TextStyle(
                                      color: const Color(0xFF123B5A),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Text(
                                  message['time'].toString(),
                                  style: const TextStyle(
                                    color: const Color(0xFF8AA9BC),
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(3, 0, 4, 3),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: messageController,
                          style: const TextStyle(
                            color: Color(0xFF123B5A),
                            fontSize: 12,
                          ),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => sendMessage(),
                          decoration: InputDecoration(
                            hintText: 'Message...',
                            hintStyle: const TextStyle(
                              color: Color(0xFF6D91A8),
                              fontSize: 12,
                            ),
                            suffixIcon: _AnimatedRoomActionButton(
                              icon: Icons.send_rounded,
                              tooltip: 'Send',
                              onTap: sendMessage,
                              color: const Color(0xFF8DE4FF),
                              size: 22,
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 9,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                      ),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            circleAction(
                              speakerOn
                                  ? Icons.volume_up_rounded
                                  : Icons.volume_off_rounded,
                              'Speaker',
                              _toggleSpeaker,
                            ),
                            circleAction(
                              micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                              'Microphone',
                              _toggleMic,
                              color: micOn
                                  ? const Color(0xFF8DE4FF)
                                  : const Color(0xFFFF8D9B),
                            ),
                            _AnimatedRoseGiftButton(
                              onTap: () => openLovelyRoomGiftStore(
                                context,
                                roomId: widget.room['id'],
                              ),
                            ),
                            circleAction(
                              Icons.emoji_emotions_outlined,
                              'Emoji',
                              () {
                                messageController.text += '😊';
                                messageController.selection =
                                    TextSelection.collapsed(
                                      offset: messageController.text.length,
                                    );
                              },
                            ),
                            _AnimatedRoomToolbarButton(
                              icon: Icons.inbox_rounded,
                              onTap: () => showMessage(
                                'Inbox feature baad mein connect hoga.',
                              ),
                            ),
                            circleAction(Icons.grid_view_rounded, 'More', () {
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: const Color(0xFFF5FBFF),
                                builder: (ctx) => SafeArea(
                                  child: Wrap(
                                    children: [
                                      ListTile(
                                        leading: const Icon(
                                          Icons.casino_rounded,
                                        ),
                                        title: const Text('Games'),
                                        onTap: () {
                                          Navigator.pop(ctx);
                                          openLovelyCasinoGames(context);
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.info_outline),
                                        title: const Text('Room Information'),
                                        onTap: () {
                                          Navigator.pop(ctx);
                                          showMessage('Room ID: $roomId');
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(
                                          Icons.exit_to_app,
                                          color: Colors.redAccent,
                                        ),
                                        title: const Text('Leave Room'),
                                        onTap: () {
                                          Navigator.pop(ctx);
                                          _leaveRoom();
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              right: 12,
              bottom: 68,
              child: _AnimatedGamepadButton(
                onTap: () => openLovelyCasinoGames(context),
              ),
            ),
            if (activeGiftEvent != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey(
                        '${activeGiftEvent!['sender_code']}_${activeGiftEvent!['gift_code']}_${activeGiftEvent!['combo']}',
                      ),
                      tween: Tween(begin: 0.3, end: 1),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.elasticOut,
                      builder: (context, scale, child) =>
                          Transform.scale(scale: scale, child: child),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 28),
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF32145F), Color(0xFF7138A8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: const Color(0xFFE5B8FF),
                            width: 1.5,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0xAA9B55FF),
                              blurRadius: 28,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0x55FFFFFF),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: const Color(0xFFE5B8FF),
                                ),
                              ),
                              child: const Text(
                                'GIFT SENT',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.45, end: 1),
                              duration: const Duration(milliseconds: 850),
                              curve: Curves.elasticOut,
                              builder: (context, value, child) {
                                return Transform.rotate(
                                  angle: (1 - value) * -0.22,
                                  child: Transform.scale(
                                    scale: value,
                                    child: child,
                                  ),
                                );
                              },
                              child: Text(
                                activeGiftEvent!['emoji']?.toString() ?? '🎁',
                                style: const TextStyle(fontSize: 88),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '${activeGiftEvent!['sender_name']} sent a gift!',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${activeGiftEvent!['gift_name']}  ×${activeGiftEvent!['quantity']}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFFFD477),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD477),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Text(
                                'COMBO  ×${activeGiftEvent!['combo']}',
                                style: const TextStyle(
                                  color: Color(0xFF32145F),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'To: ${activeGiftEvent!['receiver_text'] ?? 'Room members'}',
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFEAD9FF),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
