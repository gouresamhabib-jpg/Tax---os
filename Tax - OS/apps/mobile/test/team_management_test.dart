import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:taxos/features/team/data/team_repository.dart';
import 'package:taxos/features/team/domain/team_member.dart';
import 'package:taxos/features/team/team_management_page.dart';

void main() {
  group('Team management demo', () {
    test('invitation is local and expires after seven days', () {
      final repository = InMemoryTeamRepository();
      final now = DateTime(2026, 11, 24, 10);
      final invitation = repository.invite(
        ' New.Member@Example.com ',
        TeamRole.accountant,
        now: now,
      );
      expect(repository.invitations, hasLength(1));
      expect(invitation.email, 'new.member@example.com');
      expect(invitation.expiresAt, now.add(const Duration(days: 7)));
    });

    testWidgets('shows team members and demo-only notice', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: TeamManagementPage(locale: 'en')),
      );
      expect(find.text('Office team'), findsOneWidget);
      expect(find.textContaining('not sent'), findsOneWidget);
      expect(find.text('Ahmed Hassan'), findsOneWidget);
      expect(find.text('Mariam Ali'), findsOneWidget);
    });

    testWidgets('prepares invitation in demo mode', (tester) async {
      final repository = InMemoryTeamRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: TeamManagementPage(locale: 'en', repository: repository),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('team_invite_fab')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('invite_email')),
        'new.person@example.com',
      );
      await tester.tap(find.byKey(const ValueKey('invite_submit')));
      await tester.pumpAndSettle();
      expect(repository.invitations, hasLength(1));
      expect(repository.invitations.single.email, 'new.person@example.com');
      expect(find.textContaining('prepared in demo mode'), findsOneWidget);
    });

    test('owner cannot be revoked or reassigned', () {
      final repository = InMemoryTeamRepository();
      repository.updateRole('member-owner', TeamRole.staff);
      repository.revoke('member-owner');
      expect(repository.members.first.role, TeamRole.owner);
      expect(repository.members.first.status, TeamMemberStatus.active);
    });
  });
}
