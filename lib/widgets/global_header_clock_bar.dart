import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_version.dart';
import '../pages/release_notes_page.dart';

class GlobalHeaderClockShell extends StatelessWidget {
  final Widget child;

  /// 公開ページでは内部アプリ向けの時計・ビルド情報を表示しない。
  ///
  /// 既定値は既存の認証済み画面と単体利用を壊さないため `true` のままにし、
  /// アプリ直下で認証状態に応じて明示的に切り替える。
  final bool showClockBar;

  /// アプリ直下の Navigator を指す key。本シェルは `MaterialApp.builder` で
  /// Navigator より上に置かれるため、`Navigator.of(context)` は祖先 Navigator を
  /// 見つけられず release ビルドで null-check 例外になる。バージョンバッジ等の
  /// 遷移はこの key を使う。
  final GlobalKey<NavigatorState>? navigatorKey;

  const GlobalHeaderClockShell({
    super.key,
    required this.child,
    this.navigatorKey,
    this.showClockBar = true,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          if (showClockBar) GlobalHeaderClockBar(navigatorKey: navigatorKey),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class GlobalHeaderClockBar extends StatefulWidget {
  const GlobalHeaderClockBar({super.key, this.navigatorKey});

  /// アプリ直下の Navigator を指す key(リリースノート等の遷移に使う)。
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  State<GlobalHeaderClockBar> createState() => _GlobalHeaderClockBarState();
}

class _GlobalHeaderClockBarState extends State<GlobalHeaderClockBar> {
  late DateTime _now;
  Timer? _timer;
  bool _showVersionTooltip = false;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// リリースノート画面へ遷移する。本バーは `MaterialApp.builder` で Navigator より
  /// 上に置かれるため、`Navigator.of(context)`(release で `navigator!` の null-check
  /// 例外)を避け、アプリ直下の [GlobalHeaderClockBar.navigatorKey] を優先して使う。
  /// key 未指定時のみ `Navigator.maybeOf`(無ければ no-op)へフォールバック。
  void _openReleaseNotes() {
    // 本バーは Navigator より上(MaterialApp.builder)にあるため、ダイアログは
    // アプリ直下 Navigator を含む navigatorKey の context 上で開く。未指定時のみ
    // ローカル context へフォールバック(Navigator が無ければ何もしない)。
    final dialogContext = widget.navigatorKey?.currentContext ??
        (Navigator.maybeOf(context) != null ? context : null);
    if (dialogContext == null) return;
    showReleaseNotesDialog(dialogContext);
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < 600) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;
    final backgroundColor =
        isDark ? const Color(0xFF0B1220) : const Color(0xFFF4F7FF);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);
    final labelColor = isDark
        ? Colors.white70
        : const Color(0xFF607D8B).withValues(alpha: 0.85);
    final clockText = DateFormat('yyyy/MM/dd HH:mm:ss').format(_now);
    final versionText = AppVersion.display;
    final versionBadgeBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : accent.withValues(alpha: 0.08);
    final versionBadgeBorder = isDark
        ? Colors.white.withValues(alpha: 0.18)
        : accent.withValues(alpha: 0.24);
    final versionBadgeFg =
        isDark ? Colors.white.withValues(alpha: 0.85) : accent;

    return Container(
      key: const Key('global_header_clock_bar'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          bottom: BorderSide(color: borderColor),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 36,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.schedule, size: 16, color: accent),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '今日の日付と時刻',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: labelColor,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                MouseRegion(
                  onEnter: (_) => setState(() => _showVersionTooltip = true),
                  onExit: (_) => setState(() => _showVersionTooltip = false),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Semantics(
                        label: 'Release Notes $versionText',
                        button: true,
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            key: const Key('global_header_version_badge'),
                            borderRadius: BorderRadius.circular(10),
                            onTap: _openReleaseNotes,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: versionBadgeBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: versionBadgeBorder,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                versionText,
                                key: const Key('global_header_version_text'),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: versionBadgeFg,
                                  height: 1.4,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_showVersionTooltip)
                        Positioned(
                          bottom: 32,
                          left: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF2D3748)
                                  : Colors.black87,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              AppVersion.isDev
                                  ? 'Release Notes (dev build)'
                                  : 'Release Notes',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  clockText,
                  key: const Key('global_header_clock_text'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
