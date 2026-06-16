import 'package:flutter/material.dart';

import 'home_page.dart';
import 'reading_page.dart';
import 'levels_page.dart';
import 'profile_page.dart';
import '../widgets/app_logo_header.dart';

class MainNavigationPage extends StatefulWidget {
  final Map<String, dynamic> student;

  const MainNavigationPage({
    super.key,
    required this.student,
  });

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int selectedTabIndex = 0;
 int? selectedLevelId;
  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      HomePage(
        onStartReading: () {
          setState(() {
            selectedTabIndex = 1;
          });
        },
        onOpenLevels: () {
          setState(() {
            selectedTabIndex = 2;
          });
        },
      ),
      ReadingPage(
        selectedLevelId: selectedLevelId,
),

      LevelsPage(
        onLevelSelected: (levelId) {
          setState(() {
            selectedLevelId = levelId;
            selectedTabIndex = 1;
          });
        },
      ),
      const ProfilePage(),
    ];

    return Scaffold(
     appBar: AppBar(
  automaticallyImplyLeading: false,
  centerTitle: true,
  toolbarHeight: 82,
  backgroundColor: const Color(0xFFFCF7FF),
  elevation: 0,
  title: const AppLogoHeader(
    height: 200,
  ),
),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: pages[selectedTabIndex],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedTabIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF6C63FF),
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            selectedTabIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Ana Sayfa",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book),
            label: "Okuma",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events),
            label: "Seviyeler",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "Profil",
          ),
        ],
      ),
    );
  }
}