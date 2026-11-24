import 'package:material_ui/material_ui.dart';

import '../../app/app_copy.dart';
import 'data/team_repository.dart';
import 'domain/team_member.dart';

class TeamManagementPage extends StatefulWidget {
  const TeamManagementPage({required this.locale, this.repository, super.key});
  final String locale;
  final InMemoryTeamRepository? repository;

  @override
  State<TeamManagementPage> createState() => _TeamManagementPageState();
}

class _TeamManagementPageState extends State<TeamManagementPage> {
  late final InMemoryTeamRepository _repository;
  String tr(String key) => AppCopy.t(widget.locale, key);

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? InMemoryTeamRepository();
  }

  @override
  Widget build(BuildContext context) {
    final active = _repository.members.where((m) => m.status == TeamMemberStatus.active).length;
    return Scaffold(
      appBar: AppBar(title: Text(tr('teamManagement'))),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('team_invite_fab'),
        onPressed: _invite,
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(tr('inviteMember')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(tr('teamSubtitle')),
          const SizedBox(height: 14),
          _DemoNotice(text: tr('teamDemoNotice')),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _CountCard(label: tr('activeMembers'), value: '$active', icon: Icons.groups_outlined)),
            const SizedBox(width: 10),
            Expanded(child: _CountCard(label: tr('pendingInvitations'), value: '${_repository.invitations.length}', icon: Icons.mail_outline)),
          ]),
          const SizedBox(height: 22),
          Text(tr('officeMembers'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ..._repository.members.map(_memberCard),
          const SizedBox(height: 20),
          Text(tr('invitations'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (_repository.invitations.isEmpty)
            Card(child: Padding(padding: const EdgeInsets.all(18), child: Text(tr('noInvitations'))))
          else
            ..._repository.invitations.map((invite) => Card(
              key: ValueKey('team_invitation_${invite.id}'),
              child: ListTile(
                leading: const Icon(Icons.mark_email_unread_outlined),
                title: Text(invite.email),
                subtitle: Text('${_roleLabel(invite.role)} • ${tr('expiresInSevenDays')}'),
                trailing: Chip(label: Text(tr('pending'))),
              ),
            )),
        ],
      ),
    );
  }

  Widget _memberCard(TeamMember member) {
    final owner = member.role == TeamRole.owner;
    final manageable = !owner && member.status != TeamMemberStatus.revoked;
    return Card(
      key: ValueKey('team_member_${member.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(child: Text(member.name.substring(0, 1))),
        title: Text(member.name),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(member.email),
          const SizedBox(height: 5),
          Wrap(spacing: 6, children: [
            Chip(label: Text(_roleLabel(member.role)), visualDensity: VisualDensity.compact),
            Chip(label: Text(_statusLabel(member.status)), visualDensity: VisualDensity.compact),
          ]),
        ]),
        isThreeLine: true,
        trailing: manageable
          ? PopupMenuButton<String>(
              key: ValueKey('team_actions_${member.id}'),
              onSelected: (action) => _memberAction(member, action),
              itemBuilder: (context) => [
                PopupMenuItem(value: 'role', child: Text(tr('changeRole'))),
                if (member.status == TeamMemberStatus.active)
                  PopupMenuItem(value: 'suspend', child: Text(tr('suspendMember'))),
                if (member.status == TeamMemberStatus.suspended)
                  PopupMenuItem(value: 'activate', child: Text(tr('reactivateMember'))),
                PopupMenuItem(value: 'revoke', child: Text(tr('revokeMember'))),
              ],
            )
          : const Icon(Icons.verified_user_outlined),
      ),
    );
  }

  Future<void> _invite() async {
    final draft = await showDialog<_InviteDraft>(context: context, builder: (_) => _InviteDialog(locale: widget.locale));
    if (draft == null || !mounted) return;
    setState(() => _repository.invite(draft.email, draft.role));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('invitePreparedDemo'))));
  }

  Future<void> _memberAction(TeamMember member, String action) async {
    if (action == 'role') {
      final role = await showDialog<TeamRole>(context: context, builder: (_) => _RoleDialog(locale: widget.locale, currentRole: member.role));
      if (role != null && mounted) setState(() => _repository.updateRole(member.id, role));
    } else if (action == 'suspend') {
      setState(() => _repository.suspend(member.id));
    } else if (action == 'activate') {
      setState(() => _repository.reactivate(member.id));
    } else if (action == 'revoke') {
      final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
        title: Text(tr('revokeMember')), content: Text(tr('revokeConfirmation')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('confirm'))),
        ],
      ));
      if (confirmed == true && mounted) setState(() => _repository.revoke(member.id));
    }
  }

  String _roleLabel(TeamRole role) => tr(switch (role) {
    TeamRole.owner => 'roleOwner', TeamRole.admin => 'roleAdmin', TeamRole.manager => 'roleManager',
    TeamRole.accountant => 'roleAccountant', TeamRole.reviewer => 'roleReviewer',
    TeamRole.staff => 'roleStaff', TeamRole.readOnly => 'roleReadOnly',
  });

  String _statusLabel(TeamMemberStatus status) => tr(switch (status) {
    TeamMemberStatus.active => 'memberActive', TeamMemberStatus.suspended => 'memberSuspended',
    TeamMemberStatus.revoked => 'memberRevoked',
  });
}

class _InviteDraft {
  const _InviteDraft(this.email, this.role);
  final String email;
  final TeamRole role;
}

class _InviteDialog extends StatefulWidget {
  const _InviteDialog({required this.locale});
  final String locale;
  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  TeamRole _role = TeamRole.accountant;
  String tr(String key) => AppCopy.t(widget.locale, key);

  @override
  void dispose() { _email.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(tr('inviteMember')),
    content: Form(
      key: _formKey,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(
          key: const ValueKey('invite_email'), controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(labelText: tr('email')),
          validator: (value) {
            final v = value?.trim() ?? '';
            return v.contains('@') && v.contains('.') ? null : tr('validEmailRequired');
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<TeamRole>(
          value: _role, decoration: InputDecoration(labelText: tr('memberRole')),
          items: _assignableRoles.map((role) => DropdownMenuItem(value: role, child: Text(_roleLabel(role)))).toList(),
          onChanged: (value) { if (value != null) setState(() => _role = value); },
        ),
      ]),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('cancel'))),
      FilledButton(
        key: const ValueKey('invite_submit'),
        onPressed: () {
          if (_formKey.currentState?.validate() != true) return;
          Navigator.pop(context, _InviteDraft(_email.text.trim(), _role));
        },
        child: Text(tr('prepareInvitation')),
      ),
    ],
  );

  String _roleLabel(TeamRole role) => tr(switch (role) {
    TeamRole.admin => 'roleAdmin', TeamRole.manager => 'roleManager',
    TeamRole.accountant => 'roleAccountant', TeamRole.reviewer => 'roleReviewer',
    TeamRole.staff => 'roleStaff', TeamRole.readOnly => 'roleReadOnly',
    TeamRole.owner => 'roleOwner',
  });
}

const _assignableRoles = [
  TeamRole.admin, TeamRole.manager, TeamRole.accountant,
  TeamRole.reviewer, TeamRole.staff, TeamRole.readOnly,
];

class _RoleDialog extends StatefulWidget {
  const _RoleDialog({required this.locale, required this.currentRole});
  final String locale;
  final TeamRole currentRole;
  @override
  State<_RoleDialog> createState() => _RoleDialogState();
}

class _RoleDialogState extends State<_RoleDialog> {
  late TeamRole _role = widget.currentRole;
  String tr(String key) => AppCopy.t(widget.locale, key);

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(tr('changeRole')),
    content: DropdownButtonFormField<TeamRole>(
      value: _role,
      items: _assignableRoles.map((role) => DropdownMenuItem(value: role, child: Text(tr(switch (role) {
        TeamRole.admin => 'roleAdmin', TeamRole.manager => 'roleManager',
        TeamRole.accountant => 'roleAccountant', TeamRole.reviewer => 'roleReviewer',
        TeamRole.staff => 'roleStaff', TeamRole.readOnly => 'roleReadOnly', TeamRole.owner => 'roleOwner',
      })))).toList(),
      onChanged: (value) { if (value != null) setState(() => _role = value); },
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('cancel'))),
      FilledButton(onPressed: () => Navigator.pop(context, _role), child: Text(tr('save'))),
    ],
  );
}

class _CountCard extends StatelessWidget {
  const _CountCard({required this.label, required this.value, required this.icon});
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(13),
      child: Row(children: [
        Icon(icon, color: const Color(0xFF176B67)), const SizedBox(width: 9),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ])),
      ]),
    ),
  );
}

class _DemoNotice extends StatelessWidget {
  const _DemoNotice({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: const Color(0xFFFFF5DF), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF0E0B8))),
    child: Row(children: [
      const Icon(Icons.info_outline, color: Color(0xFF8B651B), size: 19), const SizedBox(width: 8),
      Expanded(child: Text(text, style: const TextStyle(color: Color(0xFF725318), fontSize: 12))),
    ]),
  );
}
