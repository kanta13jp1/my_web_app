import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SelfTouchDisclosure {
  const SelfTouchDisclosure({
    required this.version,
    required this.title,
    required this.body,
    required this.supportLabel,
    required this.supportUrl,
  });

  final String version;
  final String title;
  final String body;
  final String supportLabel;
  final Uri supportUrl;

  static final SelfTouchDisclosure fallback = SelfTouchDisclosure(
    version: '2026-09-03-v1',
    title: '記録を始める前に',
    body: 'この機能は自己観察を助けるもので、医療上の診断や治療ではありません。'
        '記録回数だけで疾患や重症度を判断しません。心身の不調が続く場合や、'
        '自分を傷つける心配がある場合は、医療機関や公的な相談窓口に相談してください。',
    supportLabel: '厚生労働省「まもろうよ こころ」相談窓口',
    supportUrl: Uri.parse(
      'https://www.mhlw.go.jp/mamorouyokokoro/soudan/',
    ),
  );

  static SelfTouchDisclosure? fromJson(Map<String, dynamic> json) {
    final version = json['version']?.toString().trim() ?? '';
    final title = json['title']?.toString().trim() ?? '';
    final body = json['body']?.toString().trim() ?? '';
    final supportLabel = json['support_label']?.toString().trim() ?? '';
    final supportUrl = Uri.tryParse(json['support_url']?.toString() ?? '');
    if (version.isEmpty ||
        title.isEmpty ||
        body.isEmpty ||
        supportLabel.isEmpty ||
        supportUrl == null ||
        supportUrl.scheme != 'https') {
      return null;
    }
    return SelfTouchDisclosure(
      version: version,
      title: title,
      body: body,
      supportLabel: supportLabel,
      supportUrl: supportUrl,
    );
  }
}

class SelfTouchConsentStore {
  SelfTouchConsentStore._();

  static const String localVersionKey = 'self_touch_consent_version';
  static const String localConsentedAtKey = 'self_touch_consented_at';

  static Future<SelfTouchDisclosure> loadDisclosure({
    SupabaseClient? client,
  }) async {
    final resolvedClient = client ?? _currentClientOrNull();
    if (resolvedClient == null) {
      return SelfTouchDisclosure.fallback;
    }

    try {
      final dynamic raw = await resolvedClient
          .from('self_touch_disclosures')
          .select('version,title,body,support_label,support_url')
          .eq('is_active', true)
          .order('effective_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (raw is Map<String, dynamic>) {
        return SelfTouchDisclosure.fromJson(raw) ??
            SelfTouchDisclosure.fallback;
      }
    } catch (error) {
      debugPrint('SelfTouchConsentStore disclosure fallback: $error');
    }
    return SelfTouchDisclosure.fallback;
  }

  static Future<bool> hasCurrentConsent({
    required String version,
    SharedPreferences? preferences,
    SupabaseClient? client,
  }) async {
    final store = preferences ?? await SharedPreferences.getInstance();
    final localConsent = store.getString(localVersionKey) == version &&
        DateTime.tryParse(store.getString(localConsentedAtKey) ?? '') != null;
    final resolvedClient = client ?? _currentClientOrNull();
    final user = resolvedClient?.auth.currentUser;
    if (resolvedClient == null || user == null) {
      return localConsent;
    }

    try {
      final dynamic raw = await resolvedClient
          .from('self_touch_tracking_consents')
          .select('consent_version,consent_granted,consented_at')
          .eq('user_id', user.id)
          .maybeSingle();
      if (raw is! Map<String, dynamic> ||
          raw['consent_granted'] != true ||
          raw['consent_version']?.toString() != version ||
          DateTime.tryParse(raw['consented_at']?.toString() ?? '') == null) {
        return false;
      }
      await store.setString(localVersionKey, version);
      await store.setString(
        localConsentedAtKey,
        raw['consented_at'].toString(),
      );
      return true;
    } catch (error) {
      debugPrint('SelfTouchConsentStore consent lookup fallback: $error');
      return localConsent;
    }
  }

  static Future<DateTime> grantConsent({
    required String version,
    SharedPreferences? preferences,
    SupabaseClient? client,
    DateTime? now,
  }) async {
    final consentedAt = (now ?? DateTime.now()).toUtc();
    final resolvedClient = client ?? _currentClientOrNull();
    final user = resolvedClient?.auth.currentUser;
    if (resolvedClient != null && user != null) {
      await resolvedClient.from('self_touch_tracking_consents').upsert({
        'user_id': user.id,
        'consent_version': version,
        'consent_granted': true,
        'consented_at': consentedAt.toIso8601String(),
        'updated_at': consentedAt.toIso8601String(),
      });
    }

    final store = preferences ?? await SharedPreferences.getInstance();
    await store.setString(localVersionKey, version);
    await store.setString(localConsentedAtKey, consentedAt.toIso8601String());
    return consentedAt;
  }

  static SupabaseClient? _currentClientOrNull() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }
}
