import 'dart:convert';

/// 構造化TAB譜の拍イベント種別。
enum StructuredTabBeatKind { chordStack, rhythmSlash, rest }

/// 構造化TAB譜の音価。
enum StructuredTabDuration {
  whole,
  half,
  quarter,
  eighth,
  sixteenth;

  /// 4分音符を 1.0 拍としたときの長さ。
  double get beatUnits => switch (this) {
        StructuredTabDuration.whole => 4.0,
        StructuredTabDuration.half => 2.0,
        StructuredTabDuration.quarter => 1.0,
        StructuredTabDuration.eighth => 0.5,
        StructuredTabDuration.sixteenth => 0.25,
      };
}

/// ピッキング方向記号（ダウン / アップ）。
enum StructuredPickDirection { down, up }

/// コードダイアグラム上のバレー（セーハ）指定。
/// 弦インデックスは `0=6弦(低音E) .. 5=1弦(高音e)`。
class StructuredChordBarre {
  const StructuredChordBarre({
    required this.fret,
    required this.startStringIndex,
    required this.endStringIndex,
  });

  final int fret;
  final int startStringIndex;
  final int endStringIndex;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'fret': fret,
      'startStringIndex': startStringIndex,
      'endStringIndex': endStringIndex,
    };
  }

  static StructuredChordBarre fromJson(Object? raw) {
    final map = _asJsonMap(raw, 'barre');
    final fret = _readInt(map, 'fret', min: 1, max: 24);
    final start = _readInt(map, 'startStringIndex', min: 0, max: 5);
    final end = _readInt(map, 'endStringIndex', min: 0, max: 5);
    if (start > end) {
      throw const FormatException(
        'barre の startStringIndex は endStringIndex 以下である必要があります。',
      );
    }
    return StructuredChordBarre(
      fret: fret,
      startStringIndex: start,
      endStringIndex: end,
    );
  }
}

/// 譜面上部に並べるコードダイアグラム定義。
/// `frets` は 6弦(E)〜1弦(e) の長さ6配列（`-1`=ミュート, `0`=開放, `1..24`=フレット）。
class StructuredChordDiagram {
  const StructuredChordDiagram({
    required this.name,
    required this.frets,
    this.baseFret = 1,
    this.barre,
  });

  final String name;
  final List<int> frets;
  final int baseFret;
  final StructuredChordBarre? barre;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'name': name,
      'frets': frets,
      if (baseFret != 1) 'baseFret': baseFret,
      if (barre != null) 'barre': barre!.toJson(),
    };
  }

  static StructuredChordDiagram fromJson(Object? raw, int index) {
    final map = _asJsonMap(raw, 'chords[$index]');
    final name = _readRequiredString(
      map,
      'name',
      context: 'chords[$index]',
      maxLength: 32,
    );
    final rawFrets = _asJsonList(map['frets'], 'chords[$index].frets');
    if (rawFrets.length != 6) {
      throw FormatException('chords[$index].frets は6弦分の長さ6である必要があります。');
    }
    final frets = List<int>.unmodifiable(<int>[
      for (var i = 0; i < 6; i++)
        _coerceInt(
          rawFrets[i],
          'chords[$index].frets[$i]',
          min: -1,
          max: 24,
        ),
    ]);
    final baseFret = _readOptionalInt(
          map,
          'baseFret',
          min: 1,
          max: 24,
        ) ??
        1;
    final rawBarre = map['barre'];
    final barre =
        rawBarre == null ? null : StructuredChordBarre.fromJson(rawBarre);
    return StructuredChordDiagram(
      name: name,
      frets: frets,
      baseFret: baseFret,
      barre: barre,
    );
  }
}

/// 1小節内の単一リズム／TABイベント。
/// `frets` は 6弦(E)〜1弦(e) の長さ6配列（`null`=非表示, `0..24`=フレット番号）。
class StructuredTabBeat {
  StructuredTabBeat({
    required this.kind,
    required this.duration,
    List<int?>? frets,
    this.staccato = false,
    this.pickDirection,
    this.beamGroup,
    this.chordSymbol,
  }) : frets = List<int?>.unmodifiable(
          frets ?? const <int?>[null, null, null, null, null, null],
        );

  final StructuredTabBeatKind kind;
  final StructuredTabDuration duration;
  final List<int?> frets;
  final bool staccato;
  final StructuredPickDirection? pickDirection;
  final String? beamGroup;
  final String? chordSymbol;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'kind': kind.name,
      'duration': duration.name,
      if (frets.any((int? f) => f != null)) 'frets': frets,
      if (staccato) 'staccato': true,
      if (pickDirection != null) 'pickDirection': pickDirection!.name,
      if (beamGroup != null && beamGroup!.isNotEmpty) 'beamGroup': beamGroup,
      if (chordSymbol != null && chordSymbol!.isNotEmpty)
        'chordSymbol': chordSymbol,
    };
  }

  static StructuredTabBeat fromJson(
    Object? raw,
    int measureIndex,
    int beatIndex,
  ) {
    final ctx = 'measures[$measureIndex].beats[$beatIndex]';
    final map = _asJsonMap(raw, ctx);
    final kind = _parseBeatKind(
      _readRequiredString(map, 'kind', context: ctx),
      ctx,
    );
    final duration = _parseDuration(
      _readRequiredString(map, 'duration', context: ctx),
      ctx,
    );
    final rawFrets = map['frets'];
    final List<int?> frets;
    if (rawFrets == null) {
      frets = const <int?>[null, null, null, null, null, null];
    } else {
      final list = _asJsonList(rawFrets, '$ctx.frets');
      if (list.length != 6) {
        throw FormatException('$ctx.frets は6弦分の長さ6である必要があります。');
      }
      frets = List<int?>.unmodifiable(<int?>[
        for (var i = 0; i < 6; i++)
          list[i] == null
              ? null
              : _coerceInt(list[i], '$ctx.frets[$i]', min: 0, max: 24),
      ]);
    }

    final staccato = _readOptionalBool(map, 'staccato', ctx) ?? false;
    final pickRaw = _readOptionalString(map, 'pickDirection', ctx);
    final pickDirection =
        pickRaw == null ? null : _parsePickDirection(pickRaw, ctx);
    final beamGroup = _readOptionalString(
      map,
      'beamGroup',
      ctx,
      maxLength: 32,
    );
    final chordSymbol = _readOptionalString(
      map,
      'chordSymbol',
      ctx,
      maxLength: 32,
    );

    return StructuredTabBeat(
      kind: kind,
      duration: duration,
      frets: frets,
      staccato: staccato,
      pickDirection: pickDirection,
      beamGroup: beamGroup,
      chordSymbol: chordSymbol,
    );
  }
}

/// 1小節分の構造化TAB譜データ。
class StructuredTabMeasure {
  StructuredTabMeasure({
    required this.number,
    required List<StructuredTabBeat> beats,
    this.chordSymbol,
    this.rehearsalMark,
    this.boxedRehearsalMark = true,
    this.repeatStart = false,
    this.repeatEnd = false,
    this.volta,
    this.hasSegno = false,
    this.hasCoda = false,
    this.topNote,
  }) : beats = List<StructuredTabBeat>.unmodifiable(beats);

  final int number;
  final String? chordSymbol;
  final String? rehearsalMark;
  final bool boxedRehearsalMark;
  final bool repeatStart;
  final bool repeatEnd;
  final String? volta;
  final bool hasSegno;
  final bool hasCoda;
  final String? topNote;
  final List<StructuredTabBeat> beats;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'number': number,
      if (chordSymbol != null && chordSymbol!.isNotEmpty)
        'chordSymbol': chordSymbol,
      if (rehearsalMark != null && rehearsalMark!.isNotEmpty)
        'rehearsalMark': rehearsalMark,
      if (!boxedRehearsalMark) 'boxedRehearsalMark': false,
      if (repeatStart) 'repeatStart': true,
      if (repeatEnd) 'repeatEnd': true,
      if (volta != null && volta!.isNotEmpty) 'volta': volta,
      if (hasSegno) 'hasSegno': true,
      if (hasCoda) 'hasCoda': true,
      if (topNote != null && topNote!.isNotEmpty) 'topNote': topNote,
      'beats': beats.map((StructuredTabBeat b) => b.toJson()).toList(),
    };
  }

  static const int maxBeatsPerMeasure = 64;

  static StructuredTabMeasure fromJson(Object? raw, int index) {
    final ctx = 'measures[$index]';
    final map = _asJsonMap(raw, ctx);
    final number = _readInt(map, 'number', min: 1, max: 999);
    final rawBeats = _asJsonList(map['beats'], '$ctx.beats');
    if (rawBeats.isEmpty) {
      throw FormatException('$ctx.beats には1つ以上の拍イベントが必要です。');
    }
    if (rawBeats.length > maxBeatsPerMeasure) {
      throw FormatException(
        '$ctx.beats は最大 $maxBeatsPerMeasure 件までです。',
      );
    }
    final beats = <StructuredTabBeat>[
      for (var i = 0; i < rawBeats.length; i++)
        StructuredTabBeat.fromJson(rawBeats[i], index, i),
    ];
    return StructuredTabMeasure(
      number: number,
      chordSymbol: _readOptionalString(
        map,
        'chordSymbol',
        ctx,
        maxLength: 32,
      ),
      rehearsalMark: _readOptionalString(
        map,
        'rehearsalMark',
        ctx,
        maxLength: 32,
      ),
      boxedRehearsalMark:
          _readOptionalBool(map, 'boxedRehearsalMark', ctx) ?? true,
      repeatStart: _readOptionalBool(map, 'repeatStart', ctx) ?? false,
      repeatEnd: _readOptionalBool(map, 'repeatEnd', ctx) ?? false,
      volta: _readOptionalString(map, 'volta', ctx, maxLength: 16),
      hasSegno: _readOptionalBool(map, 'hasSegno', ctx) ?? false,
      hasCoda: _readOptionalBool(map, 'hasCoda', ctx) ?? false,
      topNote: _readOptionalString(map, 'topNote', ctx, maxLength: 64),
      beats: beats,
    );
  }
}

/// 1曲分の構造化コードTABスコア全体。
class StructuredGuitarTabScore {
  StructuredGuitarTabScore({
    required this.id,
    required this.title,
    required this.artist,
    required this.tuning,
    required this.capo,
    required this.bpm,
    required List<StructuredChordDiagram> chords,
    required List<StructuredTabMeasure> measures,
    this.beatsPerMeasure = 4,
    this.beatUnit = 4,
    this.isOriginalPractice = true,
    this.isUserImported = false,
    this.summary = '',
  })  : chords = List<StructuredChordDiagram>.unmodifiable(chords),
        measures = List<StructuredTabMeasure>.unmodifiable(measures);

  final String id;
  final String title;
  final String artist;
  final String tuning;
  final String capo;
  final int bpm;
  final int beatsPerMeasure;
  final int beatUnit;
  final bool isOriginalPractice;
  final bool isUserImported;
  final String summary;
  final List<StructuredChordDiagram> chords;
  final List<StructuredTabMeasure> measures;

  StructuredGuitarTabScore copyWith({
    String? id,
    bool? isOriginalPractice,
    bool? isUserImported,
  }) {
    return StructuredGuitarTabScore(
      id: id ?? this.id,
      title: title,
      artist: artist,
      tuning: tuning,
      capo: capo,
      bpm: bpm,
      beatsPerMeasure: beatsPerMeasure,
      beatUnit: beatUnit,
      isOriginalPractice: isOriginalPractice ?? this.isOriginalPractice,
      isUserImported: isUserImported ?? this.isUserImported,
      summary: summary,
      chords: chords,
      measures: measures,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'title': title,
      'artist': artist,
      'tuning': tuning,
      'capo': capo,
      'bpm': bpm,
      'beatsPerMeasure': beatsPerMeasure,
      'beatUnit': beatUnit,
      'isOriginalPractice': isOriginalPractice,
      'isUserImported': isUserImported,
      if (summary.isNotEmpty) 'summary': summary,
      'chords': chords.map((StructuredChordDiagram c) => c.toJson()).toList(),
      'measures': measures.map((StructuredTabMeasure m) => m.toJson()).toList(),
    };
  }

  String toPrettyJson() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }

  static const int maxJsonLength = 256 * 1024;
  static const int maxChordsCount = 64;
  static const int maxMeasuresCount = 256;

  static StructuredGuitarTabScore fromJson(
    Map<String, Object?> map, {
    bool forceUserImported = false,
  }) {
    final id = _readRequiredString(
      map,
      'id',
      context: 'score',
      maxLength: 100,
    );
    final title = _readRequiredString(
      map,
      'title',
      context: 'score',
      maxLength: 120,
    );
    final artist = _readOptionalString(
          map,
          'artist',
          'score',
          maxLength: 120,
        ) ??
        'オリジナル練習譜';
    final tuning = _readOptionalString(
          map,
          'tuning',
          'score',
          maxLength: 80,
        ) ??
        'Standard tuning';
    final capo = _readOptionalString(
          map,
          'capo',
          'score',
          maxLength: 40,
        ) ??
        'なし';
    final bpm = _readInt(map, 'bpm', min: 30, max: 260);
    final beatsPerMeasure =
        _readOptionalInt(map, 'beatsPerMeasure', min: 1, max: 12) ?? 4;
    final beatUnit = _readOptionalInt(map, 'beatUnit', min: 2, max: 16) ?? 4;
    if (beatUnit != 2 && beatUnit != 4 && beatUnit != 8 && beatUnit != 16) {
      throw const FormatException('beatUnit は 2, 4, 8, 16 のいずれかである必要があります。');
    }
    final summary = _readOptionalString(
          map,
          'summary',
          'score',
          maxLength: 500,
        ) ??
        '';
    final isOriginalPractice = forceUserImported
        ? false
        : (_readOptionalBool(map, 'isOriginalPractice', 'score') ?? true);
    final isUserImported = forceUserImported ||
        (_readOptionalBool(map, 'isUserImported', 'score') ?? false);

    final rawChords = map['chords'];
    final chords = <StructuredChordDiagram>[];
    if (rawChords != null) {
      final chordList = _asJsonList(rawChords, 'chords');
      if (chordList.length > maxChordsCount) {
        throw const FormatException(
          'chords は最大 $maxChordsCount 件までです。',
        );
      }
      for (var i = 0; i < chordList.length; i++) {
        chords.add(StructuredChordDiagram.fromJson(chordList[i], i));
      }
    }

    final rawMeasures = _asJsonList(map['measures'], 'measures');
    if (rawMeasures.isEmpty) {
      throw const FormatException('measures には1小節以上のデータが必要です。');
    }
    if (rawMeasures.length > maxMeasuresCount) {
      throw const FormatException(
        'measures は最大 $maxMeasuresCount 小節までです。',
      );
    }
    final measures = <StructuredTabMeasure>[
      for (var i = 0; i < rawMeasures.length; i++)
        StructuredTabMeasure.fromJson(rawMeasures[i], i),
    ];

    return StructuredGuitarTabScore(
      id: id,
      title: title,
      artist: artist,
      tuning: tuning,
      capo: capo,
      bpm: bpm,
      beatsPerMeasure: beatsPerMeasure,
      beatUnit: beatUnit,
      isOriginalPractice: isOriginalPractice,
      isUserImported: isUserImported,
      summary: summary,
      chords: chords,
      measures: measures,
    );
  }

  static StructuredGuitarTabScore parseJsonString(
    String rawJson, {
    bool forceUserImported = false,
  }) {
    if (rawJson.length > maxJsonLength) {
      throw const FormatException(
        'JSONテキストが大きすぎます（256KB以下にしてください）。',
      );
    }
    final trimmed = rawJson.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('JSONテキストが空です。');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } on FormatException catch (error) {
      throw FormatException('JSONの構文が正しくありません: ${error.message}');
    }
    final map = _asJsonMap(decoded, 'root');
    return fromJson(map, forceUserImported: forceUserImported);
  }
}

/// メトロノーム同期再生用の1ステップ。
class StructuredTabPlaybackStep {
  const StructuredTabPlaybackStep({
    required this.measureIndex,
    required this.beatIndex,
    required this.measureNumber,
    required this.durationBeats,
  });

  final int measureIndex;
  final int beatIndex;
  final int measureNumber;
  final double durationBeats;
}

/// 反復・1/2番カッコ・D.S. al Coda・Da Coda を展開した再生タイムラインを生成する。
List<StructuredTabPlaybackStep> expandStructuredTabTimeline(
  StructuredGuitarTabScore score, {
  int maxMeasureVisits = 300,
}) {
  final measures = score.measures;
  if (measures.isEmpty) {
    return const <StructuredTabPlaybackStep>[];
  }

  final steps = <StructuredTabPlaybackStep>[];
  final completedRepeatEnds = <int>{};
  var repeatReturnIndex = 0;
  var shouldSkipFirstVolta = false;
  var skippedFirstVoltaInPass = false;
  var inDsPass = false;
  var hasUsedDaCoda = false;
  var idx = 0;
  var visits = 0;

  while (idx >= 0 && idx < measures.length && visits < maxMeasureVisits) {
    visits++;
    final measure = measures[idx];
    final volta = measure.volta?.trim();
    final isFirstVolta = volta != null && volta.startsWith('1');

    if (measure.repeatStart) {
      if (idx != repeatReturnIndex) {
        shouldSkipFirstVolta = false;
        skippedFirstVoltaInPass = false;
      }
      repeatReturnIndex = idx;
    }

    if (isFirstVolta &&
        (shouldSkipFirstVolta || (inDsPass && !hasUsedDaCoda))) {
      skippedFirstVoltaInPass = true;
      idx++;
      continue;
    }
    if (!isFirstVolta && skippedFirstVoltaInPass) {
      shouldSkipFirstVolta = false;
      skippedFirstVoltaInPass = false;
    }

    for (var beatIdx = 0; beatIdx < measure.beats.length; beatIdx++) {
      final beat = measure.beats[beatIdx];
      steps.add(
        StructuredTabPlaybackStep(
          measureIndex: idx,
          beatIndex: beatIdx,
          measureNumber: measure.number,
          durationBeats: beat.duration.beatUnits,
        ),
      );
    }

    if (inDsPass && !hasUsedDaCoda && _isDaCoda(measure.topNote)) {
      final codaIdx =
          measures.indexWhere((StructuredTabMeasure m) => m.hasCoda);
      if (codaIdx >= 0) {
        hasUsedDaCoda = true;
        idx = codaIdx;
        continue;
      }
    }

    if (!inDsPass && _isDalSegno(measure.topNote)) {
      final segnoIdx =
          measures.indexWhere((StructuredTabMeasure m) => m.hasSegno);
      if (segnoIdx >= 0) {
        inDsPass = true;
        shouldSkipFirstVolta = false;
        skippedFirstVoltaInPass = false;
        idx = segnoIdx;
        continue;
      }
    }

    if (measure.repeatEnd) {
      if (completedRepeatEnds.contains(idx)) {
        shouldSkipFirstVolta = false;
        skippedFirstVoltaInPass = false;
      } else {
        final isFadeRepeat = _isFadeOutRepeat(measure.topNote);
        if (!inDsPass || isFadeRepeat) {
          completedRepeatEnds.add(idx);
          if (!isFadeRepeat) {
            shouldSkipFirstVolta = true;
            skippedFirstVoltaInPass = false;
          }
          idx = repeatReturnIndex;
          continue;
        }
      }
    }

    idx++;
  }

  return List<StructuredTabPlaybackStep>.unmodifiable(steps);
}

bool _isDaCoda(String? note) {
  if (note == null) return false;
  final normalized = note.toLowerCase();
  return normalized.contains('da coda') || normalized.contains('to coda');
}

bool _isDalSegno(String? note) {
  if (note == null) return false;
  final normalized = note.toLowerCase().trim();
  if (normalized.startsWith('(') || normalized.contains('straight')) {
    return false;
  }
  return normalized.contains('d.s.') || normalized.contains('dal segno');
}

bool _isFadeOutRepeat(String? note) {
  if (note == null) return false;
  final normalized = note.toLowerCase();
  return normalized.contains('fade out') || normalized.contains('repeat &');
}

StructuredTabBeatKind _parseBeatKind(String raw, String context) {
  for (final kind in StructuredTabBeatKind.values) {
    if (kind.name == raw) return kind;
  }
  throw FormatException('$context.kind の値 "$raw" は未対応です。');
}

StructuredTabDuration _parseDuration(String raw, String context) {
  for (final duration in StructuredTabDuration.values) {
    if (duration.name == raw) return duration;
  }
  throw FormatException('$context.duration の値 "$raw" は未対応です。');
}

StructuredPickDirection _parsePickDirection(String raw, String context) {
  for (final direction in StructuredPickDirection.values) {
    if (direction.name == raw) return direction;
  }
  throw FormatException('$context.pickDirection の値 "$raw" は未対応です。');
}

Map<String, Object?> _asJsonMap(Object? raw, String fieldName) {
  if (raw is! Map) {
    throw FormatException('$fieldName はJSONオブジェクトである必要があります。');
  }
  final result = <String, Object?>{};
  for (final entry in raw.entries) {
    result[entry.key.toString()] = entry.value;
  }
  return result;
}

List<Object?> _asJsonList(Object? raw, String fieldName) {
  if (raw is! List) {
    throw FormatException('$fieldName はJSON配列である必要があります。');
  }
  return List<Object?>.from(raw);
}

String _readRequiredString(
  Map<String, Object?> map,
  String key, {
  required String context,
  int maxLength = 256,
}) {
  final raw = map[key];
  if (raw is! String || raw.trim().isEmpty) {
    throw FormatException('$context.$key は空でない文字列である必要があります。');
  }
  final trimmed = raw.trim();
  if (trimmed.length > maxLength) {
    throw FormatException('$context.$key は $maxLength 文字以内である必要があります。');
  }
  return trimmed;
}

String? _readOptionalString(
  Map<String, Object?> map,
  String key,
  String context, {
  int maxLength = 256,
}) {
  final raw = map[key];
  if (raw == null) return null;
  if (raw is! String) {
    throw FormatException('$context.$key は文字列である必要があります。');
  }
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.length > maxLength) {
    throw FormatException('$context.$key は $maxLength 文字以内である必要があります。');
  }
  return trimmed;
}

int _readInt(
  Map<String, Object?> map,
  String key, {
  required int min,
  required int max,
}) {
  return _coerceInt(map[key], key, min: min, max: max);
}

int? _readOptionalInt(
  Map<String, Object?> map,
  String key, {
  required int min,
  required int max,
}) {
  final raw = map[key];
  if (raw == null) return null;
  return _coerceInt(raw, key, min: min, max: max);
}

int _coerceInt(
  Object? raw,
  String fieldName, {
  required int min,
  required int max,
}) {
  if (raw is! int) {
    throw FormatException('$fieldName は整数である必要があります。');
  }
  if (raw < min || raw > max) {
    throw FormatException('$fieldName は $min〜$max の範囲で指定してください。');
  }
  return raw;
}

bool? _readOptionalBool(
  Map<String, Object?> map,
  String key,
  String context,
) {
  final raw = map[key];
  if (raw == null) return null;
  if (raw is! bool) {
    throw FormatException('$context.$key は真偽値(true/false)である必要があります。');
  }
  return raw;
}
