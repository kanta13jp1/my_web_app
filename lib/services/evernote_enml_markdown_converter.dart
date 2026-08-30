import 'package:xml/xml.dart';

const String evernoteResourceScheme = 'evernote-resource';
const String evernoteNoteScheme = 'evernote-note';

class EvernoteEnmlResourceReference {
  const EvernoteEnmlResourceReference({
    required this.hash,
    required this.mimeType,
    required this.label,
  });

  final String hash;
  final String mimeType;
  final String label;
}

class EvernoteEnmlMarkdownResult {
  const EvernoteEnmlMarkdownResult({
    required this.markdown,
    required this.unresolvedResourceHashes,
    required this.encryptedSectionCount,
  });

  final String markdown;
  final List<String> unresolvedResourceHashes;
  final int encryptedSectionCount;
}

/// Converts the editable subset of Evernote ENML into the Markdown format used
/// by the note editor. The original ENML remains the recovery source of truth.
class EvernoteEnmlMarkdownConverter {
  const EvernoteEnmlMarkdownConverter();

  EvernoteEnmlMarkdownResult convert({
    required String enml,
    required Iterable<EvernoteEnmlResourceReference> resources,
  }) {
    if (enml.trim().isEmpty) {
      return const EvernoteEnmlMarkdownResult(
        markdown: '',
        unresolvedResourceHashes: <String>[],
        encryptedSectionCount: 0,
      );
    }

    final document = XmlDocument.parse(enml);
    final resourcesByHash = <String, EvernoteEnmlResourceReference>{
      for (final resource in resources)
        if (resource.hash.trim().isNotEmpty)
          resource.hash.trim().toLowerCase(): resource,
    };
    final unresolved = <String>{};
    var encryptedSectionCount = 0;
    final buffer = StringBuffer();
    for (final child in document.rootElement.children) {
      encryptedSectionCount += _writeNode(
        child,
        buffer,
        resourcesByHash,
        unresolved,
        listDepth: 0,
      );
    }

    return EvernoteEnmlMarkdownResult(
      markdown: _normalize(buffer.toString()),
      unresolvedResourceHashes: unresolved.toList(growable: false)..sort(),
      encryptedSectionCount: encryptedSectionCount,
    );
  }

  static String resolveResourceUrls(
    String markdown,
    Map<String, String> urlsByHash,
  ) {
    var resolved = markdown;
    for (final entry in urlsByHash.entries) {
      final reference = '$evernoteResourceScheme:${entry.key.toLowerCase()}';
      resolved = resolved.replaceAll(reference, entry.value);
    }
    return resolved;
  }

  static String? sourceIdFromReference(String reference) {
    final uri = Uri.tryParse(reference);
    if (uri?.scheme != evernoteNoteScheme) return null;
    final encoded = uri!.path.isNotEmpty
        ? uri.path
        : reference.substring('$evernoteNoteScheme:'.length);
    if (encoded.isEmpty) return null;
    return Uri.decodeComponent(encoded);
  }

  int _writeNode(
    XmlNode node,
    StringBuffer buffer,
    Map<String, EvernoteEnmlResourceReference> resourcesByHash,
    Set<String> unresolved, {
    required int listDepth,
  }) {
    if (node is XmlText) {
      final value = node.value;
      if (value.trim().isEmpty && value.contains('\n')) return 0;
      buffer.write(_escapeText(value));
      return 0;
    }
    if (node is! XmlElement) return 0;

    final name = node.localName.toLowerCase();
    if (name == 'br') {
      _newline(buffer);
      return 0;
    }
    if (name == 'hr') {
      _blankLine(buffer);
      buffer.write('---');
      _blankLine(buffer);
      return 0;
    }
    if (name == 'en-todo') {
      final checked = node.getAttribute('checked')?.toLowerCase() == 'true';
      buffer.write(checked ? '- [x] ' : '- [ ] ');
      return 0;
    }
    if (name == 'en-media') {
      _writeMedia(node, buffer, resourcesByHash, unresolved);
      return 0;
    }
    if (name == 'en-crypt') {
      buffer.write(
        '[Encrypted Evernote content — unlock in Evernote before migration]',
      );
      return 1;
    }
    if (name == 'table') {
      _writeTable(node, buffer);
      return 0;
    }
    if (name == 'ul' || name == 'ol') {
      return _writeList(
        node,
        buffer,
        resourcesByHash,
        unresolved,
        ordered: name == 'ol',
        listDepth: listDepth,
      );
    }
    if (name == 'pre') {
      _blankLine(buffer);
      buffer
        ..write('```\n')
        ..write(node.innerText.replaceAll('\r\n', '\n').replaceAll('\r', '\n'))
        ..write('\n```');
      _blankLine(buffer);
      return 0;
    }
    if (name == 'a') {
      final href = node.getAttribute('href')?.trim() ?? '';
      final label = _inlineText(node).trim();
      if (href.isEmpty) {
        buffer.write(_escapeText(label));
      } else {
        final sourceId = _sourceIdFromEvernoteHref(href);
        final target = sourceId == null
            ? href
            : '$evernoteNoteScheme:${Uri.encodeComponent(sourceId)}';
        buffer
          ..write('[')
          ..write(_escapeLabel(label.isEmpty ? href : label))
          ..write('](')
          ..write(target.replaceAll(')', '%29'))
          ..write(')');
      }
      return 0;
    }

    final wrappers = switch (name) {
      'b' || 'strong' => ('**', '**'),
      'i' || 'em' => ('*', '*'),
      's' || 'strike' || 'del' => ('~~', '~~'),
      'code' => ('`', '`'),
      'u' => ('<u>', '</u>'),
      _ => ('', ''),
    };
    if (wrappers.$1.isNotEmpty) buffer.write(wrappers.$1);

    final headingLevel = _headingLevel(name);
    if (headingLevel != null) {
      _blankLine(buffer);
      buffer.write('${List<String>.filled(headingLevel, '#').join()} ');
    } else if (name == 'blockquote') {
      _blankLine(buffer);
      final lines = node.innerText
          .replaceAll('\r\n', '\n')
          .replaceAll('\r', '\n')
          .split('\n');
      buffer.write(lines.map((line) => '> ${line.trim()}').join('\n'));
      _blankLine(buffer);
      return 0;
    }

    var encrypted = 0;
    for (final child in node.children) {
      encrypted += _writeNode(
        child,
        buffer,
        resourcesByHash,
        unresolved,
        listDepth: listDepth,
      );
    }
    if (wrappers.$2.isNotEmpty) buffer.write(wrappers.$2);

    if (headingLevel != null || name == 'p' || name == 'div') {
      _blankLine(buffer);
    }
    return encrypted;
  }

  int _writeList(
    XmlElement list,
    StringBuffer buffer,
    Map<String, EvernoteEnmlResourceReference> resourcesByHash,
    Set<String> unresolved, {
    required bool ordered,
    required int listDepth,
  }) {
    _newline(buffer);
    var encrypted = 0;
    var index = 1;
    for (final item in list.childElements.where(
      (element) => element.localName.toLowerCase() == 'li',
    )) {
      final indent = List<String>.filled(listDepth, '  ').join();
      final marker = ordered ? '${index++}.' : '-';
      buffer.write('$indent$marker ');
      for (final child in item.children) {
        encrypted += _writeNode(
          child,
          buffer,
          resourcesByHash,
          unresolved,
          listDepth: listDepth + 1,
        );
      }
      _newline(buffer);
    }
    return encrypted;
  }

  void _writeMedia(
    XmlElement node,
    StringBuffer buffer,
    Map<String, EvernoteEnmlResourceReference> resourcesByHash,
    Set<String> unresolved,
  ) {
    final hash = node.getAttribute('hash')?.trim().toLowerCase() ?? '';
    final resource = resourcesByHash[hash];
    if (hash.isEmpty || resource == null) {
      unresolved.add(hash.isEmpty ? '<missing-hash>' : hash);
      buffer.write('[Unresolved Evernote attachment]');
      return;
    }

    final label = _escapeLabel(resource.label);
    final reference = '$evernoteResourceScheme:$hash';
    if (resource.mimeType.toLowerCase().startsWith('image/')) {
      buffer.write('![$label]($reference)');
    } else {
      buffer.write('[$label]($reference)');
    }
  }

  void _writeTable(XmlElement table, StringBuffer buffer) {
    final rows = table.descendants
        .whereType<XmlElement>()
        .where((element) => element.localName.toLowerCase() == 'tr')
        .map(
          (row) => row.childElements
              .where(
                (cell) => <String>{'th', 'td'}.contains(
                  cell.localName.toLowerCase(),
                ),
              )
              .map(
                (cell) => cell.innerText
                    .replaceAll('|', r'\|')
                    .replaceAll(RegExp(r'\s+'), ' ')
                    .trim(),
              )
              .toList(growable: false),
        )
        .where((row) => row.isNotEmpty)
        .toList(growable: false);
    if (rows.isEmpty) return;

    final columnCount =
        rows.map((row) => row.length).fold(0, (a, b) => a > b ? a : b);
    String renderRow(List<String> row) {
      final cells = <String>[
        ...row,
        ...List<String>.filled(columnCount - row.length, ''),
      ];
      return '| ${cells.join(' | ')} |';
    }

    _blankLine(buffer);
    buffer
      ..writeln(renderRow(rows.first))
      ..writeln('| ${List<String>.filled(columnCount, '---').join(' | ')} |');
    for (final row in rows.skip(1)) {
      buffer.writeln(renderRow(row));
    }
    _blankLine(buffer);
  }

  int? _headingLevel(String name) {
    final match = RegExp(r'^h([1-6])$').firstMatch(name);
    return match == null ? null : int.parse(match.group(1)!);
  }

  String? _sourceIdFromEvernoteHref(String href) {
    final uri = Uri.tryParse(href);
    if (uri?.scheme.toLowerCase() != 'evernote') return null;
    final segments = uri!.pathSegments;
    final viewIndex = segments.indexOf('view');
    final guidIndex = viewIndex + 3;
    if (viewIndex < 0 || guidIndex >= segments.length) return null;
    final sourceId = segments[guidIndex].trim();
    return sourceId.isEmpty ? null : sourceId;
  }

  String _inlineText(XmlElement element) =>
      element.descendants.whereType<XmlText>().map((node) => node.value).join();

  String _escapeText(String value) {
    return value
        .replaceAll('\\', r'\\')
        .replaceAll('*', r'\*')
        .replaceAll('_', r'\_')
        .replaceAll('[', r'\[')
        .replaceAll(']', r'\]')
        .replaceAll('`', r'\`');
  }

  String _escapeLabel(String value) => value
      .replaceAll('\\', r'\\')
      .replaceAll('[', r'\[')
      .replaceAll(']', r'\]');

  void _newline(StringBuffer buffer) {
    if (buffer.isNotEmpty && !buffer.toString().endsWith('\n')) {
      buffer.write('\n');
    }
  }

  void _blankLine(StringBuffer buffer) {
    if (buffer.isEmpty) return;
    if (buffer.toString().endsWith('\n\n')) return;
    if (buffer.toString().endsWith('\n')) {
      buffer.write('\n');
    } else {
      buffer.write('\n\n');
    }
  }

  String _normalize(String value) {
    return value
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\u00a0', ' ')
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'[ \t]+$'), ''))
        .join('\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}
