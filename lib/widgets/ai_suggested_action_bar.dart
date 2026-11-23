import 'dart:async';

import 'package:flutter/material.dart';

import '../models/ai_suggested_action.dart';
import '../services/ai_suggested_action_monitor_service.dart';

class AiSuggestedActionExecutionResult {
  const AiSuggestedActionExecutionResult({
    required this.action,
    required this.handledMode,
    required this.message,
    this.recordedEvent,
  });

  final AiSuggestedAction action;
  final String handledMode;
  final String message;
  final AiSuggestedActionEvent? recordedEvent;
}

class AiSuggestedActionBar extends StatefulWidget {
  const AiSuggestedActionBar({
    super.key,
    required this.actions,
    this.onSendNarrativeChoice,
    this.onSceneTransition,
    this.onNavigateRoute,
    this.onStandardAction,
    this.onActionHandled,
    this.monitorService = const AiSuggestedActionMonitorService(),
    this.recordImpressions = true,
  });

  final List<AiSuggestedAction> actions;
  final ValueChanged<String>? onSendNarrativeChoice;
  final ValueChanged<AiSuggestedAction>? onSceneTransition;
  final ValueChanged<String>? onNavigateRoute;
  final ValueChanged<AiSuggestedAction>? onStandardAction;
  final ValueChanged<AiSuggestedActionExecutionResult>? onActionHandled;
  final AiSuggestedActionMonitorService monitorService;
  final bool recordImpressions;

  @override
  State<AiSuggestedActionBar> createState() => _AiSuggestedActionBarState();
}

class _AiSuggestedActionBarState extends State<AiSuggestedActionBar> {
  final Set<String> _recordedImpressionKeys = <String>{};
  String? _activeSceneTitle;
  String? _activeSceneDescription;
  String? _lastFeedbackMessage;

  @override
  void initState() {
    super.initState();
    _recordNewImpressions();
  }

  @override
  void didUpdateWidget(covariant AiSuggestedActionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _recordNewImpressions();
  }

  void _recordNewImpressions() {
    if (!widget.recordImpressions || widget.actions.isEmpty) {
      return;
    }
    for (final action in widget.actions) {
      final dedupeKey = '${action.id}:${action.rawActionType}:${action.label}';
      if (_recordedImpressionKeys.add(dedupeKey)) {
        unawaited(
          _recordSafely(
            action: action,
            eventKind: 'impression',
          ),
        );
      }
    }
  }

  Future<AiSuggestedActionEvent?> _recordSafely({
    required AiSuggestedAction action,
    required String eventKind,
  }) async {
    try {
      return await widget.monitorService.recordActionEvent(
        action: action,
        eventKind: eventKind,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _handleTap(AiSuggestedAction action) async {
    final event = await _recordSafely(
      action: action,
      eventKind: 'click',
    );
    if (!mounted) {
      return;
    }

    late final String handledMode;
    late final String message;

    if (action.isPotentialCreatorDeception) {
      handledMode = 'safe_fallback_notice';
      message =
          '意図外または未定義のアクション (${action.rawActionType}) を検知したため安全フォールバックとして処理しました: 「${action.label}」';
      setState(() {
        _lastFeedbackMessage = message;
      });
    } else {
      switch (action.type) {
        case AiSuggestedActionType.narrativeChoice:
        case AiSuggestedActionType.genericNarrativeChoice:
          final reply = action.effectiveNarrativeReply;
          handledMode = 'narrative_reply';
          message = '会話分岐「$reply」を応答キューへ適用しました';
          setState(() {
            _lastFeedbackMessage = message;
          });
          widget.onSendNarrativeChoice?.call(reply);
          break;
        case AiSuggestedActionType.sceneTransition:
          handledMode = 'scene_transition';
          final title = action.sceneTitle ?? action.label;
          final desc =
              action.sceneDescription ?? action.effectiveNarrativeReply;
          message = 'シーンを「$title」へ移行しました';
          setState(() {
            _activeSceneTitle = title;
            _activeSceneDescription = desc;
            _lastFeedbackMessage = message;
          });
          widget.onSceneTransition?.call(action);
          break;
        case AiSuggestedActionType.openTool:
          final route = action.targetRoute;
          if (route != null && AiSuggestedAction.isSafeAppRoute(route)) {
            handledMode = 'safe_route';
            message = '画面遷移を実行: $route';
            setState(() {
              _lastFeedbackMessage = message;
            });
            widget.onNavigateRoute?.call(route);
          } else {
            handledMode = 'safe_fallback_notice';
            message = '安全な遷移先が確認できないため案内テキストとして処理しました: 「${action.label}」';
            setState(() {
              _lastFeedbackMessage = message;
            });
          }
          break;
        case AiSuggestedActionType.invite:
        case AiSuggestedActionType.renameSpace:
          handledMode = 'standard_callback';
          message =
              '標準アクション (${action.type.wireValue}) を実行しました: 「${action.label}」';
          setState(() {
            _lastFeedbackMessage = message;
          });
          widget.onStandardAction?.call(action);
          break;
        case AiSuggestedActionType.unknownFallback:
          handledMode = 'safe_fallback_notice';
          message = '未定義アクション (${action.rawActionType}) を安全フォールバックとして処理しました';
          setState(() {
            _lastFeedbackMessage = message;
          });
          break;
      }
    }

    widget.onActionHandled?.call(
      AiSuggestedActionExecutionResult(
        action: action,
        handledMode: handledMode,
        message: message,
        recordedEvent: event,
      ),
    );
  }

  IconData _iconFor(AiSuggestedAction action) {
    if (action.isPotentialCreatorDeception) {
      return Icons.warning_amber_rounded;
    }
    switch (action.type) {
      case AiSuggestedActionType.invite:
        return Icons.group_add_outlined;
      case AiSuggestedActionType.renameSpace:
        return Icons.drive_file_rename_outline;
      case AiSuggestedActionType.openTool:
        return Icons.open_in_new;
      case AiSuggestedActionType.narrativeChoice:
        return Icons.alt_route;
      case AiSuggestedActionType.sceneTransition:
        return Icons.auto_awesome;
      case AiSuggestedActionType.genericNarrativeChoice:
        return Icons.forum_outlined;
      case AiSuggestedActionType.unknownFallback:
        return Icons.shield_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.actions.isEmpty) {
      return const SizedBox.shrink();
    }
    final colorScheme = Theme.of(context).colorScheme;
    final activeSceneTitle = _activeSceneTitle;
    final activeSceneDescription = _activeSceneDescription;
    final lastFeedbackMessage = _lastFeedbackMessage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SizeTransition(
              sizeFactor: animation,
              axisAlignment: -1,
              child: child,
            ),
          ),
          child: activeSceneTitle == null
              ? const SizedBox.shrink()
              : Container(
                  key: ValueKey<String>('scene_$activeSceneTitle'),
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withAlpha(18),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF4F46E5).withAlpha(80),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        size: 18,
                        color: Color(0xFF4F46E5),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'シーン移行: $activeSceneTitle',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                            if (activeSceneDescription != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  activeSceneDescription,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onSurfaceVariant,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'シーン表示を閉じる',
                        iconSize: 16,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          setState(() {
                            _activeSceneTitle = null;
                            _activeSceneDescription = null;
                          });
                        },
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var index = 0; index < widget.actions.length; index++)
              _buildChip(
                context: context,
                action: widget.actions[index],
                index: index,
              ),
          ],
        ),
        if (lastFeedbackMessage != null)
          Container(
            key: const Key('ai_suggested_action_feedback'),
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withAlpha(110),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 15,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    lastFeedbackMessage,
                    style: const TextStyle(fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildChip({
    required BuildContext context,
    required AiSuggestedAction action,
    required int index,
  }) {
    final isFlagged = action.isPotentialCreatorDeception;
    final keyId = action.id.isEmpty ? 'idx_$index' : action.id;
    final fg = isFlagged
        ? const Color(0xFF92400E)
        : Theme.of(context).colorScheme.primary;
    final bg = isFlagged
        ? const Color(0xFFFEF3C7)
        : Theme.of(context).colorScheme.surfaceContainerLow;
    final border = isFlagged
        ? const Color(0xFFF59E0B)
        : Theme.of(context).colorScheme.outlineVariant;

    return Semantics(
      button: true,
      label: isFlagged
          ? '${action.label} (安全フォールバック: ${action.rawActionType})'
          : '${action.label} (${action.type.displayName})',
      child: OutlinedButton.icon(
        key: Key('ai_suggested_action_$keyId'),
        onPressed: () => _handleTap(action),
        icon: Icon(_iconFor(action), size: 16, color: fg),
        label: Text(
          isFlagged ? '${action.label} [安全フォールバック]' : action.label,
          style: TextStyle(fontSize: 12, color: fg, height: 1.3),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: bg,
          side: BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
    );
  }
}
