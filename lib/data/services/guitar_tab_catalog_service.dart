import '../models/guitar_tab_catalog_model.dart';

/// Bundled practice catalog. The notation is original instructional material,
/// not a transcription of a copyrighted Beatles recording or score.
class GuitarTabCatalogService {
  const GuitarTabCatalogService();

  Future<List<GuitarTabCatalogModel>> loadCatalog() async {
    return _catalog;
  }

  static const List<GuitarTabCatalogModel> _catalog = <GuitarTabCatalogModel>[
    GuitarTabCatalogModel(
      id: 'blackbird-fingerstyle',
      title: 'Blackbird',
      album: 'The Beatles',
      year: 1968,
      difficulty: 'intermediate',
      tuning: 'Standard (E A D G B E)',
      capo: 'なし',
      practiceBpm: 60,
      summary: '親指のベースと高音の2音を分解し、響きを残したまま92 BPMへ近づけるフィンガースタイル・スタディです。',
      techniques: <String>['3フィンガー', '2音ボイシング', '開放弦', 'ポジション移動'],
      sections: <GuitarTabSectionCatalogModel>[
        GuitarTabSectionCatalogModel(
          title: '01 Thumb & pinch — オリジナル練習',
          practiceNote: '親指の低音と人差し指・中指の高音を交互に。音量をそろえ、4拍を止めずに繰り返します。',
          lines: <String>[
            '   1 & 2 & 3 & 4 &',
            'e|----0-------0-----|',
            'B|------1-------1---|',
            'G|--0-------2-------|',
            'D|--------0-------0-|',
            'A|------------------|',
            'E|3-----------------|',
          ],
        ),
        GuitarTabSectionCatalogModel(
          title: '02 Open-string flow — オリジナル練習',
          practiceNote: '押弦を離す直前まで開放弦を鳴らします。指を高く上げすぎず、次の形へ小さく移動します。',
          lines: <String>[
            '   1 & 2 & 3 & 4 &',
            'e|0-------0---------|',
            'B|--1-------3---1---|',
            'G|----0-------2-----|',
            'D|------2---------0-|',
            'A|3-----------------|',
            'E|------------------|',
          ],
        ),
        GuitarTabSectionCatalogModel(
          title: '03 Shift landing — オリジナル練習',
          practiceNote: 'ベース音を合図にポジションを移動します。着地が濁る場合は、テンポを5 BPM下げて再開します。',
          lines: <String>[
            '   1 & 2 & 3 & 4 &',
            'e|----3-------5-----|',
            'B|------3-------5---|',
            'G|--4-------5-------|',
            'D|------------------|',
            'A|--------3-------5-|',
            'E|3-----------------|',
          ],
        ),
      ],
      practiceSteps: <GuitarPracticeStepCatalogModel>[
        GuitarPracticeStepCatalogModel(
          id: 'separate',
          title: '指を分ける',
          goal: '親指と高音を別々に動かす',
          cue: '低音を先に決め、2音を軽く添える',
          minutes: 5,
          recommendedBpm: 60,
        ),
        GuitarPracticeStepCatalogModel(
          id: 'ring',
          title: '響きをつなぐ',
          goal: '開放弦を残して滑らかに移動する',
          cue: '次の音が鳴るまで前の指を離さない',
          minutes: 7,
          recommendedBpm: 72,
        ),
        GuitarPracticeStepCatalogModel(
          id: 'tempo',
          title: '原速へ橋渡し',
          goal: '84 BPMから92 BPMへ段階的に上げる',
          cue: '3回ノーミスごとに4 BPM上げる',
          minutes: 8,
          recommendedBpm: 84,
        ),
      ],
      resources: <GuitarLessonResourceCatalogModel>[
        GuitarLessonResourceCatalogModel(
          id: 'suwa-pdf',
          title: 'アルペジオ解説PDF',
          provider: 'muua.jp / suwa-ep.info',
          description: '6ページの奏法解説と参考譜。配布条件・利用条件は提供元で確認してください。',
          actionLabel: 'PDFを開く',
          url: 'https://suwa-ep.info/s/download/bb2.pdf',
          kind: 'pdfGuide',
        ),
        GuitarLessonResourceCatalogModel(
          id: 'musescore',
          title: '再生できる参考スコア',
          provider: 'MuseScore',
          description: '楽譜表示、再生、テンポ変更に対応した外部スコアページです。',
          actionLabel: 'MuseScoreで見る',
          url: 'https://ja.musescore.com/user/6375061/scores/7758575',
          kind: 'interactiveScore',
        ),
        GuitarLessonResourceCatalogModel(
          id: 'reddit-video',
          title: '動画レッスン',
          provider: 'Reddit / r/guitarlessons',
          description: '初心者向け解説動画が共有されているコミュニティ投稿です。',
          actionLabel: '動画レッスンを見る',
          url:
              'https://www.reddit.com/r/guitarlessons/comments/11ei1zq/how_to_play_blackbird_easy_guitar_tab/?tl=ja',
          kind: 'videoLesson',
        ),
      ],
    ),
    GuitarTabCatalogModel(
      id: 'day-tripper-riff',
      title: 'Day Tripper',
      album: '1965 single',
      year: 1965,
      difficulty: 'beginner',
      tuning: 'Standard (E A D G B E)',
      capo: 'なし',
      practiceBpm: 88,
      summary: '低音弦の短いフレーズで、休符とオルタネイトピッキングを整えます。',
      techniques: <String>['単音リフ', 'オルタネイト', '休符'],
      sections: <GuitarTabSectionCatalogModel>[
        GuitarTabSectionCatalogModel(
          title: 'E blues pulse — オリジナル練習',
          practiceNote: '最後の休符までを1小節として数え、音を止めるタイミングをそろえます。',
          lines: <String>[
            'e|----------------|',
            'B|----------------|',
            'G|----------------|',
            'D|------2-4-2-----|',
            'A|--2-4-------4-2-|',
            'E|0---------------|',
          ],
        ),
      ],
    ),
    GuitarTabCatalogModel(
      id: 'here-comes-the-sun-arpeggio',
      title: 'Here Comes the Sun',
      album: 'Abbey Road',
      year: 1969,
      difficulty: 'intermediate',
      tuning: 'Standard (E A D G B E)',
      capo: 'なし',
      practiceBpm: 76,
      summary: 'Dフォーム周辺のアルペジオで、明るい響きとアクセント移動を学びます。',
      techniques: <String>['アルペジオ', 'アクセント', 'コード保持'],
      sections: <GuitarTabSectionCatalogModel>[
        GuitarTabSectionCatalogModel(
          title: 'D-shape sunrise — オリジナル練習',
          practiceNote: '左手のDフォームを保ち、1音ずつ同じ音量で鳴らします。',
          lines: <String>[
            'e|2-----0---------|',
            'B|--3-----3-2-----|',
            'G|----2-------2---|',
            'D|0-------------0-|',
            'A|----------------|',
            'E|----------------|',
          ],
        ),
      ],
    ),
    GuitarTabCatalogModel(
      id: 'let-it-be-chords',
      title: 'Let It Be',
      album: 'Let It Be',
      year: 1970,
      difficulty: 'beginner',
      tuning: 'Standard (E A D G B E)',
      capo: 'なし',
      practiceBpm: 68,
      summary: '開放コードの切り替えと、一定の8分ストロークを落ち着いて練習します。',
      techniques: <String>['オープンコード', 'ストローク', 'コードチェンジ'],
      sections: <GuitarTabSectionCatalogModel>[
        GuitarTabSectionCatalogModel(
          title: 'Open-chord cadence — オリジナル練習',
          practiceNote: '各フォームを4拍ずつ保ちます。まずはダウンストロークだけで始めましょう。',
          lines: <String>[
            '   C       G       Am      Fmaj7',
            'e|0-------3-------0-------0-----|',
            'B|1-------0-------1-------1-----|',
            'G|0-------0-------2-------2-----|',
            'D|2-------0-------2-------3-----|',
            'A|3-------2-------0-------------|',
            'E|--------3---------------------|',
          ],
        ),
      ],
    ),
  ];
}
