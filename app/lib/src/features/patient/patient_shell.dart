import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Bottom-tab shell for the whole patient side: Home · Records · Scan · Sharing · Profile.
class PatientShell extends StatelessWidget {
  const PatientShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const _items = <BottomNavigationBarItem>[
    BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
    BottomNavigationBarItem(icon: Icon(Icons.folder_outlined), activeIcon: Icon(Icons.folder), label: 'Records'),
    BottomNavigationBarItem(icon: Icon(Icons.document_scanner_outlined), activeIcon: Icon(Icons.document_scanner), label: 'Scan'),
    BottomNavigationBarItem(icon: Icon(Icons.ios_share_outlined), activeIcon: Icon(Icons.ios_share), label: 'Sharing'),
    BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: shell.currentIndex,
        onTap: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        items: _items,
      ),
    );
  }
}
