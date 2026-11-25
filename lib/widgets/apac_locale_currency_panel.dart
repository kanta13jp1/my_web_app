import 'package:flutter/material.dart';

import '../services/apac_i18n_currency_service.dart';

/// APAC 多言語・多通貨切替および為替・財務推計データの要検証警告パネル (#2594)。
class ApacLocaleCurrencyPanel extends StatefulWidget {
  const ApacLocaleCurrencyPanel({
    super.key,
    this.notifier,
    this.document,
    this.baseAmountJpy = 1250000,
    this.referenceJpyPerUnitRates =
        ApacI18nCurrencyService.defaultReferenceJpyPerUnitRates,
    this.onLocaleChanged,
    this.onCurrencyChanged,
  });

  final ApacLocaleNotifier? notifier;
  final RegionalDocumentMetadata? document;
  final double baseAmountJpy;
  final Map<String, double> referenceJpyPerUnitRates;
  final ValueChanged<String>? onLocaleChanged;
  final ValueChanged<String>? onCurrencyChanged;

  @override
  State<ApacLocaleCurrencyPanel> createState() =>
      _ApacLocaleCurrencyPanelState();
}

class _ApacLocaleCurrencyPanelState extends State<ApacLocaleCurrencyPanel> {
  late ApacLocaleNotifier _notifier;
  late bool _ownsNotifier;

  ApacLocaleNotifier _createOwnedNotifier() {
    final doc = widget.document;
    if (doc == null) {
      return ApacLocaleNotifier();
    }
    return ApacLocaleNotifier(
      initialLocaleTag: doc.contentLocale,
      initialCurrencyCode: doc.baseCurrencyCode,
      initialRegionCode: doc.targetRegion,
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.notifier != null) {
      _notifier = widget.notifier!;
      _ownsNotifier = false;
    } else {
      _notifier = _createOwnedNotifier();
      _ownsNotifier = true;
    }
  }

  @override
  void didUpdateWidget(covariant ApacLocaleCurrencyPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.notifier != oldWidget.notifier) {
      if (_ownsNotifier) {
        _notifier.dispose();
      }
      if (widget.notifier != null) {
        _notifier = widget.notifier!;
        _ownsNotifier = false;
      } else {
        _notifier = _createOwnedNotifier();
        _ownsNotifier = true;
      }
    }
  }

  @override
  void dispose() {
    if (_ownsNotifier) {
      _notifier.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBackground = isDark ? const Color(0xFF141A22) : Colors.white;
    final cardBorder =
        isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    final primaryText =
        isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final secondaryText =
        isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
    final chipBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final chipBorder =
        isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8);

    // WCAG AAA (コントラスト比 >= 7.0:1) を満たす要検証警告ペア
    final warningBg =
        isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7);
    final warningFg =
        isDark ? const Color(0xFFFEF3C7) : const Color(0xFF451A03);
    final warningBorder =
        isDark ? const Color(0xFFFBBF24) : const Color(0xFF92400E);
    final warningBadgeBg =
        isDark ? const Color(0xFFFDE68A) : const Color(0xFF78350F);
    final warningBadgeFg = isDark ? const Color(0xFF451A03) : Colors.white;

    // WCAG AAA (コントラスト比 >= 7.0:1) を満たす検証済み基準通貨ペア
    final verifiedBg =
        isDark ? const Color(0xFF022C22) : const Color(0xFFD1FAE5);
    final verifiedFg =
        isDark ? const Color(0xFFD1FAE5) : const Color(0xFF064E3B);
    final verifiedBorder =
        isDark ? const Color(0xFF34D399) : const Color(0xFF065F46);

    final selectedButtonBg =
        isDark ? const Color(0xFFBFDBFE) : const Color(0xFF1E3A8A);
    final selectedButtonFg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final unselectedButtonBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final unselectedButtonFg = primaryText;

    return AnimatedBuilder(
      animation: _notifier,
      builder: (BuildContext context, Widget? _) {
        final strings = _notifier.strings;
        final doc = widget.document;
        final baseCurrency = doc?.baseCurrencyCode ??
            ApacI18nCurrencyService.defaultCurrencyCode;
        final baseAmount = doc?.amountMinorOrDecimal ?? widget.baseAmountJpy;
        final displayCurrency = _notifier.currencyCode;
        final converted = displayCurrency == baseCurrency
            ? baseAmount
            : ApacI18nCurrencyService.convertEstimatedAmount(
                amount: baseAmount,
                fromCurrencyCode: baseCurrency,
                toCurrencyCode: displayCurrency,
                jpyPerUnitRates: widget.referenceJpyPerUnitRates,
              );
        final effectiveAmount = converted ?? baseAmount;
        final formattedAmount = _notifier.formatAmount(
          effectiveAmount,
          currencyCode: displayCurrency,
        );
        final baseFormattedAmount = _notifier.formatAmount(
          baseAmount,
          currencyCode: baseCurrency,
        );
        final requiresFxWarning =
            ApacI18nCurrencyService.evaluateRequiresFxVerification(
          fxRequiresVerification: doc?.fxRequiresVerification ?? false,
          baseCurrencyCode: baseCurrency,
          displayCurrencyCode: displayCurrency,
          isFinancialEstimate: _notifier.isFinancialEstimate,
        );

        return Card(
          key: const ValueKey<String>('apac_locale_currency_panel'),
          color: cardBackground,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: cardBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.public,
                      color: primaryText,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        strings.panelTitle,
                        key: const ValueKey<String>('apac_panel_title'),
                        softWrap: true,
                        style: TextStyle(
                          color: primaryText,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  strings.panelSubtitle,
                  key: const ValueKey<String>('apac_panel_subtitle'),
                  softWrap: true,
                  style: TextStyle(
                    color: secondaryText,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                if (doc != null && doc.title.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.description_outlined,
                        color: secondaryText,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          doc.title,
                          key: const ValueKey<String>('apac_document_title'),
                          softWrap: true,
                          style: TextStyle(
                            color: primaryText,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _MetadataPill(
                      key: const ValueKey<String>(
                        'apac_region_metadata_chip',
                      ),
                      label:
                          '${strings.regionLabel}: ${_notifier.targetRegion}',
                      backgroundColor: chipBg,
                      foregroundColor: primaryText,
                      borderColor: chipBorder,
                    ),
                    _MetadataPill(
                      key: const ValueKey<String>(
                        'apac_locale_metadata_chip',
                      ),
                      label: '${strings.localeLabel}: ${_notifier.localeTag}',
                      backgroundColor: chipBg,
                      foregroundColor: primaryText,
                      borderColor: chipBorder,
                    ),
                    _MetadataPill(
                      key: const ValueKey<String>(
                        'apac_currency_metadata_chip',
                      ),
                      label: '${strings.currencyLabel}: $displayCurrency',
                      backgroundColor: chipBg,
                      foregroundColor: primaryText,
                      borderColor: chipBorder,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  strings.localeSectionLabel,
                  style: TextStyle(
                    color: primaryText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final config
                        in ApacI18nCurrencyService.supportedLocales)
                      _buildSelectorButton(
                        buttonKey: ValueKey<String>(
                          'apac_locale_button_${config.localeTag}',
                        ),
                        label: '${config.localeTag} · ${config.nativeLabel}',
                        selected: _notifier.localeTag == config.localeTag,
                        selectedBg: selectedButtonBg,
                        selectedFg: selectedButtonFg,
                        unselectedBg: unselectedButtonBg,
                        unselectedFg: unselectedButtonFg,
                        borderColor: chipBorder,
                        onPressed: () {
                          _notifier.setLocale(config.localeTag);
                          widget.onLocaleChanged?.call(config.localeTag);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  strings.currencySectionLabel,
                  style: TextStyle(
                    color: primaryText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final currency
                        in ApacI18nCurrencyService.supportedCurrencies)
                      _buildSelectorButton(
                        buttonKey: ValueKey<String>(
                          'apac_currency_button_${currency.code}',
                        ),
                        label: '${currency.code} (${currency.symbol})',
                        selected: displayCurrency == currency.code,
                        selectedBg: selectedButtonBg,
                        selectedFg: selectedButtonFg,
                        unselectedBg: unselectedButtonBg,
                        unselectedFg: unselectedButtonFg,
                        borderColor: chipBorder,
                        onPressed: () {
                          _notifier.setCurrency(currency.code);
                          widget.onCurrencyChanged?.call(currency.code);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              displayCurrency != baseCurrency
                                  ? strings.fxEstimateLabel
                                  : strings.formattedAmountLabel,
                              softWrap: true,
                              style: TextStyle(
                                color: secondaryText,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              formattedAmount,
                              key: const ValueKey<String>(
                                'apac_formatted_amount_text',
                              ),
                              softWrap: true,
                              style: TextStyle(
                                color: primaryText,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (displayCurrency != baseCurrency) ...<Widget>[
                        const SizedBox(height: 4),
                        Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                '$baseCurrency: $baseFormattedAmount -> $displayCurrency: $formattedAmount',
                                key: const ValueKey<String>(
                                  'apac_fx_converted_amount_text',
                                ),
                                softWrap: true,
                                style: TextStyle(
                                  color: secondaryText,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  child: OutlinedButton(
                    key: const ValueKey<String>('apac_estimate_toggle_button'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: unselectedButtonBg,
                      foregroundColor: unselectedButtonFg,
                      side: BorderSide(color: chipBorder),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () {
                      _notifier.setFinancialEstimate(
                        enabled: !_notifier.isFinancialEstimate,
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          _notifier.isFinancialEstimate
                              ? Icons.verified_outlined
                              : Icons.analytics_outlined,
                          size: 18,
                          color: unselectedButtonFg,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _notifier.isFinancialEstimate
                                ? strings.estimateToggleDisableLabel
                                : strings.estimateToggleEnableLabel,
                            softWrap: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (requiresFxWarning)
                  Semantics(
                    liveRegion: true,
                    container: true,
                    label:
                        '${strings.fxWarningTitle} ${strings.fxWarningDisclaimer}',
                    child: Container(
                      key: const ValueKey<String>(
                        'apac_fx_verification_warning_banner',
                      ),
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: warningBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: warningBorder,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            key: const ValueKey<String>(
                              'apac_fx_verification_warning_badge',
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: warningBadgeBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(
                                  Icons.warning_amber_rounded,
                                  size: 16,
                                  color: warningBadgeFg,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    strings.fxWarningBadge,
                                    softWrap: true,
                                    style: TextStyle(
                                      color: warningBadgeFg,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Flexible(
                                child: Text(
                                  strings.fxWarningTitle,
                                  softWrap: true,
                                  style: TextStyle(
                                    color: warningFg,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            strings.fxWarningDisclaimer,
                            softWrap: true,
                            style: TextStyle(
                              color: warningFg,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              height: 1.5,
                            ),
                          ),
                          if (doc != null &&
                              doc.verificationNote.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 8),
                            Text(
                              '${strings.verificationNoteLabel}: ${doc.verificationNote}',
                              key: const ValueKey<String>(
                                'apac_verification_note_text',
                              ),
                              softWrap: true,
                              style: TextStyle(
                                color: warningFg,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                else
                  Semantics(
                    container: true,
                    label:
                        '${strings.fxVerifiedBadge} ${strings.fxVerifiedDetail}',
                    child: Container(
                      key: const ValueKey<String>(
                        'apac_verified_base_status_badge',
                      ),
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: verifiedBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: verifiedBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Icon(
                                Icons.verified_user_outlined,
                                size: 18,
                                color: verifiedFg,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  strings.fxVerifiedBadge,
                                  softWrap: true,
                                  style: TextStyle(
                                    color: verifiedFg,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            strings.fxVerifiedDetail,
                            softWrap: true,
                            style: TextStyle(
                              color: verifiedFg,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSelectorButton({
    required Key buttonKey,
    required String label,
    required bool selected,
    required Color selectedBg,
    required Color selectedFg,
    required Color unselectedBg,
    required Color unselectedFg,
    required Color borderColor,
    required VoidCallback onPressed,
  }) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Flexible(
          child: Text(
            label,
            softWrap: true,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
        ),
      ],
    );

    if (selected) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: FilledButton(
          key: buttonKey,
          style: FilledButton.styleFrom(
            backgroundColor: selectedBg,
            foregroundColor: selectedFg,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          onPressed: onPressed,
          child: child,
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      child: OutlinedButton(
        key: buttonKey,
        style: OutlinedButton.styleFrom(
          backgroundColor: unselectedBg,
          foregroundColor: unselectedFg,
          side: BorderSide(color: borderColor),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        onPressed: onPressed,
        child: child,
      ),
    );
  }
}

class _MetadataPill extends StatelessWidget {
  const _MetadataPill({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        softWrap: true,
        style: TextStyle(
          color: foregroundColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
      ),
    );
  }
}
