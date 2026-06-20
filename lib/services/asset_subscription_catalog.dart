import '../models/asset_liability_workbook.dart';

/// サブスク (AI/クラウド SaaS) のテンプレート 1 件。
///
/// ユーザーが「Anthropic」「OpenAI」等をワンタップで定期固定費に登録できるよう、
/// 代表的な月額サービスのプリセットを提供する。金額は概算 (円換算の目安) であり、
/// 実際の請求額・請求日に合わせて登録ダイアログで調整する前提。
class AssetSubscriptionPreset {
  /// 安定した一意 ID (重複登録の判定・テスト用)。
  final String id;

  /// 表示名 (例: Anthropic (Claude))。
  final String name;

  /// 月額の概算 (円)。USD 課金のサービスはおおよその円換算。0 より大きい。
  final double defaultMonthlyAmount;

  /// 補足 (プラン名や「従量課金」など)。カードのサブタイトルに表示する。
  final String note;

  const AssetSubscriptionPreset({
    required this.id,
    required this.name,
    required this.defaultMonthlyAmount,
    this.note = '',
  });

  /// 登録ダイアログへ渡す prefill 用の [AssetRecurringFixedCost] を作る。
  /// 区分は subscription 固定。[paymentDay] は呼び出し側で既定値を渡す
  /// (請求日はユーザーがダイアログで調整する)。id は保存時に採番し直されるため
  /// プレースホルダーで良い。
  AssetRecurringFixedCost toPrefill({int paymentDay = 1}) {
    return AssetRecurringFixedCost(
      id: 'sub_preset_$id',
      name: name,
      amount: defaultMonthlyAmount,
      paymentDay: paymentDay,
      cadence: AssetRecurringFixedCostCadence.monthly,
      category: AssetRecurringFixedCostCategory.subscription,
    );
  }
}

/// 代表的な AI/クラウド サブスクのプリセット集 (静的カタログ)。
///
/// あくまで登録を素早くするためのテンプレートで、金額は目安。ここに無いサービスは
/// 「その他を追加」から手入力できる。
class AssetSubscriptionCatalog {
  const AssetSubscriptionCatalog._();

  /// 登録時に請求日が未指定のときに使う既定の振替日 (ユーザーが調整する前提)。
  static const int defaultPaymentDay = 1;

  static const List<AssetSubscriptionPreset> presets =
      <AssetSubscriptionPreset>[
    AssetSubscriptionPreset(
      id: 'anthropic',
      name: 'Anthropic (Claude)',
      defaultMonthlyAmount: 3000,
      note: 'Claude Pro 目安 / 実際の請求額に調整',
    ),
    AssetSubscriptionPreset(
      id: 'openai',
      name: 'OpenAI (ChatGPT)',
      defaultMonthlyAmount: 3000,
      note: 'ChatGPT Plus 目安',
    ),
    AssetSubscriptionPreset(
      id: 'gemini',
      name: 'Google Gemini',
      defaultMonthlyAmount: 2900,
      note: 'Google AI Pro 目安',
    ),
    AssetSubscriptionPreset(
      id: 'gcp',
      name: 'Google Cloud (GCP)',
      defaultMonthlyAmount: 1000,
      note: '従量課金 / 平均額を入力',
    ),
    AssetSubscriptionPreset(
      id: 'supabase',
      name: 'Supabase',
      defaultMonthlyAmount: 3800,
      note: 'Pro プラン 目安',
    ),
    AssetSubscriptionPreset(
      id: 'notion',
      name: 'Notion',
      defaultMonthlyAmount: 1650,
      note: 'Plus プラン 目安',
    ),
    AssetSubscriptionPreset(
      id: 'github',
      name: 'GitHub',
      defaultMonthlyAmount: 1500,
      note: 'Copilot / Pro 目安',
    ),
    AssetSubscriptionPreset(
      id: 'cursor',
      name: 'Cursor',
      defaultMonthlyAmount: 3000,
      note: 'Pro プラン 目安',
    ),
    AssetSubscriptionPreset(
      id: 'microsoft365',
      name: 'Microsoft 365',
      defaultMonthlyAmount: 1490,
      note: 'Personal 目安',
    ),
    AssetSubscriptionPreset(
      id: 'figma',
      name: 'Figma',
      defaultMonthlyAmount: 1800,
      note: 'Professional 目安',
    ),
    AssetSubscriptionPreset(
      id: 'vercel',
      name: 'Vercel',
      defaultMonthlyAmount: 3000,
      note: 'Pro プラン 目安 (従量加算あり)',
    ),
  ];
}
