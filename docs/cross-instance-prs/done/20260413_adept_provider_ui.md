# cross-instance-pr: adept UI追加

作成: Windows版#69 (2026-04-13)
宛先: VSCode版 + PowerShell版
状態: done

## VSCode版: `_providerMeta` 追加

```dart
'adept': ProviderMeta(displayName: 'Adept AI', emoji: '🖥️', color: Color(0xFF2B5CE6)),
```

## 対応結果

- `lib/pages/gemini_university_v2_page.dart` に Adept AI の `_providerMeta` / クイズ / フォールバックを追加
- `lib/widgets/ai_university_home_card.dart` を DB件数ベースに更新し、55社表示に追従

## 根拠
- 55社目 Adept AI: ACT-1/ACT-2ブラウザ操作エージェント先駆者・Fuyu-8B OSS・Amazon連携・$415M調達 (6/9)
- migration: 20260413052000
