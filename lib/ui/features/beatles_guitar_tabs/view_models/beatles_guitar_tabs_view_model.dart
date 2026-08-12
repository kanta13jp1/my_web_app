import 'package:flutter/foundation.dart';

import '../../../../data/repositories/guitar_tab_repository.dart';
import '../../../../domain/models/guitar_tab_song.dart';

enum BeatlesGuitarTabsStatus { initial, loading, ready, failure }

class BeatlesGuitarTabsViewModel extends ChangeNotifier {
  BeatlesGuitarTabsViewModel({required GuitarTabRepository repository})
      : _repository = repository;

  final GuitarTabRepository _repository;

  BeatlesGuitarTabsStatus _status = BeatlesGuitarTabsStatus.initial;
  List<GuitarTabSong> _songs = const <GuitarTabSong>[];
  String _query = '';
  GuitarTabDifficulty? _difficulty;
  String? _selectedSongId;
  int _practiceBpm = 72;
  String? _errorMessage;

  BeatlesGuitarTabsStatus get status => _status;
  List<GuitarTabSong> get songs => List<GuitarTabSong>.unmodifiable(_songs);
  String get query => _query;
  GuitarTabDifficulty? get difficulty => _difficulty;
  int get practiceBpm => _practiceBpm;
  String? get errorMessage => _errorMessage;

  GuitarTabSong? get selectedSong {
    for (final song in _songs) {
      if (song.id == _selectedSongId) return song;
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
      notifyListeners();
      return;
    }
  }

  void setPracticeBpm(double value) {
    final next = value.round().clamp(60, 180);
    if (_practiceBpm == next) return;
    _practiceBpm = next;
    notifyListeners();
  }

  void resetPracticeBpm() {
    final song = selectedSong;
    if (song == null || _practiceBpm == song.practiceBpm) return;
    _practiceBpm = song.practiceBpm;
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
      return;
    }
    _selectedSongId = visible.first.id;
    _practiceBpm = visible.first.practiceBpm;
  }
}
