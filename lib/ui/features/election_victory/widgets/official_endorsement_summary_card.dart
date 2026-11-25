import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../data/kokumin_source_verification.dart';
import '../../../../models/election_intelligence.dart';
import 'official_endorsement_scope_note.dart';

/// The production candidate card, also rendered by the isolated browser fixture.
class OfficialEndorsementSummaryCard extends StatelessWidget {
  const OfficialEndorsementSummaryCard({
    super.key,
    required this.snapshot,
    required this.onOpenSource,
  });

  final OfficialEndorsementSnapshot snapshot;
  final ValueChanged<String> onOpenSource;

  static final DateFormat _dateOnlyFormat = DateFormat('yyyy/MM/dd', 'ja_JP');
  static final NumberFormat _numberFormat = NumberFormat('#,##0', 'ja_JP');

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF2563EB);
    final incumbent = snapshot.incumbentCount;
    final newcomer = snapshot.newcomerCount;
    final former = snapshot.formerCount;
    final prefectural = snapshot.prefecturalCount;
    final municipal = snapshot.municipalCount;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.how_to_reg_outlined, size: 18, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '公認予定候補の掲載状況',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildMiniStatChip(
                '公認掲載',
                snapshot.totalCount,
                color: accent,
                suffix: '件',
              ),
              if (incumbent > 0)
                _buildMiniStatChip(
                  '掲載内の現職',
                  incumbent,
                  color: const Color(0xFF0F766E),
                  suffix: '件',
                ),
              if (newcomer > 0)
                _buildMiniStatChip(
                  '掲載内の新人',
                  newcomer,
                  color: const Color(0xFF7C3AED),
                  suffix: '件',
                ),
              if (former > 0)
                _buildMiniStatChip(
                  '掲載内の元職',
                  former,
                  color: const Color(0xFFB45309),
                  suffix: '件',
                ),
              _buildMiniStatChip(
                '掲載地域',
                snapshot.prefectureCount,
                suffix: '/47都道府県',
                color: const Color(0xFF64748B),
              ),
            ],
          ),
          if (prefectural + municipal > 0) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (prefectural > 0)
                  _buildMiniStatChip(
                    '都道府県議',
                    prefectural,
                    color: const Color(0xFF0EA5E9),
                    suffix: '件',
                  ),
                if (municipal > 0)
                  _buildMiniStatChip(
                    '市区町村議',
                    municipal,
                    color: const Color(0xFF16A34A),
                    suffix: '件',
                  ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          OfficialEndorsementScopeNote(snapshot: snapshot),
          const SizedBox(height: 6),
          Text(
            kokuminSourceVerificationLabel(
              sourceUrl: snapshot.sourceUrl,
              sourceDate: snapshot.sourceAsOf,
              sourceDocumentSha256: snapshot.sourceDocumentSha256,
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: Builder(
              builder: (tileContext) => Material(
                type: MaterialType.transparency,
                textStyle: DefaultTextStyle.of(tileContext).style,
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  dense: true,
                  title: const Text('都道府県別の公認掲載件数'),
                  subtitle: Text('${snapshot.prefectureCount}都道府県'),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final item in snapshot.prefectures)
                            _buildOfficialEndorsementPrefectureChip(item),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => onOpenSource(snapshot.sourceUrl),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(
                '党公式の公認予定候補一覧を開く'
                '(${_formatAsOfDate(snapshot.sourceAsOf)}現在)',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficialEndorsementPrefectureChip(
    OfficialEndorsementPrefecture endorsement,
  ) {
    const color = Color(0xFF1D4ED8);
    final breakdown =
        endorsement.hasBreakdown ? ' (${endorsement.breakdownLabel})' : '';
    final assemblyBreakdown = endorsement.hasAssemblyBreakdown
        ? ' [${endorsement.assemblyBreakdownLabel}]'
        : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Text(
        '${endorsement.prefecture} ${_formatInt(endorsement.totalCount)}件'
        '$breakdown$assemblyBreakdown',
        style: const TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
      ),
    );
  }

  Widget _buildMiniStatChip(
    String label,
    int value, {
    required Color color,
    String suffix = '人',
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label ${_formatInt(value)}$suffix',
        style: TextStyle(
          color: color.withValues(alpha: 0.95),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
      ),
    );
  }

  String _formatAsOfDate(String iso) {
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) {
      return iso;
    }
    return _dateOnlyFormat.format(parsed);
  }

  String _formatInt(int value) => _numberFormat.format(value);
}
