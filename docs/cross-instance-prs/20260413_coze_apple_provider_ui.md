# cross-instance-pr: coze + apple UI追加

作成: Windows版#63 (2026-04-13)
宛先: VSCode版 + PowerShell版
状態: pending

## VSCode版: `_providerMeta` / `_fallback` / `_quizzes` 追加

```dart
'coze': ProviderMeta(displayName: 'Coze', emoji: '🤖', color: Color(0xFF5B61FF)),
'apple': ProviderMeta(displayName: 'Apple Intelligence', emoji: '🍎', color: Color(0xFF1D1D1F)),
```

## PowerShell版: yml カウント 45→47社

## 根拠
- 46社目 Coze: ByteDance AIエージェントPF。600+プラグイン・マルチモデル・ノーコード (8/9)
- 47社目 Apple Intelligence: オンデバイスAI。20億台デプロイ・プライバシー最優先 (6/9)
- migrations: 20260413042000 / 20260413043000
