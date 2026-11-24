enum TeamRole { owner, admin, manager, accountant, reviewer, staff, readOnly }
enum TeamMemberStatus { active, suspended, revoked }

class TeamMember {
  const TeamMember({required this.id, required this.name, required this.email, required this.role, required this.status});
  final String id;
  final String name;
  final String email;
  final TeamRole role;
  final TeamMemberStatus status;
  TeamMember copyWith({TeamRole? role, TeamMemberStatus? status}) => TeamMember(
    id: id, name: name, email: email, role: role ?? this.role, status: status ?? this.status,
  );
}

class TeamInvitation {
  const TeamInvitation({required this.id, required this.email, required this.role, required this.createdAt, required this.expiresAt});
  final String id;
  final String email;
  final TeamRole role;
  final DateTime createdAt;
  final DateTime expiresAt;
}
