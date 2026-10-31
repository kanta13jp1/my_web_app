/// Build-time and live provider-count helpers for AI University.
///
/// Production CI resolves [aiUniversityBuildProviderCount] from the normalized
/// active provider IDs in `public.ai_university_content` and passes that exact
/// value to Flutter and the static SEO renderer.
const int aiUniversityBuildProviderCount = int.fromEnvironment(
  'AI_UNIVERSITY_PROVIDER_COUNT',
  defaultValue: 0,
);

String normalizeAiUniversityProviderId(Object? value) {
  return value?.toString().trim().toLowerCase() ?? '';
}

List<String> normalizedAiUniversityProviderIds(
  Iterable<Map<String, dynamic>> rows,
) {
  final ids = <String>{};
  for (final row in rows) {
    final id = normalizeAiUniversityProviderId(
      row['provider'] ?? row['provider_id'],
    );
    if (id.isNotEmpty) ids.add(id);
  }
  return ids.toList(growable: false);
}

int aiUniversityProviderCountForDisplay({
  required int liveProviderCount,
  int buildProviderCount = aiUniversityBuildProviderCount,
}) {
  if (liveProviderCount > 0) return liveProviderCount;
  return buildProviderCount > 0 ? buildProviderCount : 0;
}
