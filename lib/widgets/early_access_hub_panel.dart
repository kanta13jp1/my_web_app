import 'package:flutter/material.dart';

import '../services/early_access_feature_service.dart';

/// 段階的アーリーアクセス権限バッジ、開発中フィーチャーフラグ切替、
/// および GitHub Issues 直結フィードバック送信フォームを提供するパネル。
class EarlyAccessHubPanel extends StatefulWidget {
  const EarlyAccessHubPanel({
    super.key,
    required this.service,
  });

  final EarlyAccessFeatureService service;

  @override
  State<EarlyAccessHubPanel> createState() => _EarlyAccessHubPanelState();
}

class _EarlyAccessHubPanelState extends State<EarlyAccessHubPanel> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();

  late String _selectedFlagKey;
  EarlyAccessFeedbackCategory _selectedCategory =
      EarlyAccessFeedbackCategory.feedback;

  @override
  void initState() {
    super.initState();
    _selectedFlagKey = widget.service.catalog.isNotEmpty
        ? widget.service.catalog.first.flagKey
        : '';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (_selectedFlagKey.isEmpty) {
      return;
    }
    final EarlyAccessFeedbackRecord? created =
        await widget.service.submitFeedback(
      flagKey: _selectedFlagKey,
      category: _selectedCategory,
      title: _titleController.text,
      body: _bodyController.text,
    );
    if (created != null && mounted) {
      _titleController.clear();
      _bodyController.clear();
    }
  }

  String _shortFlagLabel(EarlyAccessFeatureFlag flag) {
    final String raw = flag.title.split('(').first.trim();
    if (raw.length <= 6) {
      return raw;
    }
    return '${raw.substring(0, 5)}…';
  }

  @override
  Widget build(BuildContext context) {
    final _EarlyAccessPalette palette = _EarlyAccessPalette.fromBrightness(
      Theme.of(context).brightness,
    );

    return ListenableBuilder(
      listenable: widget.service,
      builder: (BuildContext context, Widget? child) {
        final EarlyAccessTier activeTier = widget.service.effectiveTier;
        final List<EarlyAccessFeatureFlag> catalog = widget.service.catalog;
        final bool hasSelectedInCatalog = catalog.any(
          (EarlyAccessFeatureFlag f) => f.flagKey == _selectedFlagKey,
        );
        if (!hasSelectedInCatalog && catalog.isNotEmpty) {
          _selectedFlagKey = catalog.first.flagKey;
        }
        final int queuedCount = widget.service.feedbackRecords
            .where(
              (EarlyAccessFeedbackRecord r) =>
                  r.syncStatus == EarlyAccessSyncStatus.queuedOffline,
            )
            .length;

        return DecoratedBox(
          decoration: BoxDecoration(
            color: palette.panelSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: palette.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _buildHeaderCard(palette, activeTier),
                const SizedBox(height: 12),
                _buildNonMonetizedNoticeBanner(palette),
                if (widget.service.statusMessage.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  _buildStatusBanner(palette, widget.service.statusMessage),
                ],
                const SizedBox(height: 16),
                Text(
                  '開発中フィーチャーフラグ一覧',
                  style: TextStyle(
                    color: palette.primaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                ...catalog.map(
                  (EarlyAccessFeatureFlag flag) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildFlagCard(palette, flag),
                  ),
                ),
                const SizedBox(height: 8),
                _buildFeedbackFormSection(palette, catalog),
                if (widget.service.feedbackRecords.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  _buildFeedbackHistorySection(palette, queuedCount),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard(
    _EarlyAccessPalette palette,
    EarlyAccessTier activeTier,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Icon(Icons.science_outlined, color: palette.primaryText),
                Text(
                  'アーリーアクセス・ラボ',
                  style: TextStyle(
                    color: palette.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                DecoratedBox(
                  key: const ValueKey<String>('early-access-tier-badge'),
                  decoration: BoxDecoration(
                    color: palette.infoBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: palette.infoBorder),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    child: Text(
                      activeTier.badgeLabel,
                      style: TextStyle(
                        color: palette.infoFg,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '現在の権限: ${activeTier.labelJa} — ${activeTier.summaryJa}',
              softWrap: true,
              style: TextStyle(color: palette.secondaryText),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: OutlinedButton(
                key: const ValueKey<String>('refresh-tier-button'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.primaryText,
                  backgroundColor: palette.panelSurface,
                  side: BorderSide(color: palette.border),
                ),
                onPressed: widget.service.refreshAppMetadataAccess,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.verified_user_outlined),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '権限を再評価',
                        softWrap: true,
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
  }

  Widget _buildNonMonetizedNoticeBanner(_EarlyAccessPalette palette) {
    return DecoratedBox(
      key: const ValueKey<String>('early-access-non-monetized-banner'),
      decoration: BoxDecoration(
        color: palette.warnBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.warnBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Text(
          '非課金・招待オプトイン限定: 本プログラムには決済・課金機能は含まれません。'
          '将来有料ティアを導入する場合は第三者決済規約および法的審査を別途実施します。',
          softWrap: true,
          style: TextStyle(color: palette.warnFg),
        ),
      ),
    );
  }

  Widget _buildStatusBanner(_EarlyAccessPalette palette, String message) {
    return DecoratedBox(
      key: const ValueKey<String>('early-access-status-banner'),
      decoration: BoxDecoration(
        color: palette.infoBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.infoBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Text(
          message,
          softWrap: true,
          style: TextStyle(color: palette.infoFg),
        ),
      ),
    );
  }

  Widget _buildFlagCard(
    _EarlyAccessPalette palette,
    EarlyAccessFeatureFlag flag,
  ) {
    final bool unlocked = widget.service.isFlagUnlocked(flag);
    final bool optedIn = widget.service.isFlagOptedIn(flag.flagKey);

    return DecoratedBox(
      key: ValueKey<String>('flag-card-${flag.flagKey}'),
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: unlocked ? palette.okBorder : palette.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        flag.title,
                        softWrap: true,
                        style: TextStyle(
                          color: palette.primaryText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: <Widget>[
                          _buildPill(
                            text: '${flag.minTier.badgeLabel} 以上',
                            bg: palette.infoBg,
                            fg: palette.infoFg,
                            border: palette.infoBorder,
                          ),
                          _buildPill(
                            text: unlocked ? '利用可能' : '上位ティア限定',
                            bg: unlocked ? palette.okBg : palette.lockedBg,
                            fg: unlocked ? palette.okFg : palette.lockedFg,
                            border:
                                unlocked ? palette.okBorder : palette.border,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                MergeSemantics(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Semantics(
                        label: '${flag.title} の試験機能を有効化',
                        child: const SizedBox.shrink(),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        child: Switch(
                          key: ValueKey<String>('flag-switch-${flag.flagKey}'),
                          value: optedIn,
                          onChanged: unlocked
                              ? (bool next) => widget.service.toggleFeatureFlag(
                                    flag.flagKey,
                                    next,
                                  )
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              flag.description,
              softWrap: true,
              style: TextStyle(color: palette.secondaryText),
            ),
            if (unlocked) ...<Widget>[
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                child: OutlinedButton(
                  key: ValueKey<String>('flag-feedback-btn-${flag.flagKey}'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.primaryText,
                    backgroundColor: palette.panelSurface,
                    side: BorderSide(color: palette.border),
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedFlagKey = flag.flagKey;
                    });
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          'フィードバックを書く',
                          softWrap: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPill({
    required String text,
    required Color bg,
    required Color fg,
    required Color border,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          text,
          softWrap: true,
          style: TextStyle(
            color: fg,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackFormSection(
    _EarlyAccessPalette palette,
    List<EarlyAccessFeatureFlag> catalog,
  ) {
    return DecoratedBox(
      key: const ValueKey<String>('early-access-feedback-form'),
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'GitHub Issues 直結フィードバック送信',
              style: TextStyle(
                color: palette.primaryText,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '対象フラグ',
              style: TextStyle(
                color: palette.secondaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: catalog.map((EarlyAccessFeatureFlag flag) {
                final bool selected = flag.flagKey == _selectedFlagKey;
                return ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  child: ChoiceChip(
                    key: ValueKey<String>('feedback-flag-chip-${flag.flagKey}'),
                    selected: selected,
                    backgroundColor: palette.panelSurface,
                    selectedColor: palette.chipSelectedBg,
                    checkmarkColor: palette.chipSelectedFg,
                    side: BorderSide(color: palette.border),
                    label: Text(
                      _shortFlagLabel(flag),
                      softWrap: true,
                      style: TextStyle(
                        color: selected
                            ? palette.chipSelectedFg
                            : palette.primaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onSelected: (bool value) {
                      if (value) {
                        setState(() {
                          _selectedFlagKey = flag.flagKey;
                        });
                      }
                    },
                  ),
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: 10),
            Text(
              'フィードバック種別',
              style: TextStyle(
                color: palette.secondaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: EarlyAccessFeedbackCategory.values.map(
                (EarlyAccessFeedbackCategory cat) {
                  final bool selected = cat == _selectedCategory;
                  return ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    child: ChoiceChip(
                      key: ValueKey<String>(
                        'feedback-category-${cat.dbValue}',
                      ),
                      selected: selected,
                      backgroundColor: palette.panelSurface,
                      selectedColor: palette.chipSelectedBg,
                      checkmarkColor: palette.chipSelectedFg,
                      side: BorderSide(color: palette.border),
                      label: Text(
                        cat.labelJa,
                        style: TextStyle(
                          color: selected
                              ? palette.chipSelectedFg
                              : palette.primaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onSelected: (bool value) {
                        if (value) {
                          setState(() {
                            _selectedCategory = cat;
                          });
                        }
                      },
                    ),
                  );
                },
              ).toList(growable: false),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey<String>('feedback-title-field'),
              controller: _titleController,
              style: TextStyle(color: palette.primaryText),
              decoration: InputDecoration(
                filled: true,
                fillColor: palette.panelSurface,
                labelText: '件名 (4文字以上)',
                labelStyle: TextStyle(color: palette.secondaryText),
                hintText: '例: 音声マクロの停止操作',
                hintMaxLines: 2,
                hintStyle: TextStyle(color: palette.secondaryText),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: palette.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: palette.infoBorder, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              key: const ValueKey<String>('feedback-body-field'),
              controller: _bodyController,
              maxLines: 3,
              style: TextStyle(color: palette.primaryText),
              decoration: InputDecoration(
                filled: true,
                fillColor: palette.panelSurface,
                labelText: '詳細フィードバック (10文字以上)',
                labelStyle: TextStyle(color: palette.secondaryText),
                hintText: '再現手順や改善提案を入力すると GitHub Issue へ送信されます',
                hintMaxLines: 2,
                hintStyle: TextStyle(color: palette.secondaryText),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: palette.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: palette.infoBorder, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: ElevatedButton(
                key: const ValueKey<String>('feedback-submit-button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.primaryBtnBg,
                  foregroundColor: palette.primaryBtnFg,
                ),
                onPressed: widget.service.isSubmittingFeedback
                    ? null
                    : _submitFeedback,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.send_outlined),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        widget.service.isSubmittingFeedback
                            ? '送信中...'
                            : 'Issue へ送信',
                        softWrap: true,
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
  }

  Widget _buildFeedbackHistorySection(
    _EarlyAccessPalette palette,
    int queuedCount,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  '送信履歴',
                  style: TextStyle(
                    color: palette.primaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (queuedCount > 0)
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    child: OutlinedButton(
                      key: const ValueKey<String>('retry-feedback-button'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.primaryText,
                        backgroundColor: palette.panelSurface,
                        side: BorderSide(color: palette.border),
                      ),
                      onPressed: widget.service.retryPendingFeedback,
                      child: Text('待機中 $queuedCount 件を再送信'),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ...widget.service.feedbackRecords.map(
              (EarlyAccessFeedbackRecord record) {
                final bool synced =
                    record.syncStatus == EarlyAccessSyncStatus.synced;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: palette.panelSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: palette.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            record.title,
                            softWrap: true,
                            style: TextStyle(
                              color: palette.primaryText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: <Widget>[
                              _buildPill(
                                text: record.category.labelJa,
                                bg: palette.infoBg,
                                fg: palette.infoFg,
                                border: palette.infoBorder,
                              ),
                              _buildPill(
                                text: record.githubIssueNumber != null
                                    ? 'Issue #${record.githubIssueNumber}'
                                    : record.syncStatus.labelJa,
                                bg: synced ? palette.okBg : palette.warnBg,
                                fg: synced ? palette.okFg : palette.warnFg,
                                border: synced
                                    ? palette.okBorder
                                    : palette.warnBorder,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EarlyAccessPalette {
  const _EarlyAccessPalette({
    required this.panelSurface,
    required this.cardSurface,
    required this.border,
    required this.primaryText,
    required this.secondaryText,
    required this.infoBg,
    required this.infoFg,
    required this.infoBorder,
    required this.okBg,
    required this.okFg,
    required this.okBorder,
    required this.warnBg,
    required this.warnFg,
    required this.warnBorder,
    required this.lockedBg,
    required this.lockedFg,
    required this.primaryBtnBg,
    required this.primaryBtnFg,
    required this.chipSelectedBg,
    required this.chipSelectedFg,
  });

  final Color panelSurface;
  final Color cardSurface;
  final Color border;
  final Color primaryText;
  final Color secondaryText;
  final Color infoBg;
  final Color infoFg;
  final Color infoBorder;
  final Color okBg;
  final Color okFg;
  final Color okBorder;
  final Color warnBg;
  final Color warnFg;
  final Color warnBorder;
  final Color lockedBg;
  final Color lockedFg;
  final Color primaryBtnBg;
  final Color primaryBtnFg;
  final Color chipSelectedBg;
  final Color chipSelectedFg;

  static _EarlyAccessPalette fromBrightness(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const _EarlyAccessPalette(
        panelSurface: Color(0xFF090D16),
        cardSurface: Color(0xFF111827),
        border: Color(0xFFCBD5E1),
        primaryText: Color(0xFFF8FAFC),
        secondaryText: Color(0xFFE2E8F0),
        infoBg: Color(0xFF1E3A8A),
        infoFg: Color(0xFFDBEAFE),
        infoBorder: Color(0xFF93C5FD),
        okBg: Color(0xFF064E3B),
        okFg: Color(0xFFECFDF5),
        okBorder: Color(0xFF6EE7B7),
        warnBg: Color(0xFF78350F),
        warnFg: Color(0xFFFEF3C7),
        warnBorder: Color(0xFFFCD34D),
        lockedBg: Color(0xFF1E293B),
        lockedFg: Color(0xFFF1F5F9),
        primaryBtnBg: Color(0xFF93C5FD),
        primaryBtnFg: Color(0xFF090D16),
        chipSelectedBg: Color(0xFF93C5FD),
        chipSelectedFg: Color(0xFF090D16),
      );
    }
    return const _EarlyAccessPalette(
      panelSurface: Color(0xFFFFFFFF),
      cardSurface: Color(0xFFF8FAFC),
      border: Color(0xFF475569),
      primaryText: Color(0xFF0F172A),
      secondaryText: Color(0xFF1E293B),
      infoBg: Color(0xFFDBEAFE),
      infoFg: Color(0xFF1E3A8A),
      infoBorder: Color(0xFF1E40AF),
      okBg: Color(0xFFDCFCE7),
      okFg: Color(0xFF14532D),
      okBorder: Color(0xFF15803D),
      warnBg: Color(0xFFFEF3C7),
      warnFg: Color(0xFF78350F),
      warnBorder: Color(0xFFB45309),
      lockedBg: Color(0xFFE2E8F0),
      lockedFg: Color(0xFF0F172A),
      primaryBtnBg: Color(0xFF1E3A8A),
      primaryBtnFg: Color(0xFFFFFFFF),
      chipSelectedBg: Color(0xFF1E3A8A),
      chipSelectedFg: Color(0xFFFFFFFF),
    );
  }
}
