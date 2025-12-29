import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../main.dart';
import '../models/note.dart';

class GeminiUniversityPage extends StatefulWidget {
  const GeminiUniversityPage({super.key});

  @override
  State<GeminiUniversityPage> createState() => _GeminiUniversityPageState();
}

class _GeminiUniversityPageState extends State<GeminiUniversityPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  // 分析タブ用
  Map<String, dynamic>? _knowledgeReport;
  String? _analysisModel;

  // コンテンツ生成タブ用
  List<Note> _myNotes = [];
  Note? _selectedNote;
  String _targetFormat = 'blog';
  String? _generatedContent;
  String? _writerModel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchNotes();
  }

  Future<void> _fetchNotes() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      final response = await supabase
          .from('notes')
          .select()
          .eq('user_id', userId)
          .order('updated_at', ascending: false)
          .limit(50);
      if (mounted)
        setState(() => _myNotes =
            (response as List).map((n) => Note.fromJson(n)).toList());
    } catch (e) {}
  }

  // CKO: 知的資産分析
  Future<void> _analyzeKnowledge() async {
    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // 直近のメモを抽出
      final recent = _myNotes
          .take(10)
          .map((n) => {'title': n.title, 'content': n.content})
          .toList();

      final response = await supabase.functions.invoke(
        'ai-assistant',
        body: {'action': 'analyze_knowledge_assets', 'recentNotes': recent},
      );

      if (response.status != 200) throw Exception('AI Error');
      final data = response.data;

      setState(() {
        _knowledgeReport = data['result'];
        _analysisModel = data['used_model'];
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('分析エラー: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // CKO: ゴーストライター
  Future<void> _generateContent() async {
    if (_selectedNote == null) return;
    setState(() => _isLoading = true);
    try {
      final response = await supabase.functions.invoke(
        'ai-assistant',
        body: {
          'action': 'generate_content_draft',
          'title': _selectedNote!.title,
          'content': _selectedNote!.content,
          'targetFormat': _targetFormat
        },
      );

      if (response.status != 200) throw Exception('AI Error');
      final data = response.data;

      setState(() {
        _generatedContent = data['result']; // Raw Markdown string
        _writerModel = data['used_model'];
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('生成エラー: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(' 知的財産教育本部 (CKO)'),
        backgroundColor: Colors.indigo.shade800,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.indigo.shade200,
          tabs: const [
            Tab(icon: Icon(Icons.analytics), text: 'AIシンクタンク'),
            Tab(icon: Icon(Icons.create), text: 'コンテンツ制作局'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAnalysisTab(),
          _buildGhostWriterTab(),
        ],
      ),
    );
  }

  Widget _buildAnalysisTab() {
    if (_knowledgeReport == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lightbulb_outline, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('あなたのメモから「知的資産」を分析します',
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _analyzeKnowledge,
              icon: _isLoading
                  ? const CircularProgressIndicator()
                  : const Icon(Icons.auto_awesome),
              label: const Text('知的資産レポートを作成'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white),
            ),
          ],
        ),
      );
    }

    final interests =
        List<String>.from(_knowledgeReport!['core_interests'] ?? []);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_analysisModel != null)
            Align(
                alignment: Alignment.centerRight,
                child: Text('Analyst: $_analysisModel',
                    style: TextStyle(
                        fontSize: 10, color: Colors.indigo.shade300))),
          const Text('現在の関心領域 (Core Interests)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: interests
                .map((tag) => Chip(
                    label: Text(tag), backgroundColor: Colors.indigo.shade50))
                .toList(),
          ),
          const Divider(height: 32),
          const Text('CKOの分析コメント',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Text(_knowledgeReport!['analysis_comment'] ?? '',
              style: const TextStyle(fontSize: 15, height: 1.6)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.school, color: Colors.amber),
                  const SizedBox(width: 8),
                  const Text('学習のススメ',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.amber))
                ]),
                const SizedBox(height: 8),
                Text(_knowledgeReport!['next_learning_suggestion'] ?? '',
                    style: TextStyle(color: Colors.amber.shade900)),
              ],
            ),
          ),
          const SizedBox(height: 32),
          OutlinedButton(
              onPressed: _analyzeKnowledge, child: const Text('再分析する')),
        ],
      ),
    );
  }

  Widget _buildGhostWriterTab() {
    return Column(
      children: [
        // コントロールパネル
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.indigo.shade50,
          child: Column(
            children: [
              DropdownButton<Note>(
                value: _selectedNote,
                hint: const Text('元ネタにするメモを選択'),
                isExpanded: true,
                items: _myNotes.map((note) {
                  return DropdownMenuItem(
                      value: note,
                      child: Text(note.title, overflow: TextOverflow.ellipsis));
                }).toList(),
                onChanged: (val) => setState(() => _selectedNote = val),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButton<String>(
                      value: _targetFormat,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'blog', child: Text('ブログ記事')),
                        DropdownMenuItem(value: 'slide', child: Text('プレゼン構成')),
                        DropdownMenuItem(value: 'book', child: Text('書籍プロット')),
                      ],
                      onChanged: (val) => setState(() => _targetFormat = val!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: (_isLoading || _selectedNote == null)
                        ? null
                        : _generateContent,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(color: Colors.white))
                        : const Icon(Icons.edit_note),
                    label: const Text('執筆開始'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 生成結果エリア
        Expanded(
          child: _generatedContent == null
              ? const Center(
                  child: Text('メモを選んで「執筆開始」を押してください。\nAIがプロ級のコンテンツに仕上げます。',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (_writerModel != null)
                            Text('Ghost Writer: $_writerModel',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.indigo.shade300)),
                          IconButton(
                            icon: const Icon(Icons.share, color: Colors.indigo),
                            onPressed: () {
                              Share.share(_generatedContent!);
                            },
                          ),
                        ],
                      ),
                      const Divider(),
                      MarkdownBody(data: _generatedContent!),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
