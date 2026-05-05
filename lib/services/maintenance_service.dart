import 'package:supabase_flutter/supabase_flutter.dart';

class MaintenanceServiceException implements Exception {
  MaintenanceServiceException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'MaintenanceServiceException($statusCode): $message';
}

class MaintenanceWindow {
  const MaintenanceWindow({
    required this.id,
    required this.scope,
    required this.affectedFeatures,
    required this.startsAt,
    required this.endsAt,
    required this.noticeDaysBefore,
    required this.messageJa,
    this.messageEn,
    required this.severity,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String scope;
  final List<String> affectedFeatures;
  final DateTime startsAt;
  final DateTime endsAt;
  final int noticeDaysBefore;
  final String messageJa;
  final String? messageEn;
  final String severity;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isSystem => scope == 'system';

  bool get isActive {
    final now = DateTime.now();
    return !now.isBefore(startsAt) && now.isBefore(endsAt);
  }

  DateTime get bannerVisibleFrom =>
      startsAt.subtract(Duration(days: noticeDaysBefore));

  String get displayMessage =>
      messageJa.trim().isEmpty ? 'システムメンテナンスを予定しています。' : messageJa.trim();

  bool affectsRoute(String routePath) {
    if (isSystem) return true;
    final normalized = normalizeFeatureKey(routePath);
    return affectedFeatures.map(normalizeFeatureKey).any(
          (feature) => feature == normalized || normalized.startsWith(feature),
        );
  }

  Map<String, dynamic> toPayload() {
    return {
      if (id.isNotEmpty) 'id': id,
      'scope': scope,
      'affected_features': affectedFeatures,
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt.toUtc().toIso8601String(),
      'notice_days_before': noticeDaysBefore,
      'message_ja': messageJa,
      'message_en': messageEn,
      'severity': severity,
    };
  }

  factory MaintenanceWindow.fromJson(Map<String, dynamic> json) {
    return MaintenanceWindow(
      id: json['id']?.toString() ?? '',
      scope: json['scope']?.toString() == 'feature' ? 'feature' : 'system',
      affectedFeatures: _asStringList(json['affected_features']),
      startsAt: _parseDate(json['starts_at']) ?? DateTime.now(),
      endsAt: _parseDate(json['ends_at']) ?? DateTime.now(),
      noticeDaysBefore: _asInt(json['notice_days_before'], fallback: 3),
      messageJa: json['message_ja']?.toString() ?? '',
      messageEn: json['message_en']?.toString(),
      severity: _normalizeSeverity(json['severity']),
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }
}

class MaintenanceSnapshot {
  const MaintenanceSnapshot({
    required this.windows,
    required this.fetchedAt,
  });

  final List<MaintenanceWindow> windows;
  final DateTime fetchedAt;

  MaintenanceWindow? blockingWindowFor(String routePath) {
    if (_isAdminRoute(routePath)) return null;
    for (final window in windows) {
      if (window.isActive && window.affectsRoute(routePath)) {
        return window;
      }
    }
    return null;
  }

  List<MaintenanceWindow> visibleBannersFor(String routePath) {
    if (_isAdminRoute(routePath)) return const [];
    return windows.where((window) {
      return window.affectsRoute(routePath);
    }).toList(growable: false);
  }
}

class MaintenanceService {
  MaintenanceService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  static const cacheTtl = Duration(minutes: 5);
  static MaintenanceSnapshot? _activeCache;

  final SupabaseClient _client;

  Future<MaintenanceSnapshot> fetchActive({bool force = false}) async {
    final cached = _activeCache;
    if (!force &&
        cached != null &&
        DateTime.now().difference(cached.fetchedAt) < cacheTtl) {
      return cached;
    }
    final data = await _invoke('maintenance.list_active', {
      'now': DateTime.now().toUtc().toIso8601String(),
    });
    final windows = _asList(data['windows'])
        .map((item) => MaintenanceWindow.fromJson(_asMap(item)))
        .toList(growable: false);
    final snapshot = MaintenanceSnapshot(
      windows: windows,
      fetchedAt: DateTime.now(),
    );
    _activeCache = snapshot;
    return snapshot;
  }

  Future<List<MaintenanceWindow>> listWindows() async {
    final data = await _invoke('maintenance.list', {});
    return _asList(data['windows'])
        .map((item) => MaintenanceWindow.fromJson(_asMap(item)))
        .toList(growable: false);
  }

  Future<MaintenanceWindow> createWindow(MaintenanceWindow window) async {
    final data = await _invoke('maintenance.create', window.toPayload());
    _activeCache = null;
    return MaintenanceWindow.fromJson(_asMap(data['window']));
  }

  Future<MaintenanceWindow> updateWindow(MaintenanceWindow window) async {
    final data = await _invoke('maintenance.update', window.toPayload());
    _activeCache = null;
    return MaintenanceWindow.fromJson(_asMap(data['window']));
  }

  Future<void> deleteWindow(String id) async {
    await _invoke('maintenance.delete', {'id': id});
    _activeCache = null;
  }

  Future<Map<String, dynamic>> _invoke(
    String action,
    Map<String, dynamic> params,
  ) async {
    final res = await _client.functions.invoke(
      'schedule-hub',
      body: {'action': action, ...params},
    );
    final data = _asMap(res.data);
    if (res.status != 200 || data['success'] == false) {
      final message = data['error']?.toString() ?? 'HTTP ${res.status}';
      throw MaintenanceServiceException(message, statusCode: res.status);
    }
    return data;
  }
}

String normalizeFeatureKey(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceFirst(RegExp(r'^/+'), '')
      .split('?')
      .first;
}

bool _isAdminRoute(String routePath) {
  final normalized = normalizeFeatureKey(routePath);
  return normalized == 'admin' ||
      normalized.startsWith('admin/') ||
      normalized == 'admin-feedback' ||
      normalized == 'blog-management' ||
      normalized == 'quota-dashboard';
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return <String, dynamic>{};
}

List<dynamic> _asList(Object? value) {
  return value is List ? value : const [];
}

List<String> _asStringList(Object? value) {
  if (value is List) {
    return value.map((item) => item.toString()).toList(growable: false);
  }
  return const [];
}

int _asInt(Object? value, {required int fallback}) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

DateTime? _parseDate(Object? value) {
  final text = value?.toString();
  return text == null || text.isEmpty ? null : DateTime.tryParse(text);
}

String _normalizeSeverity(Object? value) {
  final text = value?.toString();
  return text == 'critical' || text == 'warning' ? text! : 'info';
}
