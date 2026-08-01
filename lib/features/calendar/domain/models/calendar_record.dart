import 'dart:convert';

enum CalendarRecordType { weather, outfit, text, image }

class CalendarRecord {
  const CalendarRecord({
    this.id,
    required this.date,
    required this.type,
    this.textContent,
    this.imagePaths = const [],
    required this.createdAt,
  });

  final int? id;
  final DateTime date;
  final CalendarRecordType type;
  final String? textContent;
  final List<String> imagePaths;
  final DateTime createdAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'record_date': date.toIso8601String(),
      'entry_type': type.name,
      'text_content': textContent,
      'image_paths': jsonEncode(imagePaths),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory CalendarRecord.fromMap(Map<String, Object?> map) {
    final encodedImagePaths = map['image_paths'] as String? ?? '[]';

    return CalendarRecord(
      id: map['id'] as int?,
      date: DateTime.parse(map['record_date'] as String),
      type: CalendarRecordType.values.firstWhere(
        (type) => type.name == map['entry_type'],
      ),
      textContent: map['text_content'] as String?,
      imagePaths: List<String>.from(jsonDecode(encodedImagePaths) as List),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
