enum GuitarTabDifficulty { beginner, intermediate, advanced }

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
}
