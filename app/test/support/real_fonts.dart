import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the real Roboto + Material Icons fonts so layout tests measure text like a
/// device does (flutter_test otherwise draws every glyph as a wide square).
Future<void> loadRealFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final root = Platform.environment['FLUTTER_ROOT'] ?? 'D:/flutter';
  final dir = '$root/bin/cache/artifacts/material_fonts';
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    var any = false;
    for (final f in files) {
      final file = File('$dir/$f');
      if (file.existsSync()) {
        loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
        any = true;
      }
    }
    if (any) await loader.load();
  }

  await family('Roboto', [
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf',
    'roboto-black.ttf',
    'roboto-light.ttf',
  ]);
  await family('MaterialIcons', ['materialicons-regular.otf']);
}
