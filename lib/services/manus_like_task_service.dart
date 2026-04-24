class ManusLikeTaskStep {
  const ManusLikeTaskStep({
    required this.stepNumber,
    required this.agentSlug,
    required this.title,
    required this.description,
    required this.expectedOutput,
    this.dependsOn = const <int>[],
    this.priority = 'high',
  });

  final int stepNumber;
  final String agentSlug;
  final String title;
  final String description;
  final String expectedOutput;
  final List<int> dependsOn;
  final String priority;
}

class ManusLikeTaskPlan {
  const ManusLikeTaskPlan({
    required this.objective,
    required this.strategyLabel,
    required this.steps,
    required this.reviewGate,
  });

  final String objective;
  final String strategyLabel;
  final List<ManusLikeTaskStep> steps;
  final String reviewGate;

  String get executionSummary {
    final stepLines = steps
        .map(
          (step) => '${step.stepNumber}. ${step.agentSlug}: ${step.title}',
        )
        .join('\n');
    return [
      'Manus-like multi-step execution',
      'Objective: $objective',
      'Strategy: $strategyLabel',
      stepLines,
      'Review gate: $reviewGate',
    ].join('\n');
  }
}

class ManusLikeTaskService {
  static const _fallbackSlugs = <String>[
    'secretary',
    'planning-director',
    'product-manager',
    'cto',
    'cfo',
    'cmo',
    'sales-director',
    'cs-director',
  ];

  static ManusLikeTaskPlan buildPlan({
    required String objective,
    Set<String> availableAgentSlugs = const <String>{},
  }) {
    final cleanObjective = _cleanObjective(objective);
    final strategy = _detectStrategy(cleanObjective);
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
      _ManusStrategy.finance => pick(['cfo', 'accountant']),
      _ManusStrategy.marketing => pick(['cmo', 'ad-planner', 'pr-director']),
      _ManusStrategy.sales => pick(['sales-director', 'inside-sales']),
      _ManusStrategy.legal => pick(['legal-director']),
      _ManusStrategy.health => pick(['cho', 'chro']),
      _ManusStrategy.product => pick(['product-manager', 'cto']),
      _ManusStrategy.technology => pick(['cto', 'backend-dev', 'frontend-dev']),
      _ManusStrategy.general => pick(['planning-director', 'product-manager']),
    };
    final specialist = switch (strategy) {
      _ManusStrategy.finance => pick(['accountant', 'procurement-director']),
      _ManusStrategy.marketing => pick(['ad-planner', 'pr-director']),
      _ManusStrategy.sales => pick(['inside-sales', 'cs-director']),
      _ManusStrategy.legal => pick(['secretary', 'planning-director']),
      _ManusStrategy.health => pick(['chro', 'secretary']),
      _ManusStrategy.product => pick(['cto', 'frontend-dev', 'backend-dev']),
      _ManusStrategy.technology => pick(['backend-dev', 'frontend-dev']),
      _ManusStrategy.general => pick(['secretary', 'planning-director']),
    };

    return ManusLikeTaskPlan(
      objective: cleanObjective,
      strategyLabel: _strategyLabel(strategy),
      reviewGate: '24時間以内にCEOが成果物を確認し、次の1手だけを再委任する',
      steps: [
        ManusLikeTaskStep(
          stepNumber: 1,
          agentSlug: pick(['secretary']),
          title: 'Manus要件整理: $cleanObjective',
          description: '目的、制約、完了条件、関係者、今日中に判断すべき論点を1ページに整理する。',
          expectedOutput: '目的 / 完了条件 / 未確定事項 / 失敗時の撤退条件',
        ),
        ManusLikeTaskStep(
          stepNumber: 2,
          agentSlug: pick(['planning-director']),
          title: 'KGI/CSF/KPIと実行順序の設計',
          description: '要件整理をもとにKGI、CSF、KPI、依存関係、最初の実行順序を数値で定義する。',
          expectedOutput: 'KGI 1件、CSF 3件以内、KPI 5件以内、今日の実行順',
          dependsOn: const [1],
        ),
        ManusLikeTaskStep(
          stepNumber: 3,
          agentSlug: primary,
          title: '主担当部門の実行案作成',
          description: 'KPI達成に必要な施策を、低コスト・短時間で試せる順に並べて具体化する。',
          expectedOutput: '実行案、必要リソース、想定効果、リスク',
          dependsOn: const [2],
        ),
        ManusLikeTaskStep(
          stepNumber: 4,
          agentSlug: specialist,
          title: '専門観点の検証と補強',
          description: '主担当案を専門観点でレビューし、抜け漏れ、ボトルネック、次の作業チケットに分解する。',
          expectedOutput: 'レビュー結果、修正案、実行チケット一覧',
          dependsOn: const [3],
        ),
        ManusLikeTaskStep(
          stepNumber: 5,
          agentSlug: pick(['secretary']),
          title: '成果統合とCEOレビュー準備',
          description: '各ステップの成果を統合し、CEOが承認/保留/差し戻しを判断できる形にまとめる。',
          expectedOutput: '意思決定メモ、次の1手、保留論点',
          dependsOn: const [1, 2, 3, 4],
        ),
      ],
    );
  }

  static String _cleanObjective(String value) {
    final clean = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return clean.isEmpty ? '未設定の社内タスク' : _clip(clean, 80);
  }

  static _ManusStrategy _detectStrategy(String objective) {
    final lower = objective.toLowerCase();
    if (_containsAny(lower, ['費用', '予算', '利益', '資金', 'コスト', 'money'])) {
      return _ManusStrategy.finance;
    }
    if (_containsAny(lower, ['sns', '集客', '広告', 'マーケ', '発信', 'ブランド'])) {
      return _ManusStrategy.marketing;
    }
    if (_containsAny(lower, ['営業', '顧客', '商談', '売上', 'sales'])) {
      return _ManusStrategy.sales;
    }
    if (_containsAny(lower, ['契約', '法務', '規約', 'コンプライアンス'])) {
      return _ManusStrategy.legal;
    }
    if (_containsAny(lower, ['健康', '睡眠', '体力', '集中', '習慣'])) {
      return _ManusStrategy.health;
    }
    if (_containsAny(lower, ['ui', 'ux', '機能', 'プロダクト', '画面'])) {
      return _ManusStrategy.product;
    }
    if (_containsAny(lower, ['api', 'db', '開発', '実装', 'ci', 'github'])) {
      return _ManusStrategy.technology;
    }
    return _ManusStrategy.general;
  }

  static bool _containsAny(String value, List<String> keywords) {
    return keywords.any(value.contains);
  }

  static String _strategyLabel(_ManusStrategy strategy) {
    return switch (strategy) {
      _ManusStrategy.finance => '財務・コスト最適化',
      _ManusStrategy.marketing => 'マーケティング・発信',
      _ManusStrategy.sales => '営業・顧客獲得',
      _ManusStrategy.legal => '法務・リスク確認',
      _ManusStrategy.health => '健康・習慣継続',
      _ManusStrategy.product => 'プロダクト改善',
      _ManusStrategy.technology => '技術実装',
      _ManusStrategy.general => '汎用プロジェクト推進',
    };
  }

  static String _clip(String text, int maxChars) {
    if (text.length <= maxChars) return text;
    return '${text.substring(0, maxChars - 3)}...';
  }
}

enum _ManusStrategy {
  finance,
  marketing,
  sales,
  legal,
  health,
  product,
  technology,
  general,
}
