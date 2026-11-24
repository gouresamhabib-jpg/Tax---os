class DemoOfficeMember {
  const DemoOfficeMember({
    required this.id,
    required this.arabicName,
    required this.englishName,
  });

  final String id;
  final String arabicName;
  final String englishName;

  String nameFor(String locale) => locale == 'ar' ? arabicName : englishName;
}

const demoOfficeMembers = <DemoOfficeMember>[
  DemoOfficeMember(
    id: 'member-1',
    arabicName: 'أحمد حسن',
    englishName: 'Ahmed Hassan',
  ),
  DemoOfficeMember(
    id: 'member-2',
    arabicName: 'مريم علي',
    englishName: 'Mariam Ali',
  ),
  DemoOfficeMember(
    id: 'member-3',
    arabicName: 'محمود سامي',
    englishName: 'Mahmoud Sami',
  ),
];

String demoOfficeMemberName(String memberId, String locale) {
  for (final member in demoOfficeMembers) {
    if (member.id == memberId) return member.nameFor(locale);
  }
  return locale == 'ar' ? 'غير محدد' : 'Unassigned';
}
