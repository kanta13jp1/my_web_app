import 'package:flutter/foundation.dart';

import '../../../../data/repositories/guitar_course_repository.dart';
import '../../../../data/repositories/guitar_tab_repository.dart';
import '../../../../data/services/guitar_lesson_link_service.dart';
import '../../../../domain/models/guitar_daily_course.dart';
import '../../../../domain/models/guitar_tab_song.dart';
import '../../../../domain/use_cases/build_guitar_course_snapshot_use_case.dart';

enum BeatlesGuitarTabsStatus { initial, loading, ready, failure }

class BeatlesGuitarTabsViewModel extends ChangeNotifier {
  BeatlesGuitarTabsViewModel({
    required GuitarTabRepository repository,
    required GuitarCourseRepository courseRepository,
    required GuitarLessonLinkService linkService,
    required BuildGuitarCourseSnapshotUseCase buildCourseSnapshot,
    DateTime Function()? clock,
  })  : _repository = repository,
        _courseRepository = courseRepository,
        _linkService = linkService,
        _buildCourseSnapshot = buildCourseSnapshot,
        _clock = clock ?? DateTime.now;

  final GuitarTabRepository _repository;
  final GuitarCourseRepository _courseRepository;
  final GuitarLessonLinkService _linkService;
  final BuildGuitarCourseSnapshotUseCase _buildCourseSnapshot;
  final DateTime Function() _clock;

  BeatlesGuitarTabsStatus _status = BeatlesGuitarTabsStatus.initial;
  List<GuitarTabSong> _songs = const <GuitarTabSong>[];
  String _query = '';
  GuitarTabDifficulty? _difficulty;
  String? _selectedSongId;
  String? _selectedPracticeStepId;
  int _practiceBpm = 72;
  String? _errorMessage;
  GuitarCourseSnapshot? _courseSnapshot;
  bool _courseActionInProgress = false;
  String? _courseActionError;

  BeatlesGuitarTabsStatus get status => _status;
  List<GuitarTabSong> get songs => List<GuitarTabSong>.unmodifiable(_songs);
  String get query => _query;
  GuitarTabDifficulty? get difficulty => _difficulty;
  int get practiceBpm => _practiceBpm;
  String? get errorMessage => _errorMessage;
  GuitarCourseSnapshot? get courseSnapshot => _courseSnapshot;
  bool get courseActionInProgress => _courseActionInProgress;
  String? get courseActionError => _courseActionError;
  int get recommendedPracticeBpm =>
      selectedPracticeStep?.recommendedBpm ??
      selectedSong?.practiceBpm ??
      _practiceBpm;

  GuitarTabSong? get selectedSong {
    for (final song in _songs) {
      if (song.id == _selectedSongId) return song;
    }
    return null;
  }

  GuitarPracticeStep? get selectedPracticeStep {
    final song = selectedSong;
    if (song == null) return null;
    for (final step in song.practiceSteps) {
      if (step.id == _selectedPracticeStepId) return step;
    }
    return null;
  }

  List<GuitarTabSong> get filteredSongs {
    final normalizedQuery = _query.trim().toLowerCase();
    return List<GuitarTabSong>.unmodifiable(
      _songs.where((song) {
        if (_difficulty != null && song.difficulty != _difficulty) {
          return false;
        }
        if (normalizedQuery.isEmpty) return true;
        final searchable = <String>[
          song.title,
          song.album,
          song.summary,
          ...song.techniques,
          ...song.practiceSteps.expand(
            (step) => <String>[step.title, step.goal, step.cue],
          ),
          ...song.resources.expand(
            (resource) => <String>[
              resource.title,
              resource.provider,
              resource.description,
            ],
          ),
        ].join(' ').toLowerCase();
        return searchable.contains(normalizedQuery);
      }),
    );
  }

  Future<void> load() async {
    _status = BeatlesGuitarTabsStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _songs = await _repository.getSongs();
      final course = await _courseRepository.getCourse();
      final progress = await _courseRepository.getProgress();
      _courseSnapshot = _buildCourseSnapshot(
        days: course,
        progress: progress,
        today: _clock(),
      );
      _status = BeatlesGuitarTabsStatus.ready;
      _selectFirstVisibleSong();
    } catch (_) {
      _songs = const <GuitarTabSong>[];
      _selectedSongId = null;
      _selectedPracticeStepId = null;
      _courseSnapshot = null;
      _status = BeatlesGuitarTabsStatus.failure;
      _errorMessage = 'ギターレッスンを読み込めませんでした。もう一度お試しください。';
    }
    notifyListeners();
  }

  void setQuery(String value) {
    if (_query == value) return;
    _query = value;
    _ensureSelectedSongIsVisible();
    notifyListeners();
  }

  void setDifficulty(GuitarTabDifficulty? value) {
    if (_difficulty == value) return;
    _difficulty = value;
    _ensureSelectedSongIsVisible();
    notifyListeners();
  }

  void selectSong(String songId) {
    for (final song in _songs) {
      if (song.id != songId) continue;
      _selectedSongId = song.id;
      _practiceBpm = song.practiceBpm;
      _selectedPracticeStepId = _defaultPracticeStepId(song);
      notifyListeners();
      return;
    }
  }

  void selectPracticeStep(String stepId) {
    final song = selectedSong;
    if (song == null) return;
    for (final step in song.practiceSteps) {
      if (step.id != stepId) continue;
      if (_selectedPracticeStepId == step.id &&
          _practiceBpm == step.recommendedBpm) {
        return;
      }
      _selectedPracticeStepId = step.id;
      _practiceBpm = step.recommendedBpm;
      notifyListeners();
      return;
    }
  }

  Future<bool> openResource(String resourceId) async {
    final song = selectedSong;
    if (song == null) return false;

    for (final resource in song.resources) {
      if (resource.id != resourceId) continue;
      try {
        return await _linkService.openExternal(resource.url);
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  bool isDailyTaskCompleted(String taskId) {
    return _courseSnapshot?.progress.completedTaskIds.contains(taskId) ?? false;
  }

  Future<bool> toggleDailyTask(String taskId) async {
    final snapshot = _courseSnapshot;
    final day = snapshot?.currentDay;
    if (snapshot == null || day == null || _courseActionInProgress) {
      return false;
    }
    if (!day.tasks.any((task) => task.id == taskId)) return false;

    _courseActionInProgress = true;
    _courseActionError = null;
    notifyListeners();
    try {
      final progress = await _courseRepository.setTaskCompleted(
        dayNumber: day.dayNumber,
        taskId: taskId,
        completed: !snapshot.progress.completedTaskIds.contains(taskId),
      );
      _courseSnapshot = _buildCourseSnapshot(
        days: snapshot.days,
        progress: progress,
        today: _clock(),
      );
      return true;
    } catch (_) {
      _courseActionError = '課題の進捗を保存できませんでした。もう一度お試しください。';
      return false;
    } finally {
      _courseActionInProgress = false;
      notifyListeners();
    }
  }

  Future<bool> completeCurrentCourseDay() async {
    final snapshot = _courseSnapshot;
    final day = snapshot?.currentDay;
    if (snapshot == null ||
        day == null ||
        !snapshot.canCompleteCurrentDay ||
        _courseActionInProgress) {
      return false;
    }

    _courseActionInProgress = true;
    _courseActionError = null;
    notifyListeners();
    try {
      final progress = await _courseRepository.completeDay(
        dayNumber: day.dayNumber,
        completedAt: _clock(),
      );
      _courseSnapshot = _buildCourseSnapshot(
        days: snapshot.days,
        progress: progress,
        today: _clock(),
      );
      return true;
    } catch (_) {
      _courseActionError = '今日のレッスンを完了できませんでした。もう一度お試しください。';
      return false;
    } finally {
      _courseActionInProgress = false;
      notifyListeners();
    }
  }

  void openCurrentCoursePractice() {
    final relatedSongId = _courseSnapshot?.currentDay?.relatedSongId;
    if (relatedSongId == null) return;
    selectSong(relatedSongId);
  }

  void setPracticeBpm(double value) {
    final next = value.round().clamp(60, 180);
    if (_practiceBpm == next) return;
    _practiceBpm = next;
    notifyListeners();
  }

  void resetPracticeBpm() {
    if (selectedSong == null || _practiceBpm == recommendedPracticeBpm) return;
    _practiceBpm = recommendedPracticeBpm;
    notifyListeners();
  }

  void _ensureSelectedSongIsVisible() {
    final visible = filteredSongs;
    if (visible.any((song) => song.id == _selectedSongId)) return;
    _selectFirstVisibleSong();
  }

  void _selectFirstVisibleSong() {
    final visible = filteredSongs;
    if (visible.isEmpty) {
      _selectedSongId = null;
      _selectedPracticeStepId = null;
      return;
    }
    _selectedSongId = visible.first.id;
    _practiceBpm = visible.first.practiceBpm;
    _selectedPracticeStepId = _defaultPracticeStepId(visible.first);
  }

  String? _defaultPracticeStepId(GuitarTabSong song) {
    if (song.practiceSteps.isEmpty) return null;
    for (final step in song.practiceSteps) {
      if (step.recommendedBpm == song.practiceBpm) return step.id;
    }
    return song.practiceSteps.first.id;
  }
}
