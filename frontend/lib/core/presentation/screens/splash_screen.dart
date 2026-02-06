import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../features/auth/data/services/auth_service.dart';
import '../../../../features/home/presentation/screens/main_screen.dart';
import '../../../../features/auth/presentation/screens/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    if (kDebugMode) {
      print('SplashScreen: _checkAuth started');
    }
    // Simulate splash delay if checkAuth is too fast
    await Future.delayed(const Duration(seconds: 1));

    final user = await _authService.checkAuth();
    if (kDebugMode) {
      print('SplashScreen: checkAuth result: ${user?.email}');
    }

    if (mounted) {
      if (user != null) {
        if (kDebugMode) {
          print('SplashScreen: Navigating to MainScreen');
        }
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => MainScreen(user: user)),
        );
      } else {
        if (kDebugMode) {
          print('SplashScreen: Navigating to LoginScreen');
        }
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bolt, size: 80, color: Color(0xFF2979FF)),
            SizedBox(height: 16),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
