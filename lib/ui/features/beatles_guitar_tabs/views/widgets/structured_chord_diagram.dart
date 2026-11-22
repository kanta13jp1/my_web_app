import 'package:flutter/material.dart';

import '../../../../../domain/models/structured_guitar_tab.dart';
import '../../../../../theme/design_tokens.dart';

/// 譜面上部に複数コードダイアグラムを並べて表示するウィジェット。
class StructuredChordDiagramStrip extends StatelessWidget {
  const StructuredChordDiagramStrip({
    super.key,
    required this.chords,
    required this.lightSheet,
  });

  final List<StructuredChordDiagram> chords;
  final bool lightSheet;

  @override
  Widget build(BuildContext context) {
    if (chords.isEmpty) {
      return const SizedBox.shrink();
    }

    final textColor =
        lightSheet ? const Color(0xFF111827) : DesignTokens.textPrimary;
    final seenNames = <String>{};

    return Wrap(
      key: const Key('structured_chord_strip'),
      alignment: WrapAlignment.center,
      spacing: DesignTokens.space16,
      runSpacing: DesignTokens.space12,
      children: <Widget>[
        for (var i = 0; i < chords.length; i++)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                chords[i].name,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: DesignTokens.space2),
              CustomPaint(
                key: seenNames.add(chords[i].name)
                    ? Key('structured_chord_${chords[i].name}')
                    : Key('structured_chord_${chords[i].name}_$i'),
                size: const Size(74, 68),
                painter: StructuredChordDiagramPainter(
                  chord: chords[i],
                  lightSheet: lightSheet,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// 6弦フレットグリッド・開放(`o`)・ミュート(`x`)・押弦ドット・バレー横棒を描画するペインター。
class StructuredChordDiagramPainter extends CustomPainter {
  const StructuredChordDiagramPainter({
    required this.chord,
    required this.lightSheet,
  });

  final StructuredChordDiagram chord;
  final bool lightSheet;

  @override
  void paint(Canvas canvas, Size size) {
    const double leftPad = 16.0;
    const double topPad = 16.0;
    const double colW = 9.0;
    const double rowH = 11.0;
    const int stringCount = 6;
    const int fretWireCount = 5;

    final inkColor =
        lightSheet ? const Color(0xFF111827) : DesignTokens.textOnDark;
    final wireColor =
        lightSheet ? const Color(0xFF4B5563) : DesignTokens.textSecondary;
    final dotColor = lightSheet ? const Color(0xFF111827) : DesignTokens.orange;

    final wirePaint = Paint()
      ..color = wireColor
      ..strokeWidth = 0.9;

    const rightX = leftPad + (stringCount - 1) * colW;
    const bottomY = topPad + (fretWireCount - 1) * rowH;

    // 縦線（6弦〜1弦）
    for (var s = 0; s < stringCount; s++) {
      final x = leftPad + s * colW;
      canvas.drawLine(Offset(x, topPad), Offset(x, bottomY), wirePaint);
    }

    // 横線（フレット線）
    for (var f = 0; f < fretWireCount; f++) {
      final y = topPad + f * rowH;
      final isNut = f == 0 && chord.baseFret == 1;
      final linePaint = Paint()
        ..color = isNut ? inkColor : wireColor
        ..strokeWidth = isNut ? 2.6 : 0.9;
      canvas.drawLine(Offset(leftPad, y), Offset(rightX, y), linePaint);
    }

    // 2フレット以上から開始する場合の開始フレットラベル
    if (chord.baseFret > 1) {
      final tp = TextPainter(
        text: TextSpan(
          text: '${chord.baseFret}',
          style: TextStyle(
            color: inkColor,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, const Offset(2, topPad + 1));
    }

    // バレー（セーハ）横棒
    final barre = chord.barre;
    if (barre != null) {
      final rel = barre.fret - chord.baseFret + 1;
      if (rel >= 1 && rel < fretWireCount) {
        final xStart = leftPad + barre.startStringIndex * colW - 2.8;
        final xEnd = leftPad + barre.endStringIndex * colW + 2.8;
        final cy = topPad + (rel - 0.5) * rowH;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(xStart, cy - 2.8, xEnd, cy + 2.8),
            const Radius.circular(2.8),
          ),
          Paint()..color = dotColor,
        );
      }
    }

    // ミュート(x)・開放(o)・押弦ドット
    final openPaint = Paint()
      ..color = inkColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final mutePaint = Paint()
      ..color = inkColor
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final dotPaint = Paint()..color = dotColor;

    for (var s = 0; s < chord.frets.length && s < stringCount; s++) {
      final fret = chord.frets[s];
      final x = leftPad + s * colW;
      if (fret == -1) {
        const double r = 2.4;
        const cy = topPad - 7.5;
        canvas.drawLine(
          Offset(x - r, cy - r),
          Offset(x + r, cy + r),
          mutePaint,
        );
        canvas.drawLine(
          Offset(x - r, cy + r),
          Offset(x + r, cy - r),
          mutePaint,
        );
      } else if (fret == 0) {
        canvas.drawCircle(Offset(x, topPad - 7.5), 2.5, openPaint);
      } else {
        final rel = fret - chord.baseFret + 1;
        final coveredByBarre = barre != null &&
            fret == barre.fret &&
            s >= barre.startStringIndex &&
            s <= barre.endStringIndex;
        if (!coveredByBarre && rel >= 1 && rel < fretWireCount) {
          final cy = topPad + (rel - 0.5) * rowH;
          canvas.drawCircle(Offset(x, cy), 2.6, dotPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(StructuredChordDiagramPainter oldDelegate) {
    return oldDelegate.chord != chord || oldDelegate.lightSheet != lightSheet;
  }
}
