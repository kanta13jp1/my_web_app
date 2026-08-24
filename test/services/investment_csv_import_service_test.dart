import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/investment_asset.dart';
import 'package:my_web_app/services/investment_csv_import_service.dart';

void main() {
  const service = InvestmentCsvImportService();

  test('maps and consolidates Rakuten holdings rows by ticker', () {
    const csv = '''
\ufeff銘柄コード,銘柄名,商品種類,保有数量[株/口],平均取得価額[円],現在値[円]
7203,トヨタ自動車,国内株式,100,"2,000","2,500"
7203,トヨタ自動車,国内株式,50,"3,000","2,500"
1343,NEXT FUNDS 東証REIT指数連動型上場投信,REIT,10,"1,800","1,900"
''';

    final result = service.parse(csv);

    expect(result.broker, InvestmentCsvBroker.rakuten);
    expect(result.inputRowCount, 3);
    expect(result.issues, isEmpty);
    expect(result.rows, hasLength(2));
    final reit = result.rows.first;
    expect(reit.draft.normalizedTicker, '1343');
    expect(reit.draft.assetType, InvestmentAssetType.reit);
    final toyota = result.rows.last;
    expect(toyota.draft.normalizedTicker, '7203');
    expect(toyota.draft.quantity, 150);
    expect(toyota.draft.buyPriceJpy, closeTo(2333.333333, 0.000001));
    expect(toyota.draft.currentPriceJpy, 2500);
    expect(toyota.mergedRowCount, 2);
  });

  test(
    'maps SBI holdings and reports invalid rows without failing preview',
    () {
      const csv = '''
銘柄,商品分類,数量,取得単価,現在値
AAPL Apple Inc.,外国株式,2,15000,18000
9432 日本電信電話,国内株式,0,170,180
コードなし,国内株式,10,100,110
''';

      final result = service.parse(csv);

      expect(result.broker, InvestmentCsvBroker.sbi);
      expect(result.rows, hasLength(1));
      expect(result.rows.single.draft.normalizedTicker, 'AAPL');
      expect(result.rows.single.draft.quantity, 2);
      expect(result.rows.single.draft.buyPriceJpy, 15000);
      expect(result.issues, hasLength(2));
      expect(result.issues.first.lineNumber, 3);
    },
  );

  test(
    'builds skip and update plans using normalized ticker as natural key',
    () {
      final parsed = service.parse('''
銘柄,数量,取得単価,現在値
aapl Apple,3,16000,19000
MSFT Microsoft,4,20000,22000
''');
      final existing = <InvestmentAsset>[
        _asset(id: 'asset-aapl', ticker: 'AAPL', quantity: 1),
      ];

      final skip = service.buildPlan(
        parsed: parsed,
        existingAssets: existing,
        duplicatePolicy: InvestmentCsvDuplicatePolicy.skip,
      );
      expect(skip.creates.single.normalizedTicker, 'MSFT');
      expect(skip.updates, isEmpty);
      expect(skip.skippedDuplicates, 1);

      final update = service.buildPlan(
        parsed: parsed,
        existingAssets: existing,
        duplicatePolicy: InvestmentCsvDuplicatePolicy.update,
      );
      expect(update.creates.single.normalizedTicker, 'MSFT');
      expect(update.updates.single.asset.id, 'asset-aapl');
      expect(update.updates.single.draft.quantity, 3);
      expect(update.skippedDuplicates, 0);
    },
  );

  test('update preserves optional existing values omitted by the CSV', () {
    final parsed = service.parse('''
銘柄,数量,取得単価
AAPL Apple,3,16000
''');
    final existing = _asset(
      id: 'asset-aapl',
      ticker: 'AAPL',
      quantity: 1,
      assetType: InvestmentAssetType.etf,
      buyDate: DateTime.utc(2025, 4, 1),
      currentPriceJpy: 19000,
      lastPricedAt: DateTime.utc(2026, 8, 1),
    );

    final plan = service.buildPlan(
      parsed: parsed,
      existingAssets: <InvestmentAsset>[existing],
      duplicatePolicy: InvestmentCsvDuplicatePolicy.update,
    );

    final draft = plan.updates.single.draft;
    expect(draft.assetType, InvestmentAssetType.etf);
    expect(draft.buyDate, DateTime.utc(2025, 4, 1));
    expect(draft.currentPriceJpy, 19000);
    expect(draft.lastPricedAt, DateTime.utc(2026, 8, 1));
  });

  test('rejects a CSV without a Rakuten or SBI holdings signature', () {
    expect(
      () => service.parse('date,amount\n2026-01-01,100'),
      throwsFormatException,
    );
    expect(
      InvestmentCsvImportService.looksLikeCsv('date,amount\n2026-01-01,100'),
      isFalse,
    );
  });
}

InvestmentAsset _asset({
  required String id,
  required String ticker,
  required double quantity,
  InvestmentAssetType assetType = InvestmentAssetType.stock,
  DateTime? buyDate,
  double? currentPriceJpy,
  DateTime? lastPricedAt,
}) {
  return InvestmentAsset(
    id: id,
    userId: 'user-1',
    assetType: assetType,
    ticker: ticker,
    quantity: quantity,
    buyPriceJpy: 10000,
    buyDate: buyDate,
    currentPriceJpy: currentPriceJpy,
    lastPricedAt: lastPricedAt,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}
