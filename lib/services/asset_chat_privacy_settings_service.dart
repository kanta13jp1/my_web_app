import 'package:shared_preferences/shared_preferences.dart';

/// AI 資産チャットへ送る金額のプライバシー設定。
///
/// 既定は OFF。ON の場合だけ Edge Function に `pii_mode=mask` を渡し、
/// LLM 送信境界で金額を幅へ変換する。
class AssetChatPrivacySettingsService {
  const AssetChatPrivacySettingsService();

  static const String maskMoneyAmountsKey = 'asset_chat_mask_money_amounts_v1';

  Future<bool> loadMaskMoneyAmounts() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(maskMoneyAmountsKey) ?? false;
  }

  Future<void> saveMaskMoneyAmounts(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(maskMoneyAmountsKey, enabled);
  }
}
