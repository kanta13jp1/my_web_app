/// Constitutional/institutional mechanism categories (#2808).
enum InstitutionCategory {
  emergencyDecree('emergency_decree', '緊急政令'),
  termExtension('term_extension', '任期延長'),
  oversight('oversight', '議会統制');

  const InstitutionCategory(this.wireName, this.label);

  final String wireName;
  final String label;
}

/// Foreign institutional reference entry linked to speeches and official URLs.
class ForeignInstitutionEntry {
  const ForeignInstitutionEntry({
    required this.id,
    required this.countryCode,
    required this.countryName,
    required this.category,
    required this.title,
    required this.summary,
    required this.officialUrl,
    required this.citedSpeechIds,
  });

  final String id;
  final String countryCode;
  final String countryName;
  final InstitutionCategory category;
  final String title;
  final String summary;
  final String officialUrl;
  final List<String> citedSpeechIds;
}

/// Service managing foreign institutional comparison data and reverse lookup.
class ForeignInstitutionRefService {
  final List<ForeignInstitutionEntry> _entries = <ForeignInstitutionEntry>[];

  /// Validates that [rawUrl] uses http:// or https:// with a valid host.
  String validateOfficialUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('officialUrl must not be empty.');
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      throw ArgumentError('officialUrl must be a valid http/https URL.');
    }
    return uri.toString();
  }

  /// Registers a country/institution entry after validating required fields.
  ForeignInstitutionEntry registerEntry(ForeignInstitutionEntry entry) {
    final id = entry.id.trim();
    final countryCode = entry.countryCode.trim().toUpperCase();
    final countryName = entry.countryName.trim();
    final title = entry.title.trim();
    final summary = entry.summary.trim();

    if (id.isEmpty ||
        countryCode.isEmpty ||
        countryName.isEmpty ||
        title.isEmpty ||
        summary.isEmpty) {
      throw ArgumentError('All institutional reference fields are required.');
    }

    final normalizedUrl = validateOfficialUrl(entry.officialUrl);
    final speechIds = entry.citedSpeechIds
        .map((String s) => s.trim())
        .where((String s) => s.isNotEmpty)
        .toSet()
        .toList();

    final sanitized = ForeignInstitutionEntry(
      id: id,
      countryCode: countryCode,
      countryName: countryName,
      category: entry.category,
      title: title,
      summary: summary,
      officialUrl: normalizedUrl,
      citedSpeechIds: List<String>.unmodifiable(speechIds),
    );
    _entries.add(sanitized);
    return sanitized;
  }

  /// Returns entries filtered by [countryCode], or all entries when null/empty.
  List<ForeignInstitutionEntry> filterByCountry([String? countryCode]) {
    final target = countryCode?.trim().toUpperCase() ?? '';
    if (target.isEmpty) {
      return List<ForeignInstitutionEntry>.unmodifiable(_entries);
    }
    return List<ForeignInstitutionEntry>.unmodifiable(
      _entries.where(
        (ForeignInstitutionEntry item) => item.countryCode == target,
      ),
    );
  }

  /// Reverse-lookup of foreign cases cited in [speechId].
  List<ForeignInstitutionEntry> findBySpeechId(String speechId) {
    final target = speechId.trim();
    if (target.isEmpty) {
      return const <ForeignInstitutionEntry>[];
    }
    return List<ForeignInstitutionEntry>.unmodifiable(
      _entries.where(
        (ForeignInstitutionEntry item) => item.citedSpeechIds.contains(target),
      ),
    );
  }

  /// Distinct country codes sorted alphabetically.
  List<String> get countries {
    final codes =
        _entries.map((ForeignInstitutionEntry e) => e.countryCode).toSet();
    final sorted = codes.toList()..sort();
    return List<String>.unmodifiable(sorted);
  }
}
