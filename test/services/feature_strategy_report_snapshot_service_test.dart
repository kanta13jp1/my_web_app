import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/feature_strategy_monitor.dart';
import 'package:my_web_app/services/feature_strategy_monitor_service.dart';
import 'package:my_web_app/services/feature_strategy_report_snapshot_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryFeatureStrategySnapshotRepository
    implements FeatureStrategyReportSnapshotRepository {
  final List<FeatureStrategyDailySnapshot> snapshots =
      <FeatureStrategyDailySnapshot>[];
  final bool failUpsert;

  _MemoryFeatureStrategySnapshotRepository({this.failUpsert = false});

  @override
  Future<List<FeatureStrategyDailySnapshot>> loadRecentSnapshots({
    int limit = 30,
  }) async {
    final ordered = List<FeatureStrategyDailySnapshot>.from(snapshots)
      ..sort((a, b) => b.dateKey.compareTo(a.dateKey));
    return ordered.take(limit).toList(growable: false);
  }

  @override
  Future<void> upsertDailySnapshot(
    FeatureStrategyDailySnapshot snapshot,
  ) async {
    if (failUpsert) {
      throw StateError('offline');
    }
    snapshots.removeWhere((item) => item.dateKey == snapshot.dateKey);
    snapshots.add(snapshot.copyWith(cloudSynced: true));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('recordReport saves strategy history locally and to cloud', () async {
    final repository = _MemoryFeatureStrategySnapshotRepository();
    final service = FeatureStrategyReportSnapshotService(
      snapshotRepository: repository,
    );

    await service.recordReport(
      _buildReport(DateTime(2026, 4, 22, 9), completedDays: 0),
    );
    final summary = await service.recordReport(
      _buildReport(DateTime(2026, 4, 23, 9), completedDays: 2),
    );

    expect(summary.cloudSynced, isTrue);
    expect(summary.snapshotCount, 2);
    expect(summary.latest!.dateKey, '2026-04-23');
    expect(summary.latest!.totalFeatures, 3);
    expect(summary.latest!.priorityFeatureIds, isNotEmpty);
    expect(summary.latest!.reviewDueCount, greaterThanOrEqualTo(0));
    expect(summary.latest!.lifeCapitalLaneCount, greaterThan(0));
    expect(summary.latest!.focusCompletedDaysLast7, 2);
    expect(repository.snapshots, hasLength(2));
  });

  test('recordReport falls back to local history when cloud sync fails',
      () async {
    final service = FeatureStrategyReportSnapshotService(
      snapshotRepository: _MemoryFeatureStrategySnapshotRepository(
        failUpsert: true,
      ),
    );

    final summary = await service.recordReport(
      _buildReport(DateTime(2026, 4, 23, 9), completedDays: 1),
    );
    final reloaded = await service.loadSummary();

    expect(summary.cloudSynced, isFalse);
    expect(summary.snapshotCount, 1);
    expect(reloaded.latest!.dateKey, '2026-04-23');
    expect(reloaded.latest!.focusCompletedDaysLast7, 1);
  });
}

FeatureStrategyReport _buildReport(
  DateTime monitoredAt, {
  required int completedDays,
}) {
  return const FeatureStrategyMonitorService().buildReport(
    catalog: const <FeatureStrategyCatalogItem>[
      FeatureStrategyCatalogItem(
        id: 'task-board',
        sectionId: 'work',
        title: 'Task Board',
        subtitle: 'Organize important work',
        keywords: <String>['task', 'focus'],
      ),
      FeatureStrategyCatalogItem(
        id: 'asset-training',
        sectionId: 'money',
        title: 'Asset Training',
        subtitle: 'Reduce wasteful spending',
        keywords: <String>['money', 'waste'],
      ),
      FeatureStrategyCatalogItem(
        id: 'health-review',
        sectionId: 'health',
        title: 'Health Review',
        subtitle: 'Check sleep and energy',
        keywords: <String>['health', 'energy'],
      ),
    ],
    recentToolIds: <String>['task-board'],
    sectionNamesById: <String, String>{
      'work': 'Work',
      'money': 'Money',
      'health': 'Health',
    },
    focusActionStatsByFeatureId: <String, FeatureStrategyFocusActionStats>{
      'asset-training': FeatureStrategyFocusActionStats(
        featureId: 'asset-training',
        completedDaysLast7: completedDays,
        deferredDaysLast7: 1,
        currentStreakDays: completedDays,
        lastCompletedAt: null,
      ),
    },
    monitoredAt: monitoredAt,
  );
}
