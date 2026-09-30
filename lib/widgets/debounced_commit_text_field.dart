import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Keeps keystrokes local; expensive parent work runs once after a typing burst.
class DebouncedCommitTextField extends StatefulWidget {
  const DebouncedCommitTextField({
    super.key,
    required this.controller,
    required this.onCommitted,
    required this.decoration,
    this.keyboardType,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final ValueChanged<String> onCommitted;
  final InputDecoration decoration;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<DebouncedCommitTextField> createState() =>
      _DebouncedCommitTextFieldState();
}

class _DebouncedCommitTextFieldState extends State<DebouncedCommitTextField> {
  final _focusNode = FocusNode();
  Timer? _timer;
  String? _pending;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) _commit();
  }

  void _onChanged(String value) {
    _pending = value;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 200), _commit);
  }

  void _commit() {
    _timer?.cancel();
    final value = _pending;
    _pending = null;
    // An explicit clear/restore from the parent wins over an old draft.
    if (mounted && value != null && value == widget.controller.text) {
      widget.onCommitted(value);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      decoration: widget.decoration,
      onChanged: _onChanged,
      onSubmitted: (_) => _commit(),
      onTapOutside: (_) {
        _commit();
        _focusNode.unfocus();
      },
    );
  }
}
