import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/env.dart';
import '../../theme.dart';
import '../../ui/widgets.dart';
import 'records_repository.dart';
import 'scan_session.dart';

class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({super.key, this.asTab = true});

  final bool asTab;

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
      ref.read(scanImageProvider.notifier).state = p.bytes;
      final id = await ref.read(recordsRepositoryProvider).upload(
            bytes: p.bytes,
            filename: p.filename,
            contentType: p.contentType,
          );
      ref.invalidate(recordsListProvider);
      // Demo: show the scanner animation first; the data that follows is static.
      if (mounted) context.push('/patient/records/$id/${Env.demo ? 'scanning' : 'review'}');
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

  /// Demo only: a built-in photo of a lab report, for when there is nothing to upload.
  Future<_Pick?> _sample() async {
    final data = await rootBundle.load('assets/demo/sample_lipid_report.png');
    return _Pick(data.buffer.asUint8List(), 'sample_lipid_report.png', 'image/png');
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
        title: const Text('Upload Record'),
        automaticallyImplyLeading: !widget.asTab,
        leading: widget.asTab ? null : BackButton(onPressed: () => context.go('/patient/records')),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            InkWell(
              onTap: _busy ? null : () => _handle(() => _fromImagePicker(ImageSource.camera)),
              borderRadius: BorderRadius.circular(16),
              child: DottedCard(
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: MediCardColors.primaryTint,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.photo_camera_outlined,
                          color: MediCardColors.primary, size: 28),
                    ),
                    const SizedBox(height: 12),
                    const Text('Tap to take a photo',
                        style: TextStyle(fontWeight: FontWeight.w700, color: MediCardColors.ink)),
                    const SizedBox(height: 4),
                    const Text('of a prescription, lab report\nor any medical document',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: MediCardColors.muted)),
                  ],
                ),
              ),
            ),
            if (Env.demo) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy ? null : () => _handle(_sample),
                icon: const Icon(Icons.bolt),
                label: const Text('Try with a sample lab report'),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed:
                  _busy ? null : () => _handle(() => _fromImagePicker(ImageSource.gallery)),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choose from Gallery'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _handle(_fromFiles),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Choose a PDF'),
            ),
            const SizedBox(height: 20),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tips for best results',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    SizedBox(height: 10),
                    _Tip('Use clear lighting'),
                    _Tip('Capture the entire document'),
                    _Tip('Avoid blur and shadows'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const InfoBanner(
              'We extract the details, then you confirm them before anything is saved as '
              'part of your record.',
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

class _Tip extends StatelessWidget {
  const _Tip(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          const Icon(Icons.check_circle, size: 16, color: MediCardColors.success),
          const SizedBox(width: 8),
          Text(text),
        ]),
      );
}

class DottedCard extends StatelessWidget {
  const DottedCard({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      decoration: BoxDecoration(
        color: MediCardColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MediCardColors.primary.withOpacity(0.4), width: 1.5),
      ),
      child: child,
    );
  }
}

class _Pick {
  _Pick(this.bytes, this.filename, this.contentType);
  final Uint8List bytes;
  final String filename;
  final String contentType;
}
