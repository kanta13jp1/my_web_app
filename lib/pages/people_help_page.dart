import 'package:flutter/material.dart';

import '../services/people_leave_request_service.dart';
import 'note_editor_page.dart';
import 'note_list_page.dart';
import 'rewards_page.dart';

class PeopleHelpPage extends StatefulWidget {
  final Widget? onboardingNotePage;
  final PeopleLeaveRequestService leaveRequestService;

  const PeopleHelpPage({
    super.key,
    this.onboardingNotePage,
    this.leaveRequestService = const PeopleLeaveRequestService(),
  });

  @override
  State<PeopleHelpPage> createState() => _PeopleHelpPageState();
}

class _PeopleHelpPageState extends State<PeopleHelpPage> {
  static const List<String> _leaveTypes = <String>[
    'Paid leave',
    'Sick leave',
    'Special leave',
  ];

  List<PeopleLeaveRequest> _leaveRequests = const <PeopleLeaveRequest>[];
  bool _isLoadingLeaveRequests = true;
  bool _isSavingLeaveRequest = false;

  @override
  void initState() {
    super.initState();
    _loadLeaveRequests();
  }

  Future<void> _loadLeaveRequests() async {
    final requests = await widget.leaveRequestService.loadRequests();
    if (!mounted) {
      _leaveRequests = requests;
      _isLoadingLeaveRequests = false;
      return;
    }
    setState(() {
      _leaveRequests = requests;
      _isLoadingLeaveRequests = false;
    });
  }

  Future<void> _openLeaveRequestDialog() async {
    final request = await showDialog<PeopleLeaveRequest>(
      context: context,
      builder: (context) {
        return const _CreateLeaveRequestDialog(leaveTypes: _leaveTypes);
      },
    );

    if (request == null) {
      return;
    }

    setState(() => _isSavingLeaveRequest = true);
    try {
      final nextRequests =
          await widget.leaveRequestService.saveRequest(request);
      if (!mounted) {
        return;
      }
      setState(() {
        _leaveRequests = nextRequests;
        _isSavingLeaveRequest = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Leave request submitted for ${request.employeeName}.',
          ),
        ),
      );
    } finally {
      if (mounted && _isSavingLeaveRequest) {
        setState(() => _isSavingLeaveRequest = false);
      }
    }
  }

  Future<void> _updateLeaveRequestStatus(
    PeopleLeaveRequest request,
    String status,
  ) async {
    final nextRequests = await widget.leaveRequestService.updateStatus(
      request.id,
      status,
    );
    if (!mounted) {
      return;
    }
    setState(() => _leaveRequests = nextRequests);
    final label = switch (status) {
      'approved' => 'approved',
      'declined' => 'declined',
      _ => status,
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${request.employeeName} was $label.')),
    );
  }

  String _formatDateRange(PeopleLeaveRequest request) {
    String formatDate(DateTime value) {
      final month = value.month.toString().padLeft(2, '0');
      final day = value.day.toString().padLeft(2, '0');
      return '${value.year}-$month-$day';
    }

    return '${formatDate(request.startDate)} to ${formatDate(request.endDate)}';
  }

  Widget _buildLeaveStatusChip(String status) {
    final Color color;
    switch (status) {
      case 'approved':
        color = const Color(0xFF4CAF50);
        break;
      case 'declined':
        color = const Color(0xFFE53935);
        break;
      default:
        color = const Color(0xFFFF6B35);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildLeaveRequestsSection() {
    return Container(
      key: const Key('people_help_leave_requests_section'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF3D5AFE).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: const Color(0xFF3D5AFE).withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor:
                    const Color(0xFF3D5AFE).withValues(alpha: 0.12),
                child: const Icon(
                  Icons.event_available_outlined,
                  color: Color(0xFF3D5AFE),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Jobcan-style leave requests',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Track PTO requests, date ranges, and approval status in one place.',
                      style: TextStyle(
                        height: 1.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('people_help_leave_request_add_button'),
              onPressed: _isSavingLeaveRequest ? null : _openLeaveRequestDialog,
              icon: _isSavingLeaveRequest
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_task),
              label: const Text('New leave request'),
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoadingLeaveRequests)
            const Center(child: CircularProgressIndicator())
          else if (_leaveRequests.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'No leave requests yet. Add one to start tracking approvals.',
                    key: Key('people_help_leave_requests_empty'),
                  ),
                ),
              ),
            )
          else
            ..._leaveRequests.map((request) {
              return Card(
                key: Key('people_help_leave_request_card_${request.id}'),
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  request.employeeName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  request.leaveType,
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildLeaveStatusChip(request.status),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _formatDateRange(request),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        request.reason,
                        style: const TextStyle(height: 1.45),
                      ),
                      if (request.status == 'pending') ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.tonalIcon(
                              key: Key(
                                'people_help_leave_request_approve_${request.id}',
                              ),
                              onPressed: () => _updateLeaveRequestStatus(
                                request,
                                'approved',
                              ),
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Approve'),
                            ),
                            OutlinedButton.icon(
                              key: Key(
                                'people_help_leave_request_decline_${request.id}',
                              ),
                              onPressed: () => _updateLeaveRequestStatus(
                                request,
                                'declined',
                              ),
                              icon: const Icon(Icons.cancel_outlined),
                              label: const Text('Decline'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('people_help_page_scaffold'),
      appBar: AppBar(
        title: const Text(
          'People Help',
          key: Key('people_help_page_title'),
        ),
        backgroundColor: const Color(0xFF3D5AFE),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeroCard(),
          const SizedBox(height: 16),
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            context,
            tileKey: const Key('people_help_quick_notes'),
            title: 'Support notes',
            subtitle:
                'Capture onboarding notes, support memos, and team context.',
            icon: Icons.sticky_note_2_outlined,
            color: const Color(0xFF3D5AFE),
            page: const NoteListPage(),
            routeName: '/notes',
          ),
          _buildActionCard(
            context,
            tileKey: const Key('people_help_quick_onboarding'),
            title: 'Create onboarding memo',
            subtitle:
                'Open a starter note for day-one setup and coaching points.',
            icon: Icons.edit_note,
            color: const Color(0xFF3D5AFE),
            page: widget.onboardingNotePage ??
                const NoteEditorPage(
                  initialTitle: 'Onboarding memo',
                  initialContent:
                      'Team context\n- \n\nFirst-week checklist\n- Accounts and tools\n- Team introductions\n\n1:1 agenda\n- Role expectations\n- 30-day focus\n',
                ),
            routeName: '/note-editor',
          ),
          _buildActionCard(
            context,
            tileKey: const Key('people_help_quick_rewards'),
            title: 'Achievements & Rewards',
            subtitle: 'Review points, levels, badges, and recognition updates.',
            icon: Icons.card_giftcard,
            color: const Color(0xFFFF8F00),
            page: const RewardsPage(),
            routeName: '/rewards',
          ),
          const SizedBox(height: 24),
          _buildLeaveRequestsSection(),
          const SizedBox(height: 24),
          _buildChecklistSection(
            title: 'First-week checklist',
            icon: Icons.checklist,
            color: const Color(0xFF3D5AFE),
            items: const [
              'Share the first three priorities before the new teammate starts.',
              'Lock the first 1:1 schedule and feedback owner.',
              'Store onboarding notes in one place so managers can reuse them.',
            ],
          ),
          const SizedBox(height: 16),
          _buildChecklistSection(
            title: 'Signals to review next',
            icon: Icons.insights,
            color: const Color(0xFF3D5AFE),
            items: const [
              'Onboarding completion trend',
              'Open follow-up items from recent 1:1s',
              'Recognition cadence by team',
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      key: const Key('people_help_hero_card'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3949AB), Color(0xFF5C6BC0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3D5AFE).withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.people_alt_outlined,
                  color: Color(0xFF3D5AFE),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'CHRO workflows in one calm workspace',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            'Keep onboarding notes, leave requests, recognition, and people metrics in one page so the next action stays obvious.',
            style: TextStyle(
              color: Colors.white,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required Key tileKey,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Widget page,
    // 遷移先画面の URL。`RouteSettings.name` を付けないと
    // Flutter Web でブラウザの URL が更新されないため必須にしている。
    required String routeName,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        key: tileKey,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            height: 1.5,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            settings: RouteSettings(name: routeName),
            builder: (_) => page,
          ),
        ),
      ),
    );
  }

  Widget _buildChecklistSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<String> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle, size: 18, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateLeaveRequestDialog extends StatefulWidget {
  final List<String> leaveTypes;

  const _CreateLeaveRequestDialog({
    required this.leaveTypes,
  });

  @override
  State<_CreateLeaveRequestDialog> createState() =>
      _CreateLeaveRequestDialogState();
}

class _CreateLeaveRequestDialogState extends State<_CreateLeaveRequestDialog> {
  late final TextEditingController _employeeController;
  late final TextEditingController _startDateController;
  late final TextEditingController _endDateController;
  late final TextEditingController _reasonController;
  late String _selectedLeaveType;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _employeeController = TextEditingController();
    _startDateController = TextEditingController();
    _endDateController = TextEditingController();
    _reasonController = TextEditingController();
    _selectedLeaveType = widget.leaveTypes.first;
  }

  @override
  void dispose() {
    _employeeController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  DateTime? _parseDate(String input) {
    final normalized = input.trim();
    if (normalized.isEmpty) {
      return null;
    }
    return DateTime.tryParse(normalized);
  }

  void _submit() {
    final employeeName = _employeeController.text.trim();
    final reason = _reasonController.text.trim();
    final startDate = _parseDate(_startDateController.text);
    final endDate = _parseDate(_endDateController.text);

    if (employeeName.isEmpty ||
        reason.isEmpty ||
        startDate == null ||
        endDate == null) {
      setState(() {
        _validationMessage =
            'Fill in every field and use YYYY-MM-DD for dates.';
      });
      return;
    }
    if (endDate.isBefore(startDate)) {
      setState(() {
        _validationMessage = 'End date must be on or after the start date.';
      });
      return;
    }

    Navigator.of(context).pop(
      PeopleLeaveRequest(
        id: 'leave-${DateTime.now().microsecondsSinceEpoch}',
        employeeName: employeeName,
        leaveType: _selectedLeaveType,
        startDate: startDate,
        endDate: endDate,
        reason: reason,
        status: 'pending',
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create leave request'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('people_help_leave_request_employee_field'),
              controller: _employeeController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Employee name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const Key('people_help_leave_request_type_field'),
              initialValue: _selectedLeaveType,
              decoration: const InputDecoration(
                labelText: 'Leave type',
                border: OutlineInputBorder(),
              ),
              items: widget.leaveTypes
                  .map(
                    (leaveType) => DropdownMenuItem<String>(
                      value: leaveType,
                      child: Text(leaveType),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() => _selectedLeaveType = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('people_help_leave_request_start_field'),
              controller: _startDateController,
              decoration: const InputDecoration(
                labelText: 'Start date',
                hintText: 'YYYY-MM-DD',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('people_help_leave_request_end_field'),
              controller: _endDateController,
              decoration: const InputDecoration(
                labelText: 'End date',
                hintText: 'YYYY-MM-DD',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('people_help_leave_request_reason_field'),
              controller: _reasonController,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
            ),
            if (_validationMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _validationMessage!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('people_help_leave_request_submit_button'),
          onPressed: _submit,
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
