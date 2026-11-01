import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          Row(
            children: [
              Container(
                width: 43,
                height: 43,
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
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Lovely Sky',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: blue,
                  ),
                ),
              ),
              roundIcon(Icons.search_rounded),
              const SizedBox(width: 8),
              roundIcon(Icons.notifications_none_rounded),
            ],
          ),
          const SizedBox(height: 20),
          blueBanner(
            'Good Vibes, Great People',
            'Connect • Chat • Make Friends',
            Icons.favorite_rounded,
          ),
          sectionTitle('Explore Lovely'),
          Row(
            children: const [
              Expanded(
                child: QuickTile(
                  icon: Icons.video_library_rounded,
                  label: 'Video',
                  color: blue,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: QuickTile(
                  icon: Icons.mic_rounded,
                  label: 'Voice',
                  color: Color(0xFF10BFD3),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: QuickTile(
                  icon: Icons.camera_alt_rounded,
                  label: 'Moment',
                  color: Color(0xFFDE72D9),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: QuickTile(
                  icon: Icons.chat_rounded,
                  label: 'Chat',
                  color: Color(0xFF42B8FF),
                ),
              ),
            ],
          ),
          sectionTitle('Popular Rooms'),
          const RoomCard(
            title: 'Music Vibes 🎵',
            subtitle: 'Meet friends and enjoy music',
            count: '2.4K online',
            icon: Icons.music_note_rounded,
          ),
          const SizedBox(height: 12),
          const RoomCard(
            title: 'Friends Forever 💙',
            subtitle: 'Talk • Laugh • Connect',
            count: '860 online',
            icon: Icons.groups_rounded,
          ),
          sectionTitle('Recommended Users'),
          const UserRow(name: 'Princess', detail: 'Online now', avatar: '👑'),
          const UserRow(
            name: 'Cute Girl',
            detail: 'Making new friends',
            avatar: '🌸',
          ),
          const UserRow(
            name: 'King',
            detail: 'Enjoying Lovely Sky',
            avatar: '😎',
          ),
        ],
      ),
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

class VideoPage extends StatelessWidget {
  const VideoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          pageTitle(
            'Video Rooms',
            subtitle: 'Discover videos and creators',
            trailing: roundIcon(Icons.search_rounded),
          ),
          const Wrap(
            spacing: 10,
            children: [
              Chip(
                label: Text('Following'),
                backgroundColor: Color(0xFFDFF3FF),
              ),
              Chip(label: Text('For You')),
              Chip(label: Text('Popular')),
            ],
          ),
          const SizedBox(height: 12),
          const VideoCard(
            title: 'Beautiful Souls 💙',
            subtitle: 'Live • 3.2K watching',
            icon: Icons.favorite_rounded,
          ),
          const SizedBox(height: 15),
          const VideoCard(
            title: 'Love & Talk',
            subtitle: 'Meet new friends',
            icon: Icons.people_rounded,
          ),
          const SizedBox(height: 15),
          const VideoCard(
            title: 'Cool Vibes ✨',
            subtitle: 'Trending now',
            icon: Icons.auto_awesome_rounded,
          ),
        ],
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
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          pageTitle(
            'My Profile',
            subtitle: 'Your Lovely world',
            trailing: roundIcon(Icons.settings_rounded),
          ),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF168FFF), Color(0xFF8BDEFF)],
              ),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: Colors.white, width: 4),
                    image: profilePhoto.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(profilePhoto),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: profilePhoto.isEmpty
                      ? const Icon(Icons.person_rounded, size: 55, color: blue)
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  displayName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  profileLoading
                      ? 'ID: Loading...'
                      : userCode.isNotEmpty
                      ? 'ID: $userCode'
                      : 'ID: Not available — login again',
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 20),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    StatItem(value: '0', label: 'Followers'),
                    StatItem(value: '0', label: 'Following'),
                    StatItem(value: '0', label: 'Likes'),
                  ],
                ),
              ],
            ),
          ),
          sectionTitle('My Lovely Space'),
          const Row(
            children: [
              Expanded(
                child: MenuTile(
                  icon: Icons.account_balance_wallet_rounded,
                  title: 'Wallet',
                  subtitle: 'Coins & history',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: MenuTile(
                  icon: Icons.storefront_rounded,
                  title: 'Store',
                  subtitle: 'Gifts & frames',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Expanded(
                child: MenuTile(
                  icon: Icons.card_giftcard_rounded,
                  title: 'Gift Bag',
                  subtitle: 'My gifts',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: MenuTile(
                  icon: Icons.emoji_events_rounded,
                  title: 'Rewards',
                  subtitle: 'Daily rewards',
                ),
              ),
            ],
          ),
          sectionTitle('Account'),
          const MenuTile(
            icon: Icons.edit_rounded,
            title: 'Edit Profile',
            subtitle: 'Name and picture',
          ),
          const SizedBox(height: 10),
          const MenuTile(
            icon: Icons.shield_rounded,
            title: 'Privacy & Security',
            subtitle: 'Protect your account',
          ),
          const SizedBox(height: 10),
          const MenuTile(
            icon: Icons.help_outline_rounded,
            title: 'Help & Support',
            subtitle: 'We are here to help',
          ),
          if (userCode == '1') ...[
            const SizedBox(height: 10),
            Card(
              color: Colors.white,
              child: ListTile(
                leading: const Icon(Icons.storage_rounded, color: blue),
                title: const Text('Cloud Database Check'),
                subtitle: const Text('Owner-only server diagnostic'),
                trailing: databaseChecking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right_rounded),
                onTap: databaseChecking ? null : _checkCloudDatabase,
              ),
            ),
          ],
        ],
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
  const MenuTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
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
    );
  }
}

class VoiceRoomScreen extends StatefulWidget {
  final Map<String, dynamic> room;

  const VoiceRoomScreen({super.key, required this.room});

  @override
  State<VoiceRoomScreen> createState() => _VoiceRoomScreenState();
}

class _VoiceRoomScreenState extends State<VoiceRoomScreen> {
  final TextEditingController messageController = TextEditingController();
  final List<Map<String, dynamic>> messages = [];

  bool micOn = true;
  bool moderationMuted = false;
  String roomRole = 'member';
  bool speakerOn = true;
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

  static const Color purple = Color(0xFF7728E8);
  static const Color pink = Color(0xFFFF4FA3);
  static const Color background = Color(0xFF160D2B);

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

  Future<void> _handleVoiceSignal(dynamic event) async {
    try {
      final decoded = jsonDecode(event is String ? event : event.toString());
      if (decoded is! Map) return;

      final data = Map<String, dynamic>.from(decoded);
      final type = data['type'];
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
        socket.add(jsonEncode({
          'type': 'mic_status',
          'payload': requestedMicOn,
        }));
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

  Future<void> _moderateMemberMic(
    String targetUid,
    bool turnMicOn,
  ) async {
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

    socket.add(jsonEncode({
      'type': 'moderator_mute',
      'target_uid': targetUid,
      'payload': turnMicOn,
    }));
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

      final response = await http.get(
        Uri.parse('$lovelyApi/voice/rooms/${widget.room['id']}/invites/pending'),
        headers: headers,
      ).timeout(const Duration(seconds: 12));

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

      final result = await http.post(
        Uri.parse(
          '$lovelyApi/voice/rooms/${widget.room['id']}/invites/$inviteId/respond',
        ),
        headers: {
          ...headers,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'accepted': accepted}),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (result.statusCode == 200) {
        showMessage(accepted
            ? 'Invitation accepted!'
            : 'Invitation rejected.');
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
      final response = await http.post(
        Uri.parse('$lovelyApi$path'),
        headers: {
          ...headers,
          if (body != null) 'Content-Type': 'application/json',
        },
        body: body == null ? null : jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

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
      final response = await http.get(
        Uri.parse('$lovelyApi/voice/rooms/${widget.room['id']}/members'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        showMessage('Room members load nahi huay (${response.statusCode}).');
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final members = List<Map<String, dynamic>>.from(
        (data['members'] as List).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      ).where((m) =>
          (m['user_uid'] ?? '').toString().isNotEmpty &&
          m['is_mine'] != true &&
          m['seat_number'] == null
      ).toList();

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
              ...members.map((m) => ListTile(
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
              )),
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
                leading: Icon(
                  isMuted ? Icons.mic : Icons.mic_off,
                  color: pink,
                ),
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
              leading: Icon(
                locked ? Icons.lock_open : Icons.lock,
                color: pink,
              ),
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
    final topSofa = number <= 3;
    final size = large ? 58.0 : 44.0;
    final avatarSize = large ? 40.0 : 30.0;
    final photo = (seat['profile_photo'] ?? '').toString();

    Widget avatar;
    if (photo.startsWith('http://') || photo.startsWith('https://')) {
      avatar = Image.network(
        photo,
        width: avatarSize,
        height: avatarSize,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Icon(Icons.person, color: Colors.white),
      );
    } else if (photo.startsWith('data:image') && photo.contains(',')) {
      try {
        avatar = Image.memory(
          base64Decode(photo.substring(photo.indexOf(',') + 1)),
          width: avatarSize,
          height: avatarSize,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const Icon(Icons.person, color: Colors.white),
        );
      } catch (_) {
        avatar = const Icon(Icons.person, color: Colors.white);
      }
    } else {
      avatar = const Icon(Icons.person, color: Colors.white);
    }

    final seatIcon = topSofa ? Icons.weekend_rounded : Icons.chair_alt_rounded;
    final seatColors = topSofa
        ? const [Color(0xFFFF5555), Color(0xFFB5122B), Color(0xFF650D24)]
        : const [Color(0xFF55C878), Color(0xFF16834A), Color(0xFF07512F)];
    const gold = Color(0xFFFFD778);

    return InkWell(
      onTap: () => _onSeatTap(number),
      borderRadius: BorderRadius.circular(topSofa ? 15 : 12),
      child: SizedBox(
        width: size,
        height: size + (occupied ? 12 : 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [gold, ...seatColors],
                ),
                borderRadius: BorderRadius.circular(topSofa ? 15 : 12),
                border: Border.all(color: gold, width: large ? 1.8 : 1.2),
                boxShadow: [
                  BoxShadow(
                    color: (topSofa ? const Color(0xFFFF3030) : const Color(0xFF20C878))
                        .withValues(alpha: 0.32),
                    blurRadius: large ? 12 : 7,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: seatColors,
                  ),
                  borderRadius: BorderRadius.circular(topSofa ? 12 : 9),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      seatIcon,
                      size: size * 0.98,
                      color: gold.withValues(alpha: occupied ? 0.48 : 0.95),
                    ),
                    if (occupied)
                      Container(
                        width: avatarSize,
                        height: avatarSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF173D2A),
                          border: Border.all(color: gold, width: 1.5),
                        ),
                        child: ClipOval(child: avatar),
                      ),
                    if (locked && !occupied)
                      Container(
                        width: large ? 27 : 23,
                        height: large ? 27 : 23,
                        decoration: BoxDecoration(
                          color: const Color(0xDD172B25),
                          shape: BoxShape.circle,
                          border: Border.all(color: gold, width: 1.2),
                        ),
                        child: Icon(
                          Icons.lock_rounded,
                          size: large ? 16 : 13,
                          color: gold,
                        ),
                      ),
                    if (occupied)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: large ? 17 : 14,
                          height: large ? 17 : 14,
                          decoration: BoxDecoration(
                            color: mine
                                ? (micOn
                                    ? const Color(0xFF20C997)
                                    : const Color(0xFFE8415B))
                                : const Color(0xFF315B48),
                            shape: BoxShape.circle,
                            border: Border.all(color: gold, width: 1.2),
                          ),
                          child: Icon(
                            mine
                                ? (micOn ? Icons.mic : Icons.mic_off)
                                : ((remoteMicStatus[
                                          seat['user_code']?.toString() ?? ''
                                        ] ?? true)
                                    ? Icons.mic
                                    : Icons.mic_off),
                            size: large ? 10 : 8,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (occupied)
              SizedBox(
                width: size + 4,
                child: Text(
                  mine ? 'You' : (seat['user_code'] ?? '').toString(),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: large ? 9 : 7,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
    unawaited(_stopVoice());
    messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.room['name'] ?? 'Voice Room').toString();
    final owner = (widget.room['owner_code'] ?? '').toString();
    final roomId = (widget.room['id'] ?? '').toString();
    final ownerPhoto =
        (widget.room['owner_photo'] ?? widget.room['profile_photo'] ?? '')
            .toString();

    Widget roundButton(IconData icon, String tip, VoidCallback action) {
      return IconButton(
        tooltip: tip,
        onPressed: action,
        icon: Icon(icon, color: Colors.white, size: 23),
        style: IconButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.09),
          minimumSize: const Size(42, 42),
        ),
      );
    }

    Widget panel(Widget child) => Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xCC211438),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: purple.withValues(alpha: 0.35)),
      ),
      child: child,
    );

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            // Top room name, owner ID and controls.
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 5, 8, 2),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 23,
                    backgroundColor: purple,
                    backgroundImage: ownerPhoto.startsWith('http')
                        ? NetworkImage(ownerPhoto)
                        : null,
                    child: ownerPhoto.startsWith('http')
                        ? null
                        : const Icon(Icons.person, color: Colors.white),
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
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'ID: ${owner.isEmpty ? roomId : owner}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  roundButton(
                    Icons.flag_outlined,
                    'Report',
                    () => showMessage('Report feature baad mein connect hoga.'),
                  ),
                  roundButton(Icons.refresh, 'Refresh', _loadSeats),
                  roundButton(
                    Icons.power_settings_new,
                    'Leave room',
                    _leaveRoom,
                  ),
                ],
              ),
            ),

            // Scrollable room area.
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
                children: [
                  Row(
                    children: [
                      roundButton(
                        speakerOn ? Icons.volume_up : Icons.volume_off,
                        'Room sound',
                        _toggleSpeaker,
                      ),
                      const SizedBox(width: 5),
                      const Icon(
                        Icons.local_fire_department,
                        color: Colors.orange,
                        size: 23,
                      ),
                      const Text('0', style: TextStyle(color: Colors.white70)),
                      const Spacer(),
                      roundButton(
                        Icons.people_alt_outlined,
                        'Members',
                        () => showMessage('Room members'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),

                  if (seatsLoading && seats.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: CircularProgressIndicator(color: pink),
                      ),
                    )
                  else ...[
                    // Three seats at the top.
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (final n in [1, 2, 3])
                          Expanded(
                            child: Column(
                              children: [
                                _buildSeat(n, large: n == 2),
                                const SizedBox(height: 3),
                                Text(
                                  'No. $n',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                                const Text(
                                  '💗 0',
                                  style: TextStyle(
                                    color: Colors.pinkAccent,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),

                    // Remaining fifteen seats in three rows.
                    for (final first in [4, 9, 14]) ...[
                      Row(
                        children: [
                          for (int i = 0; i < 5; i++)
                            Expanded(
                              child: Column(
                                children: [
                                  _buildSeat(first + i),
                                  const SizedBox(height: 3),
                                  Text(
                                    'No. ${first + i}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const Text(
                                    '💗 0',
                                    style: TextStyle(
                                      color: Colors.pinkAccent,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                    ],
                  ],

                  // Room tabs.
                  Row(
                    children: [
                      const Text(
                        'All',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 22),
                      TextButton(
                        onPressed: () => showMessage('Room chat'),
                        child: const Text(
                          'Chat',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),

                  // Room announcement and message history.
                  panel(
                    const Text(
                      'Welcome to Lovely Sky! Please respect all members '
                      'and follow the room rules.',
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                  panel(
                    const Text(
                      'Room announcement: Only Friendship',
                      style: TextStyle(color: Colors.amber, fontSize: 14),
                    ),
                  ),
                  panel(
                    const Row(
                      children: [
                        Icon(
                          Icons.campaign_outlined,
                          color: Colors.white70,
                          size: 28,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Invite friends to support your room.',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (messages.isNotEmpty)
                    ...messages.map(
                      (message) => panel(
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const CircleAvatar(
                              radius: 15,
                              backgroundColor: purple,
                              child: Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 17,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                message['text'].toString(),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            Text(
                              message['time'].toString(),
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Compact bottom row: chat, send, emoji, mic, gift and More.
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Games',
                constraints: const BoxConstraints.tightFor(
                  width: 38,
                  height: 29,
                ),
                padding: EdgeInsets.zero,
                onPressed: () => showMessage('Games feature'),
                icon: const Icon(
                  Icons.sports_esports,
                  color: Colors.amber,
                  size: 22,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(5, 2, 5, 2),
              color: Colors.transparent,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: messageController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Message...',
                        hintStyle: const TextStyle(color: Colors.white54),
                        isDense: true,
                        filled: true,
                        fillColor: background,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Send',
                    constraints: const BoxConstraints.tightFor(
                      width: 36,
                      height: 42,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: sendMessage,
                    icon: const Icon(Icons.send_rounded, color: pink, size: 22),
                  ),
                  IconButton(
                    tooltip: 'Emoji',
                    constraints: const BoxConstraints.tightFor(
                      width: 34,
                      height: 42,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      messageController.text += '😊';
                      messageController.selection = TextSelection.collapsed(
                        offset: messageController.text.length,
                      );
                    },
                    icon: const Icon(
                      Icons.emoji_emotions_outlined,
                      color: Colors.white,
                      size: 23,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Mic',
                    constraints: const BoxConstraints.tightFor(
                      width: 34,
                      height: 42,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: _toggleMic,
                    icon: Icon(
                      micOn ? Icons.mic : Icons.mic_off,
                      color: micOn ? pink : Colors.white54,
                      size: 24,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Gift',
                    constraints: const BoxConstraints.tightFor(
                      width: 38,
                      height: 42,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: () =>
                        showMessage('Gift feature abhi connect karna hai.'),
                    icon: const Icon(
                      Icons.card_giftcard_rounded,
                      color: pink,
                      size: 29,
                    ),
                  ),
                  IconButton(
                        tooltip: 'More',
                        onPressed: () => showModalBottomSheet(
                          context: context,
                          backgroundColor: background,
                          builder: (ctx) => SafeArea(
                            child: Wrap(
                              children: [
                                ListTile(
                                  leading: const Icon(
                                    Icons.info_outline,
                                    color: Colors.white,
                                  ),
                                  title: const Text(
                                    'Room Information',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    showMessage('Room ID: $roomId');
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(
                                    Icons.volume_up,
                                    color: Colors.white,
                                  ),
                                  title: const Text(
                                    'Speaker On / Off',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    setState(() => speakerOn = !speakerOn);
                                    showMessage(
                                      speakerOn ? 'Speaker On' : 'Speaker Off',
                                    );
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(
                                    Icons.exit_to_app,
                                    color: Colors.redAccent,
                                  ),
                                  title: const Text(
                                    'Leave Room',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    _leaveRoom();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        icon: const Icon(
                          Icons.grid_view_rounded,
                          color: Colors.white,
                          size: 26,
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
