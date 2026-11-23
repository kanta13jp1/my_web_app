import 'dart:convert';

import 'package:chord_pro/chord_pro.dart'
    show
        AccidentalPreference,
        AnnotationToken,
        Chord,
        ChordPro,
        ChordRecallToken,
        ChordSystem,
        ChordToken,
        LineKind,
        SectionKind,
        Song,
        TextToken;

import '../../data/services/guitar_chord_voicing_resolver.dart';

/// 端末またはカタログが保持する ChordPro 弾き語り譜面の正本モデル。
class ChordLyricsSheetDocument {
  const ChordLyricsSheetDocument({
    required this.id,
    required this.title,
    required this.artist,
    required this.keyLabel,
    required this.defaultCapo,
    required this.description,
    required this.sourceChordPro,
    this.isUserImported = false,
  });

  final String id;
  final String title;
  final String artist;
  final String keyLabel;
  final int defaultCapo;
  final String description;
  final String sourceChordPro;
  final bool isUserImported;

  ChordLyricsSheetDocument copyWith({
    String? id,
    String? title,
    String? artist,
    String? keyLabel,
    int? defaultCapo,
    String? description,
    String? sourceChordPro,
    bool? isUserImported,
  }) {
    return ChordLyricsSheetDocument(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      keyLabel: keyLabel ?? this.keyLabel,
      defaultCapo: defaultCapo ?? this.defaultCapo,
      description: description ?? this.description,
      sourceChordPro: sourceChordPro ?? this.sourceChordPro,
      isUserImported: isUserImported ?? this.isUserImported,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'title': title,
      'artist': artist,
      'keyLabel': keyLabel,
      'defaultCapo': defaultCapo,
      'description': description,
      'sourceChordPro': sourceChordPro,
    };
  }

  static ChordLyricsSheetDocument fromJson(
    Map<String, dynamic> map, {
    bool isUserImported = false,
  }) {
    final id = _readNonEmptyString(map['id'], 'id');
    final title = _readNonEmptyString(map['title'], 'title');
    final artist = _readNonEmptyString(
      map['artist'] ?? 'マイ譜面',
      'artist',
    );
    final keyLabel = _readNonEmptyString(map['keyLabel'] ?? 'C', 'keyLabel');
    final rawCapo = map['defaultCapo'];
    final defaultCapo = rawCapo is num ? rawCapo.round().clamp(0, 7) : 0;
    final description = (map['description'] as String?)?.trim() ?? '';
    final source = _readNonEmptyString(
      map['sourceChordPro'],
      'sourceChordPro',
    );

    return ChordLyricsSheetDocument(
      id: id,
      title: title,
      artist: artist,
      keyLabel: keyLabel,
      defaultCapo: defaultCapo,
      description: description,
      sourceChordPro: source,
      isUserImported: isUserImported,
    );
  }

  static String _readNonEmptyString(Object? raw, String field) {
    if (raw is! String || raw.trim().isEmpty) {
      throw FormatException('弾き語り譜面の $field が空または不正です。');
    }
    return raw.trim();
  }
}

/// 横向きコード図＋歌詞セグメントの不可分ペア。
class ChordLyricCluster {
  const ChordLyricCluster({
    required this.lyricText,
    this.chordLabel,
    this.diagram,
  });

  final String lyricText;
  final String? chordLabel;
  final ResolvedGuitarChordDiagram? diagram;

  bool get hasChord => chordLabel != null && chordLabel!.isNotEmpty;
}

/// 1行分のレンダリング単位（構造化行・注釈コメント行・TABそのまま行）。
class ChordLyricsLineView {
  const ChordLyricsLineView({
    required this.clusters,
    this.commentText,
    this.verbatimText,
  });

  final List<ChordLyricCluster> clusters;
  final String? commentText;
  final String? verbatimText;

  bool get isEmpty =>
      commentText == null && verbatimText == null && clusters.isEmpty;

  bool get hasLyrics => clusters.any(
        (ChordLyricCluster cluster) => cluster.lyricText.trim().isNotEmpty,
      );
}

/// セクション単位（Verse / Chorus / Bridge 等）のコード譜ブロック。
class ChordLyricsSectionView {
  const ChordLyricsSectionView({
    this.label,
    required this.lines,
  });

  final String? label;
  final List<ChordLyricsLineView> lines;
}

/// カポ・移調適用後の弾き語りコード譜ビュー状態。
class ParsedChordLyricsSong {
  const ParsedChordLyricsSong({
    required this.title,
    required this.subtitle,
    required this.effectiveKeyLabel,
    required this.capoFret,
    required this.transposeSemitones,
    required this.tempoBpm,
    required this.sections,
    required this.uniqueDiagrams,
  });

  final String title;
  final String subtitle;
  final String effectiveKeyLabel;
  final int capoFret;
  final int transposeSemitones;
  final int? tempoBpm;
  final List<ChordLyricsSectionView> sections;
  final List<ResolvedGuitarChordDiagram> uniqueDiagrams;
}

/// ChordPro 生テキストを解析し、カポ・移調を反映した [ParsedChordLyricsSong] を構築する。
ParsedChordLyricsSong parseChordLyricsDocument(
  ChordLyricsSheetDocument document, {
  int capoFret = 0,
  int transposeSemitones = 0,
  bool preferFlats = false,
  GuitarChordVoicingResolver resolver = const GuitarChordVoicingResolver(),
}) {
  final Song rawSong = ChordPro.parseSong(document.sourceChordPro);
  final netShift = transposeSemitones - capoFret;
  final Song effectiveSong = (netShift == 0 && !preferFlats)
      ? rawSong
      : rawSong.transposed(
          netShift,
          accidentals: preferFlats
              ? AccidentalPreference.flats
              : AccidentalPreference.sharps,
        );

  final effectiveKeyLabel = _resolveEffectiveKey(
    rawSong: rawSong,
    effectiveSong: effectiveSong,
    fallbackKey: document.keyLabel,
    netShift: netShift,
    preferFlats: preferFlats,
  );

  final seenDiagrams = <String, ResolvedGuitarChordDiagram>{};
  final sectionViews = <ChordLyricsSectionView>[];
  String? lastChordLabel;

  for (final section in effectiveSong.activeSections) {
    final lineViews = <ChordLyricsLineView>[];
    for (final line in section.lines) {
      if (line.kind == LineKind.comment) {
        final comment = line.comment?.trim();
        if (comment != null && comment.isNotEmpty) {
          lineViews.add(
            ChordLyricsLineView(
              clusters: const <ChordLyricCluster>[],
              commentText: comment,
            ),
          );
        }
        continue;
      }

      if (line.kind == LineKind.verbatim) {
        final verbatim = line.verbatim;
        if (verbatim != null && verbatim.isNotEmpty) {
          lineViews.add(
            ChordLyricsLineView(
              clusters: const <ChordLyricCluster>[],
              verbatimText: verbatim,
            ),
          );
        }
        continue;
      }

      if (line.kind != LineKind.structured) continue;

      final clusters = <ChordLyricCluster>[];
      String? pendingChord;
      final lyricBuffer = StringBuffer();

      void flushPendingCluster() {
        final text = lyricBuffer.toString();
        lyricBuffer.clear();
        if (pendingChord == null && text.isEmpty) return;
        ResolvedGuitarChordDiagram? diagram;
        final chordName = pendingChord;
        if (chordName != null && chordName.isNotEmpty) {
          final resolved = resolver.resolve(
            chordName,
            songDefinitions: effectiveSong.chordDefinitions,
          );
          diagram = resolved;
          if (resolved.hasDiagram && !resolved.isNoChord) {
            seenDiagrams.putIfAbsent(resolved.diagram.name, () => resolved);
          }
        }
        clusters.add(
          ChordLyricCluster(
            lyricText: text,
            chordLabel: chordName,
            diagram: diagram,
          ),
        );
        pendingChord = null;
      }

      for (final token in line.tokens) {
        if (token is ChordToken) {
          flushPendingCluster();
          final nextLabel = token.chord?.raw ?? token.raw;
          if (nextLabel.trim().isNotEmpty) {
            pendingChord = nextLabel.trim();
            lastChordLabel = pendingChord;
          }
        } else if (token is ChordRecallToken) {
          if (lastChordLabel != null) {
            flushPendingCluster();
            pendingChord = lastChordLabel;
          }
        } else if (token is TextToken) {
          lyricBuffer.write(token.text);
        } else if (token is AnnotationToken) {
          if (pendingChord == null && lyricBuffer.isEmpty) {
            lyricBuffer.write(token.text);
          } else {
            flushPendingCluster();
            clusters.add(ChordLyricCluster(lyricText: token.text));
          }
        }
      }
      flushPendingCluster();

      lineViews.add(ChordLyricsLineView(clusters: clusters));
    }

    final nonEmptyLines = _trimOuterBlankLines(lineViews);
    if (nonEmptyLines.isEmpty) continue;

    sectionViews.add(
      ChordLyricsSectionView(
        label: _resolveSectionLabel(section.kind, section.label),
        lines: nonEmptyLines,
      ),
    );
  }

  final title = effectiveSong.metadata.titles.isNotEmpty
      ? effectiveSong.metadata.titles.first
      : document.title;
  final subtitle = effectiveSong.metadata.subtitles.isNotEmpty
      ? effectiveSong.metadata.subtitles.first
      : effectiveSong.metadata.artists.isNotEmpty
          ? effectiveSong.metadata.artists.first
          : document.artist;

  return ParsedChordLyricsSong(
    title: title,
    subtitle: subtitle,
    effectiveKeyLabel: effectiveKeyLabel,
    capoFret: capoFret,
    transposeSemitones: transposeSemitones,
    tempoBpm: effectiveSong.metadata.tempo,
    sections: sectionViews,
    uniqueDiagrams: seenDiagrams.values.toList(growable: false),
  );
}

String _resolveEffectiveKey({
  required Song rawSong,
  required Song effectiveSong,
  required String fallbackKey,
  required int netShift,
  required bool preferFlats,
}) {
  if (effectiveSong.metadata.keys.isNotEmpty) {
    return effectiveSong.metadata.keys.first;
  }
  final sourceKey = rawSong.metadata.keys.isNotEmpty
      ? rawSong.metadata.keys.first
      : fallbackKey;
  if (netShift == 0 && !preferFlats) return sourceKey;
  final parsedKey = Chord.tryParse(sourceKey);
  if (parsedKey == null || parsedKey.system != ChordSystem.letter) {
    return sourceKey;
  }
  return parsedKey
      .transpose(
        netShift,
        accidentals: preferFlats
            ? AccidentalPreference.flats
            : AccidentalPreference.sharps,
      )
      .raw;
}

String? _resolveSectionLabel(SectionKind kind, String? explicitLabel) {
  final cleaned = explicitLabel?.trim();
  if (cleaned != null && cleaned.isNotEmpty) return cleaned;
  return switch (kind) {
    SectionKind.chorus => 'サビ',
    SectionKind.bridge => 'ブリッジ',
    _ => null,
  };
}

List<ChordLyricsLineView> _trimOuterBlankLines(
  List<ChordLyricsLineView> lines,
) {
  var start = 0;
  var end = lines.length;
  while (start < end && lines[start].isEmpty) {
    start++;
  }
  while (end > start && lines[end - 1].isEmpty) {
    end--;
  }
  return lines.sublist(start, end);
}

/// ユーザーが入力したテキストから表示タイトル・アーティスト等を抽出しつつ ChordPro 構文検証を行う。
ChordLyricsSheetDocument buildUserChordLyricsDocument({
  required String id,
  required String rawChordPro,
  String? fallbackTitle,
  String? fallbackArtist,
}) {
  final trimmedSource = rawChordPro.trim();
  if (trimmedSource.isEmpty) {
    throw const FormatException('ChordPro テキストが空です。');
  }
  if (utf8.encode(trimmedSource).length > 65536) {
    throw const FormatException('64KB を超える ChordPro テキストは保存できません。');
  }
  final parsed = ChordPro.parseSong(trimmedSource);
  final hasMeaningfulLine = parsed.sections.any(
    (s) => s.lines.any(
      (l) => l.tokens.isNotEmpty || (l.verbatim?.isNotEmpty ?? false),
    ),
  );
  if (!hasMeaningfulLine) {
    throw const FormatException('有効なコードまたは歌詞行が見つかりません。');
  }

  final title = parsed.metadata.titles.isNotEmpty
      ? parsed.metadata.titles.first.trim()
      : (fallbackTitle?.trim().isNotEmpty ?? false)
          ? fallbackTitle!.trim()
          : 'マイ弾き語り譜面';
  final artist = parsed.metadata.artists.isNotEmpty
      ? parsed.metadata.artists.first.trim()
      : parsed.metadata.subtitles.isNotEmpty
          ? parsed.metadata.subtitles.first.trim()
          : (fallbackArtist?.trim().isNotEmpty ?? false)
              ? fallbackArtist!.trim()
              : '端末ローカル譜面';
  final keyLabel =
      parsed.metadata.keys.isNotEmpty ? parsed.metadata.keys.first.trim() : 'C';
  final capo = (parsed.metadata.capo ?? 0).clamp(0, 7);

  return ChordLyricsSheetDocument(
    id: id,
    title: title,
    artist: artist,
    keyLabel: keyLabel,
    defaultCapo: capo,
    description: 'この端末のみに非公開保存された個人練習用 ChordPro 譜面です。',
    sourceChordPro: trimmedSource,
    isUserImported: true,
  );
}
