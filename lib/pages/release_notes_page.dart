import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../core/app_version.dart';

class ReleaseNoteLink {
  final String type;
  final String title;
  final String url;

  const ReleaseNoteLink({
    required this.type,
    required this.title,
    required this.url,
  });

  factory ReleaseNoteLink.fromJson(Map<String, dynamic> json) {
    return ReleaseNoteLink(
      type: json['type']?.toString() ?? 'link',
      title: json['title']?.toString() ?? json['type']?.toString() ?? 'Link',
      url: json['url']?.toString() ?? '',
    );
  }
}

class ReleaseNoteChange {
  final String category;
  final String summary;
  final List<ReleaseNoteLink> links;

  const ReleaseNoteChange({
    required this.category,
    required this.summary,
    this.links = const [],
  });

  factory ReleaseNoteChange.fromJson(Map<String, dynamic> json) {
    return ReleaseNoteChange(
      category: json['category']?.toString() ?? 'change',
      summary: json['summary']?.toString() ?? '',
      links: _parseLinks(json['links']),
    );
  }
}

class ReleaseNoteVersion {
  final String version;
  final String build;
  final String date;
  final String category;
  final String summary;
  final List<ReleaseNoteLink> links;
  final List<ReleaseNoteChange> changes;

  const ReleaseNoteVersion({
    required this.version,
    required this.build,
    required this.date,
    required this.category,
    required this.summary,
    this.links = const [],
    this.changes = const [],
  });

  factory ReleaseNoteVersion.fromJson(Map<String, dynamic> json) {
    return ReleaseNoteVersion(
      version: json['version']?.toString() ?? 'dev',
      build: json['build']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      category: json['category']?.toString() ?? 'release',
      summary: json['summary']?.toString() ?? '',
      links: _parseLinks(json['links']),
      changes: (json['changes'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ReleaseNoteChange.fromJson)
          .toList(growable: false),
    );
  }

  String get versionLabel {
    if (build.isEmpty || build == '0') return 'v$version';
    return 'v$version (build $build)';
  }

  String get searchableText {
    return [
      version,
      build,
      date,
      category,
      summary,
      ...links.map((link) => '${link.type} ${link.title} ${link.url}'),
      ...changes.map(
        (change) => '${change.category} ${change.summary} '
            '${change.links.map((link) => link.title).join(' ')}',
      ),
    ].join(' ').toLowerCase();
  }
}

class ReleaseNotesDocument {
  final String generatedAt;
  final ReleaseNoteVersion current;
  final List<ReleaseNoteVersion> versions;

  const ReleaseNotesDocument({
    required this.generatedAt,
    required this.current,
    required this.versions,
  });

  factory ReleaseNotesDocument.fromJson(Map<String, dynamic> json) {
    final currentJson = json['current'] as Map<String, dynamic>? ?? {};
    final versions = (json['versions'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ReleaseNoteVersion.fromJson)
        .toList(growable: false);
    final current = ReleaseNoteVersion.fromJson(currentJson);
    return ReleaseNotesDocument(
      generatedAt: json['generatedAt']?.toString() ?? '',
      current: current,
      versions: versions.isEmpty ? [current] : versions,
    );
  }
}

/// リリースノートをポップアップ(ダイアログ)で表示する。
///
/// ヘッダーのバージョンバッジ等、フルページ遷移より軽い確認に使う。[context] は
/// アプリ直下の Navigator を含むもの(ヘッダーは Navigator より上にあるため呼び出し
/// 側で `navigatorKey.currentContext` を渡すこと)。
Future<void> showReleaseNotesDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
          child: ReleaseNotesPage(
            onClose: () => Navigator.of(dialogContext).pop(),
          ),
        ),
      );
    },
  );
}

class ReleaseNotesPage extends StatefulWidget {
  final ReleaseNotesDocument? initialDocument;

  /// 非 null のときダイアログ表示とみなし、AppBar に閉じるボタンを出す。
  final VoidCallback? onClose;

  const ReleaseNotesPage({
    super.key,
    this.initialDocument,
    this.onClose,
  });

  @override
  State<ReleaseNotesPage> createState() => _ReleaseNotesPageState();
}

class _ReleaseNotesPageState extends State<ReleaseNotesPage> {
  final TextEditingController _searchController = TextEditingController();
  ReleaseNotesDocument? _document;
  String _query = '';
  String? _selectedVersion;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initialDocument = widget.initialDocument;
    if (initialDocument != null) {
      _document = initialDocument;
      _selectedVersion = initialDocument.current.version;
      _loading = false;
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cacheKey = refresh
          ? DateTime.now().millisecondsSinceEpoch.toString()
          : 'startup';
      final response = await http.get(
        Uri.base.resolve('release-notes.json?t=$cacheKey'),
        headers: const {'Cache-Control': 'no-cache'},
      );
      if (response.statusCode != 200) {
        throw StateError('HTTP ${response.statusCode}');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('release-notes.json root must be object');
      }
      final document = ReleaseNotesDocument.fromJson(decoded);
      if (!mounted) return;
      setState(() {
        _document = document;
        _selectedVersion = document.current.version;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final document = _document;
    final versions = _filteredVersions(document?.versions ?? const []);
    final selected = _selectedVersionFor(versions, document?.current);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.onClose == null,
        leading: widget.onClose != null
            ? IconButton(
                key: const Key('release_notes_close_button'),
                tooltip: '閉じる',
                icon: const Icon(Icons.close),
                onPressed: widget.onClose,
              )
            : null,
        title: const Text('Release Notes'),
        actions: [
          IconButton(
            tooltip: '再読み込み',
            icon: const Icon(Icons.refresh),
            onPressed: () => _load(refresh: true),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : document == null
              ? _buildError(theme)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    _buildCurrentSummary(theme, document.current),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('release_notes_search_field'),
                      controller: _searchController,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        labelText: 'バージョン、PR、カテゴリで検索',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                    const SizedBox(height: 16),
                    if (_error != null) _buildInlineWarning(theme),
                    _buildVersionChips(versions),
                    const SizedBox(height: 16),
                    if (selected == null)
                      const Center(child: Text('該当するRelease Notesがありません'))
                    else
                      _buildVersionDetail(theme, selected),
                  ],
                ),
    );
  }

  Widget _buildCurrentSummary(ThemeData theme, ReleaseNoteVersion current) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.new_releases_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    current.versionLabel,
                    key: const Key('release_notes_current_version'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(AppVersion.display, style: theme.textTheme.labelMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(current.summary),
            if (current.date.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Date: ${current.date}', style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInlineWarning(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        'release-notes.jsonを読み込めませんでした: $_error',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error, size: 40),
            const SizedBox(height: 12),
            Text(_error ?? 'Release Notesを読み込めませんでした'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _load(refresh: true),
              icon: const Icon(Icons.refresh),
              label: const Text('再読み込み'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionChips(List<ReleaseNoteVersion> versions) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: versions.map((version) {
        final selected = version.version == _selectedVersion;
        return ChoiceChip(
          key: Key('release_notes_version_${version.version}'),
          label: Text(version.versionLabel),
          selected: selected,
          onSelected: (_) => setState(() => _selectedVersion = version.version),
        );
      }).toList(),
    );
  }

  Widget _buildVersionDetail(ThemeData theme, ReleaseNoteVersion version) {
    return Card(
      key: const Key('release_notes_detail_card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              version.versionLabel,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text('${version.category} / ${version.date}'),
            const SizedBox(height: 12),
            Text(version.summary),
            const SizedBox(height: 12),
            _buildLinks(version.links),
            const Divider(height: 28),
            Text('Changes', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            if (version.changes.isEmpty)
              const Text('このバージョンの個別変更リンクはまだありません。')
            else
              ...version.changes.map(_buildChangeTile),
          ],
        ),
      ),
    );
  }

  Widget _buildChangeTile(ReleaseNoteChange change) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 14,
        child: Text(
          change.category.isEmpty ? '?' : change.category[0].toUpperCase(),
          style: const TextStyle(fontSize: 11),
        ),
      ),
      title: Text(change.summary),
      subtitle: change.links.isEmpty ? null : _buildLinks(change.links),
    );
  }

  Widget _buildLinks(List<ReleaseNoteLink> links) {
    if (links.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: links.map((link) {
        return OutlinedButton.icon(
          onPressed: () => _openLink(link.url),
          icon: const Icon(Icons.open_in_new, size: 16),
          label: Text(link.title),
        );
      }).toList(),
    );
  }

  List<ReleaseNoteVersion> _filteredVersions(
    List<ReleaseNoteVersion> versions,
  ) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return versions;
    return versions
        .where((version) => version.searchableText.contains(query))
        .toList(growable: false);
  }

  ReleaseNoteVersion? _selectedVersionFor(
    List<ReleaseNoteVersion> versions,
    ReleaseNoteVersion? current,
  ) {
    if (versions.isEmpty) return null;
    final selected = _selectedVersion;
    if (selected != null) {
      for (final version in versions) {
        if (version.version == selected) return version;
      }
    }
    if (current != null && versions.any((v) => v.version == current.version)) {
      return current;
    }
    return versions.first;
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, webOnlyWindowName: '_blank');
  }
}

List<ReleaseNoteLink> _parseLinks(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map<String, dynamic>>()
      .map(ReleaseNoteLink.fromJson)
      .where((link) => link.url.isNotEmpty)
      .toList(growable: false);
}
