import 'package:flutter/material.dart';

import 'application/ai_commercial_compliance_controller.dart';
import 'data/supabase_ai_commercial_compliance_repository.dart';
import 'domain/ai_commercial_compliance_models.dart';
import 'presentation/ai_commercial_compliance_view.dart';

/// AI 生成素材の商用ライセンス・著作権コンプライアンス Container (#2664).
class AiCommercialComplianceContainer extends StatefulWidget {
  const AiCommercialComplianceContainer({
    super.key,
    this.repository,
    this.controller,
    this.autoLoad = true,
  });

  final AiCommercialComplianceRepository? repository;
  final AiCommercialComplianceController? controller;
  final bool autoLoad;

  @override
  State<AiCommercialComplianceContainer> createState() =>
      _AiCommercialComplianceContainerState();
}

class _AiCommercialComplianceContainerState
    extends State<AiCommercialComplianceContainer> {
  late final AiCommercialComplianceController _controller;
  late final bool _ownsController;
  final TextEditingController _assetTitleController = TextEditingController(
    text: '製品デモ紹介ナレーション・サムネイル一式',
  );
  final TextEditingController _adminRuleKeyController = TextEditingController();
  final TextEditingController _adminRuleTitleController =
      TextEditingController();
  final TextEditingController _adminRuleBodyController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        AiCommercialComplianceController(
          repository:
              widget.repository ?? SupabaseAiCommercialComplianceRepository(),
        );
    if (widget.autoLoad) {
      WidgetsBinding.instance.addPostFrameCallback((final Duration _) {
        if (mounted) {
          _controller.loadDashboard();
        }
      });
    }
  }

  @override
  void dispose() {
    _assetTitleController.dispose();
    _adminRuleKeyController.dispose();
    _adminRuleTitleController.dispose();
    _adminRuleBodyController.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  Future<void> _openWizardDialog() async {
    await showDialog<void>(
      context: context,
      builder: (final BuildContext dialogContext) {
        return ListenableBuilder(
          listenable: _controller,
          builder: (final BuildContext ctx, final Widget? _) {
            final AiCommercialComplianceState st = _controller.state;
            final ThemeData theme = Theme.of(ctx);
            final bool isDark = theme.brightness == Brightness.dark;
            final Color primaryInk =
                isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
            final Color secondaryInk =
                isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
            return AlertDialog(
              key: const ValueKey<String>('compliance-wizard-dialog'),
              title: Text(
                '公開前コンプライアンス確認ウィザード',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: primaryInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        '${st.selectedProvider.labelJa} / ${st.selectedPlanTier.labelJa}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: secondaryInk,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final AiComplianceRule rule in st.applicableRules)
                        CheckboxListTile(
                          key: ValueKey<String>(
                            'dialog-rule-checkbox-${rule.ruleKey}',
                          ),
                          value: st.acceptedRuleIds.contains(rule.id),
                          onChanged: (final bool? checked) {
                            _controller.toggleRuleAcceptance(
                              rule.id,
                              checked ?? false,
                            );
                          },
                          title: Text(
                            rule.title,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: primaryInk,
                            ),
                          ),
                          subtitle: Text(
                            rule.disclaimerBody,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: secondaryInk,
                            ),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('閉じる'),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: FilledButton(
                    key: const ValueKey<String>('dialog-confirm-submit-button'),
                    onPressed: st.isReadyToSubmit && !st.isSubmitting
                        ? () async {
                            final bool ok = await _controller.submitConsent(
                              assetTitle: _assetTitleController.text,
                            );
                            if (ok && dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                          }
                        : null,
                    child: const Text('全項目に同意して記録'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _handleAdminSaveRule() async {
    final bool saved = await _controller.upsertRule(
      ruleKey: _adminRuleKeyController.text,
      aiProvider: _controller.state.selectedProvider,
      title: _adminRuleTitleController.text,
      disclaimerBody: _adminRuleBodyController.text,
    );
    if (saved && mounted) {
      _adminRuleKeyController.clear();
      _adminRuleTitleController.clear();
      _adminRuleBodyController.clear();
    }
    return saved;
  }

  @override
  Widget build(final BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (final BuildContext context, final Widget? _) {
        return AiCommercialComplianceView(
          state: _controller.state,
          assetTitleController: _assetTitleController,
          adminRuleKeyController: _adminRuleKeyController,
          adminRuleTitleController: _adminRuleTitleController,
          adminRuleBodyController: _adminRuleBodyController,
          onRefresh: _controller.loadDashboard,
          onProviderChanged: _controller.setProvider,
          onPlanTierChanged: _controller.setPlanTier,
          onCommercialVerifiedChanged: _controller.setCommercialLicenseVerified,
          onCopyrightConfirmedChanged:
              _controller.setCopyrightNonSimilarityConfirmed,
          onToggleRule: _controller.toggleRuleAcceptance,
          onOpenWizardDialog: _openWizardDialog,
          onSubmit: () => _controller.submitConsent(
            assetTitle: _assetTitleController.text,
          ),
          onAdminSaveRule: _handleAdminSaveRule,
        );
      },
    );
  }
}
