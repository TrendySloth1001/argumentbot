import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:line_icons/line_icons.dart';
import '../../../../features/auth/data/models/user_model.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../feed/presentation/screens/feed_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../widgets/home_tab.dart';

class MainScreen extends StatefulWidget {
  final User user;

  const MainScreen({super.key, required this.user});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late User _currentUser;

  static const Color neonGreen = Color(0xFF00FF88);

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
  }

  void _onAvatarUpdated(String avatarUrl) {
    setState(() {
      _currentUser = User(
        id: _currentUser.id,
        email: _currentUser.email,
        username: _currentUser.username,
        createdAt: _currentUser.createdAt,
        avatarUrl: avatarUrl,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeTab(user: _currentUser),
      const FeedScreen(),
      ProfileScreen(user: _currentUser, onAvatarUpdated: _onAvatarUpdated),
      const SettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border(top: BorderSide(color: Colors.grey[900]!)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: GNav(
              rippleColor: neonGreen.withAlpha(40),
              hoverColor: neonGreen.withAlpha(30),
              gap: 8,
              activeColor: neonGreen,
              iconSize: 22,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              duration: const Duration(milliseconds: 300),
              tabBackgroundColor: neonGreen.withAlpha(26),
              color: Colors.grey[500],
              tabs: const [
                GButton(icon: LineIcons.home, text: 'Home'),
                GButton(icon: LineIcons.globe, text: 'Feed'),
                GButton(icon: LineIcons.user, text: 'Profile'),
                GButton(icon: LineIcons.cog, text: 'Settings'),
              ],
              selectedIndex: _selectedIndex,
              onTabChange: (index) {
                setState(() => _selectedIndex = index);
              },
            ),
          ),
        ),
      ),
    );
  }
}
