import 'dart:math';

import 'package:flutter/material.dart';

import '../services/asset_cashflow_forecast_service.dart';

/// 将来 N ヶ月の月末残高予測カード。
///
/// 純関数 [AssetCashflowForecastService] の結果([AssetCashflowForecast])を
/// 受け取り、残高カーブ + ショート警告 + 前提サマリを描画する自己完結ウィジェット。
/// ページ状態へ依存しないためウィジェットテストで単体検証できる。
class AssetCashflowForecastCard extends StatelessWidget {
  const AssetCashflowForecastCard({
    super.key,
    required this.forecast,
    this.currencyFormatter,
    this.currentHorizon,
    this.availableHorizons = const [3, 6, 12],
    this.onHorizonChanged,
    this.onReviewPaymentDays,
  });

  final AssetCashflowForecast forecast;

  /// 金額整形(ページの `_formatYen` を渡す)。null なら簡易整形。
  final String Function(double value)? currencyFormatter;

  /// 現在の予測期間(月数)。null + onHorizonChanged null で切替 UI を出さない。
  final int? currentHorizon;

  /// 切替の選択肢(月数)。
  final List<int> availableHorizons;

  /// 予測期間が切り替えられたとき。null なら切替 UI を出さない。
  final ValueChanged<int>? onHorizonChanged;

  /// 「支払日を見直す」リンク。null ならリンクを出さない。
  final VoidCallback? onReviewPaymentDays;

  static const Color _accent = Color(0xFF4F46E5);
  static const Color _danger = Color(0xFFDC2626);
  static const Color _warn = Color(0xFFD97706);
  static const Color _safe = Color(0xFF059669);

  String _yen(double value) {
    final formatter = currencyFormatter;
    if (formatter != null) {
      return formatter(value);
    }
    return '¥${value.round()}';
  }

  String _monthLabel(DateTime month) => '${month.month}月';

  @override
  Widget build(BuildContext context) {
    final months = forecast.months;
    return Card(
      key: const Key('asset_cashflow_forecast_card'),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timeline, color: _accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '将来残高予測(今後${months.length}ヶ月)',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            if (onHorizonChanged != null) _buildHorizonSelector(),
            const SizedBox(height: 4),
            if (forecast.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '繰り返し収入・固定費・返済予定を登録すると、今後の残高見込みを表示します。',
                  style: TextStyle(fontSize: 12, height: 1.5),
                ),
              )
            else ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 160,
                width: double.infinity,
                // image + container + 単一 label で graphic として確実に読ませる
                // (Flutter Web の role=img の alt として全文を読み上げ)。
                child: Semantics(
                  container: true,
                  image: true,
                  label: '将来残高予測グラフ。${_chartA11yValue()}',
                  child: ExcludeSemantics(
                    child: CustomPaint(
                      key: const Key('asset_cashflow_forecast_chart'),
                      painter: _ForecastChartPainter(forecast: forecast),
                    ),
                  ),
                ),
              ),
              const Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  Text('● 月末残高', style: TextStyle(color: _accent)),
                  Text('◆ 月内最低残高', style: TextStyle(color: _danger)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('現在', style: TextStyle(fontSize: 11)),
                  Text(
                    '${months.first.month.year}/${months.first.month.month}〜'
                    '${months.last.month.year}/${months.last.month.month}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildSummary(context),
              ExpansionTile(
                key: const Key('asset_cashflow_forecast_month_details'),
                tilePadding: EdgeInsets.zero,
                title: const Text('月別内訳（月末・月内最低）'),
                children: [
                  for (final month in months)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${month.month.year}/${month.month.month} '
                          '月末 ${_yen(month.closingBalance)} / '
                          '月内最低 ${_yen(month.worstBalance)}',
                          style: TextStyle(
                            color: month.isShortfall ? _danger : null,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// スクリーンリーダー向けにグラフ内容を文章化する(視覚に依らない要約)。
  String _chartA11yValue() {
    final months = forecast.months;
    final last = months.isEmpty ? null : months.last;
    final buffer = StringBuffer('今後${months.length}ヶ月の月末残高と月内最低残高。');
    if (last != null) {
      buffer.write('${_monthLabel(last.month)}末は${_yen(last.closingBalance)}。');
    }
    buffer.write('最小見込み残高は${_yen(forecast.worstBalance)}。');
    final shortfallDate = forecast.firstShortfallDate;
    if (shortfallDate != null) {
      buffer.write('${shortfallDate.month}月${shortfallDate.day}日頃に残高不足の見込み。');
    } else if (forecast.safetyShortfallAmount > 0) {
      buffer.write('安全余裕を割り込む時期があります。');
    } else {
      buffer.write('残高不足の見込みはありません。');
    }
    return buffer.toString();
  }

  Widget _buildHorizonSelector() {
    final selected = currentHorizon ?? forecast.months.length;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 8,
        children: [
          for (final months in availableHorizons)
            ChoiceChip(
              key: Key('asset_cashflow_forecast_horizon_$months'),
              label: Text('$monthsヶ月'),
              selected: selected == months,
              onSelected: (_) => onHorizonChanged?.call(months),
            ),
        ],
      ),
    );
  }

  Widget _buildSummary(BuildContext context) {
    final shortfallDate = forecast.firstShortfallDate;
    final hasSafetyBreach =
        shortfallDate == null && forecast.safetyShortfallAmount > 0;
    final last = forecast.months.isEmpty ? null : forecast.months.last;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (shortfallDate != null)
          _buildAlert(
            alertKey: const Key('asset_cashflow_forecast_shortfall'),
            color: _danger,
            icon: Icons.warning_amber,
            message:
                '${shortfallDate.month}/${shortfallDate.day} 頃に残高が不足する見込みです。'
                '回避には ${_yen(forecast.shortfallRecoveryAmount)} の追加資金が必要です。',
          )
        else if (hasSafetyBreach)
          _buildAlert(
            alertKey: const Key('asset_cashflow_forecast_safety_breach'),
            color: _warn,
            icon: Icons.info_outline,
            message: '残高不足は回避できる見込みですが、安全余裕 ${_yen(forecast.safetyMargin)} を'
                '割り込む時期があります(最小見込み残高 ${_yen(forecast.worstBalance)})。',
          )
        else
          Row(
            children: [
              const Icon(Icons.check_circle, color: _safe, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '今後${forecast.months.length}ヶ月は残高不足の見込みはありません'
                  '(最小見込み残高 ${_yen(forecast.worstBalance)})。',
                  style: const TextStyle(fontSize: 12, height: 1.5),
                ),
              ),
            ],
          ),
        if ((shortfallDate != null || hasSafetyBreach) &&
            onReviewPaymentDays != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('asset_cashflow_forecast_review_payment_days'),
              onPressed: onReviewPaymentDays,
              icon: const Icon(Icons.event_repeat, size: 16),
              label: const Text('支払日を見直す(マネーカレンダー)'),
            ),
          ),
        const SizedBox(height: 8),
        if (last != null)
          Text(
            '${_monthLabel(last.month)}末の見込み残高: ${_yen(last.closingBalance)}',
            style: const TextStyle(
              fontSize: 12,
              height: 1.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        const SizedBox(height: 2),
        Text(
          '現金・預金 ${_yen(forecast.startingBalance)} を起点に、繰り返し収入・固定費・返済予定を'
          '毎月積み上げた見込みです。未登録の入出金は含まれません。',
          style: TextStyle(
            fontSize: 11,
            height: 1.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildAlert({
    required Key alertKey,
    required Color color,
    required IconData icon,
    required String message,
  }) {
    // liveRegion + 明示 label: 警告の出現/変化を本文そのままで読み上げる
    // (内側 Text は ExcludeSemantics で重複排除し、アナウンス内容を固定)。
    return Semantics(
      liveRegion: true,
      container: true,
      label: message,
      child: ExcludeSemantics(
        child: Container(
          key: alertKey,
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ForecastChartPainter extends CustomPainter {
  const _ForecastChartPainter({required this.forecast});

  final AssetCashflowForecast forecast;

  @override
  void paint(Canvas canvas, Size size) {
    final closings = forecast.months
        .map((month) => month.closingBalance)
        .toList(growable: false);
    final series = <double>[forecast.startingBalance, ...closings];
    final lows = <double>[
      forecast.startingBalance,
      ...forecast.months.map((month) => month.worstBalance),
    ];
    if (series.length < 2) {
      return;
    }

    final reference = <double>[0, forecast.safetyMargin];
    var minValue = [...series, ...lows, ...reference].reduce(min);
    var maxValue = [...series, ...lows, ...reference].reduce(max);
    if ((maxValue - minValue).abs() < 1) {
      maxValue += 1;
      minValue -= 1;
    }
    final range = maxValue - minValue;

    const leftPad = 8.0;
    const rightPad = 8.0;
    const topPad = 8.0;
    const bottomPad = 8.0;
    final chartWidth = size.width - leftPad - rightPad;
    final chartHeight = size.height - topPad - bottomPad;

    double xFor(int index) =>
        leftPad + chartWidth * index / (series.length - 1);
    double yFor(double value) =>
        topPad + chartHeight * (1 - (value - minValue) / range);

    // 0 円ライン。
    final zeroPaint = Paint()
      ..color = const Color(0xFF9CA3AF)
      ..strokeWidth = 1;
    final zeroY = yFor(0);
    canvas.drawLine(
      Offset(leftPad, zeroY),
      Offset(size.width - rightPad, zeroY),
      zeroPaint,
    );
    final zeroLabel = TextPainter(
      text: const TextSpan(
        text: '0円',
        style: TextStyle(color: Color(0xFF4B5563), fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    zeroLabel.paint(canvas, Offset(leftPad, max(0, zeroY - 14)));
    zeroLabel.dispose();

    // 安全線(0 と異なる場合のみ)。
    if (forecast.safetyMargin.abs() >= 1) {
      final safePaint = Paint()
        ..color = const Color(0xFF059669)
        ..strokeWidth = 1;
      final safeY = yFor(forecast.safetyMargin);
      for (double x = leftPad; x < size.width - rightPad; x += 8) {
        canvas.drawLine(
          Offset(x, safeY),
          Offset(min(x + 4, size.width - rightPad), safeY),
          safePaint,
        );
      }
    }

    // 残高ポリライン。
    final linePaint = Paint()
      ..color = const Color(0xFF4F46E5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(xFor(0), yFor(series.first));
    for (var i = 1; i < series.length; i++) {
      path.lineTo(xFor(i), yFor(series[i]));
    }
    canvas.drawPath(path, linePaint);

    // 月内の谷も同じ縦軸に描く。月末に回復しても不足を隠さない。
    final lowPath = Path()..moveTo(xFor(0), yFor(lows.first));
    for (var i = 1; i < lows.length; i++) {
      lowPath.lineTo(xFor(i), yFor(lows[i]));
    }
    canvas.drawPath(
      lowPath,
      Paint()
        ..color = const Color(0xFFDC2626)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );
    for (var i = 1; i < lows.length; i++) {
      final x = xFor(i);
      final y = yFor(lows[i]);
      final diamond = Path()
        ..moveTo(x, y - 4)
        ..lineTo(x + 4, y)
        ..lineTo(x, y + 4)
        ..lineTo(x - 4, y)
        ..close();
      canvas.drawPath(diamond, Paint()..color = const Color(0xFFDC2626));
    }

    // 月末残高の点は凡例と同色。月内不足は赤い最低残高で表す。
    for (var i = 0; i < series.length; i++) {
      final value = series[i];
      final pointPaint = Paint()
        ..color = const Color(0xFF4F46E5)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(xFor(i), yFor(value)), 3, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ForecastChartPainter oldDelegate) =>
      oldDelegate.forecast != forecast;
}
