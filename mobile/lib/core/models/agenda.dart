class AgendaItem {
  const AgendaItem({
    required this.id,
    required this.sourceId,
    required this.kind,
    required this.title,
    required this.day,
    this.startsAt,
    this.endsAt,
    this.isAllDay = false,
    this.isImportant = false,
    this.isCompleted = false,
    this.status = 'pending',
    this.metadata = const {},
  });

  final String id;
  final Object sourceId;
  final String kind;
  final String title;
  final DateTime day;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool isAllDay;
  final bool isImportant;
  final bool isCompleted;
  final String status;
  final Map<String, Object?> metadata;

  String get displayTitle => isCompleted ? '✓ $title' : title;

  factory AgendaItem.fromJson(Map<String, Object?> json) => AgendaItem(
        id: json['id']! as String,
        sourceId: json['source_id']!,
        kind: json['kind']! as String,
        title: json['title']! as String,
        day: DateTime.parse(json['day']! as String),
        startsAt: json['starts_at'] == null
            ? null
            : DateTime.parse(json['starts_at']! as String),
        endsAt: json['ends_at'] == null
            ? null
            : DateTime.parse(json['ends_at']! as String),
        isAllDay: json['is_all_day'] as bool? ?? false,
        isImportant: json['is_important'] as bool? ?? false,
        isCompleted: json['is_completed'] as bool? ?? false,
        status: json['status'] as String? ?? 'pending',
        metadata: Map<String, Object?>.from(
          json['metadata'] as Map? ?? const <String, Object?>{},
        ),
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'source_id': sourceId,
        'kind': kind,
        'title': title,
        'day': _date(day),
        'starts_at': startsAt?.toIso8601String(),
        'ends_at': endsAt?.toIso8601String(),
        'is_all_day': isAllDay,
        'is_important': isImportant,
        'is_completed': isCompleted,
        'status': status,
        'metadata': metadata,
      };

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
