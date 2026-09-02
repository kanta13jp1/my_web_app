import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/ui/features/notion_migration/data/notion_vault_manifest_service.dart';

void main() {
  const parser = NotionVaultManifestParser();

  test('keeps only allowlisted structure and omits every excluded path', () {
    final preview = parser.parse(_picked(_manifest()));

    expect(preview.fileCount, 3);
    expect(preview.stageableCount, 2);
    expect(preview.excludedCount, 1);
    expect(preview.credentialCandidateCount, 1);
    expect(preview.entries, hasLength(2));
    expect(
      preview.entries.map((entry) => entry.relativePath),
      isNot(contains('private/service-account.json')),
    );
    expect(
      jsonEncode(
        preview.entries.map((entry) => entry.structureMetadata).toList(),
      ),
      isNot(contains('service-account')),
    );
    expect(preview.entries.first.structureMetadata, isNot(contains('body')));
    expect(
      preview.entries.first.structureMetadata,
      isNot(contains('property_values')),
    );
    expect(preview.sourceManifestSha256, hasLength(64));
  });

  test('rejects a manifest without the local-only safety contract', () {
    final manifest = _manifest();
    manifest['local_only'] = false;

    expect(
      () => parser.parse(_picked(manifest)),
      throwsA(
        isA<NotionVaultManifestException>().having(
          (error) => error.code,
          'code',
          'manifest_policy_invalid',
        ),
      ),
    );
  });

  test('rejects traversal paths before staging', () {
    final manifest = _manifest();
    final entries = manifest['entries']! as List<Map<String, dynamic>>;
    entries.first['relative_path'] = '../outside.md';

    expect(
      () => parser.parse(_picked(manifest)),
      throwsA(
        isA<NotionVaultManifestException>().having(
          (error) => error.code,
          'code',
          'manifest_path_invalid',
        ),
      ),
    );
  });

  test('rejects excluded entries that were opened or hashed', () {
    final manifest = _manifest();
    final entries = manifest['entries']! as List<Map<String, dynamic>>;
    entries.last['sha256'] =
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

    expect(
      () => parser.parse(_picked(manifest)),
      throwsA(
        isA<NotionVaultManifestException>().having(
          (error) => error.code,
          'code',
          'manifest_exclusion_policy_invalid',
        ),
      ),
    );
  });
}

PickedNotionVaultManifest _picked(Map<String, dynamic> manifest) {
  return PickedNotionVaultManifest(
    name: 'company-vault-manifest.json',
    bytes: Uint8List.fromList(utf8.encode(jsonEncode(manifest))),
  );
}

Map<String, dynamic> _manifest() {
  const noteHash =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const reviewHash =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  return <String, dynamic>{
    'schema_version': 1,
    'local_only': true,
    'vault_name': 'company',
    'source_absolute_path_included': false,
    'policy': <String, dynamic>{
      'network_requests': false,
      'vault_files_copied': false,
      'note_body_or_property_values_included': false,
      'excluded_files_opened_or_hashed': false,
    },
    'entries': <Map<String, dynamic>>[
      <String, dynamic>{
        'relative_path': 'HOME.md',
        'category': 'note',
        'migration_action': 'auto_stage',
        'reason': 'markdown_note',
        'size_bytes': 120,
        'content_inspected': true,
        'sha256': noteHash,
        'markdown': <String, dynamic>{
          'frontmatter_present': true,
          'property_keys': <String>['title'],
          'wikilinks': <Map<String, dynamic>>[
            <String, dynamic>{
              'target': 'Finance',
              'embedded': false,
              'occurrences': 1,
              'resolved': true,
              'ambiguous': false,
              'resolved_relative_path': 'Finance.md',
            },
            <String, dynamic>{
              'target': 'private/service-account.json',
              'embedded': false,
              'occurrences': 1,
              'resolved': true,
              'ambiguous': false,
              'resolved_relative_path': 'private/service-account.json',
              'target_migration_action': 'exclude',
            },
          ],
          'external_link_count': 0,
          'callout_types': <String, int>{'note': 1},
          'task_count': 2,
          'completed_task_count': 1,
          'body': 'must never survive the allowlist',
          'property_values': <String, String>{'title': 'secret'},
        },
      },
      <String, dynamic>{
        'relative_path': 'Finance.md',
        'category': 'note',
        'migration_action': 'review_required',
        'reason': 'sensitive_note_name',
        'size_bytes': 80,
        'content_inspected': true,
        'sha256': reviewHash,
        'markdown': <String, dynamic>{
          'frontmatter_present': false,
          'property_keys': <String>[],
          'wikilinks': <Map<String, dynamic>>[],
          'external_link_count': 0,
          'callout_types': <String, int>{},
          'task_count': 0,
          'completed_task_count': 0,
        },
      },
      <String, dynamic>{
        'relative_path': 'private/service-account.json',
        'category': 'credential_candidate',
        'migration_action': 'exclude',
        'reason': 'explicit_credential_path',
        'size_bytes': 2048,
        'content_inspected': false,
        'sha256': null,
      },
    ],
    'summary': <String, dynamic>{
      'file_count': 3,
      'action_counts': <String, int>{
        'auto_stage': 1,
        'review_required': 1,
        'exclude': 1,
      },
      'category_counts': <String, int>{'note': 2, 'credential_candidate': 1},
      'review_required_count': 1,
      'credential_candidate_count': 1,
      'unresolved_wikilink_occurrences': 0,
      'unreferenced_attachment_count': 0,
    },
  };
}
