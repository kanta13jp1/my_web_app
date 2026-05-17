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

    test('saves and restores monthly paid statuses', () async {
      await store.saveMonth(
        month: DateTime(2026, 5, 13),
        state: AssetLiabilityMonthlyState(
          paymentOverrides: const <String, double>{'モビット': 70000},
          paidAccountNames: const <String>{'auPayカード'},
          actualPaymentAmounts: const <String, double>{'aupay_card': 6200},
          paymentDifferenceReasons: const <String, String>{
            'aupay_card': 'late fee',
          },
          annualRateOverrides: const <String, double>{'mobit': 0.175},
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
            ),
          ],
        ),
      );

      final loadedMay = await store.loadMonth(DateTime(2026, 5, 20));
      final loadedJune = await store.loadMonth(DateTime(2026, 6, 1));

      expect(loadedMay.paymentOverrides['モビット'], 70000);
      expect(loadedMay.paidAccountNames, contains('auPayカード'));
      expect(loadedMay.actualPaymentAmounts['aupay_card'], 6200);
      expect(loadedMay.paymentDifferenceReasons['aupay_card'], 'late fee');
      expect(loadedMay.annualRateOverrides['mobit'], 0.175);
      expect(loadedMay.paymentSourceAccountIds['mobit'], 'custom_bank');
      expect(loadedMay.cardBillingAccountIds['au'], 'aupay_card');
      expect(loadedMay.cardStatementLines.single.amount, 6200);
      expect(loadedMay.cardStatementLines.single.description, 'mobile');
      expect(loadedMay.incomePlans.single.name, 'Salary');
      expect(loadedMay.transferTasks.single.id, 'transfer_bank_topup');
      expect(loadedMay.transferTasks.single.amount, 10000);
      expect(loadedJune.paymentOverrides, isEmpty);
      expect(loadedJune.actualPaymentAmounts, isEmpty);
      expect(loadedJune.paymentDifferenceReasons, isEmpty);
      expect(loadedJune.annualRateOverrides, isEmpty);
      expect(loadedJune.paidAccountNames, isEmpty);
      expect(loadedJune.paymentSourceAccountIds, isEmpty);
      expect(loadedJune.cardBillingAccountIds, isEmpty);
      expect(loadedJune.cardStatementLines, isEmpty);
      expect(loadedJune.incomePlans, isEmpty);
      expect(loadedJune.transferTasks, isEmpty);
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
        state: const AssetLiabilityMonthlyState(
          actualPaymentAmounts: <String, double>{'Legacy card': 6200},
          paymentDifferenceReasons: <String, String>{'Legacy card': 'late fee'},
          annualRateOverrides: <String, double>{'Legacy card': 0.145},
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
  });
}
