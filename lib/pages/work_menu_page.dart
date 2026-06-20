import 'package:flutter/material.dart';

import '../data/home_tool_catalog.dart';
import '../services/home_tool_usage_service.dart';

class WorkMenuPage extends StatefulWidget {
  const WorkMenuPage({
    super.key,
    this.lockExploratoryTools = false,
    this.highlightedToolIds = const <String>{},
    this.badgeLabels = const <String, String>{},
    this.autofocusSearch = false,
    this.openMorningBriefing,
    this.openCfoOffice,
    this.openAbstinenceGuard,
  });

  final bool lockExploratoryTools;
  final Set<String> highlightedToolIds;
  final Map<String, String> badgeLabels;
  final bool autofocusSearch;
  final HomeToolOpenCallback? openMorningBriefing;
  final HomeToolOpenCallback? openCfoOffice;
  final HomeToolOpenCallback? openAbstinenceGuard;

  @override
  State<WorkMenuPage> createState() => _WorkMenuPageState();
}

class _WorkMenuPageState extends State<WorkMenuPage> {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  late Future<List<String>> _recentToolIdsFuture;
  String _query = '';

  List<HomeToolEntry> get _entries => buildHomeToolCatalog(
        openMorningBriefing: widget.openMorningBriefing,
        openCfoOffice: widget.openCfoOffice,
        openAbstinenceGuard: widget.openAbstinenceGuard,
      );

  Map<String, HomeToolEntry> get _entryMap => <String, HomeToolEntry>{
        for (final entry in _entries) entry.id: entry,
      };

  List<HomeToolEntry> get _filteredEntries {
    if (_query.trim().isEmpty) {
      return _entries;
    }
    final normalized = _query.trim().toLowerCase();
    return _entries.where((entry) {
      final haystacks = <String>[
        entry.title,
        entry.subtitle,
        ...entry.keywords,
      ];
      return haystacks.any((value) => value.toLowerCase().contains(normalized));
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    _recentToolIdsFuture = HomeToolUsageService.loadRecentToolIds();
    if (widget.autofocusSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _searchFocusNode.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _openEntry(HomeToolEntry entry) async {
    if (widget.lockExploratoryTools && entry.requiresClearDeck) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('先に必須導線を完了してから探索系メニューを開いてください。')),
      );
      return;
    }
    await HomeToolUsageService.recordToolUse(entry.id);
    if (!mounted) return;
    // entry.onOpen はカタログラッパー経由で user_feature_usage に記録される。
    await entry.onOpen(context);
    if (!mounted) return;
    setState(() {
      _recentToolIdsFuture = HomeToolUsageService.loadRecentToolIds();
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredEntries = _filteredEntries;

    return Scaffold(
      appBar: AppBar(title: const Text('業務メニュー')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _buildIntroCard(),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            onChanged: (value) {
              setState(() {
                _query = value;
              });
            },
            decoration: InputDecoration(
              labelText: '機能を検索',
              hintText: '例: 統一地方選 / 禁欲 / データベース / AI検索',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _query = '';
                        });
                      },
                      icon: const Icon(Icons.close),
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (_query.trim().isEmpty) ...[
            _buildSectionHeader(
              title: '最近使った機能',
              description: '直近で開いた導線をすぐ再開できます。',
              icon: Icons.history,
              color: const Color(0xFF3D5AFE),
            ),
            const SizedBox(height: 10),
            FutureBuilder<List<String>>(
              future: _recentToolIdsFuture,
              builder: (context, snapshot) {
                final recentEntries = (snapshot.data ?? const <String>[])
                    .map((id) => _entryMap[id])
                    .whereType<HomeToolEntry>()
                    .toList();
                if (recentEntries.isEmpty) {
                  return _buildEmptyState(
                    'まだ履歴がありません。下の一覧からよく使う機能を開くとここに並びます。',
                  );
                }
                return _buildEntryGrid(recentEntries.take(4).toList());
              },
            ),
            const SizedBox(height: 20),
          ] else ...[
            _buildSectionHeader(
              title: '検索結果',
              description: '${filteredEntries.length}件の機能が見つかりました。',
              icon: Icons.manage_search,
              color: const Color(0xFF3D5AFE),
            ),
            const SizedBox(height: 10),
            if (filteredEntries.isEmpty)
              _buildEmptyState('一致する機能がありません。別のキーワードで試してください。')
            else
              _buildEntryGrid(filteredEntries),
            const SizedBox(height: 20),
          ],
          if (_query.trim().isEmpty)
            ...homeToolSections.map((section) {
              final sectionEntries = filteredEntries
                  .where((entry) => entry.sectionId == section.id)
                  .toList();
              if (sectionEntries.isEmpty) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      title: section.title,
                      description: section.description,
                      icon: section.icon,
                      color: section.color,
                    ),
                    const SizedBox(height: 10),
                    _buildEntryGrid(sectionEntries),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF0F172A),
            Color(0xFF1E3A8A),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x220F172A),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ホームを「今日の入口」に戻し、探索系の機能はここに集約しました。',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '検索、最近使った機能、部署別の整理から最短で目的の画面へ移動できます。',
            style: TextStyle(
              color: Colors.white70,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      height: 1.4,
                      color: Theme.of(
                        context,
                      ).textTheme.bodySmall?.color?.withValues(alpha: 0.8),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEntryGrid(List<HomeToolEntry> entries) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 1200
        ? 3
        : width >= 760
            ? 2
            : 1;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: crossAxisCount == 1 ? 3.8 : 2.35,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) => _buildEntryCard(entries[index]),
    );
  }

  Widget _buildEntryCard(HomeToolEntry entry) {
    final theme = Theme.of(context);
    final isHighlighted = widget.highlightedToolIds.contains(entry.id);
    final badgeLabel = widget.badgeLabels[entry.id];
    final isLocked = widget.lockExploratoryTools && entry.requiresClearDeck;
    final cardColor = isHighlighted
        ? Color.alphaBlend(entry.color.withValues(alpha: 0.12), theme.cardColor)
        : theme.cardColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openEntry(entry),
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isHighlighted
                  ? entry.color.withValues(alpha: 0.55)
                  : theme.dividerColor.withValues(alpha: 0.2),
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: (isLocked ? const Color(0xFF607D8B) : entry.color)
                        .withValues(
                      alpha: 0.12,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    entry.icon,
                    color: isLocked ? const Color(0xFF607D8B) : entry.color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: isLocked
                                    ? const Color(0xFF607D8B)
                                    : isHighlighted
                                        ? entry.color
                                        : null,
                              ),
                            ),
                          ),
                          if (badgeLabel != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: entry.color.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                badgeLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: entry.color,
                                  height: 1.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isLocked ? '先に必須導線を終えてから開くメニューです。' : entry.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.5,
            ),
      ),
    );
  }
}
