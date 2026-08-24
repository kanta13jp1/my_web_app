import 'package:flutter/foundation.dart';

import '../models/pdf_document_analysis.dart';
import '../services/pdf_document_analysis_service.dart';

class PdfDocumentAnalysisViewModel extends ChangeNotifier {
  final PdfDocumentAnalysisGateway _gateway;

  PdfDocumentAnalysisViewModel({required PdfDocumentAnalysisGateway gateway})
    : _gateway = gateway;

  PdfDocumentSelection? _selection;
  PdfDocumentAnalysisResult? _result;
  String? _errorMessage;
  bool _isPicking = false;
  bool _isAnalyzing = false;
  bool _disposed = false;

  PdfDocumentSelection? get selection => _selection;
  PdfDocumentAnalysisResult? get result => _result;
  String? get errorMessage => _errorMessage;
  bool get isPicking => _isPicking;
  bool get isAnalyzing => _isAnalyzing;
  bool get isBusy => _isPicking || _isAnalyzing;

  Future<void> pickPdf() async {
    if (isBusy) return;
    _isPicking = true;
    _errorMessage = null;
    _notify();
    try {
      final selected = await _gateway.pickPdf();
      if (selected != null) {
        _selection = selected;
        _result = null;
      }
    } on PdfDocumentAnalysisException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'PDFを選択できませんでした。';
    } finally {
      _isPicking = false;
      _notify();
    }
  }

  Future<void> analyzeConfirmed() async {
    final selected = _selection;
    if (selected == null || isBusy) return;
    _isAnalyzing = true;
    _errorMessage = null;
    _result = null;
    _notify();
    try {
      _result = await _gateway.analyze(selected);
    } on PdfDocumentAnalysisException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'PDFを解析できませんでした。時間をおいて再試行してください。';
    } finally {
      _isAnalyzing = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
