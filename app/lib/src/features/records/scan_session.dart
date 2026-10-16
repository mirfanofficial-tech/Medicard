import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The picture the patient just scanned or chose. Kept in memory so the scanner
/// animation and the review screen can show it next to what was read from it.
final scanImageProvider = StateProvider<Uint8List?>((_) => null);
