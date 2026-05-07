class LrmGpaGoal {
  const LrmGpaGoal({
    required this.title,
    required this.successCriteria,
    required this.constraints,
    required this.completionSignals,
  });

  final String title;
  final List<String> successCriteria;
  final List<String> constraints;
  final List<String> completionSignals;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'title': title,
    'success_criteria': successCriteria,
    'constraints': constraints,
    'completion_signals': completionSignals,
  };
}

class LrmGpaPlanStep {
  const LrmGpaPlanStep({
    required this.stepNumber,
    required this.phase,
    required this.agentSlug,
    required this.title,
    required this.requiredData,
    required this.doneWhen,
    this.toolCandidates = const <String>[],
    this.dependsOn = const <int>[],
  });

  final int stepNumber;
  final String phase;
  final String agentSlug;
  final String title;
  final List<String> requiredData;
  final String doneWhen;
  final List<String> toolCandidates;
  final List<int> dependsOn;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'step_number': stepNumber,
    'phase': phase,
    'agent_slug': agentSlug,
    'title': title,
    'required_data': requiredData,
    'done_when': doneWhen,
    'tool_candidates': toolCandidates,
    'depends_on': dependsOn,
  };
}

class LrmGpaActionDraft {
  const LrmGpaActionDraft({
    required this.kind,
    required this.ownerAgentSlug,
    required this.title,
    required this.nextAction,
    required this.acceptanceCriteria,
    required this.draftPayload,
  });

  final String kind;
  final String ownerAgentSlug;
  final String title;
  final String nextAction;
  final List<String> acceptanceCriteria;
  final Map<String, dynamic> draftPayload;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'kind': kind,
    'owner_agent_slug': ownerAgentSlug,
    'title': title,
    'next_action': nextAction,
    'acceptance_criteria': acceptanceCriteria,
    'draft_payload': draftPayload,
  };
}

class LrmSelfReview {
  const LrmSelfReview({
    required this.missingInfo,
    required this.scopeWarnings,
    required this.risks,
    required this.safetyChecks,
    required this.requiresApproval,
  });

  final List<String> missingInfo;
  final List<String> scopeWarnings;
  final List<String> risks;
  final List<String> safetyChecks;
  final bool requiresApproval;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'missing_info': missingInfo,
    'scope_warnings': scopeWarnings,
    'risks': risks,
    'safety_checks': safetyChecks,
    'requires_approval': requiresApproval,
  };
}

class LrmSelfCorrectionPlan {
  const LrmSelfCorrectionPlan({
    required this.request,
    required this.generatedAt,
    required this.strategyLabel,
    required this.goal,
    required this.plan,
    required this.actions,
    required this.selfReview,
  });

  final String request;
  final DateTime generatedAt;
  final String strategyLabel;
  final LrmGpaGoal goal;
  final List<LrmGpaPlanStep> plan;
  final List<LrmGpaActionDraft> actions;
  final LrmSelfReview selfReview;

  bool get requiresApproval => selfReview.requiresApproval;

  String get executionSummary {
    final stepLines = plan
        .map((step) => '${step.stepNumber}. ${step.agentSlug}: ${step.title}')
        .join('\n');
    final actionLines = actions
        .map((action) => '- ${action.kind}: ${action.title}')
        .join('\n');
    return [
      'LRM self-correcting GPA plan',
      'Request: $request',
      'Strategy: $strategyLabel',
      'Goal: ${goal.title}',
      stepLines,
      'Actions:',
      actionLines,
      'Requires approval: $requiresApproval',
    ].join('\n');
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'request': request,
    'generated_at': generatedAt.toIso8601String(),
    'strategy_label': strategyLabel,
    'goal': goal.toJson(),
    'plan': plan.map((step) => step.toJson()).toList(),
    'actions': actions.map((action) => action.toJson()).toList(),
    'self_review': selfReview.toJson(),
  };
}

class LrmSelfCorrectionPlannerService {
  static const List<String> _fallbackSlugs = <String>[
    'secretary',
    'planning-director',
    'product-manager',
    'cto',
    'cfo',
    'cmo',
    'legal-director',
    'cs-director',
  ];

  static const List<String> _dangerousFragments = <String>[
    'drop table',
    'truncate table',
    'delete from',
    'rm -rf',
    'sudo ',
    'secret',
    'api key',
    'password',
    'payment',
    'wire transfer',
    'publish',
    'deploy',
  ];

  static LrmSelfCorrectionPlan buildPlan({
    required String request,
    Set<String> availableAgentSlugs = const <String>{},
    DateTime? now,
  }) {
    final cleanRequest = _cleanRequest(request);
    final strategy = _detectStrategy(cleanRequest);
    final available = availableAgentSlugs.isEmpty
        ? _fallbackSlugs.toSet()
        : availableAgentSlugs;

    String pick(List<String> preferred) {
      for (final slug in preferred) {
        if (available.contains(slug)) return slug;
      }
      for (final slug in _fallbackSlugs) {
        if (available.contains(slug)) return slug;
      }
      return preferred.first;
    }

    final primary = switch (strategy) {
      _LrmPlannerStrategy.finance => pick(['cfo', 'accountant']),
      _LrmPlannerStrategy.growth => pick(['cmo', 'sales-director']),
      _LrmPlannerStrategy.engineering => pick(['cto', 'backend-dev']),
      _LrmPlannerStrategy.legal => pick(['legal-director', 'secretary']),
      _LrmPlannerStrategy.health => pick(['cho', 'chro']),
      _LrmPlannerStrategy.operations => pick([
        'planning-director',
        'cs-director',
      ]),
      _LrmPlannerStrategy.general => pick(['planning-director', 'secretary']),
    };
    final reviewer = switch (strategy) {
      _LrmPlannerStrategy.finance => pick(['accountant', 'legal-director']),
      _LrmPlannerStrategy.growth => pick(['cs-director', 'pr-director']),
      _LrmPlannerStrategy.engineering => pick([
        'backend-dev',
        'legal-director',
      ]),
      _LrmPlannerStrategy.legal => pick(['secretary', 'planning-director']),
      _LrmPlannerStrategy.health => pick(['chro', 'secretary']),
      _LrmPlannerStrategy.operations => pick(['secretary', 'product-manager']),
      _LrmPlannerStrategy.general => pick(['secretary', 'planning-director']),
    };
    final coordinator = pick(['secretary']);
    final planner = pick(['planning-director', 'product-manager']);

    final selfReview = _buildSelfReview(cleanRequest);
    final goal = LrmGpaGoal(
      title: 'GPA: ${_clip(cleanRequest, 72)}',
      successCriteria: <String>[
        'The request is converted into one measurable success condition.',
        'The first execution slice has an owner, evidence, and review gate.',
        'External writes remain draft-only until CEO approval is explicit.',
      ],
      constraints: <String>[
        'Keep the first slice executable within 24 hours.',
        'Do not create public posts, payments, deletes, deploys, or issues without explicit approval.',
        'Prefer reversible app tasks and GitHub/WBS drafts before external action.',
      ],
      completionSignals: <String>[
        'Goal, Plan, Action, and self-review JSON are available.',
        'At least one app task draft has an accountable AI officer.',
        'Risk and missing-information checks are visible before execution.',
      ],
    );

    final steps = <LrmGpaPlanStep>[
      LrmGpaPlanStep(
        stepNumber: 1,
        phase: 'goal',
        agentSlug: coordinator,
        title: 'Clarify success, constraints, and stop conditions',
        requiredData: <String>[
          'Original CEO request',
          'Deadline or desired review window',
          'Known no-go operations',
        ],
        doneWhen: 'A one-sentence goal and explicit non-goals are written.',
        toolCandidates: const <String>['agent_memory', 'notes'],
      ),
      LrmGpaPlanStep(
        stepNumber: 2,
        phase: 'plan',
        agentSlug: planner,
        title: 'Decompose into owner-ready subtasks',
        requiredData: <String>[
          'Relevant WBS or Issue links',
          'Available AI officer roster',
          'Required evidence for completion',
        ],
        doneWhen: 'Subtasks have owner, dependency, and acceptance criteria.',
        dependsOn: const <int>[1],
        toolCandidates: const <String>['wbs_draft', 'github_issue_draft'],
      ),
      LrmGpaPlanStep(
        stepNumber: 3,
        phase: 'action',
        agentSlug: primary,
        title: 'Prepare the first reversible execution slice',
        requiredData: <String>[
          'Smallest safe action',
          'Validation command or review evidence',
          'Rollback or no-op path',
        ],
        doneWhen:
            'A draft app task can be queued without external side effects.',
        dependsOn: const <int>[2],
        toolCandidates: const <String>['agent_tasks'],
      ),
      LrmGpaPlanStep(
        stepNumber: 4,
        phase: 'self_review',
        agentSlug: reviewer,
        title: 'Run self-correction before execution',
        requiredData: <String>[
          'Missing-info list',
          'Scope warnings',
          'Safety checks',
        ],
        doneWhen:
            'The plan is either approved for a small first step or blocked for CEO clarification.',
        dependsOn: const <int>[1, 2, 3],
        toolCandidates: const <String>['review_gate'],
      ),
    ];

    final actions = <LrmGpaActionDraft>[
      LrmGpaActionDraft(
        kind: 'app_task',
        ownerAgentSlug: primary,
        title: 'Execute first GPA slice: ${_clip(cleanRequest, 56)}',
        nextAction: selfReview.requiresApproval
            ? 'Wait for CEO approval before any external side effect.'
            : 'Queue a reversible internal task and attach validation evidence.',
        acceptanceCriteria: <String>[
          'Owner confirms the first slice is small and reversible.',
          'Evidence is attached before marking complete.',
          'Self-review warnings are addressed or accepted by CEO.',
        ],
        draftPayload: <String, dynamic>{
          'task_type': 'lrm_gpa_action',
          'source': 'lrm_self_correction_planner',
        },
      ),
      LrmGpaActionDraft(
        kind: 'github_issue_draft',
        ownerAgentSlug: planner,
        title: '[GPA] ${_clip(cleanRequest, 68)}',
        nextAction:
            'Create only after the CEO confirms this should enter GitHub.',
        acceptanceCriteria: <String>[
          'Issue body includes Goal, Plan, Action, and self-review sections.',
          'Labels and owner match the WBS routing.',
          'No external credential or private data is copied into the issue.',
        ],
        draftPayload: <String, dynamic>{
          'labels': <String>['automation', 'wbs'],
          'body_sections': <String>['Goal', 'Plan', 'Action', 'Self-review'],
        },
      ),
      LrmGpaActionDraft(
        kind: 'wbs_draft',
        ownerAgentSlug: coordinator,
        title: 'GPA follow-up: ${_clip(cleanRequest, 64)}',
        nextAction: 'Register only after deduping against existing WBS tasks.',
        acceptanceCriteria: <String>[
          'Due date and owner are explicit.',
          'Blocked state is captured if approval or external data is missing.',
          'GitHub Issue link is attached when available.',
        ],
        draftPayload: <String, dynamic>{
          'priority': 'high',
          'status': selfReview.requiresApproval ? 'blocked' : 'ready',
        },
      ),
    ];

    return LrmSelfCorrectionPlan(
      request: cleanRequest,
      generatedAt: now ?? DateTime.now().toUtc(),
      strategyLabel: _strategyLabel(strategy),
      goal: goal,
      plan: steps,
      actions: actions,
      selfReview: selfReview,
    );
  }

  static LrmSelfReview _buildSelfReview(String request) {
    final lower = request.toLowerCase();
    final missingInfo = <String>[
      if (request.length < 24) 'The request is short; confirm desired outcome.',
      if (!RegExp(r'\d').hasMatch(request))
        'No numeric target, date, or review window is stated.',
    ];
    final scopeWarnings = <String>[
      if (_containsAny(lower, ['all ', 'everything', 'complete ', 'fully ']))
        'Scope may be too broad; reduce the first action to one 24-hour slice.',
      if (_containsAny(lower, ['automatic', 'autonomous', 'no approval']))
        'Autonomy request detected; keep external side effects behind approval.',
    ];
    final dangerousMatches = _dangerousFragments
        .where((fragment) => lower.contains(fragment))
        .toList();
    final risks = <String>[
      if (dangerousMatches.isNotEmpty)
        'Sensitive or irreversible operation terms detected: ${dangerousMatches.join(', ')}.',
      if (missingInfo.isNotEmpty)
        'The plan may optimize the wrong target until missing info is resolved.',
      if (scopeWarnings.isNotEmpty)
        'Overscope can create unreviewable WBS or GitHub work.',
    ];
    final requiresApproval =
        dangerousMatches.isNotEmpty ||
        _containsAny(lower, [
          'send',
          'publish',
          'deploy',
          'delete',
          'payment',
          'secret',
          'credential',
        ]);
    final safetyChecks = <String>[
      'External writes stay draft-only until CEO approval.',
      'Dangerous shell, database, payment, and credential operations are blocked.',
      'Generated GitHub/WBS outputs must be deduped before creation.',
      if (requiresApproval)
        'CEO approval required before executing the requested external action.',
    ];
    return LrmSelfReview(
      missingInfo: missingInfo,
      scopeWarnings: scopeWarnings,
      risks: risks,
      safetyChecks: safetyChecks,
      requiresApproval: requiresApproval,
    );
  }

  static String _cleanRequest(String value) {
    final clean = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return clean.isEmpty ? 'Unspecified CEO request' : _clip(clean, 240);
  }

  static _LrmPlannerStrategy _detectStrategy(String request) {
    final lower = request.toLowerCase();
    if (_containsAny(lower, ['cost', 'budget', 'revenue', 'profit', 'cash'])) {
      return _LrmPlannerStrategy.finance;
    }
    if (_containsAny(lower, ['sns', 'marketing', 'sales', 'growth', 'lp'])) {
      return _LrmPlannerStrategy.growth;
    }
    if (_containsAny(lower, ['api', 'db', 'ci', 'deploy', 'flutter', 'bug'])) {
      return _LrmPlannerStrategy.engineering;
    }
    if (_containsAny(lower, ['legal', 'contract', 'privacy', 'terms'])) {
      return _LrmPlannerStrategy.legal;
    }
    if (_containsAny(lower, ['health', 'sleep', 'training', 'focus'])) {
      return _LrmPlannerStrategy.health;
    }
    if (_containsAny(lower, ['ops', 'support', 'schedule', 'process'])) {
      return _LrmPlannerStrategy.operations;
    }
    return _LrmPlannerStrategy.general;
  }

  static bool _containsAny(String value, List<String> keywords) {
    return keywords.any(value.contains);
  }

  static String _strategyLabel(_LrmPlannerStrategy strategy) {
    return switch (strategy) {
      _LrmPlannerStrategy.finance => 'finance and budget planning',
      _LrmPlannerStrategy.growth => 'growth and customer acquisition',
      _LrmPlannerStrategy.engineering => 'engineering delivery',
      _LrmPlannerStrategy.legal => 'legal and compliance review',
      _LrmPlannerStrategy.health => 'health and habit continuity',
      _LrmPlannerStrategy.operations => 'operations and process control',
      _LrmPlannerStrategy.general => 'general executive planning',
    };
  }

  static String _clip(String text, int maxChars) {
    if (text.length <= maxChars) return text;
    return '${text.substring(0, maxChars - 3)}...';
  }
}

enum _LrmPlannerStrategy {
  finance,
  growth,
  engineering,
  legal,
  health,
  operations,
  general,
}
