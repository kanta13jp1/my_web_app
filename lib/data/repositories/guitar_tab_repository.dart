import '../../domain/models/guitar_tab_song.dart';
import '../models/guitar_tab_catalog_model.dart';
import '../services/guitar_tab_catalog_service.dart';

abstract interface class GuitarTabRepository {
  Future<List<GuitarTabSong>> getSongs();
}

class LocalGuitarTabRepository implements GuitarTabRepository {
  const LocalGuitarTabRepository({required this.catalogService});

  final GuitarTabCatalogService catalogService;

  @override
  Future<List<GuitarTabSong>> getSongs() async {
    final catalog = await catalogService.loadCatalog();
    return List<GuitarTabSong>.unmodifiable(catalog.map(_toDomain));
  }

  GuitarTabSong _toDomain(GuitarTabCatalogModel model) {
    return GuitarTabSong(
      id: model.id,
      title: model.title,
      album: model.album,
      year: model.year,
      difficulty: _parseDifficulty(model.difficulty),
      tuning: model.tuning,
      capo: model.capo,
      practiceBpm: model.practiceBpm,
      summary: model.summary,
      techniques: List<String>.unmodifiable(model.techniques),
      sections: List<GuitarTabSection>.unmodifiable(
        model.sections.map(
          (section) => GuitarTabSection(
            title: section.title,
            practiceNote: section.practiceNote,
            lines: List<String>.unmodifiable(section.lines),
          ),
        ),
      ),
      practiceSteps: List<GuitarPracticeStep>.unmodifiable(
        model.practiceSteps.map(
          (step) => GuitarPracticeStep(
            id: step.id,
            title: step.title,
            goal: step.goal,
            cue: step.cue,
            minutes: step.minutes,
            recommendedBpm: step.recommendedBpm,
          ),
        ),
      ),
      resources: List<GuitarLessonResource>.unmodifiable(
        model.resources.map(
          (resource) => GuitarLessonResource(
            id: resource.id,
            title: resource.title,
            provider: resource.provider,
            description: resource.description,
            actionLabel: resource.actionLabel,
            url: Uri.parse(resource.url),
            kind: _parseResourceKind(resource.kind),
          ),
        ),
      ),
    );
  }

  GuitarLessonResourceKind _parseResourceKind(String raw) {
    return switch (raw) {
      'pdfGuide' => GuitarLessonResourceKind.pdfGuide,
      'interactiveScore' => GuitarLessonResourceKind.interactiveScore,
      'videoLesson' => GuitarLessonResourceKind.videoLesson,
      _ => throw FormatException('Unknown guitar lesson resource kind: $raw'),
    };
  }

  GuitarTabDifficulty _parseDifficulty(String raw) {
    return switch (raw) {
      'beginner' => GuitarTabDifficulty.beginner,
      'intermediate' => GuitarTabDifficulty.intermediate,
      'advanced' => GuitarTabDifficulty.advanced,
      _ => throw FormatException('Unknown guitar tab difficulty: $raw'),
    };
  }
}
