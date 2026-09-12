import 'package:flutter/material.dart';

import '../services/evernote_cloud_stage_service.dart';
import '../services/evernote_migration_commit_service.dart';

const double evernoteContextWideBreakpoint = 720;

class EvernoteCloudStageStatus extends StatelessWidget {
  const EvernoteCloudStageStatus({
    super.key,
    required this.progress,
  });

  final EvernoteCloudStageProgress progress;

  @override
  Widget build(BuildContext context) {
    final percent = (progress.fraction * 100).round();
    final failed = progress.state == EvernoteCloudStageState.failed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          key: const Key('evernote-cloud-stage-progress'),
          value: progress.fraction,
        ),
        const SizedBox(height: 8),
        Text(
          'Private cloud archive: $percent% · ${progress.state.name}',
          key: const Key('evernote-cloud-stage-progress-label'),
          style: failed
              ? TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w700,
                )
              : null,
        ),
      ],
    );
  }
}

class EvernoteSourceContextFields extends StatelessWidget {
  const EvernoteSourceContextFields({
    super.key,
    required this.notebookController,
    required this.stackController,
    required this.spaceController,
    required this.onChanged,
  });

  final TextEditingController notebookController;
  final TextEditingController stackController;
  final TextEditingController spaceController;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    Widget optionalField({
      required Key key,
      required TextEditingController controller,
      required String label,
    }) {
      return TextField(
        key: key,
        controller: controller,
        maxLength: 200,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Evernote source hierarchy',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('evernote-source-notebook-name'),
          controller: notebookController,
          maxLength: 200,
          decoration: const InputDecoration(
            labelText: '元ノートブック名（必須）',
            helperText: 'ファイル名から推定しています。Evernote上の名前に修正してください。',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final stack = optionalField(
              key: const Key('evernote-source-stack-name'),
              controller: stackController,
              label: '元スタック名（任意）',
            );
            final space = optionalField(
              key: const Key('evernote-source-space-name'),
              controller: spaceController,
              label: '元Space名（任意）',
            );
            if (constraints.maxWidth >= evernoteContextWideBreakpoint) {
              return Row(
                key: const Key('evernote-source-context-wide'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: stack),
                  const SizedBox(width: 12),
                  Expanded(child: space),
                ],
              );
            }
            return Column(
              key: const Key('evernote-source-context-narrow'),
              children: [
                stack,
                const SizedBox(height: 8),
                space,
              ],
            );
          },
        ),
      ],
    );
  }
}

class EvernoteCloudTransferStatus extends StatelessWidget {
  const EvernoteCloudTransferStatus({
    super.key,
    required this.progress,
  });

  final EvernoteMigrationTransferProgress progress;

  @override
  Widget build(BuildContext context) {
    final failed = progress.state == EvernoteMigrationTransferState.failed;
    final label = 'Cloud transfer: ${progress.percent}% · '
        '${progress.state.label} · ${progress.stageLabel} · '
        'object ${progress.objectIndex}/${progress.objectCount}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          key: const Key('evernote-cloud-transfer-progress'),
          value: progress.fraction,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          key: const Key('evernote-cloud-transfer-progress-label'),
          style: failed
              ? TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w700,
                )
              : null,
        ),
      ],
    );
  }
}
