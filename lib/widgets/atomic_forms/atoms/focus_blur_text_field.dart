import 'package:flutter/material.dart';

/// フォーカスアウト時（Blur）に即時クライアント側バリデーションを実行する Atom 入力フィールド (#2730)。
class FocusBlurTextField extends StatefulWidget {
  const FocusBlurTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.validator,
    this.labelText,
    this.hintText,
    this.keyboardType,
    this.minLines,
    this.maxLines = 1,
    this.onChanged,
    this.enabled = true,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? Function(String value)? validator;
  final String? labelText;
  final String? hintText;
  final TextInputType? keyboardType;
  final int? minLines;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  @override
  State<FocusBlurTextField> createState() => FocusBlurTextFieldState();
}

class FocusBlurTextFieldState extends State<FocusBlurTextField> {
  TextEditingController? _internalController;
  FocusNode? _internalFocusNode;
  bool _hasReceivedFocus = false;
  String? _errorText;

  TextEditingController get _effectiveController =>
      widget.controller ?? (_internalController ??= TextEditingController());

  FocusNode get _effectiveFocusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  String? get errorText => _errorText;

  @override
  void initState() {
    super.initState();
    _effectiveFocusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant FocusBlurTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _internalFocusNode)
          ?.removeListener(_handleFocusChange);
      _effectiveFocusNode.addListener(_handleFocusChange);
    }
  }

  @override
  void dispose() {
    _effectiveFocusNode.removeListener(_handleFocusChange);
    _internalController?.dispose();
    _internalFocusNode?.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (_effectiveFocusNode.hasFocus) {
      _hasReceivedFocus = true;
      return;
    }
    if (_hasReceivedFocus) {
      validateNow();
    }
  }

  /// 現在の入力値を即座に検証し、エラー表示を更新して妥当性を返す。
  bool validateNow() {
    final nextError = widget.validator?.call(_effectiveController.text);
    if (mounted && nextError != _errorText) {
      setState(() {
        _errorText = nextError;
      });
    } else {
      _errorText = nextError;
    }
    return nextError == null;
  }

  /// エラー表示をリセットする。
  void clearValidation() {
    if (mounted) {
      setState(() {
        _errorText = null;
        _hasReceivedFocus = false;
      });
    } else {
      _errorText = null;
      _hasReceivedFocus = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _effectiveController,
      focusNode: _effectiveFocusNode,
      enabled: widget.enabled,
      keyboardType: widget.keyboardType,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      onChanged: (value) {
        if (_errorText != null) {
          validateNow();
        }
        widget.onChanged?.call(value);
      },
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: widget.hintText,
        errorText: _errorText,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
