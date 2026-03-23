import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GrowthAcquisitionService {
  static const String touchLanding = 'touch_landing';
  static const String touchImport = 'touch_import';
  static const String touchPublicMemo = 'touch_public_memo';
  static const String touchReferral = 'touch_referral';

  static const String importPreviewNotion = 'import_preview_notion';
  static const String importPreviewEvernote = 'import_preview_evernote';
  static const String importPreviewMarkdown = 'import_preview_markdown';

  static const String importSignupCta = 'import_signup_cta';
  static const String publicMemoSignupCta = 'public_memo_signup_cta';

  static const String signupSubmitLanding = 'signup_submit_landing';
  static const String signupSubmitImport = 'signup_submit_import';
  static const String signupSubmitPublicMemo = 'signup_submit_public_memo';
  static const String signupSubmitReferral = 'signup_submit_referral';

  static const String _latestTouchpointKey = 'growth_latest_touchpoint';
  static const String _latestTouchpointUpdatedAtKey =
      'growth_latest_touchpoint_updated_at';

  final SupabaseClient? _clientOverride;

  const GrowthAcquisitionService({
    SupabaseClient? clientOverride,
  }) : _clientOverride = clientOverride;

  SupabaseClient? get _client {
    if (_clientOverride != null) {
      return _clientOverride;
    }
    try {
      return Supabase.instance.client;
    } on AssertionError {
      return null;
    } catch (_) {
      return null;
    }
  }

  static String? signalForPagePath(String pagePath) {
    switch (pagePath) {
      case '/':
      case '/landing':
        return touchLanding;
      case '/import':
        return touchImport;
      case '/public-memo':
      case '/public-memos':
        return touchPublicMemo;
      default:
        return null;
    }
  }

  static String? previewSignalForSourceType(String sourceType) {
    switch (sourceType) {
      case 'notion':
        return importPreviewNotion;
      case 'evernote':
        return importPreviewEvernote;
      case 'markdown':
        return importPreviewMarkdown;
      default:
        return null;
    }
  }

  static String resolveSignupSubmitSignal(String? latestTouchpoint) {
    switch (latestTouchpoint) {
      case touchImport:
        return signupSubmitImport;
      case touchPublicMemo:
        return signupSubmitPublicMemo;
      case touchReferral:
        return signupSubmitReferral;
      default:
        return signupSubmitLanding;
    }
  }

  Future<String?> loadLatestTouchpoint() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final touchpoint = prefs.getString(_latestTouchpointKey)?.trim();
      if (touchpoint == null || touchpoint.isEmpty) {
        return null;
      }
      return touchpoint;
    } catch (error) {
      debugPrint('Growth touchpoint read failed: $error');
      return null;
    }
  }

  Future<void> recordTouchpointForPagePath(String pagePath) async {
    final signalKey = signalForPagePath(pagePath);
    if (signalKey == null) {
      return;
    }
    await _persistLatestTouchpoint(signalKey);
    await _recordSignal(signalKey);
  }

  Future<void> recordReferralTouch() async {
    await _persistLatestTouchpoint(touchReferral);
    await _recordSignal(touchReferral);
  }

  Future<void> recordImportPreview(String sourceType) async {
    final signalKey = previewSignalForSourceType(sourceType);
    if (signalKey == null) {
      return;
    }
    await _persistLatestTouchpoint(touchImport);
    await _recordSignal(signalKey);
  }

  Future<void> recordImportSignUpCta() async {
    await _persistLatestTouchpoint(touchImport);
    await _recordSignal(importSignupCta);
  }

  Future<void> recordPublicMemoSignUpCta() async {
    await _persistLatestTouchpoint(touchPublicMemo);
    await _recordSignal(publicMemoSignupCta);
  }

  Future<void> recordLandingSignupSubmit() async {
    final latestTouchpoint = await loadLatestTouchpoint();
    await _recordSignal(resolveSignupSubmitSignal(latestTouchpoint));
  }

  Future<void> _persistLatestTouchpoint(String signalKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_latestTouchpointKey, signalKey);
      await prefs.setString(
        _latestTouchpointUpdatedAtKey,
        DateTime.now().toUtc().toIso8601String(),
      );
    } catch (error) {
      debugPrint('Growth touchpoint persist failed: $error');
    }
  }

  Future<void> _recordSignal(
    String signalKey, {
    DateTime? now,
  }) async {
    final client = _client;
    if (client == null) {
      return;
    }

    final dateKey = _formatDate(now ?? DateTime.now());

    try {
      final response = await client.functions.invoke(
        'growth-acquisition-signal',
        body: <String, dynamic>{
          'signalKey': signalKey,
          'dateKey': dateKey,
        },
      );
      final payload = _asMap(response.data);
      if (payload['success'] == true) {
        return;
      }
      debugPrint(
        'Growth acquisition signal returned an unexpected payload: $payload',
      );
    } catch (error, stackTrace) {
      debugPrint('Growth acquisition signal fallback activated: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    await _recordSignalFallback(
      signalKey: signalKey,
      dateKey: dateKey,
    );
  }

  Future<void> _recordSignalFallback({
    required String signalKey,
    required String dateKey,
  }) async {
    final client = _client;
    if (client == null) {
      return;
    }

    try {
      final existing = await client
          .from('app_analytics')
          .select(
            'date, landing_views, conversions, share_count, source_details',
          )
          .eq('date', dateKey)
          .maybeSingle();

      if (existing == null) {
        await client.from('app_analytics').upsert(<String, dynamic>{
          'date': dateKey,
          'landing_views': 0,
          'conversions': 0,
          'share_count': 0,
          'source_details': <String, int>{signalKey: 1},
        });
        return;
      }

      final row = _asMap(existing);
      final sourceDetails = _normalizeSourceDetails(row['source_details'])
        ..update(signalKey, (count) => count + 1, ifAbsent: () => 1);

      await client.from('app_analytics').update(<String, dynamic>{
        'source_details': sourceDetails,
      }).eq('date', dateKey);
    } catch (error, stackTrace) {
      debugPrint('Growth acquisition fallback failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  Map<String, int> _normalizeSourceDetails(dynamic raw) {
    if (raw is! Map) {
      return <String, int>{};
    }

    final result = <String, int>{};
    raw.forEach((key, value) {
      final count = _toInt(value);
      if (count > 0) {
        result[key.toString()] = count;
      }
    });
    return result;
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  String _formatDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '${normalized.year}-$month-$day';
  }
}
