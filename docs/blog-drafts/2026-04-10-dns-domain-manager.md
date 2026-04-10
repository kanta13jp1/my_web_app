---
title: Flutter WebでDNS・ドメイン管理ツールを実装してCloudflare/Google Domainsと戦う話
date: 2026-04-10
tags: [Flutter, Supabase, DNS, ドメイン管理, EdgeFunction]
status: draft
target_platforms: [zenn, qiita, dev.to, note]
---

# Flutter WebでDNS・ドメイン管理ツールを実装してCloudflare/Google Domainsと戦う話

## はじめに

「自分株式会社」は、Notion・Evernote・MoneyForwardなど21の競合SaaSを超えることを目指したAI統合ライフマネジメントアプリです。

今回はその一環として、**DNS・ドメイン管理機能**をFlutter Web + Supabase Edge Functionで実装しました。
競合はCloudflare・Google Domains・Amazon Route53という強豪揃いですが、「自分の会社の全情報を一元管理する」というコンセプトのもと、ドメイン管理もアプリ内に統合しました。

サービスURL: https://my-web-app-b67f4.web.app/

## 実装した機能

### 3タブ構成のDNS管理UI

```dart
TabBar(
  controller: _tabController,
  tabs: const [
    Tab(icon: Icon(Icons.language), text: 'ドメイン'),
    Tab(icon: Icon(Icons.dns), text: 'DNSレコード'),
    Tab(icon: Icon(Icons.lock), text: 'SSL'),
  ],
),
```

1. **ドメインタブ**: ドメイン一覧表示・追加ダイアログ（Cloudflare/Google Domains/Route53等のレジストラ選択付き）
2. **DNSレコードタブ**: 選択したドメインのA/AAAA/CNAME/MX/TXT/NS/SRV/CAAレコード管理
3. **SSL管理タブ**: 全ドメインのSSL証明書有効期限モニタリング

### Edge Function側 (Deno)

Edge Functionでは以下のアクションをサポートしています。

```typescript
// GET エンドポイント
// view=domains  → ドメイン一覧
// view=records  → 特定ドメインのDNSレコード一覧
// view=ssl_status → SSL証明書状態

// POST アクション
// action=add_domain   { domain, registrar }
// action=add_record   { domain_id, record_type, name, value, ttl, priority }
// action=delete_record { record_id }
```

データはSupabaseの`app_analytics`テーブルを活用し、`source`フィールドで`dns_domain`/`dns_record`を区別するシンプルな設計です。新規テーブルを作らずに済むのがポイント。

## 詰まったポイント: DropdownButtonFormFieldのdeprecated警告

Flutter 3.33.0以降で`DropdownButtonFormField`の`value`プロパティが非推奨になりました。

```dart
// ❌ 旧: deprecated
DropdownButtonFormField<String>(
  value: selectedType,
  ...
)

// ✅ 新: initialValue を使用
DropdownButtonFormField<String>(
  initialValue: selectedType,
  ...
)
```

このような破壊的変更への対応は`flutter analyze`を0エラーで維持することで自動的に検知できます。

## colorSchemeトークンによるダークモード対応

ハードコードの`Colors.black`や`Colors.white`を使わず、全ての色指定をMaterial 3の`colorScheme`トークンで統一しています。

```dart
// ❌ ハードコード（ダークモード非対応）
color: Colors.black54

// ✅ colorSchemeトークン（ダークモード自動対応）
color: colorScheme.outline
color: colorScheme.onSurfaceVariant
color: colorScheme.surfaceContainerHighest
```

これにより、アプリ全体のテーマを切り替えるだけで、DNS管理画面も自動的にダーク/ライトモードに対応します。

## TabControllerのFABリビルド問題

`FloatingActionButton`をタブに応じて動的に切り替えたい場合、`TabController`のリスナーで`setState()`を明示的に呼ぶ必要があります。

```dart
_tabController.addListener(() {
  if (!_tabController.indexIsChanging) {
    setState(() {}); // FABを再ビルドするためのsetState
    if (_tabController.index == 2 && _sslStatus.isEmpty) {
      _fetchSslStatus();
    }
  }
});
```

`_tabController.indexIsChanging`チェックを入れることで、アニメーション中の不要なリビルドを防いでいます。

## アーキテクチャ: Edge Function First

Dart/Flutter側にはUI表示ロジックのみを置き、ビジネスロジックはすべてSupabase Edge Function (Deno)に集約しています。

- ✅ クライアントコードが軽量になる
- ✅ ロジックの変更がデプロイなしで反映可能
- ✅ セキュリティ（Service Role Keyをクライアントに渡さない）

```dart
// Flutter側: 薄いHTTPクライアントとして機能
final response = await _supabase.functions.invoke(
  'dns-domain-manager',
  method: HttpMethod.get,
  queryParameters: {'view': 'domains'},
);
```

## まとめ

21の競合SaaSに挑む「自分株式会社」の開発を通じて、Flutter Web + Supabase Edge Functionのアーキテクチャパターンが固まってきました。

- **Edge Function First**: ビジネスロジックはDeno側に集約
- **colorSchemeトークン**: ハードコードカラー禁止でダークモード完全対応
- **flutter analyze 0エラー維持**: CIで常時チェック、deprecated APIを即時修正

次は録音→X自動投稿パイプラインの強化で、バイラル係数 > 1 を目指します！

---

URL: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic #DNS #ドメイン管理
