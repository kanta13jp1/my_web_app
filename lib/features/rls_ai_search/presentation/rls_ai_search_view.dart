import 'package:flutter/material.dart';

import '../application/rls_ai_search_controller.dart';
import '../domain/rls_ai_search_models.dart';

/// RLS 連動 AI 検索・ライブ ACL 付与/剥奪・プロンプト参照ソース表示パネル。
class RlsAiSearchView extends StatefulWidget {
  const RlsAiSearchView({
    super.key,
    required this.controller,
  });

  final RlsAiSearchController controller;

  @override
  State<RlsAiSearchView> createState() => _RlsAiSearchViewState();
}

class _RlsAiSearchViewState extends State<RlsAiSearchView> {
  final TextEditingController _queryController = TextEditingController();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _SearchPalette palette = _SearchPalette.fromBrightness(
      Theme.of(context).brightness,
    );

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (BuildContext context, Widget? child) {
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
                _buildHeader(palette),
                const SizedBox(height: 12),
                _buildSummaryMetrics(palette),
                if (widget.controller.statusMessage.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  _buildBanner(
                    key: const ValueKey<String>('rls-search-status-banner'),
                    text: widget.controller.statusMessage,
                    bg: palette.okBg,
                    fg: palette.okFg,
                    border: palette.okBorder,
                  ),
                ],
                if (widget.controller.errorMessage.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  _buildBanner(
                    key: const ValueKey<String>('rls-search-error-banner'),
                    text: widget.controller.errorMessage,
                    bg: palette.dangerBg,
                    fg: palette.dangerFg,
                    border: palette.dangerBorder,
                  ),
                ],
                const SizedBox(height: 12),
                _buildQueryCard(palette),
                const SizedBox(height: 12),
                _buildAclControlsSection(palette),
                const SizedBox(height: 12),
                _buildPromptContextCard(palette),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(_SearchPalette palette) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Icon(Icons.verified_user_outlined, color: palette.primaryText),
        Text(
          'RLS連動 pgvector AI検索',
          style: TextStyle(
            color: palette.primaryText,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        _buildBadge(
          key: const ValueKey<String>('rls-search-header-badge'),
          label: '権限外コンテキスト完全除外',
          bg: palette.infoBg,
          fg: palette.infoFg,
          border: palette.infoBorder,
        ),
      ],
    );
  }

  Widget _buildSummaryMetrics(_SearchPalette palette) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        _buildMetricTile(
          palette,
          label: '認可済みヒット',
          value: '${widget.controller.hits.length} 件',
          bg: palette.okBg,
          fg: palette.okFg,
          border: palette.okBorder,
        ),
        _buildMetricTile(
          palette,
          label: '権限外/剥奪除外',
          value: '${widget.controller.excludedUnauthorizedCount} 件',
          bg: palette.dangerBg,
          fg: palette.dangerFg,
          border: palette.dangerBorder,
        ),
        _buildMetricTile(
          palette,
          label: '有効ACL / 剥奪',
          value:
              '${widget.controller.activeAclCount} / ${widget.controller.revokedAclCount}',
          bg: palette.infoBg,
          fg: palette.infoFg,
          border: palette.infoBorder,
        ),
      ],
    );
  }

  Widget _buildMetricTile(
    _SearchPalette palette, {
    required String label,
    required String value,
    required Color bg,
    required Color fg,
    required Color border,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner({
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
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildQueryCard(_SearchPalette palette) {
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
            TextFormField(
              key: const ValueKey<String>('rls-search-query-field'),
              controller: _queryController,
              style: TextStyle(color: palette.primaryText),
              decoration: InputDecoration(
                filled: true,
                fillColor: palette.panelSurface,
                labelText: 'AI検索クエリ（閲覧権限のあるソースのみ対象）',
                labelStyle: TextStyle(color: palette.secondaryText),
                hintText: '例: ロードマップ 予算',
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
            Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: 48,
                  minHeight: 48,
                ),
                child: ElevatedButton(
                  key: const ValueKey<String>('rls-search-submit-button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.primaryBtnBg,
                    foregroundColor: palette.primaryBtnFg,
                  ),
                  onPressed: widget.controller.isBusy
                      ? null
                      : () => widget.controller.runAuthorizedSearch(
                            query: _queryController.text,
                          ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.search_outlined),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'AIコンテキスト検索',
                          softWrap: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAclControlsSection(_SearchPalette palette) {
    final List<RlsDocumentAclEntry> entries = widget.controller.aclEntries;
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
              '外部ソース ACL 即時同期コントロール',
              style: TextStyle(
                color: palette.primaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            if (entries.isEmpty)
              Text(
                '表示可能な ACL エントリはありません。',
                softWrap: true,
                style: TextStyle(color: palette.secondaryText),
              )
            else
              ...entries.map((RlsDocumentAclEntry entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: DecoratedBox(
                    key: ValueKey<String>(
                      'rls-acl-row-${entry.id}',
                    ),
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
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: <Widget>[
                              Text(
                                '${entry.documentTitle} (${entry.externalSourceKey})',
                                softWrap: true,
                                style: TextStyle(
                                  color: palette.primaryText,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              _buildBadge(
                                label: entry.isActive ? '有効ACL' : '剥奪済み',
                                bg: entry.isActive
                                    ? palette.okBg
                                    : palette.dangerBg,
                                fg: entry.isActive
                                    ? palette.okFg
                                    : palette.dangerFg,
                                border: entry.isActive
                                    ? palette.okBorder
                                    : palette.dangerBorder,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '対象: ${entry.granteeLabel} | 権限: ${entry.permissionLevel.labelJa} | ACL v${entry.aclVersion}',
                            softWrap: true,
                            style: TextStyle(color: palette.secondaryText),
                          ),
                          const SizedBox(height: 8),
                          if (entry.canManage)
                            ConstrainedBox(
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              child: OutlinedButton(
                                key: ValueKey<String>(
                                  'rls-acl-toggle-${entry.externalSourceKey}',
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: palette.primaryText,
                                  backgroundColor: palette.cardSurface,
                                  side: BorderSide(color: palette.border),
                                ),
                                onPressed: widget.controller.isBusy
                                    ? null
                                    : () => widget.controller.toggleAclAccess(
                                          entry: entry,
                                          grantAccess: !entry.isActive,
                                        ),
                                child: Text(
                                  entry.isActive ? 'アクセス即時剥奪' : '閲覧権限を再付与',
                                  softWrap: true,
                                ),
                              ),
                            )
                          else
                            _buildBadge(
                              key: ValueKey<String>(
                                'rls-acl-readonly-${entry.externalSourceKey}',
                              ),
                              label: '閲覧専用 (所有者のみ変更可)',
                              bg: palette.infoBg,
                              fg: palette.infoFg,
                              border: palette.infoBorder,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptContextCard(_SearchPalette palette) {
    final List<RlsAiDocumentHit> hits = widget.controller.hits;
    return DecoratedBox(
      key: const ValueKey<String>('rls-prompt-context-card'),
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
            Text(
              'AIプロンプト注入済みコンテキスト (${hits.length}件)',
              style: TextStyle(
                color: palette.primaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.controller.promptContextPreview.isEmpty
                  ? '権限検証を通過した参照コンテキストはまだありません。'
                  : widget.controller.promptContextPreview,
              softWrap: true,
              style: TextStyle(color: palette.secondaryText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge({
    Key? key,
    required String label,
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
          label,
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

class _SearchPalette {
  const _SearchPalette({
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
    required this.dangerBg,
    required this.dangerFg,
    required this.dangerBorder,
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
  final Color dangerBg;
  final Color dangerFg;
  final Color dangerBorder;
  final Color primaryBtnBg;
  final Color primaryBtnFg;

  static _SearchPalette fromBrightness(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const _SearchPalette(
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
        dangerBg: Color(0xFF7F1D1D),
        dangerFg: Color(0xFFFEE2E2),
        dangerBorder: Color(0xFFFCA5A5),
        primaryBtnBg: Color(0xFF93C5FD),
        primaryBtnFg: Color(0xFF090D16),
      );
    }
    return const _SearchPalette(
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
      dangerBg: Color(0xFFFEE2E2),
      dangerFg: Color(0xFF7F1D1D),
      dangerBorder: Color(0xFFB91C1C),
      primaryBtnBg: Color(0xFF1E3A8A),
      primaryBtnFg: Color(0xFFFFFFFF),
    );
  }
}
