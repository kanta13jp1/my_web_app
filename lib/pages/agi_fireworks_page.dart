import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/platform_view.dart' as platform_view;

class AgiFireworksPage extends StatefulWidget {
  const AgiFireworksPage({super.key});

  static const videoAssetPath =
      '/assets/videos/agi-fireworks-2026-07-15-to-2026-08-14.mp4';

  @override
  State<AgiFireworksPage> createState() => _AgiFireworksPageState();
}

class _AgiFireworksPageState extends State<AgiFireworksPage> {
  late final String _videoViewType;

  @override
  void initState() {
    super.initState();
    _videoViewType = 'agi-fireworks-video-${identityHashCode(this)}';
    if (kIsWeb) {
      platform_view.registerVideoViewFactory(
        _videoViewType,
        AgiFireworksPage.videoAssetPath,
      );
    }
  }

  Future<void> _openVideo() async {
    await launchUrl(
      Uri.base.resolve(AgiFireworksPage.videoAssetPath),
      mode: LaunchMode.platformDefault,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'AGI Fireworks',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            height: 1.4,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _HeroCard(),
                  const SizedBox(height: 16),
                  _VideoCard(
                    videoViewType: _videoViewType,
                    onOpenVideo: _openVideo,
                  ),
                  const SizedBox(height: 16),
                  const _PrivacyNotice(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('agi-fireworks-hero'),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF3D5AFE).withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B35).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              '2026/07/15 – 08/14',
              style: TextStyle(
                color: Color(0xFFFFA07A),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'AIエージェントとの1か月を、\n打ち上げ花火で振り返る',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.4,
              letterSpacing: 0.96,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Claude、Codex、Antigravityなどのセッションを、夜空に広がる花火として可視化しました。',
            style: TextStyle(
              color: Color(0xFFB0B0B0),
              fontSize: 14,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 20),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricChip(icon: Icons.terminal, label: '1,129 shells'),
              _MetricChip(
                icon: Icons.nights_stay_outlined,
                label: '25 active nights',
              ),
              _MetricChip(
                icon: Icons.build_outlined,
                label: '46,571 tool calls',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A).withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF7986CB)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFE5E7EB),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.videoViewType, required this.onOpenVideo});

  final String videoViewType;
  final VoidCallback onOpenVideo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF6B35).withValues(alpha: 0.26),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            key: const Key('agi-fireworks-video-frame'),
            aspectRatio: 1044 / 494,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ColoredBox(
                color: Colors.black,
                child: kIsWeb
                    ? HtmlElementView(viewType: videoViewType)
                    : const _WebPlaybackFallback(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '再生時間 1:08 ・ 音声あり',
                  style: TextStyle(
                    color: Color(0xFFB0B0B0),
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
              ),
              TextButton.icon(
                key: const Key('agi-fireworks-open-video'),
                onPressed: onOpenVideo,
                icon: const Icon(Icons.open_in_new, size: 17),
                label: const Text('動画を別タブで開く'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFF6B35),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WebPlaybackFallback extends StatelessWidget {
  const _WebPlaybackFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'この動画はWeb版のmy_web_appで再生できます。',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFFB0B0B0), fontSize: 13, height: 1.6),
        ),
      ),
    );
  }
}

class _PrivacyNotice extends StatelessWidget {
  const _PrivacyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('agi-fireworks-privacy-notice'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC107).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFFC107).withValues(alpha: 0.28),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.privacy_tip_outlined, color: Color(0xFFFFC107), size: 21),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '共有前にご確認ください：映像にはプロジェクト名やセッション時刻が含まれます。公開範囲に注意してください。',
              style: TextStyle(
                color: Color(0xFFE5E7EB),
                fontSize: 13,
                height: 1.7,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
