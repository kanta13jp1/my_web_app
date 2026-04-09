// ignore_for_file: require_trailing_commas
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/local_election_reality.dart';
import '../models/public_memo.dart';
import '../services/local_election_share_service.dart';
import '../services/public_memo_service.dart';

/// Composer dialog to preview/edit and post an upcoming-election thread to X.
///
/// Shows weekend-specific tabs (今週末 / 2〜28週後) with election-count
/// badges. Selecting a tab regenerates the thread preview.
class ElectionXPostComposerDialog extends StatefulWidget {
  final LocalElectionRealitySnapshot snapshot;
  final PublicMemo? publishedMemo;
  final LocalElectionShareService shareService;

  /// Optional window index to pre-select (0 = 今週末, 1 = 2週後 …).
  /// When null the dialog auto-selects the first window that has elections.
  final int? initialWindowIndex;

  const ElectionXPostComposerDialog({
    super.key,
    required this.snapshot,
    required this.shareService,
    this.publishedMemo,
    this.initialWindowIndex,
  });

  static Future<void> show(
    BuildContext context, {
    required LocalElectionRealitySnapshot snapshot,
    required LocalElectionShareService shareService,
    PublicMemo? publishedMemo,
    int? initialWindowIndex,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => ElectionXPostComposerDialog(
        snapshot: snapshot,
        shareService: shareService,
        publishedMemo: publishedMemo,
        initialWindowIndex: initialWindowIndex,
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
  static const Color _xBlue = Color(0xFF1DA1F2);

  List<TextEditingController> _controllers = [];
  int _selectedIndex = 0;

  // Cached election counts per window
  late final List<int> _electionCounts;

  @override
  void initState() {
    super.initState();
    final windows = LocalElectionShareService.availableWindows;
    _electionCounts = windows
        .map(
          (w) => widget.shareService
              .schedulesForWindow(snapshot: widget.snapshot, window: w)
              .length,
        )
        .toList();
    // Use caller-supplied index when provided; otherwise auto-select first
    // weekend that has elections.
    final requestedIndex = widget.initialWindowIndex;
    _selectedIndex = requestedIndex != null
        ? requestedIndex.clamp(0, windows.length - 1)
        : _electionCounts.indexWhere((c) => c > 0).clamp(0, windows.length - 1);
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
    final window =
        LocalElectionShareService.availableWindows[_selectedIndex];
    final saturday =
        widget.shareService.scheduleWindowRange(window).start;
    final tweets = widget.shareService.buildUpcomingElectionsThread(
      snapshot: widget.snapshot,
      publicUrl: publicUrl,
      weekendSaturday: saturday,
    );
    _controllers =
        tweets.map((t) => TextEditingController(text: t)).toList();
  }

  void _selectWindow(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
      _buildControllers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 760),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            _buildWeekendSelector(),
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
        color: _xBlue.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
      child: Row(
        children: [
          const Icon(Icons.alternate_email, color: _xBlue, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '地方選挙 X スレッド投稿',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: _xBlue,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekendSelector() {
    final windows = LocalElectionShareService.availableWindows;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 2, bottom: 8),
            child: Text(
              '投開票週末を選択',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(windows.length, (i) {
                final w = windows[i];
                final count = _electionCounts[i];
                final dateRange = widget.shareService
                    .buildWindowDateRangeLabel(w)
                    .replaceAll('/', '/');
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _WeekendChip(
                    label: w.label,
                    dateRange: dateRange,
                    count: count,
                    isSelected: i == _selectedIndex,
                    onTap: () => _selectWindow(i),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTweetList() {
    if (_controllers.isEmpty ||
        (_controllers.length == 1 &&
            _controllers[0].text.endsWith('ありません。'))) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            '選択した週末に選挙データがありません。\n別の週末を選択するか、スケジュールを最新取得してください。',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      shrinkWrap: true,
      itemCount: _controllers.length,
      separatorBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              margin: const EdgeInsets.only(left: 20),
              width: 2,
              height: 20,
              color: Colors.grey.shade300,
            ),
          ],
        ),
      ),
      itemBuilder: (_, i) => _buildTweetEditor(i),
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
                  radius: 13,
                  backgroundColor: _xBlue,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
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
                    fontWeight:
                        isOver ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(width: 6),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.copy_all, size: 15),
              label: const Text('全コピー'),
              onPressed: _controllers.isNotEmpty ? _copyAll : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _xBlue),
              icon: const Icon(Icons.send, size: 15),
              label: const Text('1つ目を投稿'),
              onPressed: _controllers.isNotEmpty
                  ? () => _openXIntent(0)
                  : null,
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
    if (_controllers.isEmpty) return;
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
    if (index >= _controllers.length) return;
    final text = _controllers[index].text;
    final uri = Uri.https('x.com', '/intent/tweet', {'text': text});
    final launched =
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('X投稿画面を開けなかったため、テキストをコピーしました'),
        ),
      );
    }
  }
}

// ---------------------------------------------------------------------------

class _WeekendChip extends StatelessWidget {
  final String label;
  final String dateRange;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _WeekendChip({
    required this.label,
    required this.dateRange,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  static const Color _xBlue = Color(0xFF1DA1F2);

  @override
  Widget build(BuildContext context) {
    final hasElections = count > 0;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? _xBlue
              : hasElections
                  ? _xBlue.withValues(alpha: 0.07)
                  : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? _xBlue
                : hasElections
                    ? _xBlue.withValues(alpha: 0.4)
                    : Colors.grey.shade300,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              dateRange,
              style: TextStyle(
                fontSize: 9,
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.85)
                    : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : hasElections
                        ? _xBlue.withValues(alpha: 0.15)
                        : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                hasElections ? '$count件' : 'なし',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : hasElections
                          ? _xBlue
                          : Colors.grey.shade500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
          child: Icon(icon, size: 15, color: Colors.grey.shade600),
        ),
      ),
    );
  }
}
