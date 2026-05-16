enum TomeDeckScenario {
  investorDeck,
  aiUniversityInfographic,
  competitorAirtable,
}

class TomePageSpec {
  const TomePageSpec({
    required this.title,
    required this.narrative,
    required this.visualDirection,
    required this.blocks,
    required this.speakerNote,
  });

  final String title;
  final String narrative;
  final String visualDirection;
  final List<String> blocks;
  final String speakerNote;
}

class TomeDeckPlan {
  const TomeDeckPlan({
    required this.scenario,
    required this.issueNumber,
    required this.title,
    required this.audience,
    required this.kgi,
    required this.csf,
    required this.kpi,
    required this.pages,
    required this.tomePrompt,
    required this.automationNotes,
    required this.sourceHints,
    required this.liveIntegrationReady,
  });

  final TomeDeckScenario scenario;
  final int issueNumber;
  final String title;
  final String audience;
  final String kgi;
  final List<String> csf;
  final Map<String, int> kpi;
  final List<TomePageSpec> pages;
  final String tomePrompt;
  final List<String> automationNotes;
  final List<String> sourceHints;
  final bool liveIntegrationReady;

  int get pageCount => pages.length;

  int get readinessScore {
    final kgiScore = kgi.trim().isEmpty ? 0 : 25;
    final csfScore = csf.length >= 3 ? 25 : csf.length * 8;
    final pageScore = pages.length >= 6 ? 30 : pages.length * 5;
    final automationScore = automationNotes.isEmpty ? 0 : 20;
    return (kgiScore + csfScore + pageScore + automationScore).clamp(0, 100);
  }
}

class TomeDeckStudioService {
  const TomeDeckStudioService();

  static const tomeProviderId = 'tome_app';
  static const sourceHintTome = 'Tome: Web 公開とリッチブロックを備えた AI デッキ / ページビルダー';
  static const sourceHintAirtable = 'Airtable: ライブテーブルや自動化実行のための構造化ソースデータ';

  TomeDeckPlan buildPlan({
    required TomeDeckScenario scenario,
    String topic = '',
    String audience = '',
    String sourceText = '',
  }) {
    final normalizedTopic =
        _clean(topic).isEmpty ? _defaultTopic(scenario) : _clean(topic);
    final normalizedAudience = _clean(audience).isEmpty
        ? _defaultAudience(scenario)
        : _clean(audience);
    final sourceSummary = _summarize(sourceText, fallback: normalizedTopic);

    switch (scenario) {
      case TomeDeckScenario.investorDeck:
        return _investorDeck(
          normalizedTopic,
          normalizedAudience,
          sourceSummary,
        );
      case TomeDeckScenario.aiUniversityInfographic:
        return _aiUniversityDeck(
          normalizedTopic,
          normalizedAudience,
          sourceSummary,
        );
      case TomeDeckScenario.competitorAirtable:
        return _competitorDeck(
          normalizedTopic,
          normalizedAudience,
          _parseTableRows(sourceText),
        );
    }
  }

  String buildMarkdown(TomeDeckPlan plan) {
    final buffer = StringBuffer()
      ..writeln('# ${plan.title}')
      ..writeln()
      ..writeln('対象読者: ${plan.audience}')
      ..writeln('KGI: ${plan.kgi}')
      ..writeln()
      ..writeln('## CSF')
      ..writeln(plan.csf.map((item) => '- $item').join('\n'))
      ..writeln()
      ..writeln('## KPI')
      ..writeln(
        plan.kpi.entries
            .map((entry) => '- ${entry.key}: ${entry.value}')
            .join('\n'),
      )
      ..writeln()
      ..writeln('## Tome プロンプト')
      ..writeln(plan.tomePrompt)
      ..writeln();

    for (var i = 0; i < plan.pages.length; i++) {
      final page = plan.pages[i];
      buffer
        ..writeln('## ページ ${i + 1}: ${page.title}')
        ..writeln(page.narrative)
        ..writeln()
        ..writeln('ビジュアル: ${page.visualDirection}')
        ..writeln()
        ..writeln(page.blocks.map((block) => '- $block').join('\n'))
        ..writeln()
        ..writeln('スピーカーノート: ${page.speakerNote}')
        ..writeln();
    }

    buffer
      ..writeln('## 自動化メモ')
      ..writeln(plan.automationNotes.map((item) => '- $item').join('\n'))
      ..writeln()
      ..writeln('## ソースヒント')
      ..writeln(plan.sourceHints.map((item) => '- $item').join('\n'));
    return buffer.toString().trim();
  }

  TomeDeckPlan _investorDeck(
    String topic,
    String audience,
    String sourceSummary,
  ) {
    final pages = [
      TomePageSpec(
        title: 'エグゼクティブテーゼ',
        narrative: '$topic はライフマネジメント OS として位置付けられる。',
        visualDirection: '1 つの強いアウトカム指標を伴うヒーロー製品スクリーンショット。',
        blocks: const [
          'ワンライン約束',
          '現在のトラクションスナップショット',
          'なぜ今なのか',
        ],
        speakerNote: '機能数ではなく緊急性から始める。',
      ),
      const TomePageSpec(
        title: '課題',
        narrative: 'ユーザーは時間・お金・健康・体力・知能・集中力を未計測の漏れで失っている。',
        visualDirection: '6 つの漏れファネル(赤→緑コンバージョン)。',
        blocks: [
          '時間の無駄',
          'お金の無駄',
          '健康・体力の無駄',
          '集中・判断の無駄',
        ],
        speakerNote: '無駄を具体的かつ計測可能にする。',
      ),
      const TomePageSpec(
        title: '解決策',
        narrative: '本システムは生の行動を KGI / CSF / KPI / モニタリング / アクションへ変換する。',
        visualDirection: 'Before / After のオペレーティングループ図。',
        blocks: [
          '現状分析',
          'KGI/CSF/KPI 設定',
          '定常モニタリング',
          'WBS による改善',
        ],
        speakerNote: 'AI 出力を具体的なオペレーションに接続する。',
      ),
      TomePageSpec(
        title: '製品概要',
        narrative: sourceSummary,
        visualDirection: '4 カード製品マップ: ホーム / AI 大学 / WBS / Life OS。',
        blocks: const [
          'AI 大学',
          'プロジェクト WBS',
          'ライフ無駄削減',
          'シェア & 成長ループ',
        ],
        speakerNote: 'ツールの集合ではなくシステムとして示す。',
      ),
      const TomePageSpec(
        title: 'ビジネスモデル',
        narrative: 'まずパーソナル OS、次にチーム / エンタープライズ workflow へ拡張。',
        visualDirection: '段階的レベニューラダー。',
        blocks: [
          '個人向け生産性',
          'チームオペレーティングダッシュボード',
          'エンタープライズ自動化',
        ],
        speakerNote: '誇張せず拡張パスを説明する。',
      ),
      const TomePageSpec(
        title: 'アスク',
        narrative: '次のマイルストーンは再現可能な「習慣→事業」ループ。',
        visualDirection: '30/60/90 日マイルストーンのロードマップ。',
        blocks: [
          '資金調達 / パートナーシップアスク',
          '短期プロダクトマイルストーン',
          'キー検証指標',
        ],
        speakerNote: '1 つの判断と 1 つの次アクションで締める。',
      ),
    ];

    return TomeDeckPlan(
      scenario: TomeDeckScenario.investorDeck,
      issueNumber: 756,
      title: 'Tome 投資家 / 社内レポートデッキ',
      audience: audience,
      kgi: '投資家または社内レポート用の判断準備済 Tome デッキを作成する。',
      csf: const [
        '計測可能な無駄削減とユーザー価値で先導する',
        '製品をオペレーティングループとして示す',
        '具体的なアスクと次マイルストーンで締める',
      ],
      kpi: const {
        'pages': 6,
        'decision_points': 1,
        'metric_blocks': 4,
      },
      pages: pages,
      tomePrompt:
          '"$topic" について $audience 向けの投資家グレード Tome デッキを簡潔に作成。太字セクション見出し / データカード / 製品スクリーンショット / 1 つの明確なアスクを使用。',
      automationNotes: const [
        '生成されたマークダウンを Tome の narrative source として貼り付け。',
        'エグゼクティブテーゼとアスクページに Tome AI ナレーションを使用。',
        'トラクションとアスクのブロックを差し替えて社内週次レポートに再利用。',
      ],
      sourceHints: const [sourceHintTome],
      liveIntegrationReady: true,
    );
  }

  TomeDeckPlan _aiUniversityDeck(
    String topic,
    String audience,
    String sourceSummary,
  ) {
    final pages = [
      const TomePageSpec(
        title: '学習マップ',
        narrative: 'AI 大学は分散した provider 知識を構造化されたカリキュラムへ転換する。',
        visualDirection: 'provider 能力でグルーピングしたネットワークマップ。',
        blocks: ['プロバイダー', 'ジャンル', 'クイズ', 'RLHF フィードバック'],
        speakerNote: '単一 provider ではなく学習システムから始める。',
      ),
      TomePageSpec(
        title: 'プロバイダースポットライト',
        narrative: sourceSummary,
        visualDirection: 'ロゴプレースホルダと能力レーダーを伴うインフォグラフィックカード。',
        blocks: const [
          'コアユースケース',
          '強み',
          '弱み',
          'ベスト workflow',
        ],
        speakerNote: 'プロバイダーを 1 ページで記憶に残す。',
      ),
      const TomePageSpec(
        title: '比較',
        narrative: '学習者は近い代替案と比較されるとツールを早く理解する。',
        visualDirection: '色分け適合度を伴う 3 列比較テーブル。',
        blocks: [
          'Tome ライクな出力',
          'ビデオ / 音声対応',
          '自動化適合度',
        ],
        speakerNote: '比較で曖昧さを減らす。',
      ),
      const TomePageSpec(
        title: '実践ループ',
        narrative: 'クイズ結果とフィードバックが学習データフライホイールになる。',
        visualDirection: 'ループ図: 学習 → クイズ → フィードバック → 再生成。',
        blocks: [
          '問題',
          '解答',
          'フィードバック信号',
          'コンテンツ改善',
        ],
        speakerNote: '教育とデータ品質を接続する。',
      ),
      const TomePageSpec(
        title: 'インフォグラフィック書き出し',
        narrative: '各レッスンは共有可能な Tome ページまたはビジュアルブリーフィングになる。',
        visualDirection: '見出し / 3 ファクト / CTA を伴う縦向きインフォグラフィック。',
        blocks: [
          '見出し',
          '3 つのデータポイント',
          'アクションプロンプト',
          '共有リンク',
        ],
        speakerNote: 'ソーシャル配信に再利用可能にする。',
      ),
    ];

    return TomeDeckPlan(
      scenario: TomeDeckScenario.aiUniversityInfographic,
      issueNumber: 757,
      title: 'Tome AI 大学 インフォグラフィックページ',
      audience: audience,
      kgi: 'AI 大学コンテンツを 1 つのコンセプトを素早く教えるビジュアル Tome ページへ転換する。',
      csf: const [
        '各レッスンを 1 つのビジュアル mental model に圧縮',
        '長文の代わりに比較と例示を使用',
        'クイズと RLHF 信号を次回改訂にフィードバック',
      ],
      kpi: const {
        'pages': 5,
        'visual_blocks': 5,
        'quiz_feedback_loops': 1,
      },
      pages: pages,
      tomePrompt:
          'AI 大学トピック "$topic" からビジュアル Tome ページを作成。インフォグラフィックブロック / 比較カード / $audience 向け学習者アクションプロンプトに変換する。',
      automationNotes: const [
        'AI 大学 provider ページをソーステキストとして使用。',
        '1 provider あたり 1 Tome ページ、または 1 ジャンルあたり 1 ショートデッキを生成。',
        'クイズ失敗と RLHF ネガティブ信号を書換ターゲットとして使用。',
      ],
      sourceHints: const [sourceHintTome],
      liveIntegrationReady: true,
    );
  }

  TomeDeckPlan _competitorDeck(
    String topic,
    String audience,
    List<Map<String, String>> rows,
  ) {
    final topRows = rows.take(5).toList();
    final competitorNames = topRows
        .map((row) => row.values.isEmpty ? '' : row.values.first)
        .where((value) => value.trim().isNotEmpty)
        .join(', ');
    final summary = competitorNames.isEmpty
        ? '競合主張のライブソースとして Airtable レコードを使用する。'
        : '現在の Airtable 行は次をカバー: $competitorNames。';

    final pages = [
      TomePageSpec(
        title: 'マーケットマップ',
        narrative: summary,
        visualDirection: '自動化深度 × ユーザー価値の 2x2 競合マトリクス。',
        blocks: const [
          '競合セグメント',
          '主要脅威',
          '差別化角度',
        ],
        speakerNote: 'マーケットの形状から始める。',
      ),
      const TomePageSpec(
        title: '比較テーブル',
        narrative: '比較ページはレビュー前に Airtable から更新する必要がある。',
        visualDirection: 'ライブテーブル埋込みまたは強調 gap 付き貼り付けテーブル。',
        blocks: ['プロダクト', '機能', '価格', 'リスク', '対抗策'],
        speakerNote: 'このページは事実 + ソース裏付けを維持。',
      ),
      const TomePageSpec(
        title: '脅威ランキング',
        narrative: '影響度・緊急度・プロダクト重複で競合を優先順位付け。',
        visualDirection: '赤 / 黄 / 緑ステータス付きランク脅威バー。',
        blocks: ['緊急', '高', '監視', '当面無視'],
        speakerNote: '優先順位の判断を弁護できるようにする。',
      ),
      const TomePageSpec(
        title: 'カウンター戦略',
        narrative: '各競合は 1 機能 / 1 メッセージ / 1 WBS タスクへマッピング。',
        visualDirection: '3 レーンアクションボード。',
        blocks: [
          '機能レスポンス',
          'メッセージレスポンス',
          'モニタリングオーナー',
        ],
        speakerNote: 'リサーチをアクションへ転換する。',
      ),
      const TomePageSpec(
        title: '自動化ケイデンス',
        narrative: 'Airtable リフレッシュ → サマリ再生成 → 週次レビュー前に Tome 更新。',
        visualDirection: 'Airtable → Tome 自動化フロー。',
        blocks: [
          'Airtable ソース',
          'AI サマリ',
          'Tome 更新',
          'WBS タスク',
        ],
        speakerNote: '更新リズムを明示する。',
      ),
    ];

    return TomeDeckPlan(
      scenario: TomeDeckScenario.competitorAirtable,
      issueNumber: 758,
      title: 'Tome 競合比較デッキ',
      audience: audience,
      kgi: '週次プロダクト判断を導けるよう競合比較資料の鮮度を維持する。',
      csf: const [
        'Airtable を競合事実の構造化ソースとして使用',
        '事実比較と戦略解釈を分離',
        'ハイリスクの発見をすべて WBS アクションへ転換',
      ],
      kpi: {
        'pages': 5,
        'airtable_rows_used': rows.length,
        'weekly_refreshes': 1,
      },
      pages: pages,
      tomePrompt:
          '"$topic" について $audience 向けの Tome 競合比較デッキを作成。Airtable スタイルレコードをソースデータに、比較テーブル表示・脅威ランキング・WBS アクションで締める。',
      automationNotes: const [
        '即時デッキドラフト用に Airtable CSV/TSV を本スタジオへ貼り付け。',
        'ライブデータが必要な時は Airtable ビューを Tome に埋め込み。',
        '残るライブ自動化には Airtable token / base / table マッピングが必要。',
      ],
      sourceHints: const [sourceHintTome, sourceHintAirtable],
      liveIntegrationReady: false,
    );
  }

  static String _defaultTopic(TomeDeckScenario scenario) {
    switch (scenario) {
      case TomeDeckScenario.investorDeck:
        return 'ライフマネジメント AI OS';
      case TomeDeckScenario.aiUniversityInfographic:
        return 'AI 大学プロバイダーレッスン';
      case TomeDeckScenario.competitorAirtable:
        return '競合比較と週次プロダクト判断';
    }
  }

  static String _defaultAudience(TomeDeckScenario scenario) {
    switch (scenario) {
      case TomeDeckScenario.investorDeck:
        return '投資家 / 経営会議';
      case TomeDeckScenario.aiUniversityInfographic:
        return 'AI 大学学習者';
      case TomeDeckScenario.competitorAirtable:
        return 'プロダクト / マーケティングチーム';
    }
  }

  static String _summarize(String text, {required String fallback}) {
    final cleaned = _clean(text);
    if (cleaned.isEmpty) return fallback;
    if (cleaned.length <= 260) return cleaned;
    return '${cleaned.substring(0, 260)}...';
  }

  static String _clean(String text) {
    return text.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static List<Map<String, String>> _parseTableRows(String text) {
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.length < 2) return const [];

    final delimiter = lines.first.contains('\t') ? '\t' : ',';
    final headers = lines.first
        .split(delimiter)
        .map((header) => header.trim())
        .where((header) => header.isNotEmpty)
        .toList();
    if (headers.isEmpty) return const [];

    final rows = <Map<String, String>>[];
    for (final line in lines.skip(1)) {
      final cells = line.split(delimiter).map((cell) => cell.trim()).toList();
      rows.add({
        for (var i = 0; i < headers.length; i++)
          headers[i]: i < cells.length ? cells[i] : '',
      });
    }
    return rows;
  }
}
