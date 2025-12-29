import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../main.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});
  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  List<Map<String, dynamic>> _subscriptions = [];
  bool _isLoading = true;
  bool _isAuditing = false;
  bool _isScanning = false;
  String? _auditResult;
  String? _usedModel;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchSubscriptions();
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
      if (mounted)
        setState(() {
          _subscriptions = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addSubscription(
      String name, double price, String cycle, String desc) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      await supabase.from('subscriptions').insert({
        'user_id': userId,
        'service_name': name,
        'price': price,
        'billing_cycle': cycle,
        'description': desc
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

  Future<void> _scanStatement() async {
    await showModalBottomSheet(
        context: context,
        builder: (context) => SafeArea(
                child: Wrap(children: [
              ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('証憑書類を撮影 (Camera)'),
                  onTap: () {
                    Navigator.pop(context);
                    _processFile(ImageSource.camera);
                  }),
              ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('画像フォルダから参照'),
                  onTap: () {
                    Navigator.pop(context);
                    _processFile(ImageSource.gallery);
                  }),
              ListTile(
                  leading: const Icon(Icons.picture_as_pdf),
                  title: const Text('PDF明細をインポート'),
                  onTap: () {
                    Navigator.pop(context);
                    _processPdf();
                  }),
            ])));
  }

  Future<void> _processFile(ImageSource source) async {
    final XFile? image = await _picker.pickImage(
        source: source, maxWidth: 1024, imageQuality: 80);
    if (image == null) return;
    final bytes = await image.readAsBytes();
    final base64 = base64Encode(bytes);
    await _analyzeStatement(base64, 'image/jpeg');
  }

  Future<void> _processPdf() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom, allowedExtensions: ['pdf'], withData: true);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.size > 4 * 1024 * 1024) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('ファイルサイズ超過(4MB以下)')));
        return;
      }
      final base64 = base64Encode(file.bytes!);
      await _analyzeStatement(base64, 'application/pdf');
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('読込エラー: $e')));
    }
  }

  Future<void> _analyzeStatement(String fileBase64, String mimeType) async {
    setState(() => _isScanning = true);
    try {
      final response = await supabase.functions.invoke('ai-assistant', body: {
        'action': 'extract_subscriptions_from_file',
        'fileBase64': fileBase64,
        'mimeType': mimeType
      });
      if (response.status != 200)
        throw Exception('Server error: ${response.status}');
      final data = response.data;
      if (data['success'] != true) throw Exception(data['error']);
      final result = data['result'];
      if (result is! List) throw Exception('Invalid response format');
      if (!mounted) return;
      _showScanResultDialog(result);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('解析失敗: $e'), backgroundColor: Colors.red));
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
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      if (items.isEmpty) const Text('該当する費用項目は見つかりませんでした。'),
                      ...List.generate(items.length, (index) {
                        final item = items[index];
                        return CheckboxListTile(
                            value: selected[index],
                            onChanged: (v) =>
                                setStateDialog(() => selected[index] = v!),
                            title: Text(item['service_name'] ?? '不明'),
                            subtitle: Text(
                                '${item['price']}円 (${item['description'] ?? ''})'),
                            activeColor: Colors.teal);
                      })
                    ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('破棄')),
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
                                                  item['price'].toString()) ??
                                              0,
                                          'monthly',
                                          item['description'] ?? 'AI自動検出');
                                    }
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('予算への計上が完了しました')));
                                },
                          child: const Text('選択項目を計上'))
                    ])));
  }

  Future<void> _runFinancialAudit() async {
    if (_subscriptions.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('監査対象の費用が存在しません')));
      return;
    }
    setState(() => _isAuditing = true);
    try {
      final response = await supabase.functions.invoke('ai-assistant', body: {
        'action': 'audit_subscriptions',
        'subscriptions': _subscriptions
      });
      if (response.status != 200)
        throw Exception('Server error: ${response.status}');
      final data = response.data;
      if (data['success'] != true) throw Exception(data['error']);
      setState(() {
        _auditResult = data['result'];
        _usedModel = data['used_model'];
      });
      if (mounted) _showAuditResultDialog();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('監査エラー: $e'), backgroundColor: Colors.red));
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
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      TextField(
                          controller: nameCtrl,
                          decoration:
                              const InputDecoration(labelText: '勘定科目 (サービス名)')),
                      TextField(
                          controller: priceCtrl,
                          decoration:
                              const InputDecoration(labelText: '金額 (JPY)'),
                          keyboardType: TextInputType.number),
                      TextField(
                          controller: descCtrl,
                          decoration:
                              const InputDecoration(labelText: '摘要 (用途備考)')),
                      DropdownButton<String>(
                          value: cycle,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(
                                value: 'monthly', child: Text('月次決算')),
                            DropdownMenuItem(
                                value: 'yearly', child: Text('年次決算'))
                          ],
                          onChanged: (v) => setState(() => cycle = v!))
                    ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('取り消し')),
                      ElevatedButton(
                          onPressed: () {
                            final price = double.tryParse(priceCtrl.text) ?? 0;
                            if (nameCtrl.text.isNotEmpty && price > 0)
                              _addSubscription(
                                  nameCtrl.text, price, cycle, descCtrl.text);
                          },
                          child: const Text('承認計上'))
                    ])));
  }

  void _showAuditResultDialog() {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
                title: const Row(children: [
                  Icon(Icons.gavel, color: Colors.red),
                  SizedBox(width: 8),
                  Expanded(child: Text('CFO 監査報告書'))
                ]),
                content: SingleChildScrollView(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                      if (_usedModel != null)
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                                color: Colors.amber[100],
                                borderRadius: BorderRadius.circular(4)),
                            child: Text('Auditor: $_usedModel',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.amber[900],
                                    fontWeight: FontWeight.bold))),
                      MarkdownBody(data: _auditResult ?? '')
                    ])),
                actions: [
                  TextButton.icon(
                      onPressed: () {
                        Share.share(
                            '【自分株式会社 財務監査報告】\nCFOによる厳格な監査の結果、以下の固定費是正勧告を受けました。\n\n${_auditResult?.substring(0, 50)}...\n\n ダウンロード: https://my-web-app-b67f4.web.app/\n#自分株式会社 #CFO',
                            subject: 'CFO監査結果');
                      },
                      icon: const Icon(Icons.share),
                      label: const Text('株主へ報告 (シェア)')),
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('確認'))
                ]));
  }

  @override
  Widget build(BuildContext context) {
    double monthlyTotal = 0;
    for (var sub in _subscriptions) {
      double price = (sub['price'] as num).toDouble();
      if (sub['billing_cycle'] == 'yearly') price /= 12;
      monthlyTotal += price;
    }
    return Scaffold(
      appBar: AppBar(
          title: const Text(' 固定費削減室 (CFO)'),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Container(
                  padding: const EdgeInsets.all(20),
                  color: Colors.teal.shade50,
                  child: Column(children: [
                    const Text('月次固定費 (概算予算)',
                        style: TextStyle(fontSize: 14, color: Colors.teal)),
                    Text('${monthlyTotal.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal)),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                          child: ElevatedButton.icon(
                              onPressed: _isScanning ? null : _scanStatement,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.teal,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: const BorderSide(
                                          color: Colors.teal))),
                              icon: _isScanning
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.document_scanner),
                              label: const Text('監査資料読込',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)))),
                      const SizedBox(width: 12),
                      Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                              onPressed:
                                  _isAuditing ? null : _runFinancialAudit,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12)),
                              icon: _isAuditing
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.gavel),
                              label: const Text('特別会計監査を実行',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))))
                    ])
                  ])),
              Expanded(
                  child: _subscriptions.isEmpty
                      ? const Center(
                          child: Text('監査資料をスキャンするか、\n「+」で経常費用を計上してください'))
                      : ListView.builder(
                          itemCount: _subscriptions.length,
                          itemBuilder: (context, index) {
                            final sub = _subscriptions[index];
                            final isMonthly = sub['billing_cycle'] == 'monthly';
                            return Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: ListTile(
                                    title: Text(sub['service_name'],
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    subtitle: Text(sub['description'] ?? ''),
                                    trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                              '${sub['price']} / ${isMonthly ? '月' : '年'}',
                                              style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold)),
                                          const SizedBox(width: 8),
                                          IconButton(
                                              icon: const Icon(Icons.delete,
                                                  color: Colors.grey),
                                              onPressed: () =>
                                                  _deleteSubscription(
                                                      sub['id']))
                                        ])));
                          })),
            ]),
      floatingActionButton: FloatingActionButton(
          onPressed: _showAddDialog,
          backgroundColor: Colors.teal,
          child: const Icon(Icons.add)),
    );
  }
}
