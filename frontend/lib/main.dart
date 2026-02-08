import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/presentation/screens/splash_screen.dart';

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'core/config/api_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kDebugMode && Platform.isAndroid) {
    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    final isEmulator = !androidInfo.isPhysicalDevice;

    if (isEmulator) {
      ApiConfig.setBaseUrl('http://10.0.2.2:3000');
      print('Running on Android Emulator: Using 10.0.2.2');
    } else {
      print('Running on Physical Android Device: Using DevTunnel');
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ArgumentBot',
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
