import 'package:flutter/material.dart';

import '../models/pdf_document_analysis.dart';
import '../services/pdf_document_analysis_service.dart';
import '../view_models/pdf_document_analysis_view_model.dart';

class PdfDocumentAnalyzerPage extends StatefulWidget {
  final PdfDocumentAnalysisGateway gateway;

  const PdfDocumentAnalyzerPage({
    super.key,
    this.gateway = const PdfDocumentAnalysisService(),
  });

  @override
  State<PdfDocumentAnalyzerPage> createState() =>
      _PdfDocumentAnalyzerPageState();
}

class _PdfDocumentAnalyzerPageState extends State<PdfDocumentAnalyzerPage> {
  late final PdfDocumentAnalysisViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = PdfDocumentAnalysisViewModel(gateway: widget.gateway);
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PDFドキュメント解析')),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) => LayoutBuilder(
          builder: (context, constraints) {
            final input = _InputPanel(
              viewModel: _viewModel,
              onAnalyze: _confirmAndAnalyze,
            );
            final output = _ResultPanel(result: _viewModel.result);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const _IntroCard(),
                      const SizedBox(height: 16),
                      if (constraints.maxWidth >= 900)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(child: input),
                            const SizedBox(width: 20),
                            Expanded(child: output),
                          ],
                        )
                      else ...<Widget>[
                        input,
                        const SizedBox(height: 20),
                        output,
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmAndAnalyze() async {
    final selection = _viewModel.selection;
    if (selection == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('解析内容と料金を確認'),
        content: Text(
          '${selection.fileName}\n'
          '${selection.pageCount}ページ × '
          r'$0.055 = $'
          '${selection.estimatedParserCostUsd.toStringAsFixed(3)}（概算）\n\n'
          'PDFは一時StorageとWriterへ送信され、処理後に削除を要求します。'
          '解析結果は自動保存しません。続行しますか？',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            key: const Key('pdf-analysis-confirm-button'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('料金を確認して解析'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _viewModel.analyzeConfirmed();
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: const Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'PDFをMarkdown化し、要約と重要項目を整理',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('最大20MB・200ページ。ページ数と概算料金を確認するまで外部AI解析は始まりません。'),
          ],
        ),
      ),
    );
  }
}

class _InputPanel extends StatelessWidget {
  final PdfDocumentAnalysisViewModel viewModel;
  final VoidCallback onAnalyze;

  const _InputPanel({required this.viewModel, required this.onAnalyze});

  @override
  Widget build(BuildContext context) {
    final selection = viewModel.selection;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('1. PDFを選択', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('pdf-picker-button'),
              onPressed: viewModel.isBusy ? null : viewModel.pickPdf,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: Text(viewModel.isPicking ? '読み込み中…' : 'PDFファイルを選択'),
            ),
            if (selection != null) ...<Widget>[
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description_outlined),
                title: Text(selection.fileName),
                subtitle: Text(
                  '${selection.pageCount}ページ ・ '
                  '${_megabytes(selection.bytes.length)}MB',
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '概算: ${selection.pageCount}ページ × '
                  r'$0.055 = $'
                  '${selection.estimatedParserCostUsd.toStringAsFixed(3)} USD',
                  key: const Key('pdf-estimated-cost'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('pdf-analyze-button'),
                onPressed: viewModel.isBusy ? null : onAnalyze,
                icon: viewModel.isAnalyzing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_outlined),
                label: Text(viewModel.isAnalyzing ? '解析中…' : '料金を確認して解析'),
              ),
            ],
            if (viewModel.errorMessage != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                viewModel.errorMessage!,
                key: const Key('pdf-analysis-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            const Divider(),
            const Text('プライバシー', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              '入力PDFはユーザー専用の非公開Storageに一時保存します。処理完了・失敗のどちらでも削除を試み、抽出本文と要約はDBへ保存しません。機密文書は送信前に内容を確認してください。',
            ),
          ],
        ),
      ),
    );
  }

  String _megabytes(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(2);
}

class _ResultPanel extends StatelessWidget {
  final PdfDocumentAnalysisResult? result;

  const _ResultPanel({required this.result});

  @override
  Widget build(BuildContext context) {
    final value = result;
    if (value == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            children: <Widget>[
              Icon(Icons.summarize_outlined, size: 48),
              SizedBox(height: 12),
              Text('解析結果はここに表示されます'),
            ],
          ),
        ),
      );
    }
    return Card(
      key: const Key('pdf-analysis-result'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(value.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            const Text('要約', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            SelectableText(value.summary),
            if (value.keyPoints.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              const Text(
                '重要ポイント',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              for (final point in value.keyPoints)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.check_circle_outline, size: 20),
                  title: Text(point),
                ),
            ],
            if (value.importantFields.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              const Text('重要項目', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              for (final field in value.importantFields)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(field.label),
                  subtitle: SelectableText(field.value),
                ),
            ],
            const SizedBox(height: 8),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                value.extractionTruncated ? '抽出本文（表示上限あり）' : '抽出本文（Markdown）',
              ),
              children: <Widget>[
                Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(value.extractedContent),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
