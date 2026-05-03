---
title: "Dart パッケージを pub.dev に公開する — pubspec・dartdoc・GitHub Actions の完全ガイド"
tags: Dart,Flutter,programming,個人開発
published: true
---

「社内で便利なユーティリティを作ったので pub.dev に公開したい」「オープンソースで貢献したい」という方向けに、パッケージ設計から自動公開 CI まで一通りの手順を解説します。適切に整備されたパッケージは、あなたの技術ブランド向上にもつながります。

## 1. パッケージの構成

```text
my_package/
  lib/
    my_package.dart          # メインエクスポートファイル
    src/
      feature_a.dart         # 実装（直接 import させない）
      feature_b.dart
  example/
    lib/
      main.dart              # 使用例（pub.dev に表示される）
  test/
    feature_a_test.dart
    feature_b_test.dart
  CHANGELOG.md               # 必須
  LICENSE                    # 必須（OSS ライセンス）
  README.md                  # pub.dev のトップページ
  pubspec.yaml               # メタデータ
```

## 2. pubspec.yaml の設定

```yaml
name: my_flutter_utils
description: >-
  A collection of Flutter utilities for common UI patterns,
  including debounced search, infinite scroll, and form validation.
version: 1.0.0
homepage: https://github.com/your-org/my_flutter_utils
repository: https://github.com/your-org/my_flutter_utils
issue_tracker: https://github.com/your-org/my_flutter_utils/issues

# 対応プラットフォームを明示（pub.dev スコアに影響）
platforms:
  android:
  ios:
  linux:
  macos:
  web:
  windows:

environment:
  sdk: '>=3.3.0 <4.0.0'
  flutter: '>=3.19.0'

dependencies:
  flutter:
    sdk: flutter

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  # パッケージ公開前チェックに使用
  pana: ^0.21.0
```

### バージョニング規則 (Semantic Versioning)

```text
MAJOR.MINOR.PATCH  例: 2.1.3

MAJOR: 破壊的変更（API の削除・変更）
MINOR: 後方互換の新機能追加
PATCH: バグ修正・内部改善

プレリリース:
  1.0.0-beta.1   ベータ版
  1.0.0-rc.1     リリース候補
  2.0.0-dev.1    開発版

パッケージ制約:
  ^1.2.3  = >=1.2.3 <2.0.0  (推奨 — MAJOR 固定)
  >=1.0.0 <3.0.0             (MAJOR 2 つまで対応)
```

## 3. dartdoc コメントの書き方

pub.dev のスコアは API ドキュメントの充実度に大きく依存します。

```dart
/// HTTP リクエストをデバウンスするサービス。
///
/// 連続した呼び出しが [duration] 以内に発生した場合、最後の呼び出しのみ実行します。
/// 検索フィールドの入力ごとに API を叩くような場面で有効です。
///
/// ```dart
/// final debounced = DebouncedSearchService(
///   duration: const Duration(milliseconds: 300),
///   onSearch: (query) async {
///     final results = await api.search(query);
///     print('Found: ${results.length} items');
///   },
/// );
///
/// // ユーザーが入力するたびに呼び出す
/// debounced.search('flutter');
/// debounced.search('flutter web'); // これだけ実行される
/// ```
///
/// See also:
///   - [ThrottledSearchService] — 最初の呼び出しを即時実行したい場合
///   - [CachedSearchService] — 結果をキャッシュしたい場合
class DebouncedSearchService {
  /// デバウンス遅延時間。デフォルトは 300ms。
  final Duration duration;

  /// 検索クエリを受け取る非同期コールバック。
  ///
  /// このコールバック内で例外が発生した場合、[onError] で処理されます。
  final Future<void> Function(String query) onSearch;

  /// エラーハンドラ（省略可能）。
  final void Function(Object error, StackTrace stack)? onError;

  Timer? _timer;

  /// [DebouncedSearchService] を作成します。
  ///
  /// [duration] と [onSearch] は必須です。
  DebouncedSearchService({
    this.duration = const Duration(milliseconds: 300),
    required this.onSearch,
    this.onError,
  });

  /// 検索をスケジュールします。
  ///
  /// [duration] 以内に再度呼ばれると、前のスケジュールはキャンセルされます。
  void search(String query) {
    _timer?.cancel();
    _timer = Timer(duration, () async {
      try {
        await onSearch(query);
      } catch (e, s) {
        onError?.call(e, s);
      }
    });
  }

  /// タイマーをキャンセルしてリソースを解放します。
  ///
  /// [dispose] 後は [search] を呼ばないでください。
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
```

### メインエクスポートファイル

```dart
// lib/my_flutter_utils.dart
/// Flutter 向けユーティリティコレクション。
///
/// ## 主な機能
///
/// - **Search**: [DebouncedSearchService], [ThrottledSearchService]
/// - **Forms**: [EmailValidator], [PasswordStrengthMeter]
/// - **Scroll**: [InfiniteScrollController], [PaginatedListView]
///
/// ## クイックスタート
///
/// ```dart
/// import 'package:my_flutter_utils/my_flutter_utils.dart';
///
/// final search = DebouncedSearchService(
///   onSearch: (q) async { /* ... */ },
/// );
/// ```
library my_flutter_utils;

export 'src/search/debounced_search_service.dart';
export 'src/search/throttled_search_service.dart';
export 'src/forms/email_validator.dart';
export 'src/forms/password_strength_meter.dart';
export 'src/scroll/infinite_scroll_controller.dart';
export 'src/scroll/paginated_list_view.dart';
```

## 4. テストの書き方

```dart
// test/debounced_search_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flutter_utils/my_flutter_utils.dart';

void main() {
  group('DebouncedSearchService', () {
    late DebouncedSearchService service;
    final calls = <String>[];

    setUp(() {
      calls.clear();
      service = DebouncedSearchService(
        duration: const Duration(milliseconds: 100),
        onSearch: (q) async => calls.add(q),
      );
    });

    tearDown(() => service.dispose());

    test('calls onSearch after delay', () async {
      service.search('hello');
      expect(calls, isEmpty); // まだ呼ばれていない

      await Future.delayed(const Duration(milliseconds: 150));
      expect(calls, ['hello']);
    });

    test('debounces rapid calls', () async {
      service.search('h');
      service.search('he');
      service.search('hel');
      service.search('hell');
      service.search('hello');

      await Future.delayed(const Duration(milliseconds: 150));
      expect(calls, ['hello']); // 最後のみ
    });

    test('does not call after dispose', () async {
      service.search('hello');
      service.dispose();

      await Future.delayed(const Duration(milliseconds: 150));
      expect(calls, isEmpty);
    });

    test('handles onSearch errors via onError', () async {
      Object? caughtError;
      final errorService = DebouncedSearchService(
        onSearch: (_) async => throw Exception('test error'),
        onError: (e, _) => caughtError = e,
      );

      errorService.search('query');
      await Future.delayed(const Duration(milliseconds: 350));

      expect(caughtError, isA<Exception>());
      errorService.dispose();
    });
  });
}
```

## 5. GitHub Actions で自動公開

### CHANGELOG.md の形式

```markdown
## 1.1.0

- `DebouncedSearchService`: `onError` コールバックを追加
- `EmailValidator`: 国際化ドメイン (IDN) 対応
- バグ修正: `InfiniteScrollController` のメモリリーク

## 1.0.1

- `PaginatedListView`: ローディングインジケーターのスタイル改善

## 1.0.0

- 初回リリース
```

### pub-publish.yml

```yaml
# .github/workflows/pub-publish.yml
name: Publish to pub.dev

on:
  push:
    tags:
      - 'v[0-9]+.[0-9]+.[0-9]+*'   # v1.0.0, v2.1.0-beta.1 など

permissions:
  id-token: write  # OIDC 認証に必要（pub.dev 公式推奨）

jobs:
  test:
    name: Test & Analyze
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: dart-lang/setup-dart@v1
        with:
          sdk: stable

      - name: Install dependencies
        run: dart pub get

      - name: Verify formatting
        run: dart format --output=none --set-exit-if-changed .

      - name: Analyze
        run: dart analyze --fatal-infos

      - name: Run tests
        run: dart test --coverage=coverage

      - name: Check coverage
        run: |
          dart pub global activate coverage
          dart pub global run coverage:format_coverage \
            --lcov --in=coverage --out=coverage/lcov.info \
            --report-on=lib
          # カバレッジ 80% 未満なら失敗
          dart pub global activate dart_coveralls
          dart_coveralls report coverage/lcov.info --min-coverage 80

  score-check:
    name: pub.dev Score Check
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1
        with:
          sdk: stable
      - run: dart pub get
      - name: Run pana
        run: |
          dart pub global activate pana
          dart pub global run pana --no-warning . 2>&1 | tee pana-output.txt
          # スコア 120pt 未満（140pt 満点）なら警告
          score=$(grep -oP 'Score: \K[0-9]+' pana-output.txt | head -1)
          echo "pub.dev score: $score / 140"
          if [ "$score" -lt 120 ]; then
            echo "::warning::pub.dev score is below 120: $score"
          fi

  publish:
    name: Publish
    needs: [test, score-check]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: dart-lang/setup-dart@v1
        with:
          sdk: stable

      - name: Install dependencies
        run: dart pub get

      - name: Publish (dry-run first)
        run: dart pub publish --dry-run

      - name: Publish to pub.dev
        run: dart pub publish --force
        # OIDC 認証: secrets 不要。dart-lang/setup-dart が処理
```

### タグを打って公開

```bash
# pubspec.yaml のバージョンを更新してからコミット
git add pubspec.yaml CHANGELOG.md
git commit -m "chore: release v1.1.0"

# タグを打つ → GHA が自動起動
git tag v1.1.0
git push origin main --tags
```

## 6. pub.dev スコアを上げるチェックリスト

| チェック項目 | スコア比重 | 対策 |
|------------|-----------|------|
| `dart analyze` 0 エラー | 高 | flutter_lints + strict mode |
| API ドキュメント率 > 20% | 高 | dartdoc コメントを全 public API に |
| テストカバレッジ | 中 | `flutter test --coverage` |
| LICENSE ファイル | 必須 | MIT / BSD-3 推奨 |
| CHANGELOG.md | 必須 | keep a changelog 形式 |
| README.md (英語) | 高 | バッジ + クイックスタート |
| example/ フォルダ | 高 | `dart pub publish` で表示 |
| `flutter pub publish --dry-run` パス | 必須 | 公開前に必ず確認 |

## まとめ

Dart パッケージを高品質で公開するための最重要ポイント:

1. **pubspec.yaml** — platforms・SDK range・description を正確に設定
2. **dartdoc** — 全 public API にコードサンプル付きコメント
3. **テスト** — カバレッジ 80% 以上 + エッジケース網羅
4. **CI** — pana スコアチェック + OIDC 自動公開

pub.dev に公開されたパッケージはあなたのポートフォリオにもなります。まず小さなユーティリティから始めてみましょう。
