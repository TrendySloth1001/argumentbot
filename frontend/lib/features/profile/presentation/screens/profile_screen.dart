import 'package:flutter/material.dart';
import '../../../../features/auth/data/models/user_model.dart';
import '../../../../features/auth/presentation/widgets/primary_button.dart';
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
    'https://plus.unsplash.com/premium_vector-1768878842221-1d2a6b22f741',
    'https://plus.unsplash.com/premium_vector-1745915292274-195e44fcc483',
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
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 280,
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
                              ? Border.all(color: Colors.blueAccent, width: 3)
                              : null,
                        ),
                        child: CircleAvatar(
                          backgroundImage: NetworkImage(url),
                          backgroundColor: Colors.grey[800],
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
      setState(() {
        _currentAvatarUrl = url;
      });
      // Notify parent to update
      widget.onAvatarUpdated?.call(url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Avatar updated!'),
            backgroundColor: Colors.green,
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Profile',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Center(
                          child: GestureDetector(
                            onTap: () => _showAvatarSelection(context),
                            child: Stack(
                              children: [
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      width: 2,
                                    ),
                                    image: _currentAvatarUrl != null
                                        ? DecorationImage(
                                            image: NetworkImage(
                                              _currentAvatarUrl!,
                                            ),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: _currentAvatarUrl == null
                                      ? Icon(
                                          Icons.person,
                                          size: 50,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        )
                                      : null,
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.blueAccent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.edit,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        _buildInfoTile(
                          context,
                          'Username',
                          widget.user.username,
                          Icons.person_outline,
                        ),
                        const SizedBox(height: 16),
                        _buildInfoTile(
                          context,
                          'Email',
                          widget.user.email,
                          Icons.email,
                        ),
                        const SizedBox(height: 16),
                        _buildInfoTile(
                          context,
                          'Joined',
                          'Recently',
                          Icons.calendar_today,
                        ),
                        const Spacer(),
                        const SizedBox(height: 24),
                        PrimaryButton(
                          text: 'Logout',
                          onPressed: () => _logout(context),
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

  Widget _buildInfoTile(
    BuildContext context,
    String title,
    String value,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[400], size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
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
