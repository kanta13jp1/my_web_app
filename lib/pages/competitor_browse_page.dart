import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/home_back_button.dart';

typedef CompetitorBrowseLoader = Future<List<Map<String, dynamic>>> Function();

class CompetitorBrowsePage extends StatefulWidget {
  final CompetitorBrowseLoader? loader;

  const CompetitorBrowsePage({super.key, this.loader});

  @override
  State<CompetitorBrowsePage> createState() => _CompetitorBrowsePageState();
}

class _CompetitorBrowsePageState extends State<CompetitorBrowsePage> {
  List<Map<String, dynamic>> _competitors = [];
  bool _loading = true;
  bool _loadFailed = false;

  String? _selectedPricingTier;
  String? _selectedJapanPresence;
  String _sortBy = 'overlap'; // 'overlap' | 'name' | 'threat'

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_loading || _loadFailed) {
      setState(() {
        _loading = true;
        _loadFailed = false;
      });
    }
    try {
      final rows = await (widget.loader?.call() ?? _fetchCompetitors());
      if (mounted) {
        setState(() {
          _competitors = rows;
          _loading = false;
          _loadFailed = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchCompetitors() async {
    final rows = await Supabase.instance.client
        .from('competitors')
        .select(
          'id, display_name, emoji, category, pricing_tier, pricing_start_usd, '
          'japan_presence_level, our_overlap_score, threat_level',
        )
        .eq('is_active', true)
        .order('our_overlap_score', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  List<Map<String, dynamic>> get _filtered {
    final list = _competitors.where((c) {
      if (_selectedPricingTier != null &&
          c['pricing_tier'] != _selectedPricingTier) {
        return false;
      }
      if (_selectedJapanPresence != null &&
          c['japan_presence_level'] != _selectedJapanPresence) {
        return false;
      }
      return true;
    }).toList();
    if (_sortBy == 'name') {
      list.sort(
        (a, b) => (a['display_name'] as String? ?? '').compareTo(
          b['display_name'] as String? ?? '',
        ),
      );
    } else if (_sortBy == 'threat') {
      const order = {'critical': 0, 'high': 1, 'medium': 2, 'low': 3};
      list.sort((a, b) {
        final ta = order[a['threat_level']] ?? 9;
        final tb = order[b['threat_level']] ?? 9;
        return ta.compareTo(tb);
      });
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final isWide = MediaQuery.of(context).size.width >= 900;
    final isMid = MediaQuery.of(context).size.width >= 600;
    final crossCount = isWide ? 4 : (isMid ? 3 : 2);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1830),
        elevation: 0,
        leading: const HomeBackButton(),
        title: const Text(
          '競合ランドスケープ',
          style: TextStyle(color: Colors.white, fontSize: 18, height: 1.5),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                '${filtered.length}社',
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
                  )
                : _loadFailed
                    ? Center(
                        child: Semantics(
                          liveRegion: true,
                          label: '競合情報の読み込みに失敗しました',
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                '競合情報を読み込めませんでした',
                                style: TextStyle(
                                  color: Color(0xFFCBD5E1),
                                  height: 1.6,
                                ),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                key: const Key('competitor-browse-retry'),
                                onPressed: _load,
                                icon: const Icon(Icons.refresh),
                                label: const Text('再読み込み'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : filtered.isEmpty
                        ? const Center(
                            child: Text(
                              '該当する競合がありません',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                height: 1.6,
                              ),
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(12),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossCount,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 1.0,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (context, i) =>
                                _CompetitorCard(data: filtered[i]),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: const Color(0xFF1A1830),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'すべて',
                  selected: _selectedPricingTier == null,
                  onTap: () {
                    setState(() => _selectedPricingTier = null);
                  },
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: '完全無料',
                  selected: _selectedPricingTier == 'free',
                  onTap: () {
                    setState(() {
                      _selectedPricingTier =
                          _selectedPricingTier == 'free' ? null : 'free';
                    });
                  },
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: 'Freemium',
                  selected: _selectedPricingTier == 'freemium',
                  onTap: () {
                    setState(() {
                      _selectedPricingTier = _selectedPricingTier == 'freemium'
                          ? null
                          : 'freemium';
                    });
                  },
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: '有料',
                  selected: _selectedPricingTier == 'paid',
                  onTap: () {
                    setState(() {
                      _selectedPricingTier =
                          _selectedPricingTier == 'paid' ? null : 'paid';
                    });
                  },
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: 'Enterprise',
                  selected: _selectedPricingTier == 'enterprise',
                  onTap: () {
                    setState(() {
                      _selectedPricingTier =
                          _selectedPricingTier == 'enterprise'
                              ? null
                              : 'enterprise';
                    });
                  },
                ),
                const SizedBox(width: 16),
                const Text(
                  '│',
                  style: TextStyle(color: Color(0xFF374151), height: 1.5),
                ),
                const SizedBox(width: 16),
                _FilterChip(
                  label: '🇯🇵 Dominant',
                  selected: _selectedJapanPresence == 'dominant',
                  onTap: () {
                    setState(() {
                      _selectedJapanPresence =
                          _selectedJapanPresence == 'dominant'
                              ? null
                              : 'dominant';
                    });
                  },
                  color: const Color(0xFFE53935),
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: '🇯🇵 Strong',
                  selected: _selectedJapanPresence == 'strong',
                  onTap: () {
                    setState(() {
                      _selectedJapanPresence =
                          _selectedJapanPresence == 'strong' ? null : 'strong';
                    });
                  },
                  color: const Color(0xFFFF6B35),
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: '📈 Growing',
                  selected: _selectedJapanPresence == 'growing',
                  onTap: () {
                    setState(() {
                      _selectedJapanPresence =
                          _selectedJapanPresence == 'growing'
                              ? null
                              : 'growing';
                    });
                  },
                  color: const Color(0xFFFFB300),
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: '🌐 Limited',
                  selected: _selectedJapanPresence == 'limited',
                  onTap: () {
                    setState(() {
                      _selectedJapanPresence =
                          _selectedJapanPresence == 'limited'
                              ? null
                              : 'limited';
                    });
                  },
                  color: const Color(0xFF607D8B),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'ソート:',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(width: 8),
              _SortButton(
                label: 'overlap',
                selected: _sortBy == 'overlap',
                onTap: () {
                  setState(() => _sortBy = 'overlap');
                },
              ),
              const SizedBox(width: 6),
              _SortButton(
                label: '脅威度',
                selected: _sortBy == 'threat',
                onTap: () {
                  setState(() => _sortBy = 'threat');
                },
              ),
              const SizedBox(width: 6),
              _SortButton(
                label: '名前',
                selected: _sortBy == 'name',
                onTap: () {
                  setState(() => _sortBy = 'name');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompetitorCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _CompetitorCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final id = data['id'] as String? ?? '';
    final name = data['display_name'] as String? ?? id;
    final emoji = data['emoji'] as String? ?? '🏢';
    final pricingTier = data['pricing_tier'] as String?;
    final pricingUsd = data['pricing_start_usd'] as num?;
    final japanLevel = data['japan_presence_level'] as String?;
    final threat = data['threat_level'] as String?;

    final threatColor = switch (threat) {
      'critical' => const Color(0xFFE53935),
      'high' => const Color(0xFFFF6B35),
      'medium' => const Color(0xFFFFB300),
      _ => const Color(0xFF4CAF50),
    };

    return InkWell(
      onTap: () => Navigator.of(context).pushNamed('/vs-$id'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1B2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: threatColor.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 20, height: 1.4)),
                const Spacer(),
                if (threat != null)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: threatColor,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const Spacer(),
            if (pricingTier != null) _PricingBadge(tier: pricingTier),
            if (pricingTier != null && pricingUsd != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '\$${pricingUsd.toStringAsFixed(0)}/月〜',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 9,
                    height: 1.4,
                  ),
                ),
              ),
            if (japanLevel != null) ...[
              const SizedBox(height: 4),
              _JapanPresenceBadge(level: japanLevel),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = const Color(0xFFFF6B35),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.18)
              : const Color(0xFF2A2744),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : const Color(0xFF374151)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : const Color(0xFF94A3B8),
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SortButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFFF6B35).withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? const Color(0xFFFF6B35) : const Color(0xFF374151),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFFFF6B35) : const Color(0xFF94A3B8),
            fontSize: 11,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _PricingBadge extends StatelessWidget {
  final String tier;

  const _PricingBadge({required this.tier});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (tier) {
      'free' => ('完全無料', const Color(0xFF4CAF50)),
      'freemium' => ('Freemium', const Color(0xFF009688)),
      'paid' => ('有料', const Color(0xFFFF9800)),
      'enterprise' => ('Enterprise', const Color(0xFF7C3AED)),
      _ => ('?', const Color(0xFF9E9E9E)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
      ),
    );
  }
}

class _JapanPresenceBadge extends StatelessWidget {
  final String level;

  const _JapanPresenceBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    final (emoji, label, color) = switch (level) {
      'dominant' => ('🇯🇵', 'Dominant', const Color(0xFFE53935)),
      'strong' => ('🇯🇵', 'Strong', const Color(0xFFFF6B35)),
      'growing' => ('📈', 'Growing', const Color(0xFFFFB300)),
      'limited' => ('🌐', 'Limited', const Color(0xFF607D8B)),
      'not_present' => ('⚠️', 'Not present', const Color(0xFF9E9E9E)),
      _ => ('', '', const Color(0xFF9E9E9E)),
    };
    if (label.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$emoji $label',
        style: TextStyle(color: color, fontSize: 9, height: 1.4),
      ),
    );
  }
}
