import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../main.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});
  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  // Data
  List<Map<String, dynamic>> _subscriptions = [];
  List<Map<String, dynamic>> _paymentSources = []; //  決済ソースリスト

  // State
  bool _isLoading = true;
  bool _isAuditing = false;
  bool _isScanning = false;
  String? _auditResult;
  String? _usedModel;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchSubscriptions(),
      _fetchPaymentSources(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchSubscriptions() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      final response = await supabase
          .from('subscriptions')
          .select()
          .eq('user_id', userId)
          .order('price', ascending: false);
      if (mounted) {
        setState(
          () => _subscriptions = List<Map<String, dynamic>>.from(response),
        );
      }
    } catch (_) {}
  }

  Future<void> _fetchPaymentSources() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      final response = await supabase
          .from('payment_sources')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: true);
      if (mounted) {
        setState(
          () => _paymentSources = List<Map<String, dynamic>>.from(response),
        );
      }
    } catch (_) {}
  }

  // --- Payment Source Management ---

  Future<void> _addPaymentSource(String name) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      await supabase
          .from('payment_sources')
          .insert({'user_id': userId, 'name': name});
      _fetchPaymentSources();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('登録エラー: $e')));
    }
  }

  Future<void> _deletePaymentSource(int id) async {
    try {
      await supabase.from('payment_sources').delete().eq('id', id);
      _fetchPaymentSources();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('削除エラー: $e')));
    }
  }

  Future<void> _updateSourceAuditDate(int sourceId) async {
    try {
      await supabase
          .from('payment_sources')
          .update({'last_audited_at': DateTime.now().toIso8601String()}).eq(
        'id',
        sourceId,
      );
      _fetchPaymentSources();
    } catch (_) {}
  }

  void _showAddSourceDialog() {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('決済チャネルの追加'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: '名称 (例: PayPayカード, auかんたん決済)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                _addPaymentSource(nameCtrl.text);
                Navigator.pop(context);
              }
            },
            child: const Text('登録'),
          ),
        ],
      ),
    );
  }

  // --- Subscriptions Management ---

  Future<void> _addSubscription(
    String name,
    double price,
    String cycle,
    String desc,
  ) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      await supabase.from('subscriptions').insert({
        'user_id': userId,
        'service_name': name,
        'price': price,
        'billing_cycle': cycle,
        'description': desc,
      });
      _fetchSubscriptions();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('計上エラー: $e')));
    }
  }

  Future<void> _deleteSubscription(int id) async {
    try {
      await supabase.from('subscriptions').delete().eq('id', id);
      _fetchSubscriptions();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('契約解除エラー: $e')));
    }
  }

  // --- AI Scan Logic ---

  Future<void> _scanStatement(int? sourceId) async {
    await showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('証憑書類を撮影 (Camera)'),
              onTap: () {
                Navigator.pop(context);
                _processFile(ImageSource.camera, sourceId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('画像フォルダから参照'),
              onTap: () {
                Navigator.pop(context);
                _processFile(ImageSource.gallery, sourceId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('PDF明細をインポート'),
              onTap: () {
                Navigator.pop(context);
                _processPdf(sourceId);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processFile(ImageSource source, int? sourceId) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      imageQuality: 80,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    final base64 = base64Encode(bytes);
    await _analyzeStatement(base64, 'image/jpeg', sourceId);
  }

  Future<void> _processPdf(int? sourceId) async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.size > 4 * 1024 * 1024) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('ファイルサイズ超過(4MB以下)')));
        return;
      }
      final base64 = base64Encode(file.bytes!);
      await _analyzeStatement(base64, 'application/pdf', sourceId);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('読込エラー: $e')));
    }
  }

  Future<void> _analyzeStatement(
    String fileBase64,
    String mimeType,
    int? sourceId,
  ) async {
    setState(() => _isScanning = true);
    try {
      final response = await supabase.functions.invoke(
        'ai-assistant',
        body: {
          'action': 'extract_subscriptions_from_file',
          'fileBase64': fileBase64,
          'mimeType': mimeType,
        },
      );
      if (response.status != 200) {
        throw Exception('Server error: ${response.status}');
      }
      final data = response.data;
      if (data['success'] != true) throw Exception(data['error']);
      final result = data['result'];
      if (result is! List) throw Exception('Invalid response format');
      if (!mounted) return;

      // ソースIDがある場合（特定のカードの明細としてスキャンした場合）、監査日時を更新
      if (sourceId != null) {
        await _updateSourceAuditDate(sourceId);
      }

      _showScanResultDialog(result);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('解析失敗: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  void _showScanResultDialog(List<dynamic> items) {
    final selected = List<bool>.filled(items.length, true);
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text(' 検出された経常費用'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (items.isEmpty) const Text('該当する費用項目は見つかりませんでした。'),
                ...List.generate(items.length, (index) {
                  final item = items[index];
                  return CheckboxListTile(
                    value: selected[index],
                    onChanged: (v) =>
                        setStateDialog(() => selected[index] = v!),
                    title: Text(item['service_name'] ?? '不明'),
                    subtitle: Text(
                      '${item['price']}円 (${item['description'] ?? ''})',
                    ),
                    activeColor: Colors.teal,
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('破棄'),
            ),
            ElevatedButton(
              onPressed: items.isEmpty
                  ? null
                  : () async {
                      Navigator.pop(context);
                      for (int i = 0; i < items.length; i++) {
                        if (selected[i]) {
                          final item = items[i];
                          await _addSubscription(
                            item['service_name'] ?? '不明',
                            double.tryParse(
                                  item['price'].toString(),
                                ) ??
                                0,
                            'monthly',
                            item['description'] ?? 'AI自動検出',
                          );
                        }
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('予算への計上が完了しました'),
                        ),
                      );
                    },
              child: const Text('選択項目を計上'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runFinancialAudit() async {
    if (_subscriptions.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('監査対象の費用が存在しません')));
      return;
    }
    setState(() => _isAuditing = true);
    try {
      final response = await supabase.functions.invoke(
        'ai-assistant',
        body: {
          'action': 'audit_subscriptions',
          'subscriptions': _subscriptions,
        },
      );
      if (response.status != 200) {
        throw Exception('Server error: ${response.status}');
      }
      final data = response.data;
      if (data['success'] != true) throw Exception(data['error']);
      setState(() {
        _auditResult = data['result'];
        _usedModel = data['used_model'];
      });
      if (mounted) _showAuditResultDialog();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('監査エラー: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isAuditing = false);
    }
  }

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String cycle = 'monthly';
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('新規費用の計上'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: '勘定科目 (サービス名)'),
              ),
              TextField(
                controller: priceCtrl,
                decoration: const InputDecoration(labelText: '金額 (JPY)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: '摘要 (用途備考)'),
              ),
              DropdownButton<String>(
                value: cycle,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(
                    value: 'monthly',
                    child: Text('月次決算'),
                  ),
                  DropdownMenuItem(
                    value: 'yearly',
                    child: Text('年次決算'),
                  ),
                ],
                onChanged: (v) => setState(() => cycle = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取り消し'),
            ),
            ElevatedButton(
              onPressed: () {
                final price = double.tryParse(priceCtrl.text) ?? 0;
                if (nameCtrl.text.isNotEmpty && price > 0) {
                  _addSubscription(
                    nameCtrl.text,
                    price,
                    cycle,
                    descCtrl.text,
                  );
                }
              },
              child: const Text('承認計上'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAuditResultDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.gavel, color: Colors.red),
            SizedBox(width: 8),
            Expanded(child: Text('CFO 監査報告書')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_usedModel != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Auditor: $_usedModel',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.amber[900],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              MarkdownBody(data: _auditResult ?? ''),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Share.share(
                '【自分株式会社 財務監査報告】\nCFOによる厳格な監査の結果、以下の固定費是正勧告を受けました。\n\n${_auditResult?.substring(0, 50)}...\n\n ダウンロード: https://my-web-app-b67f4.web.app/\n#自分株式会社 #CFO',
                subject: 'CFO監査結果',
              );
            },
            icon: const Icon(Icons.share),
            label: const Text('株主へ報告 (シェア)'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('確認'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double monthlyTotal = 0;
    for (var sub in _subscriptions) {
      double price = (sub['price'] as num).toDouble();
      if (sub['billing_cycle'] == 'yearly') price /= 12;
      monthlyTotal += price;
    }

    // 今月の監査状況
    int auditedCount = 0;
    final now = DateTime.now();
    for (var source in _paymentSources) {
      if (source['last_audited_at'] != null) {
        final auditDate = DateTime.parse(source['last_audited_at']);
        if (auditDate.year == now.year && auditDate.month == now.month) {
          auditedCount++;
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(' 固定費削減室 (CFO)'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_card),
            tooltip: '決済チャネル追加',
            onPressed: _showAddSourceDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // KPI Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    color: Colors.teal.shade50,
                    child: Column(
                      children: [
                        const Text(
                          '月次固定費 (概算予算)',
                          style: TextStyle(fontSize: 14, color: Colors.teal),
                        ),
                        Text(
                          monthlyTotal.toStringAsFixed(0),
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                onPressed:
                                    _isAuditing ? null : _runFinancialAudit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                icon: _isAuditing
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.gavel),
                                label: const Text(
                                  '特別会計監査を実行',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Payment Sources (Monthly Closing)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.verified_user, color: Colors.teal),
                            const SizedBox(width: 8),
                            const Text(
                              '決済チャネル監査状況 (月次決算)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '$auditedCount / ${_paymentSources.length} 完了',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_paymentSources.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Text(
                                '右上のアイコンから\n使用しているカードや口座を登録してください',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ..._paymentSources.map((source) {
                          final lastAuditStr = source['last_audited_at'];
                          bool isAuditedThisMonth = false;
                          if (lastAuditStr != null) {
                            final d = DateTime.parse(lastAuditStr);
                            isAuditedThisMonth =
                                d.year == now.year && d.month == now.month;
                          }

                          return Card(
                            elevation: 0,
                            color: isAuditedThisMonth
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: isAuditedThisMonth
                                    ? Colors.green
                                    : Colors.red.shade200,
                              ),
                            ),
                            child: ListTile(
                              leading: Icon(
                                isAuditedThisMonth
                                    ? Icons.check_circle
                                    : Icons.warning_amber,
                                color: isAuditedThisMonth
                                    ? Colors.green
                                    : Colors.red,
                              ),
                              title: Text(source['name'] ?? ''),
                              subtitle: Text(
                                isAuditedThisMonth
                                    ? '監査完了: ${DateFormat('MM/dd').format(DateTime.parse(lastAuditStr))}'
                                    : '今月の明細が未確認です',
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.document_scanner),
                                tooltip: '明細をスキャン',
                                onPressed: () => _scanStatement(source['id']),
                              ),
                              onLongPress: () => showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('削除しますか？'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('キャンセル'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _deletePaymentSource(
                                          source['id'],
                                        );
                                      },
                                      child: const Text('削除'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const Divider(),

                  // Subscriptions List
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '計上済み経常費用一覧',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
                  if (_subscriptions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        '明細をスキャンするか、\n「+」で経常費用を計上してください',
                        textAlign: TextAlign.center,
                      ),
                    ),

                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _subscriptions.length,
                    itemBuilder: (context, index) {
                      final sub = _subscriptions[index];
                      final isMonthly = sub['billing_cycle'] == 'monthly';
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: ListTile(
                          title: Text(
                            sub['service_name'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(sub['description'] ?? ''),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${sub['price']} / ${isMonthly ? '月' : '年'}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.grey,
                                ),
                                onPressed: () => _deleteSubscription(sub['id']),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add),
      ),
    );
  }
}
