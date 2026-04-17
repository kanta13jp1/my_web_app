# cross-instance-pr: zhipu UI追加

作成: Windows版#65 (2026-04-13)
宛先: VSCode版 + PowerShell版
状態: done

## VSCode版: `_providerMeta` 追加

```dart
'zhipu': ProviderMeta(displayName: 'Zhipu AI (GLM)', emoji: '🔮', color: Color(0xFF4E5FFF)),
```

## 根拠
- 50社目キリ番 Zhipu AI: 清華大学発・中国AI御三家・GLM-4 128K・CogVideo (8/9)
- migration: 20260413046000

## NAR文字化け修正 (追記)
`scripts/fetch_horse_racing.py` line 96: `errors="replace"` → `errors="ignore"` 修正済み (Windows版#65)
Flutter Webでボックス表示になっていた文字化けが解消される。
次回 horse-racing-update.yml 実行時に自動クリーンアップ + 再取得。
