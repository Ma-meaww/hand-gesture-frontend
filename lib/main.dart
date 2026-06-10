import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import 'gesture_control_page.dart';
import 'voice_command_page.dart';
import 'settings_page.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    cameras = await availableCameras();
  } catch (e) {
    cameras = [];
  }

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
      body: pages[selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.camera_alt), label: 'Gesture'),
          NavigationDestination(icon: Icon(Icons.mic), label: 'Voice'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class BackgroundLayout extends StatelessWidget {
  final Widget child;

  const BackgroundLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage("assets/images/background1.jpg"),
          fit: BoxFit.cover,
        ),
      ),
      child: child,
    );
  }
}
