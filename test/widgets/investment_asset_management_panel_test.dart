import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/investment_asset.dart';
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
    ]);

    await _pumpPanel(tester, repository: repository, userId: 'user-1');

    expect(find.text('AAPL'), findsOne);
    expect(find.text('¥2,400'), findsWidgets);
    expect(find.text('+¥400'), findsOne);
    expect(find.text('+20.0%'), findsOne);
    expect(tester.takeException(), isNull);
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

    await tester.tap(
      find.byKey(const ValueKey<String>('investment_asset_delete_asset-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('investment_asset_delete_confirm')));
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 1);
    expect(
      find.byKey(const ValueKey<String>('investment_asset_asset-1')),
      findsNothing,
    );
    expect(find.text('BTC'), findsOne);
  });
}

Future<void> _pumpPanel(
  WidgetTester tester, {
  required InvestmentAssetRepository repository,
  required String? userId,
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
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

InvestmentAsset _asset({
  required String id,
  required String ticker,
  required double quantity,
  required double buyPriceJpy,
  double? currentPriceJpy,
}) {
  return InvestmentAsset(
    id: id,
    userId: 'user-1',
    assetType: InvestmentAssetType.stock,
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
  _FakeInvestmentAssetRepository(Iterable<InvestmentAsset> seed)
      : assets = seed.toList();

  final List<InvestmentAsset> assets;
  int fetchCalls = 0;
  int createCalls = 0;
  int updateCalls = 0;
  int deleteCalls = 0;
  InvestmentAssetDraft? lastCreatedDraft;
  InvestmentAssetDraft? lastUpdatedDraft;

  @override
  Future<List<InvestmentAsset>> fetchByUser({required String userId}) async {
    fetchCalls++;
    return List<InvestmentAsset>.from(assets);
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
