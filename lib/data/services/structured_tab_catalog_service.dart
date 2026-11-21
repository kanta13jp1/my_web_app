import '../../domain/models/structured_guitar_tab.dart';

/// バンドルされた構造化TAB練習カタログ。
/// 収録曲はすべてオリジナルの奏法練習エチュードであり、特定著作物の採譜は含みません。
class StructuredTabCatalogService {
  const StructuredTabCatalogService();

  Future<List<StructuredGuitarTabScore>> loadCatalog() async {
    return List<StructuredGuitarTabScore>.unmodifiable(_buildCatalog());
  }

  static List<StructuredGuitarTabScore> _buildCatalog() {
    return <StructuredGuitarTabScore>[
      _buildOffbeatPopEtude(),
      _buildOpenArpeggioEtude(),
    ];
  }

  static StructuredGuitarTabScore _buildOffbeatPopEtude() {
    const cFrets = <int?>[null, 3, 2, 0, 1, 0];
    const amFrets = <int?>[null, 0, 2, 2, 1, 0];
    const fFrets = <int?>[1, 3, 3, 2, 1, 1];
    const gFrets = <int?>[3, 2, 0, 0, 0, 3];
    const gOverBFrets = <int?>[null, 2, 0, 0, 0, 3];

    List<StructuredTabBeat> offbeatChordBar(
      List<int?> frets, {
      bool includePickMarks = false,
    }) {
      return <StructuredTabBeat>[
        StructuredTabBeat(
          kind: StructuredTabBeatKind.rest,
          duration: StructuredTabDuration.quarter,
        ),
        StructuredTabBeat(
          kind: StructuredTabBeatKind.chordStack,
          duration: StructuredTabDuration.quarter,
          frets: frets,
          staccato: true,
          pickDirection: includePickMarks ? StructuredPickDirection.down : null,
        ),
        StructuredTabBeat(
          kind: StructuredTabBeatKind.rest,
          duration: StructuredTabDuration.eighth,
        ),
        StructuredTabBeat(
          kind: StructuredTabBeatKind.rhythmSlash,
          duration: StructuredTabDuration.eighth,
          pickDirection: includePickMarks ? StructuredPickDirection.up : null,
        ),
        StructuredTabBeat(
          kind: StructuredTabBeatKind.rest,
          duration: StructuredTabDuration.quarter,
        ),
      ];
    }

    List<StructuredTabBeat> offbeatContinueBar() {
      return <StructuredTabBeat>[
        StructuredTabBeat(
          kind: StructuredTabBeatKind.rest,
          duration: StructuredTabDuration.quarter,
        ),
        StructuredTabBeat(
          kind: StructuredTabBeatKind.rhythmSlash,
          duration: StructuredTabDuration.quarter,
          staccato: true,
        ),
        StructuredTabBeat(
          kind: StructuredTabBeatKind.rest,
          duration: StructuredTabDuration.eighth,
        ),
        StructuredTabBeat(
          kind: StructuredTabBeatKind.rhythmSlash,
          duration: StructuredTabDuration.eighth,
        ),
        StructuredTabBeat(
          kind: StructuredTabBeatKind.rest,
          duration: StructuredTabDuration.quarter,
        ),
      ];
    }

    List<StructuredTabBeat> eighthDriveFillBar({
      List<int?>? firstHitFrets,
      bool includePickMarks = false,
    }) {
      return <StructuredTabBeat>[
        StructuredTabBeat(
          kind: StructuredTabBeatKind.rest,
          duration: StructuredTabDuration.eighth,
        ),
        StructuredTabBeat(
          kind: firstHitFrets != null
              ? StructuredTabBeatKind.chordStack
              : StructuredTabBeatKind.rhythmSlash,
          duration: StructuredTabDuration.eighth,
          frets: firstHitFrets,
          pickDirection: includePickMarks ? StructuredPickDirection.up : null,
        ),
        StructuredTabBeat(
          kind: StructuredTabBeatKind.rhythmSlash,
          duration: StructuredTabDuration.eighth,
          beamGroup: 'b2',
          pickDirection: includePickMarks ? StructuredPickDirection.down : null,
        ),
        StructuredTabBeat(
          kind: StructuredTabBeatKind.rhythmSlash,
          duration: StructuredTabDuration.eighth,
          beamGroup: 'b2',
          pickDirection: includePickMarks ? StructuredPickDirection.up : null,
        ),
        StructuredTabBeat(
          kind: StructuredTabBeatKind.rhythmSlash,
          duration: StructuredTabDuration.eighth,
          beamGroup: 'b34',
          pickDirection: includePickMarks ? StructuredPickDirection.down : null,
        ),
        StructuredTabBeat(
          kind: StructuredTabBeatKind.rhythmSlash,
          duration: StructuredTabDuration.eighth,
          beamGroup: 'b34',
          pickDirection: includePickMarks ? StructuredPickDirection.up : null,
        ),
        StructuredTabBeat(
          kind: StructuredTabBeatKind.rhythmSlash,
          duration: StructuredTabDuration.eighth,
          beamGroup: 'b34',
          pickDirection: includePickMarks ? StructuredPickDirection.down : null,
        ),
        StructuredTabBeat(
          kind: StructuredTabBeatKind.rhythmSlash,
          duration: StructuredTabDuration.eighth,
          beamGroup: 'b34',
          pickDirection: includePickMarks ? StructuredPickDirection.up : null,
        ),
      ];
    }

    List<StructuredTabBeat> fullEighthSlashBar() {
      return <StructuredTabBeat>[
        for (var i = 0; i < 4; i++)
          StructuredTabBeat(
            kind: StructuredTabBeatKind.rhythmSlash,
            duration: StructuredTabDuration.eighth,
            beamGroup: 'g12',
          ),
        for (var i = 0; i < 4; i++)
          StructuredTabBeat(
            kind: StructuredTabBeatKind.rhythmSlash,
            duration: StructuredTabDuration.eighth,
            beamGroup: 'g34',
          ),
      ];
    }

    return StructuredGuitarTabScore(
      id: 'offbeat-pop-stroke-etude',
      title: 'オフビート・ポップストローク総合練習（オリジナル）',
      artist: 'オリジナル練習譜',
      tuning: 'Standard tuning',
      capo: 'Capo fret 3',
      bpm: 154,
      beatsPerMeasure: 4,
      beatUnit: 4,
      isOriginalPractice: true,
      summary:
          '2拍・3拍ウラのキレのあるカッティングと、反復・1/2番カッコ・D.S. al Coda の譜面進行を実践するオリジナル教材です。',
      chords: const <StructuredChordDiagram>[
        StructuredChordDiagram(name: 'C', frets: <int>[-1, 3, 2, 0, 1, 0]),
        StructuredChordDiagram(name: 'Am', frets: <int>[-1, 0, 2, 2, 1, 0]),
        StructuredChordDiagram(
          name: 'F',
          frets: <int>[1, 3, 3, 2, 1, 1],
          barre: StructuredChordBarre(
            fret: 1,
            startStringIndex: 0,
            endStringIndex: 5,
          ),
        ),
        StructuredChordDiagram(name: 'G', frets: <int>[3, 2, 0, 0, 0, 3]),
        StructuredChordDiagram(name: 'G/B', frets: <int>[-1, 2, 0, 0, 0, 3]),
      ],
      measures: <StructuredTabMeasure>[
        // Intro (1-4)
        StructuredTabMeasure(
          number: 1,
          rehearsalMark: 'Intro',
          boxedRehearsalMark: false,
          chordSymbol: 'C',
          repeatStart: true,
          beats: offbeatChordBar(cFrets, includePickMarks: true),
        ),
        StructuredTabMeasure(
          number: 2,
          beats: offbeatContinueBar(),
        ),
        StructuredTabMeasure(
          number: 3,
          chordSymbol: 'Am',
          beats: offbeatChordBar(amFrets),
        ),
        StructuredTabMeasure(
          number: 4,
          repeatEnd: true,
          beats: offbeatContinueBar(),
        ),
        // [A] (5-12)
        StructuredTabMeasure(
          number: 5,
          rehearsalMark: 'A',
          hasSegno: true,
          topNote: '(D.S. time Straight)',
          repeatStart: true,
          chordSymbol: 'C',
          beats: offbeatChordBar(cFrets),
        ),
        StructuredTabMeasure(
          number: 6,
          beats: offbeatContinueBar(),
        ),
        StructuredTabMeasure(
          number: 7,
          chordSymbol: 'Am',
          beats: offbeatChordBar(amFrets),
        ),
        StructuredTabMeasure(
          number: 8,
          beats: offbeatContinueBar(),
        ),
        StructuredTabMeasure(
          number: 9,
          chordSymbol: 'F',
          beats: offbeatChordBar(fFrets),
        ),
        StructuredTabMeasure(
          number: 10,
          chordSymbol: 'G',
          beats: offbeatChordBar(gFrets),
        ),
        StructuredTabMeasure(
          number: 11,
          chordSymbol: 'G',
          volta: '1.',
          repeatEnd: true,
          beats: eighthDriveFillBar(
            firstHitFrets: gFrets,
            includePickMarks: true,
          ),
        ),
        StructuredTabMeasure(
          number: 12,
          chordSymbol: 'C',
          volta: '2.',
          beats: offbeatChordBar(cFrets),
        ),
        // [B] (13-16)
        StructuredTabMeasure(
          number: 13,
          rehearsalMark: 'B',
          chordSymbol: 'F',
          beats: offbeatChordBar(fFrets),
        ),
        StructuredTabMeasure(
          number: 14,
          chordSymbol: 'G',
          beats: offbeatChordBar(gFrets),
        ),
        StructuredTabMeasure(
          number: 15,
          chordSymbol: 'C',
          topNote: 'Da Coda',
          beats: offbeatChordBar(cFrets),
        ),
        StructuredTabMeasure(
          number: 16,
          beats: fullEighthSlashBar(),
        ),
        // [C] (17-20)
        StructuredTabMeasure(
          number: 17,
          rehearsalMark: 'C',
          chordSymbol: 'F',
          beats: offbeatChordBar(fFrets),
        ),
        StructuredTabMeasure(
          number: 18,
          beats: offbeatContinueBar(),
        ),
        StructuredTabMeasure(
          number: 19,
          chordSymbol: 'G',
          beats: offbeatChordBar(gFrets),
        ),
        StructuredTabMeasure(
          number: 20,
          topNote: 'D.S. al Coda',
          beats: fullEighthSlashBar(),
        ),
        // Coda (21-22)
        StructuredTabMeasure(
          number: 21,
          hasCoda: true,
          chordSymbol: 'C',
          beats: <StructuredTabBeat>[
            StructuredTabBeat(
              kind: StructuredTabBeatKind.rest,
              duration: StructuredTabDuration.quarter,
            ),
            StructuredTabBeat(
              kind: StructuredTabBeatKind.chordStack,
              duration: StructuredTabDuration.quarter,
              frets: cFrets,
            ),
            StructuredTabBeat(
              kind: StructuredTabBeatKind.rest,
              duration: StructuredTabDuration.quarter,
            ),
            StructuredTabBeat(
              kind: StructuredTabBeatKind.chordStack,
              duration: StructuredTabDuration.quarter,
              frets: gOverBFrets,
              chordSymbol: 'G/B',
            ),
          ],
        ),
        StructuredTabMeasure(
          number: 22,
          chordSymbol: 'Am',
          beats: offbeatChordBar(amFrets),
        ),
        // [D] (23-24)
        StructuredTabMeasure(
          number: 23,
          rehearsalMark: 'D',
          chordSymbol: 'F',
          repeatStart: true,
          beats: offbeatChordBar(fFrets),
        ),
        StructuredTabMeasure(
          number: 24,
          chordSymbol: 'G',
          topNote: 'Repeat & Fade Out.',
          repeatEnd: true,
          beats: offbeatChordBar(gFrets),
        ),
      ],
    );
  }

  static StructuredGuitarTabScore _buildOpenArpeggioEtude() {
    List<StructuredTabBeat> arpeggioPattern(List<int> bassAndTop) {
      // bassAndTop: [6弦/5弦バスインデックス, フレット, 3弦フレット, 2弦フレット, 1弦フレット]
      final bassString = bassAndTop[0];
      final bassFret = bassAndTop[1];
      final gFret = bassAndTop[2];
      final bFret = bassAndTop[3];
      final eFret = bassAndTop[4];

      List<int?> singleNote(int stringIndex, int fret) {
        final list = <int?>[null, null, null, null, null, null];
        list[stringIndex] = fret;
        return list;
      }

      return <StructuredTabBeat>[
        StructuredTabBeat(
          kind: StructuredTabBeatKind.chordStack,
          duration: StructuredTabDuration.eighth,
          frets: singleNote(bassString, bassFret),
          beamGroup: 'a1',
        ),
        StructuredTabBeat(
          kind: StructuredTabBeatKind.chordStack,
          duration: StructuredTabDuration.eighth,
          frets: singleNote(3, gFret),
          beamGroup: 'a1',
        ),
        StructuredTabBeat(
          kind: StructuredTabBeatKind.chordStack,
          duration: StructuredTabDuration.eighth,
          frets: singleNote(4, bFret),
          beamGroup: 'a1',
        ),
        StructuredTabBeat(
          kind: StructuredTabBeatKind.chordStack,
          duration: StructuredTabDuration.eighth,
          frets: singleNote(5, eFret),
          beamGroup: 'a1',
        ),
        StructuredTabBeat(
          kind: StructuredTabBeatKind.chordStack,
          duration: StructuredTabDuration.eighth,
          frets: singleNote(4, bFret),
          beamGroup: 'a2',
        ),
        StructuredTabBeat(
          kind: StructuredTabBeatKind.chordStack,
          duration: StructuredTabDuration.eighth,
          frets: singleNote(3, gFret),
          beamGroup: 'a2',
        ),
        StructuredTabBeat(
          kind: StructuredTabBeatKind.chordStack,
          duration: StructuredTabDuration.quarter,
          frets: singleNote(4, bFret),
        ),
      ];
    }

    return StructuredGuitarTabScore(
      id: 'open-arpeggio-cadence-etude',
      title: '開放弦アルペジオ・カデンツ練習（オリジナル）',
      artist: 'オリジナル練習譜',
      tuning: 'Standard tuning',
      capo: 'なし',
      bpm: 88,
      beatsPerMeasure: 4,
      beatUnit: 4,
      isOriginalPractice: true,
      summary: 'Em・C・G・D の基本コードで低音弦から高音弦へ均一に鳴らす8分音符アルペジオ練習です。',
      chords: const <StructuredChordDiagram>[
        StructuredChordDiagram(name: 'Em', frets: <int>[0, 2, 2, 0, 0, 0]),
        StructuredChordDiagram(name: 'C', frets: <int>[-1, 3, 2, 0, 1, 0]),
        StructuredChordDiagram(name: 'G', frets: <int>[3, 2, 0, 0, 0, 3]),
        StructuredChordDiagram(name: 'D', frets: <int>[-1, -1, 0, 2, 3, 2]),
      ],
      measures: <StructuredTabMeasure>[
        StructuredTabMeasure(
          number: 1,
          rehearsalMark: 'A',
          chordSymbol: 'Em',
          repeatStart: true,
          beats: arpeggioPattern(<int>[0, 0, 0, 0, 0]),
        ),
        StructuredTabMeasure(
          number: 2,
          chordSymbol: 'C',
          beats: arpeggioPattern(<int>[1, 3, 0, 1, 0]),
        ),
        StructuredTabMeasure(
          number: 3,
          chordSymbol: 'G',
          beats: arpeggioPattern(<int>[0, 3, 0, 0, 3]),
        ),
        StructuredTabMeasure(
          number: 4,
          chordSymbol: 'D',
          repeatEnd: true,
          beats: arpeggioPattern(<int>[2, 0, 2, 3, 2]),
        ),
      ],
    );
  }
}
