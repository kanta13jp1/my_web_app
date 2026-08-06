# GitHub Code Quality が 7/20 に GA — 個人・小規模チームは「自分株式会社」で無料で同等以上を実現できる

published: false
topics: [GitHub, Flutter, 個人開発, コード品質, CodeQuality]
type: tech

---

## はじめに

2026 年 7 月 20 日、GitHub が **GitHub Code Quality** を一般提供 (GA) に移行します。
料金は **有効化リポジトリのアクティブコミッター 1 人あたり月額 $10 (+ AI 機能の従量課金)**。

主な機能はこうです:

- Organization 全体への一括展開
- Organization レベルの品質ダッシュボード
- ルールセット (rulesets) によるコードカバレッジの強制
- リポジトリ・Organization 単位の品質スコアリング
- 有効化・検出結果管理用 API

企業チームにとっては嬉しいリリースですが、**個人開発者・小規模チーム**には「$10/コミッター/月」の課金ハードルがあります。

この記事では、同等以上のコード品質管理を **GitHub Actions + Supabase Edge Functions + 自分株式会社** の組み合わせで**ゼロコスト**で実現する方法を紹介します。

---

## GitHub Code Quality GA で何が変わるか

| 機能 | GA 以前 | GA (7/20〜) |
|------|---------|------------|
| 利用資格 | パブリックプレビュー | 有料プラン ($10/コミッター/月) |
| スコープ | リポジトリ単位 | Organization 全体 |
| ダッシュボード | なし | Organization レベル品質ダッシュボード |
| API | なし | 有効化・検出結果管理 API |
| カバレッジ強制 | 手動 | ルールセット (rulesets) 対応 |

コード品質の**可視化・強制・API 化**がセットになった点は大きいですが、コミッター数が多い組織では月次コストが急増します。

---

## 個人・小規模チームが今すぐ使えるゼロコスト代替

### 1. flutter analyze + GitHub Actions で 0 エラー強制

```yaml
# .github/workflows/analyze.yml
name: Flutter Analyze
on: [push, pull_request]
jobs:
  analyze:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter analyze --fatal-infos
```

`--fatal-infos` を付けると info レベルも CI を落とすため、**ルールセットによるカバレッジ強制**と同等の効果が得られます。

### 2. カバレッジをダッシュボード化

```yaml
      - run: flutter test --coverage
      - uses: VeryGoodOpenSource/very_good_coverage@v2
        with:
          min_coverage: 80
```

Codecov や Coveralls を使えば Organization ダッシュボード相当の可視化が無料で実現できます。

### 3. Supabase Edge Functions で品質スコアを蓄積

```typescript
// supabase/functions/code-quality-snapshot/index.ts
Deno.serve(async (req) => {
  const { coverage, analyzeErrors, testCount } = await req.json();
  const score = Math.max(0, 100 - analyzeErrors * 5) * (coverage / 100);
  await supabase.from('code_quality_snapshots').insert({
    score,
    coverage,
    analyze_errors: analyzeErrors,
    test_count: testCount,
    created_at: new Date().toISOString(),
  });
  return new Response(JSON.stringify({ score }));
});
```

**毎 push のスコアを Supabase に蓄積** → 自分株式会社の経営コックピットで時系列グラフ化、という流れで GitHub Code Quality ダッシュボードの代替が作れます。

### 4. 自分株式会社の KPI として管理

自分株式会社では「開発部 KPI」として `flutter analyze エラー数 = 0` を毎日チェックしています。
Slack 連携で「本日のコード品質スコア」を朝会チャンネルに自動投稿することで、小規模チームの品質文化を維持しています。

---

## GitHub Code Quality GA を選ぶべき人・選ばなくていい人

| 状況 | 判断 |
|------|------|
| 10+ コミッターの組織 | Code Quality GA を検討 (ダッシュボード・API の価値大) |
| 1〜5 人の個人・スタートアップ | GHA + Codecov + Supabase でゼロコスト代替可 |
| OSS プロジェクト | GitHub Actions は無料枠で対応可能 |
| Flutter/Dart プロジェクト | `flutter analyze` が最強の静的解析 — Code Quality 以上 |

---

## まとめ

GitHub Code Quality の GA は企業チームにとって価値ある投資ですが、個人・小規模チームは **GitHub Actions + flutter analyze + Supabase + 自分株式会社** の組み合わせで同等以上をゼロコストで実現できます。

7/20 の GA を機に、自分のコード品質管理フローを見直してみてください。

---

## 関連リンク

- [自分株式会社 (個人経営 OS)](https://my-web-app-b67f4.web.app/)
- [GitHub Code Quality GA 発表 (GitHub Blog)](https://github.blog/changelog/month/07-2026/)
- [flutter analyze 公式ドキュメント](https://dart.dev/tools/dart-analyze)
- [Supabase Edge Functions](https://supabase.com/docs/guides/functions)

---

*投稿先: Zenn / Qiita*
*作成: 2026-07-19 (自分株式会社 Claude Schedule)*
