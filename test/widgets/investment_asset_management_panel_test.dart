import 'dart:convert';
import 'dart:typed_data';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/investment_asset.dart';
import 'package:my_web_app/models/investment_portfolio_history.dart';
import 'package:my_web_app/services/investment_asset_repository.dart';
import 'package:my_web_app/widgets/investment_asset_management_panel.dart';

void main() {
  testWidgets('logged-out state does not query the repository', (tester) async {
    final repository = _FakeInvestmentAssetRepository(const []);

    await _pumpPanel(tester, repository: repository, userId: null);

    expect(find.byKey(const Key('investment_asset_logged_out')), findsOne);
    expect(repository.fetchCalls, 0);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('investment_asset_add')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('shows valuation, gain, and rate on a narrow layout', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FakeInvestmentAssetRepository([
      _asset(
        id: 'asset-1',
        ticker: 'AAPL',
        quantity: 2,
        buyPriceJpy: 1000,
        currentPriceJpy: 1200,
      ),
      _asset(
        id: 'asset-2',
        ticker: 'BTC',
        quantity: 0.5,
        buyPriceJpy: 9000000,
        assetType: InvestmentAssetType.crypto,
      ),
    ]);

    await _pumpPanel(tester, repository: repository, userId: 'user-1');

    expect(find.text('AAPL'), findsOne);
    expect(find.text('¥2,400'), findsWidgets);
    expect(find.text('+¥400'), findsOne);
    expect(find.text('+20.0%'), findsOne);
    expect(find.text('取得額（評価済）'), findsOne);
    expect(find.text('¥2,000'), findsOne);
    expect(find.text('¥4,502,000'), findsNothing);
    expect(find.text('価格未取得'), findsOne);
    expect(find.text('1件'), findsOne);
    expect(tester.takeException(), isNull);
  });

  testWidgets('retries after a repository load error', (tester) async {
    final repository = _FakeInvestmentAssetRepository(const [])
      ..fetchError = Exception('temporary load failure');

    await _pumpPanel(tester, repository: repository, userId: 'user-1');

    expect(find.byKey(const Key('investment_asset_load_error')), findsOne);
    expect(repository.fetchCalls, 1);

    repository.fetchError = null;
    await tester.tap(find.byTooltip('再読み込み'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('investment_asset_empty')), findsOne);
    expect(repository.fetchCalls, 2);
  });

  testWidgets('retries a history error without hiding holdings', (
    tester,
  ) async {
    final repository = _FakeInvestmentAssetRepository([
      _asset(
        id: 'asset-1',
        ticker: 'AAPL',
        quantity: 2,
        buyPriceJpy: 1000,
        currentPriceJpy: 1200,
      ),
    ])
      ..historyFetchError = Exception('temporary history failure');

    await _pumpPanel(tester, repository: repository, userId: 'user-1');

    expect(find.text('AAPL'), findsOne);
    expect(find.byKey(const Key('investment_history_load_error')), findsOne);
    expect(repository.historyFetchCalls, 1);

    repository.historyFetchError = null;
    await tester.tap(find.byTooltip('推移を再読み込み'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('investment_history_empty')), findsOne);
    expect(repository.historyFetchCalls, 2);
  });

  testWidgets('filters portfolio history when the period changes', (
    tester,
  ) async {
    final repository = _FakeInvestmentAssetRepository(
      [
        _asset(
          id: 'asset-1',
          ticker: 'AAPL',
          quantity: 2,
          buyPriceJpy: 1000,
          currentPriceJpy: 1200,
        ),
      ],
      history: [
        _historyPoint(DateTime.utc(2024, 7, 21)),
        _historyPoint(DateTime.utc(2026, 7, 21)),
      ],
    );

    await _pumpPanel(
      tester,
      repository: repository,
      userId: 'user-1',
      now: () => DateTime.utc(2026, 7, 21),
    );

    expect(_marketSpotCount(tester), 1);
    await tester.tap(find.text('3年'));
    await tester.pumpAndSettle();
    expect(_marketSpotCount(tester), 2);
  });

  testWidgets('clears holdings when the user logs out', (tester) async {
    final repository = _FakeInvestmentAssetRepository([
      _asset(id: 'asset-1', ticker: 'AAPL', quantity: 2, buyPriceJpy: 1000),
    ]);

    await _pumpPanel(tester, repository: repository, userId: 'user-1');
    expect(find.text('AAPL'), findsOne);

    await _pumpPanel(tester, repository: repository, userId: null);

    expect(find.byKey(const Key('investment_asset_logged_out')), findsOne);
    expect(find.text('AAPL'), findsNothing);
    expect(repository.fetchCalls, 1);
  });

  testWidgets('clears cached price when the asset type changes', (
    tester,
  ) async {
    final repository = _FakeInvestmentAssetRepository([
      _asset(
        id: 'asset-1',
        ticker: 'AAPL',
        quantity: 2,
        buyPriceJpy: 1000,
        currentPriceJpy: 1200,
      ),
    ]);
    await _pumpPanel(tester, repository: repository, userId: 'user-1');

    await tester.tap(
      find.byKey(const ValueKey<String>('investment_asset_edit_asset-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('investment_asset_type_field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ETF').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('investment_asset_save')));
    await tester.pumpAndSettle();

    expect(repository.updateCalls, 1);
    expect(repository.lastUpdatedDraft?.assetType, InvestmentAssetType.etf);
    expect(repository.lastUpdatedDraft?.normalizedTicker, 'AAPL');
    expect(repository.lastUpdatedDraft?.currentPriceJpy, isNull);
    expect(repository.lastUpdatedDraft?.lastPricedAt, isNull);
  });

  testWidgets('shows form errors for blank, invalid, and negative values', (
    tester,
  ) async {
    final repository = _FakeInvestmentAssetRepository(const []);
    await _pumpPanel(tester, repository: repository, userId: 'user-1');

    await tester.tap(find.byKey(const Key('investment_asset_add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('investment_asset_save')));
    await tester.pump();

    expect(find.text('銘柄コードを入力してください。'), findsOne);
    expect(find.text('0より大きい数量を入力してください。'), findsOne);
    expect(find.text('0以上の取得価格を入力してください。'), findsOne);

    await tester.enterText(
      find.byKey(const Key('investment_asset_ticker_field')),
      '7203/T',
    );
    await tester.enterText(
      find.byKey(const Key('investment_asset_quantity_field')),
      '-1',
    );
    await tester.enterText(
      find.byKey(const Key('investment_asset_buy_price_field')),
      '-1',
    );
    await tester.tap(find.byKey(const Key('investment_asset_save')));
    await tester.pump();

    expect(
      find.text('銘柄コードは半角英数字と . _ : - を1〜32文字で入力してください。'),
      findsOne,
    );
    expect(find.text('0より大きい数量を入力してください。'), findsOne);
    expect(find.text('0以上の取得価格を入力してください。'), findsOne);
    expect(repository.createCalls, 0);
  });

  testWidgets('allows quantity edits for an unchanged legacy ticker', (
    tester,
  ) async {
    final repository = _FakeInvestmentAssetRepository([
      _asset(
        id: 'asset-legacy',
        ticker: 'BTC/JPY',
        quantity: 1,
        buyPriceJpy: 100,
        assetType: InvestmentAssetType.crypto,
      ),
    ]);
    await _pumpPanel(tester, repository: repository, userId: 'user-1');

    await tester.tap(
      find.byKey(const ValueKey<String>('investment_asset_edit_asset-legacy')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('investment_asset_quantity_field')),
      '2',
    );
    await tester.tap(find.byKey(const Key('investment_asset_save')));
    await tester.pumpAndSettle();

    expect(repository.updateCalls, 1);
    expect(repository.lastUpdatedDraft?.toUpdateMap()['ticker'], 'BTC/JPY');
  });

  testWidgets('adds, edits, and deletes an investment asset', (tester) async {
    final repository = _FakeInvestmentAssetRepository([
      _asset(
        id: 'asset-1',
        ticker: 'AAPL',
        quantity: 2,
        buyPriceJpy: 1000,
        currentPriceJpy: 1200,
      ),
    ]);
    await _pumpPanel(tester, repository: repository, userId: 'user-1');

    await tester.tap(find.byKey(const Key('investment_asset_add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('investment_asset_ticker_field')),
      'btc',
    );
    await tester.enterText(
      find.byKey(const Key('investment_asset_quantity_field')),
      '0.5',
    );
    await tester.enterText(
      find.byKey(const Key('investment_asset_buy_price_field')),
      '9000000',
    );
    await tester.tap(find.byKey(const Key('investment_asset_save')));
    await tester.pumpAndSettle();

    expect(repository.createCalls, 1);
    expect(repository.lastCreatedDraft?.normalizedTicker, 'BTC');
    expect(find.text('BTC'), findsOne);
    expect(find.text('未取得'), findsWidgets);

    await tester.tap(
      find.byKey(const ValueKey<String>('investment_asset_edit_asset-1')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('investment_asset_quantity_field')),
      '3',
    );
    await tester.tap(find.byKey(const Key('investment_asset_save')));
    await tester.pumpAndSettle();

    expect(repository.updateCalls, 1);
    expect(repository.lastUpdatedDraft?.quantity, 3);
    expect(repository.lastUpdatedDraft?.currentPriceJpy, 1200);
    expect(repository.lastUpdatedDraft?.lastPricedAt, isNotNull);

    await tester.tap(
      find.byKey(const ValueKey<String>('investment_asset_edit_asset-1')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('investment_asset_ticker_field')),
      '7203',
    );
    await tester.tap(find.byKey(const Key('investment_asset_save')));
    await tester.pumpAndSettle();

    expect(repository.updateCalls, 2);
    expect(repository.lastUpdatedDraft?.normalizedTicker, '7203');
    expect(repository.lastUpdatedDraft?.currentPriceJpy, isNull);
    expect(repository.lastUpdatedDraft?.lastPricedAt, isNull);
    expect(find.text('7203'), findsOne);

    await tester.tap(
      find.byKey(const ValueKey<String>('investment_asset_delete_asset-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('investment_asset_delete_confirm')));
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 1);
    expect(repository.historyFetchCalls, 5);
    expect(
      find.byKey(const ValueKey<String>('investment_asset_asset-1')),
      findsNothing,
    );
    expect(find.text('BTC'), findsOne);
  });

  testWidgets('previews CSV and skips an existing ticker by default', (
    tester,
  ) async {
    final repository = _FakeInvestmentAssetRepository([
      _asset(id: 'asset-aapl', ticker: 'AAPL', quantity: 1, buyPriceJpy: 10000),
    ]);
    final csv = Uint8List.fromList(
      utf8.encode('''
銘柄,数量,取得単価,現在値
AAPL Apple,3,16000,19000
MSFT Microsoft,4,20000,22000
'''),
    );
    await _pumpPanel(
      tester,
      repository: repository,
      userId: 'user-1',
      csvBytesPicker: () async => csv,
    );

    await tester.tap(find.byKey(const Key('investment_asset_csv_import')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('investment_csv_preview_dialog')), findsOne);
    expect(find.text('SBI証券 CSVプレビュー'), findsOne);
    expect(find.textContaining('新規1・更新0・スキップ1'), findsOne);

    await tester.tap(find.byKey(const Key('investment_csv_import_confirm')));
    await tester.pumpAndSettle();

    expect(repository.createCalls, 1);
    expect(repository.updateCalls, 0);
    expect(repository.lastCreatedDraft?.normalizedTicker, 'MSFT');
    expect(find.text('MSFT'), findsOne);
  });

  testWidgets('updates an existing ticker when update policy is selected', (
    tester,
  ) async {
    final repository = _FakeInvestmentAssetRepository([
      _asset(id: 'asset-aapl', ticker: 'AAPL', quantity: 1, buyPriceJpy: 10000),
    ]);
    final csv = Uint8List.fromList(
      utf8.encode('''
銘柄,数量,取得単価,現在値
AAPL Apple,3,16000,19000
'''),
    );
    await _pumpPanel(
      tester,
      repository: repository,
      userId: 'user-1',
      csvBytesPicker: () async => csv,
    );

    await tester.tap(find.byKey(const Key('investment_asset_csv_import')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('更新'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('新規0・更新1・スキップ0'), findsOne);
    await tester.tap(find.byKey(const Key('investment_csv_import_confirm')));
    await tester.pumpAndSettle();

    expect(repository.createCalls, 0);
    expect(repository.updateCalls, 1);
    expect(repository.lastUpdatedDraft?.normalizedTicker, 'AAPL');
    expect(repository.lastUpdatedDraft?.quantity, 3);
    expect(repository.lastUpdatedDraft?.buyPriceJpy, 16000);
  });
}

Future<void> _pumpPanel(
  WidgetTester tester, {
  required InvestmentAssetRepository repository,
  required String? userId,
  DateTime Function()? now,
  InvestmentCsvBytesPicker? csvBytesPicker,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(
            width: 520,
            child: InvestmentAssetManagementPanel(
              repository: repository,
              userId: userId,
              now: now,
              csvBytesPicker: csvBytesPicker,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

int _marketSpotCount(WidgetTester tester) {
  final chart = tester.widget<LineChart>(find.byType(LineChart));
  return chart.data.lineBarsData.first.spots.length;
}

InvestmentAsset _asset({
  required String id,
  required String ticker,
  required double quantity,
  required double buyPriceJpy,
  InvestmentAssetType assetType = InvestmentAssetType.stock,
  double? currentPriceJpy,
}) {
  return InvestmentAsset(
    id: id,
    userId: 'user-1',
    assetType: assetType,
    ticker: ticker,
    quantity: quantity,
    buyPriceJpy: buyPriceJpy,
    buyDate: DateTime.utc(2026, 1, 2),
    currentPriceJpy: currentPriceJpy,
    lastPricedAt: currentPriceJpy == null ? null : DateTime.utc(2026, 7, 20, 3),
    createdAt: DateTime.utc(2026, 1, 2),
    updatedAt: DateTime.utc(2026, 7, 20),
  );
}

class _FakeInvestmentAssetRepository implements InvestmentAssetRepository {
  _FakeInvestmentAssetRepository(
    Iterable<InvestmentAsset> seed, {
    Iterable<InvestmentPortfolioHistoryPoint> history = const [],
  })  : assets = seed.toList(),
        history = history.toList();

  final List<InvestmentAsset> assets;
  final List<InvestmentPortfolioHistoryPoint> history;
  int fetchCalls = 0;
  int createCalls = 0;
  int updateCalls = 0;
  int deleteCalls = 0;
  int historyFetchCalls = 0;
  InvestmentAssetDraft? lastCreatedDraft;
  InvestmentAssetDraft? lastUpdatedDraft;
  Exception? fetchError;
  Exception? historyFetchError;

  @override
  Future<List<InvestmentAsset>> fetchByUser({required String userId}) async {
    fetchCalls++;
    final error = fetchError;
    if (error != null) throw error;
    return List<InvestmentAsset>.from(assets);
  }

  @override
  Future<List<InvestmentPortfolioHistoryPoint>> fetchPortfolioHistory({
    required String userId,
  }) async {
    historyFetchCalls++;
    final error = historyFetchError;
    if (error != null) throw error;
    return List<InvestmentPortfolioHistoryPoint>.from(history);
  }

  @override
  Future<InvestmentAsset> create({
    required String userId,
    required InvestmentAssetDraft draft,
  }) async {
    createCalls++;
    lastCreatedDraft = draft;
    final asset = _fromDraft(id: 'asset-created', userId: userId, draft: draft);
    assets.add(asset);
    return asset;
  }

  @override
  Future<InvestmentAsset> update({
    required String userId,
    required String assetId,
    required InvestmentAssetDraft draft,
  }) async {
    updateCalls++;
    lastUpdatedDraft = draft;
    final updated = _fromDraft(id: assetId, userId: userId, draft: draft);
    final index = assets.indexWhere((asset) => asset.id == assetId);
    assets[index] = updated;
    return updated;
  }

  @override
  Future<void> delete({required String userId, required String assetId}) async {
    deleteCalls++;
    assets.removeWhere((asset) => asset.id == assetId);
  }
}

InvestmentPortfolioHistoryPoint _historyPoint(DateTime recordedAt) {
  return InvestmentPortfolioHistoryPoint(
    recordedAt: recordedAt,
    marketValueJpy: 2400,
    acquisitionCostJpy: 2000,
    pricedAssetCount: 1,
    unpricedAssetCount: 0,
  );
}

InvestmentAsset _fromDraft({
  required String id,
  required String userId,
  required InvestmentAssetDraft draft,
}) {
  return InvestmentAsset(
    id: id,
    userId: userId,
    assetType: draft.assetType,
    ticker: draft.normalizedTicker,
    quantity: draft.quantity,
    buyPriceJpy: draft.buyPriceJpy,
    buyDate: draft.buyDate,
    currentPriceJpy: draft.currentPriceJpy,
    lastPricedAt: draft.lastPricedAt,
    createdAt: DateTime.utc(2026, 7, 20),
    updatedAt: DateTime.utc(2026, 7, 20),
  );
}
