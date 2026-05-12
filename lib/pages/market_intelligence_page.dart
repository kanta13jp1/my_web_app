import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class MarketIntelligencePage extends StatefulWidget {
  const MarketIntelligencePage({super.key});

  @override
  State<MarketIntelligencePage> createState() => _MarketIntelligencePageState();
}

class _MarketIntelligencePageState extends State<MarketIntelligencePage> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  String? _errorMessage;
  _MarketIntelReport? _report;

  static const _defaultFeeds = <Map<String, String>>[
    {
      'title': 'Google News: AI markets',
      'url':
          'https://news.google.com/rss/search?q=AI%20market%20software%20startup&hl=en-US&gl=US&ceid=US:en',
      'category': 'AI',
    },
    {
      'title': 'Google News: fintech',
      'url':
          'https://news.google.com/rss/search?q=fintech%20market%20intelligence%20software&hl=en-US&gl=US&ceid=US:en',
      'category': 'FinTech',
    },
    {
      'title': 'ITmedia AI+',
      'url': 'https://rss.itmedia.co.jp/rss/2.0/aiplus.xml',
      'category': 'AI',
    },
    {
      'title': 'CNET Japan',
      'url': 'http://feed.japan.cnet.com/rss/index.rdf',
      'category': 'Technology',
    },
  ];

  static const _watchlist = <Map<String, Object>>[
    {
      'name': 'AI coding tools',
      'keywords': [
        'Claude Code',
        'Codex',
        'Cursor',
        'Gemini Code Assist',
        'Devin',
      ],
    },
    {
      'name': 'AI infrastructure',
      'keywords': ['OpenAI', 'Anthropic', 'Google', 'Microsoft', 'Nvidia'],
    },
    {
      'name': 'Financial terminals',
      'keywords': ['Bloomberg', 'FactSet', 'Refinitiv', 'Koyfin', 'Sentieo'],
    },
  ];

  static const _themes = <String>[
    'AI automation',
    'developer tooling',
    'fintech disruption',
    'pricing pressure',
    'enterprise adoption',
    'risk and regulation',
  ];

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'tools-hub',
        body: {
          'action': 'market_intel.analyze',
          'feeds': _defaultFeeds,
          'watchlist': _watchlist,
          'themes': _themes,
          'per_feed_limit': 10,
          'news_limit': 120,
          'signal_limit': 12,
        },
      );
      if (response.status != 200) {
        throw Exception('HTTP ${response.status}: ${response.data}');
      }
      final data = response.data as Map<String, dynamic>? ?? {};
      if (!mounted) return;
      setState(() => _report = _MarketIntelReport.fromJson(data));
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Market intelligence load failed: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Market Intelligence'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadReport,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ColoredBox(
        color: const Color(0xFFF7F9FC),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _isLoading && report == null
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null && report == null
                  ? _ErrorState(message: _errorMessage!, onRetry: _loadReport)
                  : _buildReport(report!),
        ),
      ),
    );
  }

  Widget _buildReport(_MarketIntelReport report) {
    return RefreshIndicator(
      onRefresh: _loadReport,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          _HeaderPanel(report: report, isRefreshing: _isLoading),
          const SizedBox(height: 12),
          _AuditStrip(report: report),
          const SizedBox(height: 16),
          if (_errorMessage != null) ...[
            _InlineWarning(message: _errorMessage!),
            const SizedBox(height: 16),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 980;
              final signalList = _SignalList(signals: report.signals);
              final sideRail = _SideRail(report: report);
              if (!wide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [sideRail, const SizedBox(height: 16), signalList],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 320, child: sideRail),
                  const SizedBox(width: 16),
                  Expanded(child: signalList),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HeaderPanel extends StatelessWidget {
  const _HeaderPanel({required this.report, required this.isRefreshing});

  final _MarketIntelReport report;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(Icons.query_stats, color: Color(0xFF1565C0), size: 28),
              Text(
                'AI Market Intelligence',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF172033),
                ),
              ),
              _StatusChip(
                label: isRefreshing ? 'Refreshing' : 'Research mode',
                color: isRefreshing
                    ? const Color(0xFFEF6C00)
                    : const Color(0xFF2E7D32),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            report.disclaimer,
            style: textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF475569),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricPill(
                icon: Icons.fact_check_outlined,
                label: '${report.signals.length} signals',
              ),
              _MetricPill(
                icon: Icons.source_outlined,
                label: '${report.sourceCount} sources',
              ),
              _MetricPill(
                icon: Icons.article_outlined,
                label: '${report.itemCount} items',
              ),
              const _MetricPill(
                icon: Icons.verified_user_outlined,
                label: 'human approval',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AuditStrip extends StatelessWidget {
  const _AuditStrip({required this.report});

  final _MarketIntelReport report;

  @override
  Widget build(BuildContext context) {
    final generated = report.generatedAt == null
        ? 'unknown'
        : DateFormat('yyyy/MM/dd HH:mm').format(report.generatedAt!.toLocal());
    return _Panel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _StatusChip(label: 'generated $generated', color: Colors.blueGrey),
          const _StatusChip(
            label: 'auto-trading off',
            color: Color(0xFFC62828),
          ),
          const _StatusChip(
            label: 'single-source claims gated',
            color: Color(0xFF6A1B9A),
          ),
          _StatusChip(label: report.auditModel, color: const Color(0xFF455A64)),
        ],
      ),
    );
  }
}

class _SideRail extends StatelessWidget {
  const _SideRail({required this.report});

  final _MarketIntelReport report;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PanelTitle(
                icon: Icons.visibility_outlined,
                title: 'Watchlist',
              ),
              const SizedBox(height: 10),
              for (final item in report.watchlist)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final keyword in item.keywords)
                            _SoftChip(label: keyword),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PanelTitle(icon: Icons.label_outline, title: 'Themes'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final theme in report.themes) _SoftChip(label: theme),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SignalList extends StatelessWidget {
  const _SignalList({required this.signals});

  final List<_MarketIntelSignal> signals;

  @override
  Widget build(BuildContext context) {
    if (signals.isEmpty) {
      return const _Panel(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: Text('No market signals found.')),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final signal in signals) ...[
          _SignalPanel(signal: signal),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _SignalPanel extends StatelessWidget {
  const _SignalPanel({required this.signal});

  final _MarketIntelSignal signal;

  @override
  Widget build(BuildContext context) {
    final color = _confidenceColor(signal.confidence);
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _StatusChip(label: signal.confidence, color: color),
              _MetricPill(
                icon: Icons.source_outlined,
                label: '${signal.sourceCount} sources',
              ),
              _MetricPill(
                icon: Icons.link_outlined,
                label: '${signal.evidenceCount} evidence',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            signal.headline,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF172033),
                ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final theme in signal.themes) _SoftChip(label: theme),
              for (final match in signal.watchlistMatches)
                _SoftChip(label: match, strong: true),
            ],
          ),
          const SizedBox(height: 12),
          _SignalNote(icon: Icons.help_outline, text: signal.uncertainty),
          const SizedBox(height: 8),
          _SignalNote(
            icon: Icons.warning_amber_outlined,
            text: signal.riskNote,
          ),
          const SizedBox(height: 14),
          const _SectionLabel(icon: Icons.open_in_new, label: 'Evidence'),
          const SizedBox(height: 8),
          for (final evidence in signal.evidence) _EvidenceRow(evidence),
          const SizedBox(height: 12),
          const _SectionLabel(
            icon: Icons.playlist_add_check,
            label: 'Watch next',
          ),
          const SizedBox(height: 8),
          for (final item in signal.whatToWatchNext)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('- $item'),
            ),
        ],
      ),
    );
  }

  static Color _confidenceColor(String confidence) {
    switch (confidence) {
      case 'high':
        return const Color(0xFF2E7D32);
      case 'medium':
        return const Color(0xFFEF6C00);
      default:
        return const Color(0xFF607D8B);
    }
  }
}

class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow(this.evidence);

  final _MarketIntelEvidence evidence;

  @override
  Widget build(BuildContext context) {
    final published = evidence.publishedAt == null
        ? 'unknown'
        : DateFormat('MM/dd HH:mm').format(evidence.publishedAt!.toLocal());
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  evidence.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${evidence.source} / $published / score ${evidence.signalScore}',
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Open source',
            onPressed: evidence.url.isEmpty
                ? null
                : () => launchUrl(
                      Uri.parse(evidence.url),
                      mode: LaunchMode.externalApplication,
                    ),
            icon: const Icon(Icons.open_in_new),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: child,
    );
  }
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF1565C0)),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF475569)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _SoftChip extends StatelessWidget {
  const _SoftChip({required this.label, this.strong = false});

  final String label;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final color = strong ? const Color(0xFF1565C0) : const Color(0xFF64748B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}

class _SignalNote extends StatelessWidget {
  const _SignalNote({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: const Color(0xFF334155)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _InlineWarning extends StatelessWidget {
  const _InlineWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_outlined, color: Color(0xFFEF6C00)),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: _Panel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 42,
                color: Color(0xFFC62828),
              ),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarketIntelReport {
  const _MarketIntelReport({
    required this.generatedAt,
    required this.disclaimer,
    required this.watchlist,
    required this.themes,
    required this.signals,
    required this.sourceCount,
    required this.itemCount,
    required this.auditModel,
  });

  final DateTime? generatedAt;
  final String disclaimer;
  final List<_MarketIntelWatchItem> watchlist;
  final List<String> themes;
  final List<_MarketIntelSignal> signals;
  final int sourceCount;
  final int itemCount;
  final String auditModel;

  factory _MarketIntelReport.fromJson(Map<String, dynamic> json) {
    final audit = json['audit'] is Map
        ? Map<String, dynamic>.from(json['audit'] as Map)
        : <String, dynamic>{};
    return _MarketIntelReport(
      generatedAt: DateTime.tryParse(json['generated_at']?.toString() ?? ''),
      disclaimer: json['disclaimer']?.toString() ?? '',
      watchlist: (json['watchlist'] as List? ?? [])
          .whereType<Map>()
          .map((item) => _MarketIntelWatchItem.fromJson(item))
          .toList(),
      themes: (json['themes'] as List? ?? [])
          .map((item) => item.toString())
          .toList(),
      signals: (json['signals'] as List? ?? [])
          .whereType<Map>()
          .map((item) => _MarketIntelSignal.fromJson(item))
          .toList(),
      sourceCount: (audit['source_count'] as num?)?.toInt() ?? 0,
      itemCount: (audit['item_count'] as num?)?.toInt() ?? 0,
      auditModel: audit['model']?.toString() ?? 'unknown',
    );
  }
}

class _MarketIntelWatchItem {
  const _MarketIntelWatchItem({required this.name, required this.keywords});

  final String name;
  final List<String> keywords;

  factory _MarketIntelWatchItem.fromJson(Map<dynamic, dynamic> json) {
    return _MarketIntelWatchItem(
      name: json['name']?.toString() ?? '',
      keywords: (json['keywords'] as List? ?? [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}

class _MarketIntelSignal {
  const _MarketIntelSignal({
    required this.headline,
    required this.confidence,
    required this.themes,
    required this.watchlistMatches,
    required this.evidence,
    required this.evidenceCount,
    required this.sourceCount,
    required this.uncertainty,
    required this.riskNote,
    required this.whatToWatchNext,
  });

  final String headline;
  final String confidence;
  final List<String> themes;
  final List<String> watchlistMatches;
  final List<_MarketIntelEvidence> evidence;
  final int evidenceCount;
  final int sourceCount;
  final String uncertainty;
  final String riskNote;
  final List<String> whatToWatchNext;

  factory _MarketIntelSignal.fromJson(Map<dynamic, dynamic> json) {
    return _MarketIntelSignal(
      headline: json['headline']?.toString() ??
          json['signal']?.toString() ??
          'Untitled signal',
      confidence: json['confidence']?.toString() ?? 'low',
      themes: (json['themes'] as List? ?? [])
          .map((item) => item.toString())
          .toList(),
      watchlistMatches: (json['watchlist_matches'] as List? ?? [])
          .map((item) => item.toString())
          .toList(),
      evidence: (json['evidence'] as List? ?? [])
          .whereType<Map>()
          .map((item) => _MarketIntelEvidence.fromJson(item))
          .toList(),
      evidenceCount: (json['evidence_count'] as num?)?.toInt() ?? 0,
      sourceCount: (json['source_count'] as num?)?.toInt() ?? 0,
      uncertainty: json['uncertainty']?.toString() ?? '',
      riskNote: json['risk_note']?.toString() ?? '',
      whatToWatchNext: (json['what_to_watch_next'] as List? ?? [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}

class _MarketIntelEvidence {
  const _MarketIntelEvidence({
    required this.title,
    required this.url,
    required this.source,
    required this.publishedAt,
    required this.signalScore,
  });

  final String title;
  final String url;
  final String source;
  final DateTime? publishedAt;
  final int signalScore;

  factory _MarketIntelEvidence.fromJson(Map<dynamic, dynamic> json) {
    return _MarketIntelEvidence(
      title: json['title']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      source: json['source']?.toString() ?? 'RSS',
      publishedAt: DateTime.tryParse(json['published_at']?.toString() ?? ''),
      signalScore: (json['signal_score'] as num?)?.toInt() ?? 0,
    );
  }
}
