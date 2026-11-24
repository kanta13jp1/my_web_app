import 'package:chord_pro/chord_pro.dart' show ChordPro;
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/services/chord_lyrics_catalog_service.dart';
import 'package:my_web_app/data/services/guitar_chord_voicing_resolver.dart';
import 'package:my_web_app/domain/models/chord_lyrics_sheet.dart';

void main() {
  const resolver = GuitarChordVoicingResolver();

  test('resolves N.C., curated high-fret chords, and slash chords', () {
    final noChord = resolver.resolve('N.C.');
    expect(noChord.isNoChord, isTrue);
    expect(noChord.hasDiagram, isTrue);
    expect(noChord.diagram.name, 'N.C.');
    expect(noChord.diagram.frets, <int>[-1, -1, -1, -1, -1, -1]);

    final dSharp = resolver.resolve('D#');
    expect(dSharp.hasDiagram, isTrue);
    expect(dSharp.diagram.baseFret, 6);
    expect(dSharp.diagram.frets, <int>[-1, 6, 8, 8, 8, 6]);
    expect(dSharp.diagram.barre?.fret, 6);

    final cMinor = resolver.resolve('Cm');
    expect(cMinor.diagram.baseFret, 3);
    expect(cMinor.diagram.frets, <int>[-1, 3, 5, 5, 4, 3]);

    final gSharp = resolver.resolve('G#');
    expect(gSharp.diagram.baseFret, 4);
    expect(gSharp.diagram.frets, <int>[4, 6, 6, 5, 4, 4]);

    final dSharpOverD = resolver.resolve('D#/D');
    expect(dSharpOverD.hasDiagram, isTrue);
    expect(dSharpOverD.diagram.frets, <int>[-1, -1, 0, 3, 4, 3]);

    // Enharmonic spelling preserves display name while reusing D# 6th-fret voicing.
    final eFlat = resolver.resolve('Eb');
    expect(eFlat.hasDiagram, isTrue);
    expect(eFlat.diagram.name, 'Eb');
    expect(eFlat.diagram.baseFret, 6);
    expect(eFlat.diagram.frets, <int>[-1, 6, 8, 8, 8, 6]);
  });

  test('prefers song {define} directives and converts relative frets', () {
    final song = ChordPro.parseSong(
      '{define: CustomG base-fret 3 frets - 3 2 0 1 0}\n[CustomG]テスト',
    );
    final custom = resolver.resolve(
      'CustomG',
      songDefinitions: song.chordDefinitions,
    );
    expect(custom.hasDiagram, isTrue);
    expect(custom.diagram.baseFret, 3);
    expect(custom.diagram.frets, <int>[-1, 5, 4, 0, 3, 0]);
  });

  test(
    'falls back to guitar_chord_library with absolute frets and slash fallback',
    () {
      final fSharpMinor = resolver.resolve('F#m');
      expect(fSharpMinor.hasDiagram, isTrue);
      for (final fret in fSharpMinor.diagram.frets) {
        if (fret > 0) {
          expect(fret, greaterThanOrEqualTo(fSharpMinor.diagram.baseFret));
        }
      }

      final slashFallback = resolver.resolve('Fmaj7/C');
      expect(slashFallback.hasDiagram, isTrue);
      expect(slashFallback.diagram.name, 'Fmaj7/C');

      final unknown = resolver.resolve('Xyz99');
      expect(unknown.hasDiagram, isFalse);
    },
  );

  test('transposes D# original practice preset to C shapes when Capo 3 is set',
      () async {
    const catalog = LocalChordLyricsCatalogService();
    final presets = await catalog.fetchPresetSheets();
    final original = presets.firstWhere(
      (ChordLyricsSheetDocument s) => s.id == 'midnight-train-etude',
    );

    final capo0 = parseChordLyricsDocument(original, capoFret: 0);
    expect(capo0.effectiveKeyLabel, 'D#');
    final capo0Chords = capo0.sections
        .expand((s) => s.lines)
        .expand((l) => l.clusters)
        .map((c) => c.chordLabel)
        .whereType<String>()
        .toList();
    expect(
      capo0Chords,
      containsAll(<String>['N.C.', 'D#', 'Cm', 'G#', 'A#', 'D#/D']),
    );

    final capo3 = parseChordLyricsDocument(original, capoFret: 3);
    expect(capo3.effectiveKeyLabel, 'C');
    final capo3Chords = capo3.sections
        .expand((s) => s.lines)
        .expand((l) => l.clusters)
        .map((c) => c.chordLabel)
        .whereType<String>()
        .toList();
    expect(
      capo3Chords,
      containsAll(<String>['N.C.', 'C', 'Am', 'F', 'G', 'C/B']),
    );

    final lyrics = capo3.sections
        .expand((s) => s.lines)
        .expand((l) => l.clusters)
        .map((c) => c.lyricText)
        .join();
    expect(lyrics, contains('夜汽車の窓に映る'));
    expect(lyrics, contains('向こうへ'));
  });

  test('validates user ChordPro input cleanly', () {
    expect(
      () => buildUserChordLyricsDocument(id: 'u1', rawChordPro: '   '),
      throwsFormatException,
    );
    final doc = buildUserChordLyricsDocument(
      id: 'u1',
      rawChordPro: '{title: 練習メモ}\n{key: G}\n[G]テスト歌詞[D]',
    );
    expect(doc.title, '練習メモ');
    expect(doc.keyLabel, 'G');
    expect(doc.isUserImported, isTrue);
  });
}
