import 'package:flutter/material.dart';
import 'auth_screen.dart';

void main() => runApp(const LovelyChatApp());

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
      title: 'Lovely Chat',
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
          NavigationDestination(icon: Icon(Icons.video_library_rounded), label: 'Video'),
          NavigationDestination(icon: Icon(Icons.mic_rounded), label: 'Voice'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_rounded), label: 'Chat'),
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
              Text(title, style: const TextStyle(
                fontSize: 25, fontWeight: FontWeight.w800, color: ink)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(
                  fontSize: 12, color: Colors.blueGrey.shade500)),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing,
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
              Text(title, style: const TextStyle(
                color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
              const SizedBox(height: 7),
              Text(subtitle, style: const TextStyle(
                color: Colors.white, fontSize: 12)),
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
        Expanded(child: Text(title, style: const TextStyle(
          color: ink, fontSize: 17, fontWeight: FontWeight.w800))),
        Text(action, style: const TextStyle(
          color: blue, fontSize: 12, fontWeight: FontWeight.w700)),
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
                width: 43, height: 43,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [blue, sky]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.favorite_rounded,
                    color: Colors.white, size: 27),
              ),
              const SizedBox(width: 10),
              const Expanded(child: Text('Lovely Chat',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                    color: blue))),
              roundIcon(Icons.search_rounded),
              const SizedBox(width: 8),
              roundIcon(Icons.notifications_none_rounded),
            ],
          ),
          const SizedBox(height: 20),
          blueBanner('Good Vibes, Great People',
              'Connect • Chat • Make Friends', Icons.favorite_rounded),
          sectionTitle('Explore Lovely'),
          Row(
            children: const [
              Expanded(child: QuickTile(icon: Icons.video_library_rounded,
                  label: 'Video', color: blue)),
              SizedBox(width: 10),
              Expanded(child: QuickTile(icon: Icons.mic_rounded,
                  label: 'Voice', color: Color(0xFF10BFD3))),
              SizedBox(width: 10),
              Expanded(child: QuickTile(icon: Icons.camera_alt_rounded,
                  label: 'Moment', color: Color(0xFFDE72D9))),
              SizedBox(width: 10),
              Expanded(child: QuickTile(icon: Icons.chat_rounded,
                  label: 'Chat', color: Color(0xFF42B8FF))),
            ],
          ),
          sectionTitle('Popular Rooms'),
          const RoomCard(title: 'Music Vibes 🎵',
              subtitle: 'Meet friends and enjoy music', count: '2.4K online',
              icon: Icons.music_note_rounded),
          const SizedBox(height: 12),
          const RoomCard(title: 'Friends Forever 💙',
              subtitle: 'Talk • Laugh • Connect', count: '860 online',
              icon: Icons.groups_rounded),
          sectionTitle('Recommended Users'),
          const UserRow(name: 'Princess', detail: 'Online now', avatar: '👑'),
          const UserRow(name: 'Cute Girl', detail: 'Making new friends', avatar: '🌸'),
          const UserRow(name: 'King', detail: 'Enjoying Lovely Chat', avatar: '😎'),
        ],
      ),
    );
  }
}

class QuickTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const QuickTile({super.key, required this.icon,
    required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 54, width: 58,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, color: color, size: 27),
        ),
        const SizedBox(height: 7),
        Text(label, style: const TextStyle(
          fontSize: 11, color: ink, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class RoomCard extends StatelessWidget {
  final String title, subtitle, count;
  final IconData icon;
  const RoomCard({super.key, required this.title, required this.subtitle,
    required this.count, required this.icon});

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
            height: 62, width: 62,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [blue, sky]),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(icon, color: Colors.white, size: 31),
          ),
          const SizedBox(width: 13),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(
                color: ink, fontWeight: FontWeight.w800, fontSize: 14)),
              const SizedBox(height: 5),
              Text(subtitle, style: TextStyle(
                color: Colors.blueGrey.shade400, fontSize: 11)),
              const SizedBox(height: 6),
              Text('● $count', style: const TextStyle(
                color: Color(0xFF14B88A), fontSize: 10)),
            ],
          )),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
            decoration: BoxDecoration(
              color: blue, borderRadius: BorderRadius.circular(22)),
            child: const Text('Join', style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class UserRow extends StatelessWidget {
  final String name, detail, avatar;
  const UserRow({super.key, required this.name,
    required this.detail, required this.avatar});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25, backgroundColor: pale,
            child: Text(avatar, style: const TextStyle(fontSize: 25)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(
                fontWeight: FontWeight.w800, color: ink)),
              const SizedBox(height: 4),
              Text(detail, style: TextStyle(
                color: Colors.blueGrey.shade400, fontSize: 11)),
            ],
          )),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: pale, borderRadius: BorderRadius.circular(20)),
            child: const Text('Follow', style: TextStyle(
              color: blue, fontWeight: FontWeight.w700, fontSize: 12)),
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
    return SafeArea(child: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        pageTitle('Video Rooms', subtitle: 'Discover videos and creators',
            trailing: roundIcon(Icons.search_rounded)),
        const Wrap(spacing: 10, children: [
          Chip(label: Text('Following'), backgroundColor: Color(0xFFDFF3FF)),
          Chip(label: Text('For You')),
          Chip(label: Text('Popular')),
        ]),
        const SizedBox(height: 12),
        const VideoCard(title: 'Beautiful Souls 💙',
            subtitle: 'Live • 3.2K watching', icon: Icons.favorite_rounded),
        const SizedBox(height: 15),
        const VideoCard(title: 'Love & Talk',
            subtitle: 'Meet new friends', icon: Icons.people_rounded),
        const SizedBox(height: 15),
        const VideoCard(title: 'Cool Vibes ✨',
            subtitle: 'Trending now', icon: Icons.auto_awesome_rounded),
      ],
    ));
  }
}

class VideoCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  const VideoCard({super.key, required this.title,
    required this.subtitle, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF168FFF), Color(0xFF8BDEFF)],
          begin: Alignment.bottomLeft, end: Alignment.topRight),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Positioned(right: 4, top: 2, child: Icon(icon,
              size: 100, color: Colors.white.withValues(alpha: 0.23))),
          Align(
            alignment: Alignment.bottomLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(
                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
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

class VoicePage extends StatelessWidget {
  const VoicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        pageTitle('Voice Rooms', subtitle: 'Talk • Make Friends • Have Fun',
            trailing: roundIcon(Icons.search_rounded)),
        blueBanner('Your Voice, Your World',
            'Join a room and meet new people', Icons.mic_rounded),
        const SizedBox(height: 18),
        const Wrap(spacing: 8, children: [
          Chip(label: Text('Popular'), backgroundColor: pale),
          Chip(label: Text('New')),
          Chip(label: Text('My Rooms')),
        ]),
        const SizedBox(height: 10),
        const RoomCard(title: 'Late Night Talk 🌙',
            subtitle: 'Come say hello', count: '3.1K online',
            icon: Icons.nightlight_round),
        const SizedBox(height: 12),
        const RoomCard(title: 'Voice Friends 💙',
            subtitle: 'Friendly conversations', count: '2.8K online',
            icon: Icons.headphones_rounded),
        const SizedBox(height: 12),
        const RoomCard(title: 'Gaming Zone 🎮',
            subtitle: 'Chat while gaming', count: '1.5K online',
            icon: Icons.sports_esports_rounded),
      ],
    ));
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
    return SafeArea(child: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        pageTitle('Messages', subtitle: 'Stay close to your friends',
            trailing: roundIcon(Icons.add_comment_rounded)),
        TextField(
          decoration: InputDecoration(
            hintText: 'Search conversations',
            prefixIcon: const Icon(Icons.search, color: blue),
            filled: true, fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 18),
        const Wrap(spacing: 8, children: [
          Chip(label: Text('All'), backgroundColor: pale),
          Chip(label: Text('Friends')),
          Chip(label: Text('Groups')),
        ]),
        const SizedBox(height: 10),
        ...people.map((p) => UserRow(
          name: p[0], detail: p[1], avatar: p[3])),
      ],
    ));
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        pageTitle('My Profile', subtitle: 'Your Lovely world',
            trailing: roundIcon(Icons.settings_rounded)),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF168FFF), Color(0xFF8BDEFF)]),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Column(children: [
            Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: Colors.white, width: 4)),
              child: const Icon(Icons.person_rounded, size: 55, color: blue),
            ),
            const SizedBox(height: 12),
            const Text('Lovely User 💙', style: TextStyle(
              fontSize: 22, color: Colors.white, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text('ID: Not connected yet',
                style: TextStyle(color: Colors.white)),
            const SizedBox(height: 20),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                StatItem(value: '0', label: 'Followers'),
                StatItem(value: '0', label: 'Following'),
                StatItem(value: '0', label: 'Likes'),
              ],
            ),
          ]),
        ),
        sectionTitle('My Lovely Space'),
        const Row(children: [
          Expanded(child: MenuTile(icon: Icons.account_balance_wallet_rounded,
              title: 'Wallet', subtitle: 'Coins & history')),
          SizedBox(width: 12),
          Expanded(child: MenuTile(icon: Icons.storefront_rounded,
              title: 'Store', subtitle: 'Gifts & frames')),
        ]),
        const SizedBox(height: 12),
        const Row(children: [
          Expanded(child: MenuTile(icon: Icons.card_giftcard_rounded,
              title: 'Gift Bag', subtitle: 'My gifts')),
          SizedBox(width: 12),
          Expanded(child: MenuTile(icon: Icons.emoji_events_rounded,
              title: 'Rewards', subtitle: 'Daily rewards')),
        ]),
        sectionTitle('Account'),
        const MenuTile(icon: Icons.edit_rounded,
            title: 'Edit Profile', subtitle: 'Name and picture'),
        const SizedBox(height: 10),
        const MenuTile(icon: Icons.shield_rounded,
            title: 'Privacy & Security', subtitle: 'Protect your account'),
        const SizedBox(height: 10),
        const MenuTile(icon: Icons.help_outline_rounded,
            title: 'Help & Support', subtitle: 'We are here to help'),
      ],
    ));
  }
}

class StatItem extends StatelessWidget {
  final String value, label;
  const StatItem({super.key, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value, style: const TextStyle(
        fontSize: 21, color: Colors.white, fontWeight: FontWeight.w900)),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(
        color: Colors.white, fontSize: 11)),
    ]);
  }
}

class MenuTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const MenuTile({super.key, required this.icon,
    required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4F3FF)),
      ),
      child: Row(children: [
        Icon(icon, color: blue, size: 25),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(
              color: ink, fontWeight: FontWeight.w800, fontSize: 12)),
            const SizedBox(height: 5),
            Text(subtitle, style: TextStyle(
              color: Colors.blueGrey.shade400, fontSize: 10)),
          ],
        )),
      ]),
    );
  }
}
