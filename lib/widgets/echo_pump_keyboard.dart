import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Opt-in, route-scoped controls. Existing game actions remain authoritative.
class EchoPumpKeyboardScope extends StatefulWidget {
  const EchoPumpKeyboardScope({
    super.key,
    required this.enabled,
    required this.onCommand,
    required this.child,
  });

  final bool enabled;
  final bool Function(BuildContext context, String command) onCommand;
  final Widget child;

  @override
  State<EchoPumpKeyboardScope> createState() => _EchoPumpKeyboardScopeState();
}

class _EchoPumpKeyboardScopeState extends State<EchoPumpKeyboardScope> {
  final _focus = FocusNode(debugLabel: 'echo-pump-keyboard');

  @override
  void didUpdateWidget(EchoPumpKeyboardScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !oldWidget.enabled) _focus.requestFocus();
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final keyboard = HardwareKeyboard.instance;
    if (!widget.enabled ||
        event is! KeyDownEvent ||
        keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isAltPressed ||
        keyboard.isShiftPressed ||
        ModalRoute.of(context)?.isCurrent == false) {
      return KeyEventResult.ignored;
    }
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused?.findAncestorWidgetOfExactType<EditableText>() != null) {
      return KeyEventResult.ignored;
    }
    final command = switch (event.logicalKey) {
      LogicalKeyboardKey.keyW => 'wait',
      LogicalKeyboardKey.keyI => 'inventory',
      LogicalKeyboardKey.keyA => 'a',
      LogicalKeyboardKey.keyB => 'b',
      LogicalKeyboardKey.keyC => 'c',
      _ => null,
    };
    return command != null && widget.onCommand(context, command)
        ? KeyEventResult.handled
        : KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) =>
      Focus(focusNode: _focus, onKeyEvent: _onKey, child: widget.child);
}
