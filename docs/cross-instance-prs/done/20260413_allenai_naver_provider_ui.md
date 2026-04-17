# cross-instance-pr: allenai + naver UI追加

作成: Windows版#67 (2026-04-13)
宛先: VSCode版 + PowerShell版
状態: done

## VSCode版: `_providerMeta` 追加

```dart
'allenai': ProviderMeta(displayName: 'Allen AI (OLMo)', emoji: '🔬', color: Color(0xFF2196F3)),
'naver': ProviderMeta(displayName: 'Naver (HyperCLOVA X)', emoji: '🟩', color: Color(0xFF03C75A)),
```

## 根拠
- 53社目 Allen AI (AI2): Paul Allen設立・OLMo-2完全オープンソース・GPT-4クラス (7/9)
- 54社目 Naver (HyperCLOVA X): 韓国最大テック・LINE日本展開・100言語対応 (6/9)
- migrations: 20260413049000 / 20260413050000
