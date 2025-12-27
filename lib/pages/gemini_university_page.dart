import 'package:flutter/material.dart';

// --- 1. データモデル (講義と章の定義) ---
class Lesson {
  final String title;
  final String content;
  final String iconEmoji;

  Lesson({required this.title, required this.content, required this.iconEmoji});
}

class Module {
  final String title;
  final List<Lesson> lessons;

  Module({required this.title, required this.lessons});
}

// --- 2. カリキュラムデータ (Gemini大学のコンテンツ) ---
// ※以前の構想に基づき、サンプルデータを入れています。内容は自由に変更可能です。
final List<Module> geminiCurriculum = [
  Module(
    title: '第1章: Gemini入門',
    lessons: [
      Lesson(
        title: 'Geminiとは？',
        iconEmoji: '🌟',
        content: 'GeminiはGoogleが開発した最新のマルチモーダルAIモデルです。\nテキストだけでなく、画像、音声、動画も理解することができます。',
      ),
      Lesson(
        title: '基本的な使い方',
        iconEmoji: '💬',
        content: '「〜について教えて」のように自然な言葉で話しかけてみましょう。\n情報の要約、アイデア出し、翻訳など幅広く活用できます。',
      ),
    ],
  ),
  Module(
    title: '第2章: プロンプトエンジニアリング',
    lessons: [
      Lesson(
        title: '効果的な指示の出し方',
        iconEmoji: '🎯',
        content: 'AIに意図を明確に伝えるには、「役割を与える」「制約条件をつける」「出力形式を指定する」ことが重要です。',
      ),
      Lesson(
        title: 'few-shot プロンプティング',
        iconEmoji: '📝',
        content: 'いくつかの例（例題と回答）を提示してから質問することで、AIの回答精度を劇的に向上させるテクニックです。',
      ),
    ],
  ),
  Module(
    title: '第3章: 活用事例',
    lessons: [
      Lesson(
        title: 'プログラミング支援',
        iconEmoji: '💻',
        content: 'コードの生成、デバッグ、リファクタリング、コメントの追加など、開発者の強力なパートナーになります。',
      ),
    ],
  ),
];

// --- 3. UI実装 (大学トップ画面) ---
class GeminiUniversityPage extends StatelessWidget {
  const GeminiUniversityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎓 Gemini大学'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: geminiCurriculum.length,
        itemBuilder: (context, index) {
          final module = geminiCurriculum[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16.0),
            elevation: 2,
            child: ExpansionTile(
              title: Text(
                module.title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              initiallyExpanded: index == 0, // 最初の章だけ開いておく
              children: module.lessons.map((lesson) {
                return ListTile(
                  leading: Text(lesson.iconEmoji, style: const TextStyle(fontSize: 24)),
                  title: Text(lesson.title),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // 詳細画面へ遷移
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LessonDetailPage(lesson: lesson),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}

// --- 4. UI実装 (講義詳細画面) ---
class LessonDetailPage extends StatelessWidget {
  final Lesson lesson;

  const LessonDetailPage({super.key, required this.lesson});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(lesson.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                lesson.iconEmoji,
                style: const TextStyle(fontSize: 64),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              lesson.title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
            ),
            const Divider(height: 32),
            Text(
              lesson.content,
              style: const TextStyle(fontSize: 16, height: 1.6),
            ),
            const SizedBox(height: 40),
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.check),
                label: const Text('学習完了'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}