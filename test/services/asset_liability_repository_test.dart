import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_persistence.dart';
import 'package:my_web_app/models/asset_liability_sync_audit_log.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';
import 'package:my_web_app/services/asset_liability_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AssetLiabilityRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('saves and restores monthly state through local repository', () async {
      const repository = SharedPreferencesAssetLiabilityRepository();
      final month = DateTime(2026, 5, 14);

      await repository.saveMonth(
        month: month,
        state: AssetLiabilityMonthlyState(
          paymentOverrides: const <String, double>{
            'mobit': 70000,
            'kddi_provider': 5764,
          },
          actualPaymentAmounts: const <String, double>{'kddi_provider': 5764},
          paymentDifferenceReasons: const <String, String>{
            'kddi_provider': 'confirmed bill',
          },
          paidAccountNames: const <String>{'kddi_provider'},
          paymentSourceAccountIds: const <String, String>{
            'mobit': 'smbc_otsuka',
          },
          cardBillingAccountIds: const <String, String>{
            'kddi_provider': 'paypay_card',
          },
          cardStatementLines: <AssetLiabilityCardStatementLine>[
            AssetLiabilityCardStatementLine(
              id: 'line_1',
              billingAccountId: 'paypay_card',
              billingAccountName: 'PayPay card',
              postedAt: DateTime(2026, 5, 12),
              description: 'KDDI',
              amount: 5764,
            ),
          ],
          incomePlans: <AssetLiabilityIncomePlan>[
            AssetLiabilityIncomePlan(
              id: 'salary',
              date: DateTime(2026, 5, 25),
              name: 'Salary',
              amount: 250000,
              destinationAccountId: 'smbc_otsuka',
              destinationAccountName: 'SMBC Otsuka',
              received: false,
            ),
          ],
        ),
      );

      final restored = await repository.loadMonth(DateTime(2026, 5, 31));

      expect(restored.paymentOverrides['mobit'], 70000);
      expect(restored.paymentOverrides['kddi_provider'], 5764);
      expect(restored.actualPaymentAmounts['kddi_provider'], 5764);
      expect(
        restored.paymentDifferenceReasons['kddi_provider'],
        'confirmed bill',
      );
      expect(restored.paidAccountNames, contains('kddi_provider'));
      expect(restored.paymentSourceAccountIds['mobit'], 'smbc_otsuka');
      expect(restored.cardBillingAccountIds['kddi_provider'], 'paypay_card');
      expect(
        restored.cardStatementLines.single.billingAccountId,
        'paypay_card',
      );
      expect(restored.cardStatementLines.single.amount, 5764);
      expect(restored.incomePlans.single.name, 'Salary');
      expect(restored.incomePlans.single.received, isFalse);
    });

    test(
      'keeps SharedPreferences persistence working without Supabase',
      () async {
        const repository = SharedPreferencesAssetLiabilityRepository();

        await repository.saveDefaultPaymentSources(const <String, String>{
          'kddi_provider': 'smbc_otsuka',
        });
        await repository.saveDefaultCardBillingAccounts(const <String, String>{
          'kddi_provider': 'paypay_card',
        });
        await repository.saveRecurringIncomeTemplates(
          const <AssetLiabilityRecurringIncomeTemplate>[
            AssetLiabilityRecurringIncomeTemplate(
              id: 'salary',
              dayOfMonth: 25,
              name: 'Salary',
              amount: 250000,
              destinationAccountId: 'smbc_otsuka',
              destinationAccountName: 'SMBC Otsuka',
            ),
          ],
        );

        final defaults = await repository.loadDefaultPaymentSources();
        final cardDefaults = await repository.loadDefaultCardBillingAccounts();
        final templates = await repository.loadRecurringIncomeTemplates();

        expect(defaults, <String, String>{'kddi_provider': 'smbc_otsuka'});
        expect(cardDefaults, <String, String>{'kddi_provider': 'paypay_card'});
        expect(templates.single.id, 'salary');
        expect(templates.single.destinationAccountId, 'smbc_otsuka');
      },
    );

    test('saves and restores monthly snapshots through repository', () async {
      const repository = SharedPreferencesAssetLiabilityRepository();
      final snapshot = AssetLiabilityMonthlySnapshot(
        monthKey: '2026-05',
        savedAt: DateTime.utc(2026, 5, 31, 12),
        positiveAssetTotal: 120000,
        liabilityTotal: -7200000,
        netWorth: -7080000,
        cashLikeTotal: 60000,
        monthlyScheduledPaymentTotal: 180000,
        monthlyPaidPaymentTotal: 100000,
        monthlyUnpaidPaymentTotal: 80000,
        monthlyActualPaymentTotal: 102000,
        monthlyPaymentDifferenceTotal: 2000,
        overduePaymentCount: 1,
      );

      await repository.saveMonthlySnapshot(snapshot);

      final snapshots = await repository.loadMonthlySnapshots();

      expect(snapshots, hasLength(1));
      expect(snapshots.single.monthKey, '2026-05');
      expect(snapshots.single.monthlyUnpaidPaymentTotal, 80000);
    });

    test('saves and restores sync audit logs through repository', () async {
      const repository = SharedPreferencesAssetLiabilityRepository();

      await repository.saveSyncAuditLog(
        AssetLiabilitySyncAuditLog.create(
          type: AssetLiabilitySyncAuditType.preview,
          monthKey: '2026-05',
          targetDataType: 'all_targets',
          count: 5,
          result: 'success',
          executedAt: DateTime.utc(2026, 5, 14, 12),
        ),
      );

      final logs = await repository.loadSyncAuditLogs();

      expect(logs, hasLength(1));
      expect(logs.single.type, AssetLiabilitySyncAuditType.preview);
      expect(logs.single.monthKey, '2026-05');
      expect(logs.single.count, 5);
    });

    test('builds a full local persistence snapshot', () async {
      const repository = SharedPreferencesAssetLiabilityRepository();
      final month = DateTime(2026, 5, 1);

      await repository.saveMonth(
        month: month,
        state: const AssetLiabilityMonthlyState(
          paymentOverrides: <String, double>{'mobit': 70000},
        ),
      );
      await repository.saveDefaultPaymentSources(const <String, String>{
        'mobit': 'smbc_otsuka',
      });
      await repository.saveDefaultCardBillingAccounts(const <String, String>{
        'kddi_provider': 'paypay_card',
      });
      await repository.saveMonthlySnapshot(
        AssetLiabilityMonthlySnapshot(
          monthKey: '2026-05',
          savedAt: DateTime.utc(2026, 5, 31, 12),
          positiveAssetTotal: 120000,
          liabilityTotal: -7200000,
          netWorth: -7080000,
          cashLikeTotal: 60000,
          monthlyScheduledPaymentTotal: 180000,
          monthlyPaidPaymentTotal: 100000,
          monthlyUnpaidPaymentTotal: 80000,
          overduePaymentCount: 1,
        ),
      );

      final snapshot = await repository.loadPersistenceSnapshot(month);

      expect(snapshot.monthKey, '2026-05');
      expect(snapshot.monthlyState.paymentOverrides['mobit'], 70000);
      expect(snapshot.defaultPaymentSourceAccountIds['mobit'], 'smbc_otsuka');
      expect(
        snapshot.defaultCardBillingAccountIds['kddi_provider'],
        'paypay_card',
      );
      expect(snapshot.monthlySnapshots.single.netWorth, -7080000);
    });

    test(
      'supports fake repository implementations for Supabase-free tests',
      () async {
        final repository = _FakeAssetLiabilityRepository();
        final month = DateTime(2026, 6, 1);

        await repository.saveMonth(
          month: month,
          state: const AssetLiabilityMonthlyState(
            paymentOverrides: <String, double>{'kddi_provider': 5764},
          ),
        );
        await repository.saveMonthlySnapshot(
          AssetLiabilityMonthlySnapshot(
            monthKey: '2026-06',
            savedAt: DateTime.utc(2026, 6, 30, 12),
            positiveAssetTotal: 100000,
            liabilityTotal: -7000000,
            netWorth: -6900000,
            cashLikeTotal: 50000,
            monthlyScheduledPaymentTotal: 160000,
            monthlyPaidPaymentTotal: 160000,
            monthlyUnpaidPaymentTotal: 0,
            overduePaymentCount: 0,
          ),
        );

        final restored = await repository.loadPersistenceSnapshot(month);

        expect(restored.monthlyState.paymentOverrides['kddi_provider'], 5764);
        expect(restored.monthlySnapshots.single.monthKey, '2026-06');
      },
    );
  });

  group('FeatureFlaggedAssetLiabilityRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('factory keeps Supabase sync disabled by default', () {
      final local = _FakeAssetLiabilityRepository();
      final remote = _RecordingAssetLiabilityRemoteStore();

      final repository = AssetLiabilityRepositoryFactory.createDefault(
        localRepository: local,
        remoteStore: remote,
      );

      expect(AssetLiabilityRepositoryFactory.supabaseSyncEnabled, isFalse);
      expect(AssetLiabilityRepositoryFactory.supabaseWritesEnabled, isFalse);
      expect(repository, same(local));
      expect(remote.calls, isEmpty);
    });

    test('factory enables sync without production writes by default', () {
      final local = _FakeAssetLiabilityRepository();
      final remote = _RecordingAssetLiabilityRemoteStore();

      final repository = AssetLiabilityRepositoryFactory.createDefault(
        localRepository: local,
        remoteStore: remote,
        syncEnabled: true,
        userIdProvider: () => 'user-1',
      );

      expect(repository.supabaseSyncEnabled, isTrue);
      expect(repository.supabaseWritesEnabled, isFalse);
      expect(remote.calls, isEmpty);
    });

    test('manual sync stays disabled when feature flag is off', () async {
      final local = _FakeAssetLiabilityRepository();
      final remote = _RecordingAssetLiabilityRemoteStore();
      final repository = FeatureFlaggedAssetLiabilityRepository(
        localRepository: local,
        remoteStore: remote,
        syncEnabled: false,
        userIdProvider: () => 'user-1',
      );
      await local.saveMonth(
        month: DateTime(2026, 5),
        state: _sampleMonthlyState(),
      );

      final result = await repository.syncMonth(DateTime(2026, 5));

      expect(result.status, AssetLiabilityManualSyncStatus.disabled);
      expect(remote.calls, isEmpty);
    });

    test('sync preview stays disabled when feature flag is off', () async {
      final local = _FakeAssetLiabilityRepository();
      final remote = _RecordingAssetLiabilityRemoteStore();
      final repository = FeatureFlaggedAssetLiabilityRepository(
        localRepository: local,
        remoteStore: remote,
        syncEnabled: false,
        userIdProvider: () => 'user-1',
      );
      await local.saveMonth(
        month: DateTime(2026, 5),
        state: _sampleMonthlyState(),
      );

      final result = await repository.previewSyncMonth(DateTime(2026, 5));

      expect(result.status, AssetLiabilityManualSyncStatus.disabled);
      expect(result.targetCount, 0);
      expect(remote.calls, isEmpty);
    });

    test('sync preview reports upload candidates without saving', () async {
      final local = _FakeAssetLiabilityRepository();
      final remote = _RecordingAssetLiabilityRemoteStore();
      final repository = FeatureFlaggedAssetLiabilityRepository(
        localRepository: local,
        remoteStore: remote,
        syncEnabled: true,
        remoteWritesEnabled: true,
        userIdProvider: () => 'user-1',
      );
      final month = DateTime(2026, 5);
      await local.saveMonth(month: month, state: _sampleMonthlyState());
      await local.saveDefaultPaymentSources(const <String, String>{
        'mobit': 'smbc_otsuka',
      });
      await local.saveRecurringIncomeTemplates(
        <AssetLiabilityRecurringIncomeTemplate>[
          _sampleRecurringIncomeTemplate(),
        ],
      );
      await local.saveMonthlySnapshot(_sampleSnapshot('2026-05'));

      final result = await repository.previewSyncMonth(month);

      expect(result.status, AssetLiabilityManualSyncStatus.success);
      expect(result.targetCount, 5);
      expect(result.localDataTargetCount, 4);
      expect(result.remoteDataTargetCount, 0);
      expect(result.uploadCandidateCount, 4);
      expect(result.downloadCandidateCount, 0);
      expect(result.conflictCount, 0);
      expect(remote.monthState('2026-05'), isNull);
      expect(remote.calls, isNot(contains('saveMonth:user-1:2026-05')));
      expect(remote.defaultPaymentSources, isEmpty);
      expect(remote.recurringIncomeTemplates, isEmpty);
      expect(remote.monthlySnapshots, isEmpty);
    });

    test(
      'sync preview records preview and upload candidate audit logs',
      () async {
        const local = SharedPreferencesAssetLiabilityRepository();
        final remote = _RecordingAssetLiabilityRemoteStore();
        final repository = FeatureFlaggedAssetLiabilityRepository(
          localRepository: local,
          remoteStore: remote,
          syncEnabled: true,
          remoteWritesEnabled: true,
          userIdProvider: () => 'user-1',
        );
        final month = DateTime(2026, 5);
        await local.saveMonth(month: month, state: _sampleMonthlyState());

        final result = await repository.previewSyncMonth(month);
        final logs = await repository.loadSyncAuditLogs();

        expect(result.status, AssetLiabilityManualSyncStatus.success);
        expect(
          logs.map((log) => log.type),
          containsAll(<AssetLiabilitySyncAuditType>[
            AssetLiabilitySyncAuditType.preview,
            AssetLiabilitySyncAuditType.uploadCandidate,
          ]),
        );
        expect(remote.calls, isNot(contains('saveMonth:user-1:2026-05')));
      },
    );

    test(
      'sync preview reports download candidates without restoring',
      () async {
        final local = _FakeAssetLiabilityRepository();
        final remote = _RecordingAssetLiabilityRemoteStore()
          ..seedMonth(DateTime(2026, 5), _sampleMonthlyState());
        final repository = FeatureFlaggedAssetLiabilityRepository(
          localRepository: local,
          remoteStore: remote,
          syncEnabled: true,
          remoteWritesEnabled: true,
          userIdProvider: () => 'user-1',
        );
        final month = DateTime(2026, 5);

        final result = await repository.previewSyncMonth(month);
        final localState = await local.loadMonth(month);

        expect(result.status, AssetLiabilityManualSyncStatus.success);
        expect(result.localDataTargetCount, 0);
        expect(result.remoteDataTargetCount, 1);
        expect(result.uploadCandidateCount, 0);
        expect(result.downloadCandidateCount, 1);
        expect(result.conflictCount, 0);
        expect(localState.isEmpty, isTrue);
      },
    );

    test('sync preview reports conflicts without overwriting data', () async {
      final local = _FakeAssetLiabilityRepository();
      final remote = _RecordingAssetLiabilityRemoteStore()
        ..seedMonth(
          DateTime(2026, 5),
          const AssetLiabilityMonthlyState(
            paymentOverrides: <String, double>{'remote_only': 1000},
          ),
        );
      final repository = FeatureFlaggedAssetLiabilityRepository(
        localRepository: local,
        remoteStore: remote,
        syncEnabled: true,
        remoteWritesEnabled: true,
        userIdProvider: () => 'user-1',
      );
      final month = DateTime(2026, 5);
      await local.saveMonth(month: month, state: _sampleMonthlyState());

      final result = await repository.previewSyncMonth(month);
      final localState = await local.loadMonth(month);

      expect(result.status, AssetLiabilityManualSyncStatus.conflict);
      expect(result.hasConflict, isTrue);
      expect(result.conflictCount, 1);
      expect(
        result.conflictTargets,
        contains(AssetLiabilitySyncTarget.monthlyState.label),
      );
      expect(result.uploadCandidateCount, 0);
      expect(result.downloadCandidateCount, 0);
      expect(localState.paymentOverrides['mobit'], 70000);
      expect(
        remote.monthState('2026-05')?.paymentOverrides['remote_only'],
        1000,
      );
      expect(remote.calls, isNot(contains('saveMonth:user-1:2026-05')));
    });

    test('does not call remote store when Supabase sync flag is off', () async {
      final local = _FakeAssetLiabilityRepository();
      final remote = _RecordingAssetLiabilityRemoteStore();
      final repository = FeatureFlaggedAssetLiabilityRepository(
        localRepository: local,
        remoteStore: remote,
        syncEnabled: false,
        userIdProvider: () => 'user-1',
      );
      final month = DateTime(2026, 5);

      await repository.saveMonth(month: month, state: _sampleMonthlyState());
      final restored = await repository.loadMonth(month);

      expect(restored.paymentOverrides['mobit'], 70000);
      expect(remote.calls, isEmpty);
    });

    test(
      'loadMonth unions local and remote so cross-device paid is not lost',
      () async {
        final local = _FakeAssetLiabilityRepository();
        final remote = _RecordingAssetLiabilityRemoteStore();
        final repository = FeatureFlaggedAssetLiabilityRepository(
          localRepository: local,
          remoteStore: remote,
          syncEnabled: true,
          remoteWritesEnabled: true,
          userIdProvider: () => 'user-1',
        );
        final month = DateTime(2026, 5);

        // この端末(ローカル)はモビットだけ支払済み。
        await local.saveMonth(
          month: month,
          state: const AssetLiabilityMonthlyState(
            paidAccountNames: <String>{'mobit'},
          ),
        );
        // 別端末(リモート)は横浜銀行を支払済み(実支払額付き)。
        remote.seedMonth(
          month,
          const AssetLiabilityMonthlyState(
            paidAccountNames: <String>{'yokohama_bank'},
            actualPaymentAmounts: <String, double>{'yokohama_bank': 4846},
          ),
        );

        final merged = await repository.loadMonth(month);

        // 双方の支払済みが取りこぼされず union される (= 端末間で paid が消えない)。
        expect(
          merged.paidAccountNames,
          containsAll(<String>{'mobit', 'yokohama_bank'}),
        );
        expect(merged.actualPaymentAmounts['yokohama_bank'], 4846);
        // 収束のためローカル/リモート双方へマージ結果を保存する。
        final localAfter = await local.loadMonth(month);
        expect(localAfter.paidAccountNames, contains('yokohama_bank'));
        expect(
          remote.monthState('2026-05')?.paidAccountNames,
          contains('mobit'),
        );
        expect(remote.calls, contains('saveMonth:user-1:2026-05'));
      },
    );

    test(
      'loadMonth unions billing confirmations and transfer tasks across '
      'devices',
      () async {
        final local = _FakeAssetLiabilityRepository();
        final remote = _RecordingAssetLiabilityRemoteStore();
        final repository = FeatureFlaggedAssetLiabilityRepository(
          localRepository: local,
          remoteStore: remote,
          syncEnabled: true,
          remoteWritesEnabled: true,
          userIdProvider: () => 'user-1',
        );
        final month = DateTime(2026, 5);

        // この端末はモビットのカード請求を確認済み + 自端末の口座移動タスク。
        await local.saveMonth(
          month: month,
          state: AssetLiabilityMonthlyState(
            billingConfirmedAccountIds: const <String>{'mobit'},
            transferTasks: <AssetLiabilityTransferTask>[
              AssetLiabilityTransferTask(
                id: 'transfer_local',
                fromAccountId: 'custom_cash',
                fromAccountName: 'Cash',
                toAccountId: 'smbc_otsuka',
                toAccountName: 'SMBC Otsuka',
                amount: 10000,
                dueDate: DateTime(2026, 5, 18),
              ),
            ],
          ),
        );
        // 別端末はPayPayカードを確認済み + 別の口座移動タスク。
        remote.seedMonth(
          month,
          AssetLiabilityMonthlyState(
            billingConfirmedAccountIds: const <String>{'paypay_card'},
            transferTasks: <AssetLiabilityTransferTask>[
              AssetLiabilityTransferTask(
                id: 'transfer_remote',
                fromAccountId: 'smbc_otsuka',
                fromAccountName: 'SMBC Otsuka',
                toAccountId: 'rakuten_bank',
                toAccountName: 'Rakuten Bank',
                amount: 20000,
                dueDate: DateTime(2026, 5, 20),
              ),
            ],
          ),
        );

        final merged = await repository.loadMonth(month);

        // 双方の請求確認フラグ・口座移動タスクが取りこぼされず union される。
        expect(
          merged.billingConfirmedAccountIds,
          containsAll(<String>{'mobit', 'paypay_card'}),
        );
        expect(
          merged.transferTasks.map((task) => task.id),
          containsAll(<String>{'transfer_local', 'transfer_remote'}),
        );
        // 収束のためローカル/リモート双方へマージ結果を保存する。
        final localAfter = await local.loadMonth(month);
        expect(
          localAfter.billingConfirmedAccountIds,
          contains('paypay_card'),
        );
        expect(
          remote.monthState('2026-05')?.billingConfirmedAccountIds,
          contains('mobit'),
        );
        expect(remote.calls, contains('saveMonth:user-1:2026-05'));
      },
    );

    test('loadMonth keeps local value when scalar fields conflict', () async {
      final local = _FakeAssetLiabilityRepository();
      final remote = _RecordingAssetLiabilityRemoteStore();
      final repository = FeatureFlaggedAssetLiabilityRepository(
        localRepository: local,
        remoteStore: remote,
        syncEnabled: true,
        remoteWritesEnabled: true,
        userIdProvider: () => 'user-1',
      );
      final month = DateTime(2026, 5);
      await local.saveMonth(
        month: month,
        state: const AssetLiabilityMonthlyState(
          paymentOverrides: <String, double>{'mobit': 70000},
        ),
      );
      remote.seedMonth(
        month,
        const AssetLiabilityMonthlyState(
          paymentOverrides: <String, double>{'mobit': 60000},
        ),
      );

      final merged = await repository.loadMonth(month);

      // 同一キーの衝突は this(ローカル) を優先する。
      expect(merged.paymentOverrides['mobit'], 70000);
    });

    test(
      'loadMonth adopts the newer state so a cross-device uncheck propagates',
      () async {
        final local = _FakeAssetLiabilityRepository();
        final remote = _RecordingAssetLiabilityRemoteStore();
        final repository = FeatureFlaggedAssetLiabilityRepository(
          localRepository: local,
          remoteStore: remote,
          syncEnabled: true,
          remoteWritesEnabled: true,
          userIdProvider: () => 'user-1',
        );
        final month = DateTime(2026, 5);

        // この端末は古い時刻にモビットを支払済みにした。
        await local.saveMonth(
          month: month,
          state: AssetLiabilityMonthlyState(
            paidAccountNames: const <String>{'mobit'},
            updatedAt: DateTime(2026, 5, 20, 9),
          ),
        );
        // 別端末はより新しい時刻にチェックを外した (paid 空 / 状態は非空)。
        remote.seedMonth(
          month,
          AssetLiabilityMonthlyState(
            paymentOverrides: const <String, double>{'mobit': 1},
            updatedAt: DateTime(2026, 5, 20, 10),
          ),
        );

        final resolved = await repository.loadMonth(month);

        // 新しい方 (= チェック解除) が採用され、union のように mobit を復活させない。
        expect(resolved.paidAccountNames, isNot(contains('mobit')));
        final localAfter = await local.loadMonth(month);
        expect(localAfter.paidAccountNames, isNot(contains('mobit')));
      },
    );

    test('loadMonth keeps the newer local state over an older remote',
        () async {
      final local = _FakeAssetLiabilityRepository();
      final remote = _RecordingAssetLiabilityRemoteStore();
      final repository = FeatureFlaggedAssetLiabilityRepository(
        localRepository: local,
        remoteStore: remote,
        syncEnabled: true,
        remoteWritesEnabled: true,
        userIdProvider: () => 'user-1',
      );
      final month = DateTime(2026, 5);

      await local.saveMonth(
        month: month,
        state: AssetLiabilityMonthlyState(
          paidAccountNames: const <String>{'mobit'},
          updatedAt: DateTime(2026, 5, 20, 10),
        ),
      );
      remote.seedMonth(
        month,
        AssetLiabilityMonthlyState(
          paidAccountNames: const <String>{'yokohama_bank'},
          updatedAt: DateTime(2026, 5, 20, 9),
        ),
      );

      final resolved = await repository.loadMonth(month);

      // 新しいローカルが状態全体として勝ち、古いリモートの paid は採用しない。
      expect(resolved.paidAccountNames, contains('mobit'));
      expect(resolved.paidAccountNames, isNot(contains('yokohama_bank')));
    });

    test('loadMonth falls back to union when timestamps are absent', () async {
      final local = _FakeAssetLiabilityRepository();
      final remote = _RecordingAssetLiabilityRemoteStore();
      final repository = FeatureFlaggedAssetLiabilityRepository(
        localRepository: local,
        remoteStore: remote,
        syncEnabled: true,
        remoteWritesEnabled: true,
        userIdProvider: () => 'user-1',
      );
      final month = DateTime(2026, 5);

      // 旧データ (updatedAt 無し) 同士は union で取りこぼさない (#3474 の挙動)。
      await local.saveMonth(
        month: month,
        state: const AssetLiabilityMonthlyState(
          paidAccountNames: <String>{'mobit'},
        ),
      );
      remote.seedMonth(
        month,
        const AssetLiabilityMonthlyState(
          paidAccountNames: <String>{'yokohama_bank'},
        ),
      );

      final resolved = await repository.loadMonth(month);

      expect(
        resolved.paidAccountNames,
        containsAll(<String>{'mobit', 'yokohama_bank'}),
      );
    });

    test(
      'sync on keeps production writes disabled unless write flag is enabled',
      () async {
        final local = _FakeAssetLiabilityRepository();
        final remote = _RecordingAssetLiabilityRemoteStore();
        final repository = FeatureFlaggedAssetLiabilityRepository(
          localRepository: local,
          remoteStore: remote,
          syncEnabled: true,
          userIdProvider: () => 'user-1',
        );
        final month = DateTime(2026, 5);

        await repository.saveMonth(month: month, state: _sampleMonthlyState());
        await repository.saveDefaultPaymentSources(const <String, String>{
          'mobit': 'smbc_otsuka',
        });
        await repository.saveMonthlySnapshot(_sampleSnapshot('2026-05'));
        final restored = await repository.loadMonth(month);

        expect(repository.supabaseSyncEnabled, isTrue);
        expect(repository.supabaseWritesEnabled, isFalse);
        expect(restored.paymentOverrides['mobit'], 70000);
        expect(remote.monthState('2026-05'), isNull);
        expect(remote.defaultPaymentSources, isEmpty);
        expect(remote.monthlySnapshots, isEmpty);
        expect(remote.calls, contains('loadMonth:user-1:2026-05'));
        expect(remote.calls.where((call) => call.startsWith('save')), isEmpty);
      },
    );

    test(
      'sync preview can inspect Supabase while production writes are disabled',
      () async {
        final local = _FakeAssetLiabilityRepository();
        final remote = _RecordingAssetLiabilityRemoteStore()
          ..seedMonth(
            DateTime(2026, 5),
            const AssetLiabilityMonthlyState(
              paymentOverrides: <String, double>{'remote_only': 1000},
            ),
          );
        final repository = FeatureFlaggedAssetLiabilityRepository(
          localRepository: local,
          remoteStore: remote,
          syncEnabled: true,
          userIdProvider: () => 'user-1',
        );
        final month = DateTime(2026, 5);
        await local.saveMonth(month: month, state: _sampleMonthlyState());

        final result = await repository.previewSyncMonth(month);

        expect(result.status, AssetLiabilityManualSyncStatus.conflict);
        expect(result.conflictCount, 1);
        expect(remote.calls, contains('loadMonth:user-1:2026-05'));
        expect(remote.calls.where((call) => call.startsWith('save')), isEmpty);
        expect(
          remote.monthState('2026-05')?.paymentOverrides['remote_only'],
          1000,
        );
      },
    );

    test(
      'manual sync skips upload candidates when production writes are disabled',
      () async {
        const local = SharedPreferencesAssetLiabilityRepository();
        final remote = _RecordingAssetLiabilityRemoteStore();
        final repository = FeatureFlaggedAssetLiabilityRepository(
          localRepository: local,
          remoteStore: remote,
          syncEnabled: true,
          userIdProvider: () => 'user-1',
        );
        final month = DateTime(2026, 5);
        await local.saveMonth(month: month, state: _sampleMonthlyState());

        final result = await repository.syncMonth(month);
        final logs = await repository.loadSyncAuditLogs();

        expect(result.status, AssetLiabilityManualSyncStatus.success);
        expect(remote.monthState('2026-05'), isNull);
        expect(remote.calls.where((call) => call.startsWith('save')), isEmpty);
        expect(
          logs
              .where(
                (log) => log.type == AssetLiabilitySyncAuditType.manualSync,
              )
              .first
              .result,
          'success_remote_write_disabled',
        );
      },
    );

    test('local-wins conflict resolution requires production writes', () async {
      const local = SharedPreferencesAssetLiabilityRepository();
      final remote = _RecordingAssetLiabilityRemoteStore()
        ..seedMonth(
          DateTime(2026, 5),
          const AssetLiabilityMonthlyState(
            paymentOverrides: <String, double>{'remote_only': 1000},
          ),
        );
      final repository = FeatureFlaggedAssetLiabilityRepository(
        localRepository: local,
        remoteStore: remote,
        syncEnabled: true,
        userIdProvider: () => 'user-1',
      );
      final month = DateTime(2026, 5);
      await local.saveMonth(month: month, state: _sampleMonthlyState());

      final result = await repository.resolveSyncConflicts(
        month: month,
        resolutions: const <AssetLiabilityConflictResolution>[
          AssetLiabilityConflictResolution(
            target: AssetLiabilitySyncTarget.monthlyState,
            choice: AssetLiabilityConflictResolutionChoice.localWins,
          ),
        ],
      );
      final logs = await repository.loadSyncAuditLogs();

      expect(result.status, AssetLiabilityConflictResolutionStatus.failure);
      expect(
        remote.monthState('2026-05')?.paymentOverrides['remote_only'],
        1000,
      );
      expect(remote.calls.where((call) => call.startsWith('save')), isEmpty);
      expect(logs.single.result, 'production_writes_disabled');
    });

    test(
      'saves monthly data and settings through remote store when on',
      () async {
        final local = _FakeAssetLiabilityRepository();
        final remote = _RecordingAssetLiabilityRemoteStore();
        final repository = FeatureFlaggedAssetLiabilityRepository(
          localRepository: local,
          remoteStore: remote,
          syncEnabled: true,
          remoteWritesEnabled: true,
          userIdProvider: () => 'user-1',
        );
        final month = DateTime(2026, 5);
        final snapshot = _sampleSnapshot('2026-05');

        await repository.saveMonth(month: month, state: _sampleMonthlyState());
        await repository.saveDefaultPaymentSources(const <String, String>{
          'mobit': 'smbc_otsuka',
        });
        await repository.saveDefaultCardBillingAccounts(const <String, String>{
          'kddi_provider': 'paypay_card',
        });
        await repository.saveRecurringIncomeTemplates(
          <AssetLiabilityRecurringIncomeTemplate>[
            _sampleRecurringIncomeTemplate(),
          ],
        );
        await repository.saveMonthlySnapshot(snapshot);

        expect(remote.monthState('2026-05')?.paymentOverrides['mobit'], 70000);
        expect(remote.defaultPaymentSources['mobit'], 'smbc_otsuka');
        expect(
          remote.defaultCardBillingAccounts['kddi_provider'],
          'paypay_card',
        );
        expect(remote.recurringIncomeTemplates.single.id, 'salary');
        expect(remote.monthlySnapshots.single.monthKey, '2026-05');
      },
    );

    test('keeps local save when remote save fails', () async {
      final errors = <Object>[];
      final local = _FakeAssetLiabilityRepository();
      final remote = _RecordingAssetLiabilityRemoteStore()..failSaves = true;
      final repository = FeatureFlaggedAssetLiabilityRepository(
        localRepository: local,
        remoteStore: remote,
        syncEnabled: true,
        remoteWritesEnabled: true,
        userIdProvider: () => 'user-1',
        onSyncError: (error, _) => errors.add(error),
      );
      final month = DateTime(2026, 5);

      await repository.saveMonth(month: month, state: _sampleMonthlyState());

      final localState = await local.loadMonth(month);
      expect(localState.paymentOverrides['mobit'], 70000);
      expect(errors, isNotEmpty);
      expect(remote.calls, contains('saveMonth:user-1:2026-05'));
    });

    test('manual sync uploads local data and reports success', () async {
      final local = _FakeAssetLiabilityRepository();
      final remote = _RecordingAssetLiabilityRemoteStore();
      final repository = FeatureFlaggedAssetLiabilityRepository(
        localRepository: local,
        remoteStore: remote,
        syncEnabled: true,
        remoteWritesEnabled: true,
        userIdProvider: () => 'user-1',
      );
      final month = DateTime(2026, 5);
      await local.saveMonth(month: month, state: _sampleMonthlyState());
      await local.saveDefaultPaymentSources(const <String, String>{
        'mobit': 'smbc_otsuka',
      });
      await local.saveDefaultCardBillingAccounts(const <String, String>{
        'kddi_provider': 'paypay_card',
      });
      await local.saveRecurringIncomeTemplates(
        <AssetLiabilityRecurringIncomeTemplate>[
          _sampleRecurringIncomeTemplate(),
        ],
      );
      await local.saveMonthlySnapshot(_sampleSnapshot('2026-05'));

      final result = await repository.syncMonth(month);

      expect(result.status, AssetLiabilityManualSyncStatus.success);
      expect(result.isSuccess, isTrue);
      expect(remote.monthState('2026-05')?.paymentOverrides['mobit'], 70000);
      expect(remote.defaultPaymentSources['mobit'], 'smbc_otsuka');
      expect(remote.defaultCardBillingAccounts['kddi_provider'], 'paypay_card');
      expect(remote.recurringIncomeTemplates.single.id, 'salary');
      expect(remote.monthlySnapshots.single.monthKey, '2026-05');
    });

    test('manual sync success records success audit log', () async {
      const local = SharedPreferencesAssetLiabilityRepository();
      final remote = _RecordingAssetLiabilityRemoteStore();
      final repository = FeatureFlaggedAssetLiabilityRepository(
        localRepository: local,
        remoteStore: remote,
        syncEnabled: true,
        remoteWritesEnabled: true,
        userIdProvider: () => 'user-1',
      );
      final month = DateTime(2026, 5);
      await local.saveMonth(month: month, state: _sampleMonthlyState());

      final result = await repository.syncMonth(month);
      final logs = await repository.loadSyncAuditLogs();

      expect(result.status, AssetLiabilityManualSyncStatus.success);
      expect(
        logs.map((log) => log.type),
        contains(AssetLiabilitySyncAuditType.success),
      );
    });

    test('manual sync failure keeps local data intact', () async {
      final local = _FakeAssetLiabilityRepository();
      final remote = _RecordingAssetLiabilityRemoteStore()..failSaves = true;
      final repository = FeatureFlaggedAssetLiabilityRepository(
        localRepository: local,
        remoteStore: remote,
        syncEnabled: true,
        remoteWritesEnabled: true,
        userIdProvider: () => 'user-1',
      );
      final month = DateTime(2026, 5);
      await local.saveMonth(month: month, state: _sampleMonthlyState());

      final result = await repository.syncMonth(month);
      final restored = await local.loadMonth(month);

      expect(result.status, AssetLiabilityManualSyncStatus.failure);
      expect(restored.paymentOverrides['mobit'], 70000);
      expect(remote.calls, contains('saveMonth:user-1:2026-05'));
    });

    test('manual sync failure records failed audit log', () async {
      const local = SharedPreferencesAssetLiabilityRepository();
      final remote = _RecordingAssetLiabilityRemoteStore()..failSaves = true;
      final repository = FeatureFlaggedAssetLiabilityRepository(
        localRepository: local,
        remoteStore: remote,
        syncEnabled: true,
        remoteWritesEnabled: true,
        userIdProvider: () => 'user-1',
      );
      final month = DateTime(2026, 5);
      await local.saveMonth(month: month, state: _sampleMonthlyState());

      final result = await repository.syncMonth(month);
      final logs = await repository.loadSyncAuditLogs();

      expect(result.status, AssetLiabilityManualSyncStatus.failure);
      expect(
        logs.map((log) => log.type),
        contains(AssetLiabilitySyncAuditType.failed),
      );
      expect((await local.loadMonth(month)).paymentOverrides['mobit'], 70000);
    });

    test(
      'manual sync detects conflict without overwriting either side',
      () async {
        final local = _FakeAssetLiabilityRepository();
        final remote = _RecordingAssetLiabilityRemoteStore()
          ..seedMonth(
            DateTime(2026, 5),
            const AssetLiabilityMonthlyState(
              paymentOverrides: <String, double>{'remote_only': 1000},
            ),
          );
        final repository = FeatureFlaggedAssetLiabilityRepository(
          localRepository: local,
          remoteStore: remote,
          syncEnabled: true,
          remoteWritesEnabled: true,
          userIdProvider: () => 'user-1',
        );
        final month = DateTime(2026, 5);
        await local.saveMonth(month: month, state: _sampleMonthlyState());

        final result = await repository.syncMonth(month);
        final localState = await local.loadMonth(month);

        expect(result.status, AssetLiabilityManualSyncStatus.conflict);
        expect(result.hasConflict, isTrue);
        expect(
          result.conflictTargets,
          contains(AssetLiabilitySyncTarget.monthlyState.label),
        );
        expect(localState.paymentOverrides['mobit'], 70000);
        expect(
          remote.monthState('2026-05')?.paymentOverrides['remote_only'],
          1000,
        );
        expect(remote.calls, isNot(contains('saveMonth:user-1:2026-05')));
      },
    );

    test('manual sync conflict records conflict audit log', () async {
      const local = SharedPreferencesAssetLiabilityRepository();
      final remote = _RecordingAssetLiabilityRemoteStore()
        ..seedMonth(
          DateTime(2026, 5),
          const AssetLiabilityMonthlyState(
            paymentOverrides: <String, double>{'remote_only': 1000},
          ),
        );
      final repository = FeatureFlaggedAssetLiabilityRepository(
        localRepository: local,
        remoteStore: remote,
        syncEnabled: true,
        remoteWritesEnabled: true,
        userIdProvider: () => 'user-1',
      );
      final month = DateTime(2026, 5);
      await local.saveMonth(month: month, state: _sampleMonthlyState());

      final result = await repository.syncMonth(month);
      final logs = await repository.loadSyncAuditLogs();

      expect(result.status, AssetLiabilityManualSyncStatus.conflict);
      expect(
        logs.map((log) => log.type),
        contains(AssetLiabilitySyncAuditType.conflictDetected),
      );
      expect(
        logs
            .firstWhere(
              (log) => log.type == AssetLiabilitySyncAuditType.conflictDetected,
            )
            .result,
        'conflict_non_destructive_stop',
      );
    });

    test(
      'resolves a monthly state conflict with explicit local wins',
      () async {
        const local = SharedPreferencesAssetLiabilityRepository();
        final remote = _RecordingAssetLiabilityRemoteStore()
          ..seedMonth(
            DateTime(2026, 5),
            const AssetLiabilityMonthlyState(
              paymentOverrides: <String, double>{'remote_only': 1000},
            ),
          );
        final repository = FeatureFlaggedAssetLiabilityRepository(
          localRepository: local,
          remoteStore: remote,
          syncEnabled: true,
          remoteWritesEnabled: true,
          userIdProvider: () => 'user-1',
        );
        final month = DateTime(2026, 5);
        await local.saveMonth(month: month, state: _sampleMonthlyState());

        final before = await repository.previewSyncMonth(month);
        final result = await repository.resolveSyncConflicts(
          month: month,
          resolutions: const <AssetLiabilityConflictResolution>[
            AssetLiabilityConflictResolution(
              target: AssetLiabilitySyncTarget.monthlyState,
              choice: AssetLiabilityConflictResolutionChoice.localWins,
            ),
          ],
        );
        final after = await repository.previewSyncMonth(month);
        final logs = await repository.loadSyncAuditLogs();

        expect(before.conflictCount, 1);
        expect(result.isSuccess, isTrue);
        expect(
          result.resolvedTargets,
          contains(AssetLiabilitySyncTarget.monthlyState),
        );
        expect(remote.monthState('2026-05')?.paymentOverrides['mobit'], 70000);
        expect((await local.loadMonth(month)).paymentOverrides['mobit'], 70000);
        expect(after.conflictCount, 0);
        expect(
          logs.map((log) => log.type),
          contains(AssetLiabilitySyncAuditType.conflictResolved),
        );
      },
    );

    test(
      'resolves a monthly state conflict with explicit Supabase wins',
      () async {
        const local = SharedPreferencesAssetLiabilityRepository();
        final remote = _RecordingAssetLiabilityRemoteStore()
          ..seedMonth(
            DateTime(2026, 5),
            const AssetLiabilityMonthlyState(
              paymentOverrides: <String, double>{'remote_only': 1000},
            ),
          );
        final repository = FeatureFlaggedAssetLiabilityRepository(
          localRepository: local,
          remoteStore: remote,
          syncEnabled: true,
          remoteWritesEnabled: true,
          userIdProvider: () => 'user-1',
        );
        final month = DateTime(2026, 5);
        await local.saveMonth(month: month, state: _sampleMonthlyState());

        final result = await repository.resolveSyncConflicts(
          month: month,
          resolutions: const <AssetLiabilityConflictResolution>[
            AssetLiabilityConflictResolution(
              target: AssetLiabilitySyncTarget.monthlyState,
              choice: AssetLiabilityConflictResolutionChoice.supabaseWins,
            ),
          ],
        );
        final restored = await local.loadMonth(month);
        final after = await repository.previewSyncMonth(month);

        expect(result.isSuccess, isTrue);
        expect(restored.paymentOverrides['remote_only'], 1000);
        expect(restored.paymentOverrides.containsKey('mobit'), isFalse);
        expect(
          remote.monthState('2026-05')?.paymentOverrides['remote_only'],
          1000,
        );
        expect(after.conflictCount, 0);
      },
    );

    test(
      'skips a conflict without overwriting either side and records the choice',
      () async {
        const local = SharedPreferencesAssetLiabilityRepository();
        final remote = _RecordingAssetLiabilityRemoteStore()
          ..seedMonth(
            DateTime(2026, 5),
            const AssetLiabilityMonthlyState(
              paymentOverrides: <String, double>{'remote_only': 1000},
            ),
          );
        final repository = FeatureFlaggedAssetLiabilityRepository(
          localRepository: local,
          remoteStore: remote,
          syncEnabled: true,
          remoteWritesEnabled: true,
          userIdProvider: () => 'user-1',
        );
        final month = DateTime(2026, 5);
        await local.saveMonth(month: month, state: _sampleMonthlyState());

        final result = await repository.resolveSyncConflicts(
          month: month,
          resolutions: const <AssetLiabilityConflictResolution>[
            AssetLiabilityConflictResolution(
              target: AssetLiabilitySyncTarget.monthlyState,
              choice: AssetLiabilityConflictResolutionChoice.skip,
            ),
          ],
        );
        final after = await repository.previewSyncMonth(month);
        final logs = await repository.loadSyncAuditLogs();

        expect(result.isSuccess, isTrue);
        expect(result.resolvedTargets, isEmpty);
        expect(
          result.skippedTargets,
          contains(AssetLiabilitySyncTarget.monthlyState),
        );
        expect((await local.loadMonth(month)).paymentOverrides['mobit'], 70000);
        expect(
          remote.monthState('2026-05')?.paymentOverrides['remote_only'],
          1000,
        );
        expect(after.conflictCount, 1);
        expect(
          logs
              .firstWhere(
                (log) =>
                    log.type == AssetLiabilitySyncAuditType.conflictResolved,
              )
              .result,
          'skipped',
        );
      },
    );

    test(
      'feature flag off does not call Supabase or create audit logs',
      () async {
        const local = SharedPreferencesAssetLiabilityRepository();
        final remote = _RecordingAssetLiabilityRemoteStore();
        final repository = FeatureFlaggedAssetLiabilityRepository(
          localRepository: local,
          remoteStore: remote,
          syncEnabled: false,
          userIdProvider: () => 'user-1',
        );
        final month = DateTime(2026, 5);
        await local.saveMonth(month: month, state: _sampleMonthlyState());

        final result = await repository.previewSyncMonth(month);
        final syncResult = await repository.syncMonth(month);
        final logs = await repository.loadSyncAuditLogs();

        expect(result.status, AssetLiabilityManualSyncStatus.disabled);
        expect(syncResult.status, AssetLiabilityManualSyncStatus.disabled);
        expect(remote.calls, isEmpty);
        expect(logs, isEmpty);
      },
    );

    test('uploads local monthly state when remote is empty', () async {
      final local = _FakeAssetLiabilityRepository();
      final remote = _RecordingAssetLiabilityRemoteStore();
      final repository = FeatureFlaggedAssetLiabilityRepository(
        localRepository: local,
        remoteStore: remote,
        syncEnabled: true,
        remoteWritesEnabled: true,
        userIdProvider: () => 'user-1',
      );
      final month = DateTime(2026, 5);
      await local.saveMonth(month: month, state: _sampleMonthlyState());

      final restored = await repository.loadMonth(month);

      expect(restored.paymentOverrides['mobit'], 70000);
      expect(remote.monthState('2026-05')?.paymentOverrides['mobit'], 70000);
    });

    test('restores remote monthly state when local is empty', () async {
      final local = _FakeAssetLiabilityRepository();
      final remote = _RecordingAssetLiabilityRemoteStore()
        ..seedMonth(DateTime(2026, 5), _sampleMonthlyState());
      final repository = FeatureFlaggedAssetLiabilityRepository(
        localRepository: local,
        remoteStore: remote,
        syncEnabled: true,
        remoteWritesEnabled: true,
        userIdProvider: () => 'user-1',
      );
      final month = DateTime(2026, 5);

      final restored = await repository.loadMonth(month);
      final localState = await local.loadMonth(month);

      expect(restored.paymentOverrides['mobit'], 70000);
      expect(localState.paymentOverrides['mobit'], 70000);
    });

    test(
      'restores remote settings and snapshots when local is empty',
      () async {
        final local = _FakeAssetLiabilityRepository();
        final remote = _RecordingAssetLiabilityRemoteStore()
          ..seedDefaultPaymentSources(const <String, String>{
            'mobit': 'smbc_otsuka',
          })
          ..seedRecurringIncomeTemplates(
            <AssetLiabilityRecurringIncomeTemplate>[
              _sampleRecurringIncomeTemplate(),
            ],
          )
          ..seedMonthlySnapshots(<AssetLiabilityMonthlySnapshot>[
            _sampleSnapshot('2026-05'),
          ]);
        final repository = FeatureFlaggedAssetLiabilityRepository(
          localRepository: local,
          remoteStore: remote,
          syncEnabled: true,
          remoteWritesEnabled: true,
          userIdProvider: () => 'user-1',
        );

        final sources = await repository.loadDefaultPaymentSources();
        final templates = await repository.loadRecurringIncomeTemplates();
        final snapshots = await repository.loadMonthlySnapshots();

        expect(sources['mobit'], 'smbc_otsuka');
        expect(templates.single.id, 'salary');
        expect(snapshots.single.monthKey, '2026-05');
        expect(
          (await local.loadDefaultPaymentSources())['mobit'],
          'smbc_otsuka',
        );
        expect(
          (await local.loadRecurringIncomeTemplates()).single.id,
          'salary',
        );
        expect((await local.loadMonthlySnapshots()).single.monthKey, '2026-05');
      },
    );

    test('restores missing months into a partially populated device', () async {
      final local = _FakeAssetLiabilityRepository();
      await local.saveMonthlySnapshot(_sampleSnapshot('2026-09'));
      final remote = _RecordingAssetLiabilityRemoteStore()
        ..seedMonthlySnapshots([
          _sampleSnapshot('2026-06'),
          _sampleSnapshot('2026-07'),
          _sampleSnapshot('2026-08'),
        ]);
      final repository = FeatureFlaggedAssetLiabilityRepository(
        localRepository: local,
        remoteStore: remote,
        syncEnabled: true,
        remoteWritesEnabled: true,
        userIdProvider: () => 'user-1',
      );

      expect(
        (await repository.loadMonthlySnapshots()).map((s) => s.monthKey),
        ['2026-09', '2026-08', '2026-07', '2026-06'],
      );
      expect(await local.loadMonthlySnapshots(), hasLength(4));
      expect(await repository.loadMonthlySnapshots(), hasLength(4));
      expect(
        remote.calls.where((c) => c.startsWith('saveMonthlySnapshot')),
        isEmpty,
      );
    });

    test('does not upload snapshots when the server read is unavailable',
        () async {
      final local = _FakeAssetLiabilityRepository();
      await local.saveMonthlySnapshot(_sampleSnapshot('2026-09'));
      final remote = _RecordingAssetLiabilityRemoteStore();
      final repository = FeatureFlaggedAssetLiabilityRepository(
        localRepository: local,
        remoteStore: remote,
        syncEnabled: true,
        remoteWritesEnabled: true,
        userIdProvider: () => 'user-1',
      );

      expect(await repository.loadMonthlySnapshots(), hasLength(1));
      expect(
        remote.calls.where((c) => c.startsWith('saveMonthlySnapshot')),
        isEmpty,
      );
    });

    test('snapshot conflicts retain the newer version per month', () async {
      final older = _sampleSnapshot('2026-08');
      final newer = _sampleSnapshot(
        '2026-08',
        savedAt: DateTime.utc(2026, 9, 1),
      );
      for (final remoteIsNewer in [true, false]) {
        final local = _FakeAssetLiabilityRepository();
        await local.saveMonthlySnapshot(remoteIsNewer ? older : newer);
        final remote = _RecordingAssetLiabilityRemoteStore()
          ..seedMonthlySnapshots([remoteIsNewer ? newer : older]);
        final repository = FeatureFlaggedAssetLiabilityRepository(
          localRepository: local,
          remoteStore: remote,
          syncEnabled: true,
          remoteWritesEnabled: true,
          userIdProvider: () => 'user-1',
        );

        expect((await repository.loadMonthlySnapshots()).single, newer);
        expect((await local.loadMonthlySnapshots()).single, newer);
        expect(
          remote.calls.where((c) => c.startsWith('saveMonthlySnapshot')),
          isEmpty,
        );
      }
    });

    test('loads generated monthly reports from remote store', () async {
      final local = _FakeAssetLiabilityRepository();
      final remote = _RecordingAssetLiabilityRemoteStore()
        ..seedMonthlyReports(<AssetLiabilityMonthlyReport>[
          AssetLiabilityMonthlyReport(
            monthKey: '2026-06',
            generatedAt: DateTime.utc(2026, 7, 1),
            totalAssets: 160000,
            totalLiabilities: -6800000,
            netWorth: -6640000,
            aiSummary: 'June summary',
            aiModel: 'deterministic-fallback',
          ),
          AssetLiabilityMonthlyReport(
            monthKey: '2026-05',
            generatedAt: DateTime.utc(2026, 6, 1),
            totalAssets: 120000,
            totalLiabilities: -7000000,
            netWorth: -6880000,
            aiSummary: 'May summary',
            aiModel: 'claude-opus-4-7',
          ),
        ]);
      final repository = FeatureFlaggedAssetLiabilityRepository(
        localRepository: local,
        remoteStore: remote,
        syncEnabled: true,
        userIdProvider: () => 'user-1',
      );

      final reports = await repository.loadMonthlyReports(limit: 1);

      expect(reports, hasLength(1));
      expect(reports.single.monthKey, '2026-06');
      expect(reports.single.aiSummary, 'June summary');
      expect(remote.calls, contains('loadMonthlyReports:user-1:1'));
    });

    test(
      'keeps local repository usable when no Supabase user is available',
      () async {
        final local = _FakeAssetLiabilityRepository();
        final remote = _RecordingAssetLiabilityRemoteStore();
        final repository = FeatureFlaggedAssetLiabilityRepository(
          localRepository: local,
          remoteStore: remote,
          syncEnabled: true,
          remoteWritesEnabled: true,
          userIdProvider: () => null,
        );
        final month = DateTime(2026, 5);

        await repository.saveMonth(month: month, state: _sampleMonthlyState());
        final restored = await repository.loadMonth(month);

        expect(restored.paymentOverrides['mobit'], 70000);
        expect(remote.calls, isEmpty);
      },
    );
  });

  group('Asset liability Supabase payloads', () {
    test('round-trips monthly state payload', () {
      final state = AssetLiabilityMonthlyState(
        paymentOverrides: const <String, double>{'mobit': 70000},
        actualPaymentAmounts: const <String, double>{'mobit': 71000},
        paymentDifferenceReasons: const <String, String>{
          'mobit': 'fee adjustment',
        },
        annualRateOverrides: const <String, double>{'mobit': 0.175},
        annualRateEvidences: <String, AssetLiabilityAnnualRateEvidence>{
          'mobit': AssetLiabilityAnnualRateEvidence(
            accountId: 'mobit',
            fileName: 'mobit_apr.png',
            mimeType: 'image/png',
            submittedAt: DateTime(2026, 5, 14, 9),
            submittedAnnualRate: 0.175,
            detectedAnnualRate: 0.175,
            status: AssetLiabilityAnnualRateEvidenceStatus.verified,
            summary: '17.5% APR visible',
            source: 'ai-hub',
          ),
        },
        paidAccountNames: const <String>{'kddi_provider'},
        billingConfirmedAccountIds: const <String>{'mobit'},
        paymentSourceAccountIds: const <String, String>{'mobit': 'smbc_otsuka'},
        cardBillingAccountIds: const <String, String>{
          'kddi_provider': 'paypay_card',
        },
        cardStatementLines: <AssetLiabilityCardStatementLine>[
          AssetLiabilityCardStatementLine(
            id: 'line_1',
            billingAccountId: 'paypay_card',
            billingAccountName: 'PayPay card',
            postedAt: DateTime(2026, 5, 12),
            description: 'KDDI',
            amount: 5764,
          ),
        ],
        incomePlans: <AssetLiabilityIncomePlan>[
          AssetLiabilityIncomePlan(
            id: 'salary',
            date: DateTime(2026, 5, 25),
            name: 'Salary',
            amount: 250000,
            destinationAccountId: 'smbc_otsuka',
            destinationAccountName: 'SMBC Otsuka',
            received: true,
          ),
        ],
        transferTasks: <AssetLiabilityTransferTask>[
          AssetLiabilityTransferTask(
            id: 'transfer_bank_topup',
            fromAccountId: 'custom_cash',
            fromAccountName: 'Cash',
            toAccountId: 'smbc_otsuka',
            toAccountName: 'SMBC Otsuka',
            amount: 10000,
            dueDate: DateTime(2026, 5, 18),
            canceled: true,
            canceledAt: DateTime.utc(2026, 5, 17, 22),
            cancellationReason: 'Paid from salary account directly.',
          ),
        ],
        updatedAt: DateTime.utc(2026, 5, 19, 8),
      );

      final payload = AssetLiabilityMonthlyStatePayload.fromState(
        monthKey: '2026-05',
        state: state,
      );
      final row = payload.toSupabaseJson(
        userId: 'user-1',
        updatedAt: DateTime.utc(2026, 5, 14),
      );
      final restored = AssetLiabilityMonthlyStatePayload.fromSupabaseJson(
        row,
      ).toState();

      expect(row['user_id'], 'user-1');
      expect(row['month_key'], '2026-05');
      expect(restored.paymentOverrides['mobit'], 70000);
      expect(restored.actualPaymentAmounts['mobit'], 71000);
      expect(restored.paymentDifferenceReasons['mobit'], 'fee adjustment');
      expect(restored.annualRateOverrides['mobit'], 0.175);
      expect(restored.annualRateEvidences['mobit']?.verified, isTrue);
      expect(row['annual_rate_evidences'], isA<Map<String, Object?>>());
      expect(restored.paidAccountNames, contains('kddi_provider'));
      // クライアント編集時刻 (LWW 用) が payload 経由で round-trip する。
      expect(row['state_updated_at'], '2026-05-19T08:00:00.000Z');
      expect(restored.updatedAt?.toUtc(), DateTime.utc(2026, 5, 19, 8));
      expect(restored.billingConfirmedAccountIds, contains('mobit'));
      expect(restored.paymentSourceAccountIds['mobit'], 'smbc_otsuka');
      expect(restored.cardBillingAccountIds['kddi_provider'], 'paypay_card');
      expect(restored.cardStatementLines.single.description, 'KDDI');
      expect(restored.cardStatementLines.single.amount, 5764);
      expect(restored.incomePlans.single.received, isTrue);
      expect(row['transfer_tasks'], isA<List<Object?>>());
      expect(restored.transferTasks.single.toAccountId, 'smbc_otsuka');
      expect(restored.transferTasks.single.amount, 10000);
      expect(restored.transferTasks.single.canceled, isTrue);
      expect(
        restored.transferTasks.single.canceledAt,
        DateTime.utc(2026, 5, 17, 22),
      );
      expect(
        restored.transferTasks.single.cancellationReason,
        'Paid from salary account directly.',
      );
    });

    test(
        'monthly_states remote payload carries billing confirmations and '
        'transfer tasks', () {
      // 回帰: 以前 saveMonth の subset マップが billing_confirmed_account_ids と
      // transfer_tasks を取りこぼし、リモートへ一切書かれず端末間で同期されなかった
      // (= paid_account_ids と同型の潜在バグ)。
      final state = AssetLiabilityMonthlyState(
        paidAccountNames: const <String>{'kddi_provider'},
        billingConfirmedAccountIds: const <String>{'mobit', 'paypay_card'},
        transferTasks: <AssetLiabilityTransferTask>[
          AssetLiabilityTransferTask(
            id: 'transfer_bank_topup',
            fromAccountId: 'custom_cash',
            fromAccountName: 'Cash',
            toAccountId: 'smbc_otsuka',
            toAccountName: 'SMBC Otsuka',
            amount: 10000,
            dueDate: DateTime(2026, 5, 18),
          ),
        ],
        incomePlans: <AssetLiabilityIncomePlan>[
          AssetLiabilityIncomePlan(
            id: 'salary',
            date: DateTime(2026, 5, 25),
            name: 'Salary',
            amount: 250000,
            destinationAccountId: 'smbc_otsuka',
            destinationAccountName: 'SMBC Otsuka',
            received: false,
          ),
        ],
        updatedAt: DateTime.utc(2026, 5, 19, 8),
      );
      final row = AssetLiabilityMonthlyStatePayload.fromState(
        monthKey: '2026-05',
        state: state,
      ).toSupabaseJson(userId: 'user-1');

      final payload =
          AssetLiabilitySupabaseRemoteStore.buildMonthlyStatesPayload(
        row,
      );

      // 取りこぼしていた 2 キーが monthly_states payload に含まれること。
      expect(payload.containsKey('billing_confirmed_account_ids'), isTrue);
      expect(payload.containsKey('transfer_tasks'), isTrue);
      expect(
        payload['billing_confirmed_account_ids'],
        containsAll(<String>['mobit', 'paypay_card']),
      );
      expect((payload['transfer_tasks']! as List<Object?>).length, 1);
      // LWW 用のクライアント編集時刻も同梱される。
      expect(payload['state_updated_at'], '2026-05-19T08:00:00.000Z');
      // income_plans は別テーブルへ保存するため monthly_states には含めない。
      expect(payload.containsKey('income_plans'), isFalse);
      // 識別子カラムは _upsertPayloadRow が個別に付与するため payload には含めない。
      expect(payload.containsKey('user_id'), isFalse);
      expect(payload.containsKey('month_key'), isFalse);
      // キー集合を厳密に固定する。toSupabaseJson に状態フィールドが増えたら
      // ここが落ちて「リモートへ同期すべきか」を必ず判断させる (= 書き忘れ防止)。
      expect(
        payload.keys.toSet(),
        <String>{
          'payment_overrides',
          'actual_payment_amounts',
          'payment_difference_reasons',
          'annual_rate_overrides',
          'annual_rate_evidences',
          'paid_account_ids',
          'billing_confirmed_account_ids',
          'payment_source_account_ids',
          'card_billing_account_ids',
          'card_statement_lines',
          'transfer_tasks',
          'state_updated_at',
        },
      );
    });

    test(
        'save split and load merge round-trip preserves billing confirmations '
        'and transfer tasks across the two tables', () {
      final state = AssetLiabilityMonthlyState(
        billingConfirmedAccountIds: const <String>{'mobit'},
        transferTasks: <AssetLiabilityTransferTask>[
          AssetLiabilityTransferTask(
            id: 'transfer_bank_topup',
            fromAccountId: 'custom_cash',
            fromAccountName: 'Cash',
            toAccountId: 'smbc_otsuka',
            toAccountName: 'SMBC Otsuka',
            amount: 10000,
            dueDate: DateTime(2026, 5, 18),
          ),
        ],
        incomePlans: <AssetLiabilityIncomePlan>[
          AssetLiabilityIncomePlan(
            id: 'salary',
            date: DateTime(2026, 5, 25),
            name: 'Salary',
            amount: 250000,
            destinationAccountId: 'smbc_otsuka',
            destinationAccountName: 'SMBC Otsuka',
            received: false,
          ),
        ],
      );
      final row = AssetLiabilityMonthlyStatePayload.fromState(
        monthKey: '2026-05',
        state: state,
      ).toSupabaseJson(userId: 'user-1');

      // saveMonth が 2 テーブルへ分割書き込みする 2 つの payload 行を再現する。
      final monthlyRow =
          AssetLiabilitySupabaseRemoteStore.buildMonthlyStatesPayload(row);
      final incomeRow = <String, Object?>{'income_plans': row['income_plans']};

      // loadMonth はこの 2 行の payload を合体して fromSupabaseJson に渡す。
      final mergedPayload = <String, Object?>{
        ...monthlyRow,
        ...incomeRow,
        'month_key': '2026-05',
      };
      final restored = AssetLiabilityMonthlyStatePayload.fromSupabaseJson(
        mergedPayload,
      ).toState();

      expect(restored.billingConfirmedAccountIds, contains('mobit'));
      expect(restored.transferTasks.single.id, 'transfer_bank_topup');
      expect(restored.transferTasks.single.amount, 10000);
      expect(restored.incomePlans.single.id, 'salary');
    });

    test('round-trips settings and snapshot payloads', () {
      const settings = AssetLiabilityUserSettingsPayload(
        defaultPaymentSourceAccountIds: <String, String>{
          'mobit': 'smbc_otsuka',
        },
        defaultCardBillingAccountIds: <String, String>{
          'kddi_provider': 'paypay_card',
        },
        recurringIncomeTemplates: <AssetLiabilityRecurringIncomeTemplate>[
          AssetLiabilityRecurringIncomeTemplate(
            id: 'salary',
            dayOfMonth: 25,
            name: 'Salary',
            amount: 250000,
            destinationAccountId: 'smbc_otsuka',
            destinationAccountName: 'SMBC Otsuka',
          ),
        ],
      );
      final settingsRow = settings.toSupabaseJson(userId: 'user-1');
      final restoredSettings =
          AssetLiabilityUserSettingsPayload.fromSupabaseJson(settingsRow);

      expect(
        restoredSettings.defaultPaymentSourceAccountIds['mobit'],
        'smbc_otsuka',
      );
      expect(
        restoredSettings.defaultCardBillingAccountIds['kddi_provider'],
        'paypay_card',
      );
      expect(restoredSettings.recurringIncomeTemplates.single.id, 'salary');

      final snapshot = AssetLiabilityMonthlySnapshot(
        monthKey: '2026-05',
        savedAt: DateTime.utc(2026, 5, 31, 12),
        positiveAssetTotal: 120000,
        liabilityTotal: -7200000,
        netWorth: -7080000,
        cashLikeTotal: 60000,
        monthlyScheduledPaymentTotal: 180000,
        monthlyPaidPaymentTotal: 100000,
        monthlyUnpaidPaymentTotal: 80000,
        monthlyActualPaymentTotal: 102000,
        monthlyPaymentDifferenceTotal: 2000,
        overduePaymentCount: 1,
      );
      final snapshotRow = AssetLiabilityMonthlySnapshotPayload(
        snapshot: snapshot,
      ).toSupabaseJson(userId: 'user-1');
      final restoredSnapshot =
          AssetLiabilityMonthlySnapshotPayload.fromSupabaseJson(
        snapshotRow,
      ).snapshot;

      expect(snapshotRow['user_id'], 'user-1');
      expect(restoredSnapshot.monthKey, '2026-05');
      expect(restoredSnapshot.netWorth, -7080000);
      expect(restoredSnapshot.monthlyActualPaymentTotal, 102000);
      expect(restoredSnapshot.monthlyPaymentDifferenceTotal, 2000);
      expect(restoredSnapshot.overduePaymentCount, 1);
    });

    test('documents Supabase table names and required identity columns', () {
      expect(
        AssetLiabilitySupabaseTablePlan.monthlyStatesTable,
        'asset_liability_monthly_states',
      );
      expect(
        AssetLiabilitySupabaseTablePlan.incomePlansTable,
        'asset_liability_income_plans',
      );
      expect(
        AssetLiabilitySupabaseTablePlan.paymentSourceSettingsTable,
        'asset_liability_payment_source_settings',
      );
      expect(
        AssetLiabilitySupabaseTablePlan.commonPayloadColumns,
        containsAll(<String>['id', 'user_id', 'month_key', 'payload']),
      );
    });
  });
}

class _FakeAssetLiabilityRepository extends AssetLiabilityRepository {
  final Map<String, AssetLiabilityMonthlyState> _states =
      <String, AssetLiabilityMonthlyState>{};
  final Map<String, String> _defaultSources = <String, String>{};
  final Map<String, String> _defaultCardBilling = <String, String>{};
  final List<AssetLiabilityRecurringIncomeTemplate> _templates =
      <AssetLiabilityRecurringIncomeTemplate>[];
  final List<AssetLiabilityMonthlySnapshot> _snapshots =
      <AssetLiabilityMonthlySnapshot>[];

  @override
  Future<AssetLiabilityMonthlyState> loadMonth(DateTime month) async {
    return _states[AssetLiabilityMonthlyStateStore.formatMonthKey(month)] ??
        const AssetLiabilityMonthlyState();
  }

  @override
  Future<void> saveMonth({
    required DateTime month,
    required AssetLiabilityMonthlyState state,
  }) async {
    _states[AssetLiabilityMonthlyStateStore.formatMonthKey(month)] = state;
  }

  @override
  Future<Map<String, String>> loadDefaultPaymentSources() async {
    return Map<String, String>.from(_defaultSources);
  }

  @override
  Future<void> saveDefaultPaymentSources(Map<String, String> sources) async {
    _defaultSources
      ..clear()
      ..addAll(sources);
  }

  @override
  Future<Map<String, String>> loadDefaultCardBillingAccounts() async {
    return Map<String, String>.from(_defaultCardBilling);
  }

  @override
  Future<void> saveDefaultCardBillingAccounts(
    Map<String, String> accounts,
  ) async {
    _defaultCardBilling
      ..clear()
      ..addAll(accounts);
  }

  @override
  Future<List<AssetLiabilityRecurringIncomeTemplate>>
      loadRecurringIncomeTemplates() async {
    return List<AssetLiabilityRecurringIncomeTemplate>.from(_templates);
  }

  @override
  Future<void> saveRecurringIncomeTemplates(
    List<AssetLiabilityRecurringIncomeTemplate> templates,
  ) async {
    _templates
      ..clear()
      ..addAll(templates);
  }

  @override
  Future<AssetLiabilityMonthlyState> copyPreviousMonthToMonth(
    DateTime targetMonth, {
    bool carryOverIncompleteTransferTasks = false,
  }) async {
    final previousMonth = DateTime(targetMonth.year, targetMonth.month - 1);
    final copied = AssetLiabilityMonthlyStateStore.copyPreviousMonthState(
      previousState: await loadMonth(previousMonth),
      targetMonth: targetMonth,
      carryOverIncompleteTransferTasks: carryOverIncompleteTransferTasks,
    );
    await saveMonth(month: targetMonth, state: copied);
    return copied;
  }

  @override
  Future<List<AssetLiabilityMonthlySnapshot>> loadMonthlySnapshots() async {
    return List<AssetLiabilityMonthlySnapshot>.from(_snapshots);
  }

  @override
  Future<void> saveMonthlySnapshot(
    AssetLiabilityMonthlySnapshot snapshot,
  ) async {
    _snapshots.removeWhere((current) => current.monthKey == snapshot.monthKey);
    _snapshots.add(snapshot);
    _snapshots.sort((a, b) => a.monthKey.compareTo(b.monthKey));
  }
}

class _RecordingAssetLiabilityRemoteStore extends AssetLiabilityRemoteStore {
  final List<String> calls = <String>[];
  final Map<String, AssetLiabilityMonthlyState> _states =
      <String, AssetLiabilityMonthlyState>{};
  final Map<String, String> _defaultPaymentSources = <String, String>{};
  final Map<String, String> _defaultCardBillingAccounts = <String, String>{};
  final List<AssetLiabilityRecurringIncomeTemplate> _recurringIncomeTemplates =
      <AssetLiabilityRecurringIncomeTemplate>[];
  final List<AssetLiabilityMonthlySnapshot> _monthlySnapshots =
      <AssetLiabilityMonthlySnapshot>[];
  final List<AssetLiabilityMonthlyReport> _monthlyReports =
      <AssetLiabilityMonthlyReport>[];

  bool _hasDefaultPaymentSources = false;
  bool _hasDefaultCardBillingAccounts = false;
  bool _hasRecurringIncomeTemplates = false;
  bool _hasMonthlySnapshots = false;
  bool _hasMonthlyReports = false;
  bool failSaves = false;

  Map<String, String> get defaultPaymentSources =>
      Map<String, String>.from(_defaultPaymentSources);

  Map<String, String> get defaultCardBillingAccounts =>
      Map<String, String>.from(_defaultCardBillingAccounts);

  List<AssetLiabilityRecurringIncomeTemplate> get recurringIncomeTemplates =>
      List<AssetLiabilityRecurringIncomeTemplate>.from(
        _recurringIncomeTemplates,
      );

  List<AssetLiabilityMonthlySnapshot> get monthlySnapshots =>
      List<AssetLiabilityMonthlySnapshot>.from(_monthlySnapshots);

  List<AssetLiabilityMonthlyReport> get monthlyReports =>
      List<AssetLiabilityMonthlyReport>.from(_monthlyReports);

  AssetLiabilityMonthlyState? monthState(String monthKey) => _states[monthKey];

  void seedMonth(DateTime month, AssetLiabilityMonthlyState state) {
    _states[AssetLiabilityMonthlyStateStore.formatMonthKey(month)] = state;
  }

  void seedDefaultPaymentSources(Map<String, String> sources) {
    _hasDefaultPaymentSources = true;
    _defaultPaymentSources
      ..clear()
      ..addAll(sources);
  }

  void seedDefaultCardBillingAccounts(Map<String, String> accounts) {
    _hasDefaultCardBillingAccounts = true;
    _defaultCardBillingAccounts
      ..clear()
      ..addAll(accounts);
  }

  void seedRecurringIncomeTemplates(
    List<AssetLiabilityRecurringIncomeTemplate> templates,
  ) {
    _hasRecurringIncomeTemplates = true;
    _recurringIncomeTemplates
      ..clear()
      ..addAll(templates);
  }

  void seedMonthlySnapshots(List<AssetLiabilityMonthlySnapshot> snapshots) {
    _hasMonthlySnapshots = true;
    _monthlySnapshots
      ..clear()
      ..addAll(snapshots)
      ..sort((a, b) => a.monthKey.compareTo(b.monthKey));
  }

  void seedMonthlyReports(List<AssetLiabilityMonthlyReport> reports) {
    _hasMonthlyReports = true;
    _monthlyReports
      ..clear()
      ..addAll(reports)
      ..sort((a, b) => b.monthKey.compareTo(a.monthKey));
  }

  @override
  Future<AssetLiabilityMonthlyState?> loadMonth({
    required String userId,
    required DateTime month,
  }) async {
    final monthKey = AssetLiabilityMonthlyStateStore.formatMonthKey(month);
    calls.add('loadMonth:$userId:$monthKey');
    return _states[monthKey];
  }

  @override
  Future<void> saveMonth({
    required String userId,
    required DateTime month,
    required AssetLiabilityMonthlyState state,
  }) async {
    final monthKey = AssetLiabilityMonthlyStateStore.formatMonthKey(month);
    calls.add('saveMonth:$userId:$monthKey');
    _throwIfSavingFails();
    _states[monthKey] = state;
  }

  @override
  Future<Map<String, String>?> loadDefaultPaymentSources({
    required String userId,
  }) async {
    calls.add('loadDefaultPaymentSources:$userId');
    if (!_hasDefaultPaymentSources) {
      return null;
    }
    return Map<String, String>.from(_defaultPaymentSources);
  }

  @override
  Future<void> saveDefaultPaymentSources({
    required String userId,
    required Map<String, String> sources,
  }) async {
    calls.add('saveDefaultPaymentSources:$userId');
    _throwIfSavingFails();
    _hasDefaultPaymentSources = true;
    _defaultPaymentSources
      ..clear()
      ..addAll(sources);
  }

  @override
  Future<Map<String, String>?> loadDefaultCardBillingAccounts({
    required String userId,
  }) async {
    calls.add('loadDefaultCardBillingAccounts:$userId');
    if (!_hasDefaultCardBillingAccounts) {
      return null;
    }
    return Map<String, String>.from(_defaultCardBillingAccounts);
  }

  @override
  Future<void> saveDefaultCardBillingAccounts({
    required String userId,
    required Map<String, String> accounts,
  }) async {
    calls.add('saveDefaultCardBillingAccounts:$userId');
    _throwIfSavingFails();
    _hasDefaultCardBillingAccounts = true;
    _defaultCardBillingAccounts
      ..clear()
      ..addAll(accounts);
  }

  @override
  Future<List<AssetLiabilityRecurringIncomeTemplate>?>
      loadRecurringIncomeTemplates({required String userId}) async {
    calls.add('loadRecurringIncomeTemplates:$userId');
    if (!_hasRecurringIncomeTemplates) {
      return null;
    }
    return List<AssetLiabilityRecurringIncomeTemplate>.from(
      _recurringIncomeTemplates,
    );
  }

  @override
  Future<void> saveRecurringIncomeTemplates({
    required String userId,
    required List<AssetLiabilityRecurringIncomeTemplate> templates,
  }) async {
    calls.add('saveRecurringIncomeTemplates:$userId');
    _throwIfSavingFails();
    _hasRecurringIncomeTemplates = true;
    _recurringIncomeTemplates
      ..clear()
      ..addAll(templates);
  }

  @override
  Future<List<AssetLiabilityMonthlySnapshot>?> loadMonthlySnapshots({
    required String userId,
  }) async {
    calls.add('loadMonthlySnapshots:$userId');
    if (!_hasMonthlySnapshots) {
      return null;
    }
    return List<AssetLiabilityMonthlySnapshot>.from(_monthlySnapshots);
  }

  @override
  Future<void> saveMonthlySnapshot({
    required String userId,
    required AssetLiabilityMonthlySnapshot snapshot,
  }) async {
    calls.add('saveMonthlySnapshot:$userId:${snapshot.monthKey}');
    _throwIfSavingFails();
    _hasMonthlySnapshots = true;
    _monthlySnapshots.removeWhere(
      (current) => current.monthKey == snapshot.monthKey,
    );
    _monthlySnapshots.add(snapshot);
    _monthlySnapshots.sort((a, b) => a.monthKey.compareTo(b.monthKey));
  }

  @override
  Future<List<AssetLiabilityMonthlyReport>?> loadMonthlyReports({
    required String userId,
    int limit = 24,
  }) async {
    calls.add('loadMonthlyReports:$userId:$limit');
    if (!_hasMonthlyReports) {
      return null;
    }
    return List<AssetLiabilityMonthlyReport>.from(
      _monthlyReports.take(limit < 0 ? 0 : limit),
    );
  }

  void _throwIfSavingFails() {
    if (failSaves) {
      throw StateError('remote save failed');
    }
  }
}

AssetLiabilityMonthlyState _sampleMonthlyState() {
  return AssetLiabilityMonthlyState(
    paymentOverrides: const <String, double>{'mobit': 70000},
    actualPaymentAmounts: const <String, double>{'kddi_provider': 5764},
    paymentDifferenceReasons: const <String, String>{
      'kddi_provider': 'confirmed bill',
    },
    annualRateOverrides: const <String, double>{'mobit': 0.175},
    annualRateEvidences: <String, AssetLiabilityAnnualRateEvidence>{
      'mobit': AssetLiabilityAnnualRateEvidence(
        accountId: 'mobit',
        fileName: 'mobit_apr.png',
        mimeType: 'image/png',
        submittedAt: DateTime(2026, 5, 14, 9),
        submittedAnnualRate: 0.175,
        detectedAnnualRate: 0.175,
        status: AssetLiabilityAnnualRateEvidenceStatus.verified,
        summary: '17.5% APR visible',
        source: 'ai-hub',
      ),
    },
    paidAccountNames: const <String>{'kddi_provider'},
    paymentSourceAccountIds: const <String, String>{'mobit': 'smbc_otsuka'},
    cardBillingAccountIds: const <String, String>{
      'kddi_provider': 'paypay_card',
    },
    cardStatementLines: <AssetLiabilityCardStatementLine>[
      AssetLiabilityCardStatementLine(
        id: 'line_1',
        billingAccountId: 'paypay_card',
        billingAccountName: 'PayPay card',
        postedAt: DateTime(2026, 5, 12),
        description: 'KDDI',
        amount: 5764,
      ),
    ],
    incomePlans: <AssetLiabilityIncomePlan>[
      AssetLiabilityIncomePlan(
        id: 'salary',
        date: DateTime(2026, 5, 25),
        name: 'Salary',
        amount: 250000,
        destinationAccountId: 'smbc_otsuka',
        destinationAccountName: 'SMBC Otsuka',
        received: false,
      ),
    ],
    transferTasks: <AssetLiabilityTransferTask>[
      AssetLiabilityTransferTask(
        id: 'transfer_bank_topup',
        fromAccountId: 'custom_cash',
        fromAccountName: 'Cash',
        toAccountId: 'smbc_otsuka',
        toAccountName: 'SMBC Otsuka',
        amount: 10000,
        dueDate: DateTime(2026, 5, 18),
      ),
    ],
  );
}

AssetLiabilityRecurringIncomeTemplate _sampleRecurringIncomeTemplate() {
  return const AssetLiabilityRecurringIncomeTemplate(
    id: 'salary',
    dayOfMonth: 25,
    name: 'Salary',
    amount: 250000,
    destinationAccountId: 'smbc_otsuka',
    destinationAccountName: 'SMBC Otsuka',
  );
}

AssetLiabilityMonthlySnapshot _sampleSnapshot(
  String monthKey, {
  DateTime? savedAt,
}) {
  return AssetLiabilityMonthlySnapshot(
    monthKey: monthKey,
    savedAt: savedAt ?? DateTime.utc(2026, 5, 31, 12),
    positiveAssetTotal: 120000,
    liabilityTotal: -7200000,
    netWorth: -7080000,
    cashLikeTotal: 60000,
    monthlyScheduledPaymentTotal: 180000,
    monthlyPaidPaymentTotal: 100000,
    monthlyUnpaidPaymentTotal: 80000,
    overduePaymentCount: 1,
  );
}
