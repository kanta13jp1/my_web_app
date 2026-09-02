import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_web_app/utils/tab_route_url_sync.dart';

/// DNS・ドメイン管理ページ
/// dns-domain-manager Edge Function と連携してドメイン設定を管理
/// Google Domains / Cloudflare / Amazon Route53 競合
class DnsDomainManagerPage extends StatefulWidget {
  const DnsDomainManagerPage({super.key});

  @override
  State<DnsDomainManagerPage> createState() => _DnsDomainManagerPageState();
}

class _DnsDomainManagerPageState extends State<DnsDomainManagerPage>
    with SingleTickerProviderStateMixin, TabRouteUrlSync {
  @override
  List<String> get tabUrlSlugs => const <String>['domains', 'records', 'ssl'];

  @override
  TabController get tabUrlController => _tabController;

  final _supabase = Supabase.instance.client;
  late final TabController _tabController;

  bool _isLoadingDomains = false;
  bool _isLoadingRecords = false;
  bool _isLoadingSsl = false;

  List<Map<String, dynamic>> _domains = [];
  List<Map<String, dynamic>> _records = [];
  List<Map<String, dynamic>> _sslStatus = [];

  Map<String, dynamic>? _selectedDomain;

  static const _recordTypes = [
    'A',
    'AAAA',
    'CNAME',
    'MX',
    'TXT',
    'NS',
    'SRV',
    'CAA',
  ];
  static const _registrars = [
    'Cloudflare',
    'Google Domains',
    'Amazon Route53',
    'お名前.com',
    'その他',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {}); // rebuild FAB
        if (_tabController.index == 2 && _sslStatus.isEmpty) {
          _fetchSslStatus();
        }
      }
    });
    _fetchDomains();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchDomains() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoadingDomains = false);
      return;
    }
    setState(() => _isLoadingDomains = true);
    try {
      final response = await _supabase.functions.invoke(
        'enterprise-hub',
        method: HttpMethod.get,
        queryParameters: {'view': 'domains'},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['domains'] is List) {
        setState(
          () =>
              _domains = (data['domains'] as List).cast<Map<String, dynamic>>(),
        );
      } else {
        setState(() => _domains = []);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ドメイン取得エラー: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingDomains = false);
    }
  }

  Future<void> _fetchRecords(String domainId) async {
    setState(() => _isLoadingRecords = true);
    try {
      final response = await _supabase.functions.invoke(
        'enterprise-hub',
        method: HttpMethod.get,
        queryParameters: {'view': 'records', 'domain_id': domainId},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['records'] is List) {
        setState(
          () =>
              _records = (data['records'] as List).cast<Map<String, dynamic>>(),
        );
      } else {
        setState(() => _records = []);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('DNSレコード取得エラー: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingRecords = false);
    }
  }

  Future<void> _fetchSslStatus() async {
    setState(() => _isLoadingSsl = true);
    try {
      final response = await _supabase.functions.invoke(
        'enterprise-hub',
        method: HttpMethod.get,
        queryParameters: {'view': 'ssl_status'},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['ssl'] is List) {
        setState(
          () => _sslStatus = (data['ssl'] as List).cast<Map<String, dynamic>>(),
        );
      } else {
        setState(() => _sslStatus = []);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('SSL情報取得エラー: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingSsl = false);
    }
  }

  Future<void> _addDomain(String domain, String registrar) async {
    try {
      final response = await _supabase.functions.invoke(
        'enterprise-hub',
        body: {
          'action': 'dns.add',
          'domain': domain,
          'registrar': registrar,
        },
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ドメインを追加しました')),
          );
        }
        await _fetchDomains();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ドメイン追加エラー: $e')),
        );
      }
    }
  }

  Future<void> _addRecord({
    required String domainId,
    required String recordType,
    required String name,
    required String value,
    int ttl = 3600,
    int? priority,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'enterprise-hub',
        body: {
          'action': 'dns.add_record',
          'domain_id': domainId,
          'record_type': recordType,
          'name': name,
          'value': value,
          'ttl': ttl,
          if (priority != null) 'priority': priority,
        },
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('DNSレコードを追加しました')),
          );
        }
        await _fetchRecords(domainId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('レコード追加エラー: $e')),
        );
      }
    }
  }

  Future<void> _deleteRecord(String recordId, String domainId) async {
    try {
      final response = await _supabase.functions.invoke(
        'enterprise-hub',
        body: {'action': 'dns.delete_record', 'record_id': recordId},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('レコードを削除しました')),
          );
        }
        await _fetchRecords(domainId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('レコード削除エラー: $e')),
        );
      }
    }
  }

  void _showAddDomainDialog() {
    final domainController = TextEditingController();
    String selectedRegistrar = _registrars.first;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialogState) => AlertDialog(
          title: const Text('ドメインを追加'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: domainController,
                decoration: const InputDecoration(
                  labelText: 'ドメイン名',
                  hintText: 'example.com',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedRegistrar,
                decoration: const InputDecoration(
                  labelText: 'レジストラ',
                  border: OutlineInputBorder(),
                ),
                items: _registrars
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) => setDialogState(() => selectedRegistrar = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () {
                final domain = domainController.text.trim();
                if (domain.isEmpty) return;
                Navigator.pop(ctx);
                _addDomain(domain, selectedRegistrar);
              },
              child: const Text('追加'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddRecordDialog(String domainId) {
    final nameController = TextEditingController();
    final valueController = TextEditingController();
    final ttlController = TextEditingController(text: '3600');
    final priorityController = TextEditingController();
    String selectedType = 'A';

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialogState) => AlertDialog(
          title: const Text('DNSレコードを追加'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'レコードタイプ',
                    border: OutlineInputBorder(),
                  ),
                  items: _recordTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedType = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'ホスト名',
                    hintText: '@または subdomain',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: valueController,
                  decoration: InputDecoration(
                    labelText: '値',
                    hintText: selectedType == 'A'
                        ? '192.168.1.1'
                        : selectedType == 'CNAME'
                            ? 'target.example.com'
                            : selectedType == 'MX'
                                ? 'mail.example.com'
                                : '値を入力',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ttlController,
                  decoration: const InputDecoration(
                    labelText: 'TTL (秒)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                if (selectedType == 'MX' || selectedType == 'SRV') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: priorityController,
                    decoration: const InputDecoration(
                      labelText: 'プライオリティ',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                final value = valueController.text.trim();
                if (name.isEmpty || value.isEmpty) return;
                final ttl = int.tryParse(ttlController.text) ?? 3600;
                final priority = int.tryParse(priorityController.text);
                Navigator.pop(ctx);
                _addRecord(
                  domainId: domainId,
                  recordType: selectedType,
                  name: name,
                  value: value,
                  ttl: ttl,
                  priority: priority,
                );
              },
              child: const Text('追加'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('DNS・ドメイン管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '更新',
            onPressed: () {
              _fetchDomains();
              if (_tabController.index == 2) _fetchSslStatus();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.language), text: 'ドメイン'),
            Tab(icon: Icon(Icons.dns), text: 'DNSレコード'),
            Tab(icon: Icon(Icons.lock), text: 'SSL'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDomainsTab(colorScheme),
          _buildRecordsTab(colorScheme),
          _buildSslTab(colorScheme),
        ],
      ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget? _buildFab() {
    if (_tabController.index == 0) {
      return FloatingActionButton.extended(
        onPressed: _showAddDomainDialog,
        icon: const Icon(Icons.add),
        label: const Text('ドメイン追加'),
      );
    }
    if (_tabController.index == 1 && _selectedDomain != null) {
      final domainId = _selectedDomain!['domain_id']?.toString() ?? '';
      return FloatingActionButton.extended(
        onPressed: () => _showAddRecordDialog(domainId),
        icon: const Icon(Icons.add),
        label: const Text('レコード追加'),
      );
    }
    return null;
  }

  Widget _buildDomainsTab(ColorScheme colorScheme) {
    if (_isLoadingDomains) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_domains.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.language, size: 64, color: colorScheme.outlineVariant),
            const SizedBox(height: 16),
            Text(
              'ドメインが登録されていません',
              style: TextStyle(
                color: colorScheme.outline,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _showAddDomainDialog,
              icon: const Icon(Icons.add),
              label: const Text('最初のドメインを追加'),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: _domains.length,
      itemBuilder: (context, index) {
        final domain = _domains[index];
        final status = domain['status']?.toString() ?? 'active';
        final isSelected = _selectedDomain != null &&
            _selectedDomain!['domain_id'] == domain['domain_id'];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: isSelected ? colorScheme.primaryContainer : null,
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: colorScheme.secondaryContainer,
              child:
                  Icon(Icons.language, color: colorScheme.onSecondaryContainer),
            ),
            title: Text(
              domain['domain']?.toString() ?? '',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(domain['registrar']?.toString() ?? 'レジストラ不明'),
                const SizedBox(height: 4),
                _buildStatusChip(status, colorScheme),
              ],
            ),
            trailing: isSelected
                ? Icon(Icons.check_circle, color: colorScheme.primary)
                : const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              setState(() => _selectedDomain = domain);
              final domainId = domain['domain_id']?.toString() ?? '';
              if (domainId.isNotEmpty) {
                _fetchRecords(domainId);
                _tabController.animateTo(1);
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildRecordsTab(ColorScheme colorScheme) {
    if (_selectedDomain == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.dns, size: 64, color: colorScheme.outlineVariant),
            const SizedBox(height: 16),
            Text(
              'ドメインタブでドメインを選択してください',
              style: TextStyle(
                color: colorScheme.outline,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _tabController.animateTo(0),
              child: const Text('ドメイン一覧へ'),
            ),
          ],
        ),
      );
    }

    final domainName = _selectedDomain!['domain']?.toString() ?? '';
    final domainId = _selectedDomain!['domain_id']?.toString() ?? '';

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              Icon(Icons.language, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                domainName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              Text(
                '${_records.length} レコード',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.outline,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingRecords
              ? const Center(child: CircularProgressIndicator())
              : _records.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.dns,
                            size: 64,
                            color: colorScheme.outlineVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'DNSレコードがありません',
                            style: TextStyle(
                              color: colorScheme.outline,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: () => _showAddRecordDialog(domainId),
                            icon: const Icon(Icons.add),
                            label: const Text('レコードを追加'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      itemCount: _records.length,
                      itemBuilder: (context, index) {
                        final record = _records[index];
                        final recordType =
                            record['record_type']?.toString() ?? '';
                        final recordId = record['record_id']?.toString() ?? '';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading:
                                _buildRecordTypeChip(recordType, colorScheme),
                            title: Text(
                              record['name']?.toString() ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                height: 1.5,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  record['value']?.toString() ?? '',
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                    height: 1.5,
                                  ),
                                ),
                                Text(
                                  'TTL: ${record['ttl'] ?? 3600}s',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colorScheme.outline,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                color: colorScheme.error,
                              ),
                              tooltip: 'レコードを削除',
                              onPressed: () =>
                                  _confirmDeleteRecord(recordId, domainId),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildSslTab(ColorScheme colorScheme) {
    if (_isLoadingSsl) {
      return const Center(child: CircularProgressIndicator());
    }

    // Auto-fetch if empty and domains available
    if (_sslStatus.isEmpty && _domains.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fetchSslStatus());
    }

    if (_sslStatus.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 64,
              color: colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'SSL情報がありません',
              style: TextStyle(
                color: colorScheme.outline,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _fetchSslStatus,
              icon: const Icon(Icons.refresh),
              label: const Text('SSL情報を取得'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _sslStatus.length,
      itemBuilder: (context, index) {
        final ssl = _sslStatus[index];
        final sslState = ssl['sslStatus']?.toString() ?? 'none';
        final expiresAt = ssl['expiresAt']?.toString();

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: _buildSslIcon(sslState, colorScheme),
            title: Text(
              ssl['domain']?.toString() ?? '',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                _buildSslStatusChip(sslState, colorScheme),
                if (expiresAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '有効期限: ${_formatDate(expiresAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.outline,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(String status, ColorScheme colorScheme) {
    Color color;
    String label;
    switch (status) {
      case 'active':
        color = const Color(0xFF4CAF50);
        label = '有効';
      case 'pending':
        color = const Color(0xFFFF6B35);
        label = '処理中';
      case 'expired':
        color = colorScheme.error;
        label = '期限切れ';
      case 'locked':
        color = colorScheme.outline;
        label = 'ロック中';
      default:
        color = colorScheme.outline;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildRecordTypeChip(String type, ColorScheme colorScheme) {
    final colors = {
      'A': const Color(0xFF3D5AFE),
      'AAAA': const Color(0xFF1976D2),
      'CNAME': const Color(0xFF3D5AFE),
      'MX': const Color(0xFFFF6B35),
      'TXT': const Color(0xFF3D5AFE),
      'NS': const Color(0xFF4CAF50),
      'SRV': const Color(0xFFE53935),
      'CAA': const Color(0xFF3D5AFE),
    };
    final color = colors[type] ?? colorScheme.primary;
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        type,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildSslIcon(String status, ColorScheme colorScheme) {
    switch (status) {
      case 'valid':
        return CircleAvatar(
          backgroundColor: const Color(0xFF4CAF50).withValues(alpha: 0.15),
          child: const Icon(Icons.lock, color: Color(0xFF4CAF50)),
        );
      case 'expiring_soon':
        return CircleAvatar(
          backgroundColor: const Color(0xFFFF6B35).withValues(alpha: 0.15),
          child: const Icon(Icons.lock_clock, color: Color(0xFFFF6B35)),
        );
      case 'expired':
        return CircleAvatar(
          backgroundColor: colorScheme.errorContainer,
          child: Icon(Icons.lock_open, color: colorScheme.error),
        );
      default:
        return CircleAvatar(
          backgroundColor: colorScheme.surfaceContainerHighest,
          child: Icon(Icons.lock_outline, color: colorScheme.outline),
        );
    }
  }

  Widget _buildSslStatusChip(String status, ColorScheme colorScheme) {
    Color color;
    String label;
    switch (status) {
      case 'valid':
        color = const Color(0xFF4CAF50);
        label = '有効';
      case 'expiring_soon':
        color = const Color(0xFFFF6B35);
        label = '間もなく期限切れ';
      case 'expired':
        color = colorScheme.error;
        label = '期限切れ';
      default:
        color = colorScheme.outline;
        label = '未設定';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
          height: 1.5,
        ),
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }

  void _confirmDeleteRecord(String recordId, String domainId) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('レコードを削除'),
        content: const Text('このDNSレコードを削除しますか？この操作は元に戻せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteRecord(recordId, domainId);
            },
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }
}
