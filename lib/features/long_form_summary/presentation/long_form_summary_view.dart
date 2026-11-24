import 'package:flutter/material.dart';

import '../domain/long_form_summary_models.dart';

/// ネットワーク・リポジトリに一切依存しない純粋 Presentational ビュー (#2642)。
/// 常に折りたたみ状態で「自動生成された要約プレビュー」を先に提示し、
/// ユーザー操作に応じて元の長文テキストを展開表示する。
class LongFormSummaryView extends StatelessWidget {
  const LongFormSummaryView({
    super.key,
    required this.items,
    required this.expandedDocumentIds,
    required this.isLoading,
    required this.isSaving,
    required this.statusMessage,
    required this.errorMessage,
    required this.titleController,
    required this.bodyController,
    required this.onSubmit,
    required this.onToggleExpand,
    required this.onRefreshSummary,
  });

  final List<LongFormDocumentWithSummary> items;
  final Set<String> expandedDocumentIds;
  final bool isLoading;
  final bool isSaving;
  final String statusMessage;
  final String errorMessage;
  final TextEditingController titleController;
  final TextEditingController bodyController;
  final VoidCallback onSubmit;
  final ValueChanged<String> onToggleExpand;
  final ValueChanged<String> onRefreshSummary;

  @override
  Widget build(BuildContext context) {
    final _LongFormPalette palette = _LongFormPalette.fromBrightness(
      Theme.of(context).brightness,
    );

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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Icon(Icons.auto_stories_outlined, color: palette.primaryText),
                Text(
                  '長文コンテンツ自動要約・プレビュー',
                  softWrap: true,
                  style: TextStyle(
                    color: palette.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (isLoading)
                  _buildPill(
                    text: '同期中',
                    bg: palette.infoBg,
                    fg: palette.infoFg,
                    border: palette.infoBorder,
                  ),
              ],
            ),
            if (statusMessage.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              _buildMessageBanner(
                key: const ValueKey<String>('long-form-status-banner'),
                text: statusMessage,
                bg: palette.infoBg,
                fg: palette.infoFg,
                border: palette.infoBorder,
              ),
            ],
            if (errorMessage.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              _buildMessageBanner(
                key: const ValueKey<String>('long-form-error-banner'),
                text: errorMessage,
                bg: palette.warnBg,
                fg: palette.warnFg,
                border: palette.warnBorder,
              ),
            ],
            const SizedBox(height: 14),
            _buildSubmitCard(palette),
            const SizedBox(height: 14),
            Text(
              '保存済みドキュメント (${items.length}件)',
              style: TextStyle(
                color: palette.primaryText,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...items.map(
              (LongFormDocumentWithSummary item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildDocumentCard(palette, item),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitCard(_LongFormPalette palette) {
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
            Text(
              '長文ドキュメント登録 (400文字以上で自動キュー登録)',
              softWrap: true,
              style: TextStyle(
                color: palette.primaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              key: const ValueKey<String>('long-form-title-field'),
              controller: titleController,
              style: TextStyle(color: palette.primaryText),
              decoration: InputDecoration(
                filled: true,
                fillColor: palette.panelSurface,
                labelText: 'タイトル',
                labelStyle: TextStyle(color: palette.secondaryText),
                hintText: '例: Self-Attention 論文ノート',
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
              key: const ValueKey<String>('long-form-body-field'),
              controller: bodyController,
              maxLines: 4,
              style: TextStyle(color: palette.primaryText),
              decoration: InputDecoration(
                filled: true,
                fillColor: palette.panelSurface,
                labelText: '長文テキスト',
                labelStyle: TextStyle(color: palette.secondaryText),
                hintText: '本文を保存するとバックグラウンドで自動要約が開始されます',
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
                key: const ValueKey<String>('long-form-submit-button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.primaryBtnBg,
                  foregroundColor: palette.primaryBtnFg,
                ),
                onPressed: isSaving ? null : onSubmit,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.summarize_outlined),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        isSaving ? '保存中...' : '保存して自動要約',
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

  Widget _buildDocumentCard(
    _LongFormPalette palette,
    LongFormDocumentWithSummary item,
  ) {
    final bool expanded = expandedDocumentIds.contains(item.documentId);
    final bool isRateLimited = item.status == LongFormSummaryStatus.rateLimited;
    final bool isCompleted = item.status == LongFormSummaryStatus.completed;

    return DecoratedBox(
      key: ValueKey<String>('long-form-card-${item.documentId}'),
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCompleted ? palette.okBorder : palette.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              item.title,
              softWrap: true,
              style: TextStyle(
                color: palette.primaryText,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                _buildPill(
                  key: ValueKey<String>('summary-status-${item.documentId}'),
                  text: isRateLimited && item.retryAfterSeconds > 0
                      ? '${item.status.labelJa} (${item.retryAfterSeconds}秒待機)'
                      : item.status.labelJa,
                  bg: isCompleted
                      ? palette.okBg
                      : (isRateLimited ? palette.warnBg : palette.infoBg),
                  fg: isCompleted
                      ? palette.okFg
                      : (isRateLimited ? palette.warnFg : palette.infoFg),
                  border: isCompleted
                      ? palette.okBorder
                      : (isRateLimited
                          ? palette.warnBorder
                          : palette.infoBorder),
                ),
                _buildPill(
                  text: '${item.charCount}文字',
                  bg: palette.panelSurface,
                  fg: palette.secondaryText,
                  border: palette.border,
                ),
              ],
            ),
            const SizedBox(height: 10),
            // 折りたたみ状態でも常に「自動生成された要約プレビュー」を先に表示する
            DecoratedBox(
              key: ValueKey<String>('summary-preview-${item.documentId}'),
              decoration: BoxDecoration(
                color: palette.panelSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: palette.infoBorder),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '自動要約プレビュー (${item.modelName})',
                      softWrap: true,
                      style: TextStyle(
                        color: palette.infoFg,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.summaryText.isNotEmpty
                          ? item.summaryText
                          : 'バックグラウンド要約ジョブが進行中または待機中です。',
                      softWrap: true,
                      style: TextStyle(color: palette.primaryText),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  child: OutlinedButton(
                    key:
                        ValueKey<String>('toggle-full-text-${item.documentId}'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.primaryText,
                      backgroundColor: palette.panelSurface,
                      side: BorderSide(color: palette.border),
                    ),
                    onPressed: () => onToggleExpand(item.documentId),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          expanded
                              ? Icons.expand_less_outlined
                              : Icons.expand_more_outlined,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            expanded ? '全文を折りたたむ' : '全文を展開する',
                            softWrap: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  child: OutlinedButton(
                    key: ValueKey<String>(
                      'refresh-summary-${item.documentId}',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.primaryText,
                      backgroundColor: palette.panelSurface,
                      side: BorderSide(color: palette.border),
                    ),
                    onPressed: () => onRefreshSummary(item.documentId),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.refresh_outlined),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '要約更新',
                            softWrap: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (expanded) ...<Widget>[
              const SizedBox(height: 10),
              DecoratedBox(
                key: ValueKey<String>('full-text-body-${item.documentId}'),
                decoration: BoxDecoration(
                  color: palette.panelSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: palette.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    item.bodyText,
                    softWrap: true,
                    style: TextStyle(color: palette.secondaryText),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBanner({
    Key? key,
    required String text,
    required Color bg,
    required Color fg,
    required Color border,
  }) {
    return DecoratedBox(
      key: key,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Text(
          text,
          softWrap: true,
          style: TextStyle(color: fg),
        ),
      ),
    );
  }

  Widget _buildPill({
    Key? key,
    required String text,
    required Color bg,
    required Color fg,
    required Color border,
  }) {
    return DecoratedBox(
      key: key,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          text,
          softWrap: true,
          style: TextStyle(
            color: fg,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _LongFormPalette {
  const _LongFormPalette({
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
    required this.primaryBtnBg,
    required this.primaryBtnFg,
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
  final Color primaryBtnBg;
  final Color primaryBtnFg;

  static _LongFormPalette fromBrightness(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const _LongFormPalette(
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
        primaryBtnBg: Color(0xFF93C5FD),
        primaryBtnFg: Color(0xFF090D16),
      );
    }
    return const _LongFormPalette(
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
      primaryBtnBg: Color(0xFF1E3A8A),
      primaryBtnFg: Color(0xFFFFFFFF),
    );
  }
}
