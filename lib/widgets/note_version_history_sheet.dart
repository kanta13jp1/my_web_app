import 'package:flutter/material.dart';

import '../controllers/note_version_history_controller.dart';
import '../services/note_version_history_service.dart';

class NoteVersionHistorySheet extends StatefulWidget {
  const NoteVersionHistorySheet({
    super.key,
    required this.repository,
    required this.noteId,
  });

  final NoteVersionHistoryRepository repository;
  final String noteId;

  @override
  State<NoteVersionHistorySheet> createState() => _NoteVersionHistorySheetState();
}

class _NoteVersionHistorySheetState extends State<NoteVersionHistorySheet> {
  late final NoteVersionHistoryController _controller;

  @override
  void initState() {
    super.initState();
    _controller = NoteVersionHistoryController(
      repository: widget.repository,
      noteId: widget.noteId,
    )..loadMore();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _date(NoteVersionSummary version) {
    final date = version.savedAt?.toLocal();
    if (date == null) return '保存日時不明';
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/'
        '${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}:'
        '${date.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.85,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Column(
              children: [
                Row(
                  children: [
                    if (_controller.selected != null)
                      IconButton(
                        tooltip: '履歴一覧に戻る',
                        onPressed: _controller.showList,
                        icon: const Icon(Icons.arrow_back),
                      ),
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'バージョン履歴',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '履歴を閉じる',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Divider(height: 1),
                Expanded(
                  child: _controller.selected == null
                      ? _list()
                      : _preview(context),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _list() => ListView.builder(
        key: const PageStorageKey('note-history-list'),
        padding: const EdgeInsets.all(12),
        itemCount: _controller.items.length + 1,
        itemBuilder: (context, index) {
          if (index < _controller.items.length) {
            final item = _controller.items[index];
            return ListTile(
              key: ValueKey('history-${item.id}'),
              leading: const Icon(Icons.history),
              title: Text(
                item.displayTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${_date(item)}\n'
                '${item.isEvernote ? 'Evernoteから移行した履歴' : '本サイトの履歴'}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _controller.select(item),
            );
          }
          return Column(
            children: [
              if (_controller.loading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                )
              else if (_controller.pageError != null) ...[
                Text(_controller.pageError!, textAlign: TextAlign.center),
                TextButton(
                  onPressed: _controller.loadMore,
                  child: const Text('履歴の読み込みを再試行'),
                ),
              ] else if (_controller.hasMore)
                TextButton(
                  onPressed: _controller.loadMore,
                  child: const Text('さらに古い履歴を読み込む'),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _controller.items.isEmpty
                        ? '保存済みバージョンがありません'
                        : '取得できる履歴をすべて表示しました',
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          );
        },
      );

  Widget _preview(BuildContext context) {
    if (_controller.detailLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final detail = _controller.detail;
    if (detail == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(_controller.detailError ?? '履歴を選択してください'),
          TextButton(
            onPressed: () => _controller.select(_controller.selected!),
            child: const Text('本文・添付情報の読み込みを再試行'),
          ),
        ],
      );
    }
    final summary = detail.summary;
    return CustomScrollView(
      key: ValueKey('history-preview-${summary.id}'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
        SelectableText(
          summary.displayTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(_date(summary)),
        if (summary.isEvernote) ...[
          Text(summary.sourceVerified ? 'Evernote履歴：検証済み' : 'Evernote履歴：未検証'),
          const Text(
            '移行原本の読み取り専用プレビューです。'
            '添付を含む安全な復元処理の検証が完了するまで、上書き復元はできません。',
          ),
          if (detail.tags.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: detail.tags.map((tag) => Chip(label: Text(tag))).toList(),
            ),
        ],
        const SizedBox(height: 16),
        const Text('保存されたMarkdown本文（読み取り専用）'),
        const Text('外部画像・リンクは自動で読み込みません。'),
        const SizedBox(height: 8),
        SelectableText(detail.content.isEmpty ? '（本文なし）' : detail.content),
        const SizedBox(height: 16),
        if (summary.isEvernote) ...[
          Text('履歴に保存された添付：${detail.attachments.length}件'),
        ] else ...[
          const Text(
            'この履歴の復元対象はタイトルと本文です。'
            'タグ・添付ファイル・タスク・リマインダーは復元対象ではありません。',
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => Navigator.pop(context, detail),
              icon: const Icon(Icons.restore),
              label: const Text('このタイトル・本文を復元'),
            ),
          ),
        ],
              ],
            ),
          ),
        ),
        if (summary.isEvernote)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.builder(
              itemCount: detail.attachments.length,
              itemBuilder: (context, index) {
                final attachment = detail.attachments[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.attach_file),
                  title: Text(attachment.fileName),
                  subtitle: Text(
                    '${attachment.mimeType} / ${attachment.fileSize} bytes',
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
