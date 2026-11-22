import 'package:flutter/material.dart';

import '../../../../../domain/models/structured_guitar_tab.dart';
import '../../../../../theme/design_tokens.dart';

/// 構造化TAB譜をレスポンシブ段組みで描画するウィジェット。
/// 音符・休符・スラッシュ・反復・セーニョ・コーダ等はすべてベクター図形で描画します。
class StructuredTabScoreView extends StatefulWidget {
  const StructuredTabScoreView({
    super.key,
    required this.score,
    required this.lightSheet,
    this.activeMeasureIndex,
    this.activeBeatIndex,
    this.onMeasureTap,
    this.rowKeys,
    this.autoScrollToActive = false,
  });

  final StructuredGuitarTabScore score;
  final bool lightSheet;
  final int? activeMeasureIndex;
  final int? activeBeatIndex;
  final ValueChanged<int>? onMeasureTap;
  final Map<int, GlobalKey>? rowKeys;
  final bool autoScrollToActive;

  @override
  State<StructuredTabScoreView> createState() => _StructuredTabScoreViewState();
}

class _StructuredTabScoreViewState extends State<StructuredTabScoreView> {
  final Map<int, GlobalKey> _internalRowKeys = <int, GlobalKey>{};
  int? _lastAutoScrolledRow;

  GlobalKey _keyForRow(int rowIdx) {
    final external = widget.rowKeys?[rowIdx];
    if (external != null) return external;
    return _internalRowKeys.putIfAbsent(rowIdx, GlobalKey.new);
  }

  void _maybeScrollToActiveRow(int? activeRowIdx, GlobalKey? rowKey) {
    if (!widget.autoScrollToActive) {
      _lastAutoScrolledRow = null;
      return;
    }
    if (activeRowIdx == null || rowKey == null) return;
    if (_lastAutoScrolledRow == activeRowIdx) return;
    _lastAutoScrolledRow = activeRowIdx;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final rowContext = rowKey.currentContext;
      if (rowContext == null || !rowContext.mounted) return;
      if (Scrollable.maybeOf(rowContext) == null) return;
      Scrollable.ensureVisible(
        rowContext,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        alignment: 0.25,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.score.measures.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final availableWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 760.0;
        final measuresPerRow = availableWidth >= 760
            ? 4
            : availableWidth >= 460
                ? 2
                : 1;

        final rows = <List<int>>[];
        int? activeRowIdx;
        GlobalKey? activeRowKey;
        for (var i = 0; i < widget.score.measures.length; i += measuresPerRow) {
          final end = (i + measuresPerRow < widget.score.measures.length)
              ? i + measuresPerRow
              : widget.score.measures.length;
          final rowIdx = rows.length;
          final slice = <int>[for (var idx = i; idx < end; idx++) idx];
          if (widget.activeMeasureIndex != null &&
              slice.contains(widget.activeMeasureIndex)) {
            activeRowIdx = rowIdx;
            activeRowKey = _keyForRow(rowIdx);
          }
          rows.add(slice);
        }

        _maybeScrollToActiveRow(activeRowIdx, activeRowKey);

        return Column(
          key: const Key('structured_tab_score_canvas'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (var rowIdx = 0; rowIdx < rows.length; rowIdx++) ...<Widget>[
              _StructuredTabRow(
                key: widget.autoScrollToActive || widget.rowKeys != null
                    ? _keyForRow(rowIdx)
                    : null,
                score: widget.score,
                measureIndices: rows[rowIdx],
                measuresPerRow: measuresPerRow,
                width: availableWidth,
                lightSheet: widget.lightSheet,
                activeMeasureIndex: widget.activeMeasureIndex,
                activeBeatIndex: widget.activeBeatIndex,
                onMeasureTap: widget.onMeasureTap,
              ),
              if (rowIdx != rows.length - 1)
                const SizedBox(height: DesignTokens.space12),
            ],
          ],
        );
      },
    );
  }
}

class _StructuredTabRow extends StatelessWidget {
  const _StructuredTabRow({
    super.key,
    required this.score,
    required this.measureIndices,
    required this.measuresPerRow,
    required this.width,
    required this.lightSheet,
    this.activeMeasureIndex,
    this.activeBeatIndex,
    this.onMeasureTap,
  });

  static const double _rowHeight = 196.0;

  final StructuredGuitarTabScore score;
  final List<int> measureIndices;
  final int measuresPerRow;
  final double width;
  final bool lightSheet;
  final int? activeMeasureIndex;
  final int? activeBeatIndex;
  final ValueChanged<int>? onMeasureTap;

  @override
  Widget build(BuildContext context) {
    final layout = _SystemRowGeometry.compute(
      score: score,
      measureIndices: measureIndices,
      slotCount: measuresPerRow,
      width: width,
    );

    final painter = _StructuredTabRowPainter(
      score: score,
      geometry: layout,
      lightSheet: lightSheet,
      activeMeasureIndex: activeMeasureIndex,
      activeBeatIndex: activeBeatIndex,
    );

    final paintWidget = CustomPaint(
      size: Size(width, _rowHeight),
      painter: painter,
    );

    if (onMeasureTap == null) {
      return paintWidget;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (TapUpDetails details) {
        final dx = details.localPosition.dx;
        for (final slot in layout.slots) {
          if (dx >= slot.left && dx <= slot.right) {
            onMeasureTap!(slot.globalMeasureIndex);
            return;
          }
        }
      },
      child: paintWidget,
    );
  }
}

class _MeasureSlotGeometry {
  const _MeasureSlotGeometry({
    required this.globalMeasureIndex,
    required this.left,
    required this.right,
    required this.contentLeft,
    required this.contentRight,
  });

  final int globalMeasureIndex;
  final double left;
  final double right;
  final double contentLeft;
  final double contentRight;
}

class _SystemRowGeometry {
  const _SystemRowGeometry({
    required this.clefRight,
    required this.staffRight,
    required this.slots,
  });

  final double clefRight;
  final double staffRight;
  final List<_MeasureSlotGeometry> slots;

  static const double clefWidth = 22.0;
  static const double timeSigWidth = 18.0;

  static _SystemRowGeometry compute({
    required StructuredGuitarTabScore score,
    required List<int> measureIndices,
    required int slotCount,
    required double width,
  }) {
    final hasTimeSig = measureIndices.isNotEmpty &&
        score.measures[measureIndices.first].number == 1;
    final prefixWidth = clefWidth + (hasTimeSig ? timeSigWidth : 0.0);
    final safeWidth = width > prefixWidth + 40 ? width : prefixWidth + 40;
    final totalMeasureArea = safeWidth - prefixWidth - 4.0;
    final slotWidth = totalMeasureArea / slotCount;

    final slots = <_MeasureSlotGeometry>[];
    for (var i = 0; i < measureIndices.length; i++) {
      final globalIdx = measureIndices[i];
      final left = prefixWidth + i * slotWidth;
      final right = left + slotWidth;
      final measure = score.measures[globalIdx];
      final leftInset = measure.repeatStart ? 12.0 : 8.0;
      final rightInset = measure.repeatEnd ? 12.0 : 8.0;
      slots.add(
        _MeasureSlotGeometry(
          globalMeasureIndex: globalIdx,
          left: left,
          right: right,
          contentLeft: left + leftInset,
          contentRight: right - rightInset,
        ),
      );
    }

    final staffRight =
        slots.isNotEmpty ? slots.last.right : prefixWidth + slotWidth;
    return _SystemRowGeometry(
      clefRight: clefWidth,
      staffRight: staffRight,
      slots: slots,
    );
  }
}

class _StructuredTabRowPainter extends CustomPainter {
  const _StructuredTabRowPainter({
    required this.score,
    required this.geometry,
    required this.lightSheet,
    this.activeMeasureIndex,
    this.activeBeatIndex,
  });

  static const double _staffTop = 96.0;
  static const double _stringSpacing = 10.0;
  static const double _staffBottom = _staffTop + 5 * _stringSpacing;
  static const double _stemBottomY = _staffBottom + 34.0;

  final StructuredGuitarTabScore score;
  final _SystemRowGeometry geometry;
  final bool lightSheet;
  final int? activeMeasureIndex;
  final int? activeBeatIndex;

  double _stringY(int stringIndex) {
    // 0=6弦(下段), 5=1弦(上段)
    return _staffTop + (5 - stringIndex) * _stringSpacing;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final bgColor = lightSheet ? Colors.white : DesignTokens.background;
    final inkColor =
        lightSheet ? const Color(0xFF111827) : DesignTokens.textOnDark;
    final lineColor =
        lightSheet ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563);
    final barlineColor =
        lightSheet ? const Color(0xFF111827) : DesignTokens.textSecondary;
    const accentColor = DesignTokens.orange;
    final markTextColor =
        lightSheet ? const Color(0xFF111827) : DesignTokens.textPrimary;

    final slots = geometry.slots;
    if (slots.isEmpty) return;

    // 1. 再生中ハイライト背景
    for (final slot in slots) {
      if (slot.globalMeasureIndex == activeMeasureIndex) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(
              slot.left + 1,
              _staffTop - 16,
              slot.right - 1,
              _stemBottomY + 6,
            ),
            const Radius.circular(6),
          ),
          Paint()..color = accentColor.withValues(alpha: 0.14),
        );
      }
    }

    // 2. 6本弦（TAB線）
    final stringPaint = Paint()
      ..color = lineColor
      ..strokeWidth = 0.85;
    for (var s = 0; s < 6; s++) {
      final y = _staffTop + s * _stringSpacing;
      canvas.drawLine(
        Offset(0, y),
        Offset(geometry.staffRight, y),
        stringPaint,
      );
    }

    // 左端閉じる線
    canvas.drawLine(
      const Offset(0.5, _staffTop),
      const Offset(0.5, _staffBottom),
      Paint()
        ..color = barlineColor
        ..strokeWidth = 1.2,
    );

    // 3. TAB クレフ（T / A / B）
    _drawTabClef(canvas, inkColor);

    // 4. 先頭段のみ拍子記号（4/4）
    final firstMeasure = score.measures[slots.first.globalMeasureIndex];
    if (firstMeasure.number == 1) {
      _drawTimeSignature(
        canvas,
        x: geometry.clefRight + 8.0,
        topNumber: score.beatsPerMeasure,
        bottomNumber: score.beatUnit,
        color: inkColor,
      );
    }

    // 5. 各小節の描画（垂直レーン分離で重なりを防止）
    for (var sIdx = 0; sIdx < slots.length; sIdx++) {
      final slot = slots[sIdx];
      final measure = score.measures[slot.globalMeasureIndex];
      final isLastMeasure =
          slot.globalMeasureIndex == score.measures.length - 1;
      final nextMeasureIndex = slot.globalMeasureIndex + 1;
      final nextStartsSection = nextMeasureIndex < score.measures.length &&
          ((score.measures[nextMeasureIndex].boxedRehearsalMark &&
                  score.measures[nextMeasureIndex].rehearsalMark != null) ||
              score.measures[nextMeasureIndex].hasCoda);

      // 小節左端の線またはリピート開始
      if (measure.repeatStart) {
        _drawRepeatStart(canvas, slot.left, barlineColor);
      } else if (sIdx > 0 || firstMeasure.number == 1) {
        canvas.drawLine(
          Offset(slot.left, _staffTop),
          Offset(slot.left, _staffBottom),
          Paint()
            ..color = barlineColor
            ..strokeWidth = 1.0,
        );
      }

      // 小節右端の線・リピート終了・セクション複縦線・終止複縦線
      if (measure.repeatEnd) {
        _drawRepeatEnd(canvas, slot.right, barlineColor);
      } else if (isLastMeasure) {
        _drawFinalDoubleBar(canvas, slot.right, barlineColor);
      } else if (nextStartsSection) {
        _drawSectionDoubleBar(canvas, slot.right, barlineColor);
      } else {
        canvas.drawLine(
          Offset(slot.right, _staffTop),
          Offset(slot.right, _staffBottom),
          Paint()
            ..color = barlineColor
            ..strokeWidth = 1.0,
        );
      }

      // Lane 1 (y=4..24): リハーサルマーク・1/2番カッコ
      if (measure.rehearsalMark != null) {
        _drawRehearsalMark(
          canvas,
          mark: measure.rehearsalMark!,
          boxed: measure.boxedRehearsalMark,
          offset: Offset(slot.left + 2, 4),
          color: markTextColor,
        );
      }
      if (measure.volta != null) {
        _drawVoltaBracket(
          canvas,
          left: slot.left,
          right: slot.right,
          label: measure.volta!,
          drawRightHook:
              measure.repeatEnd || measure.volta!.trim().startsWith('1'),
          color: barlineColor,
        );
      }

      // Lane 2 (y=26..42): セーニョ・コーダ・ナビゲーション指示
      if (measure.hasSegno) {
        _drawSegno(canvas, center: Offset(slot.left + 12, 33), color: inkColor);
      }
      if (measure.hasCoda) {
        _drawCoda(canvas, center: Offset(slot.left + 14, 33), color: inkColor);
      }
      if (measure.topNote != null) {
        final hasSymbolPrefix = measure.hasSegno || measure.hasCoda;
        final topStyle = TextStyle(
          color: markTextColor,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        );
        if (hasSymbolPrefix) {
          _paintText(
            canvas,
            text: measure.topNote!,
            offset: Offset(slot.left + 26, 27),
            style: topStyle,
          );
        } else {
          final tp = TextPainter(
            text: TextSpan(text: measure.topNote, style: topStyle),
            textDirection: TextDirection.ltr,
          )..layout();
          final desiredX = slot.right - 4.0 - tp.width;
          final safeX = desiredX > slot.left + 4.0 ? desiredX : slot.left + 4.0;
          tp.paint(canvas, Offset(safeX, 27));
        }
      }

      // Lane 3 (y=46..60): 小節頭コード名
      if (measure.chordSymbol != null) {
        _paintText(
          canvas,
          text: measure.chordSymbol!,
          offset: Offset(slot.left + 6, 46),
          style: TextStyle(
            color: markTextColor,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        );
      }

      // Lane 5 (y=78..92): 小節番号
      _paintText(
        canvas,
        text: '${measure.number}',
        offset: Offset(slot.left + 3, _staffTop - 16),
        style: TextStyle(
          color: lightSheet ? const Color(0xFF4B5563) : const Color(0xFF9CA3AF),
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      );

      // 小節内の拍イベント配置（音価に応じた横幅配分）
      _drawMeasureBeats(
        canvas,
        measure: measure,
        slot: slot,
        bgColor: bgColor,
        inkColor: inkColor,
        accentColor: accentColor,
      );
    }
  }

  void _drawMeasureBeats(
    Canvas canvas, {
    required StructuredTabMeasure measure,
    required _MeasureSlotGeometry slot,
    required Color bgColor,
    required Color inkColor,
    required Color accentColor,
  }) {
    final beats = measure.beats;
    if (beats.isEmpty) return;

    final totalUnits = beats.fold<double>(
      0.0,
      (double sum, StructuredTabBeat beat) => sum + beat.duration.beatUnits,
    );
    final safeUnits = totalUnits > 0 ? totalUnits : 1.0;
    final span = (slot.contentRight - slot.contentLeft).clamp(24.0, 2000.0);

    final beatXs = <double>[];
    var cursorUnits = 0.0;
    for (final beat in beats) {
      final frac = cursorUnits / safeUnits;
      // 左端に寄りすぎないよう微小余白を確保
      final x = slot.contentLeft + 8.0 + frac * (span - 14.0);
      beatXs.add(x);
      cursorUnits += beat.duration.beatUnits;
    }

    // 拍ごとの個別要素描画
    for (var bIdx = 0; bIdx < beats.length; bIdx++) {
      final beat = beats[bIdx];
      final x = beatXs[bIdx];
      final isActiveBeat = slot.globalMeasureIndex == activeMeasureIndex &&
          bIdx == activeBeatIndex;

      if (isActiveBeat) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              x - 9,
              _staffTop - 6,
              18,
              _staffBottom - _staffTop + 12,
            ),
            const Radius.circular(4),
          ),
          Paint()..color = accentColor.withValues(alpha: 0.30),
        );
      }

      // Lane 3 (y=46..60): 拍途中コード変更（例: C -> G/B）
      if (beat.chordSymbol != null) {
        _paintText(
          canvas,
          text: beat.chordSymbol!,
          offset: Offset(x - 8, 46),
          style: TextStyle(
            color: inkColor,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        );
      }

      // Lane 4 (y=63..74): ピッキング記号（ダウン⊓ / アップ∨）
      if (beat.pickDirection != null) {
        _drawPickDirection(
          canvas,
          x: x,
          y: 68.0,
          direction: beat.pickDirection!,
          color: inkColor,
        );
      }

      // Lane 5 (y=78..92): スタッカート点
      if (beat.staccato) {
        canvas.drawCircle(
          Offset(x, _staffTop - 6.0),
          1.7,
          Paint()..color = inkColor,
        );
      }

      final isBeamed = _isBeatInBeamGroup(beats, bIdx);

      switch (beat.kind) {
        case StructuredTabBeatKind.rest:
          _drawRest(
            canvas,
            x: x,
            duration: beat.duration,
            color: inkColor,
          );
        case StructuredTabBeatKind.rhythmSlash:
          _drawRhythmSlash(
            canvas,
            x: x,
            duration: beat.duration,
            drawFlag: !isBeamed &&
                (beat.duration == StructuredTabDuration.eighth ||
                    beat.duration == StructuredTabDuration.sixteenth),
            color: isActiveBeat ? accentColor : inkColor,
          );
        case StructuredTabBeatKind.chordStack:
          final lowestStringIdx = _drawFretStack(
            canvas,
            x: x,
            frets: beat.frets,
            bgColor: bgColor,
            textColor: isActiveBeat ? accentColor : inkColor,
          );
          if (beat.duration != StructuredTabDuration.whole) {
            final stemTop = lowestStringIdx != null
                ? _stringY(lowestStringIdx) + 6.5
                : _staffBottom + 2.0;
            final safeStemTop =
                stemTop < _stemBottomY - 6 ? stemTop : _stemBottomY - 6;
            _drawStem(
              canvas,
              x: x,
              topY: safeStemTop,
              bottomY: _stemBottomY,
              drawFlag: !isBeamed &&
                  (beat.duration == StructuredTabDuration.eighth ||
                      beat.duration == StructuredTabDuration.sixteenth),
              color: isActiveBeat ? accentColor : inkColor,
            );
          }
      }
    }

    // 連桁（ビーム）描画
    _drawBeamGroups(canvas, beats: beats, beatXs: beatXs, color: inkColor);
  }

  bool _isBeatInBeamGroup(List<StructuredTabBeat> beats, int index) {
    final group = beats[index].beamGroup;
    if (group == null || group.isEmpty) return false;
    final hasPrev = index > 0 && beats[index - 1].beamGroup == group;
    final hasNext =
        index + 1 < beats.length && beats[index + 1].beamGroup == group;
    return hasPrev || hasNext;
  }

  void _drawBeamGroups(
    Canvas canvas, {
    required List<StructuredTabBeat> beats,
    required List<double> beatXs,
    required Color color,
  }) {
    var i = 0;
    while (i < beats.length) {
      final group = beats[i].beamGroup;
      if (group == null || group.isEmpty) {
        i++;
        continue;
      }
      var end = i;
      while (end + 1 < beats.length && beats[end + 1].beamGroup == group) {
        end++;
      }
      if (end > i) {
        final startX = _stemXForBeat(beats[i], beatXs[i]);
        final endX = _stemXForBeat(beats[end], beatXs[end]);
        canvas.drawLine(
          Offset(startX, _stemBottomY),
          Offset(endX, _stemBottomY),
          Paint()
            ..color = color
            ..strokeWidth = 3.2
            ..strokeCap = StrokeCap.butt,
        );
      }
      i = end + 1;
    }
  }

  double _stemXForBeat(StructuredTabBeat beat, double beatX) {
    return beat.kind == StructuredTabBeatKind.rhythmSlash ? beatX - 3.5 : beatX;
  }

  int? _drawFretStack(
    Canvas canvas, {
    required double x,
    required List<int?> frets,
    required Color bgColor,
    required Color textColor,
  }) {
    int? lowestStringIndex;
    for (var s = 0; s < 6 && s < frets.length; s++) {
      final fret = frets[s];
      if (fret == null) continue;
      lowestStringIndex ??= s;
      final cy = _stringY(s);
      final label = '$fret';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: textColor,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final boxW = tp.width + 4.0;
      final boxH = tp.height + 1.5;
      canvas.drawRect(
        Rect.fromCenter(center: Offset(x, cy), width: boxW, height: boxH),
        Paint()..color = bgColor,
      );
      tp.paint(canvas, Offset(x - tp.width / 2, cy - tp.height / 2));
    }
    return lowestStringIndex;
  }

  void _drawRhythmSlash(
    Canvas canvas, {
    required double x,
    required StructuredTabDuration duration,
    required bool drawFlag,
    required Color color,
  }) {
    const double cy = (_staffTop + _staffBottom) / 2;
    final slashPath = Path()
      ..moveTo(x - 3.5, cy + 5.0)
      ..lineTo(x + 2.5, cy - 5.0)
      ..lineTo(x + 5.2, cy - 5.0)
      ..lineTo(x - 0.8, cy + 5.0)
      ..close();
    canvas.drawPath(slashPath, Paint()..color = color);

    if (duration != StructuredTabDuration.whole) {
      _drawStem(
        canvas,
        x: x - 3.5,
        topY: cy + 5.0,
        bottomY: _stemBottomY,
        drawFlag: drawFlag,
        color: color,
      );
    }
  }

  void _drawStem(
    Canvas canvas, {
    required double x,
    required double topY,
    required double bottomY,
    required bool drawFlag,
    required Color color,
  }) {
    canvas.drawLine(
      Offset(x, topY),
      Offset(x, bottomY),
      Paint()
        ..color = color
        ..strokeWidth = 1.2,
    );
    if (drawFlag) {
      final flagPath = Path()
        ..moveTo(x, bottomY)
        ..quadraticBezierTo(x + 6.0, bottomY - 5.0, x + 4.5, bottomY - 12.0)
        ..quadraticBezierTo(x + 3.5, bottomY - 7.5, x, bottomY - 4.0)
        ..close();
      canvas.drawPath(flagPath, Paint()..color = color);
    }
  }

  void _drawRest(
    Canvas canvas, {
    required double x,
    required StructuredTabDuration duration,
    required Color color,
  }) {
    const double midY = (_staffTop + _staffBottom) / 2;
    switch (duration) {
      case StructuredTabDuration.whole:
        canvas.drawRect(
          Rect.fromLTWH(x - 5, midY - 5, 10, 4),
          Paint()..color = color,
        );
      case StructuredTabDuration.half:
        canvas.drawRect(
          Rect.fromLTWH(x - 5, midY - 9, 10, 4),
          Paint()..color = color,
        );
      case StructuredTabDuration.quarter:
        final path = Path()
          ..moveTo(x - 2.5, midY - 12)
          ..lineTo(x + 3.5, midY - 5)
          ..lineTo(x - 2.5, midY + 1)
          ..lineTo(x + 3.5, midY + 7)
          ..quadraticBezierTo(x - 2.5, midY + 8, x + 0.5, midY + 14);
        canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      case StructuredTabDuration.eighth:
      case StructuredTabDuration.sixteenth:
        canvas.drawCircle(
          Offset(x - 2.5, midY - 4.5),
          2.2,
          Paint()..color = color,
        );
        final armPaint = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round;
        final path = Path()
          ..moveTo(x - 2.0, midY - 3.5)
          ..quadraticBezierTo(x + 1.5, midY - 2.0, x + 3.5, midY - 6.0)
          ..lineTo(x - 1.0, midY + 9.0);
        canvas.drawPath(path, armPaint);
    }
  }

  void _drawPickDirection(
    Canvas canvas, {
    required double x,
    required double y,
    required StructuredPickDirection direction,
    required Color color,
  }) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.square;

    if (direction == StructuredPickDirection.down) {
      final path = Path()
        ..moveTo(x - 3.5, y + 4.5)
        ..lineTo(x - 3.5, y - 3.0)
        ..lineTo(x + 3.5, y - 3.0)
        ..lineTo(x + 3.5, y + 4.5);
      canvas.drawPath(path, paint);
      canvas.drawLine(
        Offset(x - 3.5, y - 2.5),
        Offset(x + 3.5, y - 2.5),
        Paint()
          ..color = color
          ..strokeWidth = 2.2,
      );
    } else {
      final path = Path()
        ..moveTo(x - 3.5, y - 3.0)
        ..lineTo(x, y + 4.5)
        ..lineTo(x + 3.5, y - 3.0);
      canvas.drawPath(path, paint);
    }
  }

  void _drawRehearsalMark(
    Canvas canvas, {
    required String mark,
    required bool boxed,
    required Offset offset,
    required Color color,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: mark,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    if (boxed) {
      final rect = Rect.fromLTWH(
        offset.dx,
        offset.dy,
        tp.width + 8.0,
        tp.height + 6.0,
      );
      canvas.drawRect(
        rect,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1,
      );
      tp.paint(canvas, Offset(offset.dx + 4.0, offset.dy + 3.0));
      return;
    }

    tp.paint(canvas, offset);
  }

  void _drawSegno(
    Canvas canvas, {
    required Offset center,
    required Color color,
  }) {
    final sPath = Path()
      ..moveTo(center.dx + 3.0, center.dy - 5.5)
      ..cubicTo(
        center.dx - 4.0,
        center.dy - 6.0,
        center.dx - 3.0,
        center.dy - 1.0,
        center.dx,
        center.dy,
      )
      ..cubicTo(
        center.dx + 3.5,
        center.dy + 1.0,
        center.dx + 4.0,
        center.dy + 6.0,
        center.dx - 3.0,
        center.dy + 5.5,
      );
    canvas.drawPath(
      sPath,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(center.dx - 5.5, center.dy + 5.5),
      Offset(center.dx + 5.5, center.dy - 5.5),
      Paint()
        ..color = color
        ..strokeWidth = 1.2,
    );
    canvas.drawCircle(
      Offset(center.dx - 4.8, center.dy - 0.5),
      1.3,
      Paint()..color = color,
    );
    canvas.drawCircle(
      Offset(center.dx + 4.8, center.dy + 0.5),
      1.3,
      Paint()..color = color,
    );
  }

  void _drawCoda(
    Canvas canvas, {
    required Offset center,
    required Color color,
  }) {
    canvas.drawOval(
      Rect.fromCenter(center: center, width: 10.0, height: 13.0),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    final crossPaint = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset(center.dx, center.dy - 9.0),
      Offset(center.dx, center.dy + 9.0),
      crossPaint,
    );
    canvas.drawLine(
      Offset(center.dx - 7.5, center.dy),
      Offset(center.dx + 7.5, center.dy),
      crossPaint,
    );
  }

  void _drawVoltaBracket(
    Canvas canvas, {
    required double left,
    required double right,
    required String label,
    required bool drawRightHook,
    required Color color,
  }) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.1;
    canvas.drawLine(Offset(left, 24), Offset(left, 14), paint);
    canvas.drawLine(Offset(left, 14), Offset(right - 2, 14), paint);
    if (drawRightHook) {
      canvas.drawLine(Offset(right - 2, 14), Offset(right - 2, 24), paint);
    }
    _paintText(
      canvas,
      text: label,
      offset: Offset(left + 4, 15),
      style: TextStyle(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  void _drawSectionDoubleBar(Canvas canvas, double x, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(x - 4.5, _staffTop),
      Offset(x - 4.5, _staffBottom),
      paint,
    );
    canvas.drawLine(
      Offset(x - 1.0, _staffTop),
      Offset(x - 1.0, _staffBottom),
      paint,
    );
  }

  void _drawRepeatStart(Canvas canvas, double x, Color color) {
    canvas.drawLine(
      Offset(x + 1.5, _staffTop),
      Offset(x + 1.5, _staffBottom),
      Paint()
        ..color = color
        ..strokeWidth = 3.0,
    );
    canvas.drawLine(
      Offset(x + 5.5, _staffTop),
      Offset(x + 5.5, _staffBottom),
      Paint()
        ..color = color
        ..strokeWidth = 1.0,
    );
    canvas.drawCircle(
      Offset(x + 9.5, _staffTop + 1.5 * _stringSpacing),
      1.6,
      Paint()..color = color,
    );
    canvas.drawCircle(
      Offset(x + 9.5, _staffTop + 3.5 * _stringSpacing),
      1.6,
      Paint()..color = color,
    );
  }

  void _drawRepeatEnd(Canvas canvas, double x, Color color) {
    canvas.drawCircle(
      Offset(x - 9.5, _staffTop + 1.5 * _stringSpacing),
      1.6,
      Paint()..color = color,
    );
    canvas.drawCircle(
      Offset(x - 9.5, _staffTop + 3.5 * _stringSpacing),
      1.6,
      Paint()..color = color,
    );
    canvas.drawLine(
      Offset(x - 5.5, _staffTop),
      Offset(x - 5.5, _staffBottom),
      Paint()
        ..color = color
        ..strokeWidth = 1.0,
    );
    canvas.drawLine(
      Offset(x - 1.5, _staffTop),
      Offset(x - 1.5, _staffBottom),
      Paint()
        ..color = color
        ..strokeWidth = 3.0,
    );
  }

  void _drawFinalDoubleBar(Canvas canvas, double x, Color color) {
    canvas.drawLine(
      Offset(x - 5.0, _staffTop),
      Offset(x - 5.0, _staffBottom),
      Paint()
        ..color = color
        ..strokeWidth = 1.0,
    );
    canvas.drawLine(
      Offset(x - 1.5, _staffTop),
      Offset(x - 1.5, _staffBottom),
      Paint()
        ..color = color
        ..strokeWidth = 3.0,
    );
  }

  void _drawTabClef(Canvas canvas, Color color) {
    const letters = <String>['T', 'A', 'B'];
    for (var i = 0; i < letters.length; i++) {
      _paintText(
        canvas,
        text: letters[i],
        offset: Offset(6, _staffTop + 3 + i * 15.0),
        style: TextStyle(
          color: color,
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          height: 1.0,
        ),
      );
    }
  }

  void _drawTimeSignature(
    Canvas canvas, {
    required double x,
    required int topNumber,
    required int bottomNumber,
    required Color color,
  }) {
    _paintText(
      canvas,
      text: '$topNumber',
      offset: Offset(x, _staffTop + 4),
      style: TextStyle(
        color: color,
        fontSize: 17,
        fontWeight: FontWeight.w900,
        height: 1.0,
      ),
    );
    _paintText(
      canvas,
      text: '$bottomNumber',
      offset: Offset(x, _staffTop + 26),
      style: TextStyle(
        color: color,
        fontSize: 17,
        fontWeight: FontWeight.w900,
        height: 1.0,
      ),
    );
  }

  void _paintText(
    Canvas canvas, {
    required String text,
    required Offset offset,
    required TextStyle style,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(_StructuredTabRowPainter oldDelegate) {
    return oldDelegate.score != score ||
        oldDelegate.lightSheet != lightSheet ||
        oldDelegate.activeMeasureIndex != activeMeasureIndex ||
        oldDelegate.activeBeatIndex != activeBeatIndex ||
        oldDelegate.geometry.staffRight != geometry.staffRight;
  }
}
