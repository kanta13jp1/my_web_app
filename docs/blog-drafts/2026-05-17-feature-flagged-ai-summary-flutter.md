---
title: "Flutter Web で AI 機能を「Feature Flag + Deterministic Fallback」で安全に出す"
tags: Flutter,AI,FeatureFlag,Supabase,個人開発
published: true
---

# Flutter Web で AI 機能を「Feature Flag + Deterministic Fallback」で安全に出す

## なぜ AI 機能は普通にリリースできないのか

AI を組み込んだ機能は、普通の機能と違って本番に出すリスクが高い。

- **コストが読めない**: ユーザー数 × プロンプト長 × API 単価 = 月末まで分からない
- **品質がブレる**: 同じ入力でも返答が変わる。エッジケースで日本語が壊れる
- **依存先が落ちる**: DeepInfra・Anthropic・OpenAI のどれか 1 つが落ちただけで UI が真っ白
- **A/B で測れない**: 「AI ありの方が体験が良い」をユーザー数 4 人の段階で判定できない

自分株式会社の資産管理ページに AI サマリーを足したとき、これら 4 つを同時に満たす方法を探した。結論は **`--dart-define` feature flag + deterministic fallback** の組み合わせだった。

---

## パターン: Status enum で 3 状態を素直に表現

最小限のコードで「フラグ off」「AI 成功」「AI 失敗 → fallback」の 3 状態を作る。

```dart
enum AssetManagementAiSummaryStatus { disabled, aiGenerated, fallback }

class AssetManagementAiSummaryFeatureFlag {
  static const String dartDefineName = 'ASSET_MANAGEMENT_AI_SUMMARY_ENABLED';

  static const bool enabled = bool.fromEnvironment(
    dartDefineName,
    defaultValue: false,
  );
}
```

ポイントは:

1. **`bool.fromEnvironment`**: ビルド時に値が確定する。本番ビルドだけ ON にできる
2. **`defaultValue: false`**: フラグを忘れたら自動で OFF。安全側に倒れる
3. **enum 3 値**: 「失敗を fallback で吸収した」を log と UI 両方で区別できる

---

## パターン: AI 呼び出しの前に fallback を作る

これが今回いちばん効いた設計判断だった。

```dart
Future<AssetManagementAiSummaryResult> generateSummary({
  required AssetManagementInsightReport report,
}) async {
  final payload = buildPayload(report);
  final fallback = buildDeterministicSummary(report);  // ★ AI 呼び出し前に作る

  if (!_aiEnabled) {
    return AssetManagementAiSummaryResult(
      status: AssetManagementAiSummaryStatus.disabled,
      text: fallback,                                    // ★ 同じ fallback を返す
      ...
    );
  }

  try {
    final response = await _chatService.sendProviderChat(...);
    return /* aiGenerated */;
  } catch (e) {
    return /* fallback with status: fallback, errorMessage: e */;
  }
}
```

**「AI が落ちても fallback は必ず返る」を関数の型レベルで保証する** のが核心。

`text` フィールドは常に non-nullable。UI 側は `AsyncSnapshot` の error 分岐を書く必要すらない。AI が爆発しても、ユーザーには deterministic な要約が表示される。

---

## パターン: テストで feature flag を強制 ON / OFF

flag を `bool.fromEnvironment` だけで書くとテストできない。コンストラクタ引数を 1 行足す。

```dart
AssetManagementAiSummaryService({
  bool aiEnabled = AssetManagementAiSummaryFeatureFlag.enabled,
  ...
}) : _aiEnabled = aiEnabled, ...;
```

これでテストは:

```dart
test('flag off → status disabled', () async {
  final svc = AssetManagementAiSummaryService(aiEnabled: false);
  final result = await svc.generateSummary(report: r);
  expect(result.status, AssetManagementAiSummaryStatus.disabled);
});

test('flag on but AI throws → status fallback', () async {
  final svc = AssetManagementAiSummaryService(
    aiEnabled: true,
    chatService: _ThrowingChatService(),
  );
  final result = await svc.generateSummary(report: r);
  expect(result.status, AssetManagementAiSummaryStatus.fallback);
  expect(result.text, isNotEmpty);  // fallback は必ず空でない
});
```

**3 状態 × 入力パターン** で組み合わせ爆発しないのも enum の利点。

---

## パターン: 本番デプロイは「flag OFF で 1 日 → ON で限定公開」

GitHub Actions で `--dart-define=ASSET_MANAGEMENT_AI_SUMMARY_ENABLED=false` を最初に出す。

1. **Day 0**: 全環境に flag OFF でデプロイ。fallback だけ動くことを確認
2. **Day 1**: dev/staging だけ flag ON。プロンプト品質と latency を観測
3. **Day 2**: 本番 ON。コスト計測 cron が予算を超えたら自動で OFF に戻す GHA を併設

`bool.fromEnvironment` がビルド時固定なので、flag 切り替えは再デプロイが必要。これが「軽率に ON にできない」セーフティとして働く。

---

## なぜ runtime flag (Supabase config table) を使わなかったか

Runtime flag (= ユーザーが管理画面で ON/OFF) も検討した。が、**個人開発で 4 人ユーザーの段階では不要** と判断した。

- 緊急停止は GHA からの再デプロイ (~3 分) で十分
- runtime flag は「DB クエリ → cache → invalidation」のレイヤーが増える
- A/B テストも母数 4 人では意味がない

スケールしたら `Supabase config table + 1 時間 cache` に切り替える予定だが、それは PMF してから。

---

## まとめ — AI 機能リリースの 4 段防衛

| 層 | 仕組み | 守るもの |
|---|---|---|
| 1. Feature flag | `bool.fromEnvironment` | 「うっかり本番 ON」事故 |
| 2. Deterministic fallback | AI 呼び出し前に必ず作る | API 障害時の UI 真っ白 |
| 3. Status enum 3 値 | `disabled / aiGenerated / fallback` | 「成功と fallback の区別」が消える |
| 4. テスト ON/OFF 注入 | コンストラクタ引数 | flag 状態のリグレッション |

この 4 層がそろえば、AI 機能は「普通の機能」と同じ気軽さでリリースできる。

自分株式会社では今回の資産管理 AI サマリーをこの方式で 1 commit (487 行) で本番に出した。次は同じ方式で「日次 KPI AI コーチ」を出す予定。

---

## 参考リンク

- 自分株式会社 (本番): <https://my-web-app-b67f4.web.app/>
- 該当 PR: feature-flagged asset management AI summaries (#2459)
- 関連記事: 「Notion データベースの限界と回避策」 (2026-05-16)
