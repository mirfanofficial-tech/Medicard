import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/env.dart';
import 'demo/demo_bar.dart';
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
      builder: (context, child) => Stack(children: [
        child ?? const SizedBox.shrink(),
        if (Env.demo)
          const Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Center(child: DemoBar()),
          ),
      ]),
    );
  }
}
