import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';

import 'auth_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const LovelyChatApp());
}

const blue = Color(0xFF168FFF);
const sky = Color(0xFF67D4FF);
const pale = Color(0xFFEAF8FF);
const ink = Color(0xFF183B59);

class LovelyChatApp extends StatelessWidget {
  const LovelyChatApp({super.key});

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
    setState(() => loading = true);
    try {
      final token = await _token();
      if (token == null || token.isEmpty) {
        _message('Please log in first.');
        return;
      }

      final response = await http
          .get(
            Uri.parse('$lovelyApi/voice/rooms?tab=$selectedTab'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['rooms'] is List && mounted) {
          setState(() {
            rooms = (data['rooms'] as List)
                .whereType<Map>()
                .map((r) => Map<String, dynamic>.from(r))
                .toList();
          });
        } else {
          _message('Room list ka response samajh nahi aaya.');
        }
      } else {
        _message('Rooms load nahi huay (${response.statusCode}).');
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
  bool speakerOn = true;
  List<Map<String, dynamic>> seats = [];
  bool seatsLoading = true;
  bool seatRequestInProgress = false;
  Timer? seatRefreshTimer;

  static const Color purple = Color(0xFF7728E8);
  static const Color pink = Color(0xFFFF4FA3);
  static const Color background = Color(0xFF160D2B);

  @override
  void initState() {
    super.initState();
    _loadSeats();
    seatRefreshTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _loadSeats(),
    );
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
    final size = large ? 58.0 : 44.0;

    return InkWell(
      onTap: () => _tapSeat(number),
      borderRadius: BorderRadius.circular(size),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: mine ? const LinearGradient(colors: [pink, purple]) : null,
          color: mine
              ? null
              : occupied
              ? const Color(0xFF49345E)
              : Colors.white.withValues(alpha: 0.07),
          border: Border.all(
            color: mine
                ? pink
                : occupied
                ? purple
                : Colors.white24,
            width: large ? 2.5 : 1.2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              occupied ? Icons.person : Icons.event_seat,
              color: Colors.white,
              size: large ? 23 : 17,
            ),
            if (occupied)
              Text(
                mine ? 'You' : (seat['user_code'] ?? '').toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: large ? 9 : 7,
                  fontWeight: FontWeight.bold,
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

  void sendMessage() {
    final text = messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      messages.add({'text': text, 'time': TimeOfDay.now().format(context)});
      messageController.clear();
    });
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
    messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.room['name'] ?? 'Voice Room').toString();
    final owner = (widget.room['owner_code'] ?? '').toString();
    final roomId = (widget.room['id'] ?? '').toString();

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text('Room #$roomId', style: const TextStyle(fontSize: 11)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Room Information',
            onPressed: () => showMessage('Room information'),
            icon: SizedBox(
              width: 28,
              height: 28,
              child: CustomPaint(painter: _OpenCircleInfoPainter()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [purple, Color(0xFF35145D), pink],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.graphic_eq_rounded,
                          size: 45,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          owner.isEmpty ? 'Voice Room' : 'Host #$owner',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 12),
                        const Chip(
                          avatar: Icon(
                            Icons.people_alt,
                            color: Colors.white,
                            size: 17,
                          ),
                          label: Text(
                            'Voice Room',
                            style: TextStyle(color: Colors.white),
                          ),
                          backgroundColor: Color(0x55300060),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Voice Seats',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (seatsLoading && seats.isEmpty)
                    const Center(child: CircularProgressIndicator(color: pink))
                  else
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildSeat(1),
                            _buildSeat(2, large: true),
                            _buildSeat(3),
                          ],
                        ),
                        const SizedBox(height: 12),
                        for (final first in [4, 9, 14]) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(
                              5,
                              (index) => _buildSeat(first + index),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  const SizedBox(height: 20),
                  const Text(
                    'Room Messages',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (messages.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'Be the first to send a message!',
                          style: TextStyle(color: Colors.white60),
                        ),
                      ),
                    ),
                  ...messages.map(
                    (message) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const CircleAvatar(
                            radius: 15,
                            backgroundColor: purple,
                            child: Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              message['text'].toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
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
            Container(
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 10),
              decoration: const BoxDecoration(
                color: Color(0xFF211438),
                border: Border(top: BorderSide(color: Color(0x447728E8))),
              ),
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
                        hintStyle: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                        isDense: true,
                        filled: true,
                        fillColor: background,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 11,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Emoji',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 40,
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
                      color: Colors.amber,
                      size: 21,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Mic',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 40,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      setState(() => micOn = !micOn);
                      showMessage(micOn ? 'Mic On' : 'Mic Off');
                    },
                    icon: Icon(
                      micOn ? Icons.mic : Icons.mic_off,
                      color: micOn ? pink : Colors.white54,
                      size: 21,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Gift',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 40,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: () =>
                        showMessage('Gift feature abhi connect karna hai.'),
                    icon: const Icon(
                      Icons.card_giftcard_rounded,
                      color: pink,
                      size: 21,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Speaker',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 40,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      setState(() => speakerOn = !speakerOn);
                      showMessage(speakerOn ? 'Speaker On' : 'Speaker Off');
                    },
                    icon: Icon(
                      speakerOn
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_rounded,
                      color: speakerOn ? pink : Colors.white54,
                      size: 21,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Inbox',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 40,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: () =>
                        showMessage('Inbox feature abhi connect karna hai.'),
                    icon: const Icon(
                      Icons.inbox_rounded,
                      color: Colors.white,
                      size: 21,
                    ),
                  ),
                  IconButton(
                    tooltip: 'More',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 40,
                    ),
                    padding: EdgeInsets.zero,
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
                                showMessage('Room information');
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
                      Icons.more_vert,
                      color: Colors.white,
                      size: 22,
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

class _OpenCircleInfoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.39;

    // Gol C shape, jiska khula hissa upar hai.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0.785,
      4.712,
      false,
      paint,
    );

    // Andar i ka nishan.
    final infoPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(
      Offset(center.dx, center.dy - 5),
      1.2,
      Paint()..color = Colors.white,
    );

    canvas.drawLine(
      Offset(center.dx, center.dy - 1),
      Offset(center.dx, center.dy + 6),
      infoPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
