import 'package:intl/intl.dart';

import '../../models/admin_growth_evidence.dart';
import '../../pages/admin_dashboard_signals.dart';

class AdminFunnelMetrics {
  final int trialRuns;
  final int saveClicks;
  final int magicLinkSends;
  final int inboxOpens;

  const AdminFunnelMetrics({
    required this.trialRuns,
    required this.saveClicks,
    required this.magicLinkSends,
    required this.inboxOpens,
  });

  static const AdminFunnelMetrics empty = AdminFunnelMetrics(
    trialRuns: 0,
    saveClicks: 0,
    magicLinkSends: 0,
    inboxOpens: 0,
  );
}

class AdminDailyStatsAggregate {
  const AdminDailyStatsAggregate({
    required this.sourceBreakdown,
    required this.shareChannelBreakdown,
    required this.acquisitionEvidence,
    required this.chartData,
    required this.maxDailyViews,
    required this.totalShares,
    required this.todayRegistrations,
    required this.effectiveTodayViews,
    required this.effectiveTotalLpViews,
    required this.todaySummaryCvr,
    required this.todayFunnel,
    required this.totalFunnel,
    required this.totalBillingFunnel,
    required this.total30DayRegistrations,
    required this.todayDropBeforeTrial,
    required this.totalDropBeforeTrial,
    required this.zeroRegistrationStreakDays,
    required this.zeroStreakAtCap,
    required this.averageViewsLast7Days,
  });

  factory AdminDailyStatsAggregate.empty() {
    return const AdminDailyStatsAggregate(
      sourceBreakdown: <String, int>{},
      shareChannelBreakdown: <String, int>{},
      acquisitionEvidence: <AdminAcquisitionCohortEvidence>[],
      chartData: <Map<String, dynamic>>[],
      maxDailyViews: 0,
      totalShares: 0,
      todayRegistrations: 0,
      effectiveTodayViews: 0,
      effectiveTotalLpViews: 0,
      todaySummaryCvr: 0,
      todayFunnel: AdminFunnelMetrics.empty,
      totalFunnel: AdminFunnelMetrics.empty,
      totalBillingFunnel: AdminBillingFunnelMetrics(
        billingViews: 0,
        upgradeClicks: 0,
        checkoutSuccesses: 0,
        checkoutCancels: 0,
      ),
      total30DayRegistrations: 0,
      todayDropBeforeTrial: 0,
      totalDropBeforeTrial: 0,
      zeroRegistrationStreakDays: 0,
      zeroStreakAtCap: false,
      averageViewsLast7Days: 0,
    );
  }

  final Map<String, int> sourceBreakdown;
  final Map<String, int> shareChannelBreakdown;
  final List<AdminAcquisitionCohortEvidence> acquisitionEvidence;
  final List<Map<String, dynamic>> chartData;
  final int maxDailyViews;
  final int totalShares;
  final int todayRegistrations;
  final int effectiveTodayViews;
  final int effectiveTotalLpViews;
  final double todaySummaryCvr;
  final AdminFunnelMetrics todayFunnel;
  final AdminFunnelMetrics totalFunnel;
  final AdminBillingFunnelMetrics totalBillingFunnel;
  final int total30DayRegistrations;
  final int todayDropBeforeTrial;
  final int totalDropBeforeTrial;
  final int zeroRegistrationStreakDays;
  final bool zeroStreakAtCap;
  final double averageViewsLast7Days;
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

String _dateKey(DateTime date) =>
    DateFormat('yyyy-MM-dd').format(DateTime(date.year, date.month, date.day));

String? _normalizeDateKey(dynamic value) {
  if (value == null) return null;
  final raw = value.toString().trim();
  if (raw.isEmpty) return null;

  final parsed = DateTime.tryParse(raw);
  if (parsed != null) {
    return _dateKey(parsed.toLocal());
  }

  return raw.length >= 10 ? raw.substring(0, 10) : raw;
}

bool isAdminFunnelEventKey(String key) {
  return key.startsWith('funnel_') ||
      key.startsWith('lp_exp_') ||
      key.startsWith('activation_exp_');
}

bool isAdminShareActionKey(String key) {
  switch (key) {
    case 'share_x':
    case 'share_line':
    case 'share_facebook':
    case 'share_copy':
    case 'share_note':
    case 'public_memo_share':
    case 'public_memo_copy':
      return true;
    default:
      return false;
  }
}

AdminFunnelMetrics extractAdminFunnelMetrics(Map<String, int> sources) {
  return AdminFunnelMetrics(
    trialRuns: sources['funnel_trial_run'] ?? 0,
    saveClicks: sources['funnel_save_cta'] ?? 0,
    magicLinkSends: sources['funnel_magic_link_send'] ?? 0,
    inboxOpens: sources['funnel_inbox_open'] ?? 0,
  );
}

AdminBillingFunnelMetrics extractAdminBillingFunnelMetrics(
  Map<String, int> sources,
) {
  return AdminBillingFunnelMetrics(
    billingViews: sources['funnel_billing_view'] ?? 0,
    upgradeClicks: sources['funnel_upgrade_click'] ?? 0,
    checkoutSuccesses: sources['funnel_checkout_success'] ?? 0,
    checkoutCancels: sources['funnel_checkout_cancel'] ?? 0,
  );
}

int countConsecutiveNoRegistrationDays(List<Map<String, dynamic>> stats) {
  var streak = 0;
  for (final stat in stats) {
    if (_toInt(stat['conversions']) > 0) {
      break;
    }
    streak += 1;
  }
  return streak;
}

double averageAdminViews(List<Map<String, dynamic>> stats, {int days = 7}) {
  final window = stats.take(days).toList();
  if (window.isEmpty) {
    return 0;
  }
  final total = window.fold<int>(
    0,
    (sum, stat) => sum + _toInt(stat['landing_views']),
  );
  return total / window.length;
}

AdminDailyStatsAggregate computeAdminDailyStatsAggregate({
  required List<Map<String, dynamic>> dailyStats,
  required int lpTodayViews,
  required int lpTotalViews,
  required bool hasLpViewStats,
  required DateTime now,
}) {
  var analyticsViews = 0;
  var totalShares = 0;
  final sourceBreakdown = <String, int>{};
  final shareChannelBreakdown = <String, int>{};
  final funnelBreakdown = <String, int>{};
  final todaySourceDetails = <String, int>{};
  final todayKey = _dateKey(now);
  var todayViews = 0;
  var todayRegistrations = 0;
  var maxDailyViews = 0;

  for (final stat in dailyStats) {
    final views = _toInt(stat['landing_views']);
    final conv = _toInt(stat['conversions']);
    final statDateKey = _normalizeDateKey(stat['date']);

    analyticsViews += views;
    totalShares += _toInt(stat['share_count']);

    if (statDateKey == todayKey) {
      todayViews = views;
      todayRegistrations = conv;
    }
    if (views > maxDailyViews) {
      maxDailyViews = views;
    }

    final sources = stat['source_details'];
    if (sources != null && sources is Map) {
      sources.forEach((key, value) {
        final count = _toInt(value);
        if (count > 0) {
          final sourceKey = key.toString();
          if (statDateKey == todayKey) {
            todaySourceDetails[sourceKey] =
                (todaySourceDetails[sourceKey] ?? 0) + count;
          }
          final target = isAdminFunnelEventKey(sourceKey)
              ? funnelBreakdown
              : isAdminShareActionKey(sourceKey)
                  ? shareChannelBreakdown
                  : sourceBreakdown;
          target[sourceKey] = (target[sourceKey] ?? 0) + count;
        }
      });
    }
  }

  final acquisitionEvidence = adminAcquisitionEvidenceFromAggregateSignals(
    sourceBreakdown,
  );
  final chartData = dailyStats.reversed.toList(growable: false);
  final effectiveTodayViews = hasLpViewStats ? lpTodayViews : todayViews;
  final effectiveTotalLpViews = hasLpViewStats ? lpTotalViews : analyticsViews;
  final double todaySummaryCvr = effectiveTodayViews == 0
      ? 0
      : (todayRegistrations / effectiveTodayViews * 100);
  final todayFunnel = extractAdminFunnelMetrics(todaySourceDetails);
  final totalFunnel = extractAdminFunnelMetrics(funnelBreakdown);
  final totalBillingFunnel = extractAdminBillingFunnelMetrics(funnelBreakdown);
  final total30DayRegistrations = dailyStats.fold<int>(
    0,
    (sum, stat) => sum + _toInt(stat['conversions']),
  );
  final todayDropBeforeTrial = effectiveTodayViews > todayFunnel.trialRuns
      ? effectiveTodayViews - todayFunnel.trialRuns
      : 0;
  final totalDropBeforeTrial = effectiveTotalLpViews > totalFunnel.trialRuns
      ? effectiveTotalLpViews - totalFunnel.trialRuns
      : 0;
  final zeroRegistrationStreakDays = countConsecutiveNoRegistrationDays(
    dailyStats,
  );
  final zeroStreakAtCap = streakAtWindowCap(
    zeroRegistrationStreakDays,
    dailyStats.length,
  );
  final averageViewsLast7Days = averageAdminViews(dailyStats);

  return AdminDailyStatsAggregate(
    sourceBreakdown: Map<String, int>.unmodifiable(sourceBreakdown),
    shareChannelBreakdown: Map<String, int>.unmodifiable(shareChannelBreakdown),
    acquisitionEvidence:
        List<AdminAcquisitionCohortEvidence>.unmodifiable(acquisitionEvidence),
    chartData: List<Map<String, dynamic>>.unmodifiable(chartData),
    maxDailyViews: maxDailyViews,
    totalShares: totalShares,
    todayRegistrations: todayRegistrations,
    effectiveTodayViews: effectiveTodayViews,
    effectiveTotalLpViews: effectiveTotalLpViews,
    todaySummaryCvr: todaySummaryCvr,
    todayFunnel: todayFunnel,
    totalFunnel: totalFunnel,
    totalBillingFunnel: totalBillingFunnel,
    total30DayRegistrations: total30DayRegistrations,
    todayDropBeforeTrial: todayDropBeforeTrial,
    totalDropBeforeTrial: totalDropBeforeTrial,
    zeroRegistrationStreakDays: zeroRegistrationStreakDays,
    zeroStreakAtCap: zeroStreakAtCap,
    averageViewsLast7Days: averageViewsLast7Days,
  );
}
