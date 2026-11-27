import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'application/vision_benchmark_controller.dart';
import 'data/supabase_vision_benchmark_repository.dart';
import 'domain/vision_benchmark_models.dart';
import 'presentation/vision_benchmark_dashboard_view.dart';

/// DI container for AI Vision benchmark monitoring dashboard (#2758).
class VisionBenchmarkContainer extends StatefulWidget {
  const VisionBenchmarkContainer({
    super.key,
    this.repository,
    this.controller,
    this.supabaseClient,
    this.autoLoad = true,
    this.onRunLiveTest,
  });

  final VisionBenchmarkRepository? repository;
  final VisionBenchmarkController? controller;
  final SupabaseClient? supabaseClient;
  final bool autoLoad;
  final Future<VisionBenchmarkRun> Function(String model, int threshold)?
      onRunLiveTest;

  @override
  State<VisionBenchmarkContainer> createState() =>
      _VisionBenchmarkContainerState();
}

class _VisionBenchmarkContainerState extends State<VisionBenchmarkContainer> {
  late final VisionBenchmarkRepository _repository;
  late final VisionBenchmarkController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ??
        SupabaseVisionBenchmarkRepository(client: widget.supabaseClient);
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        VisionBenchmarkController(
          repository: _repository,
          onRunLiveTest: widget.onRunLiveTest ??
              (widget.repository == null ? _runDefaultLiveTest : null),
        );
    if (widget.autoLoad) {
      _controller.loadDashboard();
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  Future<VisionBenchmarkRun> _runDefaultLiveTest(
    final String model,
    final int threshold,
  ) async {
    final client = widget.supabaseClient ?? Supabase.instance.client;
    final res = await client.functions.invoke(
      'ai-assistant',
      body: <String, Object?>{
        'action': 'test_model',
        'model': model,
      },
    );
    final raw = res.data is String ? jsonDecode(res.data as String) : res.data;
    final payload = raw is Map<Object?, Object?>
        ? raw.map<String, Object?>(
            (final Object? k, final Object? v) => MapEntry(k.toString(), v),
          )
        : const <String, Object?>{};
    final benchmark = payload['benchmark'] is Map<Object?, Object?>
        ? (payload['benchmark']! as Map<Object?, Object?>).map<String, Object?>(
            (final Object? k, final Object? v) => MapEntry(k.toString(), v),
          )
        : const <String, Object?>{};
    final score = ((benchmark['score'] as num?)?.round() ?? 0).clamp(0, 100);
    final latencyMs = (benchmark['latency'] as num?)?.round() ?? 0;
    final detail = (benchmark['detail'] ?? payload['error'] ?? '').toString();
    final passed = payload['success'] == true && score >= threshold;
    final levels = <VisionBenchmarkLevel>[];
    final rawLevels = benchmark['levels'];
    if (rawLevels is List<Object?>) {
      for (var i = 0; i < rawLevels.length; i++) {
        final item = rawLevels[i];
        if (item is Map<Object?, Object?>) {
          final m = item.map<String, Object?>(
            (final Object? k, final Object? v) => MapEntry(k.toString(), v),
          );
          levels.add(
            VisionBenchmarkLevel(
              level: (m['level'] ?? 'level${i + 1}').toString(),
              description: (m['description'] ?? '').toString(),
              passed: m['passed'] as bool? ?? false,
              score: ((m['score'] as num?)?.round() ?? 0).clamp(0, 100),
              maxPoints: (m['maxPoints'] as num?)?.round() ?? 100,
              latencyMs: (m['latency'] as num?)?.round() ?? 0,
              response: (m['response'] ?? '').toString(),
            ),
          );
        }
      }
    }
    return _repository.recordRun(
      model: model,
      provider: _inferProvider(model),
      score: score,
      latencyMs: latencyMs,
      threshold: threshold,
      passed: passed,
      detail: detail,
      levels: levels,
    );
  }

  String _inferProvider(final String model) {
    final lower = model.toLowerCase();
    if (lower.contains('claude')) return 'claude';
    if (lower.contains('gpt') || lower.startsWith('o')) return 'gpt';
    if (lower.contains('deepseek')) return 'deepseek';
    if (lower.contains('gemini') || lower.contains('gemma')) return 'gemini';
    return 'unknown';
  }

  @override
  Widget build(final BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (final BuildContext context, final Widget? _) {
        return VisionBenchmarkDashboardView(
          state: _controller.state,
          onRefresh: () => _controller.loadDashboard(),
          onThresholdChanged: _controller.updateThreshold,
          onSelectModel: _controller.selectModelFilter,
          onRunLiveTest: _controller.canRunLiveTest
              ? _controller.runAndRecordBenchmark
              : null,
        );
      },
    );
  }
}

/// Standalone page wrapper for `/vision-benchmark` route (#2758).
class VisionBenchmarkDashboardPage extends StatelessWidget {
  const VisionBenchmarkDashboardPage({
    super.key,
    this.repository,
    this.controller,
    this.supabaseClient,
    this.autoLoad = true,
    this.onRunLiveTest,
  });

  final VisionBenchmarkRepository? repository;
  final VisionBenchmarkController? controller;
  final SupabaseClient? supabaseClient;
  final bool autoLoad;
  final Future<VisionBenchmarkRun> Function(String model, int threshold)?
      onRunLiveTest;

  @override
  Widget build(final BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI監視ダッシュボード'),
      ),
      body: VisionBenchmarkContainer(
        repository: repository,
        controller: controller,
        supabaseClient: supabaseClient,
        autoLoad: autoLoad,
        onRunLiveTest: onRunLiveTest,
      ),
    );
  }
}
