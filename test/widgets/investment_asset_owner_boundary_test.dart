import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/investment_asset.dart';
import 'package:my_web_app/models/investment_portfolio_history.dart';
import 'package:my_web_app/services/investment_asset_repository.dart';
import 'package:my_web_app/widgets/investment_asset_management_panel.dart';

void main() {
  for (final operation in ['add', 'edit', 'delete']) {
    for (final phase in ['dialog', 'write', 'writeError']) {
      for (final mode in ['same', 'other', 'aba']) {
        testWidgets('investment owner $operation phase=$phase scope=$mode',
            (tester) async {
          final h = _Harness();
          if (phase != 'dialog') h.repository.gates[1] = Completer<void>();
          if (phase == 'writeError') h.repository.failAt = 1;
          await h.mount(tester);
          await h.open(tester, operation);
          if (phase == 'dialog') await h.switchOwner(tester, mode);
          if (phase == 'dialog' && mode != 'same') {
            await h.closeInvalidDialog(tester);
          } else {
            await h.confirm(tester, operation);
          }
          if (phase != 'dialog') {
            expect(h.repository.writes.length, 1);
            await h.switchOwner(tester, mode);
          }
          final historyBefore = h.repository.historyCalls;
          h.repository.gates[1]?.complete();
          await _frames(tester);
          final expectedWrites = phase == 'dialog' && mode != 'same' ? 0 : 1;
          expect(h.repository.writes.length, expectedWrites);
          expect(h.repository.writes.every((w) => w.owner == 'a'), isTrue);
          final failureText = operation == 'delete'
              ? '投資資産を削除できませんでした。時間をおいて再試行してください。'
              : '投資資産を保存できませんでした。時間をおいて再試行してください。';
          if (mode == 'same' && phase == 'writeError') {
            expect(find.text(failureText), findsOneWidget);
          } else {
            expect(find.text(failureText), findsNothing);
          }
          if (mode != 'same') {
            expect(h.repository.historyCalls, historyBefore);
            expect(find.textContaining('changed-a'), findsNothing);
            expect(find.textContaining('created-a'), findsNothing);
            expect(
              find.text(mode == 'other' ? 'BETA' : 'ALPHA'),
              findsOneWidget,
            );
          } else if (phase != 'writeError') {
            if (operation == 'delete') {
              expect(find.text('ALPHA'), findsNothing);
            } else {
              expect(
                find.textContaining(
                  operation == 'add' ? 'created-a' : 'changed-a',
                ),
                findsWidgets,
              );
            }
          }
          expect(tester.takeException(), isNull);
          await h.finish(tester);
        });
      }
    }
  }

  for (final phase in ['picker', 'preview', 'row', 'rowError']) {
    for (final mode in ['same', 'other', 'aba']) {
      testWidgets('investment owner csv phase=$phase scope=$mode',
          (tester) async {
        final h = _Harness();
        final picker = Completer<Uint8List?>();
        h.picker = () => picker.future;
        if (phase == 'row' || phase == 'rowError') {
          h.repository.gates[1] = Completer<void>();
        }
        if (phase == 'rowError') h.repository.failAt = 1;
        await h.mount(tester);
        await tester.tap(find.byKey(const Key('investment_asset_csv_import')));
        await _frames(tester);
        if (phase == 'picker') await h.switchOwner(tester, mode);
        picker.complete(_csv());
        await _frames(tester);
        if (phase == 'picker' && mode != 'same') {
          expect(
            find.byKey(const Key('investment_csv_preview_dialog')),
            findsNothing,
          );
          expect(h.repository.writes, isEmpty);
          await h.finish(tester);
          return;
        }
        expect(
          find.byKey(const Key('investment_csv_preview_dialog')),
          findsOneWidget,
        );
        if (phase == 'preview') await h.switchOwner(tester, mode);
        if (phase == 'preview' && mode != 'same') {
          await h.closeInvalidDialog(tester);
        } else {
          await tester
              .tap(find.byKey(const Key('investment_csv_import_confirm')));
          await _frames(tester);
        }
        if (phase == 'row' || phase == 'rowError') {
          expect(h.repository.writes.length, 1);
          await h.switchOwner(tester, mode);
          h.repository.gates[1]!.complete();
          await _frames(tester);
        }
        final expected = mode != 'same'
            ? (phase == 'row' || phase == 'rowError' ? 1 : 0)
            : (phase == 'rowError' ? 1 : 2);
        expect(h.repository.writes.length, expected);
        expect(h.repository.writes.every((w) => w.owner == 'a'), isTrue);
        if (mode != 'same') {
          expect(find.text('NEW1'), findsNothing);
          expect(find.text('NEW2'), findsNothing);
          expect(find.textContaining('件追加・'), findsNothing);
          expect(find.textContaining('一部が保存済み'), findsNothing);
        } else if (phase == 'rowError') {
          expect(find.textContaining('一部が保存済み'), findsOneWidget);
        } else {
          expect(find.text('NEW1'), findsOneWidget);
          expect(find.text('NEW2'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await h.finish(tester);
      });
    }
  }

  for (final fault in ['error', 'done']) {
    testWidgets('investment owner stream fails closed on $fault',
        (tester) async {
      final h = _Harness();
      await h.mount(tester);
      if (fault == 'error') {
        h.events.addError(StateError('synthetic owner-stream failure'));
      } else {
        await h.events.close();
      }
      await _frames(tester);
      expect(
        find.byKey(const Key('investment_asset_owner_unconfirmed')),
        findsOneWidget,
      );
      expect(find.text('ALPHA'), findsNothing);
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('investment_asset_add')))
            .onPressed,
        isNull,
      );
      expect(h.repository.writes, isEmpty);
      expect(tester.takeException(), isNull);
      await h.finish(tester);
    });
  }

  for (final fault in ['error', 'done', 'repository']) {
    testWidgets('investment owner open editor redacts on $fault',
        (tester) async {
      final h = _Harness();
      final original = h.repository;
      await h.mount(tester);
      await h.open(tester, 'edit');
      expect(find.text('changed-a'), findsOneWidget);
      if (fault == 'error') {
        h.events.addError(StateError('synthetic owner-stream failure'));
      } else if (fault == 'done') {
        await h.events.close();
      } else {
        h.repository = _Repository();
        await tester.pumpWidget(h.widget());
      }
      await _frames(tester);
      await h.closeInvalidDialog(tester);
      expect(original.writes, isEmpty);
      expect(h.repository.writes, isEmpty);
      expect(tester.takeException(), isNull);
      await h.finish(tester);
    });
  }

  for (final mode in ['other', 'aba', 'error', 'done', 'repository']) {
    testWidgets('investment owner nested date picker redacts on $mode',
        (tester) async {
      final h = _Harness();
      final original = h.repository;
      await h.mount(tester);
      await h.open(tester, 'edit');
      final dateField = find.byKey(
        const Key('investment_asset_buy_date_field'),
      );
      await tester.ensureVisible(dateField);
      await tester.tap(dateField);
      await _frames(tester);
      expect(find.byType(DatePickerDialog), findsOneWidget);
      if (mode == 'error') {
        h.events.addError(StateError('synthetic owner-stream failure'));
      } else if (mode == 'done') {
        await h.events.close();
      } else if (mode == 'repository') {
        h.repository = _Repository();
        await tester.pumpWidget(h.widget());
      } else {
        await h.switchOwner(tester, mode);
      }
      await _frames(tester);
      expect(find.byType(DatePickerDialog), findsNothing);
      await h.closeInvalidDialog(tester, expectedDialogs: 2);
      await h.closeInvalidDialog(tester);
      expect(original.writes, isEmpty);
      expect(h.repository.writes, isEmpty);
      expect(tester.takeException(), isNull);
      await h.finish(tester);
    });
  }

  testWidgets('investment owner old finally does not unlock new-owner save',
      (tester) async {
    final h = _Harness();
    h.repository.gates[1] = Completer<void>();
    h.repository.gates[2] = Completer<void>();
    await h.mount(tester);
    await h.open(tester, 'edit');
    await h.confirm(tester, 'edit');
    await h.switchOwner(tester, 'other');
    await h.open(tester, 'edit');
    await h.confirm(tester, 'edit');
    expect(h.repository.writes.length, 2);
    h.repository.gates[1]!.complete();
    await _frames(tester);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('investment_asset_add')))
          .onPressed,
      isNull,
    );
    h.repository.gates[2]!.complete();
    await _frames(tester);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('investment_asset_add')))
          .onPressed,
      isNotNull,
    );
    expect(h.repository.writes.map((w) => w.owner), ['a', 'b']);
    expect(tester.takeException(), isNull);
    await h.finish(tester);
  });

  testWidgets('investment owner repository replacement discards old completion',
      (tester) async {
    final h = _Harness();
    final old = h.repository;
    old.gates[1] = Completer<void>();
    await h.mount(tester);
    await h.open(tester, 'edit');
    await h.confirm(tester, 'edit');
    h.repository = _Repository();
    await tester.pumpWidget(h.widget());
    await _frames(tester);
    old.gates[1]!.complete();
    await _frames(tester);
    expect(find.text('ALPHA'), findsOneWidget);
    expect(find.textContaining('changed-a'), findsNothing);
    expect(h.repository.writes, isEmpty);
    expect(tester.takeException(), isNull);
    await h.finish(tester);
  });
}

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Uint8List _csv() => Uint8List.fromList(
      utf8.encode(
        '銘柄,数量,取得単価,現在値\nNEW1 Sample,1,1000,1200\nNEW2 Sample,1,1000,1200\n',
      ),
    );

class _Harness {
  String? owner = 'a';
  _Repository repository = _Repository();
  final events = StreamController<String?>.broadcast(sync: true);
  InvestmentCsvBytesPicker? picker;

  Widget widget() => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 520,
              child: InvestmentAssetManagementPanel(
                repository: repository,
                userId: owner,
                currentOwnerId: () => owner,
                ownerChanges: events.stream,
                csvBytesPicker: picker,
              ),
            ),
          ),
        ),
      );

  Future<void> mount(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(widget());
    await _frames(tester);
  }

  Future<void> switchOwner(WidgetTester tester, String mode) async {
    if (mode == 'same') return;
    owner = 'b';
    events.add(owner);
    await _frames(tester);
    if (mode == 'aba') {
      owner = 'a';
      events.add(owner);
      await _frames(tester);
    }
  }

  Future<void> open(WidgetTester tester, String operation) async {
    final id = 'seed-${owner!}';
    final key = operation == 'add'
        ? 'investment_asset_add'
        : 'investment_asset_${operation}_$id';
    await tester.ensureVisible(find.byKey(ValueKey<String>(key)));
    await tester.tap(find.byKey(ValueKey<String>(key)));
    await _frames(tester);
    if (operation == 'add') {
      await tester.enterText(
        find.byKey(const Key('investment_asset_ticker_field')),
        'NEW',
      );
      await tester.enterText(
        find.byKey(const Key('investment_asset_quantity_field')),
        '1',
      );
      await tester.enterText(
        find.byKey(const Key('investment_asset_buy_price_field')),
        '1000',
      );
      await tester.enterText(
        find.byKey(const Key('investment_asset_name_field')),
        'created-${owner!}',
      );
    } else if (operation == 'edit') {
      await tester.enterText(
        find.byKey(const Key('investment_asset_name_field')),
        'changed-${owner!}',
      );
    }
  }

  Future<void> closeInvalidDialog(
    WidgetTester tester, {
    int expectedDialogs = 1,
  }) async {
    expect(
      find.byKey(const Key('investment_owner_dialog_invalid')),
      findsNWidgets(expectedDialogs),
    );
    for (final key in [
      'investment_asset_name_field',
      'investment_asset_delete_confirm',
      'investment_csv_preview_dialog',
    ]) {
      expect(find.byKey(Key(key)), findsNothing);
    }
    expect(find.text('changed-a'), findsNothing);
    final closeButton = find
        .byKey(const Key('investment_owner_dialog_close'))
        .hitTestable();
    expect(closeButton, findsOneWidget);
    await tester.tap(closeButton);
    await _frames(tester);
    expect(
      find.byKey(const Key('investment_owner_dialog_invalid')),
      findsNWidgets(expectedDialogs - 1),
    );
  }

  Future<void> confirm(WidgetTester tester, String operation) async {
    await tester.tap(
      find.byKey(
        Key(
          operation == 'delete'
              ? 'investment_asset_delete_confirm'
              : 'investment_asset_save',
        ),
      ),
    );
    await _frames(tester);
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester);
    if (!events.isClosed) await events.close();
  }
}

class _Write {
  _Write(this.owner, this.operation);
  final String owner;
  final String operation;
}

class _Repository implements InvestmentAssetRepository {
  final rows = <String, List<InvestmentAsset>>{
    'a': [_seed('a', 'ALPHA')],
    'b': [_seed('b', 'BETA')],
  };
  final writes = <_Write>[];
  final gates = <int, Completer<void>>{};
  int? failAt;
  int historyCalls = 0;

  @override
  Future<List<InvestmentAsset>> fetchByUser({required String userId}) async =>
      List<InvestmentAsset>.from(rows[userId] ?? <InvestmentAsset>[]);

  @override
  Future<List<InvestmentPortfolioHistoryPoint>> fetchPortfolioHistory({
    required String userId,
  }) async {
    historyCalls++;
    return const <InvestmentPortfolioHistoryPoint>[];
  }

  Future<InvestmentAsset> _write(
    String operation,
    String userId,
    String id,
    InvestmentAssetDraft? draft,
  ) async {
    writes.add(_Write(userId, operation));
    final position = writes.length;
    await gates[position]?.future;
    if (failAt == position) throw StateError('synthetic mutation failure');
    final bucket = rows.putIfAbsent(userId, () => <InvestmentAsset>[]);
    if (operation == 'delete') {
      final previous = bucket.firstWhere((a) => a.id == id);
      bucket.removeWhere((a) => a.id == id);
      return previous;
    }
    final value = InvestmentAsset(
      id: id,
      userId: userId,
      assetType: draft!.assetType,
      ticker: draft.normalizedTicker,
      displayName: draft.displayName,
      quantity: draft.quantity,
      buyPriceJpy: draft.buyPriceJpy,
      buyDate: draft.buyDate,
      currentPriceJpy: draft.currentPriceJpy,
      lastPricedAt: draft.lastPricedAt,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    bucket.removeWhere((a) => a.id == id);
    bucket.add(value);
    return value;
  }

  @override
  Future<InvestmentAsset> create({
    required String userId,
    required InvestmentAssetDraft draft,
  }) =>
      _write(
        'add',
        userId,
        'created-$userId-${writes.length + 1}',
        draft,
      );

  @override
  Future<InvestmentAsset> update({
    required String userId,
    required String assetId,
    required InvestmentAssetDraft draft,
  }) =>
      _write('edit', userId, assetId, draft);

  @override
  Future<void> delete({
    required String userId,
    required String assetId,
  }) async {
    await _write('delete', userId, assetId, null);
  }
}

InvestmentAsset _seed(String owner, String ticker) => InvestmentAsset(
      id: 'seed-$owner',
      userId: owner,
      assetType: InvestmentAssetType.stock,
      ticker: ticker,
      quantity: 1,
      buyPriceJpy: 1000,
      buyDate: DateTime.utc(2026, 1, 1),
      currentPriceJpy: 1200,
      lastPricedAt: DateTime.utc(2026, 1, 1),
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
