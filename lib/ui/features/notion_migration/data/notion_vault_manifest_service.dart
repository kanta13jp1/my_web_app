import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';

import '../domain/notion_vault_manifest_models.dart';

const int _maxManifestBytes = 10 * 1024 * 1024;
const int _maxManifestEntries = 10000;
final RegExp _sha256Pattern = RegExp(r'^[0-9a-f]{64}$');

class NotionVaultManifestException implements Exception {
  const NotionVaultManifestException(this.code);

  final String code;

  @override
  String toString() => code;
}

class PickedNotionVaultManifest {
  const PickedNotionVaultManifest({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

abstract interface class NotionVaultManifestPicker {
  Future<PickedNotionVaultManifest?> pick();
}

class FilePickerNotionVaultManifestPicker implements NotionVaultManifestPicker {
  const FilePickerNotionVaultManifestPicker();

  @override
  Future<PickedNotionVaultManifest?> pick() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      throw const NotionVaultManifestException('manifest_bytes_unavailable');
    }
    return PickedNotionVaultManifest(name: file.name, bytes: bytes);
  }
}

class NotionVaultManifestParser {
  const NotionVaultManifestParser();

  NotionVaultManifestPreview parse(PickedNotionVaultManifest source) {
    if (source.bytes.isEmpty || source.bytes.length > _maxManifestBytes) {
      throw const NotionVaultManifestException('manifest_size_invalid');
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(source.bytes, allowMalformed: false));
    } on FormatException {
      throw const NotionVaultManifestException('manifest_json_invalid');
    }
    final root = _map(decoded, 'manifest_schema_invalid');
    final schemaVersion = _integer(root['schema_version']);
    final policy = _map(root['policy'], 'manifest_policy_invalid');
    if (schemaVersion != 1 ||
        root['local_only'] != true ||
        root['source_absolute_path_included'] != false ||
        policy['network_requests'] != false ||
        policy['vault_files_copied'] != false ||
        policy['note_body_or_property_values_included'] != false ||
        policy['excluded_files_opened_or_hashed'] != false) {
      throw const NotionVaultManifestException('manifest_policy_invalid');
    }

    final vaultName = _boundedString(root['vault_name'], 1, 200);
    final summary = _map(root['summary'], 'manifest_summary_invalid');
    final actionCounts = _map(
      summary['action_counts'],
      'manifest_summary_invalid',
    );
    final fileCount = _nonNegativeInteger(summary['file_count']);
    final autoStageCount = _nonNegativeInteger(actionCounts['auto_stage']);
    final reviewRequiredCount = _nonNegativeInteger(
      actionCounts['review_required'],
    );
    final excludedCount = _nonNegativeInteger(actionCounts['exclude']);
    final credentialCandidateCount = _nonNegativeInteger(
      summary['credential_candidate_count'],
    );
    final unresolvedWikilinkOccurrences = _nonNegativeInteger(
      summary['unresolved_wikilink_occurrences'],
    );
    if (fileCount != autoStageCount + reviewRequiredCount + excludedCount ||
        credentialCandidateCount > excludedCount) {
      throw const NotionVaultManifestException('manifest_summary_invalid');
    }

    final rawEntries = root['entries'];
    if (rawEntries is! List ||
        rawEntries.length != fileCount ||
        rawEntries.length > _maxManifestEntries) {
      throw const NotionVaultManifestException('manifest_entries_invalid');
    }
    final validatedEntries = <_ValidatedManifestEntry>[];
    final excludedPaths = <String>{};
    for (final rawEntry in rawEntries) {
      final entry = _map(rawEntry, 'manifest_entry_invalid');
      final relativePath = _safeRelativePath(entry['relative_path']);
      final action = _boundedString(entry['migration_action'], 1, 30);
      final category = _boundedString(entry['category'], 1, 40);
      if (action == 'exclude') {
        if (entry['sha256'] != null || entry['content_inspected'] != false) {
          throw const NotionVaultManifestException(
            'manifest_exclusion_policy_invalid',
          );
        }
      }
      validatedEntries.add(
        _ValidatedManifestEntry(
          data: entry,
          relativePath: relativePath,
          action: action,
          category: category,
        ),
      );
      if (action == 'exclude') {
        excludedPaths.add(relativePath.toLowerCase());
      }
    }

    var actualAutoStageCount = 0;
    var actualReviewRequiredCount = 0;
    var actualExcludedCount = 0;
    var actualCredentialCandidateCount = 0;
    var actualUnresolvedWikilinkOccurrences = 0;
    final entries = <NotionVaultManifestEntry>[];
    for (final validated in validatedEntries) {
      final entry = validated.data;
      final relativePath = validated.relativePath;
      final action = validated.action;
      final category = validated.category;
      if (action == 'exclude') {
        actualExcludedCount++;
        if (category == 'credential_candidate') {
          actualCredentialCandidateCount++;
        }
        continue;
      }
      if (!{'auto_stage', 'review_required'}.contains(action) ||
          !{'note', 'attachment'}.contains(category)) {
        throw const NotionVaultManifestException('manifest_entry_invalid');
      }
      if (action == 'auto_stage') {
        actualAutoStageCount++;
      } else {
        actualReviewRequiredCount++;
      }
      final sourceHash = _boundedString(entry['sha256'], 64, 64);
      if (!_sha256Pattern.hasMatch(sourceHash)) {
        throw const NotionVaultManifestException('manifest_hash_invalid');
      }
      final structureMetadata = _safeStructureMetadata(
        entry,
        category,
        excludedPaths,
      );
      if (category == 'note') {
        final links = structureMetadata['wikilinks']! as List<dynamic>;
        for (final rawLink in links) {
          final link = rawLink as Map<String, dynamic>;
          if (link['resolved'] != true) {
            actualUnresolvedWikilinkOccurrences += link['occurrences']! as int;
          }
        }
      }
      entries.add(
        NotionVaultManifestEntry(
          relativePath: relativePath,
          category: category,
          migrationAction: action,
          sizeBytes: _nonNegativeInteger(entry['size_bytes']),
          sourceHash: sourceHash,
          structureMetadata: structureMetadata,
        ),
      );
    }
    if (actualAutoStageCount != autoStageCount ||
        actualReviewRequiredCount != reviewRequiredCount ||
        actualExcludedCount != excludedCount ||
        actualCredentialCandidateCount != credentialCandidateCount ||
        actualUnresolvedWikilinkOccurrences != unresolvedWikilinkOccurrences) {
      throw const NotionVaultManifestException('manifest_entries_invalid');
    }

    return NotionVaultManifestPreview(
      sourceFileName: _safeFileName(source.name),
      sourceManifestSha256: sha256.convert(source.bytes).toString(),
      vaultName: vaultName,
      schemaVersion: schemaVersion,
      fileCount: fileCount,
      autoStageCount: autoStageCount,
      reviewRequiredCount: reviewRequiredCount,
      excludedCount: excludedCount,
      credentialCandidateCount: credentialCandidateCount,
      unresolvedWikilinkOccurrences: unresolvedWikilinkOccurrences,
      entries: List.unmodifiable(entries),
    );
  }

  Map<String, dynamic> _safeStructureMetadata(
    Map<String, dynamic> entry,
    String category,
    Set<String> excludedPaths,
  ) {
    if (category == 'attachment') {
      return {
        'referenced_by': _stringList(entry['referenced_by'], 4000)
            .where((path) => !excludedPaths.contains(path.toLowerCase()))
            .toList(growable: false),
      };
    }
    final markdown = _map(entry['markdown'], 'manifest_markdown_invalid');
    final rawLinks = markdown['wikilinks'];
    if (rawLinks is! List || rawLinks.length > _maxManifestEntries) {
      throw const NotionVaultManifestException('manifest_markdown_invalid');
    }
    final links = <Map<String, dynamic>>[];
    for (final rawLink in rawLinks) {
      final link = _map(rawLink, 'manifest_markdown_invalid');
      final target = _boundedString(link['target'], 1, 4000);
      String? resolvedRelativePath;
      if (link['resolved_relative_path'] is String) {
        resolvedRelativePath = _safeRelativePath(
          link['resolved_relative_path'],
        );
      }
      if (link['target_migration_action'] == 'exclude' ||
          (resolvedRelativePath != null &&
              excludedPaths.contains(resolvedRelativePath.toLowerCase())) ||
          _targetCouldReferenceExcludedPath(target, excludedPaths)) {
        continue;
      }
      links.add({
        'target': target,
        'embedded': link['embedded'] == true,
        'occurrences': _nonNegativeInteger(link['occurrences']),
        'resolved': link['resolved'] == true,
        'ambiguous': link['ambiguous'] == true,
        if (resolvedRelativePath != null)
          'resolved_relative_path': resolvedRelativePath,
      });
    }
    return {
      'frontmatter_present': markdown['frontmatter_present'] == true,
      'property_keys': _stringList(markdown['property_keys'], 200),
      'wikilinks': links,
      'external_link_count': _nonNegativeInteger(
        markdown['external_link_count'],
      ),
      'callout_types': _safeCountMap(markdown['callout_types']),
      'task_count': _nonNegativeInteger(markdown['task_count']),
      'completed_task_count': _nonNegativeInteger(
        markdown['completed_task_count'],
      ),
    };
  }

  bool _targetCouldReferenceExcludedPath(
    String target,
    Set<String> excludedPaths,
  ) {
    final normalized = target
        .split('#')
        .first
        .split('^')
        .first
        .trim()
        .replaceAll('\\', '/')
        .toLowerCase();
    if (normalized.isEmpty) return false;
    final targetName = normalized.split('/').last;
    final targetStem = targetName.contains('.')
        ? targetName.substring(0, targetName.lastIndexOf('.'))
        : targetName;
    for (final path in excludedPaths) {
      final excludedName = path.split('/').last;
      final excludedStem = excludedName.contains('.')
          ? excludedName.substring(0, excludedName.lastIndexOf('.'))
          : excludedName;
      if (normalized == path ||
          targetName == excludedName ||
          targetStem == excludedStem) {
        return true;
      }
    }
    return false;
  }

  Map<String, int> _safeCountMap(dynamic value) {
    final source = _map(value, 'manifest_markdown_invalid');
    if (source.length > 100) {
      throw const NotionVaultManifestException('manifest_markdown_invalid');
    }
    return {
      for (final entry in source.entries)
        _boundedString(entry.key, 1, 100): _nonNegativeInteger(entry.value),
    };
  }

  List<String> _stringList(dynamic value, int maxLength) {
    if (value is! List || value.length > _maxManifestEntries) {
      throw const NotionVaultManifestException('manifest_entry_invalid');
    }
    return value
        .map((item) => _boundedString(item, 1, maxLength))
        .toList(growable: false);
  }

  Map<String, dynamic> _map(dynamic value, String code) {
    if (value is! Map) throw NotionVaultManifestException(code);
    return Map<String, dynamic>.from(value);
  }

  int _integer(dynamic value) {
    if (value is int) return value;
    if (value is num && value.isFinite && value == value.truncate()) {
      return value.toInt();
    }
    throw const NotionVaultManifestException('manifest_number_invalid');
  }

  int _nonNegativeInteger(dynamic value) {
    final parsed = _integer(value);
    if (parsed < 0) {
      throw const NotionVaultManifestException('manifest_number_invalid');
    }
    return parsed;
  }

  String _boundedString(dynamic value, int min, int max) {
    if (value is! String || value.length < min || value.length > max) {
      throw const NotionVaultManifestException('manifest_string_invalid');
    }
    return value;
  }

  String _safeRelativePath(dynamic value) {
    final path = _boundedString(value, 1, 4000).replaceAll('\\', '/');
    final segments = path.split('/');
    if (path.startsWith('/') ||
        RegExp(r'^[a-zA-Z]:').hasMatch(path) ||
        segments.any((segment) => segment.isEmpty || segment == '..')) {
      throw const NotionVaultManifestException('manifest_path_invalid');
    }
    return path;
  }

  String _safeFileName(String value) {
    final normalized = value.replaceAll('\\', '/').split('/').last;
    return _boundedString(normalized, 1, 255);
  }
}

class _ValidatedManifestEntry {
  const _ValidatedManifestEntry({
    required this.data,
    required this.relativePath,
    required this.action,
    required this.category,
  });

  final Map<String, dynamic> data;
  final String relativePath;
  final String action;
  final String category;
}
