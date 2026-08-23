import 'design_compliance_data.dart';

enum UiImprovementStage {
  applied,
  inProgress,
  planned,
}

enum UiImprovementAdoption {
  applied,
  inProgress,
  planned,
}

class UiImprovementRollout {
  const UiImprovementRollout({
    required this.stage,
    required this.figmaMcp,
    required this.aiDesignerMcp,
    required this.designSkills,
    required this.designMd,
    required this.headline,
    required this.nextStep,
    this.updatedAt,
  });

  final UiImprovementStage stage;
  final UiImprovementAdoption figmaMcp;
  final UiImprovementAdoption aiDesignerMcp;
  final UiImprovementAdoption designSkills;
  final UiImprovementAdoption designMd;
  final String headline;
  final String nextStep;
  final String? updatedAt;
}

const Map<String, UiImprovementRollout> kUiImprovementRolloutOverrides =
    <String, UiImprovementRollout>{
  '/ui-design-status': UiImprovementRollout(
    stage: UiImprovementStage.applied,
    figmaMcp: UiImprovementAdoption.applied,
    aiDesignerMcp: UiImprovementAdoption.applied,
    designSkills: UiImprovementAdoption.applied,
    designMd: UiImprovementAdoption.applied,
    headline:
        'Screen inventory, rollout state, and audit score are visible on the site.',
    nextStep:
        'Expand the same workflow to more screen groups and keep the inventory current.',
    updatedAt: '2026-04-07',
  ),
  '/work-menu': UiImprovementRollout(
    stage: UiImprovementStage.applied,
    figmaMcp: UiImprovementAdoption.applied,
    aiDesignerMcp: UiImprovementAdoption.applied,
    designSkills: UiImprovementAdoption.applied,
    designMd: UiImprovementAdoption.applied,
    headline:
        'The main navigation now includes a direct entry to the rollout dashboard.',
    nextStep: 'Add stronger priority indicators by section.',
    updatedAt: '2026-04-07',
  ),
  '/guitar-recording-studio': UiImprovementRollout(
    stage: UiImprovementStage.applied,
    figmaMcp: UiImprovementAdoption.applied,
    aiDesignerMcp: UiImprovementAdoption.applied,
    designSkills: UiImprovementAdoption.applied,
    designMd: UiImprovementAdoption.applied,
    headline:
        'The recording studio is treated as a primary screen in the new UI workflow.',
    nextStep: 'Keep refining history cards and the AI feedback flow.',
    updatedAt: '2026-04-07',
  ),
  '/public-guitar-gallery': UiImprovementRollout(
    stage: UiImprovementStage.inProgress,
    figmaMcp: UiImprovementAdoption.inProgress,
    aiDesignerMcp: UiImprovementAdoption.applied,
    designSkills: UiImprovementAdoption.applied,
    designMd: UiImprovementAdoption.applied,
    headline:
        'The public gallery is being aligned with the upgraded recording flow.',
    nextStep: 'Tighten density and sharing UX with a Figma-backed pass.',
    updatedAt: '2026-04-07',
  ),
  '/landing': UiImprovementRollout(
    stage: UiImprovementStage.inProgress,
    figmaMcp: UiImprovementAdoption.applied,
    aiDesignerMcp: UiImprovementAdoption.inProgress,
    designSkills: UiImprovementAdoption.applied,
    designMd: UiImprovementAdoption.applied,
    headline:
        'The landing experience follows the new direction and is still being tuned.',
    nextStep: 'Refine hero density and comparison flow.',
    updatedAt: '2026-04-07',
  ),
  '/home': UiImprovementRollout(
    stage: UiImprovementStage.inProgress,
    figmaMcp: UiImprovementAdoption.inProgress,
    aiDesignerMcp: UiImprovementAdoption.inProgress,
    designSkills: UiImprovementAdoption.applied,
    designMd: UiImprovementAdoption.applied,
    headline:
        'The home screen now surfaces rollout coverage and screen inventory directly.',
    nextStep:
        'Keep simplifying the card hierarchy while expanding the new workflow to more high-traffic widgets.',
    updatedAt: '2026-04-08',
  ),
  '/enterprise': UiImprovementRollout(
    stage: UiImprovementStage.inProgress,
    figmaMcp: UiImprovementAdoption.inProgress,
    aiDesignerMcp: UiImprovementAdoption.planned,
    designSkills: UiImprovementAdoption.applied,
    designMd: UiImprovementAdoption.applied,
    headline:
        'Enterprise-facing marketing screens are already on the rollout track.',
    nextStep: 'Run a stronger Figma pass shared with the comparison pages.',
    updatedAt: '2026-04-07',
  ),
};

UiImprovementRollout resolveUiImprovementRollout(PageComplianceRecord record) {
  final UiImprovementRollout? override =
      kUiImprovementRolloutOverrides[record.route];
  if (override != null) {
    return override;
  }

  final bool audited = record.isAudited;
  final bool strongScore = record.score >= 0.8;

  return UiImprovementRollout(
    stage: audited ? UiImprovementStage.inProgress : UiImprovementStage.planned,
    figmaMcp: UiImprovementAdoption.planned,
    aiDesignerMcp: UiImprovementAdoption.planned,
    designSkills: strongScore
        ? UiImprovementAdoption.inProgress
        : audited
            ? UiImprovementAdoption.inProgress
            : UiImprovementAdoption.planned,
    designMd:
        audited ? UiImprovementAdoption.applied : UiImprovementAdoption.planned,
    headline: audited
        ? 'This screen already has a DESIGN.md audit and is in the rollout queue.'
        : 'This screen is not audited yet and is still in the planning queue.',
    nextStep: audited
        ? 'Apply a Figma pass and an AIDesigner exploration pass.'
        : 'Start with a DESIGN.md audit and a nearby-screen review.',
    updatedAt: record.auditDate,
  );
}
