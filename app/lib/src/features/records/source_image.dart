import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/env.dart';

/// Renders the uploaded source document for a record. Images are shown inline;
/// PDFs and anything else fall back to a labelled chip.
class SourceImage extends ConsumerWidget {
  const SourceImage({super.key, required this.url});

  final String url;

  bool get _isImage {
    final u = url.toLowerCase();
    return u.endsWith('.png') || u.endsWith('.jpg') || u.endsWith('.jpeg');
  }

  String get _absolute =>
      url.startsWith('http') ? url : '${Env.apiBaseUrl}$url';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!_isImage) {
      return const Row(children: [
        Icon(Icons.picture_as_pdf, size: 18),
        SizedBox(width: 6),
        Text('PDF source on file'),
      ]);
    }
    return FutureBuilder<String?>(
      future: ref.read(tokenStoreProvider).accessToken,
      builder: (context, snap) {
        final headers = snap.data == null
            ? <String, String>{}
            : {'Authorization': 'Bearer ${snap.data}'};
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            _absolute,
            headers: headers,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Text('Could not load the source image.'),
            loadingBuilder: (_, child, progress) =>
                progress == null ? child : const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                ),
          ),
        );
      },
    );
  }
}
