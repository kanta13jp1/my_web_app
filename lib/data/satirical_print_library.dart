import '../models/campaign_video.dart';

/// 「酒・煙草・風俗をやめよう」応援キャンペーン用の風刺画ライブラリ。
///
/// ウィリアム・ホガース『ビール通りとジン横丁』を筆頭に、酒・煙草・性的悪徳を
/// 戒めた**パブリックドメイン**の名画をキュレーションし、日付シードで決定論的に
/// ローテーションする (= 同じ日は誰が見ても同じ / 翌日は別の絵 = 毎日入れ替わる)。
///
/// バックエンド不要・オフライン可・純関数なので単体テスト可能。実画像は
/// [CampaignVideo.imageFile] に Wikimedia Commons のファイル名を持たせ、取得
/// できないものはグラデーションの装飾フレームへ自動フォールバックする。
abstract final class SatiricalPrintLibrary {
  SatiricalPrintLibrary._();

  /// キュレーション済みの全作品。
  static List<CampaignVideo> all() {
    return const [
      // ── 酒 ────────────────────────────────────────
      CampaignVideo(
        id: 'print-gin-lane',
        category: CampaignCategory.alcohol,
        title: '『ジン横丁』(1751)',
        caption: 'ジンに溺れたロンドンの惨状。安酒が家庭も命も蝕む——ホガースの警告。',
        creatorName: 'ウィリアム・ホガース',
        creatorHandle: '@satire_archive',
        imageFile: 'Gin_Lane.jpg',
        verified: true,
        likes: 3658,
        comments: 53,
        reposts: 364,
      ),
      CampaignVideo(
        id: 'print-beer-street',
        category: CampaignCategory.alcohol,
        title: '『ビール通り』(1751)',
        caption: '健全な労働と節度。ジン横丁と対をなす、しらふの街の豊かさ。',
        creatorName: 'ウィリアム・ホガース',
        creatorHandle: '@satire_archive',
        imageFile: 'Beer_Street.jpg',
        verified: true,
        likes: 1902,
        comments: 33,
        reposts: 188,
      ),
      CampaignVideo(
        id: 'print-midnight-conversation',
        category: CampaignCategory.alcohol,
        title: '『真夜中の現代の宴会』(1733)',
        caption: '深夜まで続く酔宴の醜態。度を越した一杯がもたらすもの。',
        creatorName: 'ウィリアム・ホガース',
        creatorHandle: '@satire_archive',
        likes: 1104,
        comments: 21,
        reposts: 77,
      ),
      CampaignVideo(
        id: 'print-the-bottle',
        category: CampaignCategory.alcohol,
        title: '『酒瓶』第1葉 (1847)',
        caption: '「まず一杯」から破滅は始まる。一家を壊す酒の連鎖8枚組の幕開け。',
        creatorName: 'ジョージ・クルックシャンク',
        creatorHandle: '@satire_archive',
        likes: 1420,
        comments: 47,
        reposts: 132,
      ),
      // ── 煙草 ──────────────────────────────────────
      CampaignVideo(
        id: 'print-the-smokers',
        category: CampaignCategory.tobacco,
        title: '『喫煙者たち』(1636頃)',
        caption: '煙に酔う男たち。習慣は思考を曇らせ、時間と健康を静かに奪う。',
        creatorName: 'アドリアン・ブラウエル',
        creatorHandle: '@satire_archive',
        imageFile: 'Adriaen_Brouwer_-_The_Smokers.jpg',
        likes: 806,
        comments: 18,
        reposts: 54,
      ),
      CampaignVideo(
        id: 'print-peasants-tavern',
        category: CampaignCategory.tobacco,
        title: '『居酒屋の農民たち』(17世紀)',
        caption: 'パイプと酒に沈む夜。惰性の煙が一日を溶かしていく。',
        creatorName: 'アドリアーン・ファン・オスターデ',
        creatorHandle: '@satire_archive',
        likes: 512,
        comments: 12,
        reposts: 31,
      ),
      CampaignVideo(
        id: 'print-vanitas-pipe',
        category: CampaignCategory.tobacco,
        title: '『ヴァニタス — 髑髏とパイプ』',
        caption: '立ちのぼる煙は儚さの象徴。「煙のように消える人生」への戒め。',
        creatorName: '17世紀オランダ静物画',
        creatorHandle: '@satire_archive',
        likes: 623,
        comments: 15,
        reposts: 48,
      ),
      // ── 風俗 ──────────────────────────────────────
      CampaignVideo(
        id: 'print-harlots-progress',
        category: CampaignCategory.fuzoku,
        title: '『娼婦一代記』第1葉 (1732)',
        caption: '地方から出た娘が誘われ堕ちていく入口。悪徳の連鎖の始まり。',
        creatorName: 'ウィリアム・ホガース',
        creatorHandle: '@satire_archive',
        likes: 1338,
        comments: 58,
        reposts: 141,
      ),
      CampaignVideo(
        id: 'print-rakes-progress',
        category: CampaignCategory.fuzoku,
        title: '『放蕩者一代記』第3葉 (1735)',
        caption: '娼館での放蕩の夜。享楽に財を蕩尽し、破滅へ向かう青年。',
        creatorName: 'ウィリアム・ホガース',
        creatorHandle: '@satire_archive',
        likes: 1571,
        comments: 62,
        reposts: 159,
      ),
      CampaignVideo(
        id: 'print-los-caprichos',
        category: CampaignCategory.fuzoku,
        title: '『ロス・カプリチョス』(1799)',
        caption: '欲望・虚栄・仲介する老婆——人間の悪徳を暴いたゴヤの銅版画集。',
        creatorName: 'フランシスコ・デ・ゴヤ',
        creatorHandle: '@satire_archive',
        likes: 1189,
        comments: 44,
        reposts: 118,
      ),
      CampaignVideo(
        id: 'print-marriage-a-la-mode',
        category: CampaignCategory.fuzoku,
        title: '『当世風結婚』第2葉 (1743)',
        caption: '放蕩と不実がむしばむ夫婦。快楽の代償は静かに膨らむ。',
        creatorName: 'ウィリアム・ホガース',
        creatorHandle: '@satire_archive',
        likes: 942,
        comments: 29,
        reposts: 88,
      ),
    ];
  }

  /// [date] を種にした決定論的ローテーション。
  ///
  /// 同じ日付なら常に同じ [count] 件を返し、日付が変われば別の組み合わせになる
  /// (= 毎日ランダムに入れ替わって見える)。日付シードの Fisher-Yates で並べ替える。
  static List<CampaignVideo> dailyPicks(DateTime date, {int count = 3}) {
    final lib = all();
    if (lib.isEmpty || count <= 0) return const [];
    final take = count < lib.length ? count : lib.length;

    final order = List<int>.generate(lib.length, (i) => i);
    var state = (date.year * 10000 + date.month * 100 + date.day) & 0x7fffffff;
    int nextRandom() {
      state = (state * 1103515245 + 12345) & 0x7fffffff;
      return state;
    }

    for (var i = order.length - 1; i > 0; i--) {
      final j = nextRandom() % (i + 1);
      final tmp = order[i];
      order[i] = order[j];
      order[j] = tmp;
    }
    return [for (final i in order.take(take)) lib[i]];
  }
}
