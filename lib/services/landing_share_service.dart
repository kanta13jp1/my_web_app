import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_share_service.dart';

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
  static const String funnelMagicLinkSend = 'funnel_magic_link_send';
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

    await _recordShareAnalytics(
      client: client,
      channel: channel,
      now: now,
    );

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
    await _incrementSourceDetail(
      client: client,
      sourceKey: eventKey,
      now: now,
    );
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

    try {
      await client.rpc('increment_share_count');
    } catch (error) {
      debugPrint('Share count rpc failed: $error');
    }

    await _incrementSourceDetail(
      client: client,
      sourceKey: _shareActionKeys[channel]!,
      now: now,
      fallbackShareCount: 1,
    );
  }

  static Future<void> _incrementSourceDetail({
    required SupabaseClient? client,
    required String sourceKey,
    DateTime? now,
    int fallbackShareCount = 0,
  }) async {
    if (client == null) {
      return;
    }

    final dateKey = _formatDate(now ?? DateTime.now());
    final currentRow =
        await _fetchAnalyticsRow(client: client, dateKey: dateKey);
    final sourceDetails = _normalizeSourceDetails(currentRow?['source_details'])
      ..update(sourceKey, (count) => count + 1, ifAbsent: () => 1);

    try {
      if (currentRow == null) {
        await client.from('app_analytics').upsert(<String, dynamic>{
          'date': dateKey,
          'landing_views': 0,
          'conversions': 0,
          'share_count': fallbackShareCount,
          'source_details': sourceDetails,
        });
        return;
      }

      await client.from('app_analytics').update(<String, dynamic>{
        'source_details': sourceDetails,
      }).eq('date', dateKey);
    } catch (error) {
      debugPrint('Share analytics update failed: $error');
    }
  }

  static Future<Map<String, dynamic>?> _fetchAnalyticsRow({
    required SupabaseClient client,
    required String dateKey,
  }) async {
    try {
      final raw = await client
          .from('app_analytics')
          .select(
            'date, landing_views, conversions, share_count, source_details',
          )
          .eq('date', dateKey)
          .limit(1);
      if (raw.isNotEmpty) {
        return Map<String, dynamic>.from(raw.first);
      }
    } catch (error) {
      debugPrint('Share analytics fetch failed: $error');
    }
    return null;
  }

  static Map<String, int> _normalizeSourceDetails(dynamic raw) {
    if (raw is! Map) {
      return <String, int>{};
    }

    final result = <String, int>{};
    raw.forEach((key, value) {
      final count = value is num ? value.toInt() : 0;
      if (count > 0) {
        result[key.toString()] = count;
      }
    });
    return result;
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
      case funnelMagicLinkSend:
      case funnelInboxOpen:
        return true;
      default:
        return false;
    }
  }
}
