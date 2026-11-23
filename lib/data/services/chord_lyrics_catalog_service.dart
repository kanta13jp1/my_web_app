import '../../domain/models/chord_lyrics_sheet.dart';

/// 著作権保護に配慮したオリジナル弾き語りコード譜（ChordPro形式）を提供するカタログ。
abstract interface class ChordLyricsCatalogService {
  Future<List<ChordLyricsSheetDocument>> fetchPresetSheets();
}

class LocalChordLyricsCatalogService implements ChordLyricsCatalogService {
  const LocalChordLyricsCatalogService();

  @override
  Future<List<ChordLyricsSheetDocument>> fetchPresetSheets() async {
    return _presets;
  }

  static const List<ChordLyricsSheetDocument> _presets =
      <ChordLyricsSheetDocument>[
    ChordLyricsSheetDocument(
      id: 'midnight-train-etude',
      title: '夜行列車とカフェオレ — 弾き語り練習曲',
      artist: 'Original Study',
      keyLabel: 'D#',
      defaultCapo: 0,
      description:
          '横向きコード図・N.C.・クリシェ分数コード（D#/D）を含み、Capo 3 にすると開放コード中心（C/Am/F/G/C/B）へ自動変換できます。',
      sourceChordPro: '''{title: 夜行列車とカフェオレ — 弾き語り練習曲}
{subtitle: Original Study}
{key: D#}
{tempo: 112}

[N.C.]
[D#][Cm][D#][Cm]

{start_of_verse: Aメロ}
[D#]夜汽車の窓に映る[Cm]光のつぶ
[D#]冷めたカフェオレを両手[Cm]に抱えたまま
[G#]見慣れたホーム[A#]を抜けて [D#]坂の[D#/D]向こうへ[Cm]走る
[G#]風にほどける[A#]約束を[D#]追いかけて[A#]
{end_of_verse}

{start_of_chorus: サビ}
[D#]朝が来るころにはきっ[Cm]と届くはず
[D#]小さな手帳のすみ[Cm]のメモひとつ
[G#]迷わ[A#]ずに踏み出[D#]す [D#/D]電車のドアが[Cm]開く
[G#]新しい朝[A#]に会えるか[D#]ら
[G#]このリズム[A#]を忘れな[D#]い [A#][Cm]
[D#][Cm][D#][Cm]
{end_of_chorus}
''',
    ),
    ChordLyricsSheetDocument(
      id: 'sunday-acoustic-etude',
      title: '日曜の朝のストローク練習曲',
      artist: 'Original Study',
      keyLabel: 'G',
      defaultCapo: 0,
      description:
          '開放コードとオンコード（G/B → C → Am7 → D7）をベースにした弾き語り入門練習曲です。',
      sourceChordPro: '''{title: 日曜の朝のストローク練習曲}
{subtitle: Original Study}
{key: G}
{tempo: 96}

[G][G/B][C][D7]

{start_of_verse: Aメロ}
[G]カーテン揺らす[G/B]朝の風[C]に目を[D]覚まし
[G]湯気の立つ[G/B]マグカップを[C]机に[D7]置いた
[Em]古いギ[C]ターの弦を[G]ひと[D]つ確かめて[Em]
[C]今日のペー[Am7]ジを静か[D7]にめくる
{end_of_verse}

{start_of_chorus: サビ}
[G]四つのコード[D]だけで歌[Em]える朝があ[C]る
[G]焦らずひと[G/B]拍ずつ[Am7]刻んで[D7]みよう[G]
{end_of_chorus}
''',
    ),
  ];
}
