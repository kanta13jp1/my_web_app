import 'package:flutter/foundation.dart';

import '../data/repositories/savored_moment_repository.dart';
import '../domain/models/savored_moment.dart';

typedef SavoredMomentClock = DateTime Function();

class SavoredMomentViewModel extends ChangeNotifier {
  SavoredMomentViewModel({
    required SavoredMomentRepository repository,
    required String? userId,
    SavoredMomentClock clock = DateTime.now,
  })  : _repository = repository,
        _userId = userId,
        _clock = clock;

  final SavoredMomentRepository _repository;
  final String? _userId;
  final SavoredMomentClock _clock;

  List<SavoredMoment> _moments = const <SavoredMoment>[];
  bool _isLoading = false;
  bool _loadFailed = false;
  bool _isSaving = false;
  String? _saveError;

  bool get isAuthenticated => _userId != null;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;

  /// True when the history read failed. The panel must then say it could not
  /// look, rather than showing an empty day as if nothing had been savored.
  bool get loadFailed => _loadFailed;
  String? get saveError => _saveError;

  SavoredMomentDigest get digest => _moments.isEmpty
      ? SavoredMomentDigest.empty
      : SavoredMomentDigest.fromMoments(moments: _moments, now: _clock());

  Future<void> load() async {
    if (_userId == null) return;
    _isLoading = true;
    _loadFailed = false;
    notifyListeners();
    try {
      _moments = await _repository.loadSince(
        userId: _userId,
        since: SavoredMomentDigest.windowStart(_clock()),
      );
    } catch (_) {
      _moments = const <SavoredMoment>[];
      _loadFailed = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Saves one line. Returns false without calling the server when the line
  /// is blank or too long, or when a save is already in flight.
  Future<bool> add(String raw) async {
    if (_userId == null || _isSaving) return false;
    final note = normalizeSavoredMomentNote(raw);
    if (note == null) return false;
    _isSaving = true;
    _saveError = null;
    notifyListeners();
    try {
      final saved = await _repository.add(
        userId: _userId,
        date: _clock(),
        note: note,
      );
      _moments = <SavoredMoment>[..._moments, saved];
      return true;
    } catch (_) {
      _saveError = '保存できませんでした。通信状態を確認して、もう一度お試しください。';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
