import 'package:flutter/material.dart';

import '../services/asset_net_worth_panel_service.dart';

/// 純資産パネル (Issue #2473)。
///
/// 純サービス [AssetNetWorthPanelService] の結果 ([AssetNetWorthPanel]) を受け取り、
/// 「純資産」「前月比 ±¥ / ±%」「直近6月のミニスパークライン」を描画する
/// 自己完結ウィジェット。ページ状態へ依存しないため単体検証できる。
class AssetNetWorthPanelCard extends StatelessWidget {
  const AssetNetWorthPanelCard({
    super.key,
    required this.panel,
    this.currencyFormatter,
  });

  final AssetNetWorthPanel panel;

  /// 金額整形 (ページの `_formatYen` を渡す)。null なら簡易整形。
  final String Function(double value)? currencyFormatter;

  static const Color _positive = Color(0xFF0D9488);
  static const Color _negative = Color(0xFFB91C1C);
  static const Color _accent = Color(0xFF2563EB);
  static const Color _muted = Color(0xFF6B7280);

  String _yen(double v) {
    final f = currencyFormatter;
    if (f != null) return f(v);
    return '¥${v.round()}';
  }

  String _signedYen(double v) => '${v >= 0 ? '+' : '-'}${_yen(v.abs())}';

  String _monthLabel(String monthKey) {
    final parts = monthKey.split('-');
    if (parts.length < 2) return monthKey;
    final m = int.tryParse(parts[1]);
    return m == null ? monthKey : '$m月';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!panel.hasData) return const SizedBox.shrink();

    final net = panel.netWorth!;
    final netColor = net < 0 ? _negative : _positive;

    return Card(
      key: const Key('asset_net_worth_panel_card'),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.savings_outlined, color: _accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '純資産',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (panel.monthKey != null)
                  Text(
                    _monthLabel(panel.monthKey!),
                    style: theme.textTheme.labelSmall?.copyWith(color: _muted),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '資産合計 − 負債合計',
              style: theme.textTheme.bodySmall?.copyWith(color: _muted),
            ),
            const SizedBox(height: 12),
            Text(
              _yen(net),
              key: const Key('asset_net_worth_value'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: netColor,
              ),
            ),
            const SizedBox(height: 8),
            _buildDeltaRow(theme),
            if (panel.positiveAssetTotal != null &&
                panel.liabilityTotal != null) ...[
              const SizedBox(height: 10),
              _buildBreakdown(theme),
            ],
            if (panel.hasSparkline) ...[
              const SizedBox(height: 14),
              _buildSparkline(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeltaRow(ThemeData theme) {
    if (!panel.hasDelta) {
      return Text(
        '前月のデータが無いため前月比を表示できません。',
        key: const Key('asset_net_worth_delta_missing'),
        style: theme.textTheme.bodySmall?.copyWith(color: _muted),
      );
    }
    final delta = panel.deltaAmount!;
    final color = delta >= 0 ? _positive : _negative;
    return Row(
      key: const Key('asset_net_worth_delta'),
      children: [
        Icon(
          delta >= 0 ? Icons.trending_up : Icons.trending_down,
          size: 18,
          color: color,
        ),
        const SizedBox(width: 6),
        Text(
          '前月比 ',
          style: theme.textTheme.bodySmall?.copyWith(color: _muted),
        ),
        Text(
          _signedYen(delta),
          style: theme.textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w700, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          panel.hasDeltaPercent
              ? '(${panel.deltaPercent! >= 0 ? '+' : ''}'
                  '${panel.deltaPercent!.toStringAsFixed(1)}%)'
              : '(—)',
          key: const Key('asset_net_worth_delta_percent'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: panel.hasDeltaPercent ? color : _muted,
          ),
        ),
      ],
    );
  }

  Widget _buildBreakdown(ThemeData theme) {
    return Row(
      children: [
        _chip(theme, '資産', _yen(panel.positiveAssetTotal!), _positive),
        const SizedBox(width: 8),
        _chip(theme, '負債', _yen(panel.liabilityTotal!), _negative),
      ],
    );
  }

  Widget _chip(ThemeData theme, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label ',
            style: theme.textTheme.labelSmall?.copyWith(color: _muted),
          ),
          Text(
            value,
            style: theme.textTheme.labelSmall
                ?.copyWith(fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildSparkline(ThemeData theme) {
    final first = panel.sparkline.first;
    final last = panel.sparkline.last;
    final rising = last.netWorth >= first.netWorth;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '直近${panel.sparkline.length}か月の推移',
          style: theme.textTheme.labelSmall?.copyWith(color: _muted),
        ),
        const SizedBox(height: 6),
        SizedBox(
          key: const Key('asset_net_worth_sparkline'),
          height: 44,
          width: double.infinity,
          child: CustomPaint(
            painter: _NetWorthSparklinePainter(
              values: [for (final p in panel.sparkline) p.netWorth],
              color: rising ? _positive : _negative,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _monthLabel(first.monthKey),
              style: theme.textTheme.labelSmall?.copyWith(color: _muted),
            ),
            Text(
              _monthLabel(last.monthKey),
              style: theme.textTheme.labelSmall?.copyWith(color: _muted),
            ),
          ],
        ),
      ],
    );
  }
}

/// 外部依存なしのミニスパークライン描画。
class _NetWorthSparklinePainter extends CustomPainter {
  _NetWorthSparklinePainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.width <= 0 || size.height <= 0) return;

    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final span = maxV - minV;
    // 全点が同値だと span=0 → 0 除算になるため中央に water line を引く。
    final flat = span.abs() < 1e-9;

    final dx = size.width / (values.length - 1);
    Offset pointAt(int i) {
      final y = flat
          ? size.height / 2
          : size.height - ((values[i] - minV) / span) * size.height;
      return Offset(dx * i, y);
    }

    final path = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var i = 1; i < values.length; i++) {
      final p = pointAt(i);
      path.lineTo(p.dx, p.dy);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // 最終点を強調。
    final lastP = pointAt(values.length - 1);
    canvas.drawCircle(lastP, 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _NetWorthSparklinePainter old) =>
      old.color != color || !_sameValues(old.values, values);

  static bool _sameValues(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
