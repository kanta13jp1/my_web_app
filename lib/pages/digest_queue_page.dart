import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/digest_queue_service.dart';
import '../services/wip_limit_legacy_bridge_service.dart';

class DigestQueuePage extends StatefulWidget {
  const DigestQueuePage({
    super.key,
    this.service,
    this.legacyService,
  });

  final DigestQueueService? service;
  final WipLimitLegacyBridgeService? legacyService;

  @override
  State<DigestQueuePage> createState() => _DigestQueuePageState();
}

class _DigestQueuePageState extends State<DigestQueuePage> {
  late final DigestQueueService _service;
  late final WipLimitLegacyBridgeService _legacyService;

  List<DigestQueueItem> _items = const <DigestQueueItem>[];
  List<LegacyWipItem> _legacyItems = const <LegacyWipItem>[];
  String? _legacyWarning;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? const DigestQueueService();
    _legacyService = widget.legacyService ??
        WipLimitLegacyBridgeService(client: Supabase.instance.client);
    _loadItems();
  }

  Future<void> _loadItems() async {
    final items = await _service.loadItems();
    final legacyResult = await _legacyService.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _items = items;
      _legacyItems = legacyResult.items;
      _legacyWarning = legacyResult.warning;
      _isLoading = false;
    });
  }

  Future<void> _showAddDialog() async {
    final titleController = TextEditingController();
    final noteController = TextEditingController();
    var selectedDomain = DigestQueueService.builtinDomains.first;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('新しい摂取を登録'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'タイトル',
                        hintText: '例: 積読の本 / 経済学の講義 / 英単語帳',
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedDomain,
                      decoration: const InputDecoration(
                        labelText: '領域',
                      ),
                      items: DigestQueueService.builtinDomains
                          .map(
                            (domain) => DropdownMenuItem<String>(
                              value: domain,
                              child: Text(domain),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setDialogState(() {
                          selectedDomain = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(
                        labelText: '消化の観点',
                        hintText: '例: 読んだら3つ要点を書く / 章末問題まで終える',
                      ),
                      minLines: 2,
                      maxLines: 4,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('キャンセル'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('登録'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      final result = await _service.addItem(
        title: titleController.text,
        domain: selectedDomain,
        note: noteController.text,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _items = result.items;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.queued
                ? '今は「${result.item.domain}」を消化中なので、「${result.item.title}」は後でやるに入れました。'
                : '「${result.item.title}」を今消化中に追加しました。',
          ),
        ),
      );
    } on ArgumentError {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('タイトルを入力してください。')),
      );
    }
  }

  Future<void> _showProgressDialog(DigestQueueItem item) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('消化メモ: ${item.title}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '何を理解したか / 何を実行したか',
            hintText: '例: 第2章まで読んで、要点を3つノートに整理した',
          ),
          minLines: 3,
          maxLines: 5,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('記録'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      final items = await _service.recordProgress(item.id, controller.text);
      if (!mounted) {
        return;
      }
      setState(() {
        _items = items;
      });
    } on ArgumentError {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('消化メモを入力してください。')),
      );
    }
  }

  Future<void> _completeItem(DigestQueueItem item) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('完了: ${item.title}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '締めのメモ',
            hintText: '例: 要約を1枚にまとめ、次の本に進める状態になった',
          ),
          minLines: 2,
          maxLines: 4,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('戻る'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('完了にする'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    final items = await _service.completeItem(
      item.id,
      note: controller.text,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _items = items;
    });

    final nextActive =
        DigestQueueService.findActiveForDomain(items, item.domain);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          nextActive != null && nextActive.id != item.id
              ? '「${item.title}」を完了しました。次は「${nextActive.title}」を消化します。'
              : '「${item.title}」を完了しました。',
        ),
      ),
    );
  }

  Future<void> _activateItem(DigestQueueItem item) async {
    try {
      final items = await _service.activateBacklogItem(item.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _items = items;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「${item.title}」を今消化中にしました。')),
      );
    } on StateError {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('その領域にはすでに今消化中の項目があります。'),
        ),
      );
    }
  }

  Future<void> _deleteItem(DigestQueueItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('項目を削除'),
        content: Text('「${item.title}」を一覧から外しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    final items = await _service.deleteItem(item.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _items = items;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('消化してから次へ'),
        actions: [
          IconButton(
            onPressed: _showAddDialog,
            icon: const Icon(Icons.add_circle_outline),
            tooltip: '新しい項目',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.playlist_add),
        label: const Text('追加'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadItems,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  _buildHeroCard(),
                  const SizedBox(height: 16),
                  _buildSummaryRow(),
                  const SizedBox(height: 20),
                  Text(
                    '今消化中',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 12),
                  ...DigestQueueService.builtinDomains.map(_buildDomainCard),
                  const SizedBox(height: 24),
                  Text(
                    '後でやる',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 12),
                  _buildBacklogSection(),
                  const SizedBox(height: 24),
                  Text(
                    '完了',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 12),
                  _buildCompletedSection(),
                  if (_legacyItems.isNotEmpty || _legacyWarning != null) ...[
                    const SizedBox(height: 24),
                    Text(
                      '統合前のWIP項目',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '旧「消化してから次を食え」で保存した項目です。ここから進捗を更新できます。',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    _buildLegacyWipSection(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF0F172A),
            Color(0xFF1D4ED8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '未消化のまま、新しいものを増やさない',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.5,
            ),
          ),
          SizedBox(height: 10),
          Text(
            '読んでいる本があるなら、まずその本を咀嚼する。勉強中のものがあるなら、まずそれを使える形にする。同じ領域では1件だけを今消化中にして、次は後でやるへ送ります。',
            style: TextStyle(
              color: Colors.white70,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow() {
    final activeCount = _items.where((item) => item.isActive).length;
    final backlogCount = _items.where((item) => item.isBacklog).length;
    final completedCount = _items.where((item) => item.isCompleted).length;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _SummaryChip(
          icon: Icons.hourglass_top,
          label: '今消化中',
          value: '$activeCount件',
          color: const Color(0xFF3D5AFE),
        ),
        _SummaryChip(
          icon: Icons.schedule,
          label: '後でやる',
          value: '$backlogCount件',
          color: const Color(0xFFFF6B35),
        ),
        _SummaryChip(
          icon: Icons.task_alt,
          label: '完了',
          value: '$completedCount件',
          color: const Color(0xFF4CAF50),
        ),
      ],
    );
  }

  Widget _buildDomainCard(String domain) {
    final active = DigestQueueService.findActiveForDomain(_items, domain);
    final waiting = DigestQueueService.backlogItems(_items)
        .where((item) => item.domain == domain)
        .toList();
    final accent = _colorForDomain(domain);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: accent.withValues(alpha: 0.12),
                foregroundColor: accent,
                child: Icon(_iconForDomain(domain)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  domain,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: active != null
                      ? accent.withValues(alpha: 0.12)
                      : const Color(0xFF4CAF50).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  active != null ? '消化中' : '新規OK',
                  style: TextStyle(
                    color: active != null ? accent : const Color(0xFF4CAF50),
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (active == null)
            Text(
              waiting.isEmpty
                  ? 'この領域には未消化の項目がありません。新しい項目を始められます。'
                  : '今は消化中の項目がないので、次の1件だけ始められます。',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  active.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.5,
                  ),
                ),
                if (active.note.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    active.note,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  active.latestProgress != null
                      ? '最新の消化メモ: ${active.latestProgress!.note}'
                      : 'まだ消化メモはありません。理解したことや実行したことを必ず言語化します。',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '消化メモ ${active.progressEntries.length}件',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          if (waiting.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '待機中 ${waiting.length}件',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            ...waiting.take(2).map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '・${item.title}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (active != null)
                OutlinedButton.icon(
                  onPressed: () => _showProgressDialog(active),
                  icon: const Icon(Icons.rate_review_outlined),
                  label: const Text('消化メモ'),
                ),
              if (active != null)
                FilledButton.icon(
                  onPressed: () => _completeItem(active),
                  icon: const Icon(Icons.task_alt),
                  label: const Text('完了'),
                ),
              if (active == null && waiting.isNotEmpty)
                FilledButton.icon(
                  onPressed: () => _activateItem(waiting.first),
                  icon: const Icon(Icons.play_arrow),
                  label: Text('始める: ${waiting.first.title}'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBacklogSection() {
    final backlogItems = DigestQueueService.backlogItems(_items);
    if (backlogItems.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('待機中の項目はありません。今消化中のものに集中できます。'),
        ),
      );
    }

    return Column(
      children: backlogItems.map((item) {
        final canStart =
            DigestQueueService.findActiveForDomain(_items, item.domain) == null;
        final accent = _colorForDomain(item.domain);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withValues(alpha: 0.14)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      item.domain,
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDate(item.createdAt),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                item.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.5,
                ),
              ),
              if (item.note.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  item.note,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: canStart ? () => _activateItem(item) : null,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('今始める'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _deleteItem(item),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('削除'),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCompletedSection() {
    final completed =
        DigestQueueService.completedItems(_items).take(8).toList();
    if (completed.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('完了した項目はまだありません。消化しきったものがここに並びます。'),
        ),
      );
    }

    return Column(
      children: completed.map((item) {
        final accent = _colorForDomain(item.domain);
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          leading: CircleAvatar(
            backgroundColor: accent.withValues(alpha: 0.12),
            foregroundColor: accent,
            child: const Icon(Icons.task_alt),
          ),
          title: Text(item.title),
          subtitle: Text('${item.domain} ・ ${item.progressEntries.length}回消化'),
          trailing: IconButton(
            onPressed: () => _deleteItem(item),
            icon: const Icon(Icons.delete_outline),
            tooltip: '削除',
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLegacyWipSection() {
    return Column(
      children: [
        if (_legacyWarning != null)
          Card(
            child: ListTile(
              leading: Icon(
                Icons.warning_amber_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              title: const Text('旧WIP項目の取得に失敗しました'),
              subtitle: Text(_legacyWarning!),
            ),
          ),
        for (final item in _legacyItems)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(item.emoji, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text('${item.progressPercent}%'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: item.progressPercent / 100),
                  const SizedBox(height: 8),
                  Text(
                    '${item.category}'
                    '${item.note.isEmpty ? '' : ' ・ ${item.note}'}'
                    '${item.createdAt == null ? '' : ' ・ ${_formatDate(item.createdAt!)}'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (!item.isCompleted) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: () => _updateLegacyProgress(item),
                        icon: const Icon(Icons.update),
                        label: const Text('進捗を更新'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _updateLegacyProgress(LegacyWipItem item) async {
    var progress = item.progressPercent;
    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('進捗更新: ${item.title}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Slider(
                value: progress.toDouble(),
                max: 100,
                divisions: 20,
                label: '$progress%',
                onChanged: (value) =>
                    setDialogState(() => progress = value.toInt()),
              ),
              Text('$progress%'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, progress),
              child: Text(progress == 100 ? '完了にする' : '更新'),
            ),
          ],
        ),
      ),
    );
    if (selected == null) return;

    try {
      await _legacyService.updateProgress(item.id, selected);
      await _loadItems();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('旧WIP項目を更新できませんでした: $error')),
      );
    }
  }

  IconData _iconForDomain(String domain) {
    switch (domain) {
      case '読書':
        return Icons.menu_book_rounded;
      case '勉強':
        return Icons.school_rounded;
      case '講座':
        return Icons.slideshow_rounded;
      case '動画':
        return Icons.ondemand_video_rounded;
      case '記事':
        return Icons.article_outlined;
      default:
        return Icons.inbox_rounded;
    }
  }

  Color _colorForDomain(String domain) {
    switch (domain) {
      case '読書':
        return const Color(0xFF3D5AFE);
      case '勉強':
        return const Color(0xFF3D5AFE);
      case '講座':
        return const Color(0xFFFF6B35);
      case '動画':
        return const Color(0xFF3D5AFE);
      case '記事':
        return const Color(0xFF607D8B);
      default:
        return const Color(0xFF795548);
    }
  }

  String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$month/$day';
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
