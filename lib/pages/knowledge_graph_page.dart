import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class KnowledgeGraphPage extends StatefulWidget {
  const KnowledgeGraphPage({super.key});

  @override
  State<KnowledgeGraphPage> createState() => _KnowledgeGraphPageState();
}

class _KnowledgeGraphPageState extends State<KnowledgeGraphPage> {
  static const _sourceOptions = <String>[
    'issues',
    'wbs',
    'docs',
    'memory',
    'notebooklm',
  ];

  final _queryController = TextEditingController();
  final _selectedSources = <String>{..._sourceOptions};
  bool _loading = false;
  bool _useLlm = true;
  String? _error;
  String? _answer;
  String? _status;
  String? _traceId;
  List<Map<String, dynamic>> _citations = [];

  Future<void> _query() async {
    final query = _queryController.text.trim();
    if (query.isEmpty || _selectedSources.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _answer = null;
      _status = null;
      _traceId = null;
      _citations = [];
    });

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final response = await Supabase.instance.client.functions.invoke(
        'memory-search-hub',
        body: {
          'action': 'memory.rag.query',
          'query': query,
          'top_k': 8,
          'sources': _selectedSources.toList()..sort(),
          'use_llm': _useLlm,
          if (userId != null) 'user_id': userId,
        },
      );
      final data = response.data as Map<String, dynamic>? ?? {};
      final citations = (data['citations'] as List? ?? [])
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList();
      if (!mounted) return;
      setState(() {
        _answer = data['answer'] as String?;
        _status = data['answer_status'] as String?;
        _traceId = data['trace_id'] as String?;
        _citations = citations;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCitation(String? rawUrl) async {
    if (rawUrl == null || rawUrl.isEmpty || !rawUrl.startsWith('http')) return;
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'ok':
        return const Color(0xFF0F766E);
      case 'stale_index':
        return const Color(0xFFB45309);
      case 'llm_failure':
        return const Color(0xFF9F1239);
      case 'no_results':
        return const Color(0xFF52525B);
      default:
        return const Color(0xFF334155);
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(_status);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Knowledge Graph RAG'),
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final source in _sourceOptions)
                  FilterChip(
                    label: Text(source),
                    selected: _selectedSources.contains(source),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedSources.add(source);
                        } else {
                          _selectedSources.remove(source);
                        }
                      });
                    },
                  ),
                FilterChip(
                  label: const Text('LLM'),
                  selected: _useLlm,
                  onSelected: (selected) => setState(() => _useLlm = selected),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _queryController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Ask about the project',
                      prefixIcon: Icon(Icons.hub_outlined),
                    ),
                    onSubmitted: (_) => _query(),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _query,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label: const Text('Query'),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C))),
            ],
            if (_answer != null) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Chip(
                          label: Text(_status ?? 'unknown'),
                          backgroundColor: statusColor.withAlpha(28),
                          labelStyle: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (_traceId != null)
                          Text(
                            _traceId!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF64748B),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SelectableText(
                      _answer!,
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
                    ),
                  ],
                ),
              ),
            ],
            if (_citations.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                'Citations',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < _citations.length; i++)
                _CitationTile(
                  index: i + 1,
                  citation: _citations[i],
                  onOpen: _openCitation,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CitationTile extends StatelessWidget {
  const _CitationTile({
    required this.index,
    required this.citation,
    required this.onOpen,
  });

  final int index;
  final Map<String, dynamic> citation;
  final Future<void> Function(String? rawUrl) onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sourceUrl = citation['source_url'] as String?;
    final confidence = citation['confidence'];
    final confidenceText =
        confidence is num ? '${(confidence * 100).round()}%' : 'n/a';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        minVerticalPadding: 12,
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE0F2FE),
          foregroundColor: const Color(0xFF0369A1),
          child: Text('$index'),
        ),
        title: Text(
          citation['title'] as String? ?? sourceUrl ?? 'Untitled',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                citation['excerpt'] as String? ?? '',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text('type: ${citation['source_type'] ?? 'unknown'}'),
                  Text('confidence: $confidenceText'),
                  Text('synced: ${citation['last_synced_at'] ?? 'unknown'}'),
                ],
              ),
            ],
          ),
        ),
        trailing: sourceUrl != null && sourceUrl.startsWith('http')
            ? IconButton(
                tooltip: 'Open source',
                icon: const Icon(Icons.open_in_new),
                onPressed: () => onOpen(sourceUrl),
              )
            : null,
        titleTextStyle: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: const Color(0xFF0F172A),
        ),
      ),
    );
  }
}
