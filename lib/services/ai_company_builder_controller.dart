import 'dart:async';

import 'package:flutter/foundation.dart';

import 'ai_company_builder_service.dart';

class AiCompanyBuilderController extends ChangeNotifier {
  AiCompanyBuilderController({required AiCompanyBuilderService service})
      : _service = service;

  final AiCompanyBuilderService _service;
  Timer? _refreshDebounce;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isControlBusy = false;
  bool _isResearchBusy = false;
  bool _disposed = false;
  String? _errorMessage;
  String? _selectedCompanyId;
  List<Map<String, dynamic>> _companies = <Map<String, dynamic>>[];
  Map<String, dynamic>? _detail;

  bool get isSignedIn => _service.isSignedIn;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  bool get isControlBusy => _isControlBusy;
  bool get isResearchBusy => _isResearchBusy;
  String? get errorMessage => _errorMessage;
  String? get selectedCompanyId => _selectedCompanyId;
  List<Map<String, dynamic>> get companies => _companies;
  Map<String, dynamic>? get detail => _detail;

  Future<void> loadCompanies() async {
    if (!isSignedIn) {
      _isLoading = false;
      _notify();
      return;
    }
    _isLoading = true;
    _errorMessage = null;
    _notify();

    try {
      final companies = await _service.listCompanies();
      final selectedId = _selectedCompanyId ??
          (companies.isNotEmpty ? companies.first['id']?.toString() : null);
      _companies = companies;
      _selectedCompanyId = selectedId;
      _isLoading = false;
      _notify();
      if (selectedId != null && selectedId.isNotEmpty) {
        await selectCompany(selectedId);
      } else {
        _detail = null;
        _notify();
      }
    } catch (error) {
      _isLoading = false;
      _errorMessage = 'Failed to load builder data: $error';
      _notify();
    }
  }

  Future<void> selectCompany(String companyId) async {
    try {
      _selectedCompanyId = companyId;
      _detail = await _service.getCompany(companyId);
      _service.subscribe(companyId, _scheduleDetailRefresh);
      _notify();
    } catch (error) {
      _errorMessage = 'Failed to load company detail: $error';
      _notify();
    }
  }

  Future<bool> bootstrap({
    required String idea,
    required double threshold,
  }) async {
    if (idea.trim().isEmpty) {
      _errorMessage = 'Enter one sentence to describe the company.';
      _notify();
      return false;
    }

    _isSubmitting = true;
    _errorMessage = null;
    _notify();
    try {
      final payload = await _service.bootstrap(
        idea: idea.trim(),
        threshold: threshold,
      );
      final company = _asMap(payload['company']);
      final companyId =
          company['id']?.toString() ?? payload['company_id']?.toString();
      _detail = payload;
      _selectedCompanyId = companyId;
      if (companyId != null && companyId.isNotEmpty) {
        _service.subscribe(companyId, _scheduleDetailRefresh);
      }
      await loadCompanies();
      return true;
    } catch (error) {
      _errorMessage = 'Bootstrap failed: $error';
      return false;
    } finally {
      _isSubmitting = false;
      _notify();
    }
  }

  Future<void> runCommand(String command) async {
    final companyId = _selectedCompanyId;
    if (companyId == null || companyId.isEmpty) return;
    _isControlBusy = true;
    _errorMessage = null;
    _notify();
    try {
      await _service.runtimeCommand(companyId: companyId, command: command);
      await _refreshSelectedDetail();
    } catch (error) {
      _errorMessage = 'Runtime command failed: $error';
    } finally {
      _isControlBusy = false;
      _notify();
    }
  }

  Future<void> setGlobalKillSwitch(bool enabled) async {
    _isControlBusy = true;
    _errorMessage = null;
    _notify();
    try {
      await _service.setGlobalKillSwitch(enabled: enabled);
      await _refreshSelectedDetail();
    } catch (error) {
      _errorMessage = 'Global kill switch failed: $error';
    } finally {
      _isControlBusy = false;
      _notify();
    }
  }

  Future<bool> addResearchSource(String sourceUrl) async {
    final companyId = _selectedCompanyId;
    if (companyId == null || companyId.isEmpty) return false;
    final trimmed = sourceUrl.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        !uri.hasScheme ||
        uri.host.isEmpty ||
        !const {'http', 'https'}.contains(uri.scheme)) {
      _errorMessage = 'Enter a valid HTTP or HTTPS source URL.';
      _notify();
      return false;
    }
    _isResearchBusy = true;
    _errorMessage = null;
    _notify();
    try {
      await _service.addResearchSource(
        companyId: companyId,
        sourceUrl: trimmed,
      );
      await _refreshSelectedDetail();
      return true;
    } catch (error) {
      _errorMessage = 'Research ingestion failed: $error';
      return false;
    } finally {
      _isResearchBusy = false;
      _notify();
    }
  }

  void _scheduleDetailRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(
      const Duration(milliseconds: 250),
      _refreshSelectedDetail,
    );
  }

  Future<void> _refreshSelectedDetail() async {
    final companyId = _selectedCompanyId;
    if (companyId == null || companyId.isEmpty || _disposed) return;
    try {
      _detail = await _service.getCompany(companyId);
      _notify();
    } catch (error) {
      _errorMessage = 'Live runtime refresh failed: $error';
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  @override
  void dispose() {
    _disposed = true;
    _refreshDebounce?.cancel();
    _refreshDebounce = null;
    unawaited(_service.dispose());
    super.dispose();
  }
}
