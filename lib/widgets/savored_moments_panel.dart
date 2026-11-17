import 'package:flutter/material.dart';

import '../domain/models/savored_moment.dart';
import '../view_models/savored_moment_view_model.dart';

/// "What did you savor today without spending?" — one line, no score.
///
/// Sits beside the prison-mode guard, which counts restraint. This panel
/// counts nothing: it shows today's sentences and recalls a few past ones as
/// written, so that remembering a good moment does not turn into grading it.
class SavoredMomentsPanel extends StatefulWidget {
  const SavoredMomentsPanel({super.key, required this.viewModel});

  final SavoredMomentViewModel viewModel;

  @override
  State<SavoredMomentsPanel> createState() => _SavoredMomentsPanelState();
}

class _SavoredMomentsPanelState extends State<SavoredMomentsPanel> {
  final _controller = TextEditingController();

  SavoredMomentViewModel get _viewModel => widget.viewModel;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final saved = await _viewModel.add(_controller.text);
    if (!mounted) return;
    if (saved) {
      _controller.clear();
    } else if (_viewModel.saveError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_viewModel.saveError!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) {
        final digest = _viewModel.digest;
        return Card(
          key: const Key('savored-moments-panel'),
          margin: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colors.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.local_florist_outlined, color: colors.primary),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '今日、お金を使わずに味わえたこと',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '刑務所モードは我慢を数えますが、我慢だけの毎日は続きません。'
                  'ここだけは点数も分析もつけず、味わったことをそのまま1行だけ残します。',
                  style: TextStyle(height: 1.5),
                ),
                if (_viewModel.isLoading) ...[
                  const SizedBox(height: 10),
                  const LinearProgressIndicator(),
                ],
                const SizedBox(height: 12),
                ..._buildBody(context, digest),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildBody(BuildContext context, SavoredMomentDigest digest) {
    if (!_viewModel.isAuthenticated) {
      return const [Text('ログインすると、味わえたことを残せます。')];
    }
    return [
      if (_viewModel.loadFailed)
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text(
            'これまでの記録を読み込めませんでした。今日の分は通常どおり残せます。',
            key: Key('savored-moments-load-failed'),
            style: TextStyle(height: 1.5),
          ),
        ),
      for (final moment in digest.today)
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.circle, size: 8),
          title: Text(moment.note),
        ),
      TextField(
        key: const Key('savored-moments-input'),
        controller: _controller,
        maxLength: savoredMomentMaxLength,
        enabled: !_viewModel.isSaving,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _save(),
        decoration: const InputDecoration(
          hintText: '例: 夕焼けがきれいだった / 温かいお茶がおいしかった',
        ),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.tonal(
          key: const Key('savored-moments-save'),
          onPressed: _viewModel.isSaving ? null : _save,
          child: const Text('残す'),
        ),
      ),
      if (digest.recent.isNotEmpty) ...[
        const SizedBox(height: 12),
        const Text(
          '最近のあなたが味わえたこと',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        for (final moment in digest.recent)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text(
              '${moment.momentDate.month}/${moment.momentDate.day}  '
              '${moment.note}',
              style: const TextStyle(height: 1.45),
            ),
          ),
      ],
    ];
  }
}
