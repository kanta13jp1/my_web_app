import '../../domain/models/savored_moment.dart';
import '../services/savored_moment_service.dart';

abstract interface class SavoredMomentRepository {
  /// Moments from [since] (local day) onwards.
  Future<List<SavoredMoment>> loadSince({
    required String userId,
    required DateTime since,
  });

  /// Saves an already-normalized [note] for the local day of [date].
  Future<SavoredMoment> add({
    required String userId,
    required DateTime date,
    required String note,
  });
}

class SupabaseSavoredMomentRepository implements SavoredMomentRepository {
  const SupabaseSavoredMomentRepository({
    required SavoredMomentService service,
  }) : _service = service;

  final SavoredMomentService _service;

  @override
  Future<List<SavoredMoment>> loadSince({
    required String userId,
    required DateTime since,
  }) async {
    final rows = await _service.loadSince(
      userId: userId,
      sinceDate: _dateKey(since),
    );
    return rows.map(_parse).toList(growable: false);
  }

  @override
  Future<SavoredMoment> add({
    required String userId,
    required DateTime date,
    required String note,
  }) async {
    final row = await _service.append(
      userId: userId,
      momentDate: _dateKey(date),
      note: note,
    );
    return _parse(row);
  }

  static SavoredMoment _parse(Map<String, dynamic> row) {
    return SavoredMoment(
      id: (row['id'] as num).toInt(),
      note: row['note'] as String,
      momentDate: DateTime.parse(row['moment_date'] as String),
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  static String _dateKey(DateTime date) {
    final local = date.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}
