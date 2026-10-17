import 'package:flutter/material.dart';

/// A silent, still-image introduction; no video or audio dependency is needed.
class EchoPumpIntro extends StatefulWidget {
  const EchoPumpIntro({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<EchoPumpIntro> createState() => _EchoPumpIntroState();
}

class _EchoPumpIntroState extends State<EchoPumpIntro>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _headings = ['23:47 / 豪雨', '非常電源 / 残りわずか', '残響 / ポンプ室'];
  static const _captions = [
    '雨は止まない。\n地下の出口は、すでに水の下だった。',
    '排水ポンプを直すには、交換ヒューズがいる。\n工具庫へ向かわなければ。',
    '暗い廊下で、何かが動いた。\n機械の音に、近づいてくる。',
  ];

  late final AnimationController _controller;
  bool _finished = false;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _finish();
      });
    _controller.forward();
  }

  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    _controller.stop();
    widget.onFinished();
  }

  void _togglePause() {
    if (_finished) return;
    setState(() => _paused = !_paused);
    if (_paused) {
      _controller.stop();
    } else {
      _controller.forward();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_finished) return;
    if (state != AppLifecycleState.resumed) {
      _controller.stop();
    } else if (!_paused) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Theme(
      data: ThemeData.dark(useMaterial3: true),
      child: Scaffold(
        key: const Key('echo-intro'),
        backgroundColor: const Color(0xFF081318),
        body: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final progress = _controller.value;
            final scene = (progress * 3).floor().clamp(0, 2);
            final phase = (progress * 3 - scene).clamp(0.0, 1.0);
            final opacity = reduceMotion
                ? 1.0
                : (phase / 0.12).clamp(0.0, 1.0) *
                    ((1 - phase) / 0.12).clamp(0.0, 1.0);
            return Stack(
              fit: StackFit.expand,
              children: [
                ClipRect(
                  child: Transform.scale(
                    scale: reduceMotion ? 1 : 1 + progress * 0.07,
                    child: child,
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x99040B10), Color(0xEB040B10)],
                    ),
                  ),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text('導入  ${scene + 1} / 3'),
                            ),
                            TextButton(
                              key: const Key('echo-intro-skip'),
                              autofocus: true,
                              onPressed: _finish,
                              child: const Text('スキップして開始'),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(28),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 680),
                              child: Opacity(
                                opacity: opacity,
                                child: Semantics(
                                  liveRegion: true,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _headings[scene],
                                        key: const Key('echo-intro-heading'),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Color(0xFFA7DFD5),
                                          fontSize: 16,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      Text(
                                        _captions[scene],
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Color(0xFFF0F5F2),
                                          fontSize: 24,
                                          height: 1.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            LinearProgressIndicator(
                              value: progress,
                              color: const Color(0xFFA7DFD5),
                              backgroundColor: Colors.white12,
                              semanticsLabel: '導入の進行',
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              key: const Key('echo-intro-pause'),
                              onPressed: _togglePause,
                              icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
                              label: Text(_paused ? '再開' : '一時停止'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
          child: Image.asset(
            'assets/echo_pump/opening_background.png',
            fit: BoxFit.cover,
            alignment: Alignment.centerRight,
            excludeFromSemantics: true,
            errorBuilder: (context, error, stackTrace) => const ColoredBox(
              color: Color(0xFF081318),
            ),
          ),
        ),
      ),
    );
  }
}
