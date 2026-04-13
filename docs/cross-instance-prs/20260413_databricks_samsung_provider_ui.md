# cross-instance-pr: databricks + samsung UI追加

作成: Windows版#64 (2026-04-13)
宛先: VSCode版 + PowerShell版
状態: pending

## VSCode版: `_providerMeta` 追加

```dart
'databricks': ProviderMeta(displayName: 'Databricks', emoji: '🧱', color: Color(0xFFFF3621)),
'samsung': ProviderMeta(displayName: 'Samsung Galaxy AI', emoji: '📱', color: Color(0xFF1428A0)),
```

## 根拠
- 48社目 Databricks: MoE LLM DBRX + MLflow + レイクハウス (8/9)
- 49社目 Samsung: Galaxy AI 2億台展開・Gemini Nano独占搭載 (6/9)
- migrations: 20260413044000 / 20260413045000
