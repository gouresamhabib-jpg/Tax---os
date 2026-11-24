import '../domain/work_item.dart';

abstract interface class WorkItemRepository {
  List<WorkItem> getAll();

  void save(WorkItem item);
}

class InMemoryWorkItemRepository implements WorkItemRepository {
  InMemoryWorkItemRepository({List<WorkItem>? initialItems})
      : _items = List.of(initialItems ?? demoWorkItems);

  final List<WorkItem> _items;

  static final demoWorkItems = <WorkItem>[
    WorkItem(
      id: 'task-1',
      title: 'مراجعة إقرار القيمة المضافة',
      clientId: 'demo-1',
      assigneeId: 'member-2',
      reviewerId: 'member-1',
      status: WorkItemStatus.inProgress,
      dueDate: DateTime(2026, 11, 26),
    ),
    WorkItem(
      id: 'task-2',
      title: 'تجهيز مستندات ضريبة المرتبات',
      clientId: 'demo-2',
      assigneeId: 'member-1',
      reviewerId: 'member-3',
      dueDate: DateTime(2026, 11, 27),
    ),
    WorkItem(
      id: 'task-3',
      title: 'مطابقة شهادة التعاملات',
      clientId: 'demo-3',
      assigneeId: 'member-3',
      status: WorkItemStatus.blocked,
      dueDate: DateTime(2026, 11, 25),
    ),
  ];

  @override
  List<WorkItem> getAll() => List.unmodifiable(_items);

  @override
  void save(WorkItem item) {
    final index = _items.indexWhere((existing) => existing.id == item.id);
    if (index == -1) {
      _items.add(item);
    } else {
      _items[index] = item;
    }
  }
}
