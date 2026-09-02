import 'package:flutter/material.dart';

import '../models/user_knowledge_graph.dart';
import '../services/user_knowledge_graph_service.dart';
import '../view_models/user_knowledge_graph_view_model.dart';

class UserKnowledgeGraphPage extends StatefulWidget {
  final UserKnowledgeGraphViewModel? viewModel;

  const UserKnowledgeGraphPage({super.key, this.viewModel});

  @override
  State<UserKnowledgeGraphPage> createState() => _UserKnowledgeGraphPageState();
}

class _UserKnowledgeGraphPageState extends State<UserKnowledgeGraphPage> {
  late final UserKnowledgeGraphViewModel _viewModel;
  late final bool _ownsViewModel;
  final _textController = TextEditingController();
  final _questionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.viewModel == null;
    _viewModel = widget.viewModel ??
        UserKnowledgeGraphViewModel(
          repository: const SupabaseUserKnowledgeGraphService(),
        );
    _viewModel.initialize();
  }

  @override
  void dispose() {
    _textController.dispose();
    _questionController.dispose();
    if (_ownsViewModel) _viewModel.dispose();
    super.dispose();
  }

  Future<void> _uploadText() async {
    final before = _viewModel.documents.length;
    await _viewModel.uploadText(_textController.text);
    if (_viewModel.documents.length > before) _textController.clear();
  }

  Future<void> _ask() async {
    final question = _questionController.text.trim();
    if (question.isEmpty) return;
    _questionController.clear();
    await _viewModel.ask(question);
  }

  Future<void> _confirmDelete(UserKnowledgeGraphDocument document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('文書を完全に削除しますか？'),
        content: Text(
          '${document.fileName} を Writer とこのアプリの一覧から削除します。'
          'この操作は取り消せません。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB91C1C),
            ),
            child: const Text('完全に削除'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _viewModel.deleteDocument(document.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('マイ・ナレッジグラフ'),
        backgroundColor: const Color(0xFF4338CA),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _viewModel,
          builder: (context, _) {
            if (_viewModel.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            return LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                final uploadPanel = _UploadPanel(
                  viewModel: _viewModel,
                  textController: _textController,
                  onUploadText: _uploadText,
                  onDelete: _confirmDelete,
                );
                final chatPanel = _ChatPanel(
                  viewModel: _viewModel,
                  questionController: _questionController,
                  onAsk: _ask,
                );
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    _ConfigurationBanner(viewModel: _viewModel),
                    if (_viewModel.errorMessage case final error?) ...[
                      const SizedBox(height: 12),
                      MaterialBanner(
                        content: SelectableText(error),
                        leading: const Icon(
                          Icons.error_outline,
                          color: Color(0xFFB91C1C),
                        ),
                        actions: <Widget>[
                          TextButton(
                            onPressed: _viewModel.clearError,
                            child: const Text('閉じる'),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(flex: 5, child: uploadPanel),
                          const SizedBox(width: 16),
                          Expanded(flex: 7, child: chatPanel),
                        ],
                      )
                    else ...<Widget>[
                      uploadPanel,
                      const SizedBox(height: 16),
                      chatPanel,
                    ],
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ConfigurationBanner extends StatelessWidget {
  final UserKnowledgeGraphViewModel viewModel;

  const _ConfigurationBanner({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final configured = viewModel.configured;
    final color =
        configured ? const Color(0xFF047857) : const Color(0xFFB45309);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        border: Border.all(color: color.withAlpha(100)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            configured ? Icons.verified_user_outlined : Icons.key_off_outlined,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  configured ? 'Writer API 接続済み' : 'Writer API の設定が必要です',
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  configured
                      ? 'API キーはサーバーの Secret にのみ保存され、ブラウザーには送信されません。'
                      : '管理者が Supabase Secret WRITER_API_KEY を設定すると利用できます。'
                          'API キーをこの画面へ入力する必要はありません。',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadPanel extends StatelessWidget {
  final UserKnowledgeGraphViewModel viewModel;
  final TextEditingController textController;
  final Future<void> Function() onUploadText;
  final Future<void> Function(UserKnowledgeGraphDocument document) onDelete;

  const _UploadPanel({
    required this.viewModel,
    required this.textController,
    required this.onUploadText,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            '自分の文書を接続',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text('PDF・Office・TXT・CSV・HTML、または貼り付けたテキストに対応します（最大4MB）。'),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            key: const Key('userKgPickFileButton'),
            onPressed: viewModel.canUpload ? viewModel.pickAndUpload : null,
            icon: viewModel.isUploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file_outlined),
            label: const Text('ファイルを選択して登録'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('userKgTextInput'),
            controller: textController,
            minLines: 4,
            maxLines: 8,
            enabled: viewModel.canUpload,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'テキストを直接登録',
              hintText: '議事録、仕様、FAQ などを貼り付け',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const Key('userKgUploadTextButton'),
            onPressed: viewModel.canUpload ? onUploadText : null,
            icon: const Icon(Icons.add_link_outlined),
            label: const Text('テキストをナレッジグラフへ追加'),
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '登録済み文書 (${viewModel.documents.length})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (viewModel.graphReady)
                const Tooltip(
                  message: 'ユーザー専用グラフ',
                  child: Icon(Icons.lock_outline, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (viewModel.documents.isEmpty)
            const _EmptyHint(text: '文書を追加すると、このユーザー専用のグラフが作成されます。')
          else
            for (final document in viewModel.documents)
              _DocumentTile(
                document: document,
                deleting: viewModel.isDeleting,
                onDelete: () => onDelete(document),
              ),
          const SizedBox(height: 10),
          Text(
            '文書本体は Writer に保持されます。削除すると Writer 側からも完全に削除されます。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatPanel extends StatelessWidget {
  final UserKnowledgeGraphViewModel viewModel;
  final TextEditingController questionController;
  final Future<void> Function() onAsk;

  const _ChatPanel({
    required this.viewModel,
    required this.questionController,
    required this.onAsk,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            '文書に質問',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text('回答には、根拠となった文書と抜粋をインライン番号で表示します。'),
          const SizedBox(height: 14),
          if (viewModel.messages.isEmpty)
            const _EmptyHint(text: '文書を登録して、内容について自然な言葉で質問してください。')
          else
            for (final message in viewModel.messages)
              _MessageBubble(message: message),
          if (viewModel.isAsking) ...<Widget>[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 14),
          TextField(
            key: const Key('userKgQuestionInput'),
            controller: questionController,
            enabled: viewModel.canAsk,
            minLines: 2,
            maxLines: 5,
            maxLength: 2000,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: viewModel.documents.isEmpty
                  ? '先に文書を登録してください'
                  : '例: この仕様のリリース条件は？',
              prefixIcon: const Icon(Icons.chat_bubble_outline),
            ),
            onSubmitted: (_) => onAsk(),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              key: const Key('userKgAskButton'),
              onPressed: viewModel.canAsk ? onAsk : null,
              icon: const Icon(Icons.send_outlined),
              label: const Text('質問する'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  final UserKnowledgeGraphDocument document;
  final bool deleting;
  final VoidCallback onDelete;

  const _DocumentTile({
    required this.document,
    required this.deleting,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final ready = <String>{
      'completed',
      'ready',
      'processed',
    }.contains(document.processingStatus.toLowerCase());
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        leading: Icon(
          ready ? Icons.description_outlined : Icons.hourglass_top_outlined,
          color: ready ? const Color(0xFF047857) : const Color(0xFFB45309),
        ),
        title: Text(
          document.fileName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${_formatBytes(document.sizeBytes)} ・ ${ready ? '検索可能' : '処理中'}',
        ),
        trailing: IconButton(
          tooltip: 'Writer から完全に削除',
          onPressed: deleting ? null : onDelete,
          icon: const Icon(Icons.delete_outline),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final UserKnowledgeGraphMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == UserKnowledgeGraphMessageRole.user;
    final background =
        isUser ? const Color(0xFFE0E7FF) : const Color(0xFFF8FAFC);
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        key: ValueKey<String>('userKgMessage-${message.text}'),
        width: isUser ? null : double.infinity,
        constraints: const BoxConstraints(maxWidth: 720),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: background,
          border: Border.all(color: const Color(0xFFC7D2FE)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SelectableText(message.text),
            if (message.citations.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              for (final citation in message.citations)
                _CitationCard(citation: citation),
            ],
          ],
        ),
      ),
    );
  }
}

class _CitationCard extends StatelessWidget {
  final UserKnowledgeGraphCitation citation;

  const _CitationCard({required this.citation});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey<int>(citation.index),
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CircleAvatar(
            radius: 13,
            backgroundColor: const Color(0xFF4338CA),
            foregroundColor: Colors.white,
            child: Text(
              '${citation.index}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  citation.fileName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                SelectableText(citation.snippet),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  final Widget child;

  const _PanelCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;

  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '$bytes B';
}
