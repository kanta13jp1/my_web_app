import 'package:chord_pro/chord_pro.dart' show ChordDefinition;
import 'package:guitar_chord_library/guitar_chord_library.dart'
    show ChordHelper, ChordPosition, GuitarChordLibrary;

import '../../domain/models/structured_guitar_tab.dart';

/// コード図解決結果（N.C. や未知コードへのフォールバック状態を含む）。
class ResolvedGuitarChordDiagram {
  const ResolvedGuitarChordDiagram({
    required this.diagram,
    this.isNoChord = false,
    this.hasDiagram = true,
  });

  final StructuredChordDiagram diagram;
  final bool isNoChord;
  final bool hasDiagram;
}

/// ChordPro 定義・定番ボイシング辞書・`guitar_chord_library` から
/// [StructuredChordDiagram]（6弦=index 0 .. 1弦=index 5 の絶対フレット表記）を解決する。
class GuitarChordVoicingResolver {
  const GuitarChordVoicingResolver();

  static final RegExp _spacesRe = RegExp(r'\s+');

  ResolvedGuitarChordDiagram resolve(
    String rawChordName, {
    List<ChordDefinition> songDefinitions = const <ChordDefinition>[],
  }) {
    final displayName = rawChordName.trim();
    if (displayName.isEmpty) {
      return const ResolvedGuitarChordDiagram(
        diagram: StructuredChordDiagram(
          name: '',
          frets: <int>[-1, -1, -1, -1, -1, -1],
        ),
        hasDiagram: false,
      );
    }

    final normalizedInput = _normalizeAccidentals(displayName);
    if (_isNoChordName(normalizedInput)) {
      return const ResolvedGuitarChordDiagram(
        diagram: StructuredChordDiagram(
          name: 'N.C.',
          frets: <int>[-1, -1, -1, -1, -1, -1],
        ),
        isNoChord: true,
        hasDiagram: true,
      );
    }

    final defined = _fromSongDefinitions(
      displayName: displayName,
      normalizedInput: normalizedInput,
      definitions: songDefinitions,
    );
    if (defined != null) {
      return ResolvedGuitarChordDiagram(diagram: defined);
    }

    final canonicalKey = _canonicalLookupKey(normalizedInput);
    final curated = _curatedVoicings[canonicalKey];
    if (curated != null) {
      return ResolvedGuitarChordDiagram(
        diagram: StructuredChordDiagram(
          name: displayName,
          frets: curated.frets,
          baseFret: curated.baseFret,
          barre: curated.barre,
        ),
      );
    }

    final fromLibrary = _lookupInLibrary(
      displayName: displayName,
      normalizedChord: normalizedInput,
    );
    if (fromLibrary != null) {
      return ResolvedGuitarChordDiagram(diagram: fromLibrary);
    }

    // 未登録の分数コード（例: D#maj7/D）はルート側和音の押弦図へ優雅にフォールバックする。
    final slashIndex = normalizedInput.indexOf('/');
    if (slashIndex > 0) {
      final headOnly = normalizedInput.substring(0, slashIndex).trim();
      if (headOnly.isNotEmpty) {
        final headCurated = _curatedVoicings[_canonicalLookupKey(headOnly)];
        if (headCurated != null) {
          return ResolvedGuitarChordDiagram(
            diagram: StructuredChordDiagram(
              name: displayName,
              frets: headCurated.frets,
              baseFret: headCurated.baseFret,
              barre: headCurated.barre,
            ),
          );
        }
        final headLibrary = _lookupInLibrary(
          displayName: displayName,
          normalizedChord: headOnly,
        );
        if (headLibrary != null) {
          return ResolvedGuitarChordDiagram(diagram: headLibrary);
        }
      }
    }

    return ResolvedGuitarChordDiagram(
      diagram: StructuredChordDiagram(
        name: displayName,
        frets: const <int>[-1, -1, -1, -1, -1, -1],
      ),
      hasDiagram: false,
    );
  }

  static bool _isNoChordName(String value) {
    final upper = value.toUpperCase();
    return upper == 'N.C.' || upper == 'N.C' || upper == 'NC';
  }

  static String _normalizeAccidentals(String value) {
    return value
        .replaceAll('♯', '#')
        .replaceAll('♭', 'b')
        .replaceAll(_spacesRe, '');
  }

  static String _canonicalLookupKey(String normalizedChord) {
    final slashIdx = normalizedChord.indexOf('/');
    if (slashIdx > 0 && slashIdx < normalizedChord.length - 1) {
      final head = _canonicalSimpleChord(normalizedChord.substring(0, slashIdx));
      final bass = _normalizeRootToken(normalizedChord.substring(slashIdx + 1));
      return '$head/$bass';
    }
    return _canonicalSimpleChord(normalizedChord);
  }

  static String _canonicalSimpleChord(String simple) {
    final parsed = ChordHelper.parseChordName(simple);
    if (parsed == null) return simple;
    final sharpRoot = _normalizeRootToken(parsed.key);
    final suffix = switch (parsed.suffix) {
      'major' || 'maj' || 'M' => '',
      'minor' || 'min' => 'm',
      'm7-5' || 'm7♭5' => 'm7b5',
      _ => parsed.suffix.replaceAll('-5', 'b5'),
    };
    return '$sharpRoot$suffix';
  }

  static String _normalizeRootToken(String root) {
    return _flatToSharpRoot[root] ?? root;
  }

  static StructuredChordDiagram? _fromSongDefinitions({
    required String displayName,
    required String normalizedInput,
    required List<ChordDefinition> definitions,
  }) {
    for (final def in definitions) {
      final defNorm = _normalizeAccidentals(def.name.trim());
      if (defNorm != normalizedInput || def.frets.length != 6) {
        continue;
      }
      final base = (def.baseFret ?? 1).clamp(1, 24);
      final absFrets = <int>[
        for (final raw in def.frets)
          if (raw == null || raw < 0)
            -1
          else if (raw == 0)
            0
          else
            raw + (base - 1),
      ];
      final barre = _inferBarreFromFingers(
        absFrets: absFrets,
        fingers: <int>[
          for (final f in def.fingers)
            if (f is int) f else 0,
        ],
      );
      return StructuredChordDiagram(
        name: displayName,
        frets: absFrets,
        baseFret: base,
        barre: barre,
      );
    }
    return null;
  }

  static StructuredChordDiagram? _lookupInLibrary({
    required String displayName,
    required String normalizedChord,
  }) {
    final guitar = GuitarChordLibrary.instrument();
    final parsed = ChordHelper.parseChordName(normalizedChord);
    if (parsed == null) return null;

    var positions = guitar.getChordPositions(parsed.key, parsed.suffix);
    if ((positions == null || positions.isEmpty) &&
        normalizedChord.contains('/')) {
      final slashIdx = normalizedChord.indexOf('/');
      final head = normalizedChord.substring(0, slashIdx);
      final bass = normalizedChord.substring(slashIdx + 1);
      final parsedHead = ChordHelper.parseChordName(head);
      if (parsedHead != null) {
        final suffixPrefix = switch (parsedHead.suffix) {
          'major' => '',
          'minor' => 'm',
          _ => parsedHead.suffix,
        };
        positions = guitar.getChordPositions(
          parsedHead.key,
          '$suffixPrefix/$bass',
        );
      }
    }
    if (positions == null || positions.isEmpty) return null;

    final chosen = _pickErgonomicPosition(positions);
    final rawFrets = chosen.fretList;
    if (rawFrets.length != 6) return null;

    // guitar_chord_library は baseFret > 1 のとき押弦位置を相対値で保持するため絶対フレットへ変換する。
    final baseFret = chosen.baseFret.clamp(1, 24);
    final absFrets = <int>[
      for (final f in rawFrets)
        if (f < 0)
          -1
        else if (f == 0)
          0
        else
          f + (baseFret - 1),
    ];
    final barre = _inferBarreFromFingers(
      absFrets: absFrets,
      fingers: chosen.fingerList,
    );
    return StructuredChordDiagram(
      name: displayName,
      frets: absFrets,
      baseFret: baseFret,
      barre: barre,
    );
  }

  static ChordPosition _pickErgonomicPosition(List<ChordPosition> positions) {
    for (final pos in positions) {
      final sounding = pos.fretList.where((int f) => f >= 0).length;
      if (pos.baseFret <= 7 && sounding >= 5) {
        return pos;
      }
    }
    for (final pos in positions) {
      if (pos.baseFret <= 8) return pos;
    }
    return positions.first;
  }

  static StructuredChordBarre? _inferBarreFromFingers({
    required List<int> absFrets,
    required List<int> fingers,
  }) {
    if (absFrets.length != 6 || fingers.length != 6) return null;
    final indicesByFret = <int, List<int>>{};
    for (var s = 0; s < 6; s++) {
      final fret = absFrets[s];
      if (fret > 0 && fingers[s] == 1) {
        indicesByFret.putIfAbsent(fret, () => <int>[]).add(s);
      }
    }
    for (final entry in indicesByFret.entries) {
      final fret = entry.key;
      final strings = entry.value;
      if (strings.length < 2) continue;
      final start = strings.first;
      final end = strings.last;
      var validSpan = true;
      for (var s = start; s <= end; s++) {
        final f = absFrets[s];
        if (f == 0 || (f > 0 && f < fret)) {
          validSpan = false;
          break;
        }
      }
      if (validSpan) {
        return StructuredChordBarre(
          fret: fret,
          startStringIndex: start,
          endStringIndex: end,
        );
      }
    }
    return null;
  }

  static const Map<String, String> _flatToSharpRoot = <String, String>{
    'Db': 'C#',
    'Eb': 'D#',
    'Gb': 'F#',
    'Ab': 'G#',
    'Bb': 'A#',
    'Cb': 'B',
    'Fb': 'E',
    'E#': 'F',
    'B#': 'C',
  };

  static const Map<String, _CuratedVoicing> _curatedVoicings =
      <String, _CuratedVoicing>{
    'C': _CuratedVoicing(frets: <int>[-1, 3, 2, 0, 1, 0]),
    'Cmaj7': _CuratedVoicing(frets: <int>[-1, 3, 2, 0, 0, 0]),
    'C7': _CuratedVoicing(frets: <int>[-1, 3, 2, 3, 1, 0]),
    'C/B': _CuratedVoicing(frets: <int>[-1, 2, 2, 0, 1, 0]),
    'C/G': _CuratedVoicing(frets: <int>[3, 3, 2, 0, 1, 0]),
    'Cm': _CuratedVoicing(
      baseFret: 3,
      frets: <int>[-1, 3, 5, 5, 4, 3],
      barre: StructuredChordBarre(
        fret: 3,
        startStringIndex: 1,
        endStringIndex: 5,
      ),
    ),
    'D': _CuratedVoicing(frets: <int>[-1, -1, 0, 2, 3, 2]),
    'Dm': _CuratedVoicing(frets: <int>[-1, -1, 0, 2, 3, 1]),
    'Dm7': _CuratedVoicing(frets: <int>[-1, -1, 0, 2, 1, 1]),
    'D7': _CuratedVoicing(frets: <int>[-1, -1, 0, 2, 1, 2]),
    'D/F#': _CuratedVoicing(frets: <int>[2, -1, 0, 2, 3, 2]),
    'D#': _CuratedVoicing(
      baseFret: 6,
      frets: <int>[-1, 6, 8, 8, 8, 6],
      barre: StructuredChordBarre(
        fret: 6,
        startStringIndex: 1,
        endStringIndex: 5,
      ),
    ),
    'D#/D': _CuratedVoicing(frets: <int>[-1, -1, 0, 3, 4, 3]),
    'E': _CuratedVoicing(frets: <int>[0, 2, 2, 1, 0, 0]),
    'Em': _CuratedVoicing(frets: <int>[0, 2, 2, 0, 0, 0]),
    'Em7': _CuratedVoicing(frets: <int>[0, 2, 0, 0, 0, 0]),
    'E7': _CuratedVoicing(frets: <int>[0, 2, 0, 1, 0, 0]),
    'F': _CuratedVoicing(
      frets: <int>[1, 3, 3, 2, 1, 1],
      barre: StructuredChordBarre(
        fret: 1,
        startStringIndex: 0,
        endStringIndex: 5,
      ),
    ),
    'Fmaj7': _CuratedVoicing(frets: <int>[-1, -1, 3, 2, 1, 0]),
    'Fm': _CuratedVoicing(
      frets: <int>[1, 3, 3, 1, 1, 1],
      barre: StructuredChordBarre(
        fret: 1,
        startStringIndex: 0,
        endStringIndex: 5,
      ),
    ),
    'F/G': _CuratedVoicing(frets: <int>[3, -1, 3, 2, 1, 1]),
    'F#m7b5': _CuratedVoicing(frets: <int>[2, -1, 2, 2, 1, -1]),
    'G': _CuratedVoicing(frets: <int>[3, 2, 0, 0, 0, 3]),
    'G7': _CuratedVoicing(frets: <int>[3, 2, 0, 0, 0, 1]),
    'G/B': _CuratedVoicing(frets: <int>[-1, 2, 0, 0, 0, 3]),
    'G/F': _CuratedVoicing(frets: <int>[1, -1, 0, 0, 0, 3]),
    'G#': _CuratedVoicing(
      baseFret: 4,
      frets: <int>[4, 6, 6, 5, 4, 4],
      barre: StructuredChordBarre(
        fret: 4,
        startStringIndex: 0,
        endStringIndex: 5,
      ),
    ),
    'A': _CuratedVoicing(frets: <int>[-1, 0, 2, 2, 2, 0]),
    'Am': _CuratedVoicing(frets: <int>[-1, 0, 2, 2, 1, 0]),
    'Am7': _CuratedVoicing(frets: <int>[-1, 0, 2, 0, 1, 0]),
    'Am/G': _CuratedVoicing(frets: <int>[3, 0, 2, 2, 1, 0]),
    'A7': _CuratedVoicing(frets: <int>[-1, 0, 2, 0, 2, 0]),
    'A#': _CuratedVoicing(
      frets: <int>[-1, 1, 3, 3, 3, 1],
      barre: StructuredChordBarre(
        fret: 1,
        startStringIndex: 1,
        endStringIndex: 5,
      ),
    ),
    'A#7': _CuratedVoicing(
      frets: <int>[-1, 1, 3, 1, 3, 1],
      barre: StructuredChordBarre(
        fret: 1,
        startStringIndex: 1,
        endStringIndex: 5,
      ),
    ),
    'Bm': _CuratedVoicing(
      baseFret: 2,
      frets: <int>[-1, 2, 4, 4, 3, 2],
      barre: StructuredChordBarre(
        fret: 2,
        startStringIndex: 1,
        endStringIndex: 5,
      ),
    ),
    'Bm7b5': _CuratedVoicing(frets: <int>[-1, 2, 3, 2, 3, -1]),
  };
}

class _CuratedVoicing {
  const _CuratedVoicing({
    this.baseFret = 1,
    required this.frets,
    this.barre,
  });

  final int baseFret;
  final List<int> frets;
  final StructuredChordBarre? barre;
}
