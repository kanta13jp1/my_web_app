import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'handoff_bundle.dart';
import 'token_diff.dart';
import 'flutter_codegen.dart';

class ClaudeDesignImporterPage extends StatefulWidget {
  const ClaudeDesignImporterPage({super.key});

  @override
  State<ClaudeDesignImporterPage> createState() =>
      _ClaudeDesignImporterPageState();
}

class _ClaudeDesignImporterPageState extends State<ClaudeDesignImporterPage>
    with SingleTickerProviderStateMixin {
  final _jsonController = TextEditingController();
  final _scrollController = ScrollController();
  late final TabController _tabController;

  ClaudeDesignHandoff? _bundle;
  TokenDiff? _diff;
  String _generatedCode = '';
  String? _error;
  bool _parsed = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _jsonController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _parse() {
    setState(() {
      _error = null;
      _parsed = false;
      _bundle = null;
      _diff = null;
      _generatedCode = '';
    });

    try {
      final decoded = jsonDecode(_jsonController.text) as Map<String, dynamic>;
      final bundle = ClaudeDesignHandoff.fromJson(decoded);
      setState(() {
        _bundle = bundle;
        _parsed = true;
      });
    } catch (e) {
      setState(() {
        _error = 'JSON parse error: $e';
      });
    }
  }

  void _diffTokens() {
    if (_bundle == null) return;
    final diff = diffTokens(currentDesignTokens, _bundle!.tokens);
    setState(() {
      _diff = diff;
      _tabController.animateTo(1);
    });
  }

  void _generateCode() {
    if (_bundle == null) return;
    final code = FlutterCodegen.reportAsJson(_bundle!.components);
    setState(() {
      _generatedCode = code;
      _tabController.animateTo(2);
    });
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('コードをコピーしました'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Color(0xFF1A1A2E),
        title: const Text(
          'Claude Design Importer',
          style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFE2E8F0)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Color(0xFFFF6B35),
          labelColor: Color(0xFFFF6B35),
          unselectedLabelColor: Color(0xFF94A3B8),
          tabs: const [
            Tab(text: 'Input'),
            Tab(text: 'Token Diff'),
            Tab(text: 'Generated Code'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInputTab(),
          _buildDiffTab(),
          _buildCodeTab(),
        ],
      ),
    );
  }

  Widget _buildInputTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Claude Design handoff bundle JSON を貼り付け',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Color(0xFF334155)),
              ),
              child: TextField(
                controller: _jsonController,
                maxLines: null,
                expands: true,
                style: const TextStyle(
                  color: Color(0xFFE2E8F0),
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
                decoration: const InputDecoration(
                  hintText: '{ "tokens": { ... }, "components": [ ... ] }',
                  hintStyle: TextStyle(color: Color(0xFF475569), fontSize: 12),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          if (_parsed && _bundle != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFF065F46),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: Color(0xFF34D399),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Parsed: ${_bundle!.components.length} components, '
                    '${_bundle!.pages.length} pages, '
                    '${_bundle!.tokens.colors.length} colors',
                    style: const TextStyle(
                      color: Color(0xFF34D399),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _parse,
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: const Text('Parse'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _bundle != null ? _diffTokens : null,
                  icon: const Icon(Icons.compare_arrows, size: 16),
                  label: const Text('Diff vs DESIGN.md'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Color(0xFFFF6B35),
                    side: const BorderSide(color: Color(0xFFFF6B35)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _bundle != null ? _generateCode : null,
                  icon: const Icon(Icons.code, size: 16),
                  label: const Text('Generate'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Color(0xFF0D9488),
                    side: const BorderSide(color: Color(0xFF0D9488)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiffTab() {
    if (_diff == null) {
      return const Center(
        child: Text(
          'Input タブで「Diff vs DESIGN.md」を実行してください',
          style: TextStyle(color: Color(0xFF475569)),
        ),
      );
    }

    final changes = _diff!.onlyChanges;
    return Column(
      children: [
        _buildDiffSummary(),
        Expanded(
          child: changes.isEmpty
              ? const Center(
                  child: Text(
                    'トークン差分なし — DESIGN.md と一致しています',
                    style: TextStyle(color: Color(0xFF0D9488)),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: changes.length,
                  itemBuilder: (context, i) => _buildDiffTile(changes[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildDiffSummary() {
    final d = _diff!;
    return Container(
      color: Color(0xFF1A1A2E),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _diffChip('+ ${d.addedCount}', Color(0xFF0D9488)),
          const SizedBox(width: 8),
          _diffChip('- ${d.removedCount}', Color(0xFFB91C1C)),
          const SizedBox(width: 8),
          _diffChip('~ ${d.modifiedCount}', Color(0xFFFF6B35)),
          const SizedBox(width: 8),
          _diffChip('= ${d.unchangedCount}', Color(0xFF475569)),
        ],
      ),
    );
  }

  Widget _diffChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildDiffTile(TokenChange change) {
    final kindColor = switch (change.kind) {
      ChangeKind.added => Color(0xFF0D9488),
      ChangeKind.removed => Color(0xFFB91C1C),
      ChangeKind.modified => Color(0xFFFF6B35),
      ChangeKind.unchanged => Color(0xFF475569),
    };
    final kindSymbol = switch (change.kind) {
      ChangeKind.added => '+',
      ChangeKind.removed => '-',
      ChangeKind.modified => '~',
      ChangeKind.unchanged => '=',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kindColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kindColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Text(
            kindSymbol,
            style: TextStyle(
              color: kindColor,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${change.tokenType}: ${change.key}',
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (change.oldValue != null || change.newValue != null)
                  Text(
                    '${change.oldValue ?? "—"} → ${change.newValue ?? "—"}',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeTab() {
    if (_generatedCode.isEmpty) {
      return const Center(
        child: Text(
          'Input タブで「Generate Flutter widgets」を実行してください',
          style: TextStyle(color: Color(0xFF475569)),
        ),
      );
    }

    return Column(
      children: [
        Container(
          color: Color(0xFF1A1A2E),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Text(
                'Generated Dart code',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(
                  Icons.copy,
                  color: Color(0xFFFF6B35),
                  size: 18,
                ),
                tooltip: 'クリップボードにコピー',
                onPressed: () => _copyToClipboard(_generatedCode),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              _generatedCode,
              style: const TextStyle(
                color: Color(0xFFE2E8F0),
                fontSize: 11,
                fontFamily: 'monospace',
                height: 1.6,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
