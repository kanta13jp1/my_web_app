import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AssetLiabilityMonthlyStateStore', () {
    const store = AssetLiabilityMonthlyStateStore();

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('maps paid-state cycles to salary day boundaries', () {
      expect(
        AssetLiabilityMonthlyStateStore.formatSalaryCycleMonthKey(
          DateTime(2026, 5, 24, 23, 59),
          salaryDay: 25,
        ),
        '2026-04',
      );
      expect(
        AssetLiabilityMonthlyStateStore.formatSalaryCycleMonthKey(
          DateTime(2026, 5, 25),
          salaryDay: 25,
        ),
        '2026-05',
      );
      expect(
        AssetLiabilityMonthlyStateStore.formatSalaryCycleMonthKey(
          DateTime(2026, 6, 24),
          salaryDay: 25,
        ),
        '2026-05',
      );
      expect(
        AssetLiabilityMonthlyStateStore.formatSalaryCycleMonthKey(
          DateTime(2026, 6, 25),
          salaryDay: 25,
        ),
        '2026-06',
      );
    });

    test('salaryCycleStart / EndExclusive give the 25th-to-24th window', () {
      // 6/13 (給料日前) は 5/25〜6/24 サイクル。
      expect(
        AssetLiabilityMonthlyStateStore.salaryCycleStart(DateTime(2026, 6, 13)),
        DateTime(2026, 5, 25),
      );
      expect(
        AssetLiabilityMonthlyStateStore.salaryCycleEndExclusive(
          DateTime(2026, 6, 13),
        ),
        DateTime(2026, 6, 25),
      );
      // 6/25 (給料日当日) は 6/25〜7/24 サイクルへ切替。
      expect(
        AssetLiabilityMonthlyStateStore.salaryCycleStart(DateTime(2026, 6, 25)),
        DateTime(2026, 6, 25),
      );
      expect(
        AssetLiabilityMonthlyStateStore.salaryCycleEndExclusive(
          DateTime(2026, 6, 25),
        ),
        DateTime(2026, 7, 25),
      );
      // 1月始端の前サイクルは前年12/25。
      expect(
        AssetLiabilityMonthlyStateStore.salaryCycleStart(DateTime(2026, 1, 5)),
        DateTime(2025, 12, 25),
      );
    });

    test('saves and restores monthly paid statuses', () async {
      await store.saveMonth(
        month: DateTime(2026, 5, 13),
        state: AssetLiabilityMonthlyState(
          paymentOverrides: const <String, double>{'モビット': 70000},
          paidAccountNames: const <String>{'auPayカード'},
          billingConfirmedAccountIds: const <String>{'paypay_card'},
          actualPaymentAmounts: const <String, double>{'aupay_card': 6200},
          paymentDifferenceReasons: const <String, String>{
            'aupay_card': 'late fee',
          },
          annualRateOverrides: const <String, double>{'mobit': 0.175},
          annualRateEvidences: <String, AssetLiabilityAnnualRateEvidence>{
            'mobit': AssetLiabilityAnnualRateEvidence(
              accountId: 'mobit',
              fileName: 'mobit_apr.png',
              mimeType: 'image/png',
              submittedAt: DateTime(2026, 5, 13, 9),
              submittedAnnualRate: 0.175,
              detectedAnnualRate: 0.175,
              status: AssetLiabilityAnnualRateEvidenceStatus.verified,
              summary: '17.5% is visible.',
              source: 'ai-hub',
            ),
          },
          paymentSourceAccountIds: const <String, String>{
            'mobit': 'custom_bank',
          },
          cardBillingAccountIds: const <String, String>{'au': 'aupay_card'},
          cardStatementLines: <AssetLiabilityCardStatementLine>[
            AssetLiabilityCardStatementLine(
              id: 'line_1',
              billingAccountId: 'aupay_card',
              billingAccountName: 'auPay card',
              postedAt: DateTime(2026, 5, 10),
              description: 'mobile',
              amount: 6200,
            ),
          ],
          incomePlans: <AssetLiabilityIncomePlan>[
            AssetLiabilityIncomePlan(
              id: 'income_salary',
              date: DateTime(2026, 5, 25),
              name: 'Salary',
              amount: 250000,
              destinationAccountId: 'custom_bank',
              destinationAccountName: 'Bank',
              received: false,
            ),
          ],
          transferTasks: <AssetLiabilityTransferTask>[
            AssetLiabilityTransferTask(
              id: 'transfer_bank_topup',
              fromAccountId: 'custom_cash',
              fromAccountName: 'Cash',
              toAccountId: 'custom_bank',
              toAccountName: 'Bank',
              amount: 10000,
              dueDate: DateTime(2026, 5, 18),
              completed: true,
              completedAt: DateTime(2026, 5, 18, 10),
              completionMemo: 'ATM手数料110円。移動後の銀行残高は84,000円。',
            ),
          ],
        ),
      );

      final loadedMay = await store.loadMonth(DateTime(2026, 5, 20));
      final loadedJune = await store.loadMonth(DateTime(2026, 6, 1));

      expect(loadedMay.paymentOverrides['モビット'], 70000);
      expect(loadedMay.paidAccountNames, contains('auPayカード'));
      expect(loadedMay.billingConfirmedAccountIds, contains('paypay_card'));
      expect(loadedMay.actualPaymentAmounts['aupay_card'], 6200);
      expect(loadedMay.paymentDifferenceReasons['aupay_card'], 'late fee');
      expect(loadedMay.annualRateOverrides['mobit'], 0.175);
      expect(loadedMay.annualRateEvidences['mobit']?.verified, isTrue);
      expect(loadedMay.annualRateEvidences['mobit']?.fileName, 'mobit_apr.png');
      expect(loadedMay.paymentSourceAccountIds['mobit'], 'custom_bank');
      expect(loadedMay.cardBillingAccountIds['au'], 'aupay_card');
      expect(loadedMay.cardStatementLines.single.amount, 6200);
      expect(loadedMay.cardStatementLines.single.description, 'mobile');
      expect(loadedMay.incomePlans.single.name, 'Salary');
      expect(loadedMay.transferTasks.single.id, 'transfer_bank_topup');
      expect(loadedMay.transferTasks.single.amount, 10000);
      expect(loadedMay.transferTasks.single.completed, isTrue);
      expect(
        loadedMay.transferTasks.single.completedAt,
        DateTime(2026, 5, 18, 10),
      );
      expect(
        loadedMay.transferTasks.single.completionMemo,
        'ATM手数料110円。移動後の銀行残高は84,000円。',
      );
      expect(loadedJune.paymentOverrides, isEmpty);
      expect(loadedJune.actualPaymentAmounts, isEmpty);
      expect(loadedJune.paymentDifferenceReasons, isEmpty);
      expect(loadedJune.annualRateOverrides, isEmpty);
      expect(loadedJune.annualRateEvidences, isEmpty);
      expect(loadedJune.paidAccountNames, isEmpty);
      expect(loadedJune.billingConfirmedAccountIds, isEmpty);
      expect(loadedJune.paymentSourceAccountIds, isEmpty);
      expect(loadedJune.cardBillingAccountIds, isEmpty);
      expect(loadedJune.cardStatementLines, isEmpty);
      expect(loadedJune.incomePlans, isEmpty);
      expect(loadedJune.transferTasks, isEmpty);
    });

    test('round-trips canceled transfer task reason', () async {
      await store.saveMonth(
        month: DateTime(2026, 5, 13),
        state: AssetLiabilityMonthlyState(
          transferTasks: <AssetLiabilityTransferTask>[
            AssetLiabilityTransferTask(
              id: 'transfer_cancelled',
              fromAccountId: 'cash',
              fromAccountName: 'Cash',
              toAccountId: 'bank',
              toAccountName: 'Bank',
              amount: 15000,
              dueDate: DateTime(2026, 5, 20),
              canceled: true,
              canceledAt: DateTime(2026, 5, 19, 21),
              cancellationReason: 'Paid directly from salary account.',
            ),
          ],
        ),
      );

      final loaded = await store.loadMonth(DateTime(2026, 5, 20));
      final task = loaded.transferTasks.single;

      expect(task.id, 'transfer_cancelled');
      expect(task.canceled, isTrue);
      expect(task.canceledAt, DateTime(2026, 5, 19, 21));
      expect(task.cancellationReason, 'Paid directly from salary account.');
      expect(task.completed, isFalse);
    });

    test('clears monthly paid status after unchecked state is saved', () async {
      await store.saveMonth(
        month: DateTime(2026, 5, 13),
        state: const AssetLiabilityMonthlyState(
          paidAccountNames: <String>{'acom_card_loan'},
        ),
      );

      final checked = await store.loadMonth(DateTime(2026, 5, 13));
      expect(checked.paidAccountNames, contains('acom_card_loan'));

      await store.saveMonth(
        month: DateTime(2026, 5, 13),
        state: const AssetLiabilityMonthlyState(),
      );

      final unchecked = await store.loadMonth(DateTime(2026, 5, 13));
      expect(unchecked.paidAccountNames, isEmpty);
    });

    test('keeps zero yen as a valid manual payment amount', () {
      const raw = '{"2026-05":{"PayPayカード":0,"モビット":"70,000"}}';

      final decoded = AssetLiabilityMonthlyStateStore.paymentOverridesForMonth(
        raw,
        '2026-05',
      );

      expect(decoded['PayPayカード'], 0);
      expect(decoded['モビット'], 70000);
    });

    test(
      'drops annual rates above the 20 percent registration block',
      () async {
        await store.saveMonth(
          month: DateTime(2026, 5, 13),
          state: AssetLiabilityMonthlyState(
            annualRateOverrides: const <String, double>{
              'legal': 0.20,
              'blocked': 0.205,
            },
            annualRateEvidences: <String, AssetLiabilityAnnualRateEvidence>{
              'legal': AssetLiabilityAnnualRateEvidence(
                accountId: 'legal',
                fileName: 'legal.png',
                mimeType: 'image/png',
                submittedAt: DateTime(2026, 5, 13),
                submittedAnnualRate: 0.20,
                detectedAnnualRate: 0.20,
                status: AssetLiabilityAnnualRateEvidenceStatus.verified,
                summary: '20%',
                source: 'test',
              ),
              'blocked': AssetLiabilityAnnualRateEvidence(
                accountId: 'blocked',
                fileName: 'blocked.png',
                mimeType: 'image/png',
                submittedAt: DateTime(2026, 5, 13),
                submittedAnnualRate: 0.205,
                detectedAnnualRate: 0.205,
                status: AssetLiabilityAnnualRateEvidenceStatus.verified,
                summary: '20.5%',
                source: 'test',
              ),
            },
          ),
        );

        final loaded = await store.loadMonth(DateTime(2026, 5, 13));
        expect(loaded.annualRateOverrides, <String, double>{'legal': 0.20});
        expect(loaded.annualRateEvidences.keys, contains('legal'));
        expect(loaded.annualRateEvidences.keys, isNot(contains('blocked')));

        const raw = '{"2026-05":{"legal":0.2,"blocked":0.205}}';
        final decoded =
            AssetLiabilityMonthlyStateStore.annualRateOverridesForMonth(
          raw,
          '2026-05',
        );
        expect(decoded, <String, double>{'legal': 0.2});
      },
    );

    test(
      'falls back to estimated payment after manual amount is cleared',
      () async {
        await store.saveMonth(
          month: DateTime(2026, 5, 13),
          state: const AssetLiabilityMonthlyState(
            paymentOverrides: <String, double>{'モビット': 70000},
            paymentSourceAccountIds: <String, String>{'mobit': 'custom_bank'},
            cardBillingAccountIds: <String, String>{'au': 'aupay_card'},
          ),
        );
        await store.saveMonth(
          month: DateTime(2026, 5, 13),
          state: const AssetLiabilityMonthlyState(),
        );

        final loaded = await store.loadMonth(DateTime(2026, 5, 13));

        expect(loaded.paymentOverrides, isEmpty);
        expect(loaded.paidAccountNames, isEmpty);
        expect(loaded.paymentSourceAccountIds, isEmpty);
        expect(loaded.cardBillingAccountIds, isEmpty);
        expect(loaded.incomePlans, isEmpty);
      },
    );

    test('migrates legacy display-name keys to stable account ids', () {
      final migrated = AssetLiabilityMonthlyStateStore.migrateLegacyKeys(
        state: const AssetLiabilityMonthlyState(
          paymentOverrides: <String, double>{'モビット': 70000},
          paidAccountNames: <String>{'auPayカード'},
          paymentSourceAccountIds: <String, String>{'モビット': '銀行口座'},
        ),
        legacyKeyToAccountId: const <String, String>{
          'モビット': 'mobit',
          'auPayカード': 'aupay_card',
          '銀行口座': 'custom_bank',
        },
      );

      expect(migrated.paymentOverrides, <String, double>{'mobit': 70000});
      expect(migrated.paidAccountNames, <String>{'aupay_card'});
      expect(migrated.paymentSourceAccountIds, <String, String>{
        'mobit': 'custom_bank',
      });
    });

    test('migrates card billing routing keys to stable account ids', () {
      final migrated = AssetLiabilityMonthlyStateStore.migrateLegacyKeys(
        state: const AssetLiabilityMonthlyState(
          cardBillingAccountIds: <String, String>{
            'Legacy utility': 'Legacy card',
          },
        ),
        legacyKeyToAccountId: const <String, String>{
          'Legacy utility': 'custom_utility',
          'Legacy card': 'paypay_card',
        },
      );

      expect(migrated.cardBillingAccountIds, <String, String>{
        'custom_utility': 'paypay_card',
      });
    });

    test('migrates actual payment difference keys to stable account ids', () {
      final migrated = AssetLiabilityMonthlyStateStore.migrateLegacyKeys(
        state: AssetLiabilityMonthlyState(
          actualPaymentAmounts: <String, double>{'Legacy card': 6200},
          paymentDifferenceReasons: const <String, String>{
            'Legacy card': 'late fee',
          },
          annualRateOverrides: const <String, double>{'Legacy card': 0.145},
          annualRateEvidences: <String, AssetLiabilityAnnualRateEvidence>{
            'Legacy card': AssetLiabilityAnnualRateEvidence(
              accountId: 'Legacy card',
              fileName: 'apr.png',
              mimeType: 'image/png',
              submittedAt: DateTime(2026, 5, 13),
              submittedAnnualRate: 0.145,
              detectedAnnualRate: 0.145,
              status: AssetLiabilityAnnualRateEvidenceStatus.verified,
              summary: '14.5%',
              source: 'ai-hub',
            ),
          },
        ),
        legacyKeyToAccountId: const <String, String>{
          'Legacy card': 'aupay_card',
        },
      );

      expect(migrated.actualPaymentAmounts, <String, double>{
        'aupay_card': 6200,
      });
      expect(migrated.paymentDifferenceReasons, <String, String>{
        'aupay_card': 'late fee',
      });
      expect(migrated.annualRateOverrides, <String, double>{
        'aupay_card': 0.145,
      });
      expect(
        migrated.annualRateEvidences['aupay_card']?.accountId,
        'aupay_card',
      );
    });

    test(
      'copies previous month settings without paid or received state',
      () async {
        await store.saveMonth(
          month: DateTime(2026, 5, 13),
          state: AssetLiabilityMonthlyState(
            paymentOverrides: const <String, double>{'mobit': 70000},
            annualRateOverrides: const <String, double>{'mobit': 0.175},
            paidAccountNames: const <String>{'mobit'},
            paymentSourceAccountIds: const <String, String>{
              'mobit': 'custom_bank',
            },
            cardBillingAccountIds: const <String, String>{
              'kddi_provider': 'paypay_card',
            },
            incomePlans: <AssetLiabilityIncomePlan>[
              AssetLiabilityIncomePlan(
                id: 'salary',
                date: DateTime(2026, 5, 31),
                name: 'Salary',
                amount: 250000,
                destinationAccountId: 'custom_bank',
                destinationAccountName: 'Bank',
                received: true,
              ),
            ],
            transferTasks: <AssetLiabilityTransferTask>[
              AssetLiabilityTransferTask(
                id: 'transfer_may',
                fromAccountId: 'custom_cash',
                fromAccountName: 'Cash',
                toAccountId: 'custom_bank',
                toAccountName: 'Bank',
                amount: 10000,
                dueDate: DateTime(2026, 5, 20),
              ),
            ],
          ),
        );

        final copied = await store.copyPreviousMonthToMonth(
          DateTime(2026, 6, 10),
        );
        final loaded = await store.loadMonth(DateTime(2026, 6, 20));

        expect(copied.paymentOverrides, <String, double>{'mobit': 70000});
        expect(copied.annualRateOverrides, <String, double>{'mobit': 0.175});
        expect(copied.paymentSourceAccountIds, <String, String>{
          'mobit': 'custom_bank',
        });
        expect(copied.cardBillingAccountIds, <String, String>{
          'kddi_provider': 'paypay_card',
        });
        expect(copied.paidAccountNames, isEmpty);
        expect(copied.transferTasks, isEmpty);
        expect(copied.incomePlans.single.date, DateTime(2026, 6, 30));
        expect(copied.incomePlans.single.received, isFalse);
        expect(loaded.paidAccountNames, isEmpty);
        expect(loaded.annualRateOverrides, <String, double>{'mobit': 0.175});
        expect(loaded.cardBillingAccountIds, <String, String>{
          'kddi_provider': 'paypay_card',
        });
        expect(loaded.incomePlans.single.received, isFalse);
        expect(loaded.transferTasks, isEmpty);
      },
    );

    test('does not copy actual payments or difference reasons', () async {
      await store.saveMonth(
        month: DateTime(2026, 5, 13),
        state: const AssetLiabilityMonthlyState(
          paymentOverrides: <String, double>{'mobit': 70000},
          actualPaymentAmounts: <String, double>{'mobit': 71000},
          paymentDifferenceReasons: <String, String>{'mobit': 'fee adjustment'},
          paidAccountNames: <String>{'mobit'},
        ),
      );

      final copied = await store.copyPreviousMonthToMonth(
        DateTime(2026, 6, 10),
      );
      final loaded = await store.loadMonth(DateTime(2026, 6, 20));

      expect(copied.paymentOverrides, <String, double>{'mobit': 70000});
      expect(copied.actualPaymentAmounts, isEmpty);
      expect(copied.paymentDifferenceReasons, isEmpty);
      expect(copied.paidAccountNames, isEmpty);
      expect(loaded.actualPaymentAmounts, isEmpty);
      expect(loaded.paymentDifferenceReasons, isEmpty);
      expect(loaded.paidAccountNames, isEmpty);
    });

    test('can carry open transfer tasks to the copied month', () async {
      await store.saveMonth(
        month: DateTime(2026, 5, 13),
        state: AssetLiabilityMonthlyState(
          transferTasks: <AssetLiabilityTransferTask>[
            AssetLiabilityTransferTask(
              id: 'open_transfer',
              fromAccountId: 'cash',
              fromAccountName: 'Cash',
              toAccountId: 'bank',
              toAccountName: 'Bank',
              amount: 12000,
              dueDate: DateTime(2026, 5, 31),
              completionMemo: 'ATM planned.',
            ),
            AssetLiabilityTransferTask(
              id: 'done_transfer',
              fromAccountId: 'cash',
              fromAccountName: 'Cash',
              toAccountId: 'bank',
              toAccountName: 'Bank',
              amount: 8000,
              dueDate: DateTime(2026, 5, 20),
              completed: true,
              completedAt: DateTime(2026, 5, 20, 9),
            ),
            AssetLiabilityTransferTask(
              id: 'canceled_transfer',
              fromAccountId: 'cash',
              fromAccountName: 'Cash',
              toAccountId: 'bank',
              toAccountName: 'Bank',
              amount: 7000,
              dueDate: DateTime(2026, 5, 21),
              canceled: true,
              canceledAt: DateTime(2026, 5, 21, 8),
              cancellationReason: 'No longer needed.',
            ),
          ],
        ),
      );

      final copied = await store.copyPreviousMonthToMonth(
        DateTime(2026, 6, 10),
        carryOverIncompleteTransferTasks: true,
      );
      final loaded = await store.loadMonth(DateTime(2026, 6, 20));

      expect(copied.transferTasks, hasLength(1));
      expect(copied.transferTasks.single.id, 'carry_2026-06_open_transfer');
      expect(copied.transferTasks.single.dueDate, DateTime(2026, 6, 30));
      expect(copied.transferTasks.single.completed, isFalse);
      expect(copied.transferTasks.single.canceled, isFalse);
      expect(copied.transferTasks.single.completionMemo, 'ATM planned.');
      expect(loaded.transferTasks.single.id, 'carry_2026-06_open_transfer');
    });

    test('saves and restores default payment source accounts', () async {
      await store.saveDefaultPaymentSources(const <String, String>{
        'mobit': 'custom_bank',
        'acom_card_loan': 'wallet_cash',
      });

      final loaded = await store.loadDefaultPaymentSources();

      expect(loaded, <String, String>{
        'mobit': 'custom_bank',
        'acom_card_loan': 'wallet_cash',
      });
    });

    test('saves and restores default card billing accounts', () async {
      await store.saveDefaultCardBillingAccounts(const <String, String>{
        'kddi_provider': 'paypay_card',
        'au': AssetLiabilityPlanningService.auPayCardAccountId,
      });

      final loaded = await store.loadDefaultCardBillingAccounts();

      expect(loaded, <String, String>{
        'kddi_provider': 'paypay_card',
        'au': AssetLiabilityPlanningService.auPayCardAccountId,
      });
    });

    test('applies recurring income templates to the target month', () async {
      final plans =
          AssetLiabilityMonthlyStateStore.applyRecurringIncomeTemplates(
        month: DateTime(2026, 2, 1),
        templates: const <AssetLiabilityRecurringIncomeTemplate>[
          AssetLiabilityRecurringIncomeTemplate(
            id: 'salary',
            dayOfMonth: 31,
            name: 'Salary',
            amount: 250000,
            destinationAccountId: 'custom_bank',
            destinationAccountName: 'Bank',
          ),
        ],
        existingPlans: const <AssetLiabilityIncomePlan>[],
      );

      expect(plans.single.id, 'recurring_salary_2026-02');
      expect(plans.single.date, DateTime(2026, 2, 28));
      expect(plans.single.received, isFalse);
      expect(plans.single.destinationAccountId, 'custom_bank');
    });

    test('saves and updates monthly snapshots by month', () async {
      await store.saveMonthlySnapshot(
        AssetLiabilityMonthlySnapshot(
          monthKey: '2026-05',
          savedAt: DateTime(2026, 5, 31, 20),
          positiveAssetTotal: 100000,
          liabilityTotal: -7000000,
          netWorth: -6900000,
          cashLikeTotal: 50000,
          monthlyScheduledPaymentTotal: 120000,
          monthlyPaidPaymentTotal: 80000,
          monthlyUnpaidPaymentTotal: 40000,
          overduePaymentCount: 1,
        ),
      );
      await store.saveMonthlySnapshot(
        AssetLiabilityMonthlySnapshot(
          monthKey: '2026-05',
          savedAt: DateTime(2026, 5, 31, 21),
          positiveAssetTotal: 110000,
          liabilityTotal: -6900000,
          netWorth: -6790000,
          cashLikeTotal: 60000,
          monthlyScheduledPaymentTotal: 130000,
          monthlyPaidPaymentTotal: 130000,
          monthlyUnpaidPaymentTotal: 0,
          overduePaymentCount: 0,
        ),
      );

      final snapshots = await store.loadMonthlySnapshots();

      expect(snapshots, hasLength(1));
      expect(snapshots.single.monthKey, '2026-05');
      expect(snapshots.single.positiveAssetTotal, 110000);
      expect(snapshots.single.monthlyPaidPaymentTotal, 130000);
      expect(snapshots.single.overduePaymentCount, 0);
    });

    test('saves and restores debt payment day overrides', () async {
      await store.saveDebtPaymentDayOverrides(const <String, int>{
        'famima_card': 27,
        'paypay_card': 15,
      });

      final overrides = await store.loadDebtPaymentDayOverrides();

      expect(overrides, <String, int>{'famima_card': 27, 'paypay_card': 15});
    });

    test('drops invalid debt payment day overrides on save and load', () async {
      await store.saveDebtPaymentDayOverrides(const <String, int>{
        'famima_card': 27,
        'too_small': 0,
        'too_large': 32,
        '': 10,
      });

      final overrides = await store.loadDebtPaymentDayOverrides();

      expect(overrides, <String, int>{'famima_card': 27});

      expect(
        AssetLiabilityMonthlyStateStore.decodeDebtPaymentDayOverrides(
          '{"famima_card": 27, "junk": "abc", "out_of_range": 99}',
        ),
        <String, int>{'famima_card': 27},
      );
      expect(
        AssetLiabilityMonthlyStateStore.decodeDebtPaymentDayOverrides(
          '[1, 2, 3]',
        ),
        isEmpty,
      );
    });

    test('saves and restores the updatedAt timestamp by month', () async {
      final timestamp = DateTime.utc(2026, 5, 20, 10, 30);
      await store.saveMonth(
        month: DateTime(2026, 5),
        state: AssetLiabilityMonthlyState(
          paidAccountNames: const <String>{'mobit'},
          updatedAt: timestamp,
        ),
      );

      final restored = await store.loadMonth(DateTime(2026, 5));
      expect(restored.updatedAt?.toUtc(), timestamp);
      // 別月には漏れない。
      final other = await store.loadMonth(DateTime(2026, 6));
      expect(other.updatedAt, isNull);
    });
  });

  group('AssetLiabilityMonthlyState.mergeWith', () {
    test('unions paid sets and fills gaps from the other device', () {
      const local = AssetLiabilityMonthlyState(
        paidAccountNames: <String>{'mobit'},
        actualPaymentAmounts: <String, double>{'mobit': 61024},
      );
      const remote = AssetLiabilityMonthlyState(
        paidAccountNames: <String>{'yokohama_bank'},
        actualPaymentAmounts: <String, double>{'yokohama_bank': 4846},
      );

      final merged = local.mergeWith(remote);

      expect(
        merged.paidAccountNames,
        containsAll(<String>{'mobit', 'yokohama_bank'}),
      );
      expect(merged.actualPaymentAmounts['mobit'], 61024);
      expect(merged.actualPaymentAmounts['yokohama_bank'], 4846);
    });

    test('keeps local value when a scalar key conflicts', () {
      const local = AssetLiabilityMonthlyState(
        paymentOverrides: <String, double>{'mobit': 70000},
      );
      const remote = AssetLiabilityMonthlyState(
        paymentOverrides: <String, double>{'mobit': 60000},
      );

      expect(local.mergeWith(remote).paymentOverrides['mobit'], 70000);
    });

    test('carries the later updatedAt into the merged result', () {
      final older = AssetLiabilityMonthlyState(
        paidAccountNames: const <String>{'mobit'},
        updatedAt: DateTime(2026, 5, 20, 9),
      );
      final newer = AssetLiabilityMonthlyState(
        paidAccountNames: const <String>{'yokohama_bank'},
        updatedAt: DateTime(2026, 5, 20, 10),
      );

      expect(older.mergeWith(newer).updatedAt, DateTime(2026, 5, 20, 10));
      expect(newer.mergeWith(older).updatedAt, DateTime(2026, 5, 20, 10));
    });

    test('unions list entries by id without duplicating shared ids', () {
      final local = AssetLiabilityMonthlyState(
        transferTasks: <AssetLiabilityTransferTask>[
          AssetLiabilityTransferTask(
            id: 'shared',
            fromAccountId: 'a',
            fromAccountName: 'A',
            toAccountId: 'b',
            toAccountName: 'B',
            amount: 1000,
            dueDate: DateTime(2026, 5, 18),
          ),
        ],
      );
      final remote = AssetLiabilityMonthlyState(
        transferTasks: <AssetLiabilityTransferTask>[
          AssetLiabilityTransferTask(
            id: 'shared',
            fromAccountId: 'a',
            fromAccountName: 'A',
            toAccountId: 'b',
            toAccountName: 'B',
            amount: 1000,
            dueDate: DateTime(2026, 5, 18),
          ),
          AssetLiabilityTransferTask(
            id: 'remote_only',
            fromAccountId: 'c',
            fromAccountName: 'C',
            toAccountId: 'd',
            toAccountName: 'D',
            amount: 2000,
            dueDate: DateTime(2026, 5, 20),
          ),
        ],
      );

      final merged = local.mergeWith(remote);

      expect(merged.transferTasks.map((task) => task.id), <String>[
        'shared',
        'remote_only',
      ]);
    });
  });
}
