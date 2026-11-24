import 'package:material_ui/material_ui.dart';

import '../../app/app_copy.dart';
import 'data/client_repository.dart';
import 'domain/client.dart';
import 'domain/client_repository.dart';
import '../../shared/demo_office_members.dart';

class ClientsPage extends StatefulWidget {
  const ClientsPage({required this.locale, this.repository, super.key});

  final String locale;
  final ClientRepository? repository;

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  late final ClientRepository _repository;

  String _query = '';
  String _filter = 'all';
  int _nextId = 5;

  String tr(String key) => AppCopy.t(widget.locale, key);

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? InMemoryClientRepository();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final filtered = _repository.getAll().where((client) {
      final matchesFilter = _filter == 'all' ||
          (_filter == 'companies' && client.type == ClientType.company) ||
          (_filter == 'individuals' && client.type == ClientType.individual);
      final searchable = [
        client.name,
        client.taxId,
        client.vatNumber,
        client.contactName,
        client.phone,
      ].join(' ').toLowerCase();
      return matchesFilter && (query.isEmpty || searchable.contains(query));
    }).toList();

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
                          tr('clients'),
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          tr('clientsSubtitle'),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.black54,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    key: const ValueKey('add_client'),
                    onPressed: () => _openClientForm(),
                    icon: const Icon(Icons.add),
                    label: Text(tr('addClient')),
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
                    const Icon(Icons.info_outline, size: 18, color: Color(0xFF8B651B)),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        tr('demoNotice'),
                        style: const TextStyle(color: Color(0xFF725318), fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('client_search'),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: tr('searchClients'),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE6ECEB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE6ECEB)),
                  ),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final filter in ['all', 'companies', 'individuals'])
                    ChoiceChip(
                      key: ValueKey('client_filter_$filter'),
                      label: Text(tr(filter)),
                      selected: _filter == filter,
                      onSelected: (_) => setState(() => _filter = filter),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    '${filtered.length} ${tr('activeClients')}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text(
                    tr('localDemoStorage'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.black54,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Card(
                child: filtered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(28),
                        child: Center(child: Text(tr('noClientsFound'))),
                      )
                    : Column(
                        children: [
                          for (var index = 0; index < filtered.length; index++)
                            Column(
                              children: [
                                if (index > 0) const Divider(height: 1),
                                ListTile(
                                  key: ValueKey('client_${filtered[index].id}'),
                                  onTap: () => _showClientDetails(filtered[index]),
                                  leading: CircleAvatar(
                                    backgroundColor: const Color(0xFFE8F2F0),
                                    child: Icon(
                                      filtered[index].type == ClientType.company
                                          ? Icons.business_outlined
                                          : Icons.person_outline,
                                      color: const Color(0xFF176B67),
                                    ),
                                  ),
                                  title: Text(
                                    filtered[index].name,
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  subtitle: Text(
                                    [
                                      tr(filtered[index].type == ClientType.company
                                          ? 'companies'
                                          : 'individuals'),
                                      if (filtered[index].taxId.isNotEmpty)
                                        '${tr('taxId')}: ${filtered[index].taxId}',
                                      if (filtered[index].phone.isNotEmpty)
                                        filtered[index].phone,
                                    ].join(' • '),
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    tooltip: tr('clientActions'),
                                    onSelected: (action) {
                                      if (action == 'edit') {
                                        _openClientForm(client: filtered[index]);
                                      } else if (action == 'delete') {
                                        _confirmDelete(filtered[index]);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem(value: 'edit', child: Text(tr('edit'))),
                                      PopupMenuItem(value: 'delete', child: Text(tr('delete'))),
                                    ],
                                  ),
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

  Future<void> _openClientForm({Client? client}) async {
    final result = await showDialog<Client>(
      context: context,
      builder: (context) => _ClientFormDialog(
        locale: widget.locale,
        client: client,
        id: 'local-$_nextId',
      ),
    );
    if (result == null || !mounted) return;

    setState(() {
      _repository.save(result);
      if (client == null) _nextId++;
    });
  }

  Future<void> _confirmDelete(Client client) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('deleteClient')),
        content: Text(
          widget.locale == 'ar'
              ? 'هل تريد حذف العميل «${client.name}» من البيانات التجريبية؟'
              : 'Delete "${client.name}" from the demo records?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('delete')),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() => _repository.delete(client.id));
    }
  }

  void _showClientDetails(Client client) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                client.name,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(tr(client.type == ClientType.company ? 'companies' : 'individuals')),
              const Divider(height: 24),
              _DetailRow(label: tr('taxId'), value: client.taxId),
              _DetailRow(label: tr('vatNumber'), value: client.vatNumber),
              _DetailRow(label: tr('contactPerson'), value: client.contactName),
              _DetailRow(label: tr('phone'), value: client.phone),
              _DetailRow(label: tr('email'), value: client.email),
              _DetailRow(label: tr('address'), value: client.address),
              _DetailRow(label: tr('notes'), value: client.notes),
              _DetailRow(
                label: tr('responsibleEmployee'),
                value: client.responsibleEmployeeId.isEmpty
                    ? tr('unassigned')
                    : demoOfficeMemberName(client.responsibleEmployeeId, widget.locale),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _openClientForm(client: client);
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(tr('editClient')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _ClientFormDialog extends StatefulWidget {
  const _ClientFormDialog({
    required this.locale,
    required this.id,
    this.client,
  });

  final String locale;
  final String id;
  final Client? client;

  @override
  State<_ClientFormDialog> createState() => _ClientFormDialogState();
}

class _ClientFormDialogState extends State<_ClientFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _taxId;
  late final TextEditingController _vatNumber;
  late final TextEditingController _contactName;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late final TextEditingController _notes;
  late ClientType _kind;
  late String _responsibleEmployeeId;

  String tr(String key) => AppCopy.t(widget.locale, key);

  @override
  void initState() {
    super.initState();
    final client = widget.client;
    _name = TextEditingController(text: client?.name ?? '');
    _taxId = TextEditingController(text: client?.taxId ?? '');
    _vatNumber = TextEditingController(text: client?.vatNumber ?? '');
    _contactName = TextEditingController(text: client?.contactName ?? '');
    _phone = TextEditingController(text: client?.phone ?? '');
    _email = TextEditingController(text: client?.email ?? '');
    _address = TextEditingController(text: client?.address ?? '');
    _notes = TextEditingController(text: client?.notes ?? '');
    _kind = client?.type ?? ClientType.company;
    _responsibleEmployeeId = client?.responsibleEmployeeId ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _taxId.dispose();
    _vatNumber.dispose();
    _contactName.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr(widget.client == null ? 'addClient' : 'editClient')),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<ClientType>(
                  initialValue: _kind,
                  decoration: InputDecoration(labelText: tr('clientType')),
                  items: [
                    DropdownMenuItem(value: ClientType.company, child: Text(tr('companies'))),
                    DropdownMenuItem(value: ClientType.individual, child: Text(tr('individuals'))),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _kind = value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _responsibleEmployeeId,
                  decoration: InputDecoration(labelText: tr('responsibleEmployee')),
                  items: [
                    DropdownMenuItem(value: '', child: Text(tr('unassigned'))),
                    for (final member in demoOfficeMembers)
                      DropdownMenuItem(
                        value: member.id,
                        child: Text(member.nameFor(widget.locale)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _responsibleEmployeeId = value);
                  },
                ),
                const SizedBox(height: 12),
                _field(controller: _name, label: tr('clientName'), required: true),
                _field(controller: _taxId, label: tr('taxId')),
                _field(controller: _vatNumber, label: tr('vatNumber')),
                _field(controller: _contactName, label: tr('contactPerson')),
                _field(controller: _phone, label: tr('phone'), keyboardType: TextInputType.phone),
                _field(controller: _email, label: tr('email'), keyboardType: TextInputType.emailAddress),
                _field(controller: _address, label: tr('address')),
                _field(controller: _notes, label: tr('notes'), maxLines: 2),
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
          key: const ValueKey('save_client'),
          onPressed: _save,
          child: Text(tr('save')),
        ),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    bool required = false,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
        validator: required
            ? (value) => value == null || value.trim().isEmpty ? tr('requiredField') : null
            : null,
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final previous = widget.client;
    Navigator.pop(
      context,
      Client(
        id: previous?.id ?? widget.id,
        name: _name.text.trim(),
        type: _kind,
        taxId: _taxId.text.trim(),
        vatNumber: _vatNumber.text.trim(),
        contactName: _contactName.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        address: _address.text.trim(),
        notes: _notes.text.trim(),
        responsibleEmployeeId: _responsibleEmployeeId,
      ),
    );
  }
}
