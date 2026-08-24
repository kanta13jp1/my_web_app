import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pdf_document_analysis.dart';
import 'offline_secure_mode_settings_service.dart';

typedef PdfDocumentInvoker = Future<Map<String, dynamic>> Function(
  Map<String, dynamic> body,
);
typedef PdfDocumentUpload = Future<void> Function(String path, Uint8List bytes);
typedef PdfDocumentRemove = Future<void> Function(String path);
typedef PdfDocumentUserIdProvider = String? Function();
typedef PdfDocumentOfflinePolicyLoader = Future<Map<String, dynamic>>
    Function();

abstract interface class PdfDocumentAnalysisGateway {
  Future<PdfDocumentSelection?> pickPdf();
  Future<PdfDocumentAnalysisResult> analyze(PdfDocumentSelection selection);
}

enum PdfDocumentAnalysisFailure { general, authenticationRequired }

class PdfDocumentAnalysisException implements Exception {
  final String message;
  final PdfDocumentAnalysisFailure failure;

  const PdfDocumentAnalysisException(
    this.message, {
    this.failure = PdfDocumentAnalysisFailure.general,
  });

  bool get requiresLogin =>
      failure == PdfDocumentAnalysisFailure.authenticationRequired;

  @override
  String toString() => message;
}

class PdfDocumentAnalysisService implements PdfDocumentAnalysisGateway {
  static const String storageBucket = 'pdf-analysis-inputs';

  final SupabaseClient? _supabase;
  final PdfDocumentInvoker? _invoker;
  final PdfDocumentUpload? _uploader;
  final PdfDocumentRemove? _remover;
  final PdfDocumentUserIdProvider? _userIdProvider;
  final PdfDocumentOfflinePolicyLoader? _offlinePolicyLoader;

  const PdfDocumentAnalysisService({
    SupabaseClient? supabase,
    PdfDocumentInvoker? invoker,
    PdfDocumentUpload? uploader,
    PdfDocumentRemove? remover,
    PdfDocumentUserIdProvider? userIdProvider,
    PdfDocumentOfflinePolicyLoader? offlinePolicyLoader,
  })  : _supabase = supabase,
        _invoker = invoker,
        _uploader = uploader,
        _remover = remover,
        _userIdProvider = userIdProvider,
        _offlinePolicyLoader = offlinePolicyLoader;

  @override
  Future<PdfDocumentSelection?> pickPdf() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['pdf'],
      allowMultiple: false,
      withData: true,
    );
    final files = result?.files;
    if (files == null || files.isEmpty) return null;
    final file = files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      throw const PdfDocumentAnalysisException(
        'PDFを読み込めませんでした。別のファイルを選んでください。',
      );
    }
    return inspectPdf(file.name, Uint8List.fromList(bytes));
  }

  static PdfDocumentSelection inspectPdf(String fileName, Uint8List bytes) {
    if (bytes.isEmpty) {
      throw const PdfDocumentAnalysisException('PDFファイルが空です。');
    }
    if (bytes.length > pdfDocumentAnalysisMaxBytes) {
      throw const PdfDocumentAnalysisException('PDFは20MB以下にしてください。');
    }
    if (bytes.length < 5 || latin1.decode(bytes.take(5).toList()) != '%PDF-') {
      throw const PdfDocumentAnalysisException('有効なPDFファイルを選択してください。');
    }
    final source = latin1.decode(bytes, allowInvalid: true);
    final explicit = RegExp(r'/Type\s*/Page\b').allMatches(source).length;
    var declared = 0;
    for (final match in RegExp(
      r'/Type\s*/Pages\b[\s\S]{0,512}?/Count\s+(\d+)',
    ).allMatches(source)) {
      final count = int.tryParse(match.group(1) ?? '') ?? 0;
      if (count > declared) declared = count;
    }
    final pageCount = explicit > declared ? explicit : declared;
    if (pageCount <= 0) {
      throw const PdfDocumentAnalysisException(
        'ページ数を安全に確認できないPDFです。別のPDFで再試行してください。',
      );
    }
    if (pageCount > pdfDocumentAnalysisMaxPages) {
      throw const PdfDocumentAnalysisException('PDFは200ページ以下にしてください。');
    }
    return PdfDocumentSelection(
      fileName: _safePdfFileName(fileName),
      bytes: bytes,
      pageCount: pageCount,
    );
  }

  @override
  Future<PdfDocumentAnalysisResult> analyze(
    PdfDocumentSelection selection,
  ) async {
    final userId =
        (_userIdProvider?.call() ?? _client.auth.currentUser?.id)?.trim();
    if (userId == null || userId.isEmpty) {
      throw const PdfDocumentAnalysisException(
        'PDFのAI解析にはログインが必要です。',
        failure: PdfDocumentAnalysisFailure.authenticationRequired,
      );
    }
    final checked = inspectPdf(selection.fileName, selection.bytes);
    if (checked.pageCount != selection.pageCount) {
      throw const PdfDocumentAnalysisException(
        'PDFのページ数が変わりました。ファイルを選び直してください。',
      );
    }
    final path = '$userId/writer-analysis/'
        '${DateTime.now().microsecondsSinceEpoch}_${checked.fileName}';
    await _upload(path, checked.bytes);
    try {
      final policy =
          await (_offlinePolicyLoader?.call() ?? _loadDefaultOfflinePolicy());
      final data = await _invoke(<String, dynamic>{
        'action': 'document.pdf.analyze',
        'storage_path': path,
        'file_name': checked.fileName,
        'confirmed_page_count': checked.pageCount,
        'format': 'markdown',
        ...policy,
      });
      if (data['success'] != true) {
        throw PdfDocumentAnalysisException(_failureMessage(data));
      }
      return PdfDocumentAnalysisResult.fromMap(data);
    } finally {
      try {
        await _remove(path);
      } catch (_) {
        // Edge Functionも削除する。ここは中断時のbest-effort回収経路。
      }
    }
  }

  SupabaseClient get _client => _supabase ?? Supabase.instance.client;

  Future<void> _upload(String path, Uint8List bytes) async {
    final uploader = _uploader;
    if (uploader != null) return uploader(path, bytes);
    await _client.storage.from(storageBucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'application/pdf',
            upsert: false,
          ),
        );
  }

  Future<void> _remove(String path) async {
    final remover = _remover;
    if (remover != null) return remover(path);
    await _client.storage.from(storageBucket).remove(<String>[path]);
  }

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    final invoker = _invoker;
    if (invoker != null) return invoker(body);
    try {
      final response = await _client.functions.invoke('ai-hub', body: body);
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return <String, dynamic>{'success': false, 'message': data?.toString()};
    } on FunctionException catch (error) {
      final details = error.details is Map
          ? Map<String, dynamic>.from(error.details as Map)
          : const <String, dynamic>{};
      return <String, dynamic>{
        'success': false,
        'code': details['code'] ?? details['error'] ?? 'http_${error.status}',
        'message': details['message'] ?? error.reasonPhrase,
      };
    }
  }

  Future<Map<String, dynamic>> _loadDefaultOfflinePolicy() async {
    const service = OfflineSecureModeSettingsService();
    final settings = await service.loadSettingsOrDefaults();
    return settings.toAiHubPolicyPayload();
  }

  String _failureMessage(Map<String, dynamic> data) {
    final code = data['code']?.toString() ?? '';
    if (code == 'feature_unavailable') {
      return 'PDF解析は現在準備中です。Writerテナントの利用確認後に有効化されます。';
    }
    if (code == 'page_count_changed') {
      return 'サーバーで確認したページ数が異なります。PDFを選び直し、料金を再確認してください。';
    }
    if (code == 'offline_secure_mode') {
      return 'オフライン保護モードでは外部AIへPDFを送信できません。';
    }
    if (code == 'budget_exceeded') {
      return 'AIの利用予算上限に達しました。時間をおいて再試行してください。';
    }
    final message = data['message']?.toString().trim() ?? '';
    return message.isEmpty ? 'PDFを解析できませんでした。' : message;
  }

  static String _safePdfFileName(String value) {
    var safe = value
        .trim()
        .replaceAll(RegExp(r'[\r\n\\/]+'), '_')
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (safe.length > 120) safe = safe.substring(safe.length - 120);
    if (safe.isEmpty) safe = 'document.pdf';
    if (!safe.toLowerCase().endsWith('.pdf')) safe = '$safe.pdf';
    return safe;
  }
}
