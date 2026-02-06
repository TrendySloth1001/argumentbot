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
    // Build screens dynamically so they get the updated user
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
          boxShadow: [
            BoxShadow(blurRadius: 20, color: Colors.white.withOpacity(.1)),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 8),
            child: GNav(
              rippleColor: Colors.grey[800]!,
              hoverColor: Colors.grey[700]!,
              gap: 8,
              activeColor: Colors.blueAccent,
              iconSize: 24,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              duration: const Duration(milliseconds: 400),
              tabBackgroundColor: Colors.grey[900]!,
              color: Colors.grey[400],
              tabs: const [
                GButton(icon: LineIcons.home, text: 'Home'),
                GButton(icon: LineIcons.globe, text: 'Feed'),
                GButton(icon: LineIcons.user, text: 'Profile'),
                GButton(icon: LineIcons.cog, text: 'Settings'),
              ],
              selectedIndex: _selectedIndex,
              onTabChange: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
            ),
          ),
        ),
      ),
    );
  }
}
