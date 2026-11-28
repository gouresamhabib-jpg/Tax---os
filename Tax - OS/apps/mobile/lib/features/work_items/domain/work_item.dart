enum WorkItemStatus { todo, inProgress, blocked, completed, cancelled }

class WorkItem {
  const WorkItem({
    required this.id,
    required this.title,
    required this.clientId,
    required this.assigneeId,
    this.reviewerId,
    this.status = WorkItemStatus.todo,
    this.dueDate,
  });

  final String id;
  final String title;
  final String clientId;
  final String assigneeId;
  final String? reviewerId;
  final WorkItemStatus status;
  final DateTime? dueDate;

  WorkItem copyWith({
    String? title,
    String? clientId,
    String? assigneeId,
    String? reviewerId,
    WorkItemStatus? status,
    DateTime? dueDate,
    bool clearReviewer = false,
    bool clearDueDate = false,
  }) {
    return WorkItem(
      id: id,
      title: title ?? this.title,
      clientId: clientId ?? this.clientId,
      assigneeId: assigneeId ?? this.assigneeId,
      reviewerId: clearReviewer ? null : reviewerId ?? this.reviewerId,
      status: status ?? this.status,
      dueDate: clearDueDate ? null : dueDate ?? this.dueDate,
    );
  }
}
