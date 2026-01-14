import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
    ),
    CourseModule(
      id: 'prompt_engineering',
      title: 'プロンプトエンジニアリング',
      description: 'AIから最適な回答を引き出すための指示出しテクニック',
      icon: Icons.edit_note,
      content: 'AIへの指示（プロンプト）の質が、出力の質を大きく左右します。\n\n'
          '【効果的なプロンプトの4要素】\n'
          '1. **Persona (役割)**: 「あなたは熟練のエンジニアです」のように役割を与える。\n'
          '2. **Context (背景)**: 前提条件や背景情報を伝える。\n'
          '3. **Task (タスク)**: 具体的に何をすべきか指示する。\n'
          '4. **Format (形式)**: 出力形式（表、JSON、箇条書きなど）を指定する。\n\n'
          'また、「段階的に考えてください (Chain of Thought)」と指示することで、論理的推論能力が向上します。',
      quiz: Quiz(
        question: '論理的な回答を引き出すために有効なフレーズは？',
        options: ['急いで答えて', '段階的に考えて', '短く答えて', '英語で答えて'],
        correctIndex: 1,
      ),
    ),
    CourseModule(
      id: 'api_integration',
      title: 'API活用とFunction Calling',
      description: 'システム開発におけるGemini APIの活用法',
      icon: Icons.api,
      content: 'Gemini APIを使用することで、アプリにAI機能を組み込むことができます。\n\n'
          '【Function Calling (ツール使用)】\n'
          'Geminiが自ら「外部ツール（APIやDB検索など）を使うべき」と判断し、関数の引数を生成する機能です。これにより、AIがリアルタイム情報にアクセスしたり、特定のアクションを実行したりできます。\n\n'
          '【JSON Mode】\n'
          '出力を必ず正しいJSON形式に固定するモードです。システム連携において非常に重要です。',
      quiz: Quiz(
        question: 'AIが外部ツールを使用するための引数を生成する機能は？',
        options: ['RAG', 'Fine-tuning', 'Function Calling', 'Embedding'],
        correctIndex: 2,
      ),
    ),
    CourseModule(
      id: 'advanced_context',
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
          'Quantization'
              'Quantization',
        ],
        correctIndex: 0,
      ),
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
                    Text(
                      module.content,
                      style: const TextStyle(height: 1.6),
                    ),
                    const SizedBox(height: 24),
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

  Widget _buildQuiz(CourseModule module) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const Text(
          '【理解度確認クイズ】',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
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

  CourseModule({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.content,
    required this.quiz,
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
