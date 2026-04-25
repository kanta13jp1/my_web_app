enum TomeDeckScenario {
  investorDeck,
  aiUniversityInfographic,
  competitorAirtable,
}

class TomePageSpec {
  const TomePageSpec({
    required this.title,
    required this.narrative,
    required this.visualDirection,
    required this.blocks,
    required this.speakerNote,
  });

  final String title;
  final String narrative;
  final String visualDirection;
  final List<String> blocks;
  final String speakerNote;
}

class TomeDeckPlan {
  const TomeDeckPlan({
    required this.scenario,
    required this.issueNumber,
    required this.title,
    required this.audience,
    required this.kgi,
    required this.csf,
    required this.kpi,
    required this.pages,
    required this.tomePrompt,
    required this.automationNotes,
    required this.sourceHints,
    required this.liveIntegrationReady,
  });

  final TomeDeckScenario scenario;
  final int issueNumber;
  final String title;
  final String audience;
  final String kgi;
  final List<String> csf;
  final Map<String, int> kpi;
  final List<TomePageSpec> pages;
  final String tomePrompt;
  final List<String> automationNotes;
  final List<String> sourceHints;
  final bool liveIntegrationReady;

  int get pageCount => pages.length;

  int get readinessScore {
    final kgiScore = kgi.trim().isEmpty ? 0 : 25;
    final csfScore = csf.length >= 3 ? 25 : csf.length * 8;
    final pageScore = pages.length >= 6 ? 30 : pages.length * 5;
    final automationScore = automationNotes.isEmpty ? 0 : 20;
    return (kgiScore + csfScore + pageScore + automationScore).clamp(0, 100);
  }
}

class TomeDeckStudioService {
  const TomeDeckStudioService();

  static const tomeProviderId = 'tome_app';
  static const sourceHintTome =
      'Tome: AI deck/page builder with web publishing and rich blocks';
  static const sourceHintAirtable =
      'Airtable: structured source data for live tables or automation runs';

  TomeDeckPlan buildPlan({
    required TomeDeckScenario scenario,
    String topic = '',
    String audience = '',
    String sourceText = '',
  }) {
    final normalizedTopic =
        _clean(topic).isEmpty ? _defaultTopic(scenario) : _clean(topic);
    final normalizedAudience = _clean(audience).isEmpty
        ? _defaultAudience(scenario)
        : _clean(audience);
    final sourceSummary = _summarize(sourceText, fallback: normalizedTopic);

    switch (scenario) {
      case TomeDeckScenario.investorDeck:
        return _investorDeck(
          normalizedTopic,
          normalizedAudience,
          sourceSummary,
        );
      case TomeDeckScenario.aiUniversityInfographic:
        return _aiUniversityDeck(
          normalizedTopic,
          normalizedAudience,
          sourceSummary,
        );
      case TomeDeckScenario.competitorAirtable:
        return _competitorDeck(
          normalizedTopic,
          normalizedAudience,
          _parseTableRows(sourceText),
        );
    }
  }

  String buildMarkdown(TomeDeckPlan plan) {
    final buffer = StringBuffer()
      ..writeln('# ${plan.title}')
      ..writeln()
      ..writeln('Audience: ${plan.audience}')
      ..writeln('KGI: ${plan.kgi}')
      ..writeln()
      ..writeln('## CSF')
      ..writeln(plan.csf.map((item) => '- $item').join('\n'))
      ..writeln()
      ..writeln('## KPI')
      ..writeln(
        plan.kpi.entries
            .map((entry) => '- ${entry.key}: ${entry.value}')
            .join('\n'),
      )
      ..writeln()
      ..writeln('## Tome Prompt')
      ..writeln(plan.tomePrompt)
      ..writeln();

    for (var i = 0; i < plan.pages.length; i++) {
      final page = plan.pages[i];
      buffer
        ..writeln('## Page ${i + 1}: ${page.title}')
        ..writeln(page.narrative)
        ..writeln()
        ..writeln('Visual: ${page.visualDirection}')
        ..writeln()
        ..writeln(page.blocks.map((block) => '- $block').join('\n'))
        ..writeln()
        ..writeln('Speaker note: ${page.speakerNote}')
        ..writeln();
    }

    buffer
      ..writeln('## Automation Notes')
      ..writeln(plan.automationNotes.map((item) => '- $item').join('\n'))
      ..writeln()
      ..writeln('## Source Hints')
      ..writeln(plan.sourceHints.map((item) => '- $item').join('\n'));
    return buffer.toString().trim();
  }

  TomeDeckPlan _investorDeck(
    String topic,
    String audience,
    String sourceSummary,
  ) {
    final pages = [
      TomePageSpec(
        title: 'Executive thesis',
        narrative:
            '$topic is positioned as a life-management operating system.',
        visualDirection:
            'Hero product screenshot with one bold outcome metric.',
        blocks: const [
          'One-line promise',
          'Current traction snapshot',
          'Why now',
        ],
        speakerNote: 'Start with urgency, not feature count.',
      ),
      const TomePageSpec(
        title: 'Problem',
        narrative:
            'Users lose time, money, health, stamina, intelligence, and focus through unmeasured leakage.',
        visualDirection: 'Six-leakage funnel with red-to-green conversion.',
        blocks: [
          'Time waste',
          'Money waste',
          'Health and stamina waste',
          'Focus and decision waste',
        ],
        speakerNote: 'Make the waste tangible and measurable.',
      ),
      const TomePageSpec(
        title: 'Solution',
        narrative:
            'The system turns raw behavior into KGI, CSF, KPI, monitoring, and action.',
        visualDirection: 'Before/after operating loop diagram.',
        blocks: [
          'Analyze current state',
          'Set KGI/CSF/KPI',
          'Monitor regularly',
          'Improve by WBS',
        ],
        speakerNote: 'Connect AI output to concrete operations.',
      ),
      TomePageSpec(
        title: 'Product surface',
        narrative: sourceSummary,
        visualDirection:
            'Four-card product map: Home, AI University, WBS, Life OS.',
        blocks: const [
          'AI University',
          'Project WBS',
          'Life waste elimination',
          'Share and growth loops',
        ],
        speakerNote: 'Show the product as a system, not a collection of tools.',
      ),
      const TomePageSpec(
        title: 'Business model',
        narrative: 'Personal OS first, team and enterprise workflows second.',
        visualDirection: 'Layered revenue ladder.',
        blocks: [
          'Individual productivity',
          'Team operating dashboard',
          'Enterprise automation',
        ],
        speakerNote: 'Explain expansion paths without overclaiming.',
      ),
      const TomePageSpec(
        title: 'Ask',
        narrative: 'The next milestone is a repeatable habit-to-business loop.',
        visualDirection: 'Roadmap with 30/60/90 day milestones.',
        blocks: [
          'Funding or partnership ask',
          'Near-term product milestone',
          'Key validation metric',
        ],
        speakerNote: 'Close with one decision and one next action.',
      ),
    ];

    return TomeDeckPlan(
      scenario: TomeDeckScenario.investorDeck,
      issueNumber: 756,
      title: 'Tome investor / internal report deck',
      audience: audience,
      kgi:
          'Create a decision-ready Tome deck for investors or internal reporting.',
      csf: const [
        'Lead with measurable waste reduction and user value',
        'Show the product as an operating loop',
        'Close with a concrete ask and next milestone',
      ],
      kpi: const {
        'pages': 6,
        'decision_points': 1,
        'metric_blocks': 4,
      },
      pages: pages,
      tomePrompt:
          'Create a concise investor-grade Tome deck about "$topic" for $audience. Use bold section titles, data cards, product screenshots, and one clear ask.',
      automationNotes: const [
        'Paste the generated markdown into Tome as the narrative source.',
        'Use Tome AI narration for the executive thesis and ask pages.',
        'Reuse the structure for internal weekly reporting by replacing traction and ask blocks.',
      ],
      sourceHints: const [sourceHintTome],
      liveIntegrationReady: true,
    );
  }

  TomeDeckPlan _aiUniversityDeck(
    String topic,
    String audience,
    String sourceSummary,
  ) {
    final pages = [
      const TomePageSpec(
        title: 'Learning map',
        narrative:
            'AI University turns scattered provider knowledge into a structured curriculum.',
        visualDirection: 'Network map grouped by provider capability.',
        blocks: ['Providers', 'Genres', 'Quizzes', 'RLHF feedback'],
        speakerNote: 'Open with the learning system, not one provider.',
      ),
      TomePageSpec(
        title: 'Provider spotlight',
        narrative: sourceSummary,
        visualDirection:
            'Infographic card with logo placeholder and capability radar.',
        blocks: const [
          'Core use case',
          'Strength',
          'Weakness',
          'Best workflow',
        ],
        speakerNote: 'Make the provider memorable in one page.',
      ),
      const TomePageSpec(
        title: 'Comparison',
        narrative:
            'Learners understand a tool faster when it is compared with nearby alternatives.',
        visualDirection: 'Three-column comparison table with color-coded fit.',
        blocks: [
          'Tome-like output',
          'Video/audio support',
          'Automation fit',
        ],
        speakerNote: 'Use comparison to reduce ambiguity.',
      ),
      const TomePageSpec(
        title: 'Practice loop',
        narrative: 'Quiz results and feedback become a learning data flywheel.',
        visualDirection: 'Loop diagram: learn, quiz, feedback, regenerate.',
        blocks: [
          'Question',
          'Answer',
          'Feedback signal',
          'Content improvement',
        ],
        speakerNote: 'Connect education to data quality.',
      ),
      const TomePageSpec(
        title: 'Infographic export',
        narrative:
            'Each lesson can become a shareable Tome page or visual briefing.',
        visualDirection:
            'Portrait infographic with headline, 3 facts, and CTA.',
        blocks: [
          'Headline',
          'Three data points',
          'Action prompt',
          'Share link',
        ],
        speakerNote: 'Make it reusable for social distribution.',
      ),
    ];

    return TomeDeckPlan(
      scenario: TomeDeckScenario.aiUniversityInfographic,
      issueNumber: 757,
      title: 'Tome AI University infographic page',
      audience: audience,
      kgi:
          'Transform AI University content into a visual Tome page that teaches one concept quickly.',
      csf: const [
        'Compress each lesson into one visual mental model',
        'Use comparison and examples instead of long prose',
        'Feed quiz and RLHF signals back into the next revision',
      ],
      kpi: const {
        'pages': 5,
        'visual_blocks': 5,
        'quiz_feedback_loops': 1,
      },
      pages: pages,
      tomePrompt:
          'Create a visual Tome page from this AI University topic: "$topic". Turn it into infographic blocks, comparison cards, and a learner action prompt for $audience.',
      automationNotes: const [
        'Use the AI University provider page as the source text.',
        'Generate one Tome page per provider or one short deck per genre.',
        'Use quiz failures and RLHF negative signals as rewrite targets.',
      ],
      sourceHints: const [sourceHintTome],
      liveIntegrationReady: true,
    );
  }

  TomeDeckPlan _competitorDeck(
    String topic,
    String audience,
    List<Map<String, String>> rows,
  ) {
    final topRows = rows.take(5).toList();
    final competitorNames = topRows
        .map((row) => row.values.isEmpty ? '' : row.values.first)
        .where((value) => value.trim().isNotEmpty)
        .join(', ');
    final summary = competitorNames.isEmpty
        ? 'Use Airtable records as the live source for competitor claims.'
        : 'Current Airtable rows cover: $competitorNames.';

    final pages = [
      TomePageSpec(
        title: 'Market map',
        narrative: summary,
        visualDirection:
            '2x2 matrix of competitors by automation depth and user value.',
        blocks: const [
          'Competitor segment',
          'Primary threat',
          'Differentiation angle',
        ],
        speakerNote: 'Start with the shape of the market.',
      ),
      const TomePageSpec(
        title: 'Comparison table',
        narrative:
            'The comparison page should be updated from Airtable before each review.',
        visualDirection:
            'Live table embed or pasted table with highlighted gaps.',
        blocks: ['Product', 'Feature', 'Price', 'Risk', 'Countermove'],
        speakerNote: 'Keep this page factual and source-backed.',
      ),
      const TomePageSpec(
        title: 'Threat ranking',
        narrative:
            'Prioritize competitors by impact, urgency, and product overlap.',
        visualDirection: 'Ranked threat bars with red/yellow/green status.',
        blocks: ['Critical', 'High', 'Watch', 'Ignore for now'],
        speakerNote: 'Defend prioritization choices.',
      ),
      const TomePageSpec(
        title: 'Counter strategy',
        narrative:
            'Each competitor should map to one feature, one message, and one WBS task.',
        visualDirection: 'Three-lane action board.',
        blocks: [
          'Feature response',
          'Message response',
          'Monitoring owner',
        ],
        speakerNote: 'Convert research into action.',
      ),
      const TomePageSpec(
        title: 'Automation cadence',
        narrative:
            'Refresh Airtable, regenerate summary, then update Tome before weekly review.',
        visualDirection: 'Airtable to Tome automation flow.',
        blocks: [
          'Airtable source',
          'AI summary',
          'Tome update',
          'WBS task',
        ],
        speakerNote: 'Make the update rhythm explicit.',
      ),
    ];

    return TomeDeckPlan(
      scenario: TomeDeckScenario.competitorAirtable,
      issueNumber: 758,
      title: 'Tome competitor comparison deck',
      audience: audience,
      kgi:
          'Keep competitor comparison materials fresh enough to guide weekly product decisions.',
      csf: const [
        'Use Airtable as the structured source of competitor facts',
        'Separate factual comparison from strategic interpretation',
        'Convert every high-risk finding into a WBS action',
      ],
      kpi: {
        'pages': 5,
        'airtable_rows_used': rows.length,
        'weekly_refreshes': 1,
      },
      pages: pages,
      tomePrompt:
          'Create a Tome competitor comparison deck about "$topic" for $audience. Use Airtable-style records as source data, show a comparison table, rank threats, and end with WBS actions.',
      automationNotes: const [
        'Paste Airtable CSV/TSV into this studio for an immediate deck draft.',
        'Embed the Airtable view in Tome when live data is needed.',
        'Remaining live automation requires an Airtable token/base/table mapping.',
      ],
      sourceHints: const [sourceHintTome, sourceHintAirtable],
      liveIntegrationReady: false,
    );
  }

  static String _defaultTopic(TomeDeckScenario scenario) {
    switch (scenario) {
      case TomeDeckScenario.investorDeck:
        return 'Life Management AI OS';
      case TomeDeckScenario.aiUniversityInfographic:
        return 'AI University provider lesson';
      case TomeDeckScenario.competitorAirtable:
        return 'Competitor comparison and weekly product decision';
    }
  }

  static String _defaultAudience(TomeDeckScenario scenario) {
    switch (scenario) {
      case TomeDeckScenario.investorDeck:
        return 'Investors / internal executive meeting';
      case TomeDeckScenario.aiUniversityInfographic:
        return 'AI University learners';
      case TomeDeckScenario.competitorAirtable:
        return 'Product and marketing team';
    }
  }

  static String _summarize(String text, {required String fallback}) {
    final cleaned = _clean(text);
    if (cleaned.isEmpty) return fallback;
    if (cleaned.length <= 260) return cleaned;
    return '${cleaned.substring(0, 260)}...';
  }

  static String _clean(String text) {
    return text.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static List<Map<String, String>> _parseTableRows(String text) {
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.length < 2) return const [];

    final delimiter = lines.first.contains('\t') ? '\t' : ',';
    final headers = lines.first
        .split(delimiter)
        .map((header) => header.trim())
        .where((header) => header.isNotEmpty)
        .toList();
    if (headers.isEmpty) return const [];

    final rows = <Map<String, String>>[];
    for (final line in lines.skip(1)) {
      final cells = line.split(delimiter).map((cell) => cell.trim()).toList();
      rows.add({
        for (var i = 0; i < headers.length; i++)
          headers[i]: i < cells.length ? cells[i] : '',
      });
    }
    return rows;
  }
}
