import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../domain/models/guitar_tab_song.dart';
import '../../../../../theme/design_tokens.dart';

/// CanvasKit 環境でもフォントメトリクスに依存せず縦棒(|)が揃う列数を算出する。
int computeGuitarTabColumnCount(List<String> lines) {
  return lines.fold<int>(
    0,
    (int maxLen, String line) => line.length > maxLen ? line.length : maxLen,
  );
}

class GuitarTabStaff extends StatelessWidget {
  const GuitarTabStaff({super.key, required this.section});

  final GuitarTabSection section;

  @override
  Widget build(BuildContext context) {
    final columnCount = computeGuitarTabColumnCount(section.lines);
    final gridMetrics = _GuitarTabGridMetrics.fromLines(
      section.lines,
      columnCount: columnCount,
    );

    return Container(
      decoration: BoxDecoration(
        color: DesignTokens.surface1,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        border: Border.all(color: DesignTokens.orange.withValues(alpha: 0.28)),
      ),
      padding: const EdgeInsets.all(DesignTokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: DesignTokens.space8,
              runSpacing: DesignTokens.space8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  section.title,
                  style: const TextStyle(
                    color: DesignTokens.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
                OutlinedButton.icon(
                  key: const Key('guitar_tab_copy_button'),
                  onPressed: () => _copyTabText(context),
                  icon: const Icon(Icons.copy_all_outlined, size: 16),
                  label: const Text('コピー'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: DesignTokens.orangeLight,
                    side: BorderSide(
                      color: DesignTokens.orange.withValues(alpha: 0.55),
                    ),
                    minimumSize: const Size(48, 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.space12,
                      vertical: DesignTokens.space8,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DesignTokens.space8),
          Text(
            section.practiceNote,
            style: const TextStyle(
              color: DesignTokens.textSecondary,
              fontSize: 13,
              height: 1.7,
            ),
          ),
          const SizedBox(height: DesignTokens.space16),
          Semantics(
            label: '${section.title}のギタータブ譜',
            value: section.lines.join('\n'),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: DesignTokens.background,
                borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                border: Border.all(color: DesignTokens.divider),
              ),
              padding: const EdgeInsets.all(DesignTokens.space12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: CustomPaint(
                  key: const Key('beatles_tab_notation'),
                  size: Size(gridMetrics.width, gridMetrics.height),
                  painter: _GuitarTabGridPainter(
                    lines: section.lines,
                    metrics: gridMetrics,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyTabText(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: section.lines.join('\n')));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('TAB譜テキストをクリップボードへコピーしました。'),
        ),
      );
  }
}

class _GuitarTabGridMetrics {
  const _GuitarTabGridMetrics({
    required this.columnCount,
    required this.isTabRows,
    required this.width,
    required this.height,
  });

  static const double cellWidth = 10.5;
  static const double stringRowHeight = 20.0;
  static const double headerRowHeight = 18.0;
  static const double padH = 12.0;
  static const double padV = 10.0;

  final int columnCount;
  final List<bool> isTabRows;
  final double width;
  final double height;

  static _GuitarTabGridMetrics fromLines(
    List<String> lines, {
    required int columnCount,
  }) {
    final isTabRows = <bool>[for (final line in lines) line.contains('|')];
    var totalRowsHeight = 0.0;
    for (final isTab in isTabRows) {
      totalRowsHeight += isTab ? stringRowHeight : headerRowHeight;
    }
    final width = math.max(
      240.0,
      padH * 2 + (columnCount > 0 ? columnCount : 1) * cellWidth,
    );
    final height = math.max(60.0, padV * 2 + totalRowsHeight);
    return _GuitarTabGridMetrics(
      columnCount: columnCount,
      isTabRows: isTabRows,
      width: width,
      height: height,
    );
  }
}

class _GuitarTabGridPainter extends CustomPainter {
  const _GuitarTabGridPainter({required this.lines, required this.metrics});

  final List<String> lines;
  final _GuitarTabGridMetrics metrics;

  double _colCenterX(int col) =>
      _GuitarTabGridMetrics.padH +
      (col + 0.5) * _GuitarTabGridMetrics.cellWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (lines.isEmpty) return;

    final stringLinePaint = Paint()
      ..color = const Color(0xFF6B7280)
      ..strokeWidth = 1.0;
    final barlinePaint = Paint()
      ..color = const Color(0xFFD1D5DB)
      ..strokeWidth = 1.4;
    final maskPaint = Paint()..color = DesignTokens.background;

    var firstTabRow = -1;
    var lastTabRow = -1;
    final rowTops = <double>[];
    var cursorY = _GuitarTabGridMetrics.padV;
    for (var i = 0; i < lines.length; i++) {
      rowTops.add(cursorY);
      final isTab = metrics.isTabRows[i];
      if (isTab) {
        if (firstTabRow == -1) firstTabRow = i;
        lastTabRow = i;
        cursorY += _GuitarTabGridMetrics.stringRowHeight;
      } else {
        cursorY += _GuitarTabGridMetrics.headerRowHeight;
      }
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final yTop = rowTops[i];
      final isTab = metrics.isTabRows[i];

      if (!isTab) {
        _paintHeaderLine(
          canvas,
          line: line,
          cy: yTop + _GuitarTabGridMetrics.headerRowHeight / 2,
        );
        continue;
      }

      final cy = yTop + _GuitarTabGridMetrics.stringRowHeight / 2;
      final pipeCols = <int>[];
      for (var c = 0; c < line.length; c++) {
        if (line[c] == '|') {
          pipeCols.add(c);
        }
      }

      if (pipeCols.isNotEmpty) {
        final startX = _colCenterX(pipeCols.first);
        final endX = pipeCols.length >= 2
            ? _colCenterX(pipeCols.last)
            : _colCenterX(math.max(line.length - 1, pipeCols.first));
        canvas.drawLine(Offset(startX, cy), Offset(endX, cy), stringLinePaint);
      }

      // 6本弦を貫く縦棒（小節線）を列番号固定で整列描画する
      final barTop = i == firstTabRow ? cy : yTop;
      final barBottom =
          i == lastTabRow ? cy : yTop + _GuitarTabGridMetrics.stringRowHeight;
      for (final pipeCol in pipeCols) {
        final bx = _colCenterX(pipeCol);
        canvas.drawLine(
          Offset(bx, barTop),
          Offset(bx, barBottom),
          barlinePaint,
        );
      }

      final firstPipe = pipeCols.isNotEmpty ? pipeCols.first : line.length;
      for (var c = 0; c < line.length; c++) {
        final ch = line[c];
        if (ch == ' ' || ch == '|' || ch == '-') continue;
        final cx = _colCenterX(c);
        final isStringName = c < firstPipe;
        if (!isStringName) {
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset(cx, cy),
              width: _GuitarTabGridMetrics.cellWidth * 0.92,
              height: 14.0,
            ),
            maskPaint,
          );
        }
        _paintGlyph(
          canvas,
          text: ch,
          center: Offset(cx, cy),
          color: isStringName
              ? DesignTokens.orangeLight
              : DesignTokens.textPrimary,
          fontSize: isStringName ? 12.0 : 12.5,
          fontWeight: FontWeight.w700,
        );
      }
    }
  }

  void _paintHeaderLine(
    Canvas canvas, {
    required String line,
    required double cy,
  }) {
    final isBeatLine = line.contains('&') || RegExp(r'^\s*\d').hasMatch(line);
    final color =
        isBeatLine ? DesignTokens.textSecondary : DesignTokens.orangeLight;
    final tokenRegex = RegExp(r'\S+');
    for (final match in tokenRegex.allMatches(line)) {
      final token = match.group(0);
      if (token == null || token.isEmpty) continue;
      final leftX = _GuitarTabGridMetrics.padH +
          match.start * _GuitarTabGridMetrics.cellWidth +
          (_GuitarTabGridMetrics.cellWidth - 7.0) / 2;
      final tp = TextPainter(
        text: TextSpan(
          text: token,
          style: TextStyle(
            color: color,
            fontSize: 11.5,
            fontWeight: isBeatLine ? FontWeight.w600 : FontWeight.w700,
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftX, cy - tp.height / 2));
    }
  }

  void _paintGlyph(
    Canvas canvas, {
    required String text,
    required Offset center,
    required Color color,
    required double fontSize,
    required FontWeight fontWeight,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(_GuitarTabGridPainter oldDelegate) {
    return !listEquals(oldDelegate.lines, lines);
  }
}
