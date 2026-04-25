# Issue Fix Plan #514

- Issue: [[feature] アプリバージョンの画面表示 + 古いバージョン検出時の更新プロンプト](https://github.com/kanta13jp1/my_web_app/issues/514)
- Labels: enhancement,priority:high,flutter-web,pwa
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/24919485897

## Goal

[feature] アプリバージョンの画面表示 + 古いバージョン検出時の更新プロンプト

## Current Context

```text
## 背景・動機

ユーザーから「**現在のアプリのバージョンを画面で確認できるようにしたい**（更新が反映されたか分からない）」「**バージョンが古い場合は更新を促したい**」という要望あり。

実機 UAT でホーム / 経営コックピット / AI大学など主要画面を見たところ、現状どこにもアプリバージョンが表示されていない。GitHub Releases は自動で v1.0.1140 まで発行されているが、ユーザー側からは自分が今どのバージョンを使っているのか分からない = **PWA のキャッシュ由来で古いバージョンを掴み続けていても気付けない**。

## 既存インフラ（ここは手を入れずに活かせる）

`.github/workflows/deploy-prod.yml` が既に**ビルド時にバージョンを注入する仕組みを完備**していた:

- L69-81: `Generate version` ステップで最新タグから `1.0.1140` 形式を生成
- L327: `--build-name=${{ steps.version.outputs.version }}`
- L330: `--dart-define=APP_VERSION=${{ steps.version.outputs.version }}` ← **Dart から読めるが読んでいない**
- L361-364: `softprops/action-gh-release@v3` で GitHub Release 自動作成

`grep -rn APP_VERSION lib/` の結果 0 件。つまり `--dart-define` で渡された値が誰にも参照されていない状態。

## 実装プラン

### Phase 1: 現在バージョンの画面表示（最短）

**1-a. ビルド時バージョンを Dart 定数として参照する**

```dart
// lib/core/app_version.dart (新規)
class AppVersion {
  static const String value = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: 'dev',
  );
  static const String buildNumber = String.fromEnvironment(
    'BUILD_NUMBER',
    defaultValue: '0',
  );
}
```

deploy-prod.yml で既に `APP_VERSION` は `--dart-define` されているので **ワークフロー修正不要**。`BUILD_NUMBER` は `github.run_number` を L330 あたりに追加で足すだけ。

**1-b. 表示場所**

```

## Autonomous Repair Loop

1. Reproduce the smallest failing path for this issue.
2. Apply the minimum safe fix on this branch.
3. Let normal CI run on the draft PR.
4. If CI fails on mechanical issues, `ci-auto-fix.yml` attempts `dart fix --apply` and `deno fmt`.
5. Merge only after CI is green and the issue scope is satisfied.

## Checklist

- [ ] Reproduction is clear
- [ ] Smallest safe fix is implemented
- [ ] Analyze/tests/CI are checked
- [ ] PR notes explain the change and the remaining risk
