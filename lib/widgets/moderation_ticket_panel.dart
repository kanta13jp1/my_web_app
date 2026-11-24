import 'package:flutter/material.dart';
import 'package:my_web_app/services/content_moderation_ticket_service.dart';

/// サポート画面向け コンテンツモデレーション報告 & チケット管理パネル。
@immutable
class ModerationTicketPanel extends StatefulWidget {
  const ModerationTicketPanel({
    required this.service,
    this.isModeratorMode = false,
    this.moderatorId = 'moderator-admin',
    super.key,
  });

  final ContentModerationTicketService service;
  final bool isModeratorMode;
  final String moderatorId;

  @override
  State<ModerationTicketPanel> createState() => _ModerationTicketPanelState();
}

class _ModerationTicketPanelState extends State<ModerationTicketPanel> {
  final TextEditingController _entityTypeController = TextEditingController(
    text: 'public_memo',
  );
  final TextEditingController _entityIdController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _evidenceController = TextEditingController();
  final TextEditingController _resolutionNoteController =
      TextEditingController();

  ModerationViolationCategory _selectedCategory =
      ModerationViolationCategory.spam;

  @override
  void dispose() {
    _entityTypeController.dispose();
    _entityIdController.dispose();
    _reasonController.dispose();
    _evidenceController.dispose();
    _resolutionNoteController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final ModerationTicket? created = await widget.service.submitReport(
      ModerationTicketDraft(
        targetEntityType: _entityTypeController.text,
        targetEntityId: _entityIdController.text,
        violationCategory: _selectedCategory,
        reportReason: _reasonController.text,
        evidenceReference: _evidenceController.text,
      ),
    );
    if (!mounted) {
      return;
    }
    if (created != null) {
      _entityIdController.clear();
      _reasonController.clear();
      _evidenceController.clear();
    }
  }

  Future<void> _handleTransition(
    ModerationTicket ticket,
    ModerationTicketStatus nextStatus,
  ) async {
    final bool ok = await widget.service.transitionTicketStatus(
      ticketId: ticket.id,
      nextStatus: nextStatus,
      moderatorId: widget.moderatorId,
      resolutionNote: _resolutionNoteController.text,
    );
    if (!mounted) {
      return;
    }
    if (ok &&
        (nextStatus == ModerationTicketStatus.resolved ||
            nextStatus == ModerationTicketStatus.dismissed)) {
      _resolutionNoteController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final _ModerationPalette palette = _ModerationPalette.fromBrightness(
      isDark: isDark,
    );

    return ListenableBuilder(
      listenable: widget.service,
      builder: (BuildContext context, Widget? child) {
        final List<ModerationTicket> visibleTickets =
            widget.service.filteredTickets;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: palette.panelSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: palette.borderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(Icons.shield_outlined, color: palette.primaryText),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'コンテンツモデレーション受付・対応管理',
                        softWrap: true,
                        style: TextStyle(
                          color: palette.primaryText,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '基準書に基づき、すべての報告は初期ステータス「未対応」として起票され、客観的なSLA・根拠メモに沿って処理されます。',
                  style: TextStyle(color: palette.secondaryText, fontSize: 13),
                ),
                const SizedBox(height: 14),
                _buildReportForm(palette),
                if (widget.service.validationErrors.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  _FeedbackCard(
                    key: const ValueKey<String>('moderation-validation-errors'),
                    title: '入力・操作エラー',
                    lines: widget.service.validationErrors,
                    background: palette.urgentBg,
                    foreground: palette.urgentFg,
                    border: palette.urgentBorder,
                  ),
                ],
                if (widget.service.statusBanner.isNotEmpty &&
                    widget.service.validationErrors.isEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  _FeedbackCard(
                    key: const ValueKey<String>('moderation-status-banner'),
                    title: '対応ステータス通知',
                    lines: <String>[widget.service.statusBanner],
                    background: palette.infoBg,
                    foreground: palette.infoFg,
                    border: palette.infoBorder,
                  ),
                ],
                const SizedBox(height: 16),
                _buildFilterSection(palette),
                if (widget.isModeratorMode) ...<Widget>[
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey<String>('moderation-resolution-field'),
                    controller: _resolutionNoteController,
                    decoration: const InputDecoration(
                      labelText: '管理者 措置メモ / 却下根拠（解決・却下時は必須）',
                      hintText: '確認した一次情報・措置内容を記録',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'チケット一覧 (${visibleTickets.length}件)',
                  style: TextStyle(
                    color: palette.primaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                if (visibleTickets.isEmpty)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: palette.cardSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: palette.borderColor),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        '該当するモデレーションチケットはありません。',
                        style: TextStyle(color: palette.secondaryText),
                      ),
                    ),
                  )
                else
                  ...visibleTickets.map((ModerationTicket ticket) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _TicketCard(
                        palette: palette,
                        ticket: ticket,
                        isModeratorMode: widget.isModeratorMode,
                        onTransition: (ModerationTicketStatus next) {
                          _handleTransition(ticket, next);
                        },
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReportForm(_ModerationPalette palette) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '新規報告フォーム',
              style: TextStyle(
                color: palette.primaryText,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              key: const ValueKey<String>('moderation-entity-type-field'),
              controller: _entityTypeController,
              decoration: const InputDecoration(
                labelText: '対象種別*（例: public_memo / note / comment）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              key: const ValueKey<String>('moderation-entity-id-field'),
              controller: _entityIdController,
              decoration: const InputDecoration(
                labelText: '対象コンテンツ ID*',
                hintText: '例: memo-12345',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '違反カテゴリ*（選択カテゴリの標準 SLA が自動適用されます）',
              style: TextStyle(
                color: palette.secondaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ModerationViolationCategory.values
                  .map((ModerationViolationCategory category) {
                final bool selected = _selectedCategory == category;
                return ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  child: ChoiceChip(
                    key: ValueKey<String>(
                      'moderation-category-${category.dbValue}',
                    ),
                    label: Text(
                      '${category.labelJa} (${category.slaHours}h)',
                      style: TextStyle(
                        color: selected
                            ? palette.chipSelectedFg
                            : palette.primaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    selected: selected,
                    selectedColor: palette.chipSelectedBg,
                    backgroundColor: palette.cardSurface,
                    side: BorderSide(
                      color: selected
                          ? palette.chipSelectedBorder
                          : palette.borderColor,
                    ),
                    onSelected: (bool isSelected) {
                      if (!isSelected) {
                        return;
                      }
                      setState(() {
                        _selectedCategory = category;
                      });
                    },
                  ),
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey<String>('moderation-reason-field'),
              controller: _reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '報告理由・事実関係*',
                hintText: '該当箇所や具体的な違反事実を記載してください',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              key: const ValueKey<String>('moderation-evidence-field'),
              controller: _evidenceController,
              decoration: const InputDecoration(
                labelText: '参照リンク・証跡メモ（任意）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: <Widget>[
                ConstrainedBox(
                  constraints:
                      const BoxConstraints(minWidth: 48, minHeight: 48),
                  child: FilledButton.icon(
                    key: const ValueKey<String>('moderation-submit-button'),
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.primaryButtonBg,
                      foregroundColor: palette.primaryButtonFg,
                    ),
                    onPressed: widget.service.isBusy ? null : _handleSubmit,
                    icon: const Icon(Icons.report_gmailerrorred_outlined),
                    label: Text(
                      widget.service.isBusy ? '送信中...' : '通報チケットを送信',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection(_ModerationPalette palette) {
    final ModerationTicketStatus? currentFilter = widget.service.statusFilter;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: ChoiceChip(
            key: const ValueKey<String>('moderation-filter-all'),
            label: Text(
              'すべて',
              style: TextStyle(
                color: currentFilter == null
                    ? palette.chipSelectedFg
                    : palette.primaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
            selected: currentFilter == null,
            selectedColor: palette.chipSelectedBg,
            backgroundColor: palette.cardSurface,
            side: BorderSide(
              color: currentFilter == null
                  ? palette.chipSelectedBorder
                  : palette.borderColor,
            ),
            onSelected: (bool selected) {
              if (selected) {
                widget.service.setStatusFilter(null);
              }
            },
          ),
        ),
        ...ModerationTicketStatus.values.map((ModerationTicketStatus status) {
          final bool selected = currentFilter == status;
          return ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: ChoiceChip(
              key: ValueKey<String>('moderation-filter-${status.dbValue}'),
              label: Text(
                status.labelJa,
                style: TextStyle(
                  color:
                      selected ? palette.chipSelectedFg : palette.primaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              selected: selected,
              selectedColor: palette.chipSelectedBg,
              backgroundColor: palette.cardSurface,
              side: BorderSide(
                color:
                    selected ? palette.chipSelectedBorder : palette.borderColor,
              ),
              onSelected: (bool isSelected) {
                if (isSelected) {
                  widget.service.setStatusFilter(status);
                }
              },
            ),
          );
        }),
      ],
    );
  }
}

@immutable
class _TicketCard extends StatelessWidget {
  const _TicketCard({
    required this.palette,
    required this.ticket,
    required this.isModeratorMode,
    required this.onTransition,
  });

  final _ModerationPalette palette;
  final ModerationTicket ticket;
  final bool isModeratorMode;
  final void Function(ModerationTicketStatus next) onTransition;

  @override
  Widget build(BuildContext context) {
    final bool isUrgentOrHigh = ticket.severity == ModerationSeverity.high ||
        ticket.severity == ModerationSeverity.urgent;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${ticket.targetEntityType}: ${ticket.targetEntityId}',
                    softWrap: true,
                    style: TextStyle(
                      color: palette.primaryText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: <Widget>[
                _StatusPill(
                  label: ticket.ticketStatus.labelJa,
                  background: palette.infoBg,
                  foreground: palette.infoFg,
                  border: palette.infoBorder,
                ),
                _StatusPill(
                  label: '重大度: ${ticket.severity.labelJa}',
                  background: isUrgentOrHigh ? palette.urgentBg : palette.okBg,
                  foreground: isUrgentOrHigh ? palette.urgentFg : palette.okFg,
                  border:
                      isUrgentOrHigh ? palette.urgentBorder : palette.okBorder,
                ),
                _StatusPill(
                  label: ticket.violationCategory.labelJa,
                  background: palette.panelSurface,
                  foreground: palette.primaryText,
                  border: palette.borderColor,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              ticket.reportReason,
              style: TextStyle(color: palette.secondaryText, fontSize: 13),
            ),
            if (ticket.resolutionNote != null &&
                ticket.resolutionNote!.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                '措置メモ: ${ticket.resolutionNote}',
                style: TextStyle(
                  color: palette.okFg,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (isModeratorMode) ...<Widget>[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  if (ModerationPolicyEvaluator.canTransitionStatus(
                    from: ticket.ticketStatus,
                    to: ModerationTicketStatus.inReview,
                  ))
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      child: OutlinedButton(
                        key: ValueKey<String>(
                          'moderation-review-${ticket.id}',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: palette.primaryText,
                          side: BorderSide(color: palette.borderColor),
                        ),
                        onPressed: () {
                          onTransition(ModerationTicketStatus.inReview);
                        },
                        child: const Text('確認開始'),
                      ),
                    ),
                  if (ModerationPolicyEvaluator.canTransitionStatus(
                    from: ticket.ticketStatus,
                    to: ModerationTicketStatus.resolved,
                  ))
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      child: FilledButton(
                        key: ValueKey<String>(
                          'moderation-resolve-${ticket.id}',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: palette.primaryButtonBg,
                          foregroundColor: palette.primaryButtonFg,
                        ),
                        onPressed: () {
                          onTransition(ModerationTicketStatus.resolved);
                        },
                        child: const Text('解決済みにする'),
                      ),
                    ),
                  if (ModerationPolicyEvaluator.canTransitionStatus(
                    from: ticket.ticketStatus,
                    to: ModerationTicketStatus.dismissed,
                  ))
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      child: OutlinedButton(
                        key: ValueKey<String>(
                          'moderation-dismiss-${ticket.id}',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: palette.urgentFg,
                          side: BorderSide(color: palette.urgentBorder),
                        ),
                        onPressed: () {
                          onTransition(ModerationTicketStatus.dismissed);
                        },
                        child: const Text('却下'),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

@immutable
class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.background,
    required this.foreground,
    required this.border,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            color: foreground,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

@immutable
class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({
    required this.title,
    required this.lines,
    required this.background,
    required this.foreground,
    required this.border,
    super.key,
  });

  final String title;
  final List<String> lines;
  final Color background;
  final Color foreground;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.info_outline, color: foreground, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    softWrap: true,
                    style: TextStyle(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...lines.map(
              (String line) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '• $line',
                  style: TextStyle(color: foreground, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

@immutable
class _ModerationPalette {
  const _ModerationPalette({
    required this.panelSurface,
    required this.cardSurface,
    required this.primaryText,
    required this.secondaryText,
    required this.borderColor,
    required this.urgentBg,
    required this.urgentFg,
    required this.urgentBorder,
    required this.infoBg,
    required this.infoFg,
    required this.infoBorder,
    required this.okBg,
    required this.okFg,
    required this.okBorder,
    required this.primaryButtonBg,
    required this.primaryButtonFg,
    required this.chipSelectedBg,
    required this.chipSelectedFg,
    required this.chipSelectedBorder,
  });

  final Color panelSurface;
  final Color cardSurface;
  final Color primaryText;
  final Color secondaryText;
  final Color borderColor;
  final Color urgentBg;
  final Color urgentFg;
  final Color urgentBorder;
  final Color infoBg;
  final Color infoFg;
  final Color infoBorder;
  final Color okBg;
  final Color okFg;
  final Color okBorder;
  final Color primaryButtonBg;
  final Color primaryButtonFg;
  final Color chipSelectedBg;
  final Color chipSelectedFg;
  final Color chipSelectedBorder;

  factory _ModerationPalette.fromBrightness({required bool isDark}) {
    if (isDark) {
      return const _ModerationPalette(
        panelSurface: Color(0xFF0F172A),
        cardSurface: Color(0xFF111827),
        primaryText: Color(0xFFF8FAFC),
        secondaryText: Color(0xFFE2E8F0),
        borderColor: Color(0xFF64748B),
        urgentBg: Color(0xFF450A0A),
        urgentFg: Color(0xFFFEE2E2),
        urgentBorder: Color(0xFFF87171),
        infoBg: Color(0xFF1E3A8A),
        infoFg: Color(0xFFEFF6FF),
        infoBorder: Color(0xFF93C5FD),
        okBg: Color(0xFF052E16),
        okFg: Color(0xFFDCFCE7),
        okBorder: Color(0xFF4ADE80),
        primaryButtonBg: Color(0xFF93C5FD),
        primaryButtonFg: Color(0xFF0F172A),
        chipSelectedBg: Color(0xFF1E3A8A),
        chipSelectedFg: Color(0xFFF8FAFC),
        chipSelectedBorder: Color(0xFF93C5FD),
      );
    }
    return const _ModerationPalette(
      panelSurface: Color(0xFFF8FAFC),
      cardSurface: Color(0xFFFFFFFF),
      primaryText: Color(0xFF0F172A),
      secondaryText: Color(0xFF1E293B),
      borderColor: Color(0xFF475569),
      urgentBg: Color(0xFFFEE2E2),
      urgentFg: Color(0xFF7F1D1D),
      urgentBorder: Color(0xFFB91C1C),
      infoBg: Color(0xFFDBEAFE),
      infoFg: Color(0xFF1E3A8A),
      infoBorder: Color(0xFF1E40AF),
      okBg: Color(0xFFDCFCE7),
      okFg: Color(0xFF14532D),
      okBorder: Color(0xFF15803D),
      primaryButtonBg: Color(0xFF1E40AF),
      primaryButtonFg: Color(0xFFFFFFFF),
      chipSelectedBg: Color(0xFFDBEAFE),
      chipSelectedFg: Color(0xFF1E3A8A),
      chipSelectedBorder: Color(0xFF1E40AF),
    );
  }
}
