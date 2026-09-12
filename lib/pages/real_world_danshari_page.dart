import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/photo_action_advice.dart';
import '../services/photo_action_advisor_service.dart';
import '../services/theme_service.dart';
import '../view_models/photo_action_advisor_view_model.dart';

class RealWorldDanshariPage extends StatefulWidget {
  RealWorldDanshariPage({
    super.key,
    this.supabaseClient,
    ImagePicker? imagePicker,
    this.viewModel,
  }) : imagePicker = imagePicker ?? ImagePicker();

  final SupabaseClient? supabaseClient;
  final ImagePicker imagePicker;
  final PhotoActionAdvisorViewModel? viewModel;

  @override
  State<RealWorldDanshariPage> createState() => _RealWorldDanshariPageState();
}

class _RealWorldDanshariPageState extends State<RealWorldDanshariPage> {
  late final PhotoActionAdvisorViewModel _viewModel;
  late final bool _ownsViewModel;

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.viewModel == null;
    _viewModel = widget.viewModel ??
        PhotoActionAdvisorViewModel(
          imagePicker: ImagePickerPhotoActionImagePicker(
            imagePicker: widget.imagePicker,
          ),
          analyzer: SupabasePhotoActionAnalyzer(
            widget.supabaseClient ?? Supabase.instance.client,
          ),
        );
  }

  @override
  void dispose() {
    if (_ownsViewModel) _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeService>().isDarkMode;
    return Scaffold(
      appBar: AppBar(
        title: const Text('AIフォト行動アドバイザー'),
        backgroundColor: const Color(0xFFFF6B35),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _viewModel,
          builder: (context, _) => LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1120),
                    child: isWide
                        ? Row(
                            key: const Key('photo-action-wide-layout'),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildInputPanel(isDark)),
                              const SizedBox(width: 24),
                              Expanded(child: _buildResultPanel(isDark)),
                            ],
                          )
                        : Column(
                            key: const Key('photo-action-narrow-layout'),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildInputPanel(isDark),
                              const SizedBox(height: 24),
                              _buildResultPanel(isDark),
                            ],
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInputPanel(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: isDark ? const Color(0xFF1F2937) : const Color(0xFFFFF3E0),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(Icons.auto_awesome, size: 44, color: Color(0xFFFF6B35)),
                SizedBox(height: 12),
                Text(
                  '片付けたい場所や、次に何をすべきか迷う場面を撮影してください。\nAIが写真から確認できる範囲で、優先行動を整理します。',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, height: 1.5),
                ),
                SizedBox(height: 8),
                Text(
                  '顔、住所、書類などの個人情報が写らないようご注意ください。',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildImagePreview(isDark),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: _viewModel.isAnalyzing
                  ? null
                  : () => _viewModel.pickAndAnalyze(
                        PhotoActionImageSource.camera,
                      ),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('カメラで撮影'),
              style: _actionButtonStyle(),
            ),
            ElevatedButton.icon(
              onPressed: _viewModel.isAnalyzing
                  ? null
                  : () => _viewModel.pickAndAnalyze(
                        PhotoActionImageSource.gallery,
                      ),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('写真をアップロード'),
              style: _actionButtonStyle(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImagePreview(bool isDark) {
    final image = _viewModel.selectedImage;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111827) : const Color(0xFFE5E7EB),
            border: Border.all(color: const Color(0xFFFF6B35)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: image == null
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, size: 48),
                      SizedBox(height: 8),
                      Text('ここに写真が表示されます'),
                    ],
                  ),
                )
              : Semantics(
                  label: '解析する写真',
                  image: true,
                  child: Image.memory(
                    image.bytes,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Text('写真を表示できませんでした'),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildResultPanel(bool isDark) {
    if (_viewModel.isAnalyzing) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 48, horizontal: 24),
          child: Column(
            children: [
              CircularProgressIndicator(color: Color(0xFFFF6B35)),
              SizedBox(height: 16),
              Text('写真を確認して、行動を組み立てています…'),
            ],
          ),
        ),
      );
    }
    if (_viewModel.errorMessage != null) {
      return Card(
        color: isDark ? const Color(0xFF3F1D1D) : const Color(0xFFFFEBEE),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(
                _viewModel.requiresLogin ? Icons.login : Icons.error_outline,
                color: const Color(0xFFD32F2F),
                size: 36,
              ),
              const SizedBox(height: 12),
              Text(
                _viewModel.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(height: 1.5),
              ),
              if (!_viewModel.requiresLogin &&
                  _viewModel.selectedImage != null) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _viewModel.analyzeSelected,
                  icon: const Icon(Icons.refresh),
                  label: const Text('もう一度分析'),
                ),
              ],
            ],
          ),
        ),
      );
    }
    final advice = _viewModel.advice;
    if (advice == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 36, horizontal: 24),
          child: Column(
            children: [
              Icon(
                Icons.checklist_outlined,
                size: 44,
                color: Color(0xFFFF6B35),
              ),
              SizedBox(height: 12),
              Text(
                '写真を選ぶと、ここに優先行動が表示されます。',
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.5),
              ),
            ],
          ),
        ),
      );
    }
    return _buildAdvice(advice, isDark);
  }

  Widget _buildAdvice(PhotoActionAdvice advice, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '写真から確認できる状況',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(advice.sceneSummary, style: const TextStyle(height: 1.5)),
                if (advice.observations.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  for (final observation in advice.observations)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Icon(Icons.circle, size: 7),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              observation,
                              style: const TextStyle(height: 1.45),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'おすすめの順番',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        for (var index = 0; index < advice.actions.length; index++) ...[
          _PhotoActionCard(action: advice.actions[index], index: index),
          const SizedBox(height: 10),
        ],
        Card(
          color: isDark ? const Color(0xFF1F2937) : const Color(0xFFEFF6FF),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  advice.confidenceNote,
                  style: const TextStyle(fontSize: 12, height: 1.45),
                ),
                if (advice.safetyNote != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.health_and_safety_outlined, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          advice.safetyNote!,
                          style: const TextStyle(fontSize: 12, height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('photo-action-help-link'),
            onPressed: () => Navigator.of(context).pushNamed('/user-manual'),
            icon: const Icon(Icons.help_outline),
            label: const Text('リアル断捨離の使い方を見る'),
          ),
        ),
      ],
    );
  }

  ButtonStyle _actionButtonStyle() => ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFF6B35),
        foregroundColor: Colors.white,
        minimumSize: const Size(180, 48),
      );
}

class _PhotoActionCard extends StatelessWidget {
  const _PhotoActionCard({required this.action, required this.index});

  final PhotoRecommendedAction action;
  final int index;

  @override
  Widget build(BuildContext context) {
    final color = switch (action.priority) {
      PhotoActionPriority.urgent => const Color(0xFFD32F2F),
      PhotoActionPriority.high => const Color(0xFFF57C00),
      PhotoActionPriority.normal => const Color(0xFF1976D2),
    };
    return Card(
      key: Key('photo-action-$index'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(
                  label: Text(
                    '${action.priority.rank}. ${action.priority.label}',
                  ),
                  side: BorderSide(color: color),
                  avatar: Icon(Icons.flag_outlined, color: color, size: 18),
                ),
                Chip(
                  avatar: const Icon(Icons.schedule, size: 18),
                  label: Text('約${action.estimatedMinutes}分'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              action.title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(action.reason, style: const TextStyle(height: 1.5)),
            if (action.caution != null) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, color: color, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      action.caution!,
                      style: const TextStyle(fontSize: 13, height: 1.45),
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
