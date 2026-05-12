import 'package:flutter/material.dart';
import 'package:my_web_app/pages/privacy_policy_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const JibunMobileApp());
}

class JibunMobileApp extends StatelessWidget {
  const JibunMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Jibun Mobile',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3157D5),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      routes: {
        '/privacy': (_) => const PrivacyPolicyPage(showBackButton: false),
      },
      home: const MobileReleaseShell(),
    );
  }
}

class MobileReleaseShell extends StatelessWidget {
  const MobileReleaseShell({super.key});

  static const _readyItems = <_MobileSurfaceItem>[
    _MobileSurfaceItem(
      icon: Icons.today_outlined,
      title: 'Daily command center',
      subtitle: 'Review the one action that should move today forward.',
    ),
    _MobileSurfaceItem(
      icon: Icons.check_circle_outline,
      title: 'WBS quick status',
      subtitle: 'Track urgent work without loading the full web route graph.',
    ),
    _MobileSurfaceItem(
      icon: Icons.health_and_safety_outlined,
      title: 'Life operations',
      subtitle: 'Keep health, money, focus, and time loops visible.',
    ),
  ];

  static const _parkedItems = <String>[
    'Browser-only sharing and OGP generation',
    'Rich web dashboards that import package:web',
    'Desktop cleanup and Windows companion features',
    'Experimental media, audio, and JS interop tools',
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Jibun Mobile',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text('Native-safe first release shell'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _HeroPanel(colorScheme: colorScheme),
            const SizedBox(height: 20),
            const Text(
              'Included in the first native build',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            for (final item in _readyItems) ...[
              _SurfaceTile(item: item),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 12),
            const Text(
              'Parked until conditional imports are complete',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            const _ParkedPanel(items: _parkedItems),
          ],
        ),
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.phone_iphone_outlined,
            color: colorScheme.onPrimaryContainer,
            size: 36,
          ),
          const SizedBox(height: 16),
          Text(
            'A small native target that can ship while the web app stays rich.',
            style: TextStyle(
              color: colorScheme.onPrimaryContainer,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'The mobile artifact intentionally avoids browser APIs. Web-only pages stay available on Flutter Web and can be moved over one feature at a time.',
            style: TextStyle(
              color: colorScheme.onPrimaryContainer.withValues(alpha: 0.82),
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _SurfaceTile extends StatelessWidget {
  const _SurfaceTile({required this.item});

  final _MobileSurfaceItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE1E6F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, color: const Color(0xFF3157D5)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.subtitle,
                  style: const TextStyle(height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ParkedPanel extends StatelessWidget {
  const _ParkedPanel({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF101828),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lock_clock_outlined,
                    color: Color(0xFF9FB3C8),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        color: Colors.white,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MobileSurfaceItem {
  const _MobileSurfaceItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}
