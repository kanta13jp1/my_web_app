# cross-instance-pr: character_ai + inflection UI追加

作成: Windows版#66 (2026-04-13)
宛先: VSCode版 + PowerShell版
状態: pending

## VSCode版: `_providerMeta` 追加

```dart
'character_ai': ProviderMeta(displayName: 'Character.AI', emoji: '🎭', color: Color(0xFF000000)),
'inflection': ProviderMeta(displayName: 'Inflection AI (Pi)', emoji: '💙', color: Color(0xFF6B48FF)),
```

## 根拠
- 51社目 Character.AI: 1.5億MAU・1,800万キャラクター・DeepMind創業者系 (7/9)
- 52社目 Inflection AI (Pi): 感情的知性特化・GPT-4クラス・Microsoft系 (6/9)
- migrations: 20260413047000 / 20260413048000
