import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'records_repository.dart';

class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({super.key});

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  bool _busy = false;
  String? _error;
  String? _picked;

  Future<void> _handle(Future<_Pick?> Function() pick) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final p = await pick();
      if (p == null) {
        setState(() => _busy = false);
        return;
      }
      setState(() => _picked = p.filename);
      final id = await ref.read(recordsRepositoryProvider).upload(
            bytes: p.bytes,
            filename: p.filename,
            contentType: p.contentType,
          );
      ref.invalidate(recordsListProvider);
      if (mounted) context.go('/patient/records/$id/review');
    } on DioException catch (e) {
      setState(() => _error = e.response?.data?['detail']?.toString() ?? 'Upload failed');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<_Pick?> _fromImagePicker(ImageSource source) async {
    // Downscale + recompress on-device so uploads stay small on poor connections.
    final x = await ImagePicker().pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (x == null) return null;
    final bytes = await x.readAsBytes();
    final ct = x.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
    return _Pick(bytes, x.name, ct);
  }

  Future<_Pick?> _fromFiles() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      withData: true,
    );
    if (res == null || res.files.isEmpty || res.files.first.bytes == null) return null;
    final f = res.files.first;
    final ext = f.name.split('.').last.toLowerCase();
    final ct = ext == 'pdf'
        ? 'application/pdf'
        : ext == 'png'
            ? 'image/png'
            : 'image/jpeg';
    return _Pick(f.bytes!, f.name, ct);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add a record'),
        leading: BackButton(onPressed: () => context.go('/patient/records')),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Photograph a prescription or report. We extract the details, then you '
              'confirm them before anything is saved.',
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : () => _handle(() => _fromImagePicker(ImageSource.camera)),
              icon: const Icon(Icons.photo_camera),
              label: const Text('Take a photo'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed:
                  _busy ? null : () => _handle(() => _fromImagePicker(ImageSource.gallery)),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              icon: const Icon(Icons.photo_library),
              label: const Text('Choose an image'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _handle(_fromFiles),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Choose a PDF'),
            ),
            if (_busy) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 8),
              Center(child: Text(_picked == null ? 'Uploading...' : 'Reading $_picked...')),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }
}

class _Pick {
  _Pick(this.bytes, this.filename, this.contentType);
  final Uint8List bytes;
  final String filename;
  final String contentType;
}
