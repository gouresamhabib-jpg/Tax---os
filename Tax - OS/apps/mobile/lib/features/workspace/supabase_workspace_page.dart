import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_environment.dart';

class SupabaseWorkspacePage extends StatefulWidget {
  const SupabaseWorkspacePage({
    required this.locale,
    required this.onToggleLocale,
    required this.membershipId,
    required this.firmId,
    required this.firmName,
    required this.role,
    super.key,
  });

  final String locale;
  final VoidCallback onToggleLocale;
  final String membershipId;
  final String firmId;
  final String firmName;
  final String role;

  @override
  State<SupabaseWorkspacePage> createState() => _SupabaseWorkspacePageState();
}

class _SupabaseWorkspacePageState extends State<SupabaseWorkspacePage> {
  int _selectedIndex = 0;
  late final _db = Supabase.instance.client.schema(AppEnvironment.supabaseSchema);
  late Future<List<Map<String, dynamic>>> _clientsFuture;
  late Future<List<Map<String, dynamic>>> _tasksFuture;
  late Future<List<Map<String, dynamic>>> _membersFuture;

  bool get _isArabic => widget.locale == 'ar';
  bool get _canManage => const {'owner', 'admin', 'manager'}.contains(widget.role);
  String tr(String ar, String en) => _isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<List<Map<String, dynamic>>> _loadClients() async {
    final rows = await _db
        .from('clients')
        .select('id, client_type, display_name, email, phone, notes, archived_at')
        .eq('firm_id', widget.firmId)
        .isFilter('archived_at', null)
        .order('display_name');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> _loadTasks() async {
    final rows = await _db
        .from('work_items')
        .select('id, title, client_id, status, priority, assignee_membership_id, reviewer_membership_id, due_at')
        .eq('firm_id', widget.firmId)
        .isFilter('archived_at', null)
        .order('due_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> _loadMembers() async {
    final rows = await _db.rpc(
      'list_firm_members',
      params: {'p_firm_id': widget.firmId},
    );
    return List<Map<String, dynamic>>.from(rows as List);
  }

  void _refresh() {
    setState(() {
      _clientsFuture = _loadClients();
      _tasksFuture = _loadTasks();
      _membersFuture = _loadMembers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final destinations = [
      NavigationDestination(icon: const Icon(Icons.people_alt_outlined), label: tr('العملاء', 'Clients')),
      NavigationDestination(icon: const Icon(Icons.checklist_outlined), label: tr('المهام', 'Tasks')),
      NavigationDestination(icon: const Icon(Icons.groups_outlined), label: tr('الفريق', 'Team')),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.firmName, style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(tooltip: tr('تحديث', 'Refresh'), onPressed: _refresh, icon: const Icon(Icons.refresh)),
          IconButton(tooltip: tr('تغيير اللغة', 'Change language'), onPressed: widget.onToggleLocale, icon: const Icon(Icons.language)),
          IconButton(tooltip: tr('تسجيل الخروج', 'Sign out'), onPressed: () => Supabase.instance.client.auth.signOut(), icon: const Icon(Icons.logout)),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (value) => setState(() => _selectedIndex = value),
              labelType: NavigationRailLabelType.all,
              destinations: destinations
                  .map((item) => NavigationRailDestination(icon: item.icon, selectedIcon: item.icon, label: Text(item.label)))
                  .toList(),
            ),
          if (wide) const VerticalDivider(width: 1),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                _ClientsPanel(
                  locale: widget.locale,
                  clientsFuture: _clientsFuture,
                  membersFuture: _membersFuture,
                  canManage: _canManage,
                  onRefresh: _refresh,
                  onAdd: _addClient,
                  onAssign: _assignClient,
                ),
                _TasksPanel(
                  locale: widget.locale,
                  tasksFuture: _tasksFuture,
                  clientsFuture: _clientsFuture,
                  membersFuture: _membersFuture,
                  canManage: _canManage,
                  onRefresh: _refresh,
                  onAdd: _addTask,
                  onStatusChanged: _changeTaskStatus,
                ),
                _TeamPanel(locale: widget.locale, membersFuture: _membersFuture),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (value) => setState(() => _selectedIndex = value),
              destinations: destinations,
            ),
    );
  }

  Future<void> _addClient() async {
    final members = await _membersFuture;
    if (!mounted) return;
    final draft = await showDialog<_ClientDraft>(
      context: context,
      builder: (_) => _ClientDialog(locale: widget.locale, members: members, currentMembershipId: widget.membershipId),
    );
    if (draft == null) return;
    try {
      final user = Supabase.instance.client.auth.currentUser!;
      final row = await _db.from('clients').insert({
        'firm_id': widget.firmId,
        'client_type': draft.type,
        'display_name': draft.name,
        'email': _emptyToNull(draft.email),
        'phone': _emptyToNull(draft.phone),
        'notes': _emptyToNull(draft.notes),
        'created_by': user.id,
      }).select('id').single();
      if (draft.taxId.trim().isNotEmpty) {
        await _db.from('client_identifiers').insert({
          'firm_id': widget.firmId,
          'client_id': row['id'],
          'identifier_type': 'tax_registration',
          'identifier_value': draft.taxId.trim(),
          'normalized_value': draft.taxId.trim().replaceAll(RegExp(r'\s+'), ''),
          'label': 'Tax registration number',
        });
      }
      await _db.from('client_assignments').insert({
        'firm_id': widget.firmId,
        'client_id': row['id'],
        'member_id': draft.responsibleMembershipId,
        'assignment_role': 'primary',
        'assigned_by_membership_id': widget.membershipId,
      });
      if (!mounted) return;
      _refresh();
      _showMessage(tr('تم حفظ العميل وتحديد المسؤول.', 'Client saved and responsibility assigned.'));
    } on PostgrestException catch (error) {
      if (mounted) _showMessage(error.message, isError: true);
    } catch (_) {
      if (mounted) _showMessage(tr('تعذر حفظ العميل.', 'Could not save the client.'), isError: true);
    }
  }

  Future<void> _assignClient(String clientId, String memberId) async {
    try {
      final active = await _db
          .from('client_assignments')
          .select('id')
          .eq('firm_id', widget.firmId)
          .eq('client_id', clientId)
          .eq('assignment_role', 'primary')
          .isFilter('ended_at', null);
      for (final assignment in active) {
        await _db.from('client_assignments').update({
          'ended_at': DateTime.now().toUtc().toIso8601String(),
          'ended_by_membership_id': widget.membershipId,
          'end_reason': 'Responsibility reassigned in TaxOS',
        }).eq('id', assignment['id']);
      }
      await _db.from('client_assignments').insert({
        'firm_id': widget.firmId,
        'client_id': clientId,
        'member_id': memberId,
        'assignment_role': 'primary',
        'assigned_by_membership_id': widget.membershipId,
      });
      if (mounted) {
        _refresh();
        _showMessage(tr('تم تحديث المسؤول عن العميل.', 'Client responsibility updated.'));
      }
    } on PostgrestException catch (error) {
      if (mounted) _showMessage(error.message, isError: true);
    }
  }

  Future<void> _addTask() async {
    final clients = await _clientsFuture;
    final members = await _membersFuture;
    if (!mounted || clients.isEmpty || members.isEmpty) {
      if (mounted) _showMessage(tr('أضف عميلًا وعضوًا بالمكتب أولاً.', 'Add a client and an office member first.'), isError: true);
      return;
    }
    final draft = await showDialog<_TaskDraft>(
      context: context,
      builder: (_) => _TaskDialog(locale: widget.locale, clients: clients, members: members, currentMembershipId: widget.membershipId),
    );
    if (draft == null) return;
    try {
      await _db.from('work_items').insert({
        'firm_id': widget.firmId,
        'client_id': draft.clientId,
        'title': draft.title,
        'status': 'todo',
        'priority': draft.priority,
        'assignee_membership_id': draft.assigneeId,
        'reviewer_membership_id': draft.reviewerId,
        'created_by_membership_id': widget.membershipId,
        'updated_by_membership_id': widget.membershipId,
        'due_at': draft.dueAt?.toUtc().toIso8601String(),
      });
      if (mounted) {
        _refresh();
        _showMessage(tr('تمت إضافة المهمة.', 'Task created.'));
      }
    } on PostgrestException catch (error) {
      if (mounted) _showMessage(error.message, isError: true);
    }
  }

  Future<void> _changeTaskStatus(String taskId, String status) async {
    try {
      await _db.from('work_items').update({
        'status': status,
        'updated_by_membership_id': widget.membershipId,
      }).eq('firm_id', widget.firmId).eq('id', taskId);
      _refresh();
    } on PostgrestException catch (error) {
      if (mounted) _showMessage(error.message, isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  String? _emptyToNull(String value) => value.trim().isEmpty ? null : value.trim();
}

class _ClientsPanel extends StatelessWidget {
  const _ClientsPanel({
    required this.locale,
    required this.clientsFuture,
    required this.membersFuture,
    required this.canManage,
    required this.onRefresh,
    required this.onAdd,
    required this.onAssign,
  });

  final String locale;
  final Future<List<Map<String, dynamic>>> clientsFuture;
  final Future<List<Map<String, dynamic>>> membersFuture;
  final bool canManage;
  final VoidCallback onRefresh;
  final VoidCallback onAdd;
  final Future<void> Function(String clientId, String memberId) onAssign;

  bool get ar => locale == 'ar';
  String tr(String a, String e) => ar ? a : e;

  @override
  Widget build(BuildContext context) => _PanelFrame(
    title: tr('سجل العملاء', 'Client registry'),
    subtitle: tr('قائمة موحدة لعملاء المكتب والمسؤول عن كل عميل.', 'One office-wide list of clients and their responsible accountant.'),
    action: canManage ? FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: Text(tr('إضافة عميل', 'Add client'))) : null,
    child: FutureBuilder<List<Map<String, dynamic>>>(
      future: clientsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return _ErrorText(error: snapshot.error.toString());
        final clients = snapshot.data ?? [];
        if (clients.isEmpty) return _EmptyState(text: tr('لا يوجد عملاء حتى الآن. أضف أول عميل للمكتب.', 'No clients yet. Add the office first client.'));
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: membersFuture,
          builder: (context, memberSnapshot) {
            if (memberSnapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (memberSnapshot.hasError) return _ErrorText(error: memberSnapshot.error.toString());
            final members = memberSnapshot.data ?? [];
            final memberNames = {for (final m in members) m['membership_id'] as String: m['display_name'] as String};
            return Card(
              child: Column(
                children: [
                  for (var i = 0; i < clients.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    ListTile(
                      leading: CircleAvatar(child: Icon(clients[i]['client_type'] == 'company' ? Icons.business_outlined : Icons.person_outline)),
                      title: Text(clients[i]['display_name'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text([
                        if ((clients[i]['phone'] as String?)?.isNotEmpty == true) clients[i]['phone'] as String,
                        if ((clients[i]['email'] as String?)?.isNotEmpty == true) clients[i]['email'] as String,
                      ].join(' • ')),
                      trailing: PopupMenuButton<String>(
                        enabled: canManage && members.isNotEmpty,
                        tooltip: tr('تغيير المسؤول', 'Change responsible accountant'),
                        onSelected: (memberId) => onAssign(clients[i]['id'] as String, memberId),
                        itemBuilder: (_) => members.map((m) => PopupMenuItem<String>(
                          value: m['membership_id'] as String,
                          child: Text(m['display_name'] as String),
                        )).toList(),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 180),
                          child: Text(
                            tr('المسؤول: ', 'Owner: ') + (memberNames[clients[i]['responsible_membership_id']] ?? tr('غير محدد', 'Unassigned')),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    ),
  );
}

class _TasksPanel extends StatelessWidget {
  const _TasksPanel({
    required this.locale,
    required this.tasksFuture,
    required this.clientsFuture,
    required this.membersFuture,
    required this.canManage,
    required this.onRefresh,
    required this.onAdd,
    required this.onStatusChanged,
  });

  final String locale;
  final Future<List<Map<String, dynamic>>> tasksFuture;
  final Future<List<Map<String, dynamic>>> clientsFuture;
  final Future<List<Map<String, dynamic>>> membersFuture;
  final bool canManage;
  final VoidCallback onRefresh;
  final VoidCallback onAdd;
  final Future<void> Function(String id, String status) onStatusChanged;

  bool get ar => locale == 'ar';
  String tr(String a, String e) => ar ? a : e;

  @override
  Widget build(BuildContext context) => _PanelFrame(
    title: tr('مهام المكتب', 'Office tasks'),
    subtitle: tr('تابع مهام كل عميل، المسؤول عن التنفيذ، والمراجع وموعد الانتهاء.', 'Track each client task, assignee, reviewer, and due date.'),
    action: canManage ? FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: Text(tr('إضافة مهمة', 'Add task'))) : null,
    child: FutureBuilder<List<Map<String, dynamic>>>(
      future: Future.wait([tasksFuture, clientsFuture, membersFuture]).then((values) => values[0]),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return _ErrorText(error: snapshot.error.toString());
        final tasks = snapshot.data ?? [];
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: clientsFuture,
          builder: (context, clientSnapshot) {
            if (clientSnapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            final clients = {for (final c in clientSnapshot.data ?? []) c['id'] as String: c['display_name'] as String};
            return FutureBuilder<List<Map<String, dynamic>>>(
              future: membersFuture,
              builder: (context, memberSnapshot) {
                if (memberSnapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
                final members = {for (final m in memberSnapshot.data ?? []) m['membership_id'] as String: m['display_name'] as String};
                if (tasks.isEmpty) return _EmptyState(text: tr('لا توجد مهام مسجلة.', 'No tasks have been recorded.'));
                return Card(
                  child: Column(
                    children: [
                      for (var i = 0; i < tasks.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        ListTile(
                          title: Text(tasks[i]['title'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text([
                              clients[tasks[i]['client_id']] ?? '',
                              tr('المسؤول: ', 'Assignee: ') + (members[tasks[i]['assignee_membership_id']] ?? ''),
                              if (tasks[i]['reviewer_membership_id'] != null) tr('المراجع: ', 'Reviewer: ') + (members[tasks[i]['reviewer_membership_id']] ?? ''),
                              if (tasks[i]['due_at'] != null) tr('الاستحقاق: ', 'Due: ') + (tasks[i]['due_at'] as String).substring(0, 10),
                            ].where((s) => s.isNotEmpty).join(' • ')),
                          ),
                          trailing: PopupMenuButton<String>(
                            tooltip: tr('تغيير الحالة', 'Change status'),
                            onSelected: (status) => onStatusChanged(tasks[i]['id'] as String, status),
                            itemBuilder: (_) => [
                              PopupMenuItem(value: 'todo', child: Text(tr('لم تبدأ', 'To do'))),
                              PopupMenuItem(value: 'in_progress', child: Text(tr('جاري التنفيذ', 'In progress'))),
                              PopupMenuItem(value: 'blocked', child: Text(tr('متوقفة', 'Blocked'))),
                              PopupMenuItem(value: 'completed', child: Text(tr('مكتملة', 'Completed'))),
                            ],
                            child: Chip(label: Text(_statusLabel(tasks[i]['status'] as String))),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    ),
  );

  String _statusLabel(String status) => switch (status) {
    'in_progress' => tr('جاري التنفيذ', 'In progress'),
    'blocked' => tr('متوقفة', 'Blocked'),
    'completed' => tr('مكتملة', 'Completed'),
    'cancelled' => tr('ملغاة', 'Cancelled'),
    _ => tr('لم تبدأ', 'To do'),
  };
}

class _TeamPanel extends StatelessWidget {
  const _TeamPanel({required this.locale, required this.membersFuture});
  final String locale;
  final Future<List<Map<String, dynamic>>> membersFuture;

  @override
  Widget build(BuildContext context) => _PanelFrame(
    title: locale == 'ar' ? 'فريق المكتب' : 'Office team',
    subtitle: locale == 'ar' ? 'الأعضاء النشطون الذين يمكن إسناد العملاء والمهام إليهم.' : 'Active members who can be assigned to clients and tasks.',
    child: FutureBuilder<List<Map<String, dynamic>>>(
      future: membersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return _ErrorText(error: snapshot.error.toString());
        final members = snapshot.data ?? [];
        if (members.isEmpty) return _EmptyState(text: locale == 'ar' ? 'لا يوجد أعضاء نشطون.' : 'No active members.');
        return Card(
          child: Column(
            children: [
              for (var i = 0; i < members.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                ListTile(
                  leading: CircleAvatar(child: Text((members[i]['display_name'] as String).characters.first.toUpperCase())),
                  title: Text(members[i]['display_name'] as String),
                  subtitle: Text(members[i]['email'] as String? ?? ''),
                  trailing: Chip(label: Text(_roleLabel(members[i]['role'] as String, locale))),
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
}

class _ClientDraft {
  const _ClientDraft(this.name, this.type, this.taxId, this.phone, this.email, this.notes, this.responsibleMembershipId);
  final String name;
  final String type;
  final String taxId;
  final String phone;
  final String email;
  final String notes;
  final String responsibleMembershipId;
}

class _ClientDialog extends StatefulWidget {
  const _ClientDialog({required this.locale, required this.members, required this.currentMembershipId});
  final String locale;
  final List<Map<String, dynamic>> members;
  final String currentMembershipId;
  @override
  State<_ClientDialog> createState() => _ClientDialogState();
}

class _ClientDialogState extends State<_ClientDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _tax = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _notes = TextEditingController();
  String _type = 'company';
  late String _responsible = widget.currentMembershipId;
  bool get ar => widget.locale == 'ar';
  String tr(String a, String e) => ar ? a : e;

  @override
  void dispose() {
    _name.dispose(); _tax.dispose(); _phone.dispose(); _email.dispose(); _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(tr('إضافة عميل جديد', 'Add client')),
    content: SizedBox(
      width: 440,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: _name, decoration: InputDecoration(labelText: tr('اسم العميل', 'Client name')), validator: (v) => (v == null || v.trim().isEmpty) ? tr('هذا الحقل مطلوب', 'Required') : null),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _type,
                decoration: InputDecoration(labelText: tr('نوع العميل', 'Client type')),
                items: [DropdownMenuItem(value: 'company', child: Text(tr('شركة / منشأة', 'Company / entity'))), DropdownMenuItem(value: 'individual', child: Text(tr('فرد', 'Individual')))],
                onChanged: (v) => setState(() => _type = v ?? 'company'),
              ),
              const SizedBox(height: 10),
              TextFormField(controller: _tax, decoration: InputDecoration(labelText: tr('رقم التسجيل الضريبي (اختياري)', 'Tax registration number (optional)'))),
              const SizedBox(height: 10),
              TextFormField(controller: _phone, decoration: InputDecoration(labelText: tr('الهاتف', 'Phone'))),
              const SizedBox(height: 10),
              TextFormField(controller: _email, decoration: InputDecoration(labelText: tr('البريد الإلكتروني', 'Email'))),
              const SizedBox(height: 10),
              TextFormField(controller: _notes, maxLines: 2, decoration: InputDecoration(labelText: tr('ملاحظات', 'Notes'))),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _responsible,
                decoration: InputDecoration(labelText: tr('المحاسب المسؤول', 'Responsible accountant')),
                items: widget.members.map((m) => DropdownMenuItem(value: m['membership_id'] as String, child: Text(m['display_name'] as String))).toList(),
                onChanged: (v) => setState(() => _responsible = v ?? widget.currentMembershipId),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('إلغاء', 'Cancel'))),
      FilledButton(onPressed: () {
        if (_form.currentState!.validate()) {
          Navigator.pop(context, _ClientDraft(_name.text.trim(), _type, _tax.text, _phone.text, _email.text, _notes.text, _responsible));
        }
      }, child: Text(tr('حفظ', 'Save'))),
    ],
  );
}

class _TaskDraft {
  const _TaskDraft(this.title, this.clientId, this.assigneeId, this.reviewerId, this.dueAt, this.priority);
  final String title;
  final String clientId;
  final String assigneeId;
  final String? reviewerId;
  final DateTime? dueAt;
  final String priority;
}

class _TaskDialog extends StatefulWidget {
  const _TaskDialog({required this.locale, required this.clients, required this.members, required this.currentMembershipId});
  final String locale;
  final List<Map<String, dynamic>> clients;
  final List<Map<String, dynamic>> members;
  final String currentMembershipId;
  @override
  State<_TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<_TaskDialog> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  late String _clientId = widget.clients.first['id'] as String;
  late String _assignee = widget.currentMembershipId;
  String? _reviewer;
  DateTime? _dueAt;
  String _priority = 'normal';
  bool get ar => widget.locale == 'ar';
  String tr(String a, String e) => ar ? a : e;

  @override
  void dispose() { _title.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(tr('إضافة مهمة', 'Add task')),
    content: SizedBox(
      width: 440,
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(controller: _title, decoration: InputDecoration(labelText: tr('عنوان المهمة', 'Task title')), validator: (v) => (v == null || v.trim().isEmpty) ? tr('هذا الحقل مطلوب', 'Required') : null),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _clientId,
              decoration: InputDecoration(labelText: tr('العميل', 'Client')),
              items: widget.clients.map((c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['display_name'] as String))).toList(),
              onChanged: (v) => setState(() => _clientId = v ?? _clientId),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _assignee,
              decoration: InputDecoration(labelText: tr('المسؤول عن التنفيذ', 'Assignee')),
              items: widget.members.map((m) => DropdownMenuItem(value: m['membership_id'] as String, child: Text(m['display_name'] as String))).toList(),
              onChanged: (v) => setState(() => _assignee = v ?? _assignee),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String?>(
              value: _reviewer,
              decoration: InputDecoration(labelText: tr('المراجع (اختياري)', 'Reviewer (optional)')),
              items: [
                DropdownMenuItem<String?>(value: null, child: Text(tr('بدون مراجع', 'No reviewer'))),
                ...widget.members.where((m) => m['membership_id'] != _assignee).map((m) => DropdownMenuItem<String?>(value: m['membership_id'] as String, child: Text(m['display_name'] as String))),
              ],
              onChanged: (v) => setState(() => _reviewer = v),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _priority,
              decoration: InputDecoration(labelText: tr('الأولوية', 'Priority')),
              items: [
                DropdownMenuItem(value: 'low', child: Text(tr('منخفضة', 'Low'))),
                DropdownMenuItem(value: 'normal', child: Text(tr('عادية', 'Normal'))),
                DropdownMenuItem(value: 'high', child: Text(tr('عالية', 'High'))),
                DropdownMenuItem(value: 'urgent', child: Text(tr('عاجلة', 'Urgent'))),
              ],
              onChanged: (v) => setState(() => _priority = v ?? 'normal'),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
                  if (picked != null) setState(() => _dueAt = picked);
                },
                icon: const Icon(Icons.event_outlined),
                label: Text(_dueAt == null ? tr('تحديد موعد الاستحقاق', 'Set due date') : _dueAt!.toIso8601String().substring(0, 10)),
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('إلغاء', 'Cancel'))),
      FilledButton(onPressed: () {
        if (_form.currentState!.validate()) {
          Navigator.pop(context, _TaskDraft(_title.text.trim(), _clientId, _assignee, _reviewer, _dueAt, _priority));
        }
      }, child: Text(tr('حفظ', 'Save'))),
    ],
  );
}

class _PanelFrame extends StatelessWidget {
  const _PanelFrame({required this.title, required this.subtitle, required this.child, this.action});
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54)),
              ])),
              if (action != null) action!,
            ]),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(28), child: Center(child: Text(text, textAlign: TextAlign.center))));
}

class _ErrorText extends StatelessWidget {
  const _ErrorText({required this.error});
  final String error;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(18), child: SelectableText(error, style: TextStyle(color: Theme.of(context).colorScheme.error))));
}

String _roleLabel(String role, String locale) {
  final ar = locale == 'ar';
  return switch (role) {
    'owner' => ar ? 'مالك المكتب' : 'Owner',
    'admin' => ar ? 'مدير النظام' : 'Admin',
    'manager' => ar ? 'مدير فريق' : 'Manager',
    'accountant' => ar ? 'محاسب' : 'Accountant',
    'reviewer' => ar ? 'مراجع' : 'Reviewer',
    'staff' => ar ? 'موظف' : 'Staff',
    'read_only' => ar ? 'عرض فقط' : 'Read only',
    _ => role,
  };
}
