import 'package:flutter/material.dart';
import 'package:my_web_app/services/artifact_kv_storage_service.dart';

class ArtifactKvStorageCard extends StatefulWidget {
  final ArtifactKvStorageService storageService;
  final ArtifactStorageScope initialScope;
  final String? namespaceFilter;

  const ArtifactKvStorageCard({
    super.key,
    required this.storageService,
    this.initialScope = ArtifactStorageScope.private,
    this.namespaceFilter,
  });

  @override
  State<ArtifactKvStorageCard> createState() => _ArtifactKvStorageCardState();
}

class _ArtifactKvStorageCardState extends State<ArtifactKvStorageCard> {
  late ArtifactStorageScope _scope;
  List<ArtifactKvRecord> _records = const <ArtifactKvRecord>[];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _scope = widget.initialScope;
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final loaded = await widget.storageService.listByNamespace(
        scope: _scope,
        namespacePrefix: widget.namespaceFilter,
      );
      if (!mounted) return;
      setState(() {
        _records = loaded;
        _isLoading = false;
      });
    } on ArtifactKvValidationException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSample() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await widget.storageService.put(
        scope: _scope,
        key: 'artifact:state',
        payloadJson: '{"status":"saved"}',
      );
      await _reload();
    } on ArtifactKvValidationException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    }
  }

  void _toggleScope() {
    setState(() {
      _scope = _scope == ArtifactStorageScope.private
          ? ArtifactStorageScope.shared
          : ArtifactStorageScope.private;
    });
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Artifact 永続ストレージ',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LinearProgressIndicator(minHeight: 3),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('区分: ${_scope.labelJa}')),
                Chip(label: Text('件数: ${_records.length}')),
              ],
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            if (_records.isEmpty)
              const Text('保存済みArtifactはありません。')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _records
                    .map(
                      (record) => Chip(
                        label: Text(
                          '${record.hierarchicalKey} (${record.byteLength}B)',
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(64, 48),
                  ),
                  onPressed: _isLoading ? null : _reload,
                  child: const Text('再読込'),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(64, 48),
                  ),
                  onPressed: _isLoading ? null : _saveSample,
                  child: const Text('状態保存'),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(64, 48),
                  ),
                  onPressed: _isLoading ? null : _toggleScope,
                  child: const Text('共有切替'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
