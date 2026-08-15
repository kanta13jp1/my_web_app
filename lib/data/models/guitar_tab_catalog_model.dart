class GuitarTabSectionCatalogModel {
  const GuitarTabSectionCatalogModel({
    required this.title,
    required this.practiceNote,
    required this.lines,
  });

  final String title;
  final String practiceNote;
  final List<String> lines;
}

class GuitarPracticeStepCatalogModel {
  const GuitarPracticeStepCatalogModel({
    required this.id,
    required this.title,
    required this.goal,
    required this.cue,
    required this.minutes,
    required this.recommendedBpm,
  });

  final String id;
  final String title;
  final String goal;
  final String cue;
  final int minutes;
  final int recommendedBpm;
}

class GuitarLessonResourceCatalogModel {
  const GuitarLessonResourceCatalogModel({
    required this.id,
    required this.title,
    required this.provider,
    required this.description,
    required this.actionLabel,
    required this.url,
    required this.kind,
  });

  final String id;
  final String title;
  final String provider;
  final String description;
  final String actionLabel;
  final String url;
  final String kind;
}

class GuitarTabCatalogModel {
  const GuitarTabCatalogModel({
    required this.id,
    required this.title,
    required this.album,
    required this.year,
    required this.difficulty,
    required this.tuning,
    required this.capo,
    required this.practiceBpm,
    required this.summary,
    required this.techniques,
    required this.sections,
    this.practiceSteps = const <GuitarPracticeStepCatalogModel>[],
    this.resources = const <GuitarLessonResourceCatalogModel>[],
  });

  final String id;
  final String title;
  final String album;
  final int year;
  final String difficulty;
  final String tuning;
  final String capo;
  final int practiceBpm;
  final String summary;
  final List<String> techniques;
  final List<GuitarTabSectionCatalogModel> sections;
  final List<GuitarPracticeStepCatalogModel> practiceSteps;
  final List<GuitarLessonResourceCatalogModel> resources;
}
