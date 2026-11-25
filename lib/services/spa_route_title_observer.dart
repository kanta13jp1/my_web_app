import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../utils/feature_route_labels.dart';
import '../utils/route_document_title.dart';

typedef SpaDocumentTitleSetter = void Function(String title);

/// SPA の各ルートに対応するブラウザタブ表示名 (`document.title`) を解決する (#2726)。
class SpaRouteTitleResolver {
  SpaRouteTitleResolver._();

  static const String appTitleSuffix = '自分株式会社';
  static const String defaultTitle = '自分株式会社 — AI統合ライフマネジメント';

  static const Map<String, String> _extraRouteLabels = <String, String>{
    '/home': 'ホーム',
    '/login': 'ログイン',
    '/landing': 'ランディング',
    '/price-tracker': '価格トラッカー',
    '/settings': '設定',
    '/admin': '管理コンソール',
    '/tasks': 'タスク管理',
    '/ai-university': 'AI大学',
    '/ai-assistant': 'AIアシスタント',
    '/career-monthly-kpi': 'キャリア月次KPI',
    '/chro-office': 'CHROオフィス',
    '/edge-functions': 'Edge Functions',
    '/agent-performance-monitor': 'エージェント監視',
    '/mental-health-tracker': 'メンタルヘルス記録',
    '/public-memo': '公開メモ',
  };

  static String resolve(String? routeName) {
    final normalized = normalizeRoutePath(routeName ?? '/');
    if (normalized == '/' ||
        normalized == '/philosophy' ||
        normalized == '/vibe-sim-lab') {
      return documentTitleForRoute(normalized);
    }
    final canonical = canonicalFeatureRoutePath(normalized);
    final extraLabel = _extraRouteLabels[canonical];
    final rawLabel = (extraLabel != null && extraLabel.isNotEmpty)
        ? extraLabel
        : featureLabelForRoute(canonical).trim();
    if (rawLabel.isEmpty || rawLabel == '/') {
      return defaultTitle;
    }
    if (rawLabel.contains(appTitleSuffix)) {
      return rawLabel;
    }
    return '$rawLabel | $appTitleSuffix';
  }
}

/// 画面遷移ごとにブラウザタブタイトルと現在のルートパスを同期する Observer (#2726)。
class SpaRouteTitleObserver extends NavigatorObserver {
  SpaRouteTitleObserver({
    SpaDocumentTitleSetter? onTitleChanged,
    this.syncSystemChrome = true,
  }) : _onTitleChanged = onTitleChanged;

  final SpaDocumentTitleSetter? _onTitleChanged;
  final bool syncSystemChrome;

  final ValueNotifier<String> currentTitle =
      ValueNotifier<String>(SpaRouteTitleResolver.defaultTitle);
  final ValueNotifier<String> currentRoutePath = ValueNotifier<String>('/');

  void applyRouteName(String? routeName) {
    final normalized = normalizeRoutePath(routeName ?? '/');
    final resolvedTitle = SpaRouteTitleResolver.resolve(normalized);

    void updateValues() {
      currentRoutePath.value = normalized;
      currentTitle.value = resolvedTitle;
      _onTitleChanged?.call(resolvedTitle);
      if (syncSystemChrome) {
        try {
          unawaited(
            SystemChrome.setApplicationSwitcherDescription(
              ApplicationSwitcherDescription(label: resolvedTitle),
            ).catchError((Object _) {}),
          );
        } catch (_) {
          // Non-web/headless bindings may ignore or throw; fail open.
        }
      }
    }

    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => updateValues());
    } else {
      updateValues();
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    applyRouteName(route.settings.name);
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) {
      applyRouteName(newRoute.settings.name);
    }
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) {
      applyRouteName(previousRoute.settings.name);
    }
    super.didPop(route, previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) {
      applyRouteName(previousRoute.settings.name);
    }
    super.didRemove(route, previousRoute);
  }
}

final SpaRouteTitleObserver spaRouteTitleObserver = SpaRouteTitleObserver();
