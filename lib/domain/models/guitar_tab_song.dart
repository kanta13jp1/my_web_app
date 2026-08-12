enum GuitarTabDifficulty { beginner, intermediate, advanced }

enum GuitarLessonResourceKind { pdfGuide, interactiveScore, videoLesson }

class GuitarLessonResource {
  const GuitarLessonResource({
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
  final Uri url;
  final GuitarLessonResourceKind kind;
}

class GuitarPracticeStep {
  const GuitarPracticeStep({
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

class GuitarTabSection {
  const GuitarTabSection({
    required this.title,
    required this.practiceNote,
    required this.lines,
  });

  final String title;
  final String practiceNote;
  final List<String> lines;
}

class GuitarTabSong {
  const GuitarTabSong({
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
    this.practiceSteps = const <GuitarPracticeStep>[],
    this.resources = const <GuitarLessonResource>[],
  });

  final String id;
  final String title;
  final String album;
  final int year;
  final GuitarTabDifficulty difficulty;
  final String tuning;
  final String capo;
  final int practiceBpm;
  final String summary;
  final List<String> techniques;
  final List<GuitarTabSection> sections;
  final List<GuitarPracticeStep> practiceSteps;
  final List<GuitarLessonResource> resources;
}
