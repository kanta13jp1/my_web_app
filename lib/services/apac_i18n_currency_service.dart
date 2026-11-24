import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// アジア太平洋地域向けロケール設定 (#2594)。
@immutable
class ApacLocaleConfig {
  const ApacLocaleConfig({
    required this.localeTag,
    required this.intlLocale,
    required this.languageCode,
    required this.countryCode,
    required this.regionCode,
    required this.defaultCurrencyCode,
    required this.nativeLabel,
    required this.japaneseLabel,
  });

  final String localeTag;
  final String intlLocale;
  final String languageCode;
  final String countryCode;
  final String regionCode;
  final String defaultCurrencyCode;
  final String nativeLabel;
  final String japaneseLabel;

  Locale get flutterLocale => Locale(languageCode, countryCode);
}

/// アジア太平洋・取引通貨設定 (#2594)。
@immutable
class ApacCurrencyConfig {
  const ApacCurrencyConfig({
    required this.code,
    required this.symbol,
    required this.decimalDigits,
    required this.displayNameJa,
    required this.displayNameEn,
    this.isBaseHomeCurrency = false,
  });

  final String code;
  final String symbol;
  final int decimalDigits;
  final String displayNameJa;
  final String displayNameEn;
  final bool isBaseHomeCurrency;
}

/// ロケール別の表示文言セット (#2594)。
@immutable
class ApacUiStrings {
  const ApacUiStrings({
    required this.panelTitle,
    required this.panelSubtitle,
    required this.localeSectionLabel,
    required this.currencySectionLabel,
    required this.regionLabel,
    required this.localeLabel,
    required this.currencyLabel,
    required this.formattedAmountLabel,
    required this.fxEstimateLabel,
    required this.fxWarningBadge,
    required this.fxWarningTitle,
    required this.fxWarningDisclaimer,
    required this.fxVerifiedBadge,
    required this.fxVerifiedDetail,
    required this.verificationNoteLabel,
    required this.estimateToggleEnableLabel,
    required this.estimateToggleDisableLabel,
  });

  final String panelTitle;
  final String panelSubtitle;
  final String localeSectionLabel;
  final String currencySectionLabel;
  final String regionLabel;
  final String localeLabel;
  final String currencyLabel;
  final String formattedAmountLabel;
  final String fxEstimateLabel;
  final String fxWarningBadge;
  final String fxWarningTitle;
  final String fxWarningDisclaimer;
  final String fxVerifiedBadge;
  final String fxVerifiedDetail;
  final String verificationNoteLabel;
  final String estimateToggleEnableLabel;
  final String estimateToggleDisableLabel;
}

/// `public.regional_knowledge_documents` および `public.notes` 拡張列に
/// 対応する地域・言語・通貨メタデータモデル (#2594)。
@immutable
class RegionalDocumentMetadata {
  const RegionalDocumentMetadata({
    required this.id,
    required this.userId,
    required this.title,
    this.targetRegion = ApacI18nCurrencyService.defaultRegionCode,
    this.contentLocale = ApacI18nCurrencyService.defaultLocaleTag,
    this.baseCurrencyCode = ApacI18nCurrencyService.defaultCurrencyCode,
    this.amountMinorOrDecimal,
    this.fxRequiresVerification = true,
    this.verificationNote = '',
    this.createdAt,
  });

  final String id;
  final String userId;
  final String title;
  final String targetRegion;
  final String contentLocale;
  final String baseCurrencyCode;
  final double? amountMinorOrDecimal;
  final bool fxRequiresVerification;
  final String verificationNote;
  final DateTime? createdAt;

  bool get isVerifiedBaseJpy =>
      baseCurrencyCode == ApacI18nCurrencyService.defaultCurrencyCode &&
      !fxRequiresVerification;

  RegionalDocumentMetadata copyWith({
    String? id,
    String? userId,
    String? title,
    String? targetRegion,
    String? contentLocale,
    String? baseCurrencyCode,
    double? amountMinorOrDecimal,
    bool clearAmount = false,
    bool? fxRequiresVerification,
    String? verificationNote,
    DateTime? createdAt,
  }) {
    return RegionalDocumentMetadata(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      targetRegion: targetRegion ?? this.targetRegion,
      contentLocale: contentLocale ?? this.contentLocale,
      baseCurrencyCode: baseCurrencyCode ?? this.baseCurrencyCode,
      amountMinorOrDecimal: clearAmount
          ? null
          : (amountMinorOrDecimal ?? this.amountMinorOrDecimal),
      fxRequiresVerification:
          fxRequiresVerification ?? this.fxRequiresVerification,
      verificationNote: verificationNote ?? this.verificationNote,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory RegionalDocumentMetadata.fromJson(Map<String, dynamic> json) {
    final rawRegion = (json['target_region'] as String?)?.trim() ?? '';
    final rawLocale = (json['content_locale'] as String?)?.trim() ?? '';
    final rawCurrency = (json['base_currency_code'] as String?)?.trim() ?? '';
    final createdAtRaw = json['created_at']?.toString();
    final rawFlag = json['fx_requires_verification'];

    return RegionalDocumentMetadata(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      title: (json['title'] as String?)?.trim() ?? '',
      targetRegion: ApacI18nCurrencyService.isSupportedRegion(rawRegion)
          ? rawRegion
          : ApacI18nCurrencyService.defaultRegionCode,
      contentLocale: ApacI18nCurrencyService.isSupportedLocale(rawLocale)
          ? rawLocale
          : ApacI18nCurrencyService.defaultLocaleTag,
      baseCurrencyCode: ApacI18nCurrencyService.isSupportedCurrency(rawCurrency)
          ? rawCurrency
          : ApacI18nCurrencyService.defaultCurrencyCode,
      amountMinorOrDecimal: _parseDouble(json['amount_minor_or_decimal']),
      fxRequiresVerification: rawFlag is bool ? rawFlag : true,
      verificationNote: (json['verification_note'] as String?)?.trim() ?? '',
      createdAt: createdAtRaw == null
          ? null
          : DateTime.tryParse(createdAtRaw)?.toUtc(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (id.isNotEmpty) 'id': id,
      if (userId.isNotEmpty) 'user_id': userId,
      'title': title,
      'target_region': targetRegion,
      'content_locale': contentLocale,
      'base_currency_code': baseCurrencyCode,
      'amount_minor_or_decimal': amountMinorOrDecimal,
      'fx_requires_verification': fxRequiresVerification,
      'verification_note': verificationNote,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  /// `public.notes` 拡張カラム更新用ペイロード。
  Map<String, dynamic> toNoteMetadataPayload() {
    return <String, dynamic>{
      'target_region': targetRegion,
      'content_locale': contentLocale,
      'base_currency_code': baseCurrencyCode,
      'fx_requires_verification': fxRequiresVerification,
    };
  }
}

/// APAC 地域向け多言語・多通貨フォーマットおよび要検証判定ロジック (#2594)。
class ApacI18nCurrencyService {
  const ApacI18nCurrencyService._();

  static const String defaultLocaleTag = 'ja-JP';
  static const String defaultRegionCode = 'JP';
  static const String defaultCurrencyCode = 'JPY';

  static const List<String> supportedRegions = <String>[
    'JP',
    'SG',
    'AU',
    'ID',
    'VN',
    'TH',
    'APAC',
  ];

  static const List<ApacLocaleConfig> supportedLocales = <ApacLocaleConfig>[
    ApacLocaleConfig(
      localeTag: 'ja-JP',
      intlLocale: 'ja_JP',
      languageCode: 'ja',
      countryCode: 'JP',
      regionCode: 'JP',
      defaultCurrencyCode: 'JPY',
      nativeLabel: '日本語 (JP)',
      japaneseLabel: '日本 (日本語)',
    ),
    ApacLocaleConfig(
      localeTag: 'en-SG',
      intlLocale: 'en_SG',
      languageCode: 'en',
      countryCode: 'SG',
      regionCode: 'SG',
      defaultCurrencyCode: 'SGD',
      nativeLabel: 'English (SG)',
      japaneseLabel: 'シンガポール (英語)',
    ),
    ApacLocaleConfig(
      localeTag: 'en-AU',
      intlLocale: 'en_AU',
      languageCode: 'en',
      countryCode: 'AU',
      regionCode: 'AU',
      defaultCurrencyCode: 'AUD',
      nativeLabel: 'English (AU)',
      japaneseLabel: 'オーストラリア (英語)',
    ),
    ApacLocaleConfig(
      localeTag: 'id-ID',
      intlLocale: 'id_ID',
      languageCode: 'id',
      countryCode: 'ID',
      regionCode: 'ID',
      defaultCurrencyCode: 'IDR',
      nativeLabel: 'Bahasa Indonesia',
      japaneseLabel: 'インドネシア (インドネシア語)',
    ),
    ApacLocaleConfig(
      localeTag: 'vi-VN',
      intlLocale: 'vi_VN',
      languageCode: 'vi',
      countryCode: 'VN',
      regionCode: 'VN',
      defaultCurrencyCode: 'VND',
      nativeLabel: 'Tiếng Việt',
      japaneseLabel: 'ベトナム (ベトナム語)',
    ),
    ApacLocaleConfig(
      localeTag: 'th-TH',
      intlLocale: 'th_TH',
      languageCode: 'th',
      countryCode: 'TH',
      regionCode: 'TH',
      defaultCurrencyCode: 'THB',
      nativeLabel: 'ภาษาไทย',
      japaneseLabel: 'タイ (タイ語)',
    ),
  ];

  static const List<ApacCurrencyConfig> supportedCurrencies =
      <ApacCurrencyConfig>[
    ApacCurrencyConfig(
      code: 'JPY',
      symbol: '¥',
      decimalDigits: 0,
      displayNameJa: '日本円',
      displayNameEn: 'Japanese Yen',
      isBaseHomeCurrency: true,
    ),
    ApacCurrencyConfig(
      code: 'SGD',
      symbol: 'S\$',
      decimalDigits: 2,
      displayNameJa: 'シンガポールドル',
      displayNameEn: 'Singapore Dollar',
    ),
    ApacCurrencyConfig(
      code: 'AUD',
      symbol: 'A\$',
      decimalDigits: 2,
      displayNameJa: '豪ドル',
      displayNameEn: 'Australian Dollar',
    ),
    ApacCurrencyConfig(
      code: 'USD',
      symbol: 'US\$',
      decimalDigits: 2,
      displayNameJa: '米ドル',
      displayNameEn: 'US Dollar',
    ),
    ApacCurrencyConfig(
      code: 'IDR',
      symbol: 'Rp',
      decimalDigits: 0,
      displayNameJa: 'インドネシアルピア',
      displayNameEn: 'Indonesian Rupiah',
    ),
    ApacCurrencyConfig(
      code: 'VND',
      symbol: '₫',
      decimalDigits: 0,
      displayNameJa: 'ベトナムドン',
      displayNameEn: 'Vietnamese Dong',
    ),
    ApacCurrencyConfig(
      code: 'THB',
      symbol: '฿',
      decimalDigits: 2,
      displayNameJa: 'タイバーツ',
      displayNameEn: 'Thai Baht',
    ),
  ];

  static const Map<String, ApacUiStrings> localizedStrings =
      <String, ApacUiStrings>{
    'ja-JP': ApacUiStrings(
      panelTitle: 'APAC 多言語・多通貨データ基盤',
      panelSubtitle: '地域・言語・基準通貨メタデータと為替換算時の要検証ガードを管理します。',
      localeSectionLabel: '表示言語・地域ロケール',
      currencySectionLabel: '表示通貨',
      regionLabel: '対象地域',
      localeLabel: '利用言語',
      currencyLabel: '基準通貨',
      formattedAmountLabel: '表示金額',
      fxEstimateLabel: '参考換算試算値',
      fxWarningBadge: '要検証 / 未確定為替レート',
      fxWarningTitle: '外部為替・財務データ依存のため要検証',
      fxWarningDisclaimer:
          '表示中の為替換算値または財務予測データは外部情報機関への依存が大きいため、意思決定前に必ず最新の一次レート・監査数値で再検証してください。',
      fxVerifiedBadge: '検証済み基準通貨 (JPY)',
      fxVerifiedDetail: '日本円ベースの確定データであり、外部為替換算による乖離リスクはありません。',
      verificationNoteLabel: '検証メモ',
      estimateToggleEnableLabel: '財務推計表示を確認',
      estimateToggleDisableLabel: '基準データ表示に戻す',
    ),
    'en-SG': ApacUiStrings(
      panelTitle: 'APAC Multi-Locale & Currency Foundation',
      panelSubtitle:
          'Manage regional language metadata, currency display, and unverified FX warnings.',
      localeSectionLabel: 'Display Locale & Region',
      currencySectionLabel: 'Display Currency',
      regionLabel: 'Target Region',
      localeLabel: 'Content Locale',
      currencyLabel: 'Base Currency',
      formattedAmountLabel: 'Formatted Amount',
      fxEstimateLabel: 'Indicative FX Conversion',
      fxWarningBadge: 'Verification Required / Unverified FX',
      fxWarningTitle: 'Unverified External FX & Financial Dependency',
      fxWarningDisclaimer:
          'Displayed FX conversions and financial estimates rely on external data providers and remain unverified. Confirm against official primary rates before valuation or settlement.',
      fxVerifiedBadge: 'Verified Base Currency (JPY)',
      fxVerifiedDetail:
          'Confirmed JPY base figure without external exchange-rate conversion.',
      verificationNoteLabel: 'Verification Note',
      estimateToggleEnableLabel: 'Preview FX Estimate',
      estimateToggleDisableLabel: 'Return to Base Record',
    ),
    'en-AU': ApacUiStrings(
      panelTitle: 'APAC Multi-Locale & Currency Foundation',
      panelSubtitle:
          'Manage Australian and ASEAN regional metadata with unverified FX safeguards.',
      localeSectionLabel: 'Display Locale & Region',
      currencySectionLabel: 'Display Currency',
      regionLabel: 'Target Region',
      localeLabel: 'Content Locale',
      currencyLabel: 'Base Currency',
      formattedAmountLabel: 'Formatted Amount',
      fxEstimateLabel: 'Indicative FX Conversion',
      fxWarningBadge: 'Verification Required / Unverified FX',
      fxWarningTitle: 'Unverified External FX & Financial Dependency',
      fxWarningDisclaimer:
          'FX conversions and financial projections depend on external market feeds and are unverified. Reconcile with primary treasury sources prior to M&A decisions.',
      fxVerifiedBadge: 'Verified Base Currency (JPY)',
      fxVerifiedDetail:
          'Confirmed JPY base figure without external exchange-rate conversion.',
      verificationNoteLabel: 'Verification Note',
      estimateToggleEnableLabel: 'Preview FX Estimate',
      estimateToggleDisableLabel: 'Return to Base Record',
    ),
    'id-ID': ApacUiStrings(
      panelTitle: 'Fondasi Multi-Bahasa & Multi-Mata Uang APAC',
      panelSubtitle:
          'Kelola metadata wilayah, format mata uang, dan peringatan kurs yang perlu diverifikasi.',
      localeSectionLabel: 'Bahasa & Wilayah Tampilan',
      currencySectionLabel: 'Mata Uang Tampilan',
      regionLabel: 'Wilayah Target',
      localeLabel: 'Bahasa Konten',
      currencyLabel: 'Mata Uang Dasar',
      formattedAmountLabel: 'Jumlah Terformat',
      fxEstimateLabel: 'Estimasi Konversi Kurs',
      fxWarningBadge: 'Perlu Verifikasi / Kurs Belum Terverifikasi',
      fxWarningTitle: 'Ketergantungan Data Kurs & Keuangan Eksternal',
      fxWarningDisclaimer:
          'Nilai konversi kurs dan estimasi keuangan bergantung pada penyedia eksternal dan belum terverifikasi. Pastikan verifikasi ulang dengan kurs resmi sebelum keputusan bisnis.',
      fxVerifiedBadge: 'Mata Uang Dasar Terverifikasi (JPY)',
      fxVerifiedDetail:
          'Data dasar JPY terverifikasi tanpa konversi nilai tukar eksternal.',
      verificationNoteLabel: 'Catatan Verifikasi',
      estimateToggleEnableLabel: 'Pratinjau Estimasi Kurs',
      estimateToggleDisableLabel: 'Kembali ke Data Dasar',
    ),
    'vi-VN': ApacUiStrings(
      panelTitle: 'Nền tảng Đa ngôn ngữ & Đa tiền tệ APAC',
      panelSubtitle:
          'Quản lý siêu dữ liệu khu vực, định dạng tiền tệ và cảnh báo tỷ giá cần xác minh.',
      localeSectionLabel: 'Ngôn ngữ & Khu vực hiển thị',
      currencySectionLabel: 'Tiền tệ hiển thị',
      regionLabel: 'Khu vực mục tiêu',
      localeLabel: 'Ngôn ngữ nội dung',
      currencyLabel: 'Tiền tệ cơ sở',
      formattedAmountLabel: 'Số tiền hiển thị',
      fxEstimateLabel: 'Ước tính quy đổi tỷ giá',
      fxWarningBadge: 'Cần xác minh / Tỷ giá chưa kiểm chứng',
      fxWarningTitle: 'Phụ thuộc dữ liệu tài chính & tỷ giá bên ngoài',
      fxWarningDisclaimer:
          'Số liệu quy đổi tỷ giá và ước tính tài chính phụ thuộc vào nguồn bên ngoài và chưa được xác minh. Vui lòng đối chiếu tỷ giá chính thức trước khi ra quyết định.',
      fxVerifiedBadge: 'Tiền tệ cơ sở đã xác minh (JPY)',
      fxVerifiedDetail:
          'Dữ liệu gốc JPY đã xác minh, không qua quy đổi tỷ giá bên ngoài.',
      verificationNoteLabel: 'Ghi chú xác minh',
      estimateToggleEnableLabel: 'Xem ước tính tỷ giá',
      estimateToggleDisableLabel: 'Quay lại dữ liệu gốc',
    ),
    'th-TH': ApacUiStrings(
      panelTitle: 'โครงสร้างข้อมูลหลายภาษาและหลายสกุลเงิน APAC',
      panelSubtitle:
          'จัดการเมตาดาต้าภูมิภาค การแสดงสกุลเงิน และคำเตือนอัตราแลกเปลี่ยนที่ต้องตรวจสอบ',
      localeSectionLabel: 'ภาษาและภูมิภาคที่แสดง',
      currencySectionLabel: 'สกุลเงินที่แสดง',
      regionLabel: 'ภูมิภาคเป้าหมาย',
      localeLabel: 'ภาษาของเนื้อหา',
      currencyLabel: 'สกุลเงินหลัก',
      formattedAmountLabel: 'จำนวนเงินที่จัดรูปแบบ',
      fxEstimateLabel: 'ประมาณการแปลงสกุลเงิน',
      fxWarningBadge: 'ต้องตรวจสอบ / อัตราแลกเปลี่ยนยังไม่ยืนยัน',
      fxWarningTitle: 'ขึ้นกับข้อมูลทางการเงินและอัตราแลกเปลี่ยนภายนอก',
      fxWarningDisclaimer:
          'ข้อมูลการแปลงสกุลเงินและประมาณการทางการเงินอาศัยผู้ให้บริการภายนอกและยังไม่ได้รับการยืนยัน กรุณาตรวจสอบกับอัตราทางการก่อนตัดสินใจ',
      fxVerifiedBadge: 'สกุลเงินหลักที่ตรวจสอบแล้ว (JPY)',
      fxVerifiedDetail:
          'ข้อมูลฐาน JPY ที่ยืนยันแล้วโดยไม่มีการแปลงอัตราแลกเปลี่ยนภายนอก',
      verificationNoteLabel: 'บันทึกการตรวจสอบ',
      estimateToggleEnableLabel: 'ดูประมาณการอัตราแลกเปลี่ยน',
      estimateToggleDisableLabel: 'กลับสู่ข้อมูลฐาน',
    ),
  };

  /// 参考レート（1単位あたり JPY 換算の基準テーブル。実運用では要外部検証扱い）。
  static const Map<String, double> defaultReferenceJpyPerUnitRates =
      <String, double>{
    'JPY': 1.0,
    'SGD': 114.0,
    'AUD': 100.0,
    'USD': 152.0,
    'IDR': 0.0096,
    'VND': 0.0060,
    'THB': 4.45,
  };

  static bool isSupportedRegion(String regionCode) =>
      supportedRegions.contains(regionCode);

  static bool isSupportedLocale(String localeTag) =>
      supportedLocales.any((config) => config.localeTag == localeTag);

  static bool isSupportedCurrency(String currencyCode) =>
      supportedCurrencies.any((config) => config.code == currencyCode);

  static ApacLocaleConfig resolveLocale(String localeTag) {
    for (final config in supportedLocales) {
      if (config.localeTag == localeTag) {
        return config;
      }
    }
    return supportedLocales.first;
  }

  static ApacCurrencyConfig resolveCurrency(String currencyCode) {
    for (final config in supportedCurrencies) {
      if (config.code == currencyCode) {
        return config;
      }
    }
    return supportedCurrencies.first;
  }

  static ApacUiStrings stringsFor(String localeTag) =>
      localizedStrings[localeTag] ?? localizedStrings[defaultLocaleTag]!;

  /// `package:intl` (`NumberFormat.currency`) を用いて指定ロケール・通貨で金額を整形する。
  static String formatCurrency({
    required num amount,
    required String currencyCode,
    String localeTag = defaultLocaleTag,
  }) {
    final localeConfig = resolveLocale(localeTag);
    final currencyConfig = resolveCurrency(currencyCode);
    final formatter = NumberFormat.currency(
      locale: localeConfig.intlLocale,
      name: currencyConfig.code,
      symbol: currencyConfig.symbol,
      decimalDigits: currencyConfig.decimalDigits,
    );
    return formatter.format(amount);
  }

  /// 参考換算レートを用いた試算変換（外部レート依存のため必ず要検証フラグと併用する）。
  static double? convertEstimatedAmount({
    required double amount,
    required String fromCurrencyCode,
    required String toCurrencyCode,
    Map<String, double> jpyPerUnitRates = defaultReferenceJpyPerUnitRates,
  }) {
    final fromRate = jpyPerUnitRates[fromCurrencyCode];
    final toRate = jpyPerUnitRates[toCurrencyCode];
    if (fromRate == null || toRate == null || fromRate <= 0 || toRate <= 0) {
      return null;
    }
    if (fromCurrencyCode == toCurrencyCode) {
      return amount;
    }
    final inJpy = amount * fromRate;
    return inJpy / toRate;
  }

  /// 外部為替依存・未検証警告バナーを表示すべきかを判定する。
  static bool evaluateRequiresFxVerification({
    required bool fxRequiresVerification,
    required String baseCurrencyCode,
    required String displayCurrencyCode,
    bool isFinancialEstimate = false,
  }) {
    if (fxRequiresVerification || isFinancialEstimate) {
      return true;
    }
    if (baseCurrencyCode != displayCurrencyCode) {
      return true;
    }
    return displayCurrencyCode != defaultCurrencyCode;
  }
}

/// 表示ロケール・通貨・要検証予測状態をリアクティブに保持する Notifier (#2594)。
class ApacLocaleNotifier extends ChangeNotifier {
  ApacLocaleNotifier({
    String initialLocaleTag = ApacI18nCurrencyService.defaultLocaleTag,
    String? initialCurrencyCode,
    String? initialRegionCode,
    bool initialIsFinancialEstimate = false,
  })  : _localeTag =
            ApacI18nCurrencyService.resolveLocale(initialLocaleTag).localeTag,
        _currencyCode = initialCurrencyCode != null &&
                ApacI18nCurrencyService.isSupportedCurrency(initialCurrencyCode)
            ? initialCurrencyCode
            : ApacI18nCurrencyService.resolveLocale(initialLocaleTag)
                .defaultCurrencyCode,
        _targetRegion = initialRegionCode != null &&
                ApacI18nCurrencyService.isSupportedRegion(initialRegionCode)
            ? initialRegionCode
            : ApacI18nCurrencyService.resolveLocale(initialLocaleTag)
                .regionCode,
        _isFinancialEstimate = initialIsFinancialEstimate;

  String _localeTag;
  String _currencyCode;
  String _targetRegion;
  bool _isFinancialEstimate;

  String get localeTag => _localeTag;
  ApacLocaleConfig get localeConfig =>
      ApacI18nCurrencyService.resolveLocale(_localeTag);
  Locale get flutterLocale => localeConfig.flutterLocale;
  String get currencyCode => _currencyCode;
  ApacCurrencyConfig get currencyConfig =>
      ApacI18nCurrencyService.resolveCurrency(_currencyCode);
  String get targetRegion => _targetRegion;
  bool get isFinancialEstimate => _isFinancialEstimate;
  ApacUiStrings get strings => ApacI18nCurrencyService.stringsFor(_localeTag);

  void setLocale(
    String nextLocaleTag, {
    bool syncRegionAndCurrency = true,
  }) {
    final resolved = ApacI18nCurrencyService.resolveLocale(nextLocaleTag);
    final nextTag = resolved.localeTag;
    final nextRegion =
        syncRegionAndCurrency ? resolved.regionCode : _targetRegion;
    final nextCurrency =
        syncRegionAndCurrency ? resolved.defaultCurrencyCode : _currencyCode;

    if (_localeTag == nextTag &&
        _targetRegion == nextRegion &&
        _currencyCode == nextCurrency) {
      return;
    }
    _localeTag = nextTag;
    _targetRegion = nextRegion;
    _currencyCode = nextCurrency;
    notifyListeners();
  }

  void setCurrency(String nextCurrencyCode) {
    if (!ApacI18nCurrencyService.isSupportedCurrency(nextCurrencyCode) ||
        _currencyCode == nextCurrencyCode) {
      return;
    }
    _currencyCode = nextCurrencyCode;
    notifyListeners();
  }

  void setTargetRegion(String nextRegionCode) {
    if (!ApacI18nCurrencyService.isSupportedRegion(nextRegionCode) ||
        _targetRegion == nextRegionCode) {
      return;
    }
    _targetRegion = nextRegionCode;
    notifyListeners();
  }

  void setFinancialEstimate({required bool enabled}) {
    if (_isFinancialEstimate == enabled) {
      return;
    }
    _isFinancialEstimate = enabled;
    notifyListeners();
  }

  String formatAmount(
    num amount, {
    String? currencyCode,
    String? localeTag,
  }) {
    return ApacI18nCurrencyService.formatCurrency(
      amount: amount,
      currencyCode: currencyCode ?? _currencyCode,
      localeTag: localeTag ?? _localeTag,
    );
  }
}

/// `regional_knowledge_documents` および `notes` メタデータを操作する
/// 遅延解決型 Supabase リポジトリ (#2594)。
class ApacRegionalKnowledgeRepository {
  const ApacRegionalKnowledgeRepository({
    SupabaseClient Function()? clientResolver,
  }) : _clientResolver = clientResolver;

  final SupabaseClient Function()? _clientResolver;

  SupabaseClient _resolveClient() {
    final resolver = _clientResolver;
    if (resolver != null) {
      return resolver();
    }
    return Supabase.instance.client;
  }

  Future<List<RegionalDocumentMetadata>> fetchDocuments({
    int limit = 30,
  }) async {
    final rows = await _resolveClient()
        .from('regional_knowledge_documents')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(RegionalDocumentMetadata.fromJson).toList(growable: false);
  }

  Future<RegionalDocumentMetadata> insertDocument(
    RegionalDocumentMetadata document,
  ) async {
    final payload = document.toJson();
    final inserted = await _resolveClient()
        .from('regional_knowledge_documents')
        .insert(payload)
        .select()
        .single();
    return RegionalDocumentMetadata.fromJson(inserted);
  }

  Future<void> updateNoteRegionalMetadata({
    required int noteId,
    required RegionalDocumentMetadata metadata,
  }) async {
    await _resolveClient()
        .from('notes')
        .update(metadata.toNoteMetadataPayload())
        .eq('id', noteId);
  }
}

double? _parseDouble(Object? raw) {
  if (raw is double) return raw;
  if (raw is int) return raw.toDouble();
  if (raw is num) return raw.toDouble();
  if (raw is String) return double.tryParse(raw.trim());
  return null;
}
