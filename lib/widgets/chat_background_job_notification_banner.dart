import 'package:flutter/material.dart';

import '../models/chat_background_job.dart';
import '../services/chat_background_job_center.dart';

class ChatBackgroundJobNotificationBanner extends StatelessWidget {
  const ChatBackgroundJobNotificationBanner({
    super.key,
    required this.jobCenter,
  });

  final ChatBackgroundJobCenter jobCenter;

  Color _accentColor(ChatBackgroundJobStatus status) {
    switch (status) {
      case ChatBackgroundJobStatus.queued:
        return const Color(0xFF94A3B8);
      case ChatBackgroundJobStatus.running:
        return const Color(0xFF38BDF8);
      case ChatBackgroundJobStatus.completed:
        return const Color(0xFF34D399);
      case ChatBackgroundJobStatus.failed:
        return const Color(0xFFF87171);
    }
  }

  IconData _statusIcon(ChatBackgroundJobStatus status) {
    switch (status) {
      case ChatBackgroundJobStatus.queued:
        return Icons.schedule;
      case ChatBackgroundJobStatus.running:
        return Icons.sync;
      case ChatBackgroundJobStatus.completed:
        return Icons.check_circle_outline;
      case ChatBackgroundJobStatus.failed:
        return Icons.error_outline;
    }
  }

  Future<void> _showJobDetailDialog(
    BuildContext context,
    ChatBackgroundJob job,
  ) async {
    final detail = job.resultDetail ?? job.errorMessage ?? job.summary;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: Key('bg_job_detail_dialog_${job.id}'),
        title: Text(job.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('状態: ${job.status.label} (${job.source})'),
              const SizedBox(height: 8),
              Text('概要: ${job.summary}'),
              const SizedBox(height: 8),
              const Text(
                '詳細・実行結果',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(detail),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: jobCenter,
      builder: (context, _) {
        final visibleJobs = jobCenter.jobs.take(3).toList(growable: false);
        if (visibleJobs.isEmpty) {
          return const SizedBox.shrink();
        }
        return Container(
          key: const Key('chat_background_job_banner'),
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Column(
            children: [
              for (final job in visibleJobs)
                _buildJobTile(
                  context: context,
                  job: job,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildJobTile({
    required BuildContext context,
    required ChatBackgroundJob job,
  }) {
    final accent = _accentColor(job.status);
    final progressValue = job.progress;

    return Semantics(
      container: true,
      liveRegion: true,
      label: '${job.title} ${job.status.label}: ${job.summary}',
      child: Container(
        key: Key('bg_job_item_${job.id}'),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accent.withAlpha(140)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_statusIcon(job.status), size: 16, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${job.title} · ${job.status.label}',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ),
                TextButton(
                  key: Key('bg_job_detail_button_${job.id}'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(48, 28),
                  ),
                  onPressed: () => _showJobDetailDialog(context, job),
                  child: const Text('詳細', style: TextStyle(fontSize: 12)),
                ),
                IconButton(
                  key: Key('bg_job_dismiss_button_${job.id}'),
                  tooltip: '通知を閉じる',
                  iconSize: 16,
                  color: Colors.white54,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: () => jobCenter.dismissJob(job.id),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text(
              job.summary,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            if (job.status == ChatBackgroundJobStatus.running)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressValue,
                    minHeight: 4,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
