import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/gamification_service.dart';
import '../services/theme_service.dart';

class GeminiUniversityV2Page extends StatefulWidget {
  const GeminiUniversityV2Page({super.key});

  @override
  State<GeminiUniversityV2Page> createState() => _GeminiUniversityV2PageState();
}

class _GeminiUniversityV2PageState extends State<GeminiUniversityV2Page>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _completedModuleIds = {};

  // Curriculum Data
  final List<CourseModule> _modules = [
    CourseModule(
      id: 'gemini_basics',
      title: 'Gemini 基礎概論',
      description: 'GeminiモデルファミリーとマルチモーダルAIの基本を学ぶ',
      icon: Icons.auto_awesome,
      content: 'GeminiはGoogleが開発した最新のマルチモーダル生成AIモデルです。\n\n'
          '【主な特徴】\n'
          '1. **ネイティブ・マルチモーダル**: テキストだけでなく、画像、音声、動画、コードを最初から理解できるように設計されています。\n'
          '2. **モデルファミリー**: \n'
          '   - **Gemini Pro**: 幅広いタスクに対応する最高性能モデル。\n'
          '   - **Gemini Flash**: 高速かつ低コスト。大量データ処理に最適。\n'
          '   - **Gemini Nano**: デバイス上で動作する効率的なモデル。\n\n'
          '従来のAIと異なり、複数のモダリティをシームレスに扱えるのが最大の特徴です。',
      quiz: Quiz(
        question: 'Geminiファミリーの中で、デバイス上で動作する最も軽量なモデルは？',
        options: ['Gemini Pro', 'Gemini Ultra', 'Gemini Nano', 'Gemini Flash'],
        correctIndex: 2,
      ),
      officialDocs: [
        {
          'title': 'Gemini API overview',
          'url': 'https://ai.google.dev/docs/gemini_api_overview',
        },
        {
          'title': 'Gemini Models',
          'url': 'https://ai.google.dev/models/gemini',
        },
      ],
    ),
    CourseModule(
      id: 'prompt_design',
      title: 'プロンプト設計',
      description: '効果的なプロンプトを作成するためのベストプラクティス',
      icon: Icons.edit_note,
      content: 'AIから最適な回答を引き出すには、プロンプトの設計が極めて重要です。\n\n'
          '【プロンプト設計のヒント】\n'
          '1. **明確な指示**: AIに何をさせたいかを具体的に記述します。\n'
          '2. **役割を与える (Persona)**: 「あなたは熟練のマーケターです」のように、AIの役割を指定します。\n'
          '3. **例を示す (Few-shot)**: 期待する出力形式の例をいくつか提示します。\n'
          '4. **段階的に考えさせる (Chain of Thought)**: 複雑な問題は、ステップバイステップで考えさせると精度が向上します。\n'
          '5. **出力形式を指定する**: JSON、Markdown、箇条書きなど、希望の形式を明確に指示します。',
      quiz: Quiz(
        question: 'AIに役割を与えるプロンプト手法を何と呼びますか？',
        options: ['Few-shot', 'Chain of Thought', 'Persona', 'Format'],
        correctIndex: 2,
      ),
      officialDocs: [
        {
          'title': 'Prompt design strategies',
          'url': 'https://ai.google.dev/docs/prompt_best_practices',
        },
        {
          'title': 'Prompt Gallery',
          'url': 'https://ai.google.dev/examples?keywords=prompting',
        },
      ],
    ),
    CourseModule(
      id: 'function_calling',
      title: 'Function Calling',
      description: '外部システムと連携して機能を拡張する',
      icon: Icons.api,
      content:
          'Function Callingは、Geminiが外部のAPIやサービスを呼び出す必要があると判断した際に、特定の関数を呼び出すための構造化されたデータを返す機能です。\n\n'
          '【主な利点】\n'
          '1. **リアルタイム情報アクセス**: 天気予報、株価、ニュースなど、最新の情報を取得できます。\n'
          '2. **外部サービス連携**: 自社のデータベース検索や、Eメール送信などのアクションを実行できます。\n'
          '3. **構造化データ抽出**: 自然言語のテキストから、定義したスキーマに基づいて情報を抽出します。\n\n'
          'これにより、AIは単なるテキスト生成にとどまらず、より動的でインタラクティブなアプリケーションの一部として機能します。',
      quiz: Quiz(
        question: 'Function Callingの主な利点は次のうちどれですか？',
        options: ['モデルの学習', 'リアルタイム情報の取得', '画像の生成', 'テキストの翻訳'],
        correctIndex: 1,
      ),
      officialDocs: [
        {
          'title': 'Function calling',
          'url': 'https://ai.google.dev/docs/function_calling',
        },
        {
          'title': 'Vertex AI - Function calling',
          'url':
              'https://cloud.google.com/vertex-ai/docs/generative-ai/multimodal/function-calling',
        },
      ],
    ),
    CourseModule(
      id: 'multimodality',
      title: 'マルチモーダリティ',
      description: 'テキスト、画像、音声を組み合わせた入力と出力',
      icon: Icons.camera_alt,
      content: 'Geminiは、テキストだけでなく、画像、音声、動画といった複数の種類の情報を同時に理解し、処理することができます。\n\n'
          '【ユースケース例】\n'
          '1. **画像の説明**: 画像をアップロードし、その内容を説明する文章を生成します。\n'
          '2. **動画の要約**: 動画ファイルから主要なシーンを抜き出し、要約を作成します。\n'
          '3. **音声コマンド**: 音声で指示を出し、それに応じたテキストや画像を生成します。\n\n'
          'プロンプトに複数のモダリティ（例：画像とテキスト）を組み合わせることで、より複雑で文脈に沿ったタスクを実行できます。',
      quiz: Quiz(
        question: 'マルチモーダルAIが扱える情報の種類は次のうちどれですか？',
        options: ['テキストのみ', 'テキストと画像のみ', 'テキスト、画像、音声、動画など', '数値データのみ'],
        correctIndex: 2,
      ),
      officialDocs: [
        {
          'title': 'Multimodal concepts',
          'url': 'https://ai.google.dev/docs/concepts#multimodal',
        },
        {'title': 'Media', 'url': 'https://ai.google.dev/docs/media'},
      ],
    ),
    CourseModule(
      id: 'long_context',
      title: 'ロングコンテキストとキャッシュ',
      description: 'Gemini 1.5の長大なコンテキストウィンドウの活用',
      icon: Icons.memory,
      content: 'Gemini 1.5 Proは、最大200万トークンという圧倒的なコンテキストウィンドウを持っています。\n\n'
          '【活用例】\n'
          '・数時間の動画や音声を一度に読み込んで分析\n'
          '・数千ページのドキュメント全体から情報を検索\n'
          '・大規模なコードベース全体の理解\n\n'
          '【Context Caching】\n'
          '頻繁に使用する長いコンテキスト（マニュアルや規定など）をキャッシュすることで、コストとレイテンシを削減できます。',
      quiz: Quiz(
        question: '長いプロンプトを再利用してコストを削減する機能は？',
        options: [
          'Context Caching',
          'Vector Search',
          'Distillation',
          'Quantization',
        ],
        correctIndex: 0,
      ),
      officialDocs: [
        {
          'title': 'Context caching',
          'url': 'https://ai.google.dev/docs/context_caching',
        },
        {
          'title': 'Get started with Gemini 1.5 Pro',
          'url':
              'https://ai.google.dev/docs/gemini_api_overview?language=python#gemini-1.5-pro',
        },
      ],
    ),
    CourseModule(
      id: 'json_mode',
      title: 'JSONモード',
      description: '構造化されたJSON出力を保証する',
      icon: Icons.code,
      content: 'JSONモードを有効にすると、モデルの出力が必ず有効なJSON文字列であることが保証されます。\n\n'
          '【利点】\n'
          '- **信頼性**: 出力が常にパース可能であるため、アプリケーションとの連携が安定します。\n'
          '- **効率化**: 出力形式を検証し、リトライするロジックをクライアント側で実装する必要がなくなります。\n\n'
          'API連携や、構造化データを必要とするアプリケーション開発において非常に強力な機能です。',
      quiz: Quiz(
        question: 'JSONモードの主な利点は何ですか？',
        options: ['出力が高速になる', '出力が必ず有効なJSONになる', '出力がカラフルになる', '出力が長くなる'],
        correctIndex: 1,
      ),
      officialDocs: [
        {
          'title': 'JSON mode',
          'url': 'https://ai.google.dev/docs/prompt_best_practices#json-mode',
        },
      ],
    ),
    CourseModule(
      id: 'responsible_ai',
      title: '責任あるAI',
      description: '安全で倫理的なAIアプリケーションを構築する',
      icon: Icons.health_and_safety,
      content: 'Googleは、AIを責任を持って開発するためのツールとガイダンスを提供しています。\n\n'
          '【安全設定 (Safety Settings)】\n'
          'Gemini APIには、有害なコンテンツ（嫌がらせ、ヘイトスピーチなど）をブロックするための安全設定が組み込まれています。閾値を調整することで、ユースケースに応じたカスタマイズが可能です。\n\n'
          '【APIキーの保護】\n'
          'APIキーは、クライアントサイドのコードに直接埋め込むべきではありません。サーバーサイドで管理し、必要に応じて呼び出すなどの対策が推奨されます。',
      quiz: Quiz(
        question: '有害なコンテンツをブロックする機能は何ですか？',
        options: ['APIキー', 'JSONモード', '安全設定', 'Persona'],
        correctIndex: 2,
      ),
      officialDocs: [
        {
          'title': 'Safety settings',
          'url': 'https://ai.google.dev/docs/safety_setting_gemini',
        },
        {
          'title': 'AI principles',
          'url': 'https://ai.google/responsibility/principles/',
        },
      ],
    ),
    CourseModule(
      id: 'api_reference',
      title: 'Gemini API リファレンス',
      description: 'REST APIやSDKの技術仕様を学ぶ',
      icon: Icons.integration_instructions,
      content:
          'このAPIリファレンスは、Geminiモデルとのやり取りに使用できる標準API、ストリーミングAPI、リアルタイムAPIについて説明します。\n\n'
          'HTTPリクエストをサポートする環境であれば、どの環境でもREST APIを利用できます。\n\n'
          '最初のAPI呼び出しを開始する方法については、クイックスタートガイドを参照してください。\n\n'
          '言語固有のライブラリおよびSDKの参照情報をお探しの場合は、左ナビゲーションの「SDKリファレンス」にある該当言語のリンクをご覧ください。\n\n'
          '利用規約を更新しました。',
      quiz: Quiz(
        question: 'HTTPリクエストをサポートする環境で利用できるAPIは？',
        options: ['REST API', 'SDK', 'GraphQL API', 'SOAP API'],
        correctIndex: 0,
      ),
      officialDocs: [
        {
          'title': 'Gemini REST API reference',
          'url': 'https://ai.google.dev/api/rest',
        },
        {
          'title': 'SDK references',
          'url': 'https://ai.google.dev/docs/sdks',
        },
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not launch $urlString'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _completeModule(String id) {
    if (!_completedModuleIds.contains(id)) {
      setState(() {
        _completedModuleIds.add(id);
      });

      // ポイント付与
      context
          .read<GamificationService>()
          .awardPoints(50, reason: 'Gemini大学講義修了');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('正解！単位を取得しました (50pt)'),
          backgroundColor: Colors.green,
        ),
      );

      if (_completedModuleIds.length == _modules.length) {
        _showGraduationDialog();
      }
    }
  }

  void _showGraduationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.school, color: Colors.orange),
            SizedBox(width: 8),
            Text('卒業おめでとうございます！'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Gemini大学の全カリキュラムを修了しました。'),
            SizedBox(height: 16),
            Text(
              '学位: Gemini Master',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('特別ボーナス: 500pt'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              context
                  .read<GamificationService>()
                  .awardPoints(500, reason: 'Gemini大学卒業');
              Navigator.pop(context);
            },
            child: const Text('学位を受け取る'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final isDark = themeService.isDarkMode;
    final primaryColor = Colors.indigo.shade800;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gemini 大学'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.menu_book), text: 'カリキュラム'),
            Tab(icon: Icon(Icons.card_membership), text: '学位・成績'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCurriculumTab(isDark),
          _buildDegreeTab(isDark),
        ],
      ),
    );
  }

  Widget _buildCurriculumTab(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _modules.length,
      itemBuilder: (context, index) {
        final module = _modules[index];
        final isCompleted = _completedModuleIds.contains(module.id);

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isCompleted
                ? const BorderSide(color: Colors.green, width: 2)
                : BorderSide.none,
          ),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor:
                  isCompleted ? Colors.green : Colors.indigo.shade100,
              child: Icon(
                isCompleted ? Icons.check : module.icon,
                color: isCompleted ? Colors.white : Colors.indigo,
              ),
            ),
            title: Text(
              module.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(module.description),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MarkdownBody(
                      data: module.content,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(height: 1.6),
                      ),
                    ),
                    _buildOfficialDocs(module),
                    if (!isCompleted)
                      _buildQuiz(module)
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text(
                            '単位取得済み',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOfficialDocs(CourseModule module) {
    if (module.officialDocs == null || module.officialDocs!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Divider(),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            '【公式ドキュメント】',
            style:
                TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
          ),
        ),
        ...module.officialDocs!.map((doc) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: TextButton.icon(
              onPressed: () => _launchUrl(doc['url']!),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(doc['title']!),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                alignment: Alignment.centerLeft,
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildQuiz(CourseModule module) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Divider(),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            '【理解度確認クイズ】',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
          ),
        ),
        const SizedBox(height: 8),
        Text(module.quiz.question, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 12),
        ...module.quiz.options.asMap().entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  if (entry.key == module.quiz.correctIndex) {
                    _completeModule(module.id);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('不正解です。もう一度内容を確認しましょう。'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.all(12),
                ),
                child: Text('${entry.key + 1}. ${entry.value}'),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDegreeTab(bool isDark) {
    final progress = _completedModuleIds.length / _modules.length;
    final isGraduated = progress >= 1.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 150,
                height: 150,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 12,
                  backgroundColor: Colors.grey.shade200,
                  color: isGraduated ? Colors.orange : Colors.indigo,
                ),
              ),
              Column(
                children: [
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text('修了率'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 40),
          if (isGraduated)
            _buildCertificate()
          else
            const Text(
              'すべての講義を修了して、\nGeminiマスターの称号を手に入れましょう！',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          const SizedBox(height: 40),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.school),
            title: const Text('取得単位数'),
            trailing: Text(
              '${_completedModuleIds.length} / ${_modules.length}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificate() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.workspace_premium, size: 64, color: Colors.orange),
          const SizedBox(height: 16),
          const Text(
            'CERTIFICATE OF COMPLETION',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Gemini Master',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              fontFamily: 'Serif',
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'この証書は、Gemini大学の全課程を修了し、\n生成AIに関する高度な知識を有することを証明します。',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 24),
          Text(
            'Date: ${DateTime.now().year}.${DateTime.now().month}.${DateTime.now().day}',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class CourseModule {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final String content;
  final Quiz quiz;
  final List<Map<String, String>>? officialDocs;

  CourseModule({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.content,
    required this.quiz,
    this.officialDocs,
  });
}

class Quiz {
  final String question;
  final List<String> options;
  final int correctIndex;

  Quiz({
    required this.question,
    required this.options,
    required this.correctIndex,
  });
}
