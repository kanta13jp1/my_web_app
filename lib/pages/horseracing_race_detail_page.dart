import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// netkeiba 風 出走表マトリックス
/// 各行 = 1頭、各列 = AI プロバイダー予想印 (◎○▲) + 馬情報
class HorseracingRaceDetailPage extends StatefulWidget {
  final Map<String, dynamic> race;

  const HorseracingRaceDetailPage({super.key, required this.race});

  @override
  State<HorseracingRaceDetailPage> createState() =>
      _HorseracingRaceDetailPageState();
}

class _HorseracingRaceDetailPageState extends State<HorseracingRaceDetailPage> {
  List<Map<String, dynamic>> _providers = [];
  Map<String, dynamic>? _consensus;
  bool _loading = false;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      setState(() => _loading = false);
      return;
    }
    final raceId = widget.race['id'] as String?;
    if (raceId == null) return;
    setState(() => _loading = true);
    try {
      final resp = await Supabase.instance.client.functions.invoke(
        'tools-hub',
        body: {'action': 'horseracing.consensus', 'race_id': raceId},
      );
      final data = resp.data as Map<String, dynamic>?;
      if (mounted) {
        setState(() {
          _consensus = data?['consensus'] as Map<String, dynamic>?;
          _providers = ((data?['providers'] as List?) ?? [])
              .cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _rerunEnsemble() async {
    final raceId = widget.race['id'] as String?;
    if (raceId == null) return;
    setState(() => _running = true);
    try {
      await Supabase.instance.client.functions.invoke(
        'tools-hub',
        body: {
          'action': 'horseracing.predict_ensemble',
          'race_id': raceId,
          'force': true,
        },
      );
      await _load();
    } catch (_) {
      if (!mounted) return;
      if (mounted) setState(() => _running = false);
    }
  }

  // Classic keiba frame colors
  Color _frameColor(int waku) {
    switch (waku) {
      case 1:
        return const Color(0xFFFFFFFF);
      case 2:
        return const Color(0xFF1E1E1E);
      case 3:
        return const Color(0xFFDC2626);
      case 4:
        return const Color(0xFF2563EB);
      case 5:
        return const Color(0xFFFACC15);
      case 6:
        return const Color(0xFF16A34A);
      case 7:
        return const Color(0xFFF97316);
      case 8:
        return const Color(0xFFEC4899);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  Color _frameTextColor(int waku) =>
      (waku == 1 || waku == 5) ? Colors.black : Colors.white;

  Color _providerColor(String provider) {
    switch (provider.toLowerCase()) {
      case 'google':
        return const Color(0xFF4285F4);
      case 'openai':
        return const Color(0xFF10A37F);
      case 'anthropic':
        return const Color(0xFFFF6B35);
      case 'x':
      case 'xai':
        return const Color(0xFF94A3B8);
      default:
        return const Color(0xFF6366F1);
    }
  }

  // Return prediction mark for a horse given provider prediction
  // first_pick=◎, second_pick=○, third_pick=▲, else ─
  (String, Color) _mark(Map<String, dynamic> provider, String horseName) {
    if ((provider['first_pick'] as String?) == horseName) {
      return ('◎', const Color(0xFFDC2626));
    }
    if ((provider['second_pick'] as String?) == horseName) {
      return ('○', const Color(0xFF2563EB));
    }
    if ((provider['third_pick'] as String?) == horseName) {
      return ('▲', const Color(0xFFF59E0B));
    }
    return ('─', const Color(0xFF374151));
  }

  // Consensus mark for a horse
  (String, Color) _consensusMark(String horseName) {
    if (_consensus == null) return ('─', const Color(0xFF374151));
    final first = _consensus!['first_pick'] as String?;
    if (first == horseName) {
      final votes = _consensus!['votes'] as int? ?? 0;
      return ('◎$votes票', const Color(0xFFDC2626));
    }
    return ('─', const Color(0xFF374151));
  }

  @override
  Widget build(BuildContext context) {
    final race = widget.race;
    final raceName = race['race_name'] as String? ?? 'レース';
    final venue = race['venue'] as String? ?? '';
    final courseType = race['course_type'] as String? ?? '芝';
    final distance = (race['distance'] as num?)?.toInt();
    final grade = race['grade'] as String? ?? '';
    final raceNumber = (race['race_number'] as num?)?.toInt();
    final postTime = race['post_time'] as String?;
    final entries =
        ((race['horse_entries'] as List?) ?? []).cast<Map<String, dynamic>>();

    // Sort by horse number
    final sortedEntries = List<Map<String, dynamic>>.from(entries)
      ..sort((a, b) {
        final na = (a['horse_number'] as num?)?.toInt() ?? 99;
        final nb = (b['horse_number'] as num?)?.toInt() ?? 99;
        return na.compareTo(nb);
      });

    final providerNames = _providers
        .map((p) {
          final prov = p['provider'] as String? ?? '';
          return prov.split(':').first;
        })
        .toSet()
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            if (raceNumber != null)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${raceNumber}R',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    height: 1.4,
                  ),
                ),
              ),
            Expanded(
              child: Text(
                raceName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            height: 32,
            child: OutlinedButton.icon(
              icon: _running
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    )
                  : const Icon(Icons.refresh, size: 14),
              label: const Text(
                'ensemble再実行',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6366F1),
                side: const BorderSide(color: Color(0xFF6366F1), width: 0.7),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: _running ? null : _rerunEnsemble,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Race header
          _buildRaceHeader(venue, courseType, distance, grade, postTime),
          // Consensus bar
          if (_consensus != null) _buildConsensusBar(),
          // Matrix table
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : sortedEntries.isEmpty
                    ? const Center(
                        child: Text(
                          '出走馬データなし',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            height: 1.5,
                          ),
                        ),
                      )
                    : _buildMatrix(sortedEntries, providerNames),
          ),
        ],
      ),
    );
  }

  Widget _buildRaceHeader(
    String venue,
    String courseType,
    int? distance,
    String grade,
    String? postTime,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        border: Border(
          bottom:
              BorderSide(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
        ),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          if (postTime != null)
            _headerChip(Icons.schedule, postTime, const Color(0xFFFF6B35)),
          _headerChip(
            Icons.location_on_outlined,
            venue,
            const Color(0xFF6366F1),
          ),
          _headerChip(
            Icons.straighten,
            '$courseType${distance != null ? ' ${distance}m' : ''}',
            const Color(0xFF0D9488),
          ),
          if (grade.isNotEmpty)
            _headerChip(Icons.star_outline, grade, const Color(0xFFFFC107)),
        ],
      ),
    );
  }

  Widget _headerChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildConsensusBar() {
    final firstPick = _consensus!['first_pick'] as String? ?? '?';
    final votes = _consensus!['votes'] as int? ?? 0;
    final agreementRate =
        ((_consensus!['agreement_rate'] as num?)?.toDouble() ?? 0) * 100;
    final placePick = _consensus!['place_consensus'] as String?;
    final placeDistribution = (_consensus!['place_distribution'] as List?)
        ?.take(3)
        .cast<Map<String, dynamic>>()
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFFDC2626).withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.group_work, color: Color(0xFFDC2626), size: 14),
              const SizedBox(width: 6),
              const Text(
                'コンセンサス',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '◎ $firstPick  ($votes社一致)',
                style: const TextStyle(
                  color: Color(0xFFDC2626),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
              const Spacer(),
              Text(
                '信頼度 ${agreementRate.toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
            ],
          ),
          if (placePick != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const SizedBox(width: 20),
                const Text(
                  '複勝',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  placePick,
                  style: const TextStyle(
                    color: Color(0xFFF59E0B),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                if (placeDistribution != null) ...[
                  const SizedBox(width: 8),
                  ...placeDistribution.map((h) {
                    final name = h['horse_name'] as String? ?? '';
                    final rank = h['rank'] as int? ?? 0;
                    return Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFF59E0B).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$rank位 $name',
                          style: const TextStyle(
                            color: Color(0xFFF59E0B),
                            fontSize: 9,
                            height: 1.4,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMatrix(
    List<Map<String, dynamic>> entries,
    List<String> providerNames,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFF1A1A1A)),
          dataRowColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFF1E1E2E);
            }
            return const Color(0xFF0F0F0F);
          }),
          columnSpacing: 8,
          horizontalMargin: 12,
          headingRowHeight: 36,
          dataRowMinHeight: 44,
          dataRowMaxHeight: 52,
          columns: [
            const DataColumn(
              label: Text(
                '枠',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
            ),
            const DataColumn(
              label: Text(
                '馬番',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
            ),
            // Provider columns
            ..._providers.map((p) {
              final prov = (p['provider'] as String? ?? '').split(':').first;
              final color = _providerColor(prov);
              return DataColumn(
                label: Text(
                  prov.length > 7 ? prov.substring(0, 7) : prov,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                ),
              );
            }),
            // Consensus column
            const DataColumn(
              label: Text(
                'コンセンサス',
                style: TextStyle(
                  color: Color(0xFFDC2626),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
            ),
            const DataColumn(
              label: Text(
                '馬名',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
            ),
            const DataColumn(
              label: Text(
                '性齢',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
            ),
            const DataColumn(
              label: Text(
                '騎手',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
            ),
            const DataColumn(
              label: Text(
                '馬体重',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
            ),
            const DataColumn(
              label: Text(
                '単勝',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
              numeric: true,
            ),
          ],
          rows: entries.map((entry) {
            final waku = (entry['frame_number'] as num?)?.toInt() ??
                (((entry['horse_number'] as num?)?.toInt() ?? 1) + 1) ~/ 2;
            final horseNum = (entry['horse_number'] as num?)?.toInt() ?? 0;
            final horseName = entry['horse_name'] as String? ?? '?';
            final ageSex = entry['age_sex'] as String? ?? '';
            final jockey = entry['jockey_name'] as String? ?? '';
            final hw = (entry['horse_weight'] as num?)?.toInt();
            final hwc = (entry['horse_weight_change'] as num?)?.toInt();
            final odds = (entry['win_odds'] as num?)?.toStringAsFixed(1);
            final frameColor = _frameColor(waku);
            final frameText = _frameTextColor(waku);

            return DataRow(
              cells: [
                // 枠
                DataCell(
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: frameColor,
                      borderRadius: BorderRadius.circular(8),
                      border: waku == 1
                          ? Border.all(color: const Color(0xFFB0B0B0))
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$waku',
                      style: TextStyle(
                        color: frameText,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
                // 馬番
                DataCell(
                  Text(
                    '$horseNum',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
                // Provider marks
                ..._providers.map((p) {
                  final (mark, color) = _mark(p, horseName);
                  return DataCell(
                    Center(
                      child: Text(
                        mark,
                        style: TextStyle(
                          color: color,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          height: 1.4,
                        ),
                      ),
                    ),
                  );
                }),
                // Consensus
                DataCell(
                  Center(
                    child: Builder(
                      builder: (context) {
                        final (mark, color) = _consensusMark(horseName);
                        return Text(
                          mark,
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            height: 1.5,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // 馬名
                DataCell(
                  SizedBox(
                    width: 80,
                    child: Text(
                      horseName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                // 性齢
                DataCell(
                  Text(
                    ageSex,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                ),
                // 騎手
                DataCell(
                  SizedBox(
                    width: 56,
                    child: Text(
                      jockey,
                      style: const TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 11,
                        height: 1.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                // 馬体重
                DataCell(
                  Text(
                    hw != null
                        ? '$hw${hwc != null ? '(${hwc >= 0 ? '+' : ''}$hwc)' : ''}'
                        : '─',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                ),
                // 単勝
                DataCell(
                  Text(
                    odds ?? '─',
                    style: TextStyle(
                      color: odds != null
                          ? (double.tryParse(odds)! < 5
                              ? const Color(0xFF4ADE80)
                              : Colors.white)
                          : const Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
