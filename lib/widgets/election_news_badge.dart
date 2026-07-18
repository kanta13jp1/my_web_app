import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// 県連カードに公式発表 news を表示するバッジ。
///
/// データ取得は行わない。ページ側が PrefectureElectionNewsService で
/// 全県分を一括取得し、該当県の news を [newsItems] として渡す
/// (旧実装は県ごとに個別 Supabase クエリを発行しており本番で
/// 県数分の fetch + CORS preflight が発生していた)。
class ElectionNewsBadge extends StatelessWidget {
  final List<Map<String, dynamic>> newsItems;

  const ElectionNewsBadge({super.key, required this.newsItems});

  Future<void> _openUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (newsItems.isEmpty) return const SizedBox.shrink();

    const accent = Color(0xFF4F46E5);

    return Column(
      children: [
        for (final item in newsItems) ...[
          _buildBadge(context, item, accent),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildBadge(
    BuildContext context,
    Map<String, dynamic> item,
    Color accent,
  ) {
    final title = item['news_title'] as String? ?? '';
    final summary = item['news_summary'] as String? ?? '';
    final sourceUrl = item['news_source_url'] as String? ?? '';
    final sourceLabel = item['news_source_label'] as String? ?? '出典';
    final announcedAt = item['announced_at'] as String? ?? '';
    final total = item['total_candidate_target'] as int?;
    final confirmed = item['confirmed_candidate_count'] as int?;
    final publicRec = item['public_recruitment_count'] as int?;
    final rep = item['representative_name'] as String? ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.campaign_outlined, size: 16, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '📢 公式発表${announcedAt.isNotEmpty ? ' ($announcedAt)' : ''}',
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              summary,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
              ),
            ),
          ],
          if (total != null || confirmed != null || publicRec != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (total != null) _buildValueChip('計 $total 人', accent),
                if (confirmed != null)
                  _buildValueChip('確定 $confirmed 人', const Color(0xFF059669)),
                if (publicRec != null)
                  _buildValueChip('公募 $publicRec 人', const Color(0xFF0891B2)),
              ],
            ),
          ],
          if (rep.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '代表: $rep',
              style: TextStyle(
                fontSize: 11,
                height: 1.5,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.55),
              ),
            ),
          ],
          if (sourceUrl.isNotEmpty) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => _openUrl(sourceUrl),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.open_in_new,
                    size: 12,
                    color: accent.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    sourceLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: accent,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildValueChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w700,
          height: 1.5,
        ),
      ),
    );
  }
}
