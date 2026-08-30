import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:xml/xml.dart';
import 'package:xml/xml_events.dart';

import 'evernote_enml_markdown_converter.dart';
import 'evernote_recognition_parser.dart';

/// A loss-preserving representation of one Evernote ENEX export.
///
/// The existing import UI only needs [plainText], but migration verification
/// also needs the original ENML, note metadata, resource bytes, and stable
/// hashes. Keeping those values here prevents preview code from becoming the
/// source of truth for a destructive source deletion.
class EvernoteEnexExport {
  const EvernoteEnexExport({
    required this.exportSha256,
    required this.notes,
    required this.warnings,
    this.exportDate,
    this.application,
    this.version,
  });

  final String exportSha256;
  final DateTime? exportDate;
  final String? application;
  final String? version;
  final List<EvernoteEnexNote> notes;
  final List<String> warnings;

  int get resourceCount =>
      notes.fold(0, (count, note) => count + note.resources.length);

  int get taskCount =>
      notes.fold(0, (count, note) => count + note.tasks.length);
}

class EvernoteEnexStreamSummary {
  const EvernoteEnexStreamSummary({
    required this.exportSha256,
    required this.noteCount,
    required this.resourceCount,
    required this.taskCount,
    required this.warnings,
    required this.processedBytes,
    this.exportDate,
    this.application,
    this.version,
  });

  final String exportSha256;
  final DateTime? exportDate;
  final String? application;
  final String? version;
  final int noteCount;
  final int resourceCount;
  final int taskCount;
  final List<String> warnings;
  final int processedBytes;
}

typedef EvernoteEnexNoteCallback = FutureOr<void> Function(
  EvernoteEnexNote note,
);

class EvernoteEnexNoteReminder {
  const EvernoteEnexNoteReminder({
    this.order,
    this.reminderAt,
    this.completedAt,
  });

  final int? order;
  final DateTime? reminderAt;
  final DateTime? completedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'order': order,
        'reminder_at': reminderAt?.toUtc().toIso8601String(),
        'completed_at': completedAt?.toUtc().toIso8601String(),
      };
}

class EvernoteEnexTaskReminder {
  const EvernoteEnexTaskReminder({
    required this.createdAt,
    required this.updatedAt,
    required this.noteLevelId,
    required this.rawXml,
    this.reminderAt,
    this.reminderDateUiOption,
    this.timeZone,
    this.dueDateOffset,
    this.status,
  });

  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String noteLevelId;
  final DateTime? reminderAt;
  final String? reminderDateUiOption;
  final String? timeZone;
  final String? dueDateOffset;
  final String? status;
  final String rawXml;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'created_at': createdAt?.toUtc().toIso8601String(),
        'updated_at': updatedAt?.toUtc().toIso8601String(),
        'note_level_id': noteLevelId,
        'reminder_at': reminderAt?.toUtc().toIso8601String(),
        'reminder_date_ui_option': reminderDateUiOption,
        'time_zone': timeZone,
        'due_date_offset': dueDateOffset,
        'status': status,
        'raw_xml': rawXml,
      };
}

class EvernoteEnexTask {
  const EvernoteEnexTask({
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    required this.inNote,
    required this.taskFlag,
    required this.sortWeight,
    required this.noteLevelId,
    required this.taskGroupNoteLevelId,
    required this.reminders,
    required this.rawXml,
    this.dueAt,
    this.dueDateUiOption,
    this.timeZone,
    this.recurrence,
    this.repeatAfterCompletion,
    this.statusUpdatedAt,
    this.creator,
    this.lastEditor,
    this.assigneeUserId,
    this.assigneeEmail,
    this.assigneeDisplayName,
    this.assigneeRawXml,
  });

  final String title;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String status;
  final bool? inNote;
  final String taskFlag;
  final String sortWeight;
  final String noteLevelId;
  final String taskGroupNoteLevelId;
  final DateTime? dueAt;
  final String? dueDateUiOption;
  final String? timeZone;
  final String? recurrence;
  final bool? repeatAfterCompletion;
  final DateTime? statusUpdatedAt;
  final String? creator;
  final String? lastEditor;
  final String? assigneeUserId;
  final String? assigneeEmail;
  final String? assigneeDisplayName;
  final String? assigneeRawXml;
  final List<EvernoteEnexTaskReminder> reminders;
  final String rawXml;

  bool get isCompleted => status == 'completed';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'created_at': createdAt?.toUtc().toIso8601String(),
        'updated_at': updatedAt?.toUtc().toIso8601String(),
        'status': status,
        'in_note': inNote,
        'task_flag': taskFlag,
        'sort_weight': sortWeight,
        'note_level_id': noteLevelId,
        'task_group_note_level_id': taskGroupNoteLevelId,
        'due_at': dueAt?.toUtc().toIso8601String(),
        'due_date_ui_option': dueDateUiOption,
        'time_zone': timeZone,
        'recurrence': recurrence,
        'repeat_after_completion': repeatAfterCompletion,
        'status_updated_at': statusUpdatedAt?.toUtc().toIso8601String(),
        'creator': creator,
        'last_editor': lastEditor,
        'assignee': assigneeUserId == null &&
                assigneeEmail == null &&
                assigneeDisplayName == null &&
                assigneeRawXml == null
            ? null
            : <String, dynamic>{
                'user_id': assigneeUserId,
                'email': assigneeEmail,
                'display_name': assigneeDisplayName,
                'raw_xml': assigneeRawXml,
              },
        'reminders': reminders
            .map((reminder) => reminder.toJson())
            .toList(growable: false),
        'raw_xml': rawXml,
      };
}

class EvernoteEnexNote {
  const EvernoteEnexNote({
    required this.sourceId,
    required this.title,
    required this.enml,
    required this.markdownText,
    required this.plainText,
    required this.tags,
    required this.attributes,
    required this.resources,
    required this.links,
    required this.contentSha256,
    this.tasks = const <EvernoteEnexTask>[],
    this.noteReminder,
    required this.rawXml,
    this.sourceGuid,
    this.createdAt,
    this.updatedAt,
  });

  /// Evernote does not guarantee a GUID in every ENEX export. When it is
  /// absent, this is a deterministic SHA-256 identifier derived from the
  /// preserved note payload.
  final String sourceId;
  final String? sourceGuid;
  final String title;
  final String enml;
  final String markdownText;
  final String plainText;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<String> tags;
  final Map<String, dynamic> attributes;
  final List<EvernoteEnexResource> resources;
  final List<String> links;
  final String contentSha256;
  final List<EvernoteEnexTask> tasks;
  final EvernoteEnexNoteReminder? noteReminder;
  final String rawXml;

  Map<String, dynamic> toImportMetadata() => <String, dynamic>{
        'source_guid': sourceGuid,
        'enml': enml,
        'created_at': createdAt?.toUtc().toIso8601String(),
        'updated_at': updatedAt?.toUtc().toIso8601String(),
        'attributes': attributes,
        'links': links,
        'tasks': tasks.map((task) => task.toJson()).toList(growable: false),
        'note_reminder': noteReminder?.toJson(),
        'resources': resources
            .map((resource) => resource.toManifestJson())
            .toList(growable: false),
        // Unknown future ENEX fields remain recoverable even when the typed parser
        // does not understand them yet.
        'raw_note_xml': rawXml,
      };
}

class EvernoteEnexResource {
  const EvernoteEnexResource({
    required this.mimeType,
    required this.data,
    required this.dataSha256,
    required this.attributes,
    required this.rawXml,
    this.evernoteHash,
    this.fileName,
    this.width,
    this.height,
    this.duration,
    this.recognitionXml,
    this.recognition,
    this.alternateData,
  });

  final String mimeType;
  final Uint8List data;
  final String dataSha256;
  final String? evernoteHash;
  final String? fileName;
  final int? width;
  final int? height;
  final int? duration;
  final String? recognitionXml;
  final EvernoteRecognitionIndex? recognition;
  final String? alternateData;
  final Map<String, dynamic> attributes;
  final String rawXml;

  Map<String, dynamic> toManifestJson() => <String, dynamic>{
        'file_name': fileName,
        'mime_type': mimeType,
        'byte_length': data.length,
        'sha256': dataSha256,
        'evernote_hash': evernoteHash,
        'width': width,
        'height': height,
        'duration': duration,
        'recognition_xml': recognitionXml,
        'recognition': recognition?.toManifestJson(),
        'alternate_data': alternateData,
        'attributes': attributes,
        'raw_resource_xml': rawXml,
      };
}

class EvernoteEnexParser {
  const EvernoteEnexParser();

  EvernoteEnexExport parseBytes(Uint8List bytes) {
    return _parse(
      utf8.decode(bytes, allowMalformed: true),
      exportSha256: sha256.convert(bytes).toString(),
    );
  }

  EvernoteEnexExport parseText(String text) {
    return _parse(
      text,
      exportSha256: sha256.convert(utf8.encode(text)).toString(),
    );
  }

  /// Parses one `<note>` subtree at a time instead of retaining the complete
  /// ENEX document and all decoded attachments in memory.
  Future<EvernoteEnexStreamSummary> parseStream(
    Stream<List<int>> source, {
    required EvernoteEnexNoteCallback onNote,
    int? totalBytes,
    void Function(int processedBytes, int? totalBytes)? onProgress,
  }) async {
    if (totalBytes != null && totalBytes <= 0) {
      throw ArgumentError.value(totalBytes, 'totalBytes', 'must be positive');
    }

    final digestOutput = _EvernoteDigestSink();
    final digestInput = sha256.startChunkedConversion(digestOutput);
    final warnings = <String>[];
    var processedBytes = 0;
    var noteCount = 0;
    var resourceCount = 0;
    var taskCount = 0;
    var rootSeen = false;
    DateTime? exportDate;
    String? application;
    String? version;
    onProgress?.call(0, totalBytes);

    final byteStream = source.map((chunk) {
      if (chunk.isEmpty) return chunk;
      processedBytes += chunk.length;
      if (totalBytes != null && processedBytes > totalBytes) {
        throw StateError(
          'The ENEX stream is larger than its declared file size.',
        );
      }
      digestInput.add(chunk);
      onProgress?.call(processedBytes, totalBytes);
      return chunk;
    });

    try {
      final noteNodes = byteStream
          .transform(const Utf8Decoder(allowMalformed: true))
          .toXmlEvents(
            validateNesting: true,
            validateDocument: true,
          )
          .map((events) {
            for (final event in events.whereType<XmlStartElementEvent>()) {
              if (!rootSeen) {
                if (event.localName != 'en-export') {
                  throw const FormatException(
                    'Invalid Evernote ENEX: en-export missing.',
                  );
                }
                rootSeen = true;
                exportDate = _parseEvernoteDate(
                  _eventAttribute(event, 'export-date'),
                );
                application = _nonEmpty(
                  _eventAttribute(event, 'application'),
                );
                version = _nonEmpty(_eventAttribute(event, 'version'));
                break;
              }
            }
            return events;
          })
          .normalizeEvents()
          .selectSubtreeEvents((event) => event.localName == 'note')
          .toXmlNodes();

      await for (final nodes in noteNodes) {
        for (final element in nodes.whereType<XmlElement>()) {
          final note = _parseNote(element, warnings);
          noteCount += 1;
          resourceCount += note.resources.length;
          taskCount += note.tasks.length;
          await onNote(note);
        }
      }
    } on XmlException catch (error) {
      throw FormatException('Invalid Evernote ENEX: $error');
    }

    if (!rootSeen) {
      throw const FormatException(
        'Invalid Evernote ENEX: en-export missing.',
      );
    }
    if (totalBytes != null && processedBytes != totalBytes) {
      throw StateError(
        'The ENEX stream ended before its declared file size.',
      );
    }
    digestInput.close();

    return EvernoteEnexStreamSummary(
      exportSha256: digestOutput.value.toString(),
      exportDate: exportDate,
      application: application,
      version: version,
      noteCount: noteCount,
      resourceCount: resourceCount,
      taskCount: taskCount,
      warnings: List<String>.unmodifiable(warnings),
      processedBytes: processedBytes,
    );
  }

  EvernoteEnexExport _parse(String text, {required String exportSha256}) {
    final XmlDocument document;
    try {
      document = XmlDocument.parse(text);
    } on XmlException catch (error) {
      throw FormatException('Invalid Evernote ENEX: ${error.message}');
    }

    final export = document.descendants
        .whereType<XmlElement>()
        .where((element) => element.localName == 'en-export')
        .firstOrNull;
    if (export == null) {
      throw const FormatException('Invalid Evernote ENEX: en-export missing.');
    }

    final warnings = <String>[];
    final notes = <EvernoteEnexNote>[];
    for (final noteElement in export.childElements.where(
      (element) => element.localName == 'note',
    )) {
      notes.add(_parseNote(noteElement, warnings));
    }

    return EvernoteEnexExport(
      exportSha256: exportSha256,
      exportDate: _parseEvernoteDate(export.getAttribute('export-date')),
      application: _nonEmpty(export.getAttribute('application')),
      version: _nonEmpty(export.getAttribute('version')),
      notes: List<EvernoteEnexNote>.unmodifiable(notes),
      warnings: List<String>.unmodifiable(warnings),
    );
  }

  EvernoteEnexNote _parseNote(XmlElement note, List<String> warnings) {
    final title = _childText(note, 'title').trim();
    final contentElement = _firstChild(note, 'content');
    final enml = contentElement == null
        ? ''
        : contentElement.children.whereType<XmlCDATA>().isNotEmpty
            ? contentElement.innerText
            : _innerXml(contentElement);
    final rawXml = note.toXmlString(pretty: false);
    final contentSha256 = sha256.convert(utf8.encode(rawXml)).toString();
    final sourceGuid = _nonEmpty(_childText(note, 'guid').trim());
    final createdAt = _parseEvernoteDate(_childText(note, 'created'));
    final updatedAt = _parseEvernoteDate(_childText(note, 'updated'));
    final tags = note.childElements
        .where((element) => element.localName == 'tag')
        .map((element) => element.innerText.trim())
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);
    final attributesElement = _firstChild(note, 'note-attributes');
    final attributes = attributesElement == null
        ? const <String, dynamic>{}
        : _parseAttributes(attributesElement);
    final noteReminder = _parseNoteReminder(attributes, warnings);
    final tasks = note.childElements
        .where((element) => element.localName == 'task')
        .map((element) => _parseTask(element, warnings))
        .toList(growable: false);
    final resources = note.childElements
        .where((element) => element.localName == 'resource')
        .map((element) => _parseResource(element, warnings))
        .toList(growable: false);
    final links = _extractLinks(enml);
    final plainText = _enmlToPlainText(enml, resources);
    var markdownText = plainText;
    try {
      final conversion = const EvernoteEnmlMarkdownConverter().convert(
        enml: enml,
        resources: resources.map(
          (resource) => EvernoteEnmlResourceReference(
            hash: resource.evernoteHash ?? '',
            mimeType: resource.mimeType,
            label: resource.fileName ?? resource.mimeType,
          ),
        ),
      );
      markdownText = conversion.markdown;
      if (conversion.unresolvedResourceHashes.isNotEmpty) {
        warnings.add(
          '${conversion.unresolvedResourceHashes.length} ENML attachment '
          'reference(s) could not be matched to an ENEX resource.',
        );
      }
      if (conversion.encryptedSectionCount > 0) {
        warnings.add(
          '${conversion.encryptedSectionCount} encrypted ENML section(s) '
          'must be unlocked in Evernote before commit.',
        );
      }
    } on XmlException {
      warnings.add(
        'ENML could not be converted to editable Markdown without loss.',
      );
    }
    final fallbackId = sha256
        .convert(
          utf8.encode(
            '${createdAt?.toUtc().toIso8601String() ?? ''}\u0000'
            '$title\u0000$contentSha256',
          ),
        )
        .toString();

    return EvernoteEnexNote(
      sourceId: sourceGuid ?? fallbackId,
      sourceGuid: sourceGuid,
      title: title.isEmpty ? 'Evernote import' : title,
      enml: enml,
      markdownText: markdownText,
      plainText: plainText,
      createdAt: createdAt,
      updatedAt: updatedAt,
      tags: List<String>.unmodifiable(tags),
      attributes: Map<String, dynamic>.unmodifiable(attributes),
      resources: List<EvernoteEnexResource>.unmodifiable(resources),
      links: List<String>.unmodifiable(links),
      contentSha256: contentSha256,
      tasks: List<EvernoteEnexTask>.unmodifiable(tasks),
      noteReminder: noteReminder,
      rawXml: rawXml,
    );
  }

  EvernoteEnexNoteReminder? _parseNoteReminder(
    Map<String, dynamic> attributes,
    List<String> warnings,
  ) {
    final rawOrder = _stringAttribute(attributes, 'reminder-order');
    final rawReminderAt = _stringAttribute(attributes, 'reminder-time');
    final rawCompletedAt = _stringAttribute(attributes, 'reminder-done-time');
    if (rawOrder == null && rawReminderAt == null && rawCompletedAt == null) {
      return null;
    }

    final order = int.tryParse(rawOrder ?? '');
    final reminderAt = _parseEvernoteDate(rawReminderAt);
    final completedAt = _parseEvernoteDate(rawCompletedAt);
    if ((rawOrder != null && (order == null || order <= 0)) ||
        (rawReminderAt != null && reminderAt == null) ||
        (rawCompletedAt != null && completedAt == null)) {
      warnings.add(
        'A note contains invalid Evernote reminder metadata; raw XML retained.',
      );
    }
    return EvernoteEnexNoteReminder(
      order: order,
      reminderAt: reminderAt,
      completedAt: completedAt,
    );
  }

  EvernoteEnexTask _parseTask(
    XmlElement task,
    List<String> warnings,
  ) {
    final title = _childText(task, 'title').trim();
    final createdAt = _parseEvernoteDate(_childText(task, 'created'));
    final updatedAt = _parseEvernoteDate(_childText(task, 'updated'));
    final status = _childText(task, 'taskStatus').trim().toLowerCase();
    final rawInNote = _childText(task, 'inNote').trim().toLowerCase();
    final inNote = _parseEvernoteBoolean(rawInNote);
    final taskFlag = _childText(task, 'taskFlag').trim();
    final sortWeight = _childText(task, 'sortWeight').trim();
    final noteLevelId = _childText(task, 'noteLevelID').trim();
    final taskGroupNoteLevelId =
        _childText(task, 'taskGroupNoteLevelID').trim();
    final rawDueAt = _childText(task, 'dueDate').trim();
    final dueAt = _parseEvernoteDate(rawDueAt);
    final dueDateUiOption =
        _nonEmpty(_childText(task, 'dueDateUIOption').trim());
    final timeZone = _nonEmpty(_childText(task, 'timeZone').trim());
    final recurrence = _nonEmpty(_childText(task, 'recurrence').trim());
    final rawRepeat =
        _childText(task, 'repeatAfterCompletion').trim().toLowerCase();
    final repeatAfterCompletion = _parseEvernoteBoolean(rawRepeat);
    final rawStatusUpdated = _childText(task, 'statusUpdated').trim();
    final statusUpdatedAt = _parseEvernoteDate(rawStatusUpdated);
    final creator = _nonEmpty(_childText(task, 'creator').trim());
    final lastEditor = _nonEmpty(_childText(task, 'lastEditor').trim());
    final assignee = _parseTaskAssignee(task);
    final reminders = task.childElements
        .where((element) => element.localName == 'reminder')
        .map((element) => _parseTaskReminder(element, warnings))
        .toList(growable: false);

    final requiredFieldsAreValid = title.isNotEmpty &&
        createdAt != null &&
        updatedAt != null &&
        <String>{'open', 'completed'}.contains(status) &&
        inNote != null &&
        taskFlag.isNotEmpty &&
        sortWeight.isNotEmpty &&
        noteLevelId.isNotEmpty &&
        taskGroupNoteLevelId.isNotEmpty;
    final optionalFieldsAreValid = (rawDueAt.isEmpty || dueAt != null) &&
        (rawRepeat.isEmpty || repeatAfterCompletion != null) &&
        (rawStatusUpdated.isEmpty || statusUpdatedAt != null);
    if (!requiredFieldsAreValid || !optionalFieldsAreValid) {
      warnings.add(
        'An Evernote task contains invalid structured fields; raw XML retained.',
      );
    }

    return EvernoteEnexTask(
      title: title,
      createdAt: createdAt,
      updatedAt: updatedAt,
      status: status,
      inNote: inNote,
      taskFlag: taskFlag,
      sortWeight: sortWeight,
      noteLevelId: noteLevelId,
      taskGroupNoteLevelId: taskGroupNoteLevelId,
      dueAt: dueAt,
      dueDateUiOption: dueDateUiOption,
      timeZone: timeZone,
      recurrence: recurrence,
      repeatAfterCompletion: repeatAfterCompletion,
      statusUpdatedAt: statusUpdatedAt,
      creator: creator,
      lastEditor: lastEditor,
      assigneeUserId: assignee.userId,
      assigneeEmail: assignee.email,
      assigneeDisplayName: assignee.displayName,
      assigneeRawXml: assignee.rawXml,
      reminders: List<EvernoteEnexTaskReminder>.unmodifiable(reminders),
      rawXml: task.toXmlString(pretty: false),
    );
  }

  ({
    String? userId,
    String? email,
    String? displayName,
    String? rawXml,
  }) _parseTaskAssignee(XmlElement task) {
    XmlElement? container;
    for (final child in task.childElements) {
      if (<String>{'assignee', 'assignedTo'}.contains(child.localName)) {
        container = child;
        break;
      }
    }

    String childValue(String name) =>
        container == null ? '' : _childText(container, name).trim();

    final userId = _firstNonEmpty(<String>[
      childValue('userID'),
      childValue('userId'),
      childValue('user-id'),
      _childText(task, 'assigneeUserID').trim(),
      _childText(task, 'assigneeUserId').trim(),
    ]);
    var email = _firstNonEmpty(<String>[
      childValue('email'),
      childValue('emailAddress'),
      childValue('email-address'),
      _childText(task, 'assigneeEmail').trim(),
    ]);
    var displayName = _firstNonEmpty(<String>[
      childValue('displayName'),
      childValue('name'),
      _childText(task, 'assigneeName').trim(),
    ]);
    final compact = _nonEmpty(container?.innerText.trim());
    if (userId == null &&
        email == null &&
        displayName == null &&
        compact != null) {
      if (compact.contains('@')) {
        email = compact;
      } else {
        displayName = compact;
      }
    }

    return (
      userId: userId,
      email: email,
      displayName: displayName,
      rawXml: container?.toXmlString(pretty: false),
    );
  }

  String? _firstNonEmpty(Iterable<String> values) {
    for (final value in values) {
      final candidate = _nonEmpty(value.trim());
      if (candidate != null) return candidate;
    }
    return null;
  }

  EvernoteEnexTaskReminder _parseTaskReminder(
    XmlElement reminder,
    List<String> warnings,
  ) {
    final createdAt = _parseEvernoteDate(_childText(reminder, 'created'));
    final updatedAt = _parseEvernoteDate(_childText(reminder, 'updated'));
    final noteLevelId = _childText(reminder, 'noteLevelID').trim();
    final rawReminderAt = _childText(reminder, 'reminderDate').trim();
    final reminderAt = _parseEvernoteDate(rawReminderAt);
    final reminderDateUiOption =
        _nonEmpty(_childText(reminder, 'reminderDateUIOption').trim());
    final timeZone = _nonEmpty(_childText(reminder, 'timeZone').trim());
    final dueDateOffset =
        _nonEmpty(_childText(reminder, 'dueDateOffset').trim());
    final status =
        _nonEmpty(_childText(reminder, 'reminderStatus').trim().toLowerCase());

    final requiredFieldsAreValid =
        createdAt != null && updatedAt != null && noteLevelId.isNotEmpty;
    final optionalFieldsAreValid =
        (rawReminderAt.isEmpty || reminderAt != null) &&
            (status == null || <String>{'active', 'muted'}.contains(status));
    if (!requiredFieldsAreValid || !optionalFieldsAreValid) {
      warnings.add(
        'An Evernote task reminder contains invalid structured fields; '
        'raw XML retained.',
      );
    }

    return EvernoteEnexTaskReminder(
      createdAt: createdAt,
      updatedAt: updatedAt,
      noteLevelId: noteLevelId,
      reminderAt: reminderAt,
      reminderDateUiOption: reminderDateUiOption,
      timeZone: timeZone,
      dueDateOffset: dueDateOffset,
      status: status,
      rawXml: reminder.toXmlString(pretty: false),
    );
  }

  bool? _parseEvernoteBoolean(String value) {
    return switch (value) {
      'true' => true,
      'false' => false,
      _ => null,
    };
  }

  EvernoteEnexResource _parseResource(
    XmlElement resource,
    List<String> warnings,
  ) {
    final dataElement = _firstChild(resource, 'data');
    final encoded = dataElement?.innerText.replaceAll(RegExp(r'\s+'), '') ?? '';
    Uint8List bytes;
    try {
      bytes = encoded.isEmpty
          ? Uint8List(0)
          : Uint8List.fromList(base64Decode(encoded));
    } on FormatException {
      bytes = Uint8List(0);
      warnings.add(
        'A resource contains invalid base64 data; raw XML retained.',
      );
    }

    final attributesElement = _firstChild(resource, 'resource-attributes');
    final attributes = attributesElement == null
        ? const <String, dynamic>{}
        : _parseAttributes(attributesElement);
    final recognitionElement = _firstChild(resource, 'recognition');
    final recognitionXml = recognitionElement == null
        ? null
        : recognitionElement.children.whereType<XmlCDATA>().isNotEmpty
            ? recognitionElement.innerText
            : _innerXml(recognitionElement);
    EvernoteRecognitionIndex? recognition;
    if (recognitionXml != null && recognitionXml.trim().isNotEmpty) {
      try {
        recognition = const EvernoteRecognitionParser().parse(recognitionXml);
      } on FormatException {
        warnings.add(
          'A resource contains invalid Evernote recognition data; '
          'raw XML retained for cloud OCR fallback.',
        );
      }
    }
    final alternateData = _firstChild(resource, 'alternate-data');

    return EvernoteEnexResource(
      mimeType: _childText(resource, 'mime').trim(),
      data: bytes,
      dataSha256: sha256.convert(bytes).toString(),
      evernoteHash: _nonEmpty(dataElement?.getAttribute('hash')),
      fileName: _stringAttribute(attributes, 'file-name'),
      width: int.tryParse(_childText(resource, 'width').trim()),
      height: int.tryParse(_childText(resource, 'height').trim()),
      duration: int.tryParse(_childText(resource, 'duration').trim()),
      recognitionXml: recognitionXml,
      recognition: recognition,
      alternateData: alternateData?.innerText,
      attributes: Map<String, dynamic>.unmodifiable(attributes),
      rawXml: resource.toXmlString(pretty: false),
    );
  }

  Map<String, dynamic> _parseAttributes(XmlElement container) {
    final values = <String, dynamic>{};
    for (final element in container.childElements) {
      final key = element.localName == 'application-data'
          ? 'application-data:${element.getAttribute('key') ?? ''}'
          : element.localName;
      final value = element.childElements.isEmpty
          ? element.innerText.trim()
          : _innerXml(element);
      final existing = values[key];
      if (existing == null) {
        values[key] = value;
      } else if (existing is List<String>) {
        existing.add(value);
      } else {
        values[key] = <String>[existing.toString(), value];
      }
    }
    return values;
  }

  List<String> _extractLinks(String enml) {
    if (enml.trim().isEmpty) return const <String>[];
    try {
      final document = XmlDocument.parse(enml);
      return document.descendants
          .whereType<XmlElement>()
          .where((element) => element.localName == 'a')
          .map((element) => element.getAttribute('href')?.trim())
          .whereType<String>()
          .where((href) => href.isNotEmpty)
          .toSet()
          .toList(growable: false);
    } on XmlException {
      return const <String>[];
    }
  }

  String _enmlToPlainText(String enml, List<EvernoteEnexResource> resources) {
    if (enml.trim().isEmpty) return '';
    try {
      final document = XmlDocument.parse(enml);
      final resourcesByHash = <String, EvernoteEnexResource>{
        for (final resource in resources)
          if (resource.evernoteHash != null)
            resource.evernoteHash!.toLowerCase(): resource,
      };
      final buffer = StringBuffer();
      for (final child in document.rootElement.children) {
        _writePlainText(child, buffer, resourcesByHash);
      }
      return _normalizePlainText(buffer.toString());
    } on XmlException {
      return _normalizePlainText(
        enml
            .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
            .replaceAll(
              RegExp(r'</(div|p|li|tr)\s*>', caseSensitive: false),
              '\n',
            )
            .replaceAll(RegExp(r'<[^>]+>'), ''),
      );
    }
  }

  void _writePlainText(
    XmlNode node,
    StringBuffer buffer,
    Map<String, EvernoteEnexResource> resourcesByHash,
  ) {
    if (node is XmlText) {
      if (node.value.trim().isEmpty && node.value.contains('\n')) {
        return;
      }
      buffer.write(node.value);
      return;
    }
    if (node is! XmlElement) return;

    final name = node.localName;
    if (name == 'br') {
      buffer.write('\n');
      return;
    }
    if (name == 'en-todo') {
      final checked = node.getAttribute('checked')?.toLowerCase() == 'true';
      buffer.write(checked ? '☑ ' : '☐ ');
      return;
    }
    if (name == 'en-media') {
      final hash = node.getAttribute('hash')?.toLowerCase();
      final resource = hash == null ? null : resourcesByHash[hash];
      final label = resource?.fileName ?? resource?.mimeType ?? 'attachment';
      buffer.write('[Attachment: $label]');
      return;
    }

    final isListItem = name == 'li';
    if (isListItem) buffer.write('- ');
    for (final child in node.children) {
      _writePlainText(child, buffer, resourcesByHash);
    }
    if (<String>{
      'div',
      'p',
      'li',
      'tr',
      'h1',
      'h2',
      'h3',
      'h4',
      'h5',
      'h6',
    }.contains(name)) {
      buffer.write('\n');
    }
  }

  String _normalizePlainText(String value) {
    return value
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\u00a0', ' ')
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
        .join('\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  DateTime? _parseEvernoteDate(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    final compact = RegExp(
      r'^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})(?:\.(\d{1,6}))?Z$',
    ).firstMatch(normalized);
    if (compact != null) {
      final fraction = (compact.group(7) ?? '').padRight(6, '0');
      return DateTime.utc(
        int.parse(compact.group(1)!),
        int.parse(compact.group(2)!),
        int.parse(compact.group(3)!),
        int.parse(compact.group(4)!),
        int.parse(compact.group(5)!),
        int.parse(compact.group(6)!),
        fraction.isEmpty ? 0 : int.parse(fraction.substring(0, 3)),
        fraction.isEmpty ? 0 : int.parse(fraction.substring(3, 6)),
      );
    }
    return DateTime.tryParse(normalized)?.toUtc();
  }

  XmlElement? _firstChild(XmlElement parent, String localName) {
    for (final child in parent.childElements) {
      if (child.localName == localName) return child;
    }
    return null;
  }

  String _childText(XmlElement parent, String localName) =>
      _firstChild(parent, localName)?.innerText ?? '';

  String _innerXml(XmlElement element) =>
      element.children.map((node) => node.toXmlString()).join();

  String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  String? _stringAttribute(Map<String, dynamic> attributes, String key) {
    final value = attributes[key];
    if (value is String) {
      return _nonEmpty(value);
    }
    if (value is List && value.isNotEmpty) {
      return _nonEmpty(value.first.toString());
    }
    return null;
  }

  String? _eventAttribute(XmlStartElementEvent event, String localName) {
    for (final attribute in event.attributes) {
      if (attribute.localName == localName) return attribute.value;
    }
    return null;
  }
}

class _EvernoteDigestSink implements Sink<Digest> {
  Digest? _value;

  Digest get value {
    final digest = _value;
    if (digest == null) {
      throw StateError('The ENEX digest is not available yet.');
    }
    return digest;
  }

  @override
  void add(Digest data) {
    if (_value != null) {
      throw StateError('The ENEX digest was already completed.');
    }
    _value = data;
  }

  @override
  void close() {
    if (_value == null) {
      throw StateError('The ENEX digest was not completed.');
    }
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
