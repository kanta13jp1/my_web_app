# Cross-Instance PR: #514 アプリバージョン Phase 2 実装

**作成**: PS#5 S46 / 2026-04-25
**宛先**: VSCode版
**期限**: 2026-05-10（PWA UX 改善・priority:high）

---

## 背景

Issue #514 Phase 1b (設定画面フッターに `v{version}` 表示) は PS#5 S46 で完了 (commit 5349062b)。
Phase 2 は Service Worker 挙動 + GHA workflow 修正が絡むため VSCode版に handoff。

## Phase 2 タスク一覧

### 2a: deploy-prod.yml に `version.json` 生成ステップ追加

**対象ファイル**: `.github/workflows/deploy-prod.yml`

現状: `--dart-define=APP_VERSION=...` は L461 にある。`BUILD_NUMBER` define は未追加。

追加する内容:
```yaml
- name: Write version.json
  run: |
    mkdir -p build/web
    echo '{"version":"${{ steps.version.outputs.version }}","buildNumber":"${{ github.run_number }}","commit":"${{ github.sha }}","deployedAt":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'"}' > build/web/version.json
```
→ Firebase Hosting に同梱され `https://my-web-app-b67f4.web.app/version.json` で公開される。

また `--dart-define=BUILD_NUMBER=${{ github.run_number }}` も L461 付近に追加して Dart 側の `AppVersion.buildNumber` に値が入るようにする。

### 2b: VersionCheckService 新規作成

**新規ファイル**: `lib/services/version_check_service.dart`

```dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/app_version.dart';

class VersionCheckService {
  static const Duration _pollInterval = Duration(minutes: 30);
  Timer? _timer;

  Future<String?> fetchLatestVersion() async {
    final uri = Uri.parse('/version.json?t=${DateTime.now().millisecondsSinceEpoch}');
    try {
      final resp = await http.get(uri, headers: {'Cache-Control': 'no-cache'});
      if (resp.statusCode != 200) return null;
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      return json['version'] as String?;
    } catch (_) {
      return null;
    }
  }

  bool isOutdated(String current, String latest) {
    final curParts = current.split('.').map(int.tryParse).toList();
    final latParts = latest.split('.').map(int.tryParse).toList();
    for (var i = 0; i < 3; i++) {
      final c = curParts[i] ?? 0;
      final l = latParts[i] ?? 0;
      if (c != l) return c < l;
    }
    return false;
  }

  void startPolling(VoidCallback onOutdated) {
    if (!kIsWeb) return; // Web 専用
    _timer = Timer.periodic(_pollInterval, (_) async {
      final latest = await fetchLatestVersion();
      if (latest != null && !AppVersion.isDev && isOutdated(AppVersion.value, latest)) {
        onOutdated();
      }
    });
  }

  void dispose() => _timer?.cancel();
}
```

### 2c: UpdateBanner widget 新規作成

**新規ファイル**: `lib/widgets/update_banner.dart`

MaterialBanner で「新しいバージョンが利用可能」を表示、「更新する」タップで SW update + reload。

```dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
// dart:js_interop は Web のみ — conditional import で guard すること

class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      content: const Text('新しいバージョンが利用可能です'),
      actions: [
        TextButton(
          onPressed: () async {
            if (kIsWeb) {
              // Service Worker 更新 + リロード (dart:js_interop 経由)
              // 詳細実装は #514 Issue の Phase 2c を参照
            }
            onDismiss();
          },
          child: const Text('更新する'),
        ),
        TextButton(
          onPressed: onDismiss,
          child: const Text('あとで'),
        ),
      ],
    );
  }
}
```

**注意**: `dart:js_interop` は VM テストで実行不可 (`dart:js_interop` is not supported on the Dart VM)。
`kIsWeb` ガード + `conditional import` で切り分け必要（参考: election_victory_page の先例）。

### 2d: main.dart or app.dart で polling 開始

`VersionCheckService.startPolling()` をアプリ起動時に呼ぶ。
`MaterialApp` の上位 widget (StatefulWidget) で管理して `dispose()` も忘れずに。

## 完了条件

- [ ] `web/version.json` が deploy 後に `https://my-web-app-b67f4.web.app/version.json` で取得できる
- [ ] `AppVersion.buildNumber` に実際の run_number が入る
- [ ] 30 分毎 polling が動作する（dev 環境では skip）
- [ ] 古いバージョン時に MaterialBanner が表示され「更新する」で reload
- [ ] `flutter analyze` 0 エラー
- [ ] `dart:js_interop` VM テスト問題が出ない

## 参照

- Issue: https://github.com/kanta13jp1/my_web_app/issues/514
- Phase 1b 完了 commit: 5349062b
- AppVersion class: `lib/core/app_version.dart`
- dart:js_interop VM 非対応先例: `election_victory_page.dart` (PS#5 S40)
