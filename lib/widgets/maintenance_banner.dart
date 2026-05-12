import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:my_web_app/pages/maintenance_mode_page.dart';
import 'package:my_web_app/services/maintenance_service.dart';
import 'package:my_web_app/services/universal_x_share_service.dart';

class MaintenanceShell extends StatefulWidget {
  const MaintenanceShell({
    super.key,
    required this.routeListenable,
    required this.child,
    this.service,
  });

  final ValueListenable<UniversalSharePageContext> routeListenable;
  final Widget child;
  final MaintenanceService? service;

  @override
  State<MaintenanceShell> createState() => _MaintenanceShellState();
}

class _MaintenanceShellState extends State<MaintenanceShell> {
  late final MaintenanceService _service;
  Timer? _timer;
  MaintenanceSnapshot _snapshot = MaintenanceSnapshot(
    windows: const [],
    fetchedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );
  final Set<String> _dismissedIds = <String>{};

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? MaintenanceService();
    _refresh(force: true);
    _timer = Timer.periodic(MaintenanceService.cacheTtl, (_) {
      _refresh(force: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool force = false}) async {
    try {
      final snapshot = await _service.fetchActive(force: force);
      if (!mounted) return;
      setState(() => _snapshot = snapshot);
    } catch (_) {
      // Maintenance lookup must never block the normal application render path.
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UniversalSharePageContext>(
      valueListenable: widget.routeListenable,
      builder: (context, page, _) {
        final routePath = page.routePath;
        final blocking = _snapshot.blockingWindowFor(routePath);
        final visibleBanners = _snapshot
            .visibleBannersFor(routePath)
            .where((window) => !_dismissedIds.contains(window.id))
            .toList(growable: false);
        return Column(
          children: [
            if (blocking == null && visibleBanners.isNotEmpty)
              MaintenanceBanner(
                window: visibleBanners.first,
                onDismiss: () {
                  setState(() => _dismissedIds.add(visibleBanners.first.id));
                },
              ),
            Expanded(
              child: blocking == null
                  ? widget.child
                  : MaintenanceModePage(window: blocking),
            ),
          ],
        );
      },
    );
  }
}

class MaintenanceBanner extends StatelessWidget {
  const MaintenanceBanner({
    super.key,
    required this.window,
    required this.onDismiss,
  });

  final MaintenanceWindow window;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = _bannerColors(window.severity);
    final starts = window.startsAt.toLocal();
    final ends = window.endsAt.toLocal();
    return SafeArea(
      bottom: false,
      child: Material(
        color: colors.background,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: colors.foreground, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${_formatDateTime(starts)}-${_formatTime(ends)} '
                  '${window.isSystem ? '全体' : window.affectedFeatures.join(', ')} '
                  'メンテナンス予定: ${window.displayMessage}',
                  style: TextStyle(
                    color: colors.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: '閉じる',
                icon: Icon(Icons.close, color: colors.foreground),
                onPressed: onDismiss,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BannerColors {
  const _BannerColors({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;
}

_BannerColors _bannerColors(String severity) {
  switch (severity) {
    case 'critical':
      return const _BannerColors(
        background: Color(0xFFFFEBEE),
        foreground: Color(0xFFB71C1C),
        border: Color(0xFFE57373),
      );
    case 'warning':
      return const _BannerColors(
        background: Color(0xFFFFF8E1),
        foreground: Color(0xFF8A4B00),
        border: Color(0xFFFFB74D),
      );
    default:
      return const _BannerColors(
        background: Color(0xFFE3F2FD),
        foreground: Color(0xFF0D47A1),
        border: Color(0xFF64B5F6),
      );
  }
}

String _formatDateTime(DateTime value) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${value.year}/${two(value.month)}/${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)}';
}

String _formatTime(DateTime value) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(value.hour)}:${two(value.minute)}';
}
