import '../domain/team_member.dart';

class InMemoryTeamRepository {
  InMemoryTeamRepository() : _members = [
    const TeamMember(id: 'member-owner', name: 'Jour Habib', email: 'owner@taxos.demo', role: TeamRole.owner, status: TeamMemberStatus.active),
    const TeamMember(id: 'member-ahmed', name: 'Ahmed Hassan', email: 'ahmed@taxos.demo', role: TeamRole.admin, status: TeamMemberStatus.active),
    const TeamMember(id: 'member-mariam', name: 'Mariam Ali', email: 'mariam@taxos.demo', role: TeamRole.accountant, status: TeamMemberStatus.active),
    const TeamMember(id: 'member-mahmoud', name: 'Mahmoud Sami', email: 'mahmoud@taxos.demo', role: TeamRole.reviewer, status: TeamMemberStatus.suspended),
  ];

  final List<TeamMember> _members;
  final List<TeamInvitation> _invitations = [];
  int _nextId = 0;

  List<TeamMember> get members => List.unmodifiable(_members);
  List<TeamInvitation> get invitations => List.unmodifiable(_invitations);

  TeamInvitation invite(String email, TeamRole role, {DateTime? now}) {
    final createdAt = now ?? DateTime.now();
    final invitation = TeamInvitation(
      id: 'invite-${++_nextId}', email: email.trim().toLowerCase(), role: role,
      createdAt: createdAt, expiresAt: createdAt.add(const Duration(days: 7)),
    );
    _invitations.insert(0, invitation);
    return invitation;
  }

  void updateRole(String id, TeamRole role) {
    final index = _members.indexWhere((member) => member.id == id);
    if (index < 0 || _members[index].role == TeamRole.owner) return;
    _members[index] = _members[index].copyWith(role: role);
  }

  void suspend(String id) => _updateStatus(id, TeamMemberStatus.suspended);
  void reactivate(String id) => _updateStatus(id, TeamMemberStatus.active);
  void revoke(String id) {
    final index = _members.indexWhere((member) => member.id == id);
    if (index < 0 || _members[index].role == TeamRole.owner) return;
    _updateStatus(id, TeamMemberStatus.revoked);
  }

  void _updateStatus(String id, TeamMemberStatus status) {
    final index = _members.indexWhere((member) => member.id == id);
    if (index < 0 || _members[index].role == TeamRole.owner ||
        _members[index].status == TeamMemberStatus.revoked) return;
    _members[index] = _members[index].copyWith(status: status);
  }
}
