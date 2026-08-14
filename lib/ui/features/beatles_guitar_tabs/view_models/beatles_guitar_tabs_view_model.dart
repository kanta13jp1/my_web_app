import 'package:flutter/foundation.dart';

import '../../../../data/repositories/guitar_tab_repository.dart';
import '../../../../data/services/guitar_lesson_link_service.dart';
import '../../../../domain/models/guitar_tab_song.dart';

enum BeatlesGuitarTabsStatus { initial, loading, ready, failure }

class BeatlesGuitarTabsViewModel extends ChangeNotifier {
  BeatlesGuitarTabsViewModel({
    required GuitarTabRepository repository,
    required GuitarLessonLinkService linkService,
  })  : _repository = repository,
        _linkService = linkService;

  final GuitarTabRepository _repository;
  final GuitarLessonLinkService _linkService;

  BeatlesGuitarTabsStatus _status = BeatlesGuitarTabsStatus.initial;
  List<GuitarTabSong> _songs = const <GuitarTabSong>[];
  String _query = '';
  GuitarTabDifficulty? _difficulty;
  String? _selectedSongId;
  String? _selectedPracticeStepId;
  int _practiceBpm = 72;
  String? _errorMessage;

  BeatlesGuitarTabsStatus get status => _status;
  List<GuitarTabSong> get songs => List<GuitarTabSong>.unmodifiable(_songs);
  String get query => _query;
  GuitarTabDifficulty? get difficulty => _difficulty;
  int get practiceBpm => _practiceBpm;
  String? get errorMessage => _errorMessage;
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
      _status = BeatlesGuitarTabsStatus.ready;
      _selectFirstVisibleSong();
    } catch (_) {
      _songs = const <GuitarTabSong>[];
      _selectedSongId = null;
      _selectedPracticeStepId = null;
      _status = BeatlesGuitarTabsStatus.failure;
      _errorMessage = 'タブ譜カタログを読み込めませんでした。もう一度お試しください。';
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
