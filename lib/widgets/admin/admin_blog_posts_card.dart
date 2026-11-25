import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminBlogPostsCard extends StatelessWidget {
  const AdminBlogPostsCard({
    super.key,
    required this.posts,
    required this.loading,
    required this.onRefresh,
    required this.onUpdateStatus,
    this.onOpenUrl,
  });

  final List<Map<String, dynamic>> posts;
  final bool loading;
  final VoidCallback onRefresh;
  final void Function(String id, String status) onUpdateStatus;
  final Future<void> Function(Uri uri)? onOpenUrl;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color statusColor(String status) {
      switch (status) {
        case 'posted':
          return const Color(0xFF0D9488);
        case 'skipped':
          return const Color(0xFF9CA3AF);
        default:
          return const Color(0xFFFF6B35);
      }
    }

    String statusLabel(String status) {
      switch (status) {
        case 'posted':
          return '投稿済';
        case 'skipped':
          return 'スキップ';
        default:
          return '下書き';
      }
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.article, color: Color(0xFF6366F1)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'ブログ投稿管理',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: onRefresh,
                  tooltip: '更新',
                ),
              ],
            ),
            Text(
              'Claude Schedule が生成した下書き・投稿状況を管理',
              style: TextStyle(
                fontSize: 12,
                color:
                    isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            if (loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (posts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'まだブログ下書きがありません。\nblog-draft Schedule タスクが実行されると自動追加されます。',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF475569),
                    height: 1.5,
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: posts.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final post = posts[index];
                  final status = post['status']?.toString() ?? 'draft';
                  final title = post['title']?.toString() ?? '(無題)';
                  final platforms = (post['target_platforms'] as List?)
                          ?.map((e) => e.toString())
                          .join(', ') ??
                      '';
                  final postUrl = post['url']?.toString() ?? '';
                  final createdAt = post['created_at'] != null
                      ? DateTime.tryParse(post['created_at'].toString())
                      : null;
                  final dateStr = createdAt != null
                      ? '${createdAt.month}/${createdAt.day}'
                      : '';

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  height: 1.5,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (platforms.isNotEmpty)
                                Text(
                                  '$platforms  $dateStr',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF475569),
                                    height: 1.5,
                                  ),
                                ),
                              if (postUrl.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    final uri = Uri.parse(postUrl);
                                    if (onOpenUrl != null) {
                                      onOpenUrl!(uri);
                                    } else {
                                      launchUrl(
                                        uri,
                                        mode: LaunchMode.externalApplication,
                                      );
                                    }
                                  },
                                  child: Text(
                                    postUrl,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF4338CA),
                                      decoration: TextDecoration.underline,
                                      height: 1.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          initialValue: status,
                          onSelected: (val) =>
                              onUpdateStatus(post['id'].toString(), val),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'draft',
                              child: Text('下書き'),
                            ),
                            PopupMenuItem(
                              value: 'posted',
                              child: Text('投稿済にする'),
                            ),
                            PopupMenuItem(
                              value: 'skipped',
                              child: Text('スキップ'),
                            ),
                          ],
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor(
                                status,
                              ).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  statusLabel(status),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: statusColor(status),
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  Icons.arrow_drop_down,
                                  size: 14,
                                  color: statusColor(status),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
