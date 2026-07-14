// R21: X コピー生成のアンチスロップ・ガードレール(依存ゼロ = VM テスト可能)。
//
// なぜ必要か: X 投稿コピーの生成経路が2つあり、universal_x_share_service だけが
// R11-R15 でアンチスロップ強化されていた。ダッシュボードの「X投稿を作る」CTA が
// 飛ぶ CmoPage は別プロンプトで、旧世代の一般論スロップ(実測 2026-07-10:
// 「あなたの価値、埋もれていませんか？…自分集客力を構築」)を再生産していた。
// FEATURE-FACT / 禁止トークン / 機能名を1箇所へ集約し、両経路のドリフトを防ぐ。

/// アプリの実在する具体機能(一次事実)。LLM はこの一覧を渡され、今日の主題に
/// 直結する1つを名前で挙げるよう求められる。universal_x_share_service と
/// CmoPage の両方がこの単一定数を参照する(byte-identical MOVE)。
const List<String> kAppFeatureFacts = <String>[
  '給料日サイクル: 給料日起点の窓で支出を実測し、過去分の二重控除を排除する家計把握',
  '負債トレンド: 口座別の残高履歴を月次で検出し、翌月の具体アクションを提示',
  'Xワンボタン投稿: 当日ニュースを字幕付きの短尺動画に自動要約して投稿',
  '資産/負債の端末跨ぎ同期: 残高履歴を端末を跨いで同期し、いつでも同じ数字を見る',
  '給与明細取込: 明細から手取りを取り込み、給料日サイクルの収入へ自動合算',
  'AI参謀室ブリーフィング: 資金繰り予測と負債トレンドを6部署が1つの状況として裁定し、部署別の次アクションを提示',
];

/// 空虚な精神論・造語のスロップトークン。R11-R15 の中核禁止語 + 2026-07-10 に
/// CmoPage が実際に出力したスロップ語。生成後の検出(detectSlop)にも使う。
const List<String> kSlopBannedTokens = <String>[
  // R11-R15 の中核(両経路の語彙が乖離しないための drift guard)
  '可能性があります',
  '強力なツール',
  '劇的に',
  '大幅に',
  '格段に',
  '重要性を認識',
  '効率よく整理',
  'と言えるでしょう',
  'game-changer',
  'powerful tool',
  // R22 実測すり抜け(2026-07-11 の実投稿: exact 禁止をかわした変形)
  'ぜひ試して',
  'ぜひ使ってみて',
  'ウェブアプリ',
  'が向上しました',
  // R21 実測スロップ(CmoPage が出した型)
  '埋もれた才能',
  '埋もれていませんか',
  '最大限にアピール',
  '社会で輝く',
  '理想の未来へ',
  '今すぐ一歩',
  '自分集客力',
  '価値、埋もれ',
];

/// 実在機能名(短縮キー)。生成物が固有機能に触れているか(hasFeatureAnchor)の判定用。
const List<String> kFeatureNames = <String>[
  '給料日サイクル',
  '負債トレンド',
  'Xワンボタン投稿',
  '端末跨ぎ同期',
  '給与明細',
  '参謀室',
];

/// R26: 内容アーキタイプの実測教訓。運営者提供の過去3ヶ月トップ
/// (2026-07-05 / 97K)と、2026-07-12 同日3連投(3.2K / 517 / 28)の両方から、
/// 独自集計データのレポート型が勝ち筋であることを共有する。単発97Kだけを因果と
/// 断定せず、同日比較を補助証拠として扱う。両生成経路
/// (universal_x_share_service / CmoPage)がこの単一定数を参照してドリフトを
/// 防ぐ(kAppFeatureFacts と同じ集約パターン)。
///
/// 注意: この定数は「測定事実+原則」のみ。「冒頭1行目に実数を置け」等の実行
/// 命令は、実数の供給源(当日見出し/実測データ行)を持つ universal 経路だけに
/// 置く — 供給源の無い CmoPage プロンプトへ命令だけ注入すると捏造圧力になる
/// (レビュー F3/F4)。
const String kDataReportArchetypeLesson =
    '実測の教訓: 運営者提供の過去3ヶ月トップは 2026-07-05 の 97K インプレッション。'
    '独自に集計した実数を「対象+基準日→取得日時→主要値→基準との差分→残り/期限→'
    'アラート→全体内訳→固有名詞の明細→公式ソース」の順で検算可能な参照資料にした'
    '「データダイジェスト型」だった。2026-07-12 の同日比較でも同系統のデータレポート型が 3.2K、'
    'ニュース要約スレが 517、ニュース→製品転換型が 28。97K は単発の歴史的ベンチマークであり、'
    '政治日程・既存読者・投稿時刻など他要因もあるため型だけの因果とは断定しない。'
    'AIは新情報を作らず、鮮度・絶対値・差分・目標・期限・内訳・異常・出典を編集する役に徹する。'
    '97Kという値を今日の投稿実績として流用してはならない。数字・固有名詞・ソースは payload に'
    '実在するものだけを使い、供給源が無いなら数字の少ない構成に落とせ(捏造は禁止)。';

/// CmoPage 用の生成プロンプトを組み立てる純関数。channel 非依存のアンチスロップ
/// テキスト(FEATURE-FACT / 一人称 persona / 禁止語 / 具体性要求 / BAD→GOOD)を
/// 追加し、既存の per-channel spec(長さ/tone)と {title,body,hashtags} 契約は
/// 一切上書きしない(facebook も同プロンプトを共有するため長さは spec のまま)。
/// performance_context の promptContext 文字列から "Own measured data" 行を
/// 抽出する純関数(CmoPage が実測供給源として使う / R23 F3 恒久解)。
/// この行はこのアカウント自身の実測インプレッションで、一人称の build-in-public
/// 実数として公開してよい唯一の恒常データ源(growth-hub buildOwnDataFactsLine)。
/// 見つからない/薄いデータ時は null(呼び出し側は捏造禁止ガードへ落とす)。
String? extractOwnMeasuredDataLine(String? performanceContext) {
  final source = (performanceContext ?? '').trim();
  if (source.isEmpty) return null;
  for (final rawLine in source.split('\n')) {
    final line = rawLine.trim();
    if (line.startsWith('Own measured data')) {
      return line.isEmpty ? null : line;
    }
  }
  return null;
}

String buildCmoDraftPrompt({
  required String channelKey,
  required String channelLabel,
  required Map<String, String> spec,
  required List<String> hashtags,
  String? measuredDataLine,
}) {
  final facts = kAppFeatureFacts.map((fact) => '- $fact').join('\n');
  final banned = kSlopBannedTokens.map((token) => '「$token」').join(' / ');
  // R23 F3 恒久解: 実測データ行があれば「実数を使ってよい」経路(universal 経路と
  // 対称)。無ければ従来どおり数字の新規生成を明示禁止する(供給源の無い経路へ
  // 「冒頭に実数」命令だけ注入すると捏造圧力になる)。
  final measured = (measuredDataLine ?? '').trim();
  final dataRule = measured.isNotEmpty
      ? '$kDataReportArchetypeLesson '
          '実測データ(このアカウント自身のX投稿の実測値。一人称の build-in-public 実数として公開してよい): '
          '$measured '
          'データレポート型で書くなら冒頭1行目にこの実測値を1つ置け。ただしこの実測行と上の実在機能リストに無い数字は作るな。'
      : '$kDataReportArchetypeLesson '
          'このプロンプトには実数の供給源(当日見出し・実測データ)を渡していないので、新しい数字を作るな。使ってよい数字は上の実在機能リストの仕組みが定義する数のみ。';
  return '''
あなたは「自分株式会社」という一人会社を運営する開発者本人です。$channelLabel 向けの日本語コピーを、build-in-public の一人称で書いてください。三人称のブランド口調(「私たち」「弊社」「本サービスは」「私たちの新しいウェブアプリは」)を禁止します。

目的:
- ${spec['goal']}

App の実在する具体機能(この中から今日伝える1つを名前で挙げ、それが何を数値/画面/具体で解決するかを書く。アプリを「ツール」等の一般名詞で濁すな):
$facts

必須ルール:
- 一人称の実体験で書く=自分が何を作った/実測した/つまずいたかを最低1つ具体で入れる。伝聞・一般論・精神論・造語を禁止。
- 本文に上の実在機能を最低1つ名前で挙げる(固有機能名を必ず含める)。
- 禁止フレーズ(これらを含む文は必ず書き直せ): $banned。
- 誇張副詞(劇的に/大幅に/格段に/飛躍的に)で改善を主張するな。改善の大きさは具体的な数字か仕組み(何がどう動いて何が消えるか)でのみ語れ。
- $dataRule

例(実質・BAD→GOOD、この差を真似て今日の内容で書け):
- BAD: 「あなたの価値、埋もれていませんか？埋もれた才能を最大限にアピールし、社会で輝くための自分集客力を構築。」
- GOOD: 「『給料日サイクル』は支出の窓を給料日起点に切る機能。作って分かったのは、月初をまたぐ引き落としが二重計上されず支出が実額で出ること。5分触って一言もらえると助かります。」

出力条件:
- JSONのみを返す(Markdownやコードフェンスは禁止)
- keys は title, body, hashtags
- title: ${spec['titleRule']}。ただし空虚なフックでなく具体(機能名や数字)を入れる。
- body: ${spec['bodyRule']}
- tone: ${spec['tone']}
- hashtags: $channelLabel に適した発見タグを3件

出力形式:
{
  "title": "...",
  "body": "...",
  "hashtags": ["...", "...", "..."]
}

推奨ハッシュタグ:
${hashtags.join(' ')}
''';
}

/// 生成された title/body に含まれるスロップトークンを返す(空=クリーン)。
/// プロンプトをすり抜けたスロップやクライアント側フォールバック文言を、投稿前に
/// 非ブロッキングで警告するための検出器。
List<String> detectSlop(String title, String body) {
  final haystack = '$title\n$body';
  return kSlopBannedTokens.where(haystack.contains).toList(growable: false);
}

/// 生成物が実在機能に1つでも触れているか。false=一般論に流れている疑い。
bool hasFeatureAnchor(String title, String body) {
  final haystack = '$title\n$body';
  return kFeatureNames.any(haystack.contains);
}

/// 検出結果から非ブロッキング警告文を作る(空なら null)。投稿は止めず、
/// 再生成を促すだけ(自動再生成は有償生成の foot-gun なのでしない)。
String? composeSlopWarning(List<String> hits) {
  if (hits.isEmpty) return null;
  final shown = hits.take(3).map((t) => '「$t」').join(' ');
  return '言い換え候補: $shown を含みます。具体性が薄い可能性があるため再生成を推奨します(このまま投稿も可能)。';
}
