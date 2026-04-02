import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 語学学習ページ
/// フラッシュカード・レッスン・進捗管理。
/// language-learning Edge Function と連携。
class LanguageLearningPage extends StatefulWidget {
  const LanguageLearningPage({super.key});

  @override
  State<LanguageLearningPage> createState() => _LanguageLearningPageState();
}

class _LanguageLearningPageState extends State<LanguageLearningPage>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late final TabController _tabController;

  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _progress;
  List<Map<String, dynamic>> _cards = [];
  List<Map<String, dynamic>> _lessons = [];

  // フラッシュカード学習状態
  int _cardIndex = 0;
  bool _showAnswer = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final progressRes = await _supabase.functions.invoke(
        'language-learning',
        queryParameters: {'view': 'progress'},
      );
      final cardsRes = await _supabase.functions.invoke(
        'language-learning',
        queryParameters: {'view': 'flashcards'},
      );
      final lessonsRes = await _supabase.functions.invoke(
        'language-learning',
        queryParameters: {'view': 'lessons'},
      );

      setState(() {
        final pd = progressRes.data;
        if (pd is Map<String, dynamic>) _progress = pd;

        final cd = cardsRes.data;
        if (cd is Map<String, dynamic>) {
          final list = cd['cards'];
          if (list is List) {
            _cards = list.map((c) => c as Map<String, dynamic>).toList();
          }
        }

        final ld = lessonsRes.data;
        if (ld is Map<String, dynamic>) {
          final list = ld['lessons'];
          if (list is List) {
            _lessons = list.map((l) => l as Map<String, dynamic>).toList();
          }
        }

        _cardIndex = 0;
        _showAnswer = false;
      });
    } catch (e) {
      setState(() => _errorMessage = '$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _answerCard(String result) async {
    if (_cards.isEmpty) return;
    final cardId = _cards[_cardIndex]['id'] as String? ?? '';
    try {
      await _supabase.functions.invoke(
        'language-learning',
        body: {'action': 'answer_card', 'cardId': cardId, 'result': result},
      );
    } catch (_) {}
    setState(() {
      _showAnswer = false;
      if (_cardIndex < _cards.length - 1) {
        _cardIndex++;
      } else {
        _cardIndex = 0;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('すべてのカードを学習しました！')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('語学学習'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchData),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.style), text: 'カード'),
            Tab(icon: Icon(Icons.book), text: 'レッスン'),
            Tab(icon: Icon(Icons.bar_chart), text: '進捗'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildError()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildFlashcardTab(),
                    _buildLessonsTab(),
                    _buildProgressTab(),
                  ],
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text(_errorMessage!),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _fetchData, child: const Text('再試行')),
        ],
      ),
    );
  }

  Widget _buildFlashcardTab() {
    if (_cards.isEmpty) {
      return const Center(
        child: Text('フラッシュカードがありません', style: TextStyle(color: Colors.grey)),
      );
    }
    final card = _cards[_cardIndex];
    final front = card['front'] as String? ?? '';
    final back = card['back'] as String? ?? '';
    final lang = card['language'] as String? ?? '';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${_cardIndex + 1} / ${_cards.length}',
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => setState(() => _showAnswer = !_showAnswer),
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            elevation: 4,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  if (lang.isNotEmpty)
                    Chip(label: Text(lang)),
                  const SizedBox(height: 16),
                  Text(
                    front,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_showAnswer) ...[
                    const Divider(height: 32),
                    Text(
                      back,
                      style: TextStyle(
                        fontSize: 22,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ] else
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Text(
                        'タップして答えを表示',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (_showAnswer)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => _answerCard('wrong'),
                icon: const Icon(Icons.close, color: Colors.red),
                label: const Text('不正解'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => _answerCard('correct'),
                icon: const Icon(Icons.check, color: Colors.green),
                label: const Text('正解'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade50,
                ),
              ),
            ],
          )
        else
          TextButton(
            onPressed: () => setState(() => _showAnswer = true),
            child: const Text('答えを表示'),
          ),
      ],
    );
  }

  Widget _buildLessonsTab() {
    if (_lessons.isEmpty) {
      return const Center(
        child: Text('レッスンがありません', style: TextStyle(color: Colors.grey)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _lessons.length,
      itemBuilder: (ctx, i) {
        final l = _lessons[i];
        final title = l['title'] as String? ?? 'レッスン ${i + 1}';
        final desc = l['description'] as String? ?? '';
        final level = l['level'] as String? ?? '';
        final completed = l['completed'] as bool? ?? false;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: completed
                  ? Colors.green.shade100
                  : Colors.blue.shade100,
              child: Icon(
                completed ? Icons.check : Icons.play_arrow,
                color: completed ? Colors.green : Colors.blue,
              ),
            ),
            title: Text(title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (desc.isNotEmpty) Text(desc),
                if (level.isNotEmpty)
                  Chip(
                    label: Text(level, style: const TextStyle(fontSize: 11)),
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
            trailing: completed
                ? const Icon(Icons.check_circle, color: Colors.green)
                : const Icon(Icons.chevron_right),
          ),
        );
      },
    );
  }

  Widget _buildProgressTab() {
    final data = _progress ?? {};
    final totalCards = data['totalCards'] as int? ?? 0;
    final masteredCards = data['masteredCards'] as int? ?? 0;
    final streak = data['streak'] as int? ?? 0;
    final languages = data['languages'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _statCard(
                  '総カード数',
                  '$totalCards',
                  Icons.style,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  '習得済み',
                  '$masteredCards',
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  '連続学習',
                  '$streak 日',
                  Icons.local_fire_department,
                  Colors.orange,
                ),
              ),
            ],
          ),
          if (totalCards > 0) ...[
            const SizedBox(height: 20),
            const Text(
              '習得率',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: masteredCards / totalCards,
              minHeight: 12,
              backgroundColor: Colors.grey.shade200,
            ),
            const SizedBox(height: 4),
            Text(
              '${(masteredCards / totalCards * 100).toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
          if (languages is List && languages.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              '学習言語',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: languages.map((lang) {
                return Chip(label: Text('$lang'));
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
