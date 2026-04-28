---
title: "Flutter Golden Tests — スクリーンショットで UI リグレッションを防ぐ"
tags: flutter,AI,個人開発,programming
published: true
---

# Flutter Golden Tests — スクリーンショットで UI リグレッションを防ぐ

「デザインが壊れた」をコードで検出する。Golden Tests はスクリーンショット差分テスト。

## 基本的な Golden Test

```dart
// test/golden/task_card_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/widgets/task_card.dart';

void main() {
  testWidgets('TaskCard golden test', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: TaskCard(
            task: Task(
              id: '1',
              title: '買い物リストを作る',
              completed: false,
              priority: Priority.high,
            ),
          ),
        ),
      ),
    );

    await expectLater(
      find.byType(TaskCard),
      matchesGoldenFile('goldens/task_card.png'),
    );
  });
}
```

```bash
# 初回: golden ファイルを生成
flutter test --update-goldens test/golden/

# 以降: 差分チェック (CI で実行)
flutter test test/golden/
```

## ダークモード対応

```dart
testWidgets('TaskCard dark mode golden', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: TaskCard(task: _sampleTask),
      ),
    ),
  );

  await expectLater(
    find.byType(TaskCard),
    matchesGoldenFile('goldens/task_card_dark.png'),
  );
});
```

## フォントレンダリングの安定化

```dart
// テスト環境でフォントのアンチエイリアス差分を抑制
setUpAll(() async {
  // テスト用フォントの登録 (CI/ローカルで差分が出やすい)
  await loadAppFonts();
});

// tolerance で許容差を設定 (0.0〜1.0)
await expectLater(
  find.byType(TaskCard),
  matchesGoldenFile(
    'goldens/task_card.png',
    // skip: !Platform.isMacOS,  // OS依存差分を回避する場合
  ),
);
```

## CI での Golden 差分確認

```yaml
# .github/workflows/golden-test.yml
- name: Run Golden Tests
  run: flutter test test/golden/ --reporter compact

- name: Upload golden diffs on failure
  if: failure()
  uses: actions/upload-artifact@v4
  with:
    name: golden-failures
    path: test/golden/failures/
    # PR コメントに差分画像を自動添付
```

## まとめ

```
生成       → flutter test --update-goldens (初回 or 意図的変更時)
検証       → flutter test test/golden/ (CI で毎回)
ダーク対応 → theme 切り替えで golden ファイルを複数管理
CI 差分    → failures/ に差分画像を upload → PR でレビュー
```

Widget テストは「動作」、Golden テストは「見た目」。両方セットでリグレッションをゼロに。
