// ignore_for_file: require_trailing_commas
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/local_election_reality.dart';
import '../models/public_memo.dart';
import '../services/local_election_share_service.dart';
import '../services/public_memo_service.dart';

/// Composer dialog to preview and post an upcoming-election thread to X.
class ElectionXPostComposerDialog extends StatefulWidget {
  final LocalElectionRealitySnapshot snapshot;
  final PublicMemo? publishedMemo;
  final LocalElectionShareService shareService;

  const ElectionXPostComposerDialog({
    super.key,
    required this.snapshot,
    required this.shareService,
    this.publishedMemo,
  });

  static Future<void> show(
    BuildContext context, {
    required LocalElectionRealitySnapshot snapshot,
    required LocalElectionShareService shareService,
    PublicMemo? publishedMemo,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => ElectionXPostComposerDialog(
        snapshot: snapshot,
        shareService: shareService,
        publishedMemo: publishedMemo,
      ),
    );
  }

  @override
  State<ElectionXPostComposerDialog> createState() =>
      _ElectionXPostComposerDialogState();
}

class _ElectionXPostComposerDialogState
    extends State<ElectionXPostComposerDialog> {
  static const int _maxTweetLen = 280;

  List<TextEditingController> _controllers = [];
  int _daysAhead = 7;

  @override
  void initState() {
    super.initState();
    _buildControllers();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _buildControllers() {
    for (final c in _controllers) {
      c.dispose();
    }
    final publicUrl = widget.publishedMemo == null
        ? ''
        : PublicMemoService.buildPublicMemoUrl(widget.publishedMemo!.id);
    final tweets = widget.shareService.buildUpcomingElectionsThread(
      snapshot: widget.snapshot,
      publicUrl: publicUrl,
      daysAhead: _daysAhead,
    );
    _controllers = tweets
        .map((t) => TextEditingController(text: t))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            _buildDaysSelector(),
            Flexible(child: _buildTweetList()),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1DA1F2).withValues(alpha: 0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      child: Row(
        children: [
          const Icon(Icons.alternate_email, color: Color(0xFF1DA1F2), size: 22),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '地方選挙 X スレッド投稿',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1DA1F2),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildDaysSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text('対象期間:', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('今週(7日)'),
            selected: _daysAhead == 7,
            onSelected: (_) => _updateDays(7),
          ),
          const SizedBox(width: 6),
          ChoiceChip(
            label: const Text('2週間'),
            selected: _daysAhead == 14,
            onSelected: (_) => _updateDays(14),
          ),
          const SizedBox(width: 6),
          ChoiceChip(
            label: const Text('1ヶ月'),
            selected: _daysAhead == 30,
            onSelected: (_) => _updateDays(30),
          ),
        ],
      ),
    );
  }

  void _updateDays(int days) {
    if (_daysAhead == days) return;
    setState(() {
      _daysAhead = days;
      _buildControllers();
    });
  }

  Widget _buildTweetList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shrinkWrap: true,
      itemCount: _controllers.length,
      separatorBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              margin: const EdgeInsets.only(left: 20),
              width: 2,
              height: 24,
              color: Colors.grey.shade300,
            ),
          ],
        ),
      ),
      itemBuilder: (context, i) => _buildTweetEditor(i),
    );
  }

  Widget _buildTweetEditor(int index) {
    final controller = _controllers[index];
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final len = value.text.length;
        final isOver = len > _maxTweetLen;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(0xFF1DA1F2),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'ツイート ${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Text(
                  '$len / $_maxTweetLen',
                  style: TextStyle(
                    fontSize: 12,
                    color: isOver ? Colors.red : Colors.grey.shade600,
                    fontWeight: isOver ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(width: 8),
                _SmallIconButton(
                  icon: Icons.copy,
                  tooltip: 'コピー',
                  onTap: () => _copy(index),
                ),
                _SmallIconButton(
                  icon: Icons.open_in_new,
                  tooltip: 'Xで投稿',
                  onTap: () => _openXIntent(index),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: isOver ? Colors.red : Colors.grey.shade300,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: controller,
                maxLines: null,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(10),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.copy_all, size: 16),
              label: const Text('全コピー'),
              onPressed: _copyAll,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1DA1F2),
              ),
              icon: const Icon(Icons.send, size: 16),
              label: const Text('1つ目を投稿'),
              onPressed: () => _openXIntent(0),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copy(int index) async {
    await Clipboard.setData(
      ClipboardData(text: _controllers[index].text),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ツイート${index + 1}をコピーしました'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _copyAll() async {
    final all = _controllers.map((c) => c.text).join('\n\n---\n\n');
    await Clipboard.setData(ClipboardData(text: all));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('スレッド全体をコピーしました'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openXIntent(int index) async {
    final text = _controllers[index].text;
    final uri = Uri.https(
      'x.com',
      '/intent/tweet',
      {'text': text},
    );
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      await Clipboard.setData(ClipboardData(text: text));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('X投稿画面を開けなかったため、テキストをコピーしました')),
      );
    }
  }
}

class _SmallIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _SmallIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 16, color: Colors.grey.shade600),
        ),
      ),
    );
  }
}
