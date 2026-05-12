import 'package:flutter/material.dart';

import '../services/ai_share_button_preferences_service.dart';

class AiShareButtonSettingsPanel extends StatefulWidget {
  final EdgeInsetsGeometry padding;

  const AiShareButtonSettingsPanel({
    super.key,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  State<AiShareButtonSettingsPanel> createState() =>
      _AiShareButtonSettingsPanelState();
}

class _AiShareButtonSettingsPanelState
    extends State<AiShareButtonSettingsPanel> {
  AiShareButtonPreferencesController get _controller =>
      aiShareButtonPreferencesController;

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  Future<void> _updateVisible(bool visible) async {
    try {
      await _controller.updateVisible(visible);
    } catch (_) {
      _showSaveError();
    }
  }

  Future<void> _updatePosition(AiShareButtonPosition position) async {
    try {
      await _controller.updatePosition(position);
    } catch (_) {
      _showSaveError();
    }
  }

  void _showSaveError() {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('AIシェアボタン設定の保存に失敗しました')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final preferences = _controller.preferences;
        return Padding(
          padding: widget.padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(
                  preferences.visible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                title: const Text('AIシェアボタン'),
                subtitle: Text(preferences.visible ? '表示中' : '非表示'),
                value: preferences.visible,
                onChanged: _updateVisible,
              ),
              const SizedBox(height: 12),
              Text(
                '表示位置',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<AiShareButtonPosition>(
                  showSelectedIcon: false,
                  segments: AiShareButtonPosition.values
                      .map(
                        (position) => ButtonSegment<AiShareButtonPosition>(
                          value: position,
                          icon: Icon(position.icon),
                          label: Text(position.label),
                        ),
                      )
                      .toList(),
                  selected: <AiShareButtonPosition>{preferences.position},
                  onSelectionChanged: (selection) {
                    if (selection.isNotEmpty) {
                      _updatePosition(selection.first);
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

extension _AiShareButtonPositionUi on AiShareButtonPosition {
  String get label {
    switch (this) {
      case AiShareButtonPosition.topLeft:
        return '左上';
      case AiShareButtonPosition.topRight:
        return '右上';
      case AiShareButtonPosition.bottomLeft:
        return '左下';
      case AiShareButtonPosition.bottomRight:
        return '右下';
    }
  }

  IconData get icon {
    switch (this) {
      case AiShareButtonPosition.topLeft:
        return Icons.north_west;
      case AiShareButtonPosition.topRight:
        return Icons.north_east;
      case AiShareButtonPosition.bottomLeft:
        return Icons.south_west;
      case AiShareButtonPosition.bottomRight:
        return Icons.south_east;
    }
  }
}
