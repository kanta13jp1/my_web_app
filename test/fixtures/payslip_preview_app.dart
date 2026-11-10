import 'package:flutter/material.dart';
import 'package:my_web_app/widgets/payslip_preview_panel.dart';

const _owner = 'synthetic-owner';
const _path = 'synthetic-owner/example.pdf';

enum _Case { current, wrongOwner, wrongPath, legacy }

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final origin = Uri.base;
  if (!const bool.fromEnvironment('PAYSLIP_PREVIEW_FIXTURE') ||
      origin.scheme != 'http' ||
      origin.host != '127.0.0.1' ||
      origin.port != 7362) {
    throw StateError('This synthetic fixture requires loopback port 7362.');
  }
  WidgetsBinding.instance.ensureSemantics();
  runApp(
    MaterialApp(
      theme: ThemeData(fontFamily: 'NotoSansJP'),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(media.size.width <= 390 ? 1.6 : 1),
          ),
          child: child!,
        );
      },
      home: const _Fixture(),
    ),
  );
}

PayslipPreview? _decode(_Case sample) => PayslipPreview.fromResponse(
      {
        'success': true,
        'status': sample == _Case.legacy ? 'parsed' : 'preview_only',
        if (sample != _Case.legacy) 'persisted': false,
        'payslip': {
          'user_id': sample == _Case.wrongOwner ? 'synthetic-other' : _owner,
          'source_pdf_path':
              sample == _Case.wrongPath ? 'synthetic-owner/other.pdf' : _path,
          'review_status': 'needs_review',
        },
        'parsed': {
          'pay_date': '2032-04-01',
          'company_name': '架空の試験組織',
          'gross_amount': 0,
          'net_amount': 37,
          'taxable_amount': 0,
          'social_insurance_total': null,
        },
        'warnings': ['非表示の試験用警告原文'],
        'masked_text_preview': '非表示の試験用抽出本文',
      },
      owner: _owner,
      storagePath: _path,
    );

class _Fixture extends StatefulWidget {
  const _Fixture();
  @override
  State<_Fixture> createState() => _FixtureState();
}

class _FixtureState extends State<_Fixture> {
  PayslipPreview? _preview = _decode(_Case.current);
  String _status = '合成応答を表示中';

  void _apply(_Case sample) {
    final preview = _decode(sample);
    setState(() {
      _preview = preview;
      _status = preview == null ? '応答を拒否しました' : '合成応答を表示中';
    });
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 850),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('給与プレビューの合成画面試験'),
                    Text('表示倍率 ${scale.toStringAsFixed(1)}倍'),
                    Text(_status),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: () => _apply(_Case.current),
                          child: const Text('正常な合成応答を表示'),
                        ),
                        TextButton(
                          onPressed: () => _apply(_Case.wrongOwner),
                          child: const Text('別の所有者の応答'),
                        ),
                        TextButton(
                          onPressed: () => _apply(_Case.wrongPath),
                          child: const Text('異なる保管先の応答'),
                        ),
                        TextButton(
                          onPressed: () => _apply(_Case.legacy),
                          child: const Text('旧形式の応答'),
                        ),
                      ],
                    ),
                    if (_preview != null)
                      PayslipPreviewPanel(
                        key: ObjectKey(_preview),
                        preview: _preview!,
                        onDismiss: () => setState(() {
                          _preview = null;
                          _status = '画面内の入力を破棄しました';
                        }),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
