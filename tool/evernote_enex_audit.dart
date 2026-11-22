import 'dart:convert';
import 'dart:io';

import 'package:my_web_app/services/evernote_enex_parser.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await runEvernoteEnexAudit(arguments);
}

/// Runs a read-only audit. A report is emitted only after the entire input
/// verifies; errors never echo parser messages or private input paths.
Future<int> runEvernoteEnexAudit(
  List<String> arguments, {
  StringSink? output,
  StringSink? errors,
}) async {
  final reportOutput = output ?? stdout;
  final errorOutput = errors ?? stderr;
  if (arguments.length != 1) {
    errorOutput.writeln(
      'Usage: dart run tool/evernote_enex_audit.dart <file.enex>',
    );
    return 64;
  }

  try {
    final file = File(arguments.single);
    if (!await file.exists()) {
      errorOutput.writeln('ENEX file not found.');
      return 66;
    }
    final report = await buildEvernoteEnexAuditReport(
      file.openRead(),
      fileName: file.uri.pathSegments.last,
      sizeBytes: await file.length(),
    );
    reportOutput.writeln(const JsonEncoder.withIndent('  ').convert(report));
    return 0;
  } on FileSystemException {
    errorOutput.writeln('ENEX file could not be read.');
    return 74;
  } catch (_) {
    errorOutput.writeln('ENEX audit failed; no complete report was produced.');
    return 65;
  }
}

/// Retains only report metadata across notes. The parser still holds the
/// current note and its decoded resources, so the largest note needs headroom.
Future<Map<String, dynamic>> buildEvernoteEnexAuditReport(
  Stream<List<int>> source, {
  required String fileName,
  required int sizeBytes,
}) async {
  if (sizeBytes <= 0) {
    throw const FormatException('ENEX input must not be empty.');
  }
  final notes = <Map<String, dynamic>>[];
  final summary = await const EvernoteEnexParser().parseStream(
    source,
    totalBytes: sizeBytes,
    onNote: (note) {
      notes.add(<String, dynamic>{
        'ordinal': notes.length + 1,
        'hasSourceId': note.sourceId.isNotEmpty,
        'hasCreatedAt': note.createdAt != null,
        'hasUpdatedAt': note.updatedAt != null,
        'contentSha256': note.contentSha256,
        'tagCount': note.tags.length,
        'resourceCount': note.resources.length,
        'hasRawEnml': note.enml.trim().isNotEmpty,
        'hasRawXml': note.rawXml.trim().isNotEmpty,
      });
    },
  );
  return <String, dynamic>{
    'fileName': fileName,
    'sizeBytes': summary.processedBytes,
    'exportSha256': summary.exportSha256,
    'noteCount': summary.noteCount,
    'resourceCount': summary.resourceCount,
    'warningCount': summary.warnings.length,
    'notes': notes,
  };
}
