import 'package:flutter/material.dart';
import 'package:my_web_app/models/kgi_csf_kpi.dart';
import 'package:my_web_app/widgets/kgi_csf_kpi_panel.dart';

const _plan = KgiCsfKpiPlan(
  domain: '演習',
  kgi: '進み具合',
  actualLabel: '3件',
  targetLabel: '4件',
  progress: 0.75,
  metrics: [
    KgiCsfKpiMetric(
      csf: '確認',
      kpi: '完了数',
      actualLabel: '3',
      targetLabel: '4',
      progress: 0.75,
    ),
  ],
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final origin = Uri.base;
  if (!const bool.fromEnvironment('ASSET_PANEL_FIXTURE') ||
      origin.scheme != 'http' ||
      origin.host != '127.0.0.1' ||
      origin.port != 7362) {
    throw StateError(
      'Expected the synthetic asset panel on loopback port 7362.',
    );
  }
  WidgetsBinding.instance.ensureSemantics();
  final dark = origin.queryParameters['appearance'] == 'dark-dense';
  runApp(
    MaterialApp(
      theme: ThemeData(
        brightness: dark ? Brightness.dark : Brightness.light,
        fontFamily: 'NotoSansJP',
      ),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(media.size.width <= 390 ? 1.6 : 1),
          ),
          child: child!,
        );
      },
      home: _PanelFixture(dark: dark),
    ),
  );
}

class _PanelFixture extends StatelessWidget {
  const _PanelFixture({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                children: [
                  Text('表示倍率 ${scale.toStringAsFixed(1)}倍'),
                  Card(
                    color: dark ? const Color(0xFF1E293B) : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Semantics(
                        identifier: 'asset-panel-bounds',
                        container: true,
                        explicitChildNodes: true,
                        child: KgiCsfKpiPanel(
                          plan: _plan,
                          accentColor: const Color(0xFF0F766E),
                          dark: dark,
                          dense: dark,
                          initiallyExpanded: !dark,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
