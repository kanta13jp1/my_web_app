import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../models/chat_incremental_rendering_config.dart';

class IncrementalChatTextView extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final ChatIncrementalRenderingConfig config;
  final bool animate;
  final VoidCallback? onCompleted;

  const IncrementalChatTextView({
    super.key,
    required this.text,
    this.style,
    this.config = const ChatIncrementalRenderingConfig(),
    this.animate = true,
    this.onCompleted,
  });

  @override
  State<IncrementalChatTextView> createState() =>
      _IncrementalChatTextViewState();
}

class _IncrementalChatTextViewState extends State<IncrementalChatTextView> {
  Timer? _timer;
  late List<String> _chunks;
  int _revealedCount = 0;

  @override
  void initState() {
    super.initState();
    _restartReveal();
  }

  @override
  void didUpdateWidget(covariant IncrementalChatTextView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.config.enabled != widget.config.enabled ||
        oldWidget.config.bufferUnit != widget.config.bufferUnit ||
        oldWidget.config.chunkDelayMs != widget.config.chunkDelayMs ||
        oldWidget.animate != widget.animate) {
      _restartReveal();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _restartReveal() {
    _timer?.cancel();
    _timer = null;
    _chunks = splitIncrementalBlocks(widget.text, widget.config.bufferUnit);
    if (!widget.animate || !widget.config.enabled || _chunks.length <= 1) {
      _revealedCount = _chunks.length;
      return;
    }
    _revealedCount = 1;
    _timer = Timer.periodic(
      Duration(milliseconds: widget.config.chunkDelayMs),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_revealedCount >= _chunks.length) {
          timer.cancel();
          widget.onCompleted?.call();
          return;
        }
        setState(() {
          _revealedCount++;
        });
        if (_revealedCount >= _chunks.length) {
          timer.cancel();
          widget.onCompleted?.call();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_chunks.isEmpty) {
      return Text(widget.text, style: widget.style);
    }
    final count = _revealedCount.clamp(0, _chunks.length);
    if (!widget.animate ||
        !widget.config.enabled ||
        widget.config.animationStyle == ChatIncrementalAnimationStyle.none ||
        count >= _chunks.length && _timer == null) {
      final visible = _chunks.take(count).join();
      return Text(visible, style: widget.style);
    }

    final stablePrefix = count > 1 ? _chunks.take(count - 1).join() : '';
    final latestChunk = count >= 1 ? _chunks[count - 1] : '';

    return Text.rich(
      TextSpan(
        style: widget.style,
        children: <InlineSpan>[
          if (stablePrefix.isNotEmpty) TextSpan(text: stablePrefix),
          if (latestChunk.isNotEmpty)
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: _buildAnimatedChunk(latestChunk, count),
            ),
        ],
      ),
    );
  }

  Widget _buildAnimatedChunk(String chunk, int generation) {
    final content = Text(chunk, style: widget.style);
    switch (widget.config.animationStyle) {
      case ChatIncrementalAnimationStyle.none:
        return content;
      case ChatIncrementalAnimationStyle.fade:
        return TweenAnimationBuilder<double>(
          key: ValueKey<String>('fade_${generation}_$chunk'),
          tween: Tween<double>(begin: 0.25, end: 1.0),
          duration: const Duration(milliseconds: 140),
          builder: (context, opacity, child) =>
              Opacity(opacity: opacity, child: child),
          child: content,
        );
      case ChatIncrementalAnimationStyle.blur:
        return TweenAnimationBuilder<double>(
          key: ValueKey<String>('blur_${generation}_$chunk'),
          tween: Tween<double>(begin: 2.0, end: 0.0),
          duration: const Duration(milliseconds: 160),
          builder: (context, sigma, child) => sigma <= 0.05
              ? child!
              : ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                  child: child,
                ),
          child: content,
        );
    }
  }
}
