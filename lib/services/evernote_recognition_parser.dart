import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:xml/xml.dart';

const int defaultEvernoteRecognitionMaxCharacters = 4 * 1024 * 1024;
const int defaultEvernoteRecognitionMaxRegions = 50000;
const int defaultEvernoteRecognitionMaxCandidates = 500000;
const int defaultEvernoteRecognitionMaxCandidateCharacters = 4096;

class EvernoteRecognitionCandidate {
  const EvernoteRecognitionCandidate({
    required this.text,
    required this.weight,
  });

  final String text;
  final int weight;

  Map<String, Object> toManifestJson() => <String, Object>{
        'text': text,
        'weight': weight,
      };
}

class EvernoteRecognitionRegion {
  EvernoteRecognitionRegion({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required List<EvernoteRecognitionCandidate> candidates,
  }) : candidates = List.unmodifiable(candidates);

  final int x;
  final int y;
  final int width;
  final int height;
  final List<EvernoteRecognitionCandidate> candidates;

  EvernoteRecognitionCandidate get displayCandidate {
    if (candidates.isEmpty) {
      throw StateError('Recognition region has no candidates.');
    }
    var best = candidates.first;
    for (final candidate in candidates.skip(1)) {
      if (candidate.weight > best.weight) {
        best = candidate;
      }
    }
    return best;
  }

  Map<String, dynamic> toManifestJson() => <String, dynamic>{
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'candidates': candidates
            .map((candidate) => candidate.toManifestJson())
            .toList(growable: false),
      };
}

class EvernoteRecognitionIndex {
  EvernoteRecognitionIndex({
    required this.rawSha256,
    required this.documentType,
    required this.objectType,
    required this.objectId,
    required this.engineVersion,
    required this.recognitionType,
    required this.language,
    required this.objectWidth,
    required this.objectHeight,
    required List<EvernoteRecognitionRegion> regions,
  }) : regions = List.unmodifiable(regions);

  final String rawSha256;
  final String? documentType;
  final String? objectType;
  final String? objectId;
  final String? engineVersion;
  final String? recognitionType;
  final String? language;
  final int? objectWidth;
  final int? objectHeight;
  final List<EvernoteRecognitionRegion> regions;

  String get searchText {
    return regions
        .expand((region) => region.candidates)
        .map(
          (candidate) => candidate.text.replaceAll(RegExp(r'\s+'), ' ').trim(),
        )
        .where((text) => text.isNotEmpty)
        .join(' ');
  }

  Map<String, dynamic> toManifestJson() => <String, dynamic>{
        'raw_sha256': rawSha256,
        'document_type': documentType,
        'object_type': objectType,
        'object_id': objectId,
        'engine_version': engineVersion,
        'recognition_type': recognitionType,
        'language': language,
        'object_width': objectWidth,
        'object_height': objectHeight,
        'search_text': searchText,
        'regions': regions
            .map((region) => region.toManifestJson())
            .toList(growable: false),
      };
}

class EvernoteRecognitionParser {
  const EvernoteRecognitionParser({
    this.maxCharacters = defaultEvernoteRecognitionMaxCharacters,
    this.maxRegions = defaultEvernoteRecognitionMaxRegions,
    this.maxCandidates = defaultEvernoteRecognitionMaxCandidates,
    this.maxCandidateCharacters =
        defaultEvernoteRecognitionMaxCandidateCharacters,
  });

  static const Set<String> _rootAttributes = {
    'docType',
    'objType',
    'objID',
    'engineVersion',
    'recoType',
    'lang',
    'objWidth',
    'objHeight',
  };
  static const Set<String> _regionAttributes = {'x', 'y', 'w', 'h'};
  static const Set<String> _candidateAttributes = {'w'};

  final int maxCharacters;
  final int maxRegions;
  final int maxCandidates;
  final int maxCandidateCharacters;

  EvernoteRecognitionIndex parse(String rawXml) {
    if (rawXml.length > maxCharacters) {
      throw FormatException(
        'Evernote recognition XML exceeds the $maxCharacters character limit.',
      );
    }

    final sanitizedXml = _removeSafePreamble(rawXml);
    late final XmlDocument document;
    try {
      document = XmlDocument.parse(sanitizedXml);
    } on Object catch (error) {
      throw FormatException('Invalid Evernote recognition XML: $error');
    }

    final root = document.rootElement;
    _expectName(root, 'recoIndex');
    _expectAttributes(root, _rootAttributes);

    final objectWidth = _optionalPositiveInt(root, 'objWidth');
    final objectHeight = _optionalPositiveInt(root, 'objHeight');
    final regions = <EvernoteRecognitionRegion>[];
    var candidateCount = 0;

    for (final child in root.childElements) {
      _expectName(child, 'item');
      _expectAttributes(child, _regionAttributes);
      if (regions.length >= maxRegions) {
        throw FormatException(
          'Evernote recognition XML exceeds the $maxRegions region limit.',
        );
      }

      final candidates = <EvernoteRecognitionCandidate>[];
      for (final candidateElement in child.childElements) {
        _expectName(candidateElement, 't');
        _expectAttributes(candidateElement, _candidateAttributes);
        if (candidateElement.childElements.isNotEmpty) {
          throw const FormatException(
            'Evernote recognition candidate cannot contain child elements.',
          );
        }
        if (candidateCount >= maxCandidates) {
          throw FormatException(
            'Evernote recognition XML exceeds the $maxCandidates candidate limit.',
          );
        }

        final text = candidateElement.innerText.trim();
        if (text.isEmpty) {
          throw const FormatException(
            'Evernote recognition candidate text cannot be empty.',
          );
        }
        if (text.length > maxCandidateCharacters) {
          throw FormatException(
            'Evernote recognition candidate exceeds the '
            '$maxCandidateCharacters character limit.',
          );
        }

        candidates.add(
          EvernoteRecognitionCandidate(
            text: text,
            weight: _requiredNonNegativeInt(candidateElement, 'w'),
          ),
        );
        candidateCount += 1;
      }

      if (candidates.isEmpty) {
        throw const FormatException(
          'Evernote recognition region must contain at least one candidate.',
        );
      }

      regions.add(
        EvernoteRecognitionRegion(
          x: _requiredNonNegativeInt(child, 'x'),
          y: _requiredNonNegativeInt(child, 'y'),
          width: _requiredNonNegativeInt(child, 'w'),
          height: _requiredNonNegativeInt(child, 'h'),
          candidates: candidates,
        ),
      );
    }

    return EvernoteRecognitionIndex(
      rawSha256: sha256.convert(utf8.encode(rawXml)).toString(),
      documentType: root.getAttribute('docType'),
      objectType: root.getAttribute('objType'),
      objectId: root.getAttribute('objID'),
      engineVersion: root.getAttribute('engineVersion'),
      recognitionType: root.getAttribute('recoType'),
      language: root.getAttribute('lang'),
      objectWidth: objectWidth,
      objectHeight: objectHeight,
      regions: regions,
    );
  }

  String _removeSafePreamble(String rawXml) {
    var value = rawXml.replaceFirst('\uFEFF', '').trim();
    final forbidden = RegExp(
      r'<!ENTITY|<!\[INCLUDE|<!\[IGNORE|<\s*(?:xi:include|xinclude)\b',
      caseSensitive: false,
    );
    if (forbidden.hasMatch(value)) {
      throw const FormatException(
        'External entities, conditional sections, and includes are forbidden.',
      );
    }

    value = value.replaceFirst(
      RegExp(r'^<\?xml\b[^?]*\?>', caseSensitive: false),
      '',
    );
    value = value.trimLeft();

    final doctypeMatches =
        RegExp(r'<!DOCTYPE\b', caseSensitive: false).allMatches(value).toList();
    if (doctypeMatches.length > 1) {
      throw const FormatException(
        'Evernote recognition XML cannot contain multiple DOCTYPE declarations.',
      );
    }
    if (doctypeMatches.isEmpty) {
      return value;
    }
    if (doctypeMatches.single.start != 0) {
      throw const FormatException(
        'Evernote recognition DOCTYPE must appear before the root element.',
      );
    }

    final end = value.indexOf('>');
    if (end < 0) {
      throw const FormatException(
        'Evernote recognition DOCTYPE is not terminated.',
      );
    }
    final doctype = value.substring(0, end + 1);
    final normalized = doctype.replaceAll(RegExp(r'\s+'), ' ');
    final expectedUrl = RegExp(
      r'''["']https?://xml\.evernote\.com/pub/recoIndex\.dtd["']''',
      caseSensitive: false,
    );
    if (!RegExp(
          r'^<!DOCTYPE\s+recoIndex\b',
          caseSensitive: false,
        ).hasMatch(normalized) ||
        !expectedUrl.hasMatch(normalized) ||
        normalized.contains('[') ||
        normalized.contains(']') ||
        normalized.contains('%') ||
        RegExp(r'<.*<', dotAll: true).hasMatch(normalized)) {
      throw const FormatException(
        'Only the external Evernote recoIndex DTD declaration is allowed.',
      );
    }

    value = value.substring(end + 1).trimLeft();
    if (RegExp(r'<!DOCTYPE\b', caseSensitive: false).hasMatch(value)) {
      throw const FormatException(
        'Evernote recognition XML cannot contain a nested DOCTYPE.',
      );
    }
    return value;
  }

  void _expectName(XmlElement element, String expected) {
    if (element.name.qualified != expected) {
      throw FormatException(
        'Unexpected Evernote recognition element <${element.name.qualified}>.',
      );
    }
  }

  void _expectAttributes(XmlElement element, Set<String> allowed) {
    for (final attribute in element.attributes) {
      if (!allowed.contains(attribute.name.qualified)) {
        throw FormatException(
          'Unexpected attribute ${attribute.name.qualified} on '
          '<${element.name.qualified}>.',
        );
      }
    }
  }

  int _requiredNonNegativeInt(XmlElement element, String attribute) {
    final value = element.getAttribute(attribute);
    final parsed = value == null ? null : int.tryParse(value);
    if (parsed == null || parsed < 0) {
      throw FormatException(
        'Attribute $attribute on <${element.name.qualified}> '
        'must be a non-negative integer.',
      );
    }
    return parsed;
  }

  int? _optionalPositiveInt(XmlElement element, String attribute) {
    final value = element.getAttribute(attribute);
    if (value == null || value.isEmpty) {
      return null;
    }
    final parsed = int.tryParse(value);
    if (parsed == null || parsed <= 0) {
      throw FormatException(
        'Attribute $attribute on <${element.name.qualified}> '
        'must be a positive integer.',
      );
    }
    return parsed;
  }
}
