import 'package:flutter/material.dart';

import 'pages/gesture_control_page.dart';
import 'pages/voice_command_page.dart';
import 'pages/settings_page.dart';
import 'services/camera_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await cameraService.loadCameras();

  runApp(const GestureControlApp());
}

class GestureControlApp extends StatelessWidget {
  const GestureControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gesture Control App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,

        // เพิ่มตรงนี้
        scaffoldBackgroundColor: Colors.transparent,

        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
      ),

      // เพิ่มตรงนี้
      builder: (context, child) {
        return BackgroundLayout(child: child ?? const SizedBox());
      },

      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int selectedIndex = 0;

  final List<Widget> pages = const [
    GestureControlPage(),
    VoiceCommandPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: false,
      backgroundColor: Colors.transparent,
      body: pages[selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFAAAB).withOpacity(0.78),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6B4A35).withOpacity(0.08),
              blurRadius: 14,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: Colors.transparent,
            indicatorColor: const Color(0xFFFFF5D7).withOpacity(0.55),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const TextStyle(
                  color: Color(0xFF6B4A35),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                );
              }

              return const TextStyle(
                color: Color(0xFF6B4A35),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              );
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const IconThemeData(color: Color(0xFFFF5E6C), size: 26);
              }

              return const IconThemeData(color: Color(0xFF6B4A35), size: 24);
            }),
          ),
          child: NavigationBar(
            height: 78,
            elevation: 0,
            backgroundColor: Colors.transparent,
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                selectedIndex = index;
              });
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.camera_alt_outlined),
                selectedIcon: Icon(Icons.camera_alt),
                label: 'Gesture',
              ),
              NavigationDestination(
                icon: Icon(Icons.mic_none_rounded),
                selectedIcon: Icon(Icons.mic_rounded),
                label: 'Voice',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BackgroundLayout extends StatelessWidget {
  final Widget child;

  const BackgroundLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(color: const Color(0xFFFFF5D7), child: child);
  }
}
