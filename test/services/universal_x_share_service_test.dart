import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/ai_hub_chat_service.dart';
import 'package:my_web_app/services/ai_share_button_preferences_service.dart';
import 'package:my_web_app/services/universal_x_share_service.dart';
import 'package:my_web_app/services/x_copy_guardrails.dart';

// 非 finance の presenter 動画で使う音声ラベル一覧(エッジ側 voice_labels.ts と対応)。
// 中庸の male/female_narrator に加え、トーン別 energetic_* / calm_* を含む。
const _kVoiceLabels = <String>[
  'female_narrator',
  'male_narrator',
  'energetic_female',
  'energetic_male',
  'calm_female',
  'calm_male',
];

void main() {
  const page = UniversalSharePageContext(
    routePath: '/gemini-university',
    title: 'Gemini University',
    url: 'https://my-web-app-b67f4.web.app/gemini-university',
  );

  test('fallback draft includes clean page URL', () {
    final draft = UniversalXShareService.buildFallbackDraft(page);

    expect(draft.text, contains(page.url));
    expect(draft.text, contains('utm_campaign=first_user_growth'));
    expect(draft.text, isNot(contains('/#/')));
    expect(draft.text.length, lessThanOrEqualTo(280));
    expect(draft.imagePrompt, contains('Gemini University'));
    expect(draft.videoPrompt, contains('Gemini University'));
  });

  test('growth draft variants include measurable X acquisition URLs', () {
    final draft = UniversalXShareService.buildGrowthDraft(
      page,
      variant: UniversalXGrowthShareVariant.questionPost,
    );

    expect(draft.source, 'growth-fallback');
    expect(draft.text, contains(page.url));
    expect(draft.text, contains('utm_source=x'));
    expect(draft.text, contains('utm_medium=ai_share'));
    expect(draft.text, contains('utm_campaign=first_user_growth'));
    expect(draft.text, contains('utm_content=question_post'));
    expect(draft.text, contains('質問です'));
    expect(draft.text, contains('一言もらえると助かります'));
    expect(draft.text, isNot(contains('繝')));
    expect(draft.text, isNot(contains('譛')));
    expect(draft.text, isNot(contains('/#/')));
    expect(draft.text.length, lessThanOrEqualTo(280));
    expect(draft.imagePrompt, contains('presenter'));
    expect(draft.imagePrompt, contains('no explicit sexualization'));
  });

  test('daily briefing draft turns X trends into a thread', () {
    final draft = UniversalXShareService.buildGrowthDraft(
      page,
      trendTopics: const [
        UniversalXTrendTopic(name: 'ワールドカップ', tweetCount: 120000),
        UniversalXTrendTopic(name: 'OpenAI', tweetCount: 42000),
        UniversalXTrendTopic(name: '日経平均', tweetCount: 18000),
      ],
    );

    // リード 1 行目は「デイリーブリーフィング — 日付」ラベルではなく、当日トップ
    // 見出しの具体フックで始まること(=フォールド上でスクロールを止める)。
    final firstLine = draft.text.split('\n').first;
    expect(firstLine, contains('ワールドカップ'));
    expect(firstLine, isNot(contains('デイリーブリーフィング')));
    expect(draft.text, isNot(contains('デイリーブリーフィング')));
    expect(draft.text, contains('ワールドカップ'));
    expect(draft.text, isNot(contains('Xで伸びている論点')));
    expect(draft.text, contains(page.url));
    expect(draft.text, contains('utm_content=daily_briefing'));
    expect(draft.text.length, lessThanOrEqualTo(280));
    expect(draft.threadReplies.length, greaterThanOrEqualTo(4));
    expect(draft.threadReplies.first, contains('なぜ重要か'));
    expect(draft.threadReplies.first, contains('見通し'));
    expect(draft.threadReplies.first.length, lessThanOrEqualTo(280));
  });

  test('fallback thread commentary never repeats within one thread', () {
    // 実障害(2026-07-06): 同一カテゴリのトレンド3件で「なぜ重要か/見通し」が
    // 完全一致(near-duplicate)。5変種プール×seedローテで pairwise 重複ゼロに。
    final draft = UniversalXShareService.buildGrowthDraft(
      page,
      trendTopics: const [
        UniversalXTrendTopic(name: '税収過去最高'),
        UniversalXTrendTopic(name: 'サイバー攻撃で退会'),
        UniversalXTrendTopic(name: '高校生を逮捕'),
        UniversalXTrendTopic(name: '広島工場増強'),
        UniversalXTrendTopic(name: '不正プログラム自作'),
      ],
    );
    // トレンド名部分を除いた解説部分(なぜ重要か以降)で重複を判定する。
    final commentaries = draft.threadReplies
        .where((reply) => reply.contains('なぜ重要か'))
        .map((reply) => reply.substring(reply.indexOf('なぜ重要か')))
        .toList();
    expect(commentaries.length, greaterThanOrEqualTo(5));
    expect(
      commentaries.toSet().length,
      commentaries.length,
      reason: 'no two replies may share identical commentary',
    );

    // トレンドなしの既定3件でも重複しない。
    final defaults = UniversalXShareService.buildGrowthDraft(page);
    final defCommentaries = defaults.threadReplies
        .where((reply) => reply.contains('なぜ重要か'))
        .map((reply) => reply.substring(reply.indexOf('なぜ重要か')))
        .toList();
    expect(defCommentaries.toSet().length, defCommentaries.length);
  });

  test('fallback poll obeys R13b subject-lock and current-state rules', () {
    // R13b(#3872): fallback poll は _buildDraftPrompt を通らないため R12 の poll
    // ルールが効かない。旧「今日の注目『$topic』、あなたは？」+「詳しく知りたい/
    // 関係なし」(関心度サーベイ = R12 で潰した 0 票型)が復活しないことを検証する。

    // AI・テック トレンド → 一人称・現在状態 poll。
    final ai = UniversalXShareService.buildGrowthDraft(
      page,
      trendTopics: const [UniversalXTrendTopic(name: 'ChatGPTの新機能が話題')],
    );
    expect(ai.poll, isNotNull);
    // 汎用の関心度 stem / 選択肢は復活しない(R12 準拠)。
    expect(ai.poll!.question, isNot(contains('あなたは？')));
    expect(ai.poll!.question, isNot(contains('今日の注目「')));
    expect(ai.poll!.options, isNot(contains('詳しく知りたい')));
    expect(ai.poll!.options, isNot(contains('関係なし')));
    expect(ai.poll!.options, isNot(contains('様子見')));
    expect(ai.poll!.options.length, inInclusiveRange(3, 4));
    for (final option in ai.poll!.options) {
      expect(option.runes.length, lessThanOrEqualTo(25));
    }

    // 経済・市場 トレンド → 家計の現在状態 poll(主題がアプリと一致)。
    final money = UniversalXShareService.buildGrowthDraft(
      page,
      trendTopics: const [UniversalXTrendTopic(name: '円安が加速し日経平均が急落')],
    );
    expect(money.poll, isNotNull);
    expect(money.poll!.question, isNot(contains('今日の注目「')));
    expect(money.poll!.options, isNot(contains('関係なし')));

    // アプリ中核の家計トレンド(物価/給料 等)も poll を発火させる(旧 false-negative)。
    final prices = UniversalXShareService.buildGrowthDraft(
      page,
      trendTopics: const [UniversalXTrendTopic(name: '物価高で家計が悲鳴')],
    );
    expect(prices.poll, isNotNull);
    expect(prices.poll!.options, isNot(contains('関係なし')));

    // 誤爆回帰: 'アイドル' は 'ドル' を部分に含むが家計トレンドではない。
    // 家計 poll を貼らず、非関連として poll を省略すること。
    final idol = UniversalXShareService.buildGrowthDraft(
      page,
      trendTopics: const [UniversalXTrendTopic(name: 'アイドルグループが解散を発表')],
    );
    expect(idol.poll, isNull);

    // カテゴリ特定不能な汎用トレンド → poll を省略(本文主題ズレ/0票を回避)。
    final generic = UniversalXShareService.buildGrowthDraft(
      page,
      trendTopics: const [UniversalXTrendTopic(name: 'カルピスの誕生日')],
    );
    expect(generic.poll, isNull);

    // 誤爆回帰: 'Ukraine' は小文字部分一致 'ai' を含むが AI トレンドではない。
    // AI 現在状態 poll を貼らず、非関連として poll を省略すること。
    final ukraine = UniversalXShareService.buildGrowthDraft(
      page,
      trendTopics: const [
        UniversalXTrendTopic(name: 'Ukraine ceasefire talks'),
      ],
    );
    expect(ukraine.poll, isNull);

    // トレンドなしの日も投票なし。
    expect(UniversalXShareService.buildGrowthDraft(page).poll, isNull);
  });

  test('LLM draft without poll does not inherit the fallback poll', () async {
    final chat = AiHubChatService(
      invoker: (body) async => {
        'success': true,
        'provider': 'groq',
        'text': '''
{
  "text": "AI大学をアップデートしました。\\n${page.url}\\n#buildinpublic",
  "imagePrompt": "16:9 product UI share image",
  "videoPrompt": "short presenter video",
  "hashtags": ["#buildinpublic"],
  "threadReplies": ["解説その1です。", "解説その2です。"]
}
''',
      },
    );
    final service = UniversalXShareService(
      chatService: chat,
      functionInvoker: (functionName, body) async => {
        'success': true,
        if (body['action'] == 'x.trends')
          'trends': [
            {'name': '注目トレンド', 'tweet_count': 1000},
          ],
      },
    );
    final draft = await service.generateDraft(page);
    expect(draft.fallbackUsed, isFalse);
    // LLM が投票を出さなかったら、fallback のテンプレ投票を継承しない。
    expect(draft.poll, isNull);
  });

  test(
    'generateDraft retries once after a transient ai-hub failure',
    () async {
      var calls = 0;
      final tiers = <String?>[];
      final maxTokens = <Object?>[];
      final chat = AiHubChatService(
        invoker: (body) async {
          calls += 1;
          tiers.add(body['tier']?.toString());
          maxTokens.add(body['max_tokens']);
          if (calls == 1) {
            throw Exception('ai-hub 502');
          }
          return {
            'success': true,
            'provider': 'groq',
            'text': '''
{
  "text": "AI大学をアップデートしました。\\n${page.url}\\n#buildinpublic",
  "imagePrompt": "16:9 product UI share image",
  "videoPrompt": "short presenter video",
  "hashtags": ["#buildinpublic"]
}
''',
          };
        },
      );
      final service = UniversalXShareService(
        chatService: chat,
        functionInvoker: (functionName, body) async => {'success': true},
      );
      final draft = await service.generateDraft(page);
      expect(calls, 2);
      expect(draft.fallbackUsed, isFalse);
      // 収益直結呼び出しは budget ティア開始・リトライで performance へ昇格。
      expect(tiers, ['budget', 'performance']);
      // edge 既定の max_tokens=512 で長文 JSON が切断されないよう上限を明示。
      expect(maxTokens, [8192, 8192]);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('generateDraft prompt carries R12 coherence constraints', () async {
    // R12: 実投稿スレッド(Fable 5 を家計スレッドへ貼り付けた非関連フック +
    // 単一機能の反復 + 0票の抽象 poll)への対策が、LLM へ渡るプロンプトに
    // 実際に届くことを検証(実装非依存 = generateDraft の公開経路で送信 body を捕捉)。
    String? sentPrompt;
    final chat = AiHubChatService(
      invoker: (body) async {
        sentPrompt = body['message']?.toString();
        return {
          'success': true,
          'provider': 'groq',
          'text': '{"text": "x ${page.url}", "hashtags": ["#buildinpublic"]}',
        };
      },
    );
    final service = UniversalXShareService(
      chatService: chat,
      functionInvoker: (functionName, body) async => {'success': true},
    );
    await service.generateDraft(page);
    final prompt = sentPrompt ?? '';
    // 関連性ゲート(見出しが真につながる日のみフックにし、無関係語の貼付を禁止)。
    expect(prompt, contains('関連性ゲート'));
    expect(prompt, contains('無関係なトレンド語'));
    // 橋渡しの逆接テンプレ禁止(「◯◯が気になる方も多いですが」型)。
    expect(prompt, contains('橋渡しの禁止形'));
    // 機能カバレッジ配分(単一機能を 3 投稿以上の主眼にしない)。
    expect(prompt, contains('機能カバレッジ配分'));
    // poll 主題ロック + 抽象 stem 禁止。
    expect(prompt, contains('投票の主題は'));
    expect(prompt, contains('どの程度追ってますか'));
    // 真正性クレームモード(作り話の個人的実績を禁止)。
    expect(prompt, contains('検証可能な範囲'));
    expect(prompt, contains('家計が健全になりました'));
    // R13: media 軸。"Media lift" 行を authoritative 測定データとして扱い、勝ち
    // メディアへ最強フックを寄せるルールがプロンプトに届くこと。
    expect(prompt, contains('Media lift'));
    // R15: 言い換え回避への強化。文法テンプレート禁止・誇張副詞クラス禁止・
    // 一般名詞呼称の exact 禁止・poll 質問文の反復禁止・例文コピー禁止が届くこと。
    expect(prompt, contains('捏造実績の文法テンプレート'));
    expect(prompt, contains('格段に'));
    expect(prompt, contains('程度を誇張する副詞'));
    expect(prompt, contains('私のアプリでは'));
    expect(prompt, contains('question 文をそのまま繰り返すな'));
    // 矛盾 few-shot(禁止テンプレートを実演していた GOOD 例)が除去済みなこと。
    expect(prompt, isNot(contains('引き落としが浮いた')));
    // R22: R12 の禁止行書き換えで脱落していた「ぜひ試して」ban の復活を固定。
    expect(prompt, contains('ぜひ試して'));
  });

  test('buildXPostFailureMessage dedupes guidance embedded in the error', () {
    // 実障害(2026-07-08): edge が error にガイダンスを埋め込み + actionRequired
    // にも同文が返る → 連結で同じ段落が二重表示された。
    const guidance = 'X APIのクレジット不足/spend cap到達です。console.x.com で引き上げてください。';
    final message = UniversalXShareService.buildXPostFailureMessage({
      'error': 'X APIのクレジットが不足しています（spend cap reached）。 $guidance',
      'actionRequired': guidance,
    });
    expect(RegExp(RegExp.escape(guidance)).allMatches(message).length, 1);
    // 独立した error / actionRequired は両方描画される(no-op 保証)。
    final independent = UniversalXShareService.buildXPostFailureMessage({
      'error': 'X post failed with 500',
      'actionRequired': 'Check credentials.',
    });
    expect(independent, contains('X post failed with 500'));
    expect(independent, contains('Check credentials.'));
  });

  test('checkXPostPreflight parses blocked state and fails open', () async {
    final service = UniversalXShareService(
      chatService: AiHubChatService(invoker: (body) async => {'success': true}),
      functionInvoker: (functionName, body) async {
        expect(body['action'], 'x.post_preflight');
        return {'success': true, 'blocked': true, 'resetAt': '2026-07-10'};
      },
    );
    final result = await service.checkXPostPreflight();
    expect(result.blocked, isTrue);
    expect(result.resetAt, '2026-07-10');

    // preflight 自体の障害では本流を止めない(fail-open)。
    final failing = UniversalXShareService(
      chatService: AiHubChatService(invoker: (body) async => {'success': true}),
      functionInvoker: (functionName, body) async =>
          throw Exception('edge down'),
    );
    final open = await failing.checkXPostPreflight();
    expect(open.blocked, isFalse);
  });

  test(
    'generateDraft repairs LLM JSON with raw newlines inside strings',
    () async {
      // 実障害(2026-07-06): 文字列値内の生改行で decode 失敗→生 JSON がリード
      // 本文に漏出。修復パスで正しく decode され、日本語コピーが採用されること。
      final chat = AiHubChatService(
        invoker: (body) async => {
          'success': true,
          'provider': 'groq',
          // 文字列値の中に「生の改行」を含む不正 JSON(実事故と同形)。
          'text':
              '{\n  "text": "目が不自由な人の歩行をAIが音声で支援\nこれは新たな可能性です。\n${page.url}",\n  "imagePrompt": "16:9 image",\n  "videoPrompt": "video",\n  "hashtags": ["#buildinpublic"],\n  "threadReplies": ["解説その1です。"]\n}',
        },
      );
      final service = UniversalXShareService(
        chatService: chat,
        functionInvoker: (functionName, body) async => {'success': true},
      );
      final draft = await service.generateDraft(page);
      expect(draft.fallbackUsed, isFalse);
      expect(draft.text, contains('目が不自由な人の歩行'));
      expect(draft.text.trim(), isNot(startsWith('{')));
      expect(draft.threadReplies, contains('解説その1です。'));
    },
  );

  test(
    'generateDraft never posts a JSON dump and falls back after retries',
    () async {
      var calls = 0;
      final chat = AiHubChatService(
        invoker: (body) async {
          calls += 1;
          // 修復不能な壊れ JSON(未終端文字列)。生テキストは JSON ダンプの
          // 指紋(`{"` 開始)を持つため本文採用は禁止される。
          return {
            'success': true,
            'provider': 'groq',
            'text': '{ "text": "未終端の文字列 ${page.url}',
          };
        },
      );
      final service = UniversalXShareService(
        chatService: chat,
        functionInvoker: (functionName, body) async => {'success': true},
      );
      final draft = await service.generateDraft(page);
      // 両 attempt が不採用→retry 実行→真のフォールバックに着地する。
      expect(calls, 2);
      expect(draft.fallbackUsed, isTrue);
      expect(draft.text.trim(), isNot(startsWith('{')));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('share image rotates the scene setting for dramatic variation', () {
    final draft = UniversalXShareService.buildGrowthDraft(
      page,
      trendTopics: const [UniversalXTrendTopic(name: '熊本豪雨から6年')],
    );

    // 固定オフィスでなく「舞台のローテ」+「presenterキャラのローテ」が
    // 画像プロンプトに入っていること。
    expect(draft.imagePrompt, contains('in the setting of'));
    expect(draft.imagePrompt, contains('as the friendly presenter'));
    // 安全ガード: 未成年除外・非性的が入っていること。
    expect(draft.imagePrompt, contains('no minors'));
    expect(draft.imagePrompt, contains('no explicit sexualization'));
    final hasScene = <String>[
      'broadcast news desk',
      'glass studio',
      'evening study',
      'co-working space',
      'rooftop lounge',
      'control room',
    ].any(draft.imagePrompt.contains);
    expect(hasScene, isTrue);
  });

  test('presenter character rotates across a diverse adult pool', () {
    // 異なるニュース(=異なる draft.text)で presenter が変わり得ること、
    // かつ全て成人・ブランドセーフ指定であることを確認する。
    final seenCharacters = <String>{};
    for (final topic in const [
      '熊本豪雨から6年',
      'OpenAI 新モデル発表',
      'ワールドカップ開幕',
      '株価が最高値を更新',
      '大型連休の交通情報',
    ]) {
      final draft = UniversalXShareService.buildGrowthDraft(
        page,
        trendTopics: [UniversalXTrendTopic(name: topic)],
      );
      expect(draft.imagePrompt, contains('as the friendly presenter'));
      expect(draft.imagePrompt, contains('adult'));
      expect(draft.imagePrompt, isNot(contains('child')));
      // presenter フレーズ全体を distinct キーにする。ハンドメンテのキーワード
      // 部分集合(39 キャラ中 18 個)だと、未カバーのキャラばかり引いた日(seed 依存)に
      // undercount して落ちる。'... as the friendly presenter' の直前までを比較キーに。
      const marker = ' as the friendly presenter';
      final markerIndex = draft.imagePrompt.indexOf(marker);
      expect(markerIndex, greaterThan(0));
      seenCharacters.add(draft.imagePrompt.substring(0, markerIndex));
    }
    // 5トピックで少なくとも2種類以上の異なるキャラが登場すること。
    expect(seenCharacters.length, greaterThanOrEqualTo(2));
  });

  test('growth draft imagePrompt weaves today\'s date and trend headlines', () {
    final draft = UniversalXShareService.buildGrowthDraft(
      page,
      trendTopics: const [
        UniversalXTrendTopic(name: 'OpenAI 新モデル発表', tweetCount: 42000),
        UniversalXTrendTopic(name: 'ワールドカップ', tweetCount: 120000),
      ],
    );

    final now = DateTime.now().toUtc().add(const Duration(hours: 9));
    final date =
        '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';
    // 固定キービジュアルが毎回ほぼ同一で X アルゴリズムへ重複信号を送っていた
    // 問題(#3776)を解消 — 当日の日付と実ニュース見出しを画像テーマへ反映する。
    expect(draft.imagePrompt, contains('Daily edition $date'));
    expect(draft.imagePrompt, contains('OpenAI 新モデル発表'));
    // 見出しは視覚テーマへ反映するのみで、事実の捏造や画像内テキスト描画はしない。
    expect(draft.imagePrompt, contains('do not invent'));
    expect(draft.imagePrompt, contains('any on-image text'));
    // presenter はローテしつつ、ブランドセーフ指定は維持する。
    expect(draft.imagePrompt, contains('presenter'));
    expect(draft.imagePrompt, contains('no text overlays'));
  });

  test('growth draft imagePrompt still varies by date without trends', () {
    final draft = UniversalXShareService.buildGrowthDraft(page);

    final now = DateTime.now().toUtc().add(const Duration(hours: 9));
    final date =
        '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';
    // 見出しが無い日でも、日付だけで最低限の日替り変化を保証する。
    expect(draft.imagePrompt, contains('Daily edition $date'));
    expect(draft.imagePrompt, isNot(contains('today\'s news mood')));
  });

  test('fallback draft (no URL) weaves date and trend into imagePrompt', () {
    const emptyUrlPage = UniversalSharePageContext(
      routePath: '/gemini-university',
      title: 'Gemini University',
      url: '',
    );

    final draft = UniversalXShareService.buildFallbackDraft(
      emptyUrlPage,
      trendTopics: const [
        UniversalXTrendTopic(name: 'ITmedia 生成AI', tweetCount: 3000),
      ],
    );

    final now = DateTime.now().toUtc().add(const Duration(hours: 9));
    final date =
        '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';
    expect(draft.imagePrompt, contains('Daily edition $date'));
    expect(draft.imagePrompt, contains('ITmedia 生成AI'));
    expect(draft.imagePrompt, contains('product screenshot style hero image'));
  });

  test(
    'fallback draft (no URL, finance) weaves date into finance imagePrompt',
    () {
      const emptyUrlFinance = UniversalSharePageContext(
        routePath: '/asset-management',
        title: 'Asset Management',
        url: '',
      );

      final draft = UniversalXShareService.buildFallbackDraft(emptyUrlFinance);

      final now = DateTime.now().toUtc().add(const Duration(hours: 9));
      final date =
          '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';
      expect(draft.imagePrompt, contains('My Finance'));
      expect(draft.imagePrompt, contains('Daily edition $date'));
    },
  );

  test('acquisitionUrlFor preserves existing query and strips fragments', () {
    const pageWithQuery = UniversalSharePageContext(
      routePath: '/work-menu',
      title: 'Work Menu',
      url: 'https://my-web-app-b67f4.web.app/work-menu?tab=ai#ignored',
    );

    final url = UniversalXShareService.acquisitionUrlFor(
      pageWithQuery,
      content: 'Pinned Post',
    );

    expect(url, contains('tab=ai'));
    expect(url, contains('utm_source=x'));
    expect(url, contains('utm_campaign=first_user_growth'));
    expect(url, contains('utm_content=pinned_post'));
    expect(url, isNot(contains('#')));
  });

  test('profileAcquisitionUrlFor builds measurable X profile URL', () {
    const home = UniversalSharePageContext(
      routePath: '/',
      title: 'Home',
      url: 'https://my-web-app-b67f4.web.app/',
    );

    final url = UniversalXShareService.profileAcquisitionUrlFor(home);
    final uri = Uri.parse(url);

    expect(uri.queryParameters['utm_source'], 'x');
    expect(uri.queryParameters['utm_medium'], 'profile');
    expect(uri.queryParameters['utm_campaign'], 'first_user_growth');
    expect(uri.queryParameters['utm_content'], 'profile_bio');
  });

  test('generateDraft accepts JSON AI package', () async {
    String? capturedPrompt;
    final chat = AiHubChatService(
      invoker: (body) async {
        capturedPrompt = body['message']?.toString();
        return {
          'success': true,
          'provider': 'groq',
          'text': '''
{
  "text": "AI大学をアップデートしました。\\n${page.url}\\n#buildinpublic #FlutterWeb",
  "imagePrompt": "16:9 product UI share image for AI University",
  "videoPrompt": "short presenter video about AI University",
  "hashtags": ["#buildinpublic", "#FlutterWeb"]
}
''',
        };
      },
    );
    final service = UniversalXShareService(
      chatService: chat,
      functionInvoker: (functionName, body) async {
        if (body['action'] == 'x.performance_context') {
          return {
            'success': true,
            'promptContext':
                'Measured X performance context: best variant=daily_briefing, Winner 1 score=30000',
          };
        }
        if (body['action'] == 'x.trends') {
          return {'success': true, 'trends': []};
        }
        return {'success': true};
      },
    );

    final draft = await service.generateDraft(page);

    expect(draft.fallbackUsed, isFalse);
    expect(draft.text, contains(page.url));
    expect(draft.text, contains('utm_campaign=first_user_growth'));
    expect(draft.imagePrompt, contains('AI University'));
    expect(draft.hashtags, contains('#FlutterWeb'));
    expect(
      capturedPrompt,
      contains('Recent X analytics and A/B test feedback'),
    );
    expect(capturedPrompt, contains('best variant=daily_briefing'));
    expect(capturedPrompt, contains('utm_content=daily_briefing'));
  });

  test('draft prompt injects R11 anti-slop content constraints', () async {
    // R11 実測: 実投稿のリプが一般論の AI スロップ(「強力なツール」「可能性が
    // あります」「重要性を認識」)だった真因は、プロンプトが (a) 製品の具体事実を
    // 一切渡さず (b) 禁止フレーズ/一人称/具体性の負の制約を持たなかったこと。
    // ここではプロンプトにそれらが確実に注入されることを実装非依存で固定する。
    String? capturedPrompt;
    final chat = AiHubChatService(
      invoker: (body) async {
        capturedPrompt = body['message']?.toString();
        return {
          'success': true,
          'provider': 'groq',
          'text': '{"text": "x ${page.url}", "hashtags": ["#buildinpublic"]}',
        };
      },
    );
    final service = UniversalXShareService(
      chatService: chat,
      functionInvoker: (functionName, body) async => {'success': true},
    );

    await service.generateDraft(page);

    // (1) 実在する具体機能が名前付きで渡り、一般名詞禁止が明示される。
    expect(capturedPrompt, contains('App の実在する具体機能'));
    expect(capturedPrompt, contains('給料日サイクル'));
    expect(capturedPrompt, contains('負債トレンド'));
    // (2) 一人称オペレーター視点 + 三人称ブランド口調の禁止。
    expect(capturedPrompt, contains('一人称の実体験で書け'));
    expect(capturedPrompt, contains('私たちの新しいウェブアプリは'));
    // (3) 禁止フレーズ ブロックと具体性の下限。
    expect(capturedPrompt, contains('禁止フレーズ'));
    expect(capturedPrompt, contains('強力なツール'));
    expect(capturedPrompt, contains('具体性の下限'));
    // (4) BAD→GOOD few-shot 対比。
    expect(capturedPrompt, contains('BAD'));
    expect(capturedPrompt, contains('GOOD'));
    // (5) 保存版まとめの内省・抽象動詞禁止(理解する/認識する)。
    expect(capturedPrompt, contains('内省・抽象動詞'));
  });

  test('draft prompt injects R23 data-report archetype guidance', () async {
    // R23 実測(2026-07-12 同日3連投): 独自集計データのレポート型 3.2K vs
    // ニュース要約 517 vs ニュース→製品転換 28。教訓(共有定数)と、measured
    // "Archetype lift" / "Own measured data" 行の消費ルール+数字の出所3系統
    // 限定(捏造ガード)がプロンプトへ確実に注入されることを固定する。
    String? capturedPrompt;
    final chat = AiHubChatService(
      invoker: (body) async {
        capturedPrompt = body['message']?.toString();
        return {
          'success': true,
          'provider': 'groq',
          'text': '{"text": "x ${page.url}", "hashtags": ["#buildinpublic"]}',
        };
      },
    );
    final service = UniversalXShareService(
      chatService: chat,
      functionInvoker: (functionName, body) async => {'success': true},
    );

    await service.generateDraft(page);

    // (1) 実測教訓は共有定数(x_copy_guardrails)から丸ごと注入される。
    expect(capturedPrompt, contains(kDataReportArchetypeLesson));
    // (2) perf context の Archetype lift 行を測定事実として扱うルール。
    expect(capturedPrompt, contains('Archetype lift (by content archetype)'));
    // (3) データレポート型の数字は3系統限定(Own measured data を含む)。
    expect(capturedPrompt, contains('Own measured data'));
    expect(capturedPrompt, contains('それ以外の数字・集計値を作るな'));
  });

  group('R26 verified project stats context (data-report source (d))', () {
    const projectPage = UniversalSharePageContext(
      routePath: '/growth-command-center',
      title: 'Growth Command Center',
      url: 'https://my-web-app-b67f4.web.app/growth-command-center',
    );
    final fixture = <String, dynamic>{
      'success': true,
      'verified': true,
      'source': 'roadmap.share_stats',
      'userCount': 1234,
      'achievementsCount': 567,
      'plans': [
        {
          'label': 'vs Internal Competitor',
          'deadline': '2026年07月15日',
          'target': 9999,
          'features_done': 1,
          'features_total': 99,
        },
        {
          'label': '短期計画',
          'deadline': '2026年08月01日',
          'target': 100,
          'features_done': 12,
          'features_total': 20,
        },
      ],
    };
    final nowJst = DateTime(2026, 7, 12, 9, 30);

    test('buildProjectStatsContext formats real numbers with countdown', () {
      final block = UniversalXShareService.buildProjectStatsContext(
        fixture,
        nowJst: nowJst,
      );
      expect(block, contains('Own project data'));
      expect(block, contains('source=growth-hub roadmap.share_stats'));
      expect(block, contains('取得日時 2026-07-12 09:30 JST'));
      expect(block, contains('registered-accounts(total)=1234'));
      expect(block, contains('development-log-entries(total)=567'));
      expect(block, contains('development-log threshold 12/20, 閾値まで残り8件'));
      expect(block, contains('登録アカウント目標 100件'));
      expect(block, contains('目標達成 +1134件'));
      // 残日数は Dart 側で確定させる(2026-07-12 → 2026-08-01 = 20日)。
      expect(block, contains('あと20日'));
      expect(block, contains('🟡 Goal gap (短期計画)'));
      // 公開 allowlist 外の内部/競合計画を prompt へ出さない。
      expect(block, isNot(contains('Internal Competitor')));
    });

    test('degrades line by line when plan fields are missing', () {
      final block = UniversalXShareService.buildProjectStatsContext(
        {
          'verified': true,
          'source': 'roadmap.share_stats',
          'userCount': 1234,
          'achievementsCount': 567,
        },
        nowJst: nowJst,
      );
      expect(block, contains('registered-accounts(total)=1234'));
      expect(block, isNot(contains('Goal gap')));
    });

    test(
      'allowlists and orders short, medium, long plans deterministically',
      () {
        Map<String, dynamic> plan(String label) => {
              'label': label,
              'deadline': '2027年08月01日',
              'target': 2000,
              'features_done': 1,
              'features_total': 2,
            };
        final block = UniversalXShareService.buildProjectStatsContext(
          {
            'verified': true,
            'source': 'roadmap.share_stats',
            'userCount': 1234,
            'achievementsCount': 567,
            'plans': [
              plan('長期計画'),
              plan('vs Internal Competitor'),
              plan('短期計画'),
              plan('中期計画'),
            ],
          },
          nowJst: nowJst,
        );
        final shortIndex = block.indexOf('Goal gap (短期計画)');
        final mediumIndex = block.indexOf('Goal gap (中期計画)');
        final longIndex = block.indexOf('Goal gap (長期計画)');
        expect(shortIndex, greaterThanOrEqualTo(0));
        expect(mediumIndex, greaterThan(shortIndex));
        expect(longIndex, greaterThan(mediumIndex));
        expect(block, isNot(contains('Internal Competitor')));
      },
    );

    test('rejects unverified responses and fewer than 2 real numbers', () {
      expect(
        UniversalXShareService.buildProjectStatsContext(
          {
            'userCount': 3,
            'achievementsCount': 4,
          },
          nowJst: nowJst,
        ),
        isEmpty,
      );
      expect(
        UniversalXShareService.buildProjectStatsContext(
          {
            'verified': true,
            'source': 'roadmap.share_stats',
            'userCount': 3,
          },
          nowJst: nowJst,
        ),
        isEmpty,
      );
      expect(
        UniversalXShareService.buildProjectStatsContext(
          const {
            'verified': true,
            'source': 'roadmap.share_stats',
          },
          nowJst: nowJst,
        ),
        isEmpty,
      );
    });

    test('marks overdue gaps as red and never publishes fake あと0日', () {
      final block = UniversalXShareService.buildProjectStatsContext(
        {
          'verified': true,
          'source': 'roadmap.share_stats',
          'userCount': 10,
          'achievementsCount': 20,
          'plans': [
            {
              'label': '短期計画',
              'deadline': '2026年07月01日',
              'target': 100,
              'features_done': 1,
              'features_total': 2,
            },
          ],
        },
        nowJst: nowJst,
      );
      expect(block, contains('終了・更新必要'));
      expect(block, contains('🔴 Goal gap (短期計画)'));
      expect(block, contains('登録アカウント目標 100件'));
      expect(block, contains('目標まで残り90件'));
      expect(block, isNot(contains('あと0日')));
      expect(block, isNot(contains('あと-')));
    });

    test('stats block and a sample digest lead stay slop-clean (R22)', () {
      final block = UniversalXShareService.buildProjectStatsContext(
        fixture,
        nowJst: nowJst,
      );
      expect(detectSlop('', block), isEmpty);
      // 97K 実測ポスト構造(集計ヘッダ+🔴🟡アラート+内訳短行)のサンプルリードも
      // R22 の禁止トークン警告を踏まないこと(数字密度はスロップではない)。
      const sampleDigestLead = '自分株式会社 開発集計 開発ログ567件 (2026/07/12時点)\n'
          '取得日時 2026-07-12 09:30 JST\n'
          '登録アカウント 1234件\n'
          '短期計画: 開発ログ閾値12/20、残り8件、期日まであと20日\n'
          '🔴 未着手 2件\n'
          '🟡 要注意 3件\n'
          'https://example.com/app';
      expect(detectSlop(sampleDigestLead, ''), isEmpty);
    });

    test('draft prompt wires the block and the (d) number source', () async {
      String? capturedPrompt;
      final chat = AiHubChatService(
        invoker: (body) async {
          capturedPrompt = body['message']?.toString();
          return {
            'success': true,
            'provider': 'groq',
            'text':
                '{"text": "x ${projectPage.url}", "hashtags": ["#buildinpublic"]}',
          };
        },
      );
      final service = UniversalXShareService(
        chatService: chat,
        functionInvoker: (functionName, body) async {
          if (body['action'] == 'roadmap.share_stats') {
            return {'success': true, ...fixture};
          }
          return {'success': true};
        },
      );

      await service.generateDraft(projectPage);

      final prompt = capturedPrompt ?? '';
      expect(prompt, contains('registered-accounts(total)=1234'));
      expect(prompt, contains('"Own project data"'));
      // 例外ルールはすべて「データレポート型の日のみ」に条件付けされている
      // (鮮度例外も含む=ゲート無し「例外:」への回帰を検出する)。
      expect(prompt, contains('例外(データレポート型の日のみ)'));
      expect(prompt, contains('例外(データレポート型の日のみ): 同名シリーズ'));
      // 数字源(d)は "Own project data" ブロックの実数に限定列挙で束縛される。
      expect(
        prompt,
        contains('(d)上の "Own project data" ブロックに実際に書かれている実数'),
      );
      // 骨格の取得日時/差分/アラート要素はブロックがある日だけ許可される
      // ((d) DISABLED 日に必須要素が埋められない矛盾=捏造圧力の回帰を検出)。
      expect(prompt, contains('ブロックが DISABLED の日はこれらの要素を省き'));
      // 97K 実測ポストの骨格(集計ヘッダ/取得日時/アラート)が指示に含まれる。
      expect(prompt, contains('集計ヘッダ'));
      expect(prompt, contains('取得日時'));
      expect(prompt, contains('デイリーブリーフィング」をシリーズ名に使うな'));
      // 既存ピン(R23)の非回帰。
      expect(prompt, contains(kDataReportArchetypeLesson));
      expect(prompt, contains('それ以外の数字・集計値を作るな'));
      expect(prompt, contains('900-1500 chars'));
      expect(prompt, contains('STRATEGY EVIDENCE ONLY'));
      expect(prompt, contains('roadmap.share_stats'));
    });

    test(
      'prompt disables source (d) when project stats are unavailable',
      () async {
        String? capturedPrompt;
        final chat = AiHubChatService(
          invoker: (body) async {
            capturedPrompt = body['message']?.toString();
            return {
              'success': true,
              'provider': 'groq',
              'text':
                  '{"text": "x ${projectPage.url}", "hashtags": ["#buildinpublic"]}',
            };
          },
        );
        final service = UniversalXShareService(
          chatService: chat,
          functionInvoker: (functionName, body) async {
            if (body['action'] == 'roadmap.share_stats') {
              throw Exception('unauthenticated');
            }
            return {'success': true};
          },
        );

        final draft = await service.generateDraft(projectPage);

        // 実データ取得の失敗は下書き生成を止めない(fail-open)。
        expect(draft.fallbackUsed, isFalse);
        expect(capturedPrompt, contains('Number source (d) below is DISABLED'));
      },
    );

    test('does not fetch global project stats for an unrelated page', () async {
      var projectStatsCalls = 0;
      String? capturedPrompt;
      final chat = AiHubChatService(
        invoker: (body) async {
          capturedPrompt = body['message']?.toString();
          return {
            'success': true,
            'provider': 'groq',
            'text': '{"text": "x ${page.url}", "hashtags": ["#buildinpublic"]}',
          };
        },
      );
      final service = UniversalXShareService(
        chatService: chat,
        functionInvoker: (functionName, body) async {
          if (body['action'] == 'roadmap.share_stats') projectStatsCalls += 1;
          return {'success': true, ...fixture};
        },
      );

      await service.generateDraft(page);

      expect(UniversalXShareService.supportsProjectStatsContext(page), isFalse);
      expect(projectStatsCalls, 0);
      expect(capturedPrompt, contains('Number source (d) below is DISABLED'));
    });

    test('accepts a long data-report lead within the raised cap', () async {
      // データレポート型の内訳込みリード(プロンプト上限 1500 字 + 2 倍の
      // ヘッドルーム=3000)が JSON ダンプ扱いで捨てられないこと。
      final longLead =
          '開発集計 567件 (2026/07/12時点)\\n${'内訳の行です。' * 300}\\n${page.url}';
      final chat = AiHubChatService(
        invoker: (body) async => {
          'success': true,
          'provider': 'groq',
          'text': '{"text": "$longLead", "hashtags": ["#buildinpublic"]}',
        },
      );
      final service = UniversalXShareService(
        chatService: chat,
        functionInvoker: (functionName, body) async => {'success': true},
      );
      final draft = await service.generateDraft(page);
      expect(draft.fallbackUsed, isFalse);
      expect(draft.text.length, greaterThan(2000));
    });
  });

  test('generateDraft recovers a poll leaked inside threadReplies', () async {
    // 実障害: LLM が poll をトップレベルでなく threadReplies の要素(オブジェクト)
    // に入れ、Map.toString() の生テキスト `{text: , poll: {...}}` がそのまま
    // リプ投稿された。オブジェクトは文字列化せず、poll は回収して native 投票を
    // 復元し、text は非空文字列のときだけ採用する。
    final chat = AiHubChatService(
      invoker: (body) async => {
        'success': true,
        'provider': 'groq',
        'text': '''
{
  "text": "AI大学をアップデートしました。\\n${page.url}\\n#buildinpublic",
  "imagePrompt": "16:9 product UI share image",
  "videoPrompt": "short presenter video",
  "hashtags": ["#buildinpublic"],
  "threadReplies": [
    {"text": "", "poll": {"question": "AI導入、どこに壁を感じますか？", "options": ["開発の複雑性", "データの整理", "人材不足", "期待値ギャップ"], "durationMinutes": 1440}},
    "現状の解説です。なぜ重要か: 明日の判断材料になるからです。",
    "背景の解説です。"
  ]
}
''',
      },
    );
    final service = UniversalXShareService(
      chatService: chat,
      functionInvoker: (functionName, body) async => {'success': true},
    );

    final draft = await service.generateDraft(page);

    expect(draft.fallbackUsed, isFalse);
    // 生オブジェクトのテキスト漏出が一切ないこと。
    for (final reply in draft.threadReplies) {
      expect(reply, isNot(contains('{text')));
      expect(reply, isNot(contains('durationMinutes')));
    }
    expect(draft.threadReplies.length, 2);
    // 迷い込んだ poll をトップレベル poll として回収できていること。
    expect(draft.poll, isNotNull);
    expect(draft.poll!.question, 'AI導入、どこに壁を感じますか？');
    expect(draft.poll!.options.length, 4);
  });

  test('generateDraft drops non-string junk threadReplies entries', () async {
    final chat = AiHubChatService(
      invoker: (body) async => {
        'success': true,
        'provider': 'groq',
        'text': '''
{
  "text": "AI大学をアップデートしました。\\n${page.url}\\n#buildinpublic",
  "imagePrompt": "16:9 product UI share image",
  "videoPrompt": "short presenter video",
  "hashtags": ["#buildinpublic"],
  "threadReplies": [123, ["a", "b"], {"foo": "bar"}]
}
''',
      },
    );
    final service = UniversalXShareService(
      chatService: chat,
      functionInvoker: (functionName, body) async => {'success': true},
    );

    final draft = await service.generateDraft(page);

    // 文字列以外は全て破棄され(空なら fallback リプへ)、生テキスト漏出がない。
    for (final reply in draft.threadReplies) {
      expect(reply, isNot(contains('foo')));
      expect(reply, isNot(contains('[a')));
      expect(reply, isNot(contains('123')));
    }
  });

  test(
    'buildManualShareParts keeps the product URL only on the final reply',
    () {
      // LLM が自リプへ製品 URL を含めると OG カードが複数リプで重複表示される
      // (実機で同一カードが2連続)。linkInReply ではリプ本文から URL を剥がし、
      // URL は最終 CTA リプライだけに載せる。
      final parts = UniversalXShareService.buildManualShareParts(
        context: page,
        text: 'リード本文\n${page.url}',
        threadReplies: <String>['ポイント解説です。', '締めです。詳しくは ${page.url} を見てください。'],
        linkInReply: true,
      );

      expect(parts.replyTexts.length, 3);
      // 中間リプに URL が残らない(重複 OG カード防止)。
      expect(parts.replyTexts[0], isNot(contains('my-web-app')));
      expect(parts.replyTexts[1], isNot(contains('my-web-app')));
      // URL は最終 CTA リプライのみ。
      expect(parts.replyTexts.last, contains(parts.textUrl));
    },
  );

  test('assembleReplyTexts keeps the URL CTA when poll+replies exceed 8', () {
    // growth-hub は replyTexts を slice(0,8) で切る。poll 質問(+1)と最終
    // CTA(+1)で 8 を超えると、素通しではサーバ側で CTA(唯一の商品 URL)が
    // 黙って落ちる。溢れは CTA 直前の分析リプから落とし CTA を必ず残す。
    final analysis = List<String>.generate(8, (i) => '分析リプライ${i + 1}です。');
    final partsReplies = <String>[...analysis, 'CTAです。\nhttps://example.com/x'];

    final capped = UniversalXShareService.assembleReplyTexts(
      partsReplyTexts: partsReplies,
      pollQuestion: 'どこに壁を感じますか？',
      hasPoll: true,
      linkInReply: true,
    );

    expect(capped.length, 8);
    expect(capped.first, 'どこに壁を感じますか？');
    expect(capped.last, contains('https://example.com/x'));

    // 8 件以下は従来と同一のパススルー。
    final passthrough = UniversalXShareService.assembleReplyTexts(
      partsReplyTexts: const ['a', 'b'],
      pollQuestion: '',
      hasPoll: false,
      linkInReply: true,
    );
    expect(passthrough, const ['a', 'b']);
  });

  test('generateDraft drops double-encoded JSON string replies', () async {
    final chat = AiHubChatService(
      invoker: (body) async => {
        'success': true,
        'provider': 'groq',
        'text': '''
{
  "text": "AI大学をアップデートしました。\\n${page.url}\\n#buildinpublic",
  "imagePrompt": "16:9 product UI share image",
  "videoPrompt": "short presenter video",
  "hashtags": ["#buildinpublic"],
  "threadReplies": [
    "{\\"text\\": \\"\\", \\"poll\\": {\\"question\\": \\"Q\\"}}",
    "手順は {設定→実行→確認} の3段階で進めると迷いません。"
  ]
}
''',
      },
    );
    final service = UniversalXShareService(
      chatService: chat,
      functionInvoker: (functionName, body) async => {'success': true},
    );

    final draft = await service.generateDraft(page);

    // オブジェクトリテラル全体の文字列は捨てるが、括弧を含む日本語散文は残す。
    expect(draft.threadReplies.length, 1);
    expect(draft.threadReplies.first, contains('3段階'));
  });

  test('postToX forwards optional media URL to growth-hub', () async {
    Map<String, dynamic>? capturedBody;
    String? capturedFunction;
    final service = UniversalXShareService(
      functionInvoker: (functionName, body) async {
        capturedFunction = functionName;
        capturedBody = body;
        return {
          'success': true,
          'posted': true,
          'account': '@kanta13jp1',
          'tweetId': '456',
        };
      },
    );

    final result = await service.postToX(
      context: page,
      text: 'テスト投稿\n${page.url}',
      mediaUrl: 'https://example.com/share.png',
    );

    expect(result.posted, isTrue);
    expect(result.tweetId, '456');
    expect(capturedFunction, 'growth-hub');
    expect(capturedBody?['action'], 'x.post');
    expect(capturedBody?['mediaUrl'], 'https://example.com/share.png');
    expect(capturedBody?['experimentKey'], 'x_first_user_growth_10k');
    expect(capturedBody?['variant'], 'post_to_x');
    expect(capturedBody?['promptProfile'], 'performance_context_v1');
    expect(capturedBody?['contentKind'], 'media');
    // 投票なしの既定経路には poll キーを一切足さない(default-off)。
    expect(capturedBody?.containsKey('poll'), isFalse);
  });

  test(
    'postToX stays poll-free (byte-identical) when no poll is given',
    () async {
      Map<String, dynamic>? capturedBody;
      final service = UniversalXShareService(
        functionInvoker: (functionName, body) async {
          capturedBody = body;
          return {'success': true, 'posted': true};
        },
      );

      await service.postToX(
        context: page,
        text: 'リード投稿\n${page.url}',
        threadReplies: const ['1. 【AI】本文\nなぜ重要か: 変わる。'],
        linkInReply: true,
      );

      expect(capturedBody?.containsKey('poll'), isFalse);
      final replies = capturedBody?['replyTexts'] as List;
      // 先頭は投票質問ではなく従来どおりスレッド本文で始まる。
      expect(replies.first.toString(), contains('本文'));
    },
  );

  test('postToX attaches a native poll to a prepended first reply', () async {
    Map<String, dynamic>? capturedBody;
    final service = UniversalXShareService(
      functionInvoker: (functionName, body) async {
        capturedBody = body;
        return {'success': true, 'posted': true, 'tweetId': '1'};
      },
    );

    await service.postToX(
      context: page,
      text: 'リード投稿\n${page.url}',
      threadReplies: const ['1. 【AI】本文\nなぜ重要か: 変わる。'],
      linkInReply: true,
      poll: const UniversalXPoll(
        question: 'あなたはどっち派?',
        options: ['きのこ', 'たけのこ'],
        durationMinutes: 1440,
      ),
    );

    final poll = capturedBody?['poll'] as Map<String, dynamic>;
    expect(poll['options'], ['きのこ', 'たけのこ']);
    expect(poll['durationMinutes'], 1440);
    final replies = capturedBody?['replyTexts'] as List;
    // 投票質問がスレッド先頭リプライとして前置される(edge がここへ poll を添付)。
    expect(replies.first.toString(), contains('どっち'));
    expect(replies[1].toString(), contains('本文'));
  });

  test('postToX drops a poll with fewer than 2 usable options', () async {
    Map<String, dynamic>? capturedBody;
    final service = UniversalXShareService(
      functionInvoker: (functionName, body) async {
        capturedBody = body;
        return {'success': true, 'posted': true};
      },
    );

    await service.postToX(
      context: page,
      text: 'リード投稿\n${page.url}',
      threadReplies: const ['1. 本文だけ'],
      poll: const UniversalXPoll(
        question: '選べる?',
        options: ['ひとつだけ', '  ', 'ひとつだけ'],
        durationMinutes: 1440,
      ),
    );

    // 実質 1 択(空白除去+重複排除後)なので投票は付かず本文が先頭のまま。
    expect(capturedBody?.containsKey('poll'), isFalse);
    final replies = capturedBody?['replyTexts'] as List;
    expect(replies.first.toString(), contains('本文だけ'));
  });

  test('postToX adds X acquisition URL when text has no URL', () async {
    Map<String, dynamic>? capturedBody;
    final service = UniversalXShareService(
      functionInvoker: (functionName, body) async {
        capturedBody = body;
        return {'success': true, 'posted': true};
      },
    );

    await service.postToX(context: page, text: 'First user feedback wanted');

    final text = capturedBody?['text']?.toString() ?? '';
    expect(text, contains(page.url));
    expect(text, contains('utm_campaign=first_user_growth'));
    expect(text, contains('utm_content=post_to_x'));
  });

  test(
    'postToX keeps the URL in the lead when linkInReply is off with a thread',
    () async {
      // R24: AIシェアの既定。従来は linkInReply=true をハードコードしていたが、
      // 実測 (2026-04-27〜07-25 / 350投稿) では URL クリックの 94% がリードに
      // URL を持つ投稿から出ており、リプライ側 CTA は 30 imp に留まった。
      // スレッド返信が「ある」場合でもリードに URL が残ることを固定する。
      Map<String, dynamic>? capturedBody;
      final service = UniversalXShareService(
        functionInvoker: (functionName, body) async {
          capturedBody = body;
          return {
            'success': true,
            'posted': true,
            'tweetId': '100',
            'replyTweetIds': ['101'],
          };
        },
      );

      await service.postToX(
        context: page,
        text: 'デイリーブリーフィング\n${page.url}',
        threadReplies: const ['1. 【AI】OpenAI\nなぜ重要か: 仕事の入口が変わる。'],
      );

      final text = capturedBody?['text']?.toString() ?? '';
      final replies = capturedBody?['replyTexts'] as List;
      expect(text, contains(page.url));
      expect(capturedBody?['linkInReply'], isFalse);
      // 本文にURLがあるので、URL入りの CTA リプライは足さない。
      expect(replies.length, 1);
      expect(replies.single.toString(), contains('OpenAI'));
      expect(replies.single.toString(), isNot(contains(page.url)));
    },
  );

  test('postToX can move the link to a reply thread', () async {
    Map<String, dynamic>? capturedBody;
    final service = UniversalXShareService(
      functionInvoker: (functionName, body) async {
        capturedBody = body;
        return {
          'success': true,
          'posted': true,
          'tweetId': '100',
          'replyTweetIds': ['101', '102'],
        };
      },
    );

    final result = await service.postToX(
      context: page,
      text: 'デイリーブリーフィング\n${page.url}',
      threadReplies: const ['1. 【AI】OpenAI\nなぜ重要か: 仕事の入口が変わる。'],
      linkInReply: true,
    );

    final text = capturedBody?['text']?.toString() ?? '';
    final replies = capturedBody?['replyTexts'] as List;
    expect(text, isNot(contains(page.url)));
    expect(replies.first.toString(), contains('OpenAI'));
    expect(replies.last.toString(), contains(page.url));
    expect(result.replyTweetIds, ['101', '102']);
  });

  test('buildManualShareParts moves the URL out of the lead into a reply', () {
    final parts = UniversalXShareService.buildManualShareParts(
      context: page,
      text: 'デイリーブリーフィング\n今日の注目:「テスト見出し」\n${page.url}',
      threadReplies: const ['1. 【AI】OpenAI\nなぜ重要か: 仕事の入口が変わる。'],
      linkInReply: true,
    );

    // Manual share (copy / X composer) must keep the product URL out of the
    // lead post — same contract as postToX's linkInReply path.
    expect(parts.leadText, isNot(contains(page.url)));
    expect(parts.leadText, contains('今日の注目'));
    expect(parts.replyTexts.first, contains('OpenAI'));
    expect(parts.replyTexts.last, contains(page.url));
  });

  test(
    'buildManualShareParts keeps the URL inline when not linking in reply',
    () {
      final parts = UniversalXShareService.buildManualShareParts(
        context: page,
        text: 'ふつうの投稿\n${page.url}',
      );

      expect(parts.leadText, contains(page.url));
      expect(parts.replyTexts, isEmpty);
    },
  );

  test(
    'final-reply CTA rotates across posts to avoid duplicate suppression',
    () {
      final seenCtas = <String>{};
      for (final body in const ['a', 'bb', 'ccc', 'dddd', 'eeeee', 'ffffff']) {
        final parts = UniversalXShareService.buildManualShareParts(
          context: page,
          text: '$body\n${page.url}',
          linkInReply: true,
        );
        final cta = parts.replyTexts.last;
        // URL は最終リプライに載る(リードには載らない)。
        expect(cta, contains(parts.textUrl));
        seenCtas.add(cta.split('\n').first);
      }
      // 固定文の近似重複でなく、プールから複数バリアントが出る。
      expect(seenCtas.length, greaterThanOrEqualTo(2));
    },
  );

  test('final-reply CTA pool includes a save/bookmark cue', () {
    // ブックマーク(保存)は 2026 のリーチ品質シグナル。ローテプールに保存促しの
    // バリアントが含まれ、複数入力のいずれかで最終リプに現れることを確認する。
    var sawSaveCue = false;
    for (var i = 0; i < 40; i += 1) {
      final parts = UniversalXShareService.buildManualShareParts(
        context: page,
        text: 'body$i\n${page.url}',
        linkInReply: true,
      );
      if (parts.replyTexts.last.contains('保存')) {
        sawSaveCue = true;
        break;
      }
    }
    expect(sawSaveCue, isTrue);
  });

  test('final-reply CTA pool includes a follow-conversion cue', () {
    // フォロワー変換レバー: ローテプールにフォロー誘導バリアントが含まれ、
    // 複数入力のいずれかで最終リプに現れることを確認する。
    var sawFollowCue = false;
    for (var i = 0; i < 60; i += 1) {
      final parts = UniversalXShareService.buildManualShareParts(
        context: page,
        text: 'follow$i\n${page.url}',
        linkInReply: true,
      );
      final cta = parts.replyTexts.last;
      if (cta.contains('フォロー') || cta.contains('プロフィール')) {
        sawFollowCue = true;
        break;
      }
    }
    expect(sawFollowCue, isTrue);
  });

  test('postToX surfaces X developer project guidance', () async {
    final service = UniversalXShareService(
      functionInvoker: (functionName, body) async {
        return {
          'success': false,
          'posted': false,
          'error': 'X API app is not enrolled for v2 posting.',
          'code': 'x_client_not_enrolled',
          'actionRequired': 'Attach the App to an X Developer Project.',
          'registrationUrl': 'https://developer.x.com/en/portal/projects',
        };
      },
    );

    expect(
      () => service.postToX(context: page, text: '繝・せ繝域兜遞ｿ\n${page.url}'),
      throwsA(
        isA<Exception>()
            .having(
              (error) => error.toString(),
              'message',
              contains('Attach the App to an X Developer Project.'),
            )
            .having(
              (error) => error.toString(),
              'registration url',
              contains('https://developer.x.com/en/portal/projects'),
            ),
      ),
    );
  });

  test('postToX omits embedded data URL media', () async {
    Map<String, dynamic>? capturedBody;
    final service = UniversalXShareService(
      functionInvoker: (functionName, body) async {
        capturedBody = body;
        return {'success': true, 'posted': true};
      },
    );

    await service.postToX(
      context: page,
      text: 'Share text ${page.url}',
      mediaUrl: 'data:image/png;base64,${'a' * 3000}',
    );

    expect(capturedBody?['mediaUrl'], isNull);
  });

  test(
    'generateImage keeps text-only sharing available on provider failure',
    () async {
      String? capturedFunction;
      Map<String, dynamic>? capturedBody;
      final service = UniversalXShareService(
        functionInvoker: (functionName, body) async {
          capturedFunction = functionName;
          capturedBody = body;
          return {
            'success': false,
            'status': 'text_only_fallback',
            'canPostTextOnly': true,
            'errors': [
              {
                'model': 'gpt-image-1.5',
                'status': 400,
                'error': 'Billing hard limit has been reached.',
              },
            ],
          };
        },
      );

      final draft = UniversalXShareService.buildFallbackDraft(page);
      final result = await service.generateImage(context: page, draft: draft);

      expect(capturedFunction, 'media-hub');
      expect(capturedBody?['prompt'], contains('as the presenter'));
      // presenter はローテするが、未成年除外・非性的の安全ガードは全画像で必須。
      expect(capturedBody?['prompt'], contains('minors'));
      expect(capturedBody?['prompt'], contains('explicit sexualization'));
      expect(result.url, isNull);
      expect(result.status, 'text_only_fallback');
      expect(result.raw['canPostTextOnly'], isTrue);
    },
  );

  test(
    'generateVideo uses My Finance mobile UX template for finance pages',
    () async {
      Map<String, dynamic>? capturedBody;
      String? capturedFunction;
      final service = UniversalXShareService(
        functionInvoker: (functionName, body) async {
          capturedFunction = functionName;
          capturedBody = body;
          return {'success': true, 'status': 'fallback_text'};
        },
      );
      const financePage = UniversalSharePageContext(
        routePath: '/asset-management',
        title: 'Asset Management',
        url: 'https://my-web-app-b67f4.web.app/asset-management',
      );
      final draft = UniversalXShareService.buildFallbackDraft(financePage);

      await service.generateVideo(
        context: financePage,
        draft: draft,
        imageUrl: 'https://example.com/share.png',
      );

      expect(capturedFunction, 'viral-video-ad-generator');
      expect(capturedBody?['template'], 'mobile_ux_validation');
      expect(capturedBody?['title'], 'My Finance');
      expect(capturedBody?['voice'], 'ja-JP');
      expect(capturedBody?['preferredModel'], 'hedra');
      expect(capturedBody?['imageUrl'], 'https://example.com/share.png');
      expect(capturedBody?['creativePipeline'], const [
        'gpt-5.5',
        'gpt-image',
        'elevenlabs',
        'hedra',
      ]);
      expect(
        capturedBody?['customPrompt'],
        contains('Moving smartphone app UX validation video'),
      );
    },
  );

  test(
    'generateVideo uses high-quality AI secretary site tour for general pages',
    () async {
      Map<String, dynamic>? capturedBody;
      final service = UniversalXShareService(
        functionInvoker: (functionName, body) async {
          capturedBody = body;
          return {'success': true, 'status': 'fallback_text'};
        },
      );

      final draft = UniversalXShareService.buildGrowthDraft(page);
      await service.generateVideo(
        context: page,
        draft: draft,
        imageUrl: 'https://example.com/secretary.png',
      );

      expect(capturedBody?['template'], 'ai_secretary_site_tour');
      // 声はキャラの性別/トーンに合わせたラベル(6 種のいずれか)を送る。
      expect(capturedBody?['voice'], isIn(_kVoiceLabels));
      expect(capturedBody?['preferredModel'], 'hedra');
      expect(capturedBody?['creativePipeline'], const [
        'gpt-5.5',
        'gpt-image',
        'elevenlabs',
        'hedra',
      ]);
      // presenter は日替りローテ、声はそれに合わせた日本語ボイス。
      expect(capturedBody?['customPrompt'], contains('Presenter for today'));
      expect(capturedBody?['customPrompt'], contains('Japanese voice'));
      expect(capturedBody?['customPrompt'], contains('ElevenLabs'));
      expect(capturedBody?['customPrompt'], contains('Hedra'));
      // シーン/照明/カメラが日替りで変わる指示が入っていること。
      expect(capturedBody?['customPrompt'], contains('Setting for today'));
      // 安全ガード(未成年除外)が動画プロンプトにも入っていること。
      expect(capturedBody?['customPrompt'], contains('no minors'));
      final scriptLines = capturedBody?['customScript'] as List;
      final script = scriptLines.join('\n');
      // 動画スクリプトは固定ツアー定型文ではなく、日替りローテの導入 +
      // ニュース由来のブリーフィング本文 + ローテのCTA で毎回変化する。
      expect(script, isNot(contains('AI大学では主要AI企業'))); // 旧固定ツアー非含有
      expect(scriptLines.length, greaterThanOrEqualTo(3));
      expect(scriptLines.first, isNotEmpty); // 導入がある
      expect(script, isNot(contains('https://')));
      expect(script, isNot(contains(page.url)));
    },
  );

  test(
    'video narration reflects today news and drops the fixed tour',
    () async {
      Map<String, dynamic>? capturedBody;
      final service = UniversalXShareService(
        functionInvoker: (functionName, body) async {
          capturedBody = body;
          return {'success': true, 'status': 'fallback_text'};
        },
      );

      final draft = UniversalXShareService.buildGrowthDraft(
        page,
        trendTopics: const [
          UniversalXTrendTopic(name: '九州北部で非常に激しい雨'),
          UniversalXTrendTopic(name: 'OpenAIが新モデルを発表'),
        ],
      );
      await service.generateVideo(
        context: page,
        draft: draft,
        imageUrl: 'https://example.com/secretary.png',
      );

      final scriptLines =
          (capturedBody?['customScript'] as List).cast<String>();
      final script = scriptLines.join('\n');
      // 当日ニュース(トレンド)が動画ナレーションに載ること。
      expect(script, contains('九州北部で非常に激しい雨'));
      // 固定のツアー定型文ではないこと。
      expect(script, isNot(contains('AI大学では主要AI企業')));
      expect(scriptLines.length, greaterThanOrEqualTo(3));
      expect(script, isNot(contains('https://')));
    },
  );

  test(
    'generateVideo can poll an existing Hedra generation and use download URL',
    () async {
      Map<String, dynamic>? capturedBody;
      final service = UniversalXShareService(
        functionInvoker: (functionName, body) async {
          capturedBody = body;
          return {
            'success': true,
            'videoStatus': 'complete',
            'generatedDownloadUrl': 'https://example.com/video.mp4',
          };
        },
      );

      final draft = UniversalXShareService.buildFallbackDraft(page);
      final result = await service.generateVideo(
        context: page,
        draft: draft,
        hedraGenerationId: '123e4567-e89b-12d3-a456-426614174000',
      );

      expect(result.url, 'https://example.com/video.mp4');
      expect(result.status, 'complete');
      expect(
        capturedBody?['hedraGenerationId'],
        '123e4567-e89b-12d3-a456-426614174000',
      );
    },
  );

  test(
    'generateVideo with cinematic engine requests fal.ai text-to-video',
    () async {
      Map<String, dynamic>? capturedBody;
      String? capturedFunction;
      final service = UniversalXShareService(
        functionInvoker: (functionName, body) async {
          capturedFunction = functionName;
          capturedBody = body;
          return {
            'success': true,
            'videoStatus': 'processing',
            'falRequestId': 'req-123',
          };
        },
      );

      final draft = UniversalXShareService.buildGrowthDraft(page);
      final result = await service.generateVideo(
        context: page,
        draft: draft,
        imageUrl: 'https://example.com/share.png',
        engine: AiShareVideoEngine.cinematic,
      );

      expect(capturedFunction, 'viral-video-ad-generator');
      expect(capturedBody?['type'], 'cinematic_video');
      expect(capturedBody?['preferredModel'], 'fal-text-to-video');
      expect(capturedBody?['creativePipeline'], const [
        'gpt-5.5',
        'fal-text-to-video',
      ]);
      // text-to-video は顔画像を使わないので Hedra 用開始画像を送らない。
      expect(capturedBody?.containsKey('imageUrl'), isFalse);
      // 固定アートディレクションで見た目の一貫性を担保する。
      expect(capturedBody?['customPrompt'], contains('paper-craft'));
      expect(capturedBody?['customPrompt'], contains('16:9'));
      // 初回はポーリング ID を送らず、応答から falRequestId を取得できる。
      expect(capturedBody?.containsKey('falRequestId'), isFalse);
      expect(result.url, isNull);
      expect(result.status, 'processing');
      expect(result.raw['falRequestId'], 'req-123');
    },
  );

  test(
    'generateVideo cinematic engine can poll an existing fal request',
    () async {
      Map<String, dynamic>? capturedBody;
      final service = UniversalXShareService(
        functionInvoker: (functionName, body) async {
          capturedBody = body;
          return {
            'success': true,
            'videoStatus': 'video_ready',
            'storedVideoUrl': 'https://example.com/storage/cinematic.mp4',
          };
        },
      );

      final draft = UniversalXShareService.buildFallbackDraft(page);
      final result = await service.generateVideo(
        context: page,
        draft: draft,
        falRequestId: 'req-123',
        engine: AiShareVideoEngine.cinematic,
      );

      expect(capturedBody?['falRequestId'], 'req-123');
      expect(result.url, 'https://example.com/storage/cinematic.mp4');
      expect(result.status, 'video_ready');
    },
  );

  test(
    'cinematic prompt falls back to page title when draft prompt is empty',
    () {
      final draft = UniversalXShareService.buildFallbackDraft(
        page,
      ).copyWith(videoPrompt: '');

      final prompt = UniversalXShareService.cinematicVideoPromptFor(
        page,
        draft,
      );

      expect(prompt, contains('Gemini University'));
      expect(prompt, contains('paper-craft'));
    },
  );

  test('generateVideo prefers durable Supabase stored video URL', () async {
    final service = UniversalXShareService(
      functionInvoker: (functionName, body) async {
        return {
          'success': true,
          'videoStatus': 'complete',
          'storedVideoUrl': 'https://example.com/storage/video.mp4',
          'generatedDownloadUrl': 'https://temporary.example.com/video.mp4',
        };
      },
    );

    final draft = UniversalXShareService.buildFallbackDraft(page);
    final result = await service.generateVideo(context: page, draft: draft);

    expect(result.url, 'https://example.com/storage/video.mp4');
    expect(result.status, 'complete');
  });

  test(
    'generateVideo uses the public OGP image when no generated image exists',
    () async {
      Map<String, dynamic>? capturedBody;
      final service = UniversalXShareService(
        functionInvoker: (functionName, body) async {
          capturedBody = body;
          return {
            'success': true,
            'videoStatus': 'submitted',
            'hedraGenerationId': '123e4567-e89b-12d3-a456-426614174000',
          };
        },
      );

      final draft = UniversalXShareService.buildGrowthDraft(page);
      final result = await service.generateVideo(context: page, draft: draft);

      expect(result.status, 'submitted');
      expect(
        capturedBody?['imageUrl'],
        UniversalXShareService.defaultHedraStartImageUrl,
      );
      expect(capturedBody?['imageUrlSource'], 'page_ogp_fallback');
      expect(capturedBody?['type'], 'presenter_video');
    },
  );

  test('generateVideo does not forward embedded data URLs to Hedra', () async {
    String? capturedFunction;
    final service = UniversalXShareService(
      functionInvoker: (functionName, body) async {
        capturedFunction = functionName;
        return {'success': true, 'status': 'unexpected'};
      },
    );

    final draft = UniversalXShareService.buildFallbackDraft(page);
    final result = await service.generateVideo(
      context: page,
      draft: draft,
      imageUrl: 'data:image/png;base64,${'a' * 3000}',
    );

    expect(capturedFunction, isNull);
    expect(result.status, 'fallback_text');
    expect(result.raw['videoReason'], contains('public URL'));
  });

  test('isEmbeddedDataUrl detects generated inline images', () {
    expect(
      UniversalXShareService.isEmbeddedDataUrl('data:image/png;base64,abc'),
      isTrue,
    );
    expect(
      UniversalXShareService.isEmbeddedDataUrl('https://example.com/a.png'),
      isFalse,
    );
  });

  test(
    'generateVideo matches narration voice gender+tone to the presenter',
    () async {
      Map<String, dynamic>? capturedBody;
      final service = UniversalXShareService(
        functionInvoker: (functionName, body) async {
          capturedBody = body;
          return {'success': true, 'status': 'fallback_text'};
        },
      );

      final baseDraft = UniversalXShareService.buildGrowthDraft(page);
      final observedLabels = <String>{};
      var sawMaleVoice = false;
      var sawFemaleVoice = false;

      // 多数の異なる seed(= 当日ニュース違い)で presenter が男女両方へ振れることを
      // 確認しつつ、毎回 presenter の性別と音声ラベルの性別が一致すること(男性キャラに
      // 女性声、女性キャラに男性声が付かない)を保証する。
      for (var i = 0; i < 120; i += 1) {
        final draft = baseDraft.copyWith(text: 'x-share-seed-$i ${page.url}');
        await service.generateVideo(
          context: page,
          draft: draft,
          imageUrl: 'https://example.com/secretary.png',
        );
        final voice = capturedBody?['voice'] as String;
        final prompt = capturedBody?['customPrompt'] as String;
        expect(voice, isIn(_kVoiceLabels));
        final presenterIsFemale = prompt.contains('female') ||
            prompt.contains('woman') ||
            prompt.contains('lady');
        final voiceIsFemale = voice.contains('female');
        expect(
          voiceIsFemale,
          presenterIsFemale,
          reason:
              'voice "$voice" gender must match presenter in prompt: $prompt',
        );
        observedLabels.add(voice);
        sawMaleVoice = sawMaleVoice || !voiceIsFemale;
        sawFemaleVoice = sawFemaleVoice || voiceIsFemale;
      }

      // ローテの結果、男女両方の声が実際に選ばれること。
      expect(sawMaleVoice, isTrue);
      expect(sawFemaleVoice, isTrue);
      // トーン別ラベルへローテするため、中庸 narrator 以外の声も現れること。
      expect(observedLabels.length, greaterThanOrEqualTo(2));
      final sawTonedVoice = observedLabels.any(
        (label) => label.startsWith('energetic_') || label.startsWith('calm_'),
      );
      expect(sawTonedVoice, isTrue);
    },
  );

  test(
    'video narration is capped to a Hedra-safe length for long news drafts',
    () async {
      Map<String, dynamic>? capturedBody;
      final service = UniversalXShareService(
        functionInvoker: (functionName, body) async {
          capturedBody = body;
          return {'success': true, 'status': 'fallback_text'};
        },
      );

      // 1 行が 800 字超になる病的な長文 draft(=実測で processing 滞留→静止画に
      // なった 685 字を大きく超える)。台本(customScript)が確実に短縮されること。
      final longLine = 'とても長いニュース解説の一文です。' * 60;
      final draft = UniversalXShareDraft(
        text: '$longLine\n$longLine',
        imagePrompt: 'x',
        videoPrompt: 'y',
        hashtags: const ['#AI'],
        threadReplies: <String>['1. $longLine', '2. $longLine', '3. $longLine'],
        fallbackUsed: false,
        source: 'test',
      );

      await service.generateVideo(
        context: page,
        draft: draft,
        imageUrl: 'https://example.com/secretary.png',
      );

      final scriptLines =
          (capturedBody?['customScript'] as List).cast<String>();
      expect(scriptLines, isNotEmpty);
      // 総ナレーションは 450 字(+省略記号の余白)以内に収まる。
      expect(scriptLines.join().runes.length, lessThanOrEqualTo(460));
    },
  );

  test('finance video narration is capped even with a long AI draft', () async {
    Map<String, dynamic>? capturedBody;
    final service = UniversalXShareService(
      functionInvoker: (functionName, body) async {
        capturedBody = body;
        return {'success': true, 'status': 'fallback_text'};
      },
    );

    const financePage = UniversalSharePageContext(
      routePath: '/asset-management',
      title: '資産管理',
      url: 'https://my-web-app-b67f4.web.app/asset-management',
    );
    final longLine = 'とても長い資産管理の説明文です。' * 60;
    final draft = UniversalXShareDraft(
      text: '$longLine\n$longLine\n$longLine',
      imagePrompt: 'x',
      videoPrompt: 'y',
      hashtags: const ['#AI'],
      fallbackUsed: false,
      source: 'test',
    );

    await service.generateVideo(
      context: financePage,
      draft: draft,
      imageUrl: 'https://example.com/secretary.png',
    );

    final scriptLines = (capturedBody?['customScript'] as List).cast<String>();
    expect(scriptLines, isNotEmpty);
    expect(scriptLines.join().runes.length, lessThanOrEqualTo(460));
  });
}
