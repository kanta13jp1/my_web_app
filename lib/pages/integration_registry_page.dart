import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/integration_registry.dart';
import '../services/csv_bytes_decoder.dart';
import '../services/integration_registry_service.dart';

typedef IntegrationMappingCsvPicker = Future<Uint8List?> Function();

Future<Uint8List?> _pickIntegrationMappingCsv() async {
  final result = await FilePicker.pickFiles(
    withData: true,
    type: FileType.custom,
    allowedExtensions: const <String>['csv'],
  );
  return result?.files.single.bytes;
}

class IntegrationRegistryPage extends StatefulWidget {
  const IntegrationRegistryPage({
    super.key,
    this.service,
    this.mappingCsvPicker,
    this.csvBytesDecoder,
  });

  final IntegrationRegistryServiceContract? service;
  final IntegrationMappingCsvPicker? mappingCsvPicker;
  final CsvBytesDecoder? csvBytesDecoder;

  @override
  State<IntegrationRegistryPage> createState() =>
      _IntegrationRegistryPageState();
}

class _IntegrationRegistryPageState extends State<IntegrationRegistryPage> {
  late final IntegrationRegistryServiceContract _service =
      widget.service ?? const SupabaseIntegrationRegistryService();
  late final IntegrationMappingCsvPicker _mappingCsvPicker =
      widget.mappingCsvPicker ?? _pickIntegrationMappingCsv;
  late final CsvBytesDecoder _csvBytesDecoder =
      widget.csvBytesDecoder ?? const CsvBytesDecoder();
  final IntegrationCodeMappingCsvParser _csvParser =
      const IntegrationCodeMappingCsvParser();

  IntegrationRegistrySnapshot _snapshot = const IntegrationRegistrySnapshot();
  IntegrationImpactReport? _impact;
  String? _selectedImpactSystem;
  String? _error;
  bool _loading = true;
  bool _impactLoading = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await _service.loadSnapshot();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _selectedImpactSystem ??=
            snapshot.systems.isEmpty ? null : snapshot.systems.first.systemKey;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _disposeDialogControllers(
    Iterable<TextEditingController> controllers,
  ) async {
    await Future<void>.delayed(kThemeAnimationDuration);
    for (final controller in controllers) {
      controller.dispose();
    }
  }

  Future<void> _copyReferenceRequest() async {
    const request = '''
POST /functions/v1/tools-hub
Authorization: Bearer jibun_sk_...
Content-Type: application/json

{"action":"api.integrations.snapshot"}''';
    await Clipboard.setData(const ClipboardData(text: request));
    if (mounted) _message('Reference API request copied.');
  }

  Future<void> _showSystemDialog([
    IntegrationSystemDefinition? existing,
  ]) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final key = TextEditingController(text: existing?.systemKey ?? '');
    final owner = TextEditingController(text: existing?.owner ?? '');
    final description = TextEditingController(
      text: existing?.description ?? '',
    );
    var status = existing?.status ?? 'active';
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            existing == null ? 'Add system' : 'Publish system version',
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    key: const Key('system-name-field'),
                    controller: name,
                    decoration: const InputDecoration(labelText: 'System name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('system-key-field'),
                    controller: key,
                    decoration: const InputDecoration(labelText: 'Stable key'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: owner,
                    decoration: const InputDecoration(labelText: 'Owner'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(value: 'draft', child: Text('Draft')),
                      DropdownMenuItem(
                        value: 'deprecated',
                        child: Text('Deprecated'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => status = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: description,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              key: const Key('save-system-dialog-button'),
              onPressed: () async {
                if (name.text.trim().isEmpty) {
                  _message('System name is required.');
                  return;
                }
                try {
                  await _service.saveSystem(
                    IntegrationSystemDraft(
                      name: name.text.trim(),
                      systemKey: key.text.trim(),
                      owner: owner.text.trim(),
                      status: status,
                      description: description.text.trim(),
                    ),
                  );
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext, true);
                  }
                } catch (error) {
                  _message(error.toString());
                }
              },
              icon: const Icon(Icons.publish),
              label: const Text('Publish'),
            ),
          ],
        ),
      ),
    );
    await _disposeDialogControllers([name, key, owner, description]);
    if (saved == true) {
      await _reload();
      if (mounted) _message('System version published.');
    }
  }

  Future<void> _showInterfaceDialog([
    IntegrationInterfaceDefinition? existing,
  ]) async {
    if (_snapshot.systems.length < 2) {
      _message('Add at least two systems first.');
      return;
    }
    final name = TextEditingController(text: existing?.name ?? '');
    final key = TextEditingController(text: existing?.interfaceKey ?? '');
    final protocol = TextEditingController(text: existing?.protocol ?? 'REST');
    final format = TextEditingController(text: existing?.format ?? 'JSON');
    final description = TextEditingController(
      text: existing?.description ?? '',
    );
    final fields = TextEditingController(
      text: existing?.fields
              .map(
                (field) =>
                    '${field.name},${field.dataType},${field.required},${field.description}',
              )
              .join('\n') ??
          '',
    );
    var sourceKey =
        existing?.sourceSystemKey ?? _snapshot.systems.first.systemKey;
    var targetKey = existing?.targetSystemKey ?? _snapshot.systems[1].systemKey;
    final published = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            existing == null ? 'Publish interface' : 'Publish new IF version',
          ),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    key: const Key('interface-name-field'),
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Interface name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('interface-key-field'),
                    controller: key,
                    decoration: const InputDecoration(
                      labelText: 'Stable interface key',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          key: const Key('interface-source-field'),
                          initialValue: sourceKey,
                          decoration: const InputDecoration(
                            labelText: 'Source system',
                          ),
                          items: _systemItems(),
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() => sourceKey = value);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          key: const Key('interface-target-field'),
                          initialValue: targetKey,
                          decoration: const InputDecoration(
                            labelText: 'Target system',
                          ),
                          items: _systemItems(),
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() => targetKey = value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: protocol,
                          decoration: const InputDecoration(
                            labelText: 'Protocol',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: format,
                          decoration: const InputDecoration(
                            labelText: 'Payload format',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('interface-fields-field'),
                    controller: fields,
                    minLines: 3,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: 'Fields: name,data type,required,description',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: description,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              key: const Key('publish-interface-dialog-button'),
              onPressed: () async {
                if (name.text.trim().isEmpty || sourceKey == targetKey) {
                  _message(
                    'Name is required and source must differ from target.',
                  );
                  return;
                }
                try {
                  await _service.publishInterface(
                    IntegrationInterfaceDraft(
                      name: name.text.trim(),
                      interfaceKey: key.text.trim(),
                      sourceSystemKey: sourceKey,
                      targetSystemKey: targetKey,
                      protocol: protocol.text.trim(),
                      format: format.text.trim(),
                      description: description.text.trim(),
                      fields: _parseFields(fields.text),
                    ),
                  );
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext, true);
                  }
                } catch (error) {
                  _message(error.toString());
                }
              },
              icon: const Icon(Icons.publish),
              label: const Text('Publish'),
            ),
          ],
        ),
      ),
    );
    await _disposeDialogControllers([
      name,
      key,
      protocol,
      format,
      fields,
      description,
    ]);
    if (published == true) {
      await _reload();
      if (mounted) _message('Interface version published.');
    }
  }

  List<IntegrationFieldDefinition> _parseFields(String input) {
    return input
        .split(RegExp(r'\r?\n'))
        .where((line) => line.trim().isNotEmpty)
        .map((line) {
          final parts = line.split(',');
          return IntegrationFieldDefinition(
            name: parts.first.trim(),
            dataType: parts.length > 1 && parts[1].trim().isNotEmpty
                ? parts[1].trim()
                : 'string',
            required: parts.length > 2 &&
                const <String>{
                  'true',
                  'yes',
                  '1',
                  'required',
                }.contains(parts[2].trim().toLowerCase()),
            description:
                parts.length > 3 ? parts.sublist(3).join(',').trim() : '',
          );
        })
        .where((field) => field.name.isNotEmpty)
        .toList();
  }

  Future<void> _showMappingDialog([IntegrationCodeMappingSet? existing]) async {
    if (_snapshot.systems.length < 2) {
      _message('Add at least two systems first.');
      return;
    }
    final name = TextEditingController(text: existing?.name ?? '');
    final key = TextEditingController(text: existing?.mappingKey ?? '');
    final description = TextEditingController(
      text: existing?.description ?? '',
    );
    final csv = TextEditingController(
      text: existing == null
          ? 'old_code,new_code,description\n100,A100,Revenue\n200,A200,Expense'
          : [
              'old_code,new_code,description',
              ...existing.entries.map(
                (entry) =>
                    '${entry.oldCode},${entry.newCode},${entry.description}',
              ),
            ].join('\n'),
    );
    var sourceKey =
        existing?.sourceSystemKey ?? _snapshot.systems.first.systemKey;
    var targetKey = existing?.targetSystemKey ?? _snapshot.systems[1].systemKey;
    var preview = <IntegrationCodeMappingEntry>[];
    String? parseError;

    void parsePreview(StateSetter setDialogState) {
      try {
        final entries = _csvParser.parse(csv.text);
        setDialogState(() {
          preview = entries;
          parseError = null;
        });
      } catch (error) {
        setDialogState(() {
          preview = <IntegrationCodeMappingEntry>[];
          parseError = error.toString();
        });
      }
    }

    final imported = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            existing == null ? 'Import code mapping' : 'Import new map version',
          ),
          content: SizedBox(
            width: 680,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    key: const Key('mapping-name-field'),
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Mapping name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('mapping-key-field'),
                    controller: key,
                    decoration: const InputDecoration(
                      labelText: 'Stable mapping key',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: sourceKey,
                          decoration: const InputDecoration(
                            labelText: 'Source system',
                          ),
                          items: _systemItems(),
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() => sourceKey = value);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: targetKey,
                          decoration: const InputDecoration(
                            labelText: 'Target system',
                          ),
                          items: _systemItems(),
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() => targetKey = value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      key: const Key('pick-mapping-csv-button'),
                      onPressed: () async {
                        final bytes = await _mappingCsvPicker();
                        if (bytes == null) return;
                        try {
                          csv.text = _csvBytesDecoder.decode(
                            bytes,
                            looksValid: (text) {
                              try {
                                _csvParser.parse(text);
                                return true;
                              } on FormatException {
                                return false;
                              }
                            },
                            formatName: 'Code mapping CSV',
                          );
                          parsePreview(setDialogState);
                        } on FormatException catch (error) {
                          setDialogState(() {
                            preview = <IntegrationCodeMappingEntry>[];
                            parseError = error.toString();
                          });
                        }
                      },
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Choose CSV'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('mapping-csv-field'),
                    controller: csv,
                    minLines: 5,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      labelText: 'CSV data',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      OutlinedButton.icon(
                        key: const Key('preview-mapping-csv-button'),
                        onPressed: () => parsePreview(setDialogState),
                        icon: const Icon(Icons.preview),
                        label: const Text('Preview'),
                      ),
                      const SizedBox(width: 12),
                      if (preview.isNotEmpty)
                        Text('${preview.length} valid mapping rows'),
                    ],
                  ),
                  if (parseError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        parseError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: description,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              key: const Key('import-mapping-dialog-button'),
              onPressed: () async {
                if (preview.isEmpty) parsePreview(setDialogState);
                if (name.text.trim().isEmpty ||
                    sourceKey == targetKey ||
                    preview.isEmpty) {
                  _message('Complete the mapping details and preview the CSV.');
                  return;
                }
                try {
                  await _service.importMappings(
                    IntegrationMappingImportDraft(
                      name: name.text.trim(),
                      mappingKey: key.text.trim(),
                      sourceSystemKey: sourceKey,
                      targetSystemKey: targetKey,
                      entries: preview,
                      description: description.text.trim(),
                    ),
                  );
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext, true);
                  }
                } catch (error) {
                  _message(error.toString());
                }
              },
              icon: const Icon(Icons.publish),
              label: const Text('Import'),
            ),
          ],
        ),
      ),
    );
    await _disposeDialogControllers([name, key, description, csv]);
    if (imported == true) {
      await _reload();
      if (mounted) _message('Mapping version imported.');
    }
  }

  List<DropdownMenuItem<String>> _systemItems() {
    return _snapshot.systems
        .map(
          (system) => DropdownMenuItem<String>(
            value: system.systemKey,
            child: Text(system.name, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList();
  }

  Future<void> _analyzeImpact() async {
    final key = _selectedImpactSystem;
    if (key == null) return;
    setState(() {
      _impactLoading = true;
      _error = null;
    });
    try {
      final report = await _service.analyzeImpact(key);
      if (mounted) setState(() => _impact = report);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _impactLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Integration Registry'),
          actions: <Widget>[
            IconButton(
              tooltip: 'Copy reference API request',
              onPressed: _copyReferenceRequest,
              icon: const Icon(Icons.api),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: _loading ? null : _reload,
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: const TabBar(
            key: Key('integration-registry-tabs'),
            isScrollable: true,
            tabs: <Tab>[
              Tab(icon: Icon(Icons.dns_outlined), text: 'Systems'),
              Tab(icon: Icon(Icons.swap_horiz), text: 'Interfaces'),
              Tab(icon: Icon(Icons.compare_arrows), text: 'Code mappings'),
              Tab(icon: Icon(Icons.account_tree_outlined), text: 'Impact'),
            ],
          ),
        ),
        body: Column(
          children: <Widget>[
            _buildSummaryBand(),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (_error != null)
              MaterialBanner(
                content: Text(_error!),
                actions: <Widget>[
                  TextButton(onPressed: _reload, child: const Text('Retry')),
                ],
              ),
            Expanded(
              child: TabBarView(
                children: <Widget>[
                  _buildSystemsTab(),
                  _buildInterfacesTab(),
                  _buildMappingsTab(),
                  _buildImpactTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBand() {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        spacing: 24,
        runSpacing: 8,
        children: <Widget>[
          _metric(Icons.dns_outlined, 'Systems', _snapshot.systems.length),
          _metric(Icons.swap_horiz, 'Interfaces', _snapshot.interfaces.length),
          _metric(Icons.compare_arrows, 'Mappings', _snapshot.mappings.length),
          const Chip(
            avatar: Icon(Icons.key, size: 18),
            label: Text('API scope: integrations.read'),
          ),
        ],
      ),
    );
  }

  Widget _metric(IconData icon, String label, int value) {
    return SizedBox(
      width: 145,
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text('$value', style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _tabFrame({required Widget action, required Widget child}) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Align(alignment: Alignment.centerRight, child: action),
              const SizedBox(height: 12),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSystemsTab() {
    return _tabFrame(
      action: FilledButton.icon(
        key: const Key('add-system-button'),
        onPressed: () => _showSystemDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add system'),
      ),
      child: _snapshot.systems.isEmpty
          ? _emptyState(
              Icons.dns_outlined,
              'No systems registered',
              () => _showSystemDialog(),
            )
          : ListView.separated(
              itemCount: _snapshot.systems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final system = _snapshot.systems[index];
                final history = _snapshot.systemVersions
                    .where((item) => item.systemKey == system.systemKey)
                    .length;
                return Card(
                  key: Key('system-${system.systemKey}'),
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.dns_outlined),
                    ),
                    title: Text(system.name),
                    subtitle: Text(
                      '${system.systemKey}  |  v${system.version}  |  ${system.status}'
                      '${system.owner.isEmpty ? '' : '  |  ${system.owner}'}'
                      '  |  $history versions',
                    ),
                    trailing: IconButton(
                      tooltip: 'Publish new version',
                      onPressed: () => _showSystemDialog(system),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildInterfacesTab() {
    return _tabFrame(
      action: FilledButton.icon(
        key: const Key('publish-interface-button'),
        onPressed: () => _showInterfaceDialog(),
        icon: const Icon(Icons.add_link),
        label: const Text('Publish interface'),
      ),
      child: _snapshot.interfaces.isEmpty
          ? _emptyState(
              Icons.swap_horiz,
              'No interfaces published',
              () => _showInterfaceDialog(),
            )
          : ListView.separated(
              itemCount: _snapshot.interfaces.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = _snapshot.interfaces[index];
                final history = _snapshot.interfaceVersions
                    .where(
                      (version) => version.interfaceKey == item.interfaceKey,
                    )
                    .toList();
                return Card(
                  key: Key('interface-${item.interfaceKey}'),
                  child: ExpansionTile(
                    leading: const Icon(Icons.swap_horiz),
                    title: Text(item.name),
                    subtitle: Text(
                      '${item.sourceSystemKey} -> ${item.targetSystemKey}  |  '
                      '${item.protocol} / ${item.format}  |  v${item.version}',
                    ),
                    trailing: IconButton(
                      tooltip: 'Publish new version',
                      onPressed: () => _showInterfaceDialog(item),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: <Widget>[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: item.fields
                              .map(
                                (field) => Chip(
                                  label: Text(
                                    '${field.name}: ${field.dataType}'
                                    '${field.required ? ' *' : ''}',
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Version history: ${history.map((e) => 'v${e.version}').join(', ')}',
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildMappingsTab() {
    return _tabFrame(
      action: FilledButton.icon(
        key: const Key('import-mapping-button'),
        onPressed: () => _showMappingDialog(),
        icon: const Icon(Icons.upload_file),
        label: const Text('Import CSV'),
      ),
      child: _snapshot.mappings.isEmpty
          ? _emptyState(
              Icons.compare_arrows,
              'No code mappings imported',
              () => _showMappingDialog(),
            )
          : ListView.separated(
              itemCount: _snapshot.mappings.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final mapping = _snapshot.mappings[index];
                final history = _snapshot.mappingVersions
                    .where((item) => item.mappingKey == mapping.mappingKey)
                    .length;
                return Card(
                  key: Key('mapping-${mapping.mappingKey}'),
                  child: ExpansionTile(
                    leading: const Icon(Icons.compare_arrows),
                    title: Text(mapping.name),
                    subtitle: Text(
                      '${mapping.sourceSystemKey} -> ${mapping.targetSystemKey}  |  '
                      '${mapping.entries.length} rows  |  v${mapping.version}  |  '
                      '$history versions',
                    ),
                    trailing: IconButton(
                      tooltip: 'Import new version',
                      onPressed: () => _showMappingDialog(mapping),
                      icon: const Icon(Icons.upload_file),
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: mapping.entries
                        .take(8)
                        .map(
                          (entry) => ListTile(
                            dense: true,
                            title: Text('${entry.oldCode} -> ${entry.newCode}'),
                            subtitle: entry.description.isEmpty
                                ? null
                                : Text(entry.description),
                          ),
                        )
                        .toList(),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildImpactTab() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  SizedBox(
                    width: 320,
                    child: DropdownButtonFormField<String>(
                      key: const Key('impact-system-dropdown'),
                      initialValue: _selectedImpactSystem,
                      decoration: const InputDecoration(
                        labelText: 'Changed system',
                      ),
                      items: _systemItems(),
                      onChanged: (value) {
                        setState(() {
                          _selectedImpactSystem = value;
                          _impact = null;
                        });
                      },
                    ),
                  ),
                  FilledButton.icon(
                    key: const Key('analyze-impact-button'),
                    onPressed: _impactLoading || _selectedImpactSystem == null
                        ? null
                        : _analyzeImpact,
                    icon: const Icon(Icons.account_tree_outlined),
                    label: const Text('Analyze impact'),
                  ),
                ],
              ),
              if (_impactLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
              const SizedBox(height: 16),
              Expanded(
                child: _impact == null
                    ? _emptyState(
                        Icons.account_tree_outlined,
                        'Select a system to calculate dependencies',
                        _analyzeImpact,
                      )
                    : ListView(
                        key: const Key('impact-results-list'),
                        children: <Widget>[
                          _impactSection(
                            'Affected systems',
                            _impact!.systems
                                .map(
                                  (item) => ListTile(
                                    leading: const Icon(Icons.dns_outlined),
                                    title: Text(item.name),
                                    subtitle: Text(item.systemKey),
                                  ),
                                )
                                .toList(),
                          ),
                          _impactSection(
                            'Affected interfaces',
                            _impact!.interfaces
                                .map(
                                  (item) => ListTile(
                                    leading: const Icon(Icons.swap_horiz),
                                    title: Text(item.name),
                                    subtitle: Text(
                                      '${item.sourceSystemKey} -> ${item.targetSystemKey}',
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          _impactSection(
                            'Affected mappings',
                            _impact!.mappings
                                .map(
                                  (item) => ListTile(
                                    leading: const Icon(Icons.compare_arrows),
                                    title: Text(item.name),
                                    subtitle: Text(
                                      '${item.entries.length} mapping rows',
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _impactSection(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const Divider(),
          if (children.isEmpty)
            const ListTile(title: Text('No affected records'))
          else
            ...children,
        ],
      ),
    );
  }

  Widget _emptyState(IconData icon, String message, VoidCallback action) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          IconButton(
            tooltip: 'Open action',
            onPressed: action,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}
