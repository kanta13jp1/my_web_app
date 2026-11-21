import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../domain/models/structured_guitar_tab.dart';

/// 構造化TABスコアの印刷用PDF生成・出力サービス。
abstract interface class StructuredTabPdfService {
  Future<Uint8List> buildScorePdf(
    StructuredGuitarTabScore score, {
    pw.Font? fontOverride,
  });

  Future<bool> printScore(StructuredGuitarTabScore score);
}

class LocalStructuredTabPdfService implements StructuredTabPdfService {
  const LocalStructuredTabPdfService();

  static const double _pageWidth = 539.0; // A4 (595pt) - 左右各28pt
  static const double _rowHeight = 148.0;

  @override
  Future<Uint8List> buildScorePdf(
    StructuredGuitarTabScore score, {
    pw.Font? fontOverride,
  }) async {
    final font = fontOverride ?? await _loadBundledFont();
    final doc = pw.Document();

    final rows = <List<int>>[];
    const int measuresPerRow = 4;
    for (var i = 0; i < score.measures.length; i += measuresPerRow) {
      final end = (i + measuresPerRow < score.measures.length)
          ? i + measuresPerRow
          : score.measures.length;
      rows.add(<int>[for (var idx = i; idx < end; idx++) idx]);
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        maxPages: 40,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        theme: pw.ThemeData.withFont(base: font, bold: font),
        build: (pw.Context context) {
          return <pw.Widget>[
            pw.Text(
              score.title,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                font: font,
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              score.artist,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                font: font,
                fontSize: 11,
                color: PdfColors.grey800,
              ),
            ),
            if (score.chords.isNotEmpty) ...<pw.Widget>[
              pw.SizedBox(height: 10),
              pw.Wrap(
                alignment: pw.WrapAlignment.center,
                spacing: 14,
                runSpacing: 8,
                children: <pw.Widget>[
                  for (final chord in score.chords)
                    _buildChordDiagramWidget(chord, font),
                ],
              ),
            ],
            pw.SizedBox(height: 10),
            pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Text(
                '${score.tuning}   |   Tempo = ${score.bpm} BPM   |   Capo: ${score.capo}',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 9.5,
                  color: PdfColors.grey800,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            for (var r = 0; r < rows.length; r++) ...<pw.Widget>[
              _buildSystemRow(
                score: score,
                measureIndices: rows[r],
                font: font,
              ),
              if (r != rows.length - 1) pw.SizedBox(height: 8),
            ],
          ];
        },
      ),
    );

    return doc.save();
  }

  @override
  Future<bool> printScore(StructuredGuitarTabScore score) async {
    return Printing.layoutPdf(
      name: '${sanitizePdfFileName(score.id)}.pdf',
      onLayout: (PdfPageFormat format) => buildScorePdf(score),
    );
  }

  /// PDF保存ファイル名向けにスコアIDを安全なASCII識別子へサニタイズする。
  static String sanitizePdfFileName(String rawId) {
    final sanitized = rawId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return sanitized.isEmpty ? 'structured-tab' : sanitized;
  }

  Future<pw.Font> _loadBundledFont() async {
    try {
      final data =
          await rootBundle.load('web/assets/fonts/NotoSansJP-Regular.ttf');
      return pw.Font.ttf(data);
    } catch (_) {
      return pw.Font.helvetica();
    }
  }

  pw.Widget _buildChordDiagramWidget(
    StructuredChordDiagram chord,
    pw.Font font,
  ) {
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: <pw.Widget>[
        pw.Text(
          chord.name,
          style: pw.TextStyle(
            font: font,
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Stack(
          children: <pw.Widget>[
            pw.CustomPaint(
              size: const PdfPoint(56, 56),
              painter: (PdfGraphics canvas, PdfPoint size) {
                double py(double topY) => size.y - topY;
                const double leftPad = 14.0;
                const double topPad = 13.0;
                const double colW = 7.0;
                const double rowH = 9.0;
                const int stringCount = 6;
                const int fretWireCount = 5;
                const rightX = leftPad + (stringCount - 1) * colW;
                const bottomY = topPad + (fretWireCount - 1) * rowH;

                canvas
                  ..setStrokeColor(PdfColors.grey700)
                  ..setLineWidth(0.7);
                for (var s = 0; s < stringCount; s++) {
                  final x = leftPad + s * colW;
                  canvas.drawLine(x, py(topPad), x, py(bottomY));
                }
                canvas.strokePath();

                for (var f = 0; f < fretWireCount; f++) {
                  final y = topPad + f * rowH;
                  final isNut = f == 0 && chord.baseFret == 1;
                  canvas
                    ..setStrokeColor(
                      isNut ? PdfColors.black : PdfColors.grey700,
                    )
                    ..setLineWidth(isNut ? 2.2 : 0.7)
                    ..drawLine(leftPad, py(y), rightX, py(y))
                    ..strokePath();
                }

                final barre = chord.barre;
                if (barre != null) {
                  final rel = barre.fret - chord.baseFret + 1;
                  if (rel >= 1 && rel < fretWireCount) {
                    final xStart =
                        leftPad + barre.startStringIndex * colW - 2.4;
                    final xEnd = leftPad + barre.endStringIndex * colW + 2.4;
                    final cy = topPad + (rel - 0.5) * rowH;
                    canvas
                      ..setFillColor(PdfColors.black)
                      ..drawRRect(
                        xStart,
                        py(cy + 2.2),
                        xEnd - xStart,
                        4.4,
                        2.2,
                        2.2,
                      )
                      ..fillPath();
                  }
                }

                for (var s = 0;
                    s < chord.frets.length && s < stringCount;
                    s++) {
                  final fret = chord.frets[s];
                  final x = leftPad + s * colW;
                  if (fret == -1) {
                    const double r = 2.0;
                    const cy = topPad - 6.0;
                    canvas
                      ..setStrokeColor(PdfColors.black)
                      ..setLineWidth(0.9)
                      ..drawLine(x - r, py(cy - r), x + r, py(cy + r))
                      ..drawLine(x - r, py(cy + r), x + r, py(cy - r))
                      ..strokePath();
                  } else if (fret == 0) {
                    canvas
                      ..setStrokeColor(PdfColors.black)
                      ..setLineWidth(0.8)
                      ..drawEllipse(x, py(topPad - 6.0), 2.1, 2.1)
                      ..strokePath();
                  } else {
                    final rel = fret - chord.baseFret + 1;
                    if (rel >= 1 && rel < fretWireCount) {
                      final cy = topPad + (rel - 0.5) * rowH;
                      canvas
                        ..setFillColor(PdfColors.black)
                        ..drawEllipse(x, py(cy), 2.4, 2.4)
                        ..fillPath();
                    }
                  }
                }
              },
            ),
            if (chord.baseFret > 1)
              pw.Positioned(
                left: 1,
                top: 13,
                child: pw.Text(
                  '${chord.baseFret}',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildSystemRow({
    required StructuredGuitarTabScore score,
    required List<int> measureIndices,
    required pw.Font font,
  }) {
    const double staffTop = 58.0;
    const double stringSpacing = 8.8;
    const double staffBottom = staffTop + 5 * stringSpacing;
    const double stemBottomY = staffBottom + 26.0;
    const double clefWidth = 18.0;

    final firstMeasure = score.measures[measureIndices.first];
    final hasTimeSig = firstMeasure.number == 1;
    final prefixWidth = clefWidth + (hasTimeSig ? 15.0 : 0.0);
    final slotWidth = (_pageWidth - prefixWidth - 4.0) / 4.0;
    final staffRight = prefixWidth + measureIndices.length * slotWidth;

    double stringY(int stringIndex) {
      return staffTop + (5 - stringIndex) * stringSpacing;
    }

    final positionedLabels = <pw.Widget>[
      for (var i = 0; i < 3; i++)
        pw.Positioned(
          left: 5,
          top: staffTop + 2 + i * 13.0,
          child: pw.Text(
            const <String>['T', 'A', 'B'][i],
            style: pw.TextStyle(
              font: font,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      if (hasTimeSig) ...<pw.Widget>[
        pw.Positioned(
          left: clefWidth + 4,
          top: staffTop + 3,
          child: pw.Text(
            '${score.beatsPerMeasure}',
            style: pw.TextStyle(
              font: font,
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.Positioned(
          left: clefWidth + 4,
          top: staffTop + 22,
          child: pw.Text(
            '${score.beatUnit}',
            style: pw.TextStyle(
              font: font,
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      ],
    ];

    final slotLefts = <double>[];
    final slotRights = <double>[];
    final beatPositions = <List<double>>[];

    for (var sIdx = 0; sIdx < measureIndices.length; sIdx++) {
      final globalIdx = measureIndices[sIdx];
      final measure = score.measures[globalIdx];
      final left = prefixWidth + sIdx * slotWidth;
      final right = left + slotWidth;
      slotLefts.add(left);
      slotRights.add(right);

      positionedLabels.add(
        pw.Positioned(
          left: left + 3,
          top: staffTop - 11,
          child: pw.Text(
            '${measure.number}',
            style: pw.TextStyle(
              font: font,
              fontSize: 7.5,
              color: PdfColors.grey700,
            ),
          ),
        ),
      );

      if (measure.rehearsalMark != null) {
        positionedLabels.add(
          pw.Positioned(
            left: left + (measure.boxedRehearsalMark ? 5 : 2),
            top: 4,
            child: pw.Text(
              measure.rehearsalMark!,
              style: pw.TextStyle(
                font: font,
                fontSize: 9.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        );
      }
      if (measure.topNote != null) {
        final noteX =
            (measure.hasSegno || measure.hasCoda) ? left + 22 : left + 5;
        final noteY = measure.volta != null ? 4.0 : 16.0;
        positionedLabels.add(
          pw.Positioned(
            left: noteX,
            top: noteY,
            child: pw.Text(
              measure.topNote!,
              style: pw.TextStyle(
                font: font,
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        );
      }
      if (measure.volta != null) {
        positionedLabels.add(
          pw.Positioned(
            left: left + 4,
            top: 17,
            child: pw.Text(
              measure.volta!,
              style: pw.TextStyle(
                font: font,
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        );
      }
      if (measure.chordSymbol != null) {
        positionedLabels.add(
          pw.Positioned(
            left: left + 5,
            top: 30,
            child: pw.Text(
              measure.chordSymbol!,
              style: pw.TextStyle(
                font: font,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        );
      }

      final contentLeft = left + (measure.repeatStart ? 10.0 : 6.0);
      final contentRight = right - (measure.repeatEnd ? 10.0 : 6.0);
      final span = (contentRight - contentLeft).clamp(20.0, 400.0);
      final totalUnits = measure.beats.fold<double>(
        0.0,
        (double sum, StructuredTabBeat beat) => sum + beat.duration.beatUnits,
      );
      final safeUnits = totalUnits > 0 ? totalUnits : 1.0;

      final xs = <double>[];
      var cursorUnits = 0.0;
      for (final beat in measure.beats) {
        final x = contentLeft + 6.0 + (cursorUnits / safeUnits) * (span - 12.0);
        xs.add(x);
        cursorUnits += beat.duration.beatUnits;

        if (beat.chordSymbol != null) {
          positionedLabels.add(
            pw.Positioned(
              left: x - 6,
              top: 30,
              child: pw.Text(
                beat.chordSymbol!,
                style: pw.TextStyle(
                  font: font,
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          );
        }

        if (beat.kind == StructuredTabBeatKind.chordStack) {
          for (var s = 0; s < 6 && s < beat.frets.length; s++) {
            final fret = beat.frets[s];
            if (fret == null) continue;
            final label = '$fret';
            final textW = label.length * 5.0;
            positionedLabels.add(
              pw.Positioned(
                left: x - textW / 2,
                top: stringY(s) - 4.5,
                child: pw.Text(
                  label,
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                ),
              ),
            );
          }
        }
      }
      beatPositions.add(xs);
    }

    return pw.Stack(
      children: <pw.Widget>[
        pw.CustomPaint(
          size: const PdfPoint(_pageWidth, _rowHeight),
          painter: (PdfGraphics canvas, PdfPoint size) {
            double py(double topY) => size.y - topY;

            // 6本TAB線
            canvas
              ..setStrokeColor(PdfColors.grey600)
              ..setLineWidth(0.7);
            for (var s = 0; s < 6; s++) {
              final y = staffTop + s * stringSpacing;
              canvas.drawLine(0, py(y), staffRight, py(y));
            }
            canvas.strokePath();

            // 左端枠線
            canvas
              ..setStrokeColor(PdfColors.black)
              ..setLineWidth(1.0)
              ..drawLine(0.5, py(staffTop), 0.5, py(staffBottom))
              ..strokePath();

            for (var sIdx = 0; sIdx < measureIndices.length; sIdx++) {
              final globalIdx = measureIndices[sIdx];
              final measure = score.measures[globalIdx];
              final left = slotLefts[sIdx];
              final right = slotRights[sIdx];
              final isLastMeasure = globalIdx == score.measures.length - 1;

              if (measure.repeatStart) {
                _pdfRepeatStart(
                  canvas,
                  py,
                  left,
                  staffTop,
                  staffBottom,
                  stringSpacing,
                );
              } else if (sIdx > 0 || hasTimeSig) {
                canvas
                  ..setStrokeColor(PdfColors.black)
                  ..setLineWidth(0.8)
                  ..drawLine(left, py(staffTop), left, py(staffBottom))
                  ..strokePath();
              }

              if (measure.repeatEnd) {
                _pdfRepeatEnd(
                  canvas,
                  py,
                  right,
                  staffTop,
                  staffBottom,
                  stringSpacing,
                );
              } else if (isLastMeasure) {
                _pdfFinalDoubleBar(canvas, py, right, staffTop, staffBottom);
              } else {
                canvas
                  ..setStrokeColor(PdfColors.black)
                  ..setLineWidth(0.8)
                  ..drawLine(right, py(staffTop), right, py(staffBottom))
                  ..strokePath();
              }

              if (measure.rehearsalMark != null && measure.boxedRehearsalMark) {
                final boxW = measure.rehearsalMark!.length * 6.5 + 8.0;
                canvas
                  ..setStrokeColor(PdfColors.black)
                  ..setLineWidth(0.9)
                  ..drawRect(left + 2, py(16.0), boxW, 13.0)
                  ..strokePath();
              }

              if (measure.hasSegno) {
                _pdfSegno(canvas, py, left + 10.0, 20.0);
              }
              if (measure.hasCoda) {
                _pdfCoda(canvas, py, left + 12.0, 20.0);
              }
              if (measure.volta != null) {
                canvas
                  ..setStrokeColor(PdfColors.black)
                  ..setLineWidth(0.9)
                  ..drawLine(left, py(25), left, py(15))
                  ..drawLine(left, py(15), right - 2, py(15))
                  ..strokePath();
              }

              final xs = beatPositions[sIdx];
              for (var bIdx = 0; bIdx < measure.beats.length; bIdx++) {
                final beat = measure.beats[bIdx];
                final x = xs[bIdx];

                if (beat.pickDirection != null) {
                  _pdfPickDirection(
                    canvas,
                    py,
                    x,
                    43.0,
                    beat.pickDirection!,
                  );
                }
                if (beat.staccato) {
                  canvas
                    ..setFillColor(PdfColors.black)
                    ..drawEllipse(x, py(staffTop - 4.5), 1.4, 1.4)
                    ..fillPath();
                }

                final isBeamed = _pdfIsBeamed(measure.beats, bIdx);

                switch (beat.kind) {
                  case StructuredTabBeatKind.rest:
                    _pdfRest(
                      canvas,
                      py,
                      x,
                      (staffTop + staffBottom) / 2,
                      beat.duration,
                    );
                  case StructuredTabBeatKind.rhythmSlash:
                    _pdfRhythmSlash(
                      canvas,
                      py,
                      x,
                      (staffTop + staffBottom) / 2,
                      stemBottomY,
                      beat.duration,
                      drawFlag: !isBeamed &&
                          (beat.duration == StructuredTabDuration.eighth ||
                              beat.duration == StructuredTabDuration.sixteenth),
                    );
                  case StructuredTabBeatKind.chordStack:
                    int? lowestIdx;
                    for (var s = 0; s < 6 && s < beat.frets.length; s++) {
                      final fret = beat.frets[s];
                      if (fret == null) continue;
                      lowestIdx ??= s;
                      final maskW = '$fret'.length * 5.2 + 3.5;
                      final cy = stringY(s);
                      canvas
                        ..setFillColor(PdfColors.white)
                        ..drawRect(x - maskW / 2, py(cy + 4.5), maskW, 9.0)
                        ..fillPath();
                    }
                    if (beat.duration != StructuredTabDuration.whole) {
                      final topY = lowestIdx != null
                          ? stringY(lowestIdx) + 5.5
                          : staffBottom + 2.0;
                      final safeTopY =
                          topY < stemBottomY - 5 ? topY : stemBottomY - 5;
                      _pdfStem(
                        canvas,
                        py,
                        x,
                        safeTopY,
                        stemBottomY,
                        drawFlag: !isBeamed &&
                            (beat.duration == StructuredTabDuration.eighth ||
                                beat.duration ==
                                    StructuredTabDuration.sixteenth),
                      );
                    }
                }
              }

              // 連桁描画
              var i = 0;
              while (i < measure.beats.length) {
                final group = measure.beats[i].beamGroup;
                if (group == null || group.isEmpty) {
                  i++;
                  continue;
                }
                var end = i;
                while (end + 1 < measure.beats.length &&
                    measure.beats[end + 1].beamGroup == group) {
                  end++;
                }
                if (end > i) {
                  final sx =
                      measure.beats[i].kind == StructuredTabBeatKind.rhythmSlash
                          ? xs[i] - 3.0
                          : xs[i];
                  final ex = measure.beats[end].kind ==
                          StructuredTabBeatKind.rhythmSlash
                      ? xs[end] - 3.0
                      : xs[end];
                  canvas
                    ..setStrokeColor(PdfColors.black)
                    ..setLineWidth(2.6)
                    ..drawLine(sx, py(stemBottomY), ex, py(stemBottomY))
                    ..strokePath();
                }
                i = end + 1;
              }
            }
          },
        ),
        ...positionedLabels,
      ],
    );
  }

  bool _pdfIsBeamed(List<StructuredTabBeat> beats, int index) {
    final group = beats[index].beamGroup;
    if (group == null || group.isEmpty) return false;
    final hasPrev = index > 0 && beats[index - 1].beamGroup == group;
    final hasNext =
        index + 1 < beats.length && beats[index + 1].beamGroup == group;
    return hasPrev || hasNext;
  }

  void _pdfRepeatStart(
    PdfGraphics canvas,
    double Function(double) py,
    double x,
    double staffTop,
    double staffBottom,
    double stringSpacing,
  ) {
    canvas
      ..setStrokeColor(PdfColors.black)
      ..setLineWidth(2.4)
      ..drawLine(x + 1.2, py(staffTop), x + 1.2, py(staffBottom))
      ..strokePath()
      ..setLineWidth(0.8)
      ..drawLine(x + 4.5, py(staffTop), x + 4.5, py(staffBottom))
      ..strokePath()
      ..setFillColor(PdfColors.black)
      ..drawEllipse(x + 7.8, py(staffTop + 1.5 * stringSpacing), 1.3, 1.3)
      ..drawEllipse(x + 7.8, py(staffTop + 3.5 * stringSpacing), 1.3, 1.3)
      ..fillPath();
  }

  void _pdfRepeatEnd(
    PdfGraphics canvas,
    double Function(double) py,
    double x,
    double staffTop,
    double staffBottom,
    double stringSpacing,
  ) {
    canvas
      ..setFillColor(PdfColors.black)
      ..drawEllipse(x - 7.8, py(staffTop + 1.5 * stringSpacing), 1.3, 1.3)
      ..drawEllipse(x - 7.8, py(staffTop + 3.5 * stringSpacing), 1.3, 1.3)
      ..fillPath()
      ..setStrokeColor(PdfColors.black)
      ..setLineWidth(0.8)
      ..drawLine(x - 4.5, py(staffTop), x - 4.5, py(staffBottom))
      ..strokePath()
      ..setLineWidth(2.4)
      ..drawLine(x - 1.2, py(staffTop), x - 1.2, py(staffBottom))
      ..strokePath();
  }

  void _pdfFinalDoubleBar(
    PdfGraphics canvas,
    double Function(double) py,
    double x,
    double staffTop,
    double staffBottom,
  ) {
    canvas
      ..setStrokeColor(PdfColors.black)
      ..setLineWidth(0.8)
      ..drawLine(x - 4.2, py(staffTop), x - 4.2, py(staffBottom))
      ..strokePath()
      ..setLineWidth(2.4)
      ..drawLine(x - 1.2, py(staffTop), x - 1.2, py(staffBottom))
      ..strokePath();
  }

  void _pdfRhythmSlash(
    PdfGraphics canvas,
    double Function(double) py,
    double x,
    double cy,
    double stemBottomY,
    StructuredTabDuration duration, {
    required bool drawFlag,
  }) {
    canvas
      ..setFillColor(PdfColors.black)
      ..moveTo(x - 3.0, py(cy + 4.2))
      ..lineTo(x + 2.0, py(cy - 4.2))
      ..lineTo(x + 4.3, py(cy - 4.2))
      ..lineTo(x - 0.7, py(cy + 4.2))
      ..closePath()
      ..fillPath();

    if (duration != StructuredTabDuration.whole) {
      _pdfStem(canvas, py, x - 3.0, cy + 4.2, stemBottomY, drawFlag: drawFlag);
    }
  }

  void _pdfStem(
    PdfGraphics canvas,
    double Function(double) py,
    double x,
    double topY,
    double bottomY, {
    required bool drawFlag,
  }) {
    canvas
      ..setStrokeColor(PdfColors.black)
      ..setLineWidth(1.0)
      ..drawLine(x, py(topY), x, py(bottomY))
      ..strokePath();
    if (drawFlag) {
      canvas
        ..setStrokeColor(PdfColors.black)
        ..setLineWidth(1.6)
        ..moveTo(x, py(bottomY))
        ..curveTo(
          x + 4.5,
          py(bottomY - 3.5),
          x + 4.5,
          py(bottomY - 7.5),
          x + 3.0,
          py(bottomY - 10.5),
        )
        ..strokePath();
    }
  }

  void _pdfRest(
    PdfGraphics canvas,
    double Function(double) py,
    double x,
    double midY,
    StructuredTabDuration duration,
  ) {
    switch (duration) {
      case StructuredTabDuration.whole:
        canvas
          ..setFillColor(PdfColors.black)
          ..drawRect(x - 4, py(midY + 0.5), 8, 3.5)
          ..fillPath();
      case StructuredTabDuration.half:
        canvas
          ..setFillColor(PdfColors.black)
          ..drawRect(x - 4, py(midY - 3.5), 8, 3.5)
          ..fillPath();
      case StructuredTabDuration.quarter:
        canvas
          ..setStrokeColor(PdfColors.black)
          ..setLineWidth(1.6)
          ..setLineCap(PdfLineCap.round)
          ..setLineJoin(PdfLineJoin.round)
          ..moveTo(x - 2.0, py(midY - 10))
          ..lineTo(x + 2.8, py(midY - 4))
          ..lineTo(x - 2.0, py(midY + 1))
          ..lineTo(x + 2.8, py(midY + 6))
          ..lineTo(x - 0.5, py(midY + 11))
          ..strokePath();
      case StructuredTabDuration.eighth:
      case StructuredTabDuration.sixteenth:
        canvas
          ..setFillColor(PdfColors.black)
          ..drawEllipse(x - 2.2, py(midY - 3.8), 1.8, 1.8)
          ..fillPath()
          ..setStrokeColor(PdfColors.black)
          ..setLineWidth(1.2)
          ..moveTo(x - 1.8, py(midY - 3.0))
          ..lineTo(x + 2.6, py(midY - 4.8))
          ..lineTo(x - 1.0, py(midY + 7.5))
          ..strokePath();
    }
  }

  void _pdfPickDirection(
    PdfGraphics canvas,
    double Function(double) py,
    double x,
    double y,
    StructuredPickDirection direction,
  ) {
    if (direction == StructuredPickDirection.down) {
      canvas
        ..setStrokeColor(PdfColors.black)
        ..setLineWidth(1.1)
        ..moveTo(x - 2.8, py(y + 3.5))
        ..lineTo(x - 2.8, py(y - 2.5))
        ..lineTo(x + 2.8, py(y - 2.5))
        ..lineTo(x + 2.8, py(y + 3.5))
        ..strokePath();
    } else {
      canvas
        ..setStrokeColor(PdfColors.black)
        ..setLineWidth(1.1)
        ..moveTo(x - 2.8, py(y - 2.5))
        ..lineTo(x, py(y + 3.5))
        ..lineTo(x + 2.8, py(y - 2.5))
        ..strokePath();
    }
  }

  void _pdfSegno(
    PdfGraphics canvas,
    double Function(double) py,
    double cx,
    double cy,
  ) {
    canvas
      ..setStrokeColor(PdfColors.black)
      ..setLineWidth(1.2)
      ..moveTo(cx + 2.5, py(cy - 4.5))
      ..curveTo(cx - 3.0, py(cy - 5.0), cx - 2.5, py(cy - 1.0), cx, py(cy))
      ..curveTo(
        cx + 2.5,
        py(cy + 1.0),
        cx + 3.0,
        py(cy + 5.0),
        cx - 2.5,
        py(cy + 4.5),
      )
      ..strokePath()
      ..drawLine(cx - 4.5, py(cy + 4.5), cx + 4.5, py(cy - 4.5))
      ..strokePath()
      ..setFillColor(PdfColors.black)
      ..drawEllipse(cx - 4.0, py(cy), 1.0, 1.0)
      ..drawEllipse(cx + 4.0, py(cy), 1.0, 1.0)
      ..fillPath();
  }

  void _pdfCoda(
    PdfGraphics canvas,
    double Function(double) py,
    double cx,
    double cy,
  ) {
    canvas
      ..setStrokeColor(PdfColors.black)
      ..setLineWidth(1.1)
      ..drawEllipse(cx, py(cy), 4.0, 5.2)
      ..strokePath()
      ..drawLine(cx, py(cy - 7.5), cx, py(cy + 7.5))
      ..drawLine(cx - 6.0, py(cy), cx + 6.0, py(cy))
      ..strokePath();
  }
}
