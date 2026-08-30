class EvernoteSearchFeatures {
  const EvernoteSearchFeatures({
    this.resourceMimeTypes = const <String>[],
    this.source,
    this.hasEncryptedText = false,
    this.hasCheckedTodo = false,
    this.hasUncheckedTodo = false,
    this.containsTypes = const <String>{},
  });

  final List<String> resourceMimeTypes;
  final String? source;
  final bool hasEncryptedText;
  final bool hasCheckedTodo;
  final bool hasUncheckedTodo;
  final Set<String> containsTypes;
}

class EvernoteSearchFeatureService {
  const EvernoteSearchFeatureService._();

  static EvernoteSearchFeatures infer({
    required String content,
    Iterable<String> attachmentMimeTypes = const <String>[],
    Iterable<String> taskStatuses = const <String>[],
    Map<String, dynamic> sourceMetadata = const <String, dynamic>{},
  }) {
    final mimes = attachmentMimeTypes
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet();
    final statuses = taskStatuses
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    final contains = <String>{};
    final lower = content.toLowerCase();

    if (mimes.isNotEmpty) contains.add('attachment');
    for (final mime in mimes) {
      if (mime.startsWith('audio/')) contains.add('fileaudio');
      if (mime.startsWith('image/')) contains.add('fileimage');
      if (mime.startsWith('video/')) contains.add('filevideo');
      if (mime == 'application/pdf') contains.add('filepdf');
      if (_archiveMimeTypes.contains(mime)) contains.add('filearchive');
      if (_documentMimeTypes.contains(mime)) contains.add('filedocument');
      if (_presentationMimeTypes.contains(mime)) {
        contains
          ..add('filepresentation')
          ..add('fileoffice');
      }
      if (_spreadsheetMimeTypes.contains(mime)) {
        contains
          ..add('filespreadsheet')
          ..add('fileoffice');
      }
      if (_officeDocumentMimeTypes.contains(mime)) {
        contains
          ..add('filedocument')
          ..add('fileoffice');
      }
    }

    final checkboxMatches = RegExp(
      r'(?m)^\s*[-*+]\s+\[([ xX])\]\s+',
    ).allMatches(content);
    var checkedTodo = false;
    var uncheckedTodo = false;
    for (final match in checkboxMatches) {
      if ((match.group(1) ?? '').trim().isEmpty) {
        uncheckedTodo = true;
      } else {
        checkedTodo = true;
      }
    }
    if (checkedTodo || uncheckedTodo) contains.add('entodo');
    if (statuses.isNotEmpty) {
      contains.add('task');
      if (statuses.any((status) => status == 'completed')) {
        contains.add('taskcompleted');
      }
      if (statuses.any((status) => status != 'completed')) {
        contains.add('tasknotcompleted');
      }
    }

    if (RegExp(r'(?m)^\s*(?:~~~)|[^\n]+').hasMatch(content) &&
        (content.contains(String.fromCharCodes(const <int>[96, 96, 96])) ||
            content.contains('~~~'))) {
      contains.add('encodeblock');
    }
    if (RegExp(r'(?m)^\s*(?:[-*+] |\d+[.)] )').hasMatch(content)) {
      contains.add('list');
    }
    if (RegExp(r'(?m)^\s*\|.*\|\s*$').hasMatch(content)) {
      contains.add('table');
    }
    if (RegExp(r'https?://\S+', caseSensitive: false).hasMatch(content)) {
      contains.add('url');
    }
    if (RegExp(
      r'https?://(?:drive|docs)\.google\.com/\S+',
      caseSensitive: false,
    ).hasMatch(content)) {
      contains.add('urlgoogledrive');
    }
    if (RegExp(
      r'\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b',
      caseSensitive: false,
    ).hasMatch(content)) {
      contains.add('email');
    }
    if (RegExp(r'\b-?\d+\b').hasMatch(content)) {
      contains.add('numberinteger');
    }
    if (RegExp(r'\b-?\d+\.\d+\b').hasMatch(content)) {
      contains.add('numberreal');
    }
    if (RegExp(r'\b\d+(?:\.\d+)?\s*%').hasMatch(content)) {
      contains.add('numberpercent');
    }
    if (RegExp(
      r'(?:[$€£¥￥]\s*\d|\d(?:[\d,.]*\d)?\s*(?:円|usd|eur|jpy))',
      caseSensitive: false,
    ).hasMatch(content)) {
      contains.add('numberprice');
    }
    if (RegExp(r'\b\d{4}[-/]\d{1,2}[-/]\d{1,2}\b').hasMatch(content)) {
      contains.add('date');
    }
    if (RegExp(r'\b(?:[01]?\d|2[0-3]):[0-5]\d\b').hasMatch(content)) {
      contains.add('time');
    }
    if (RegExp(
      r'\b(?:\+?\d[\d ()-]{7,}\d)\b',
    ).hasMatch(content)) {
      contains.add('phonenumber');
    }

    final attributes = _stringMap(sourceMetadata['attributes']);
    final source = _firstNonEmpty(<dynamic>[
      attributes['source'],
      sourceMetadata['source'],
      attributes['source-application'],
    ]);
    final hasEncryptedText =
        sourceMetadata['has_encrypted_text'] == true ||
        lower.contains('<en-crypt') ||
        lower.contains('evernote encrypted');

    if (hasEncryptedText) contains.add('encrypt');

    return EvernoteSearchFeatures(
      resourceMimeTypes: List<String>.unmodifiable(mimes.toList()..sort()),
      source: source,
      hasEncryptedText: hasEncryptedText,
      hasCheckedTodo: checkedTodo,
      hasUncheckedTodo: uncheckedTodo,
      containsTypes: Set<String>.unmodifiable(contains),
    );
  }

  static Map<String, dynamic> _stringMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  static String? _firstNonEmpty(Iterable<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }

  static const Set<String> _archiveMimeTypes = <String>{
    'application/zip',
    'application/x-7z-compressed',
    'application/x-rar-compressed',
    'application/gzip',
    'application/x-tar',
  };

  static const Set<String> _officeDocumentMimeTypes = <String>{
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/rtf',
  };

  static const Set<String> _documentMimeTypes = <String>{
    'text/plain',
    'text/markdown',
    'application/rtf',
    ..._officeDocumentMimeTypes,
  };

  static const Set<String> _presentationMimeTypes = <String>{
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  };

  static const Set<String> _spreadsheetMimeTypes = <String>{
    'text/csv',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  };
}
