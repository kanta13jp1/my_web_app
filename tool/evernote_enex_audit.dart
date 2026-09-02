import 'dart:convert';
import 'dart:io';

import 'package:my_web_app/services/evernote_enex_parser.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln('Usage: dart run tool/evernote_enex_audit.dart <file.enex>');
    exitCode = 64;
    return;
  }

  final file = File(arguments.single);
  if (!await file.exists()) {
    stderr.writeln('ENEX file not found.');
    exitCode = 66;
    return;
  }

  final bytes = await file.readAsBytes();
  final export = const EvernoteEnexParser().parseBytes(bytes);
  final report = <String, dynamic>{
    'fileName': file.uri.pathSegments.last,
    'sizeBytes': bytes.length,
    'exportSha256': export.exportSha256,
    'noteCount': export.notes.length,
    'resourceCount': export.resourceCount,
    'warningCount': export.warnings.length,
    'notes': <Map<String, dynamic>>[
      for (var index = 0; index < export.notes.length; index += 1)
        <String, dynamic>{
          'ordinal': index + 1,
          'hasSourceId': export.notes[index].sourceId.isNotEmpty,
          'hasCreatedAt': export.notes[index].createdAt != null,
          'hasUpdatedAt': export.notes[index].updatedAt != null,
          'contentSha256': export.notes[index].contentSha256,
          'tagCount': export.notes[index].tags.length,
          'resourceCount': export.notes[index].resources.length,
          'hasRawEnml': export.notes[index].enml.trim().isNotEmpty,
          'hasRawXml': export.notes[index].rawXml.trim().isNotEmpty,
        },
    ],
  };
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));
}
