import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';

import '../../core/api_client.dart';
import 'models.dart';

class RecordsRepository {
  RecordsRepository(this._dio);

  final Dio _dio;

  Future<String> upload({
    required Uint8List bytes,
    required String filename,
    required String contentType,
  }) async {
    final parts = contentType.split('/');
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: MediaType(parts.first, parts.last),
      ),
    });
    final r = await _dio.post('/records/upload', data: form);
    return r.data['record_id'] as String;
  }

  Future<(ExtractionView, RecordData)> extract(String recordId) async {
    final r = await _dio.post('/records/$recordId/extract');
    return (
      ExtractionView.fromJson(Map<String, dynamic>.from(r.data['extraction'] as Map)),
      RecordData.fromJson(Map<String, dynamic>.from(r.data['draft'] as Map)),
    );
  }

  Future<RecordDetail> confirm({
    required String recordId,
    required String type,
    String? docDate,
    String? provider,
    required RecordData data,
  }) async {
    final r = await _dio.post('/records/$recordId/confirm', data: {
      'type': type,
      'doc_date': docDate,
      'provider': provider,
      'data': data.toJson(),
    });
    return RecordDetail.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<RecordDetail> setSensitive(String recordId, bool sensitive) async {
    final r = await _dio.post('/records/$recordId/sensitive', data: {'sensitive': sensitive});
    return RecordDetail.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<List<RecordSummary>> list() async {
    final r = await _dio.get('/records');
    return (r.data as List)
        .map((e) => RecordSummary.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<RecordDetail> get(String recordId) async {
    final r = await _dio.get('/records/$recordId');
    return RecordDetail.fromJson(Map<String, dynamic>.from(r.data as Map));
  }
}

final recordsRepositoryProvider = Provider<RecordsRepository>(
  (ref) => RecordsRepository(ref.watch(dioProvider)),
);

/// Timeline list, refreshable.
final recordsListProvider = FutureProvider.autoDispose<List<RecordSummary>>(
  (ref) => ref.watch(recordsRepositoryProvider).list(),
);
