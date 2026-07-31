import 'package:flutter/material.dart';

/// 月次資産ダッシュボード (Issue #2472) の 1 パネル。
class AssetDashboardPanel {
  /// パネル見出し。
  final String title;

  /// 本体ウィジェット。
  final Widget child;

  /// 「詳細」導線。null ならリンクを出さない。
  final VoidCallback? onOpenDetail;

  /// 導線ラベル (既定「詳細」)。
  final String detailLabel;

  const AssetDashboardPanel({
    required this.title,
    required this.child,
    this.onOpenDetail,
    this.detailLabel = '詳細',
  });
}

/// 幅からダッシュボードの列数を決める純関数。
///
/// mobile は 1 列、[breakpoint] 以上で 2 列 (= 2x2 グリッド)。
/// レイアウト判定をウィジェットから切り離して単体検証できるようにしている。
@visibleForTesting
int dashboardColumnCountFor(
  double width, {
  double breakpoint = AssetDashboardGrid.twoColumnBreakpoint,
}) {
  if (!width.isFinite || width <= 0) return 1;
  return width >= breakpoint ? 2 : 1;
}

/// 月次資産ダッシュボードの responsive グリッド (Issue #2472)。
///
/// スコープの 4 パネル (純資産 / キャッシュフロー / 投資 / アラート) を
/// mobile 1 列 / web 2x2 で並べる。**渡されたパネルだけ**を描画するため、
/// 利用できないパネルは呼び出し側が単に渡さなければよく、空セルも出ない。
class AssetDashboardGrid extends StatelessWidget {
  const AssetDashboardGrid({
    super.key,
    required this.panels,
    this.breakpoint = twoColumnBreakpoint,
    this.spacing = 16,
  });

  /// 2 列へ切り替える最小幅。
  static const double twoColumnBreakpoint = 720;

  final List<AssetDashboardPanel> panels;
  final double breakpoint;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (panels.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = dashboardColumnCountFor(
          constraints.maxWidth,
          breakpoint: breakpoint,
        );
        if (columns == 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < panels.length; i++) ...[
                if (i > 0) SizedBox(height: spacing),
                _buildPanel(context, panels[i]),
              ],
            ],
          );
        }
        return _buildTwoColumnRows(context);
      },
    );
  }

  /// 2 列レイアウト。行ごとに Row を作り、端数は空 Expanded で埋めて
  /// 最後の 1 枚が横幅いっぱいに伸びないようにする。
  Widget _buildTwoColumnRows(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < panels.length; i += 2) {
      final left = panels[i];
      final right = i + 1 < panels.length ? panels[i + 1] : null;
      if (rows.isNotEmpty) rows.add(SizedBox(height: spacing));
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildPanel(context, left)),
            SizedBox(width: spacing),
            Expanded(
              child: right == null
                  ? const SizedBox.shrink()
                  : _buildPanel(context, right),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }

  Widget _buildPanel(BuildContext context, AssetDashboardPanel panel) {
    final theme = Theme.of(context);
    return Column(
      key: Key('asset_dashboard_panel_${panel.title}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                panel.title,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ),
            if (panel.onOpenDetail != null)
              TextButton(
                key: Key('asset_dashboard_detail_${panel.title}'),
                onPressed: panel.onOpenDetail,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(panel.detailLabel),
              ),
          ],
        ),
        const SizedBox(height: 4),
        panel.child,
      ],
    );
  }
}
