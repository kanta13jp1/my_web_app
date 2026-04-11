import 'dart:convert';
import 'dart:math' show Random;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web/web.dart' as web_api;
import '../services/gamification_service.dart';
import '../services/theme_service.dart';
import 'ai_university_ranking_page.dart';
import 'api_playground_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// プロバイダーメタデータ
//
// DB (ai_university_content) に新プロバイダーの rows を追加するだけで
// UI に自動反映される。このマップへの追記は任意（未登録は汎用デフォルト表示）。
//
// セッション毎に新興AIプロバイダーを検討し必要に応じて追記する。
// 例: deepseek, mistral, cohere, perplexity, amazon, inflection, etc.
// ─────────────────────────────────────────────────────────────────────────────

class _ProviderMeta {
  _ProviderMeta({
    required this.name,
    required this.emoji,
    required this.color,
    required this.officialUrl,
  });
  final String name;
  final String emoji;
  final Color color;
  final String officialUrl;
}

final _unknownMeta = _ProviderMeta(
  name: 'AI',
  emoji: '🤖',
  color: const Color(0xFF607D8B),
  officialUrl: '',
);

// 既知プロバイダーの表示設定。DB に新しい provider が現れれば自動的にタブが増える。
// 表示名・絵文字・色・URL をカスタマイズしたい場合のみここに追加する。
final Map<String, _ProviderMeta> _providerMeta = {
  'google': _ProviderMeta(
    name: 'Google',
    emoji: '🔵',
    color: const Color(0xFF4285F4),
    officialUrl: 'https://ai.google.dev/',
  ),
  'openai': _ProviderMeta(
    name: 'OpenAI',
    emoji: '⚫',
    color: const Color(0xFF10A37F),
    officialUrl: 'https://platform.openai.com/',
  ),
  'anthropic': _ProviderMeta(
    name: 'Anthropic',
    emoji: '🟠',
    color: const Color(0xFFD4690E),
    officialUrl: 'https://docs.anthropic.com/',
  ),
  'microsoft': _ProviderMeta(
    name: 'Microsoft',
    emoji: '🔷',
    color: const Color(0xFF00A4EF),
    officialUrl: 'https://azure.microsoft.com/ja-jp/solutions/ai/',
  ),
  'meta': _ProviderMeta(
    name: 'Meta',
    emoji: '🟣',
    color: const Color(0xFF0866FF),
    officialUrl: 'https://ai.meta.com/',
  ),
  'x': _ProviderMeta(
    name: 'xAI',
    emoji: '⚡',
    color: const Color(0xFF1DA1F2),
    officialUrl: 'https://x.ai/',
  ),
  'deepseek': _ProviderMeta(
    name: 'DeepSeek',
    emoji: '🐋',
    color: const Color(0xFF4D6BFE),
    officialUrl: 'https://platform.deepseek.com/',
  ),
  'mistral': _ProviderMeta(
    name: 'Mistral',
    emoji: '💨',
    color: const Color(0xFFFF7000),
    officialUrl: 'https://docs.mistral.ai/',
  ),
  'cohere': _ProviderMeta(
    name: 'Cohere',
    emoji: '🔮',
    color: const Color(0xFF39594D),
    officialUrl: 'https://docs.cohere.com/',
  ),
  'perplexity': _ProviderMeta(
    name: 'Perplexity',
    emoji: '🔍',
    color: const Color(0xFF20808D),
    officialUrl: 'https://docs.perplexity.ai/',
  ),
  'amazon': _ProviderMeta(
    name: 'Amazon',
    emoji: '🔶',
    color: const Color(0xFFFF9900),
    officialUrl: 'https://aws.amazon.com/jp/bedrock/',
  ),
};

// ─────────────────────────────────────────────────────────────────────────────
// クイズデータ（プロバイダー別、DB コンテンツとは独立）
// ─────────────────────────────────────────────────────────────────────────────

class _Quiz {
  _Quiz({required this.question, required this.options, required this.correct});
  final String question;
  final List<String> options;
  final int correct;
}

final Map<String, _Quiz> _quizzes = {
  'google': _Quiz(
    question: 'Gemini 2.5 シリーズの最大入力コンテキスト長は？',
    options: ['128K', '256K', '1M', '2M'],
    correct: 2,
  ),
  'openai': _Quiz(
    question: 'OpenAI o1/o3 シリーズの特徴として正しいのは？',
    options: ['高速低コスト', '推論前の thinking ステップ', '画像生成特化', 'リアルタイム検索'],
    correct: 1,
  ),
  'anthropic': _Quiz(
    question: 'Anthropic が提唱する「Constitutional AI」の目的は？',
    options: ['高速化', '安全で有害性の低い応答の実現', '長文生成', '低コスト化'],
    correct: 1,
  ),
  'microsoft': _Quiz(
    question: 'Microsoft Copilot が統合されている主なサービスは？',
    options: ['Google Workspace', 'Microsoft 365 / Azure', 'AWS', 'Slack'],
    correct: 1,
  ),
  'meta': _Quiz(
    question: 'Meta の LLaMA モデルが注目される最大の理由は？',
    options: ['クローズドソース', 'オープンソース公開・商用利用可', '音声特化', '最安値API'],
    correct: 1,
  ),
  'x': _Quiz(
    question: 'xAI Grok の特徴として正しいのは？',
    options: ['オフライン専用', 'X(Twitter)リアルタイム情報へのアクセス', '画像専用', '翻訳特化'],
    correct: 1,
  ),
  'deepseek': _Quiz(
    question: 'DeepSeek R1 が注目される理由として正しいのは？',
    options: ['Google が開発', '低コストで高性能な推論モデル・OSS公開', '音声合成特化', '画像生成のみ'],
    correct: 1,
  ),
  'mistral': _Quiz(
    question: 'Mistral AI の本拠地はどこ？',
    options: ['米国', 'フランス', '英国', '日本'],
    correct: 1,
  ),
  'perplexity': _Quiz(
    question: 'Perplexity AI の主な特徴は？',
    options: ['画像生成', 'リアルタイム検索+引用付き回答', '音声合成', 'コード専用'],
    correct: 1,
  ),
};

// ─────────────────────────────────────────────────────────────────────────────
// フォールバックコンテンツ（DB が空の場合に表示）
// ─────────────────────────────────────────────────────────────────────────────

const Map<String, String> _fallback = {
  'google': '''
## Google AI (Gemini)

### 主要モデル
- **Gemini 2.5 Pro** — 最高精度・1Mトークン・Thinking機能
- **Gemini 2.5 Flash** — 高速・低コスト・Thinking対応
- **Gemini 2.0 Flash** — 安定版

### 特徴
- 100万トークンの超長文コンテキスト
- 画像・動画・音声のネイティブ処理
- Google Search連携・リアルタイム情報
- Vertex AI / Google AI Studio でAPI提供
''',
  'openai': '''
## OpenAI

### 主要モデル
- **GPT-4o** — 高汎用性・マルチモーダル
- **o1 / o3** — 推論特化・Thinking機能
- **o1-mini / o3-mini** — 軽量推論

### 特徴
- Function Calling / Structured Outputs
- Assistants API でのスレッド管理
- DALL-E 3 による画像生成
- 業界標準のAPIエコシステム
''',
  'anthropic': '''
## Anthropic (Claude)

### 主要モデル
- **Claude Sonnet 4.6** — 最新・高性能バランス型
- **Claude Opus 4.6** — 最高精度
- **Claude Haiku 4.5** — 高速・低コスト

### 特徴
- Constitutional AI による安全設計
- 200Kトークンコンテキスト
- コーディング・文章作成に高評価
- Claude Code (CLIツール) で開発者支援
''',
  'microsoft': '''
## Microsoft (Copilot / Azure AI)

### 主要サービス
- **Microsoft Copilot** — Word/Excel/Teams統合
- **Azure OpenAI Service** — GPT-4o/o1エンタープライズ版
- **Phi-4** — 軽量オープンソースSLM

### 特徴
- Microsoft 365 との深い統合
- エンタープライズセキュリティ・コンプライアンス
- GitHub Copilot でコーディング支援
- RAG構築: Azure AI Search + OpenAI
''',
  'meta': '''
## Meta AI (LLaMA)

### 主要モデル
- **LLaMA 3.3 70B** — 最新・高精度オープンソース
- **LLaMA 3.2** — マルチモーダル対応
- **LLaMA 3.1 405B** — 大規模・GPT-4級

### 特徴
- 完全オープンソース (商用利用可能ライセンス)
- ローカル実行対応 (Ollama等)
- WhatsApp/Instagram統合の Meta AI バックエンド
- 自由なファインチューニング
''',
  'x': '''
## xAI (Grok)

### 主要モデル
- **Grok 3** — 最新・高性能
- **Grok 3 mini** — 軽量版
- **Grok 2** — 安定版

### 特徴
- X(Twitter) のリアルタイム情報へのアクセス
- Aurora (画像生成) 統合
- X Premium ユーザーは無料利用可
- 制限の少ない応答スタイル
''',
  'deepseek': '''
## DeepSeek

中国の AI 企業が開発。圧倒的コストパフォーマンスで2025年初頭に世界的注目を集めた。

### 主要モデル
- **DeepSeek R1** — 推論特化・o1に匹敵・超低コスト・OSS
- **DeepSeek V3** — 汎用・高性能
- **DeepSeek Coder V2** — コーディング特化

### 特徴
- GPT-4o 比 約30〜50倍安いAPI料金
- R1 は Chain-of-Thought 推論ステップを明示出力
- MIT ライセンスでオープンソース公開
- Ollama 等でローカル実行も可能
''',
  'mistral': '''
## Mistral AI

フランス発。効率的なオープンウェイトモデルで欧州AI界をリード。

### 主要モデル
- **Mistral Large** — 最高精度
- **Mistral Nemo** — 128Kコンテキスト・軽量
- **Codestral** — コーディング特化

### 特徴
- 欧州発・GDPRコンプライアンス重視
- オープンウェイト版あり (自由デプロイ)
- Function Calling・JSON モード対応
''',
  'perplexity': '''
## Perplexity AI

検索エンジンとLLMを融合したAI検索サービス。

### 特徴
- リアルタイム検索 + 引用付き回答
- 情報ソースの透明性が高い
- Pro Search: 深い分析・比較が可能
- API 提供あり (OpenAI互換)
''',
  'amazon': '''
## Amazon (Bedrock)

AWS のマネージドAI基盤サービス。複数モデルをAPIで利用可能。

### 主要機能
- **Amazon Bedrock** — Claude/LLaMA/Titan等をAPI提供
- **Amazon Titan** — AWS独自モデル
- **Nova** — 最新の Amazon 独自マルチモーダルモデル

### 特徴
- 複数ファウンデーションモデルを統一APIで切替可能
- AWS IAM による細粒度アクセス制御
- Knowledge Bases でRAG構築が容易
''',
};

// ─────────────────────────────────────────────────────────────────────────────
// ページ本体
// ─────────────────────────────────────────────────────────────────────────────

class GeminiUniversityV2Page extends StatefulWidget {
  const GeminiUniversityV2Page({super.key});

  @override
  State<GeminiUniversityV2Page> createState() => _GeminiUniversityV2PageState();
}

class _GeminiUniversityV2PageState extends State<GeminiUniversityV2Page>
    with TickerProviderStateMixin {
  final _supabase = Supabase.instance.client;

  List<String> _providers = [];
  Map<String, List<Map<String, dynamic>>> _content = {};
  bool _loading = true;
  String? _error;
  TabController? _tabController;
  final Set<String> _answeredQuizzes = {};
  static const String _prefsKey = 'ai_univ_answered_quizzes';
  final _shareCardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _fetchContent();
    _loadAnsweredQuizzes();
  }

  Future<void> _loadAnsweredQuizzes() async {
    // ローカル (SharedPreferences) から読み込み
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey) ?? '';
    final localSet =
        saved.isNotEmpty ? saved.split(',').toSet() : <String>{};

    // Supabase からクロスデバイス記録を取得してマージ
    final user = _supabase.auth.currentUser;
    Set<String> remoteSet = {};
    if (user != null) {
      try {
        final rows = await _supabase
            .from('ai_university_scores')
            .select('provider_id')
            .eq('user_id', user.id)
            .eq('quiz_correct', true)
            .timeout(const Duration(seconds: 5));
        remoteSet = (rows as List)
            .cast<Map<String, dynamic>>()
            .map((r) => r['provider_id'] as String)
            .toSet();
      } catch (_) {
        // Supabase 取得失敗はサイレント — ローカルデータを使用
      }
    }

    final merged = localSet.union(remoteSet);
    if (mounted && merged.isNotEmpty) {
      setState(() => _answeredQuizzes.addAll(merged));
      // ローカルにも同期して次回起動時のオフライン対応
      if (merged.length > localSet.length) {
        await prefs.setString(_prefsKey, merged.join(','));
      }
    }
  }

  Future<void> _saveAnsweredQuizzes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, _answeredQuizzes.join(','));
  }

  Future<void> _shareProgress() async {
    final count = _answeredQuizzes.length;
    final total = _quizzes.length;
    const url = 'https://my-web-app-b67f4.web.app/#/gemini-university';

    // A/B/C テスト: 3バリエーションをランダム選択
    final variant = Random().nextInt(3);
    final String text;
    switch (variant) {
      case 0:
        // A: 正解数フォーカス
        text = '🎓 AI 大学でクイズ $count/$total 問正解！\n'
            'Google・OpenAI・Anthropic など主要AIを体系的に学習中。\n'
            '$url\n'
            '#AILearning #buildinpublic #FlutterWeb';
      case 1:
        // B: プロバイダー制覇フォーカス
        text = '🏆 AI 大学で $count 社のAIプロバイダーを制覇中！\n'
            'Google・OpenAI・DeepSeek・Mistral... 9社を比較学習できます。\n'
            '$url\n'
            '#AIUniversity #buildinpublic';
      default:
        // C: ランキング/競争フォーカス
        text = '📊 AI 大学ランキングに挑戦中！正解 $count 問達成 🎯\n'
            '複数のAIを使い比べながら正しく理解。ランキングで競おう！\n'
            '$url\n'
            '#AILearning #FlutterWeb';
    }

    await SharePlus.instance.share(ShareParams(text: text));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SNS シェアカード — OGP スタイル画像プレビュー + ダウンロード
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _showShareCardDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // カードプレビュー
              RepaintBoundary(
                key: _shareCardKey,
                child: _buildShareCard(),
              ),
              // ボタン行
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.download),
                        label: const Text('画像を保存'),
                        onPressed: _captureAndDownload,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.share),
                        label: const Text('テキストでシェア'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _shareProgress();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShareCard() {
    final count = _answeredQuizzes.length;
    final total = _providers.isNotEmpty ? _providers.length : _quizzes.length;

    return Container(
      width: 360,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1a237e), Color(0xFF283593), Color(0xFF3949AB)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ヘッダー
          const Row(
            children: [
              Text('🎓', style: TextStyle(fontSize: 32)),
              SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI 大学',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '自分株式会社',
                    style: TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white24),
          const SizedBox(height: 14),
          // 達成数メッセージ
          Text(
            '$count 社のAIを\n学習しました！',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          // プロバイダーバッジ行
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _providers.map((id) {
              final m = _meta(id);
              final learned = _answeredQuizzes.contains(id);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: learned
                      ? m.color.withAlpha(180)
                      : Colors.white.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${m.emoji} ${m.name}',
                  style: TextStyle(
                    fontSize: 11,
                    color: learned ? Colors.white : Colors.white38,
                    fontWeight:
                        learned ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // クイズ達成バー
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.withAlpha(40),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withAlpha(80)),
            ),
            child: Row(
              children: [
                const Text('📊', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Text(
                  'クイズ正解: $count / $total 問',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'my-web-app-b67f4.web.app',
            style: TextStyle(color: Colors.white60, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Future<void> _captureAndDownload() async {
    try {
      final boundary = _shareCardKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final pngBytes = byteData.buffer.asUint8List();
      final b64 = base64Encode(pngBytes);
      final a = web_api.HTMLAnchorElement()
        ..href = 'data:image/png;base64,$b64'
        ..download = 'ai-university-card.png';
      web_api.document.body?.append(a);
      a.click();
      a.remove();
    } catch (_) {
      // キャプチャ失敗はサイレント
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _fetchContent() async {
    try {
      final rows = await _supabase
          .from('ai_university_content')
          .select()
          .eq('is_active', true)
          .order('sort_order')
          .timeout(const Duration(seconds: 10));

      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (final row in (rows as List).cast<Map<String, dynamic>>()) {
        final provider = row['provider'] as String;
        (grouped[provider] ??= []).add(row);
      }

      // DB が空なら _providerMeta の全キーをフォールバックで表示
      final providers =
          grouped.isEmpty ? _providerMeta.keys.toList() : grouped.keys.toList();

      _tabController?.dispose();
      final tc = TabController(length: providers.length, vsync: this);
      if (mounted) {
        setState(() {
          _providers = providers;
          _content = grouped;
          _loading = false;
          _error = null;
          _tabController = tc;
        });
      }
    } catch (e) {
      if (mounted) {
        final providers = _providerMeta.keys.toList();
        _tabController?.dispose();
        setState(() {
          _loading = false;
          _error = e.toString();
          _providers = providers;
          _tabController = TabController(length: providers.length, vsync: this);
        });
      }
    }
  }

  _ProviderMeta _meta(String id) => _providerMeta[id] ?? _unknownMeta;

  Future<void> _awardQuizPoints(String providerId) async {
    if (_answeredQuizzes.contains(providerId)) return;
    setState(() => _answeredQuizzes.add(providerId));
    _saveAnsweredQuizzes();
    context
        .read<GamificationService>()
        .awardPoints(50, reason: 'AI大学クイズ正解: ${_meta(providerId).name}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎉 正解！ +50pt — ${_meta(providerId).name}'),
        duration: const Duration(seconds: 2),
      ),
    );
    // Supabase にスコアを記録 (RLS: users_own_scores で直接書き込み可)
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        await _supabase.from('ai_university_scores').upsert(
          {
            'user_id': user.id,
            'provider_id': providerId,
            'quiz_correct': true,
            'studied_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'user_id,provider_id',
        );
        // ストリーク更新 (DB関数で連続学習日数を計算)
        await _supabase.rpc(
          'update_ai_university_streak',
          params: {'p_user_id': user.id},
        );
      } catch (_) {
        // スコア保存失敗はサイレント — ローカルの SharedPreferences は保持済み
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final isDark = themeService.isDarkMode;
    final tc = _tabController;

    if (_loading || tc == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('AI 大学')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 大学'),
        backgroundColor: Colors.indigo.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard),
            tooltip: 'ランキング',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AiUniversityRankingPage(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.science),
            tooltip: 'API実験室',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ApiPlaygroundPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'シェアカード',
            onPressed: _showShareCardDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'コンテンツを更新',
            onPressed: () {
              setState(() => _loading = true);
              _fetchContent();
            },
          ),
        ],
        bottom: TabBar(
          controller: tc,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: _providers.map((id) {
            final m = _meta(id);
            return Tab(text: '${m.emoji} ${m.name}');
          }).toList(),
        ),
      ),
      body: Column(
        children: [
          if (_error != null)
            Container(
              color: Colors.orange.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'DBから取得できませんでした。フォールバック表示中。',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => _loading = true);
                      _fetchContent();
                    },
                    child: const Text('再試行'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: tc,
              children: _providers
                  .map((id) => _buildProviderTab(id, isDark))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderTab(String providerId, bool isDark) {
    final m = _meta(providerId);
    final rows = _content[providerId];
    final surface = isDark ? Colors.grey.shade900 : Colors.grey.shade50;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildProviderHeader(providerId, m, rows),
        const SizedBox(height: 12),
        if (rows != null && rows.isNotEmpty)
          ...rows.map((row) => _buildContentCard(row, isDark, surface))
        else
          _buildFallbackCard(providerId, surface),
        const SizedBox(height: 16),
        _buildQuizCard(providerId, m),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildProviderHeader(
    String id,
    _ProviderMeta m,
    List<Map<String, dynamic>>? rows,
  ) {
    String? updatedAt;
    if (rows != null && rows.isNotEmpty) {
      final ts = rows.first['updated_at'];
      if (ts != null) {
        try {
          final dt = DateTime.parse(ts.toString()).toLocal();
          updatedAt =
              '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} 更新';
        } catch (_) {}
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [m.color.withAlpha(200), m.color.withAlpha(130)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(m.emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (updatedAt != null)
                  Text(
                    updatedAt,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                if (rows == null || rows.isEmpty)
                  const Text(
                    'フォールバック表示',
                    style: TextStyle(color: Colors.white60, fontSize: 11),
                  ),
              ],
            ),
          ),
          if (m.officialUrl.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.open_in_new, color: Colors.white),
              tooltip: '公式サイト',
              onPressed: () => _launchUrl(m.officialUrl),
            ),
        ],
      ),
    );
  }

  Widget _buildContentCard(
    Map<String, dynamic> row,
    bool isDark,
    Color surface,
  ) {
    final category = row['category'] as String? ?? '';
    final title = row['title'] as String? ?? '';
    final content = row['content'] as String? ?? '';
    final sourceUrl = row['source_url'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: surface,
      child: ExpansionTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          _categoryLabel(category),
          style: const TextStyle(fontSize: 12),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MarkdownBody(
                  data: content,
                  onTapLink: (_, href, __) {
                    if (href != null) _launchUrl(href);
                  },
                ),
                if (sourceUrl != null && sourceUrl.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.open_in_new, size: 14),
                    label: const Text('出典を開く'),
                    onPressed: () => _launchUrl(sourceUrl),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackCard(String providerId, Color surface) {
    final markdown = _fallback[providerId] ??
        '## ${_meta(providerId).name}\n\nコンテンツは準備中です。\n\n毎週月曜の AI 大学更新タスクで DB が自動更新されます。';
    return Card(
      color: surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: MarkdownBody(
          data: markdown,
          onTapLink: (_, href, __) {
            if (href != null) _launchUrl(href);
          },
        ),
      ),
    );
  }

  Widget _buildQuizCard(String providerId, _ProviderMeta m) {
    final quiz = _quizzes[providerId];
    if (quiz == null) return const SizedBox.shrink();

    final answered = _answeredQuizzes.contains(providerId);

    return Card(
      color: m.color.withAlpha(25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: m.color.withAlpha(80)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.quiz, color: m.color),
                const SizedBox(width: 8),
                Text(
                  '${m.name} クイズ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: m.color,
                  ),
                ),
                if (answered) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
                  const Text(
                    ' +50pt',
                    style: TextStyle(color: Colors.green, fontSize: 12),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(
              quiz.question,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            ...List.generate(quiz.options.length, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: m.color.withAlpha(100)),
                    minimumSize: const Size(double.infinity, 40),
                    alignment: Alignment.centerLeft,
                  ),
                  onPressed: answered
                      ? null
                      : () {
                          if (i == quiz.correct) {
                            _awardQuizPoints(providerId);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('不正解。もう一度試してください。'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                  child: Text('${_optionLabel(i)}  ${quiz.options[i]}'),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _categoryLabel(String category) {
    const labels = {
      'overview': '概要',
      'models': 'モデル一覧',
      'api': 'API / SDK',
      'pricing': '料金',
      'news': '最新ニュース',
      'tutorial': 'チュートリアル',
    };
    return labels[category] ?? category;
  }

  String _optionLabel(int i) {
    const labels = ['A', 'B', 'C', 'D'];
    return i < labels.length ? labels[i] : '${i + 1}';
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
