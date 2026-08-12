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
      practiceBpm: 72,
      summary: '2音の響きと親指のベースを分けて練習する、フィンガースタイル入門です。',
      techniques: <String>['フィンガーピッキング', '2音ボイシング', 'ベース独立'],
      sections: <GuitarTabSectionCatalogModel>[
        GuitarTabSectionCatalogModel(
          title: 'Interval walk — オリジナル練習',
          practiceNote: '親指で6・4弦、人差し指で3弦を弾きます。各音を重ねず、粒をそろえましょう。',
          lines: <String>[
            'e|----------------|',
            'B|----------------|',
            'G|----0-----2---0-|',
            'D|------0-----0---|',
            'A|----------------|',
            'E|--3-------------|',
          ],
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
