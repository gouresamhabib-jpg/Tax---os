import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_environment.dart';

class TaxObligationsPanel extends StatefulWidget {
  const TaxObligationsPanel({
    required this.locale,
    required this.firmId,
    required this.membershipId,
    required this.canManage,
    super.key,
  });

  final String locale;
  final String firmId;
  final String membershipId;
  final bool canManage;

  @override
  State<TaxObligationsPanel> createState() => _TaxObligationsPanelState();
}

class _TaxObligationsPanelState extends State<TaxObligationsPanel> {
  late final _db = Supabase.instance.client.schema(AppEnvironment.supabaseSchema);
  late Future<_ObligationData> _dataFuture;

  bool get ar => widget.locale == 'ar';
  String tr(String a, String e) => ar ? a : e;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<_ObligationData> _loadData() async {
    final clients = await _db
        .from('clients')
        .select('id, display_name')
        .eq('firm_id', widget.firmId)
        .isFilter('archived_at', null)
        .order('display_name');
    final catalogue = await _db
        .from('tax_obligation_catalog')
        .select('id, code, name_ar, name_en, frequency, category, description_ar, description_en')
        .eq('is_active', true)
        .order('frequency')
        .order('name_ar');
    final assignments = await _db
        .from('client_tax_obligations')
        .select('id, client_id, obligation_id, effective_from, effective_to, is_active, notes')
        .eq('firm_id', widget.firmId)
        .eq('is_active', true);
    return _ObligationData(
      clients: List<Map<String, dynamic>>.from(clients),
      catalogue: List<Map<String, dynamic>>.from(catalogue),
      assignments: List<Map<String, dynamic>>.from(assignments),
    );
  }

  void _load() {
    _dataFuture = _loadData();
  }

  Future<void> _refresh() async {
    setState(_load);
    await _dataFuture;
  }

  Future<void> _addAssignment(_ObligationData data) async {
    if (data.clients.isEmpty || data.catalogue.isEmpty) {
      _message(tr('أضف عميلًا أولًا أو راجع مكتبة الالتزامات.', 'Add a client first or review the obligation catalogue.'), error: true);
      return;
    }
    final draft = await showDialog<_AssignmentDraft>(
      context: context,
      builder: (_) => _AssignmentDialog(locale: widget.locale, data: data),
    );
    if (draft == null) return;
    try {
      for (final obligationId in draft.obligationIds) {
        final existing = await _db
            .from('client_tax_obligations')
            .select('id')
            .eq('firm_id', widget.firmId)
            .eq('client_id', draft.clientId)
            .eq('obligation_id', obligationId)
            .maybeSingle();
        if (existing == null) {
          await _db.from('client_tax_obligations').insert({
            'firm_id': widget.firmId,
            'client_id': draft.clientId,
            'obligation_id': obligationId,
            'effective_from': draft.effectiveFrom.toIso8601String().substring(0, 10),
            'created_by_membership_id': widget.membershipId,
            'notes': draft.notes.trim().isEmpty ? null : draft.notes.trim(),
          });
        } else {
          await _db.from('client_tax_obligations').update({
            'is_active': true,
            'effective_from': draft.effectiveFrom.toIso8601String().substring(0, 10),
            'effective_to': null,
            'notes': draft.notes.trim().isEmpty ? null : draft.notes.trim(),
          }).eq('id', existing['id']);
        }
      }
      if (!mounted) return;
      await _refresh();
      _message(tr('تم ربط الالتزامات المختارة بالعميل.', 'Selected obligations assigned to client.'));
    } on PostgrestException catch (e) {
      _message(e.message, error: true);
    }
  }

  Future<void> _deactivate(String id) async {
    try {
      await _db.from('client_tax_obligations').update({
        'is_active': false,
        'effective_to': DateTime.now().toIso8601String().substring(0, 10),
      }).eq('firm_id', widget.firmId).eq('id', id);
      await _refresh();
    } on PostgrestException catch (e) {
      _message(e.message, error: true);
    }
  }

  void _message(String value, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(value),
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
    ));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_ObligationData>(
    future: _dataFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return _frame(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('تعذر تحميل مكتبة الالتزامات.', 'Could not load the obligation catalogue.')),
                  const SizedBox(height: 8),
                  SelectableText(snapshot.error.toString()),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: Text(tr('إعادة المحاولة', 'Retry'))),
                ],
              ),
            ),
          ),
        );
      }
      final data = snapshot.data!;
      final clients = {for (final c in data.clients) c['id'] as String: c['display_name'] as String};
      final catalogue = {for (final o in data.catalogue) o['id'] as String: o};
      final rows = data.assignments.where((a) => clients.containsKey(a['client_id']) && catalogue.containsKey(a['obligation_id'])).toList();
      return _frame(
        action: widget.canManage
            ? FilledButton.icon(onPressed: () => _addAssignment(data), icon: const Icon(Icons.add), label: Text(tr('اختيار التزامات لعميل', 'Assign to client')))
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _countChip(tr('العملاء', 'Clients'), data.clients.length),
                _countChip(tr('الالتزامات بالمكتبة', 'Catalogue items'), data.catalogue.length),
                _countChip(tr('التزامات مفعّلة', 'Active assignments'), rows.length),
              ],
            ),
            const SizedBox(height: 16),
            if (data.catalogue.isEmpty)
              Card(child: Padding(padding: const EdgeInsets.all(18), child: Text(tr('مكتبة الالتزامات فارغة. تحقق من تطبيق ترحيل قاعدة البيانات.', 'The catalogue is empty. Check that the database migration has been applied.'))))
            else if (rows.isEmpty)
              Card(child: Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(tr('لم يتم ربط التزامات بأي عميل بعد. اختر الالتزامات المنطبقة على كل عميل.', 'No obligations have been assigned yet. Select the obligations that apply to each client.'), textAlign: TextAlign.center))))
            else
              Card(
                child: Column(
                  children: [
                    for (var i = 0; i < rows.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      Builder(builder: (context) {
                        final row = rows[i];
                        final obligation = catalogue[row['obligation_id']]!;
                        final frequency = obligation['frequency'] as String;
                        final name = ar ? obligation['name_ar'] as String : obligation['name_en'] as String;
                        return ListTile(
                          leading: CircleAvatar(child: Icon(_frequencyIcon(frequency))),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('${clients[row['client_id']]} • ${_frequencyLabel(frequency)} • ${row['effective_from']}'),
                          trailing: widget.canManage
                              ? IconButton(tooltip: tr('إلغاء التفعيل', 'Deactivate'), onPressed: () => _deactivate(row['id'] as String), icon: const Icon(Icons.link_off_outlined))
                              : null,
                        );
                      }),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 14),
            Text(tr('المكتبة المرجعية', 'Reference catalogue'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ..._frequencies.map((frequency) {
              final items = data.catalogue.where((item) => item['frequency'] == frequency).toList();
              if (items.isEmpty) return const SizedBox.shrink();
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ExpansionTile(
                  title: Text(_frequencyLabel(frequency), style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${items.length} ${tr('التزامات', 'obligations')}'),
                  children: [
                    for (final item in items)
                      ListTile(
                        title: Text(ar ? item['name_ar'] as String : item['name_en'] as String),
                        subtitle: Text((ar ? item['description_ar'] : item['description_en']) as String? ?? ''),
                      ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            Text(
              tr('ملاحظة: هذه مكتبة بداية وليست حصرًا قانونيًا كاملًا. يجب التحقق من انطباق كل التزام ودوريته وموعده على كل عميل قبل الاعتماد عليه.', 'Note: This is a starter catalogue, not a complete legal inventory. Verify each client’s applicability, frequency, and due date before relying on it.'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    },
  );

  Widget _frame({required Widget child, Widget? action}) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr('الالتزامات الضريبية', 'Tax obligations'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text(tr('مكتبة مركزية تختار منها الالتزامات المنطبقة على كل عميل.', 'A central catalogue for selecting obligations applicable to each client.'), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54)),
              ])),
              if (action != null) action,
            ]),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    ),
  );

  Widget _countChip(String label, int value) => Chip(avatar: const Icon(Icons.numbers, size: 16), label: Text('$label: $value'));

  String _frequencyLabel(String value) => switch (value) {
    'monthly' => tr('شهري', 'Monthly'),
    'quarterly' => tr('ربع سنوي', 'Quarterly'),
    'annual' => tr('سنوي', 'Annual'),
    'event_based' => tr('مرتبط بحدث', 'Event-based'),
    _ => value,
  };

  IconData _frequencyIcon(String value) => switch (value) {
    'monthly' => Icons.calendar_view_month,
    'quarterly' => Icons.date_range,
    'annual' => Icons.calendar_today,
    _ => Icons.event_note,
  };

  static const _frequencies = ['monthly', 'quarterly', 'annual', 'event_based'];
}

class _ObligationData {
  const _ObligationData({required this.clients, required this.catalogue, required this.assignments});
  final List<Map<String, dynamic>> clients;
  final List<Map<String, dynamic>> catalogue;
  final List<Map<String, dynamic>> assignments;
}

class _AssignmentDraft {
  const _AssignmentDraft(this.clientId, this.obligationIds, this.effectiveFrom, this.notes);
  final String clientId;
  final List<String> obligationIds;
  final DateTime effectiveFrom;
  final String notes;
}

class _AssignmentDialog extends StatefulWidget {
  const _AssignmentDialog({required this.locale, required this.data});
  final String locale;
  final _ObligationData data;

  @override
  State<_AssignmentDialog> createState() => _AssignmentDialogState();
}

class _AssignmentDialogState extends State<_AssignmentDialog> {
  late String _clientId = widget.data.clients.first['id'] as String;
  late final Set<String> _selected = {};
  final _notes = TextEditingController();
  DateTime _effectiveFrom = DateTime.now();
  bool get ar => widget.locale == 'ar';
  String tr(String a, String e) => ar ? a : e;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(tr('اختيار التزامات العميل', 'Select client obligations')),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _clientId,
              decoration: InputDecoration(labelText: tr('العميل', 'Client')),
              items: widget.data.clients.map((c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['display_name'] as String))).toList(),
              onChanged: (v) => setState(() => _clientId = v ?? _clientId),
            ),
            const SizedBox(height: 14),
            Text(tr('حدد الالتزامات المنطبقة', 'Choose applicable obligations'), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            for (final item in widget.data.catalogue)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _selected.contains(item['id']),
                onChanged: (v) => setState(() {
                  if (v == true) { _selected.add(item['id'] as String); } else { _selected.remove(item['id']); }
                }),
                title: Text(ar ? item['name_ar'] as String : item['name_en'] as String),
                subtitle: Text(switch (item['frequency']) {
                  'monthly' => tr('شهري', 'Monthly'),
                  'quarterly' => tr('ربع سنوي', 'Quarterly'),
                  'annual' => tr('سنوي', 'Annual'),
                  _ => tr('مرتبط بحدث', 'Event-based'),
                }),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final date = await showDatePicker(context: context, initialDate: _effectiveFrom, firstDate: DateTime(2000), lastDate: DateTime(2100));
                if (date != null) setState(() => _effectiveFrom = date);
              },
              icon: const Icon(Icons.event_outlined),
              label: Text(tr('ساري من: ', 'Effective from: ') + _effectiveFrom.toIso8601String().substring(0, 10)),
            ),
            TextField(controller: _notes, decoration: InputDecoration(labelText: tr('ملاحظات (اختياري)', 'Notes (optional)'))),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('إلغاء', 'Cancel'))),
      FilledButton(
        onPressed: _selected.isEmpty ? null : () => Navigator.pop(context, _AssignmentDraft(_clientId, _selected.toList(), _effectiveFrom, _notes.text)),
        child: Text(tr('حفظ الاختيارات', 'Save selections')),
      ),
    ],
  );
}
