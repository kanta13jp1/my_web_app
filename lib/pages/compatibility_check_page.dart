import 'package:flutter/material.dart';
import '../services/personality_test_service.dart';
import '../services/compatibility_service.dart';
import 'compatibility_result_page.dart';

/// 相手のタイプを選択して相性をチェックするページ
class CompatibilityCheckPage extends StatefulWidget {
  final String myType;

  const CompatibilityCheckPage({
    super.key,
    required this.myType,
  });

  @override
  State<CompatibilityCheckPage> createState() => _CompatibilityCheckPageState();
}

class _CompatibilityCheckPageState extends State<CompatibilityCheckPage> {
  final CompatibilityService _compatibilityService = CompatibilityService();
  String? _selectedPartnerType;
  List<Map<String, dynamic>>? _topMatches;
  bool _showingTopMatches = false;

  @override
  void initState() {
    super.initState();
    _loadTopMatches();
  }

  void _loadTopMatches() {
    final matches = _compatibilityService.getTopCompatibleTypes(widget.myType);
    setState(() {
      _topMatches = matches;
    });
  }

  void _checkCompatibility() {
    if (_selectedPartnerType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('相手のタイプを選択してください')),
      );
      return;
    }

    // 相性結果ページに遷移
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CompatibilityResultPage(
          myType: widget.myType,
          partnerType: _selectedPartnerType!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('相性診断'),
        backgroundColor: const Color(0xFFFFE0B2),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // あなたのタイプ表示
              _buildYourTypeCard(),
              const SizedBox(height: 24),

              // タブ切り替え
              _buildTabSelector(),
              const SizedBox(height: 24),

              // コンテンツ
              if (_showingTopMatches)
                _buildTopMatchesList()
              else
                _buildTypeSelector(),

              const SizedBox(height: 32),

              // 診断ボタン（タイプ選択時のみ表示）
              if (!_showingTopMatches && _selectedPartnerType != null)
                _buildCheckButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildYourTypeCard() {
    final personalityType = PersonalityTestService.personalityTypes.firstWhere(
      (t) => t.code == widget.myType,
      orElse: () => PersonalityTestService.personalityTypes[0],
    );

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE3F2FD), Color(0xFFE8EAF6)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              'あなたのタイプ',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.myType,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0D47A1),
                        letterSpacing: 3,
                      ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    personalityType.nameJa,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: const Color(0xFF0D47A1),
                        ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTab(
              title: 'おすすめ',
              icon: Icons.star,
              isSelected: _showingTopMatches,
              onTap: () {
                setState(() {
                  _showingTopMatches = true;
                  _selectedPartnerType = null;
                });
              },
            ),
          ),
          Expanded(
            child: _buildTab(
              title: 'すべて',
              icon: Icons.grid_view,
              isSelected: !_showingTopMatches,
              onTap: () {
                setState(() {
                  _showingTopMatches = false;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFA726) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopMatchesList() {
    if (_topMatches == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.star, color: Color(0xFFFFA000)),
            const SizedBox(width: 8),
            Text(
              'あなたと相性の良いタイプ TOP5',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ..._topMatches!.asMap().entries.map((entry) {
          final int index = entry.key;
          final Map<String, dynamic> match = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildTopMatchCard(
              rank: index + 1,
              type: match['type'],
              score: match['score'],
              level: match['level'],
              title: match['title'],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTopMatchCard({
    required int rank,
    required String type,
    required int score,
    required String level,
    required String title,
  }) {
    final personalityType = PersonalityTestService.personalityTypes.firstWhere(
      (t) => t.code == type,
      orElse: () => PersonalityTestService.personalityTypes[0],
    );

    Color rankColor;
    IconData rankIcon;
    switch (rank) {
      case 1:
        rankColor = const Color(0xFFFFA000);
        rankIcon = Icons.emoji_events;
        break;
      case 2:
        rankColor = Theme.of(context).colorScheme.onSurfaceVariant;
        rankIcon = Icons.emoji_events;
        break;
      case 3:
        rankColor = const Color(0xFF6D4C41);
        rankIcon = Icons.emoji_events;
        break;
      default:
        rankColor = const Color(0xFF1976D2);
        rankIcon = Icons.star;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: rank <= 3
              ? rankColor
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          width: rank <= 3 ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CompatibilityResultPage(
                myType: widget.myType,
                partnerType: type,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // ランク表示
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: rankColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(rankIcon, color: rankColor, size: 20),
                    Text(
                      '$rank',
                      style: TextStyle(
                        color: rankColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // タイプ情報
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          type,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          personalityType.nameJa,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),

              // スコア表示
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.favorite,
                      color: Color(0xFFF57C00),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$score',
                      style: const TextStyle(
                        color: Color(0xFFF57C00),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        height: 1.5,
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

  Widget _buildTypeSelector() {
    const types = [
      'INTJ',
      'INTP',
      'ENTJ',
      'ENTP',
      'INFJ',
      'INFP',
      'ENFJ',
      'ENFP',
      'ISTJ',
      'ISFJ',
      'ESTJ',
      'ESFJ',
      'ISTP',
      'ISFP',
      'ESTP',
      'ESFP',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '相手のタイプを選択',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 1,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: types.length,
          itemBuilder: (context, index) {
            final type = types[index];
            final isSelected = _selectedPartnerType == type;
            final isMyType = type == widget.myType;

            return _buildTypeCard(type, isSelected, isMyType);
          },
        ),
      ],
    );
  }

  Widget _buildTypeCard(String type, bool isSelected, bool isMyType) {
    final personalityType = PersonalityTestService.personalityTypes.firstWhere(
      (t) => t.code == type,
      orElse: () => PersonalityTestService.personalityTypes[0],
    );

    return Card(
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? const Color(0xFFFFA726)
              : isMyType
                  ? const Color(0xFF64B5F6)
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
          width: isSelected || isMyType ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: isMyType
            ? null
            : () {
                setState(() {
                  _selectedPartnerType = type;
                });
              },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFFFF3E0)
                : isMyType
                    ? const Color(0xFFE3F2FD)
                    : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                type,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? const Color(0xFFE65100)
                          : isMyType
                              ? const Color(0xFF0D47A1)
                              : Theme.of(context).colorScheme.onSurface,
                      letterSpacing: 1.2,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                personalityType.nameJa,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (isMyType) ...[
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFBBDEFB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'あなた',
                    style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFF0D47A1),
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: _checkCompatibility,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFA726),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.favorite, size: 24),
            const SizedBox(width: 8),
            Text(
              '相性を診断する',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
