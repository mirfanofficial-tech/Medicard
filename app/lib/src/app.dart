import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme.dart';

class MediCardApp extends ConsumerWidget {
  const MediCardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'MediCard',
      debugShowCheckedModeBanner: false,
      theme: buildMediCardTheme(),
      routerConfig: router,
    );
  }
}
