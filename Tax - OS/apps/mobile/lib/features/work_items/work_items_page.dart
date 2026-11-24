import 'package:material_ui/material_ui.dart';

import '../../app/app_copy.dart';
import '../../shared/demo_office_members.dart';
import '../clients/data/client_repository.dart';
import '../clients/domain/client.dart';
import '../clients/domain/client_repository.dart';
import 'data/work_item_repository.dart';
import 'domain/work_item.dart';

class WorkItemsPage extends StatefulWidget {
  const WorkItemsPage({
    required this.locale,
    this.repository,
    this.clientRepository,
    super.key,
  });

  final String locale;
  final WorkItemRepository? repository;
  final ClientRepository? clientRepository;

  @override
  State<WorkItemsPage> createState() => _WorkItemsPageState();
}

class _WorkItemsPageState extends State<WorkItemsPage> {
  late final WorkItemRepository _repository;
  late final ClientRepository _clientRepository;
  String _filter = 'all';
  int _nextId = 4;

  String tr(String key) => AppCopy.t(widget.locale, key);

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? InMemoryWorkItemRepository();
    _clientRepository = widget.clientRepository ?? InMemoryClientRepository();
  }

  @override
  Widget build(BuildContext context) {
    final allItems = _repository.getAll();
    final clients = _clientRepository.getAll();
    final visibleItems =
        allItems.where((item) {
          return _filter == 'all' ||
              (_filter == 'open' &&
                  item.status != WorkItemStatus.completed &&
                  item.status != WorkItemStatus.cancelled) ||
              (_filter == 'completed' &&
                  item.status == WorkItemStatus.completed);
        }).toList()..sort((a, b) {
          if (a.dueDate == null && b.dueDate == null) {
            return a.title.compareTo(b.title);
          }
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
        });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
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
                          tr('tasksPageTitle'),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          tr('tasksPageSubtitle'),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    key: const ValueKey('add_work_item'),
                    onPressed: _openForm,
                    icon: const Icon(Icons.add),
                    label: Text(tr('addTask')),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5DF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF0E0B8)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Color(0xFF8B651B),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        tr('taskDemoNotice'),
                        style: const TextStyle(
                          color: Color(0xFF725318),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  for (final filter in ['all', 'open', 'completed'])
                    ChoiceChip(
                      key: ValueKey('task_filter_$filter'),
                      label: Text(
                        tr(filter == 'all' ? 'all' : 'taskFilter_$filter'),
                      ),
                      selected: _filter == filter,
                      onSelected: (_) => setState(() => _filter = filter),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    '${visibleItems.length} ${tr('tasksCount')}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text(
                    tr('localDemoStorage'),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Card(
                child: visibleItems.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(28),
                        child: Center(child: Text(tr('noTasksFound'))),
                      )
                    : Column(
                        children: [
                          for (
                            var index = 0;
                            index < visibleItems.length;
                            index++
                          )
                            Column(
                              children: [
                                if (index > 0) const Divider(height: 1),
                                _WorkItemTile(
                                  item: visibleItems[index],
                                  clients: clients,
                                  locale: widget.locale,
                                  onStatusChanged: (status) {
                                    setState(() {
                                      _repository.save(
                                        visibleItems[index].copyWith(
                                          status: status,
                                        ),
                                      );
                                    });
                                  },
                                ),
                              ],
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openForm() async {
    final result = await showDialog<WorkItem>(
      context: context,
      builder: (context) => _WorkItemFormDialog(
        locale: widget.locale,
        id: 'task-local-$_nextId',
        clients: _clientRepository
            .getAll()
            .where((client) => !client.isArchived)
            .toList(),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _repository.save(result);
      _nextId++;
    });
  }
}

class _WorkItemTile extends StatelessWidget {
  const _WorkItemTile({
    required this.item,
    required this.clients,
    required this.locale,
    required this.onStatusChanged,
  });

  final WorkItem item;
  final List<Client> clients;
  final String locale;
  final ValueChanged<WorkItemStatus> onStatusChanged;

  String tr(String key) => AppCopy.t(locale, key);

  @override
  Widget build(BuildContext context) {
    final clientNames = {for (final client in clients) client.id: client.name};
    return ListTile(
      key: ValueKey('work_item_${item.id}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFE8F2F0),
        child: const Icon(Icons.assignment_outlined, color: Color(0xFF176B67)),
      ),
      title: Text(
        item.title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 7),
        child: Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            _MetaLabel(
              icon: Icons.business_outlined,
              label: clientNames[item.clientId] ?? item.clientId,
            ),
            _MetaLabel(
              icon: Icons.person_outline,
              label:
                  '${tr('assignee')}: ${demoOfficeMemberName(item.assigneeId, locale)}',
            ),
            if (item.reviewerId != null)
              _MetaLabel(
                icon: Icons.fact_check_outlined,
                label:
                    '${tr('reviewer')}: ${demoOfficeMemberName(item.reviewerId!, locale)}',
              ),
            if (item.dueDate != null)
              _MetaLabel(
                icon: Icons.event_outlined,
                label:
                    '${tr('dueDate')}: ${_formatDate(item.dueDate!, locale)}',
              ),
          ],
        ),
      ),
      trailing: PopupMenuButton<WorkItemStatus>(
        key: ValueKey('task_status_${item.id}'),
        tooltip: tr('changeTaskStatus'),
        onSelected: onStatusChanged,
        itemBuilder: (context) => [
          for (final status in WorkItemStatus.values)
            PopupMenuItem(value: status, child: Text(_statusLabel(status, tr))),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F3F2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _statusLabel(item.status, tr),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _MetaLabel extends StatelessWidget {
  const _MetaLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: Colors.black54),
      const SizedBox(width: 4),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _WorkItemFormDialog extends StatefulWidget {
  const _WorkItemFormDialog({
    required this.locale,
    required this.id,
    required this.clients,
  });

  final String locale;
  final String id;
  final List<Client> clients;

  @override
  State<_WorkItemFormDialog> createState() => _WorkItemFormDialogState();
}

class _WorkItemFormDialogState extends State<_WorkItemFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  late String _clientId;
  String _assigneeId = 'member-1';
  String? _reviewerId;
  DateTime? _dueDate;

  String tr(String key) => AppCopy.t(widget.locale, key);

  @override
  void initState() {
    super.initState();
    _clientId = widget.clients.isEmpty ? '' : widget.clients.first.id;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('addTask')),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const ValueKey('task_title'),
                  controller: _title,
                  decoration: InputDecoration(labelText: tr('taskTitle')),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? tr('requiredField')
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const ValueKey('task_client'),
                  initialValue: _clientId.isEmpty ? null : _clientId,
                  decoration: InputDecoration(labelText: tr('client')),
                  items: [
                    for (final client in widget.clients)
                      DropdownMenuItem(
                        value: client.id,
                        child: Text(client.name),
                      ),
                  ],
                  validator: (value) => value == null || value.isEmpty
                      ? tr('requiredField')
                      : null,
                  onChanged: (value) {
                    if (value != null) setState(() => _clientId = value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _assigneeId,
                  decoration: InputDecoration(labelText: tr('assignee')),
                  items: [
                    for (final member in demoOfficeMembers)
                      DropdownMenuItem(
                        value: member.id,
                        child: Text(member.nameFor(widget.locale)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _assigneeId = value;
                        if (_reviewerId == value) _reviewerId = null;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  key: const ValueKey('task_reviewer'),
                  initialValue: _reviewerId,
                  decoration: InputDecoration(
                    labelText: tr('reviewerOptional'),
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(tr('noReviewer')),
                    ),
                    for (final member in demoOfficeMembers.where(
                      (m) => m.id != _assigneeId,
                    ))
                      DropdownMenuItem<String?>(
                        value: member.id,
                        child: Text(member.nameFor(widget.locale)),
                      ),
                  ],
                  onChanged: (value) => setState(() => _reviewerId = value),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OutlinedButton.icon(
                    key: const ValueKey('task_due_date'),
                    onPressed: _chooseDueDate,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      _dueDate == null
                          ? tr('setDueDate')
                          : '${tr('dueDate')}: ${_formatDate(_dueDate!, widget.locale)}',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('cancel')),
        ),
        FilledButton(
          key: const ValueKey('save_work_item'),
          onPressed: _save,
          child: Text(tr('save')),
        ),
      ],
    );
  }

  Future<void> _chooseDueDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (selected != null) setState(() => _dueDate = selected);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      WorkItem(
        id: widget.id,
        title: _title.text.trim(),
        clientId: _clientId,
        assigneeId: _assigneeId,
        reviewerId: _reviewerId,
        dueDate: _dueDate,
      ),
    );
  }
}

String _statusLabel(WorkItemStatus status, String Function(String) tr) {
  return switch (status) {
    WorkItemStatus.todo => tr('taskTodo'),
    WorkItemStatus.inProgress => tr('taskInProgress'),
    WorkItemStatus.blocked => tr('taskBlocked'),
    WorkItemStatus.completed => tr('taskCompleted'),
    WorkItemStatus.cancelled => tr('taskCancelled'),
  };
}

String _formatDate(DateTime date, String locale) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return locale == 'ar'
      ? '$day/$month/${date.year}'
      : '$month/$day/${date.year}';
}
