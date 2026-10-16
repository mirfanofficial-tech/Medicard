import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../demo/demo_data.dart' show demoPatientChatQuestions;
import '../chat/chat_controller.dart';
import '../chat/chat_panel.dart';
import 'request_watcher.dart';

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
    return RequestWatcher(
        child: Scaffold(
      body: shell,
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: AskAiFab(
        onPressed: () => showChat(
          context,
          scope: const ChatScope.patient(),
          title: 'Your health assistant',
          subtitle: 'Answers from your own records',
          welcome: 'Hello! I can explain your reports, medicines, diet and next tests in simple '
              'words. What would you like to know?',
          suggestions: demoPatientChatQuestions,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: shell.currentIndex,
        onTap: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        items: _items,
      ),
    ));
  }
}
