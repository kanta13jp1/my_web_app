import 'package:flutter/material.dart';

import '../services/mcp_file_search_service.dart';

class McpFileSearchPage extends StatefulWidget {
  const McpFileSearchPage({super.key, this.gateway});

  final McpFileSearchGateway? gateway;

  @override
  State<McpFileSearchPage> createState() => _McpFileSearchPageState();
}

class _McpFileSearchPageState extends State<McpFileSearchPage> {
  final _queryController = TextEditingController();
  late final McpFileSearchGateway _gateway;

  List<McpFileConnector> _connectors = const [];
  List<McpFileSearchResult> _results = const [];
  final List<McpFileContextAttachment> _attachments = [];
  final Set<String> _attachingFileIds = {};
  String? _selectedConnectorId;
  String? _error;
  bool _loadingConnectors = true;
  bool _searching = false;
  int _deniedCount = 0;
  int _unsafeCount = 0;

  @override
  void initState() {
    super.initState();
    _gateway = widget.gateway ?? McpFileSearchService();
    _loadConnectors();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _loadConnectors() async {
    try {
      final connectors = await _gateway.loadConnectors();
      if (!mounted) return;
      setState(() {
        _connectors = connectors;
        _selectedConnectorId = connectors.firstOrNull?.id;
        _loadingConnectors = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '接続先を読み込めませんでした: $error';
        _loadingConnectors = false;
      });
    }
  }

  Future<void> _search() async {
    final connectorId = _selectedConnectorId;
    final query = _queryController.text.trim();
    if (connectorId == null || connectorId.isEmpty || query.isEmpty) return;

    setState(() {
      _searching = true;
      _error = null;
      _deniedCount = 0;
      _unsafeCount = 0;
    });
    try {
      final response = await _gateway.search(
        connectorId: connectorId,
        query: query,
      );
      if (!mounted) return;
      setState(() {
        _results = response.results;
        _deniedCount = response.deniedCount;
        _unsafeCount = response.unsafeCount;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _results = const [];
        _error = '検索に失敗しました: $error';
      });
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _attach(McpFileSearchResult result) async {
    if (_attachingFileIds.contains(result.id) ||
        _attachments.any((item) => item.uri == result.uri)) {
      return;
    }
    setState(() {
      _attachingFileIds.add(result.id);
      _error = null;
    });
    try {
      final attachment = await _gateway.attachContext(result);
      if (!mounted) return;
      setState(() => _attachments.add(attachment));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${attachment.title} を追加しました')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'ファイルを追加できませんでした: $error');
    } finally {
      if (mounted) {
        setState(() => _attachingFileIds.remove(result.id));
      }
    }
  }

  void _openChat() {
    Navigator.of(context).pushNamed(
      '/ai-assistant-chat',
      arguments: <String, dynamic>{
        'context_file_ids': _attachments.map((item) => item.id).toList(),
        'context_titles': _attachments.map((item) => item.title).toList(),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('外部ファイル検索'),
        actions: [
          IconButton(
            onPressed: _loadingConnectors ? null : _loadConnectors,
            tooltip: '接続先を再読み込み',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Material(
            color: theme.colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final connectorField = DropdownButtonFormField<String>(
                    key: ValueKey(_selectedConnectorId),
                    initialValue: _selectedConnectorId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: '接続先',
                      prefixIcon: Icon(Icons.cloud_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: _connectors
                        .map(
                          (connector) => DropdownMenuItem<String>(
                            value: connector.id,
                            child: Text(
                              connector.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _searching
                        ? null
                        : (value) =>
                              setState(() => _selectedConnectorId = value),
                  );
                  final queryField = TextField(
                    key: const Key('mcp_file_query'),
                    controller: _queryController,
                    enabled: !_loadingConnectors && _connectors.isNotEmpty,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      labelText: '検索',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        key: const Key('mcp_file_search_button'),
                        onPressed: _searching ? null : _search,
                        tooltip: '検索を実行',
                        icon: _searching
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.arrow_forward),
                      ),
                    ),
                  );
                  if (constraints.maxWidth < 680) {
                    return Column(
                      children: [
                        connectorField,
                        const SizedBox(height: 12),
                        queryField,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      SizedBox(width: 260, child: connectorField),
                      const SizedBox(width: 12),
                      Expanded(child: queryField),
                    ],
                  );
                },
              ),
            ),
          ),
          if (_error != null)
            MaterialBanner(
              content: Text(_error!),
              leading: const Icon(Icons.error_outline),
              actions: [
                IconButton(
                  onPressed: () => setState(() => _error = null),
                  tooltip: '閉じる',
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          if (_deniedCount > 0 || _unsafeCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '非表示: 権限 $_deniedCount / 安全性 $_unsafeCount',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          Expanded(child: _buildResults(theme)),
          if (_attachments.isNotEmpty) _buildAttachmentBar(theme),
        ],
      ),
    );
  }

  Widget _buildResults(ThemeData theme) {
    if (_loadingConnectors) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_connectors.isEmpty) {
      return const Center(child: Text('利用可能な接続先がありません'));
    }
    if (_results.isEmpty) {
      return Center(
        child: Text(
          _searching ? '検索中...' : '検索結果はありません',
          style: theme.textTheme.bodyLarge,
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _buildResult(_results[index], theme),
    );
  }

  Widget _buildResult(McpFileSearchResult result, ThemeData theme) {
    final attached = _attachments.any((item) => item.uri == result.uri);
    final attaching = _attachingFileIds.contains(result.id);
    final modified = result.modifiedAt?.toLocal();
    final dateLabel = modified == null
        ? ''
        : '${modified.year}/${modified.month.toString().padLeft(2, '0')}/'
              '${modified.day.toString().padLeft(2, '0')}';
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: const SizedBox.square(
          dimension: 40,
          child: Icon(Icons.insert_drive_file_outlined),
        ),
        title: Text(result.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (result.snippet.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                result.snippet,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 6),
            Text(
              [
                result.connectorName,
                result.mimeType,
                dateLabel,
              ].where((value) => value.isNotEmpty).join('  ·  '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        trailing: SizedBox.square(
          dimension: 48,
          child: attaching
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  key: Key('mcp_file_attach_${result.id}'),
                  onPressed: result.contextEligible && !attached
                      ? () => _attach(result)
                      : null,
                  tooltip: attached
                      ? '追加済み'
                      : result.contextEligible
                      ? 'AIコンテキストに追加'
                      : '追加できません',
                  icon: Icon(attached ? Icons.check_circle : Icons.add_link),
                ),
        ),
      ),
    );
  }

  Widget _buildAttachmentBar(ThemeData theme) {
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.attach_file, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_attachments.length}件: '
                  '${_attachments.map((item) => item.title).join(', ')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: () => setState(_attachments.clear),
                tooltip: 'すべて解除',
                icon: const Icon(Icons.clear_all),
              ),
              FilledButton.icon(
                key: const Key('mcp_file_open_chat'),
                onPressed: _openChat,
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('AIチャット'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
