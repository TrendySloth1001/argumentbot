import 'package:flutter/material.dart';
import '../../../../features/auth/data/models/user_model.dart';
import '../../../../features/auth/presentation/screens/login_screen.dart';
import '../../../../features/auth/data/services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  final User user;
  final Function(String avatarUrl)? onAvatarUpdated;

  const ProfileScreen({super.key, required this.user, this.onAvatarUpdated});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late String? _currentAvatarUrl;

  // Theme colors
  static const Color neonGreen = Color(0xFF00FF88);

  @override
  void initState() {
    super.initState();
    _currentAvatarUrl = widget.user.avatarUrl;
  }

  final List<String> _avatarOptions = [
    'https://static.vecteezy.com/system/resources/thumbnails/002/002/403/small/man-with-beard-avatar-character-isolated-icon-free-vector.jpg',
    'https://static.vecteezy.com/system/resources/thumbnails/002/318/271/small/user-profile-icon-free-vector.jpg',
    'https://static.vecteezy.com/system/resources/thumbnails/009/749/643/small/woman-profile-mascot-illustration-female-avatar-character-icon-cartoon-girl-head-face-business-user-logo-free-vector.jpg',
    'https://static.vecteezy.com/system/resources/thumbnails/023/402/465/small/man-avatar-free-vector.jpg',
    'https://static.vecteezy.com/system/resources/thumbnails/006/898/692/small/avatar-face-icon-female-social-profile-of-business-woman-woman-portrait-support-service-call-center-illustration-free-vector.jpg',
    'https://static.vecteezy.com/system/resources/thumbnails/009/749/748/small/female-avatar-icon-cartoon-woman-profile-mascot-illustration-girl-face-business-user-logo-free-vector.jpg',
    'https://plus.unsplash.com/premium_vector-1682269287900-d96e9a6c188b',
    'https://plus.unsplash.com/premium_vector-1727955579176-073f1c85dcda',
    'https://plus.unsplash.com/premium_vector-1741992520506-bc31b1405729',
    'https://plus.unsplash.com/premium_vector-1723550230272-423cdac21d58',
    'https://plus.unsplash.com/premium_vector-1721934027068-09908109d02e',
    'https://plus.unsplash.com/premium_vector-1749476966758-539bb66459c8',
  ];

  void _logout(BuildContext context) async {
    await AuthService().logout();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _showAvatarSelection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose Avatar',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 240,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _avatarOptions.length,
                  itemBuilder: (context, index) {
                    final url = _avatarOptions[index];
                    final isSelected = url == _currentAvatarUrl;
                    return GestureDetector(
                      onTap: () => _selectAvatar(context, url),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: neonGreen, width: 3)
                              : null,
                        ),
                        child: ClipOval(
                          child: Image.network(url, fit: BoxFit.cover),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _selectAvatar(BuildContext context, String url) async {
    Navigator.pop(context);
    try {
      await AuthService().updateProfile(url);
      setState(() => _currentAvatarUrl = url);
      widget.onAvatarUpdated?.call(url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Avatar updated!'),
            backgroundColor: neonGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update avatar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'Profile',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              _buildDivider(),
              const SizedBox(height: 32),

              // Avatar
              Center(
                child: GestureDetector(
                  onTap: () => _showAvatarSelection(context),
                  child: Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: neonGreen, width: 3),
                        ),
                        child: ClipOval(
                          child:
                              _currentAvatarUrl != null &&
                                  _currentAvatarUrl!.isNotEmpty
                              ? Image.network(
                                  _currentAvatarUrl!,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  color: Colors.black,
                                  alignment: Alignment.center,
                                  child: Text(
                                    widget.user.username.isNotEmpty
                                        ? widget.user.username[0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      color: neonGreen,
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: neonGreen,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.edit,
                            color: Colors.black,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),
              _buildDivider(),
              const SizedBox(height: 24),

              // Info tiles
              _buildInfoTile(
                'Username',
                widget.user.username,
                Icons.person_outline,
              ),
              const SizedBox(height: 12),
              _buildInfoTile('Email', widget.user.email, Icons.email_outlined),
              const SizedBox(height: 12),
              _buildInfoTile(
                'Joined',
                'Recently',
                Icons.calendar_today_outlined,
              ),

              const SizedBox(height: 48),

              // Logout button
              GestureDetector(
                onTap: () => _logout(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withAlpha(128)),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Logout',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            Colors.grey[800]!,
            Colors.grey[800]!,
            Colors.transparent,
          ],
          stops: const [0.0, 0.2, 0.8, 1.0],
        ),
      ),
    );
  }

  Widget _buildInfoTile(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: neonGreen, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 11,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
