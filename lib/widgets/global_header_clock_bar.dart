import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_version.dart';

class GlobalHeaderClockShell extends StatelessWidget {
  final Widget child;

  const GlobalHeaderClockShell({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          const GlobalHeaderClockBar(),
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
  const GlobalHeaderClockBar({super.key});

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

  @override
  Widget build(BuildContext context) {
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
                            onTap: () => Navigator.of(context)
                                .pushNamed('/release-notes'),
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
