import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'activation_revenue_experiment_service.dart';
import 'app_share_service.dart';
import 'landing_conversion_experiment_service.dart';

class LandingShareSnapshot {
  final int todayCount;
  final int totalCount;
  final Map<String, int> channelCounts;
  final String? lastChannel;

  const LandingShareSnapshot({
    required this.todayCount,
    required this.totalCount,
    required this.channelCounts,
    this.lastChannel,
  });

  factory LandingShareSnapshot.empty() {
    return const LandingShareSnapshot(
      todayCount: 0,
      totalCount: 0,
      channelCounts: <String, int>{},
    );
  }

  int countFor(String channel) => channelCounts[channel] ?? 0;
}

class LandingShareService {
  static const String channelX = 'x';
  static const String channelLine = 'line';
  static const String channelFacebook = 'facebook';
  static const String channelCopy = 'copy';
  static const String funnelTrialRun = 'funnel_trial_run';
  static const String funnelSaveCta = 'funnel_save_cta';
  static const String funnelMagicLinkAttempt = 'funnel_magic_link_attempt';
  static const String funnelMagicLinkSend = 'funnel_magic_link_send';
  static const String funnelMagicLinkFailInvalidEmail =
      'funnel_magic_link_fail_invalid_email';
  static const String funnelMagicLinkFailRateLimit =
      'funnel_magic_link_fail_rate_limit';
  static const String funnelMagicLinkFailDeliveryConfig =
      'funnel_magic_link_fail_delivery_config';
  static const String funnelMagicLinkFailRedirect =
      'funnel_magic_link_fail_redirect';
  static const String funnelMagicLinkFailNetwork =
      'funnel_magic_link_fail_network';
  static const String funnelMagicLinkFailUnknown =
      'funnel_magic_link_fail_unknown';
  static const String funnelGoogleOAuthStart = 'funnel_google_oauth_start';
  static const String funnelGoogleOAuthFailCancelled =
      'funnel_google_oauth_fail_cancelled';
  static const String funnelGoogleOAuthFailRateLimit =
      'funnel_google_oauth_fail_rate_limit';
  static const String funnelGoogleOAuthFailProviderConfig =
      'funnel_google_oauth_fail_provider_config';
  static const String funnelGoogleOAuthFailRedirect =
      'funnel_google_oauth_fail_redirect';
  static const String funnelGoogleOAuthFailCallbackExchange =
      'funnel_google_oauth_fail_callback_exchange';
  static const String funnelGoogleOAuthFailUnknown =
      'funnel_google_oauth_fail_unknown';
  static const String funnelInboxOpen = 'funnel_inbox_open';

  static const List<String> supportedChannels = <String>[
    channelX,
    channelLine,
    channelFacebook,
    channelCopy,
  ];

  static const Map<String, String> _incomingSourceKeys = <String, String>{
    channelX: 'x_share',
    channelLine: 'line',
    channelFacebook: 'facebook',
    channelCopy: 'copy_link',
  };

  static const Map<String, String> _shareActionKeys = <String, String>{
    channelX: 'share_x',
    channelLine: 'share_line',
    channelFacebook: 'share_facebook',
    channelCopy: 'share_copy',
  };

  static const String _dayKey = 'landing_share_stats_day';
  static const String _todayCountKey = 'landing_share_today_count';
  static const String _totalCountKey = 'landing_share_total_count';
  static const String _lastChannelKey = 'landing_share_last_channel';

  static String buildShareUrl(String channel) {
    _validateChannel(channel);
    final baseUri = Uri.parse(AppShareService.appUrl);
    final sourceKey = _incomingSourceKeys[channel]!;
    final queryParameters = Map<String, String>.from(baseUri.queryParameters)
      ..['src'] = sourceKey
      ..['utm_source'] = sourceKey
      ..['utm_medium'] = 'social'
      ..['utm_campaign'] = 'share_boost';
    return baseUri.replace(queryParameters: queryParameters).toString();
  }

  static String buildShareMessage(String channel) {
    final shareUrl = buildShareUrl(channel);
    return '''
AI提案を保存して、明日も続きから再開できます。
まずは30秒で無料体験できます。

$shareUrl

#自分株式会社
''';
  }

  static String channelLabel(String channel) {
    switch (channel) {
      case channelX:
        return 'X';
      case channelLine:
        return 'LINE';
      case channelFacebook:
        return 'Facebook';
      case channelCopy:
        return 'リンクコピー';
      default:
        return channel;
    }
  }

  static Future<void> shareLandingPage({required String channel}) async {
    _validateChannel(channel);
    final message = buildShareMessage(channel);
    final shareUrl = buildShareUrl(channel);
    switch (channel) {
      case channelX:
        await AppShareService.shareToTwitter(customMessage: message);
        return;
      case channelLine:
        await AppShareService.shareToLine(customMessage: message);
        return;
      case channelFacebook:
        await AppShareService.shareToFacebook(
          customMessage: message,
          shareUrl: shareUrl,
        );
        return;
      case channelCopy:
        await Clipboard.setData(ClipboardData(text: shareUrl));
        return;
    }
  }

  static Future<LandingShareSnapshot> loadSnapshot({
    SharedPreferences? prefs,
    DateTime? now,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    await _resetTodayCounterIfNeeded(store: store, now: now);
    return _readSnapshot(store);
  }

  static Future<LandingShareSnapshot> recordShareAction({
    required String channel,
    SupabaseClient? client,
    SharedPreferences? prefs,
    DateTime? now,
  }) async {
    _validateChannel(channel);
    final store = prefs ?? await SharedPreferences.getInstance();
    await _resetTodayCounterIfNeeded(store: store, now: now);

    final todayCount = (store.getInt(_todayCountKey) ?? 0) + 1;
    final totalCount = (store.getInt(_totalCountKey) ?? 0) + 1;
    final perChannelKey = _channelStorageKey(channel);
    final channelCount = (store.getInt(perChannelKey) ?? 0) + 1;

    await store.setInt(_todayCountKey, todayCount);
    await store.setInt(_totalCountKey, totalCount);
    await store.setInt(perChannelKey, channelCount);
    await store.setString(_lastChannelKey, channel);

    await _recordShareAnalytics(client: client, channel: channel, now: now);

    return _readSnapshot(store);
  }

  static Future<bool> recordIncomingShareVisit({
    SupabaseClient? client,
    Uri? currentUri,
    DateTime? now,
  }) async {
    final sourceKey = resolveIncomingSource(
      (currentUri ?? Uri.base).queryParameters,
    );
    if (sourceKey == null) {
      return false;
    }

    await _incrementSourceDetail(
      client: client,
      sourceKey: sourceKey,
      now: now,
    );
    return true;
  }

  static Future<void> recordFunnelEvent({
    required String eventKey,
    SupabaseClient? client,
    DateTime? now,
  }) async {
    if (!_isSupportedFunnelEvent(eventKey)) {
      throw ArgumentError.value(
        eventKey,
        'eventKey',
        'Unsupported funnel event',
      );
    }
    await _incrementSourceDetail(client: client, sourceKey: eventKey, now: now);
  }

  static String? resolveIncomingSource(Map<String, String> queryParameters) {
    final source = queryParameters['src']?.trim().toLowerCase();
    switch (source) {
      case 'x':
      case 'twitter':
      case 'x_share':
        return 'x_share';
      case 'line':
        return 'line';
      case 'facebook':
      case 'fb':
        return 'facebook';
      case 'copy':
      case 'copy_link':
      case 'share_copy':
        return 'copy_link';
      default:
        return null;
    }
  }

  static Future<void> _recordShareAnalytics({
    required SupabaseClient? client,
    required String channel,
    DateTime? now,
  }) async {
    if (client == null) {
      return;
    }

    await _incrementSourceDetail(
      client: client,
      sourceKey: _shareActionKeys[channel]!,
      now: now,
      shareIncrement: 1,
    );
  }

  static Future<void> _incrementSourceDetail({
    required SupabaseClient? client,
    required String sourceKey,
    DateTime? now,
    int shareIncrement = 0,
  }) async {
    if (client == null) {
      return;
    }

    final dateKey = _formatDate(now ?? DateTime.now());
    try {
      final response = await client.functions.invoke(
        'growth-hub',
        body: <String, dynamic>{
          'action': 'acquisition.signal',
          'signalKey': sourceKey,
          'dateKey': dateKey,
          'shareIncrement': shareIncrement,
        },
      );
      final payload = response.data;
      if (payload is Map<String, dynamic> && payload['success'] == true) {
        return;
      }
      debugPrint('Analytics Edge Function returned an unexpected payload');
    } catch (error) {
      debugPrint('Analytics Edge Function failed: $error');
    }
  }

  static Future<void> _resetTodayCounterIfNeeded({
    required SharedPreferences store,
    DateTime? now,
  }) async {
    final todayKey = _formatDate(now ?? DateTime.now());
    if (store.getString(_dayKey) == todayKey) {
      return;
    }

    await store.setString(_dayKey, todayKey);
    await store.setInt(_todayCountKey, 0);
  }

  static LandingShareSnapshot _readSnapshot(SharedPreferences store) {
    final channelCounts = <String, int>{
      for (final channel in supportedChannels)
        channel: store.getInt(_channelStorageKey(channel)) ?? 0,
    };
    return LandingShareSnapshot(
      todayCount: store.getInt(_todayCountKey) ?? 0,
      totalCount: store.getInt(_totalCountKey) ?? 0,
      channelCounts: channelCounts,
      lastChannel: store.getString(_lastChannelKey),
    );
  }

  static String _channelStorageKey(String channel) {
    return 'landing_share_channel_$channel';
  }

  static String _formatDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '${normalized.year}-$month-$day';
  }

  static void _validateChannel(String channel) {
    if (!supportedChannels.contains(channel)) {
      throw ArgumentError.value(
        channel,
        'channel',
        'Unsupported share channel',
      );
    }
  }

  static bool _isSupportedFunnelEvent(String eventKey) {
    switch (eventKey) {
      case funnelTrialRun:
      case funnelSaveCta:
      case funnelMagicLinkAttempt:
      case funnelMagicLinkSend:
      case funnelMagicLinkFailInvalidEmail:
      case funnelMagicLinkFailRateLimit:
      case funnelMagicLinkFailDeliveryConfig:
      case funnelMagicLinkFailRedirect:
      case funnelMagicLinkFailNetwork:
      case funnelMagicLinkFailUnknown:
      case funnelGoogleOAuthStart:
      case funnelGoogleOAuthFailCancelled:
      case funnelGoogleOAuthFailRateLimit:
      case funnelGoogleOAuthFailProviderConfig:
      case funnelGoogleOAuthFailRedirect:
      case funnelGoogleOAuthFailCallbackExchange:
      case funnelGoogleOAuthFailUnknown:
      case funnelInboxOpen:
        return true;
      default:
        return LandingConversionExperimentService.isExperimentEventKey(
              eventKey,
            ) ||
            ActivationRevenueExperimentService.isExperimentEventKey(eventKey);
    }
  }
}
