import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 語学学習ページ
/// language-learning Edge Function と連携
/// Duolingo / Anki 競合
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
  List<Map<String, dynamic>> _decks = [];
  Map<String, dynamic>? _selectedDeck;
  List<Map<String, dynamic>> _cards = [];
  List<Map<String, dynamic>> _reviewCards = [];
  int _reviewIndex = 0;
  bool _showAnswer = false;
  Map<String, dynamic> _streak = {};
  Map<String, dynamic> _stats = {};

  final _deckTitleCtrl = TextEditingController();
  final _deckDescCtrl = TextEditingController();
  final _cardFrontCtrl = TextEditingController();
  final _cardBackCtrl = TextEditingController();
  final _cardExampleCtrl = TextEditingController();

  String _selectedFromLang = 'ja';
  String _selectedToLang = 'en';

  static const _langLabels = {
    'en': '英語',
    'ja': '日本語',
    'zh': '中国語',
    'ko': '韓国語',
    'fr': 'フランス語',
    'de': 'ドイツ語',
    'es': 'スペイン語',
    'pt': 'ポルトガル語',
    'it': 'イタリア語',
    'ru': 'ロシア語',
    'ar': 'アラビア語',
    'hi': 'ヒンディー語',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchDecks();
    _fetchStreak();
    _fetchStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _deckTitleCtrl.dispose();
    _deckDescCtrl.dispose();
    _cardFrontCtrl.dispose();
    _cardBackCtrl.dispose();
    _cardExampleCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchDecks() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'social-commerce-hub',
        body: {'action': 'lang.list_decks'},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['decks'] is List) {
        setState(() {
          _decks = (data['decks'] as List).cast<Map<String, dynamic>>();
        });
      } else {
        setState(() => _decks = []);
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = '単語帳の取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchCards(String deckId) async {
    try {
      final response = await _supabase.functions.invoke(
        'social-commerce-hub',
        body: {'action': 'lang.list_cards', 'deck_id': deckId},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['cards'] is List) {
        setState(() {
          _cards = (data['cards'] as List).cast<Map<String, dynamic>>();
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchReviewCards(String deckId) async {
    try {
      final response = await _supabase.functions.invoke(
        'social-commerce-hub',
        body: {'action': 'lang.review_session', 'deck_id': deckId},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['dueCards'] is List) {
        setState(() {
          _reviewCards =
              (data['dueCards'] as List).cast<Map<String, dynamic>>();
          _reviewIndex = 0;
          _showAnswer = false;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchStreak() async {
    try {
      final response = await _supabase.functions.invoke(
        'social-commerce-hub',
        body: {'action': 'lang.streak'},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['streak'] is Map) {
        setState(
          () => _streak = Map<String, dynamic>.from(data['streak'] as Map),
        );
      }
    } catch (_) {}
  }

  Future<void> _fetchStats() async {
    try {
      final response = await _supabase.functions.invoke(
        'social-commerce-hub',
        body: {'action': 'lang.stats'},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['stats'] is Map) {
        setState(
          () => _stats = Map<String, dynamic>.from(data['stats'] as Map),
        );
      }
    } catch (_) {}
  }

  Future<void> _createDeck() async {
    if (_deckTitleCtrl.text.trim().isEmpty) return;
    try {
      await _supabase.functions.invoke(
        'social-commerce-hub',
        body: {
          'action': 'lang.create_deck',
          'title': _deckTitleCtrl.text.trim(),
          'language_from': _selectedFromLang,
          'language_to': _selectedToLang,
          'description': _deckDescCtrl.text.trim(),
        },
      );
      _deckTitleCtrl.clear();
      _deckDescCtrl.clear();
      if (mounted) Navigator.of(context).pop();
      await _fetchDecks();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('作成失敗: $e')),
        );
      }
    }
  }

  Future<void> _addCard() async {
    final deck = _selectedDeck;
    if (deck == null) return;
    if (_cardFrontCtrl.text.trim().isEmpty ||
        _cardBackCtrl.text.trim().isEmpty) {
      return;
    }
    try {
      await _supabase.functions.invoke(
        'social-commerce-hub',
        body: {
          'action': 'lang.add_card',
          'deck_id': deck['deck_id'] as String? ?? '',
          'front': _cardFrontCtrl.text.trim(),
          'back': _cardBackCtrl.text.trim(),
          'example': _cardExampleCtrl.text.trim(),
        },
      );
      _cardFrontCtrl.clear();
      _cardBackCtrl.clear();
      _cardExampleCtrl.clear();
      if (mounted) Navigator.of(context).pop();
      await _fetchCards(deck['deck_id'] as String? ?? '');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('カード追加失敗: $e')),
        );
      }
    }
  }

  Future<void> _reviewCard(bool correct) async {
    if (_reviewCards.isEmpty || _reviewIndex >= _reviewCards.length) return;
    final card = _reviewCards[_reviewIndex];
    try {
      await _supabase.functions.invoke(
        'social-commerce-hub',
        body: {
          'action': 'lang.review_card',
          'card_id': card['card_id'] as String? ?? '',
          'correct': correct,
          'quality': correct ? 4 : 1,
        },
      );
      setState(() {
        if (_reviewIndex < _reviewCards.length - 1) {
          _reviewIndex++;
          _showAnswer = false;
        } else {
          _reviewCards = [];
          _reviewIndex = 0;
          _showAnswer = false;
        }
      });
      await _fetchStreak();
    } catch (_) {}
  }

  void _showCreateDeckDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('単語帳を作成'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _deckTitleCtrl,
              decoration: const InputDecoration(labelText: '単語帳名 *'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _deckDescCtrl,
              decoration: const InputDecoration(labelText: '説明 (任意)'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedFromLang,
                    isExpanded: true,
                    items: _langLabels.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedFromLang = v);
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.arrow_forward),
                ),
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedToLang,
                    isExpanded: true,
                    items: _langLabels.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedToLang = v);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: _createDeck,
            child: const Text('作成'),
          ),
        ],
      ),
    );
  }

  void _showAddCardDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('カードを追加'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _cardFrontCtrl,
              decoration: const InputDecoration(labelText: '表 (覚える単語・フレーズ) *'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _cardBackCtrl,
              decoration: const InputDecoration(labelText: '裏 (訳・意味) *'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _cardExampleCtrl,
              decoration: const InputDecoration(labelText: '例文 (任意)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: _addCard,
            child: const Text('追加'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('語学学習'),
        backgroundColor: const Color(0xFFFF6B35),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.library_books), text: '単語帳'),
            Tab(icon: Icon(Icons.flip), text: 'レビュー'),
            Tab(icon: Icon(Icons.bar_chart), text: '統計'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '単語帳を作成',
            onPressed: _showCreateDeckDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Color(0xFFE53935),
                      height: 1.5,
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDecksTab(),
                    _buildReviewTab(),
                    _buildStatsTab(),
                  ],
                ),
    );
  }

  Widget _buildDecksTab() {
    if (_decks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.library_books_outlined,
              size: 64,
              color: Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 16),
            const Text(
              '単語帳がありません',
              style: TextStyle(
                fontSize: 18,
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _showCreateDeckDialog,
              icon: const Icon(Icons.add),
              label: const Text('最初の単語帳を作成'),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        // Streak banner
        if (_streak.isNotEmpty)
          Container(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF2A1F0A)
                : const Color(0xFFFFF3E0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text(
                  '🔥',
                  style: TextStyle(
                    fontSize: 20,
                    height: 1.5,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_streak['current'] ?? 0}日連続学習中',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF6B35),
                    height: 1.5,
                  ),
                ),
                const Spacer(),
                Text(
                  '最長: ${_streak['longest'] ?? 0}日',
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _decks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final deck = _decks[i];
              final fromLang = deck['language_from'] as String? ?? '';
              final toLang = deck['language_to'] as String? ?? '';
              final cardCount = deck['card_count'] ?? 0;
              final isSelected = _selectedDeck?['deck_id'] == deck['deck_id'];
              return Card(
                elevation: isSelected ? 4 : 1,
                color: isSelected ? const Color(0xFFFFF3E0) : null,
                child: ListTile(
                  leading: const Icon(Icons.book, color: Color(0xFFFF6B35)),
                  title: Text(deck['title'] as String? ?? ''),
                  subtitle: Text(
                    '${_langLabels[fromLang] ?? fromLang} → ${_langLabels[toLang] ?? toLang} | $cardCount 枚',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected)
                        IconButton(
                          icon: const Icon(
                            Icons.add_card,
                            color: Color(0xFFFF6B35),
                          ),
                          tooltip: 'カードを追加',
                          onPressed: _showAddCardDialog,
                        ),
                      IconButton(
                        icon: const Icon(
                          Icons.play_arrow,
                          color: Color(0xFF4CAF50),
                        ),
                        tooltip: 'レビュー開始',
                        onPressed: () async {
                          setState(() => _selectedDeck = deck);
                          await _fetchReviewCards(
                            deck['deck_id'] as String? ?? '',
                          );
                          _tabController.animateTo(1);
                        },
                      ),
                    ],
                  ),
                  onTap: () async {
                    setState(() => _selectedDeck = deck);
                    await _fetchCards(deck['deck_id'] as String? ?? '');
                  },
                ),
              );
            },
          ),
        ),
        // Card list for selected deck
        if (_selectedDeck != null && _cards.isNotEmpty)
          Container(
            height: 200,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    '「${_selectedDeck!['title']}」のカード (${_cards.length}枚)',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _cards.length,
                    itemBuilder: (_, i) {
                      final card = _cards[i];
                      return ListTile(
                        dense: true,
                        title: Text(card['front'] as String? ?? ''),
                        trailing: Text(card['back'] as String? ?? ''),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildReviewTab() {
    if (_selectedDeck == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flip_outlined, size: 64, color: Color(0xFF9CA3AF)),
            SizedBox(height: 16),
            Text(
              '「単語帳」タブから単語帳を選択してレビューを開始してください',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }
    if (_reviewCards.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Color(0xFF4CAF50),
            ),
            const SizedBox(height: 16),
            const Text(
              '本日のレビューは完了です！',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'また明日復習しましょう',
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () =>
                  _fetchReviewCards(_selectedDeck!['deck_id'] as String? ?? ''),
              icon: const Icon(Icons.refresh),
              label: const Text('再チェック'),
            ),
          ],
        ),
      );
    }

    final card = _reviewCards[_reviewIndex];
    final progress = (_reviewIndex + 1) / _reviewCards.length;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Progress
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: progress,
                  color: const Color(0xFFFF6B35),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_reviewIndex + 1}/${_reviewCards.length}',
                style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  height: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          // Card
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showAnswer = !_showAnswer),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _showAnswer
                          ? [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)]
                          : [const Color(0xFFFFF3E0), const Color(0xFFFFF3E0)],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!_showAnswer) ...[
                        const Text(
                          '単語',
                          style: TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          card['front'] as String? ?? '',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          'タップして答えを見る',
                          style: TextStyle(
                            color: Color(0xFF9CA3AF),
                            height: 1.5,
                          ),
                        ),
                      ] else ...[
                        const Text(
                          '訳',
                          style: TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          card['back'] as String? ?? '',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4CAF50),
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (card['example'] != null &&
                            (card['example'] as String).isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              '例: ${card['example']}',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontSize: 14,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (_showAnswer) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: OutlinedButton.icon(
                      onPressed: () => _reviewCard(false),
                      icon: const Icon(Icons.close, color: Color(0xFFE53935)),
                      label: const Text(
                        'もう一度',
                        style: TextStyle(
                          color: Color(0xFFE53935),
                          height: 1.5,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE53935)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ElevatedButton.icon(
                      onPressed: () => _reviewCard(true),
                      icon: const Icon(Icons.check),
                      label: const Text('覚えた！'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else
            ElevatedButton.icon(
              onPressed: () => setState(() => _showAnswer = true),
              icon: const Icon(Icons.visibility),
              label: const Text('答えを見る'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsTab() {
    final totalCards = _stats['totalCards'] ?? 0;
    final totalReviews = _stats['totalReviews'] ?? 0;
    final correctRate = _stats['correctRate'] ?? 0;
    final deckCount = _stats['deckCount'] ?? _decks.length;

    return RefreshIndicator(
      onRefresh: () async {
        await _fetchStats();
        await _fetchStreak();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Streak card
          Card(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF2A1F0A)
                : const Color(0xFFFFF3E0),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    '🔥',
                    style: TextStyle(
                      fontSize: 48,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_streak['current'] ?? 0}日連続',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF6B35),
                          height: 1.5,
                        ),
                      ),
                      Text(
                        '最長: ${_streak['longest'] ?? 0}日',
                        style: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Stats grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _buildStatCard(
                '単語帳',
                '$deckCount',
                Icons.library_books,
                const Color(0xFF3D5AFE),
              ),
              _buildStatCard(
                '総カード数',
                '$totalCards',
                Icons.flip,
                const Color(0xFFFF6B35),
              ),
              _buildStatCard(
                '総レビュー',
                '$totalReviews',
                Icons.history,
                const Color(0xFF4CAF50),
              ),
              _buildStatCard(
                '正解率',
                '$correctRate%',
                Icons.percent,
                const Color(0xFF3D5AFE),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Tips card
          Card(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF0C1A2A)
                : const Color(0xFFE3F2FD),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '学習のコツ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildTip('🧠', '間隔反復法 (SM-2) で効率的に暗記'),
                  _buildTip('⏰', '毎日少しずつ継続することが大切'),
                  _buildTip('📝', '例文を一緒に覚えると定着率UP'),
                  _buildTip('🔥', 'ストリークを途切れさせないように'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
                height: 1.5,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTip(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            emoji,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
