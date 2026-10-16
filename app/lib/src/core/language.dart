import 'package:flutter_riverpod/flutter_riverpod.dart';

/// true = Urdu. Drives the speech-recognition language and the Urdu labels.
final urduProvider = StateProvider<bool>((_) => false);
