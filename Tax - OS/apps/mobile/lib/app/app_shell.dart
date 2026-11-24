import 'package:flutter/material.dart';

import 'app_copy.dart';
import '../features/clients/clients_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    required this.locale,
    required this.onToggleLocale,
    super.key,
  });

  final String locale;
  final VoidCallback onToggleLocale;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  String tr(String key) => AppCopy.t(widget.locale, key);

  static const _destinations = <_DestinationData>[
    _DestinationData('dashboard', Icons.space_dashboard_outlined),
    _DestinationData('clients', Icons.people_alt_outlined),
    _DestinationData('obligations', Icons.assignment_outlined),
    _DestinationData('calendar', Icons.calendar_month_outlined),
    _DestinationData('documents', Icons.folder_open_outlined),
    _DestinationData('office', Icons.business_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final useRail = width >= 900;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Text(
                'T',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'TaxOS',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        actions: [
          _DemoBadge(label: tr('demo')),
          const SizedBox(width: 6),
          IconButton(
            key: const ValueKey('toggle_locale'),
            tooltip: 'Switch language',
            onPressed: widget.onToggleLocale,
            icon: const Icon(Icons.language),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          if (useRail)
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _selectDestination,
              labelType: NavigationRailLabelType.all,
              backgroundColor: Colors.white,
              destinations: _destinations
                  .map(
                    (item) => NavigationRailDestination(
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.icon),
                      label: Text(tr(item.labelKey)),
                    ),
                  )
                  .toList(),
            ),
          if (useRail) const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                _DashboardPage(locale: widget.locale),
                ClientsPage(locale: widget.locale),
                _ObligationsPage(locale: widget.locale),
                _CalendarPage(locale: widget.locale),
                _DocumentsPage(locale: widget.locale),
                _OfficePage(locale: widget.locale),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: useRail
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _selectDestination,
              destinations: _destinations
                  .map(
                    (item) => NavigationDestination(
                      key: ValueKey('nav_${item.labelKey}'),
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.icon),
                      label: tr(item.labelKey),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  void _selectDestination(int index) {
    setState(() => _selectedIndex = index);
  }
}

class _DestinationData {
  const _DestinationData(this.labelKey, this.icon);

  final String labelKey;
  final IconData icon;
}

class _DemoBadge extends StatelessWidget {
  const _DemoBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F2F0),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF176B67),
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      );
}

class _PageHeading extends StatelessWidget {
  const _PageHeading({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.black54,
                ),
          ),
        ],
      );
}

class _PageFrame extends StatelessWidget {
  const _PageFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: child,
          ),
        ),
      );
}

class _DashboardPage extends StatelessWidget {
  const _DashboardPage({required this.locale});

  final String locale;

  String tr(String key) => AppCopy.t(locale, key);

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _MetricData('upcoming', '18', Icons.event_available_outlined),
      _MetricData('overdue', '4', Icons.warning_amber_rounded),
      _MetricData('inReview', '7', Icons.rate_review_outlined),
      _MetricData('completed', '32', Icons.task_alt_outlined),
    ];

    return _PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PageHeading(
            title: tr('welcome'),
            subtitle: tr('welcomeSubtitle'),
          ),
          const SizedBox(height: 18),
          _DemoNotice(text: tr('demoNotice')),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 850
                  ? 4
                  : constraints.maxWidth >= 520
                      ? 2
                      : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: metrics.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 116,
                ),
                itemBuilder: (context, index) {
                  final item = metrics[index];
                  return _MetricCard(
                    label: tr(item.labelKey),
                    value: item.value,
                    icon: item.icon,
                  );
                },
              );
            },
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              Expanded(
                child: Text(
                  tr('recentWork'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ObligationTable(locale: locale),
        ],
      ),
    );
  }
}

class _MetricData {
  const _MetricData(this.labelKey, this.value, this.icon);

  final String labelKey;
  final String value;
  final IconData icon;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F2F0),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: const Color(0xFF176B67)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.black54,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _ObligationTable extends StatelessWidget {
  const _ObligationTable({required this.locale});

  final String locale;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('clientAlNoor', 'vat', 'oct2026', '2026/11/30', 'inProgress'),
      ('clientAlAmal', 'payroll', 'oct2026', '2026/11/30', 'readyReview'),
      ('clientDelta', 'incomeTax', 'taxYear2025', '2026/12/31', 'filed'),
    ];

    return Card(
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 600;
                  final row = rows[i];
                  return compact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(AppCopy.t(locale, row.$1), style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 5),
                            Text(AppCopy.t(locale, row.$2)),
                            Text(AppCopy.t(locale, row.$3)),
                            Text(row.$4, style: const TextStyle(color: Colors.black54)),
                            const SizedBox(height: 6),
                            _StatusPill(label: AppCopy.t(locale, row.$5)),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(flex: 3, child: Text(AppCopy.t(locale, row.$1), style: const TextStyle(fontWeight: FontWeight.w700))),
                            Expanded(flex: 2, child: Text(AppCopy.t(locale, row.$2))),
                            Expanded(flex: 2, child: Text(AppCopy.t(locale, row.$3))),
                            Expanded(flex: 2, child: Text(row.$4)),
                            _StatusPill(label: AppCopy.t(locale, row.$5)),
                          ],
                        );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F2F0),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF176B67),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _DemoNotice extends StatelessWidget {
  const _DemoNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
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
                text,
                style: const TextStyle(color: Color(0xFF725318), fontSize: 13),
              ),
            ),
          ],
        ),
      );
}

class _ObligationsPage extends StatelessWidget {
  const _ObligationsPage({required this.locale});

  final String locale;

  String tr(String key) => AppCopy.t(locale, key);

  @override
  Widget build(BuildContext context) => _PageFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PageHeading(title: tr('obligations'), subtitle: tr('obligationsSubtitle')),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              children: [
                for (final key in ['all', 'inProgress', 'readyReview', 'filed'])
                  Chip(label: Text(tr(key))),
              ],
            ),
            const SizedBox(height: 12),
            _ObligationTable(locale: locale),
          ],
        ),
      );
}

class _CalendarPage extends StatelessWidget {
  const _CalendarPage({required this.locale});

  final String locale;

  @override
  Widget build(BuildContext context) {
    final tr = (String key) => AppCopy.t(locale, key);
    return _PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PageHeading(title: tr('calendar'), subtitle: tr('calendarSubtitle')),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.calendar_month_outlined, size: 42, color: Color(0xFF176B67)),
                    const SizedBox(height: 12),
                    Text(tr('calendarEmpty')),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentsPage extends StatelessWidget {
  const _DocumentsPage({required this.locale});

  final String locale;

  @override
  Widget build(BuildContext context) {
    final tr = (String key) => AppCopy.t(locale, key);
    return _PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PageHeading(title: tr('documents'), subtitle: tr('documentsSubtitle')),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.folder_open_outlined, size: 42, color: Color(0xFF176B67)),
                    const SizedBox(height: 12),
                    Text(tr('documentsEmpty')),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfficePage extends StatelessWidget {
  const _OfficePage({required this.locale});

  final String locale;

  @override
  Widget build(BuildContext context) {
    final tr = (String key) => AppCopy.t(locale, key);
    return _PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PageHeading(title: tr('office'), subtitle: tr('officeSubtitle')),
          const SizedBox(height: 18),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.business_outlined)),
                  title: Text(tr('officeName')),
                  subtitle: Text(tr('workspaceMode')),
                  trailing: const Icon(Icons.more_horiz),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(tr('language')),
                  subtitle: Text(locale == 'ar' ? tr('arabic') : tr('english')),
                ),
                ListTile(
                  leading: const Icon(Icons.cloud_off_outlined),
                  title: Text(tr('noConnection')),
                  subtitle: Text(tr('demoNotice')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
