class DiaryEntry {
  final int? id;
  final String entryDate; // yyyy-MM-dd
  final String body;
  final String reminder;
  final bool reminderCompleted;
  final String createdAt;
  final String updatedAt;

  const DiaryEntry({
    this.id,
    required this.entryDate,
    required this.body,
    required this.reminder,
    required this.reminderCompleted,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DiaryEntry.newEmpty(String entryDate) {
    final now = DateTime.now().toIso8601String();
    return DiaryEntry(
      entryDate: entryDate,
      body: '',
      reminder: '',
      reminderCompleted: false,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory DiaryEntry.fromMap(Map<String, dynamic> map) {
    return DiaryEntry(
      id: map['id'] as int?,
      entryDate: map['entry_date'] as String,
      body: (map['body'] ?? '') as String,
      reminder: (map['reminder'] ?? '') as String,
      reminderCompleted: (map['reminder_completed'] ?? 0) == 1,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'entry_date': entryDate,
      'body': body,
      'reminder': reminder,
      'reminder_completed': reminderCompleted ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  Map<String, dynamic> toBackupJson() {
    return {
      'entryDate': entryDate,
      'body': body,
      'reminder': reminder,
      'reminderCompleted': reminderCompleted,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory DiaryEntry.fromBackupJson(Map<String, dynamic> json) {
    final now = DateTime.now().toIso8601String();
    final rawCompleted = json['reminderCompleted'] ?? json['reminder_completed'] ?? false;

    return DiaryEntry(
      entryDate: (json['entryDate'] ?? json['entry_date']) as String,
      body: (json['body'] ?? '') as String,
      reminder: (json['reminder'] ?? '') as String,
      reminderCompleted: rawCompleted == true || rawCompleted == 1,
      createdAt: (json['createdAt'] ?? json['created_at'] ?? now) as String,
      updatedAt: (json['updatedAt'] ?? json['updated_at'] ?? now) as String,
    );
  }

  DiaryEntry copyWith({
    int? id,
    String? entryDate,
    String? body,
    String? reminder,
    bool? reminderCompleted,
    String? createdAt,
    String? updatedAt,
  }) {
    return DiaryEntry(
      id: id ?? this.id,
      entryDate: entryDate ?? this.entryDate,
      body: body ?? this.body,
      reminder: reminder ?? this.reminder,
      reminderCompleted: reminderCompleted ?? this.reminderCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
