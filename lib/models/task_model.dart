enum TaskType {
  deadline, // A. 締切のあるタスク
  daily, // B. 毎日実施する必要があるタスク
  routine, // C. 定期的な自己研鑽・開発
  reward, // D. 完了後の快楽
}

class TaskModel {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final TaskType taskType;
  final DateTime? deadline;
  final bool isCompleted;
  final DateTime createdAt;

  TaskModel({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.taskType,
    this.deadline,
    required this.isCompleted,
    required this.createdAt,
  });

  // A -> B -> C -> D の順に並び替えるためのスコア
  int get priorityScore {
    switch (taskType) {
      case TaskType.deadline:
        return 1;
      case TaskType.daily:
        return 2;
      case TaskType.routine:
        return 3;
      case TaskType.reward:
        return 4;
    }
  }

  // ユーザーへの意識付けメッセージ（タイプ別）
  String get adviceMessage {
    switch (taskType) {
      case TaskType.deadline:
        return '締切がある作業は今すぐ着手。何から手をつけるか迷うな。';
      case TaskType.daily:
        return '単純作業ほど凡ミスが増える。絶対にミスがないよう注意せよ。';
      case TaskType.routine:
        return '興味を持てるように工夫せよ。感情や疲労は顔に出すな。';
      case TaskType.reward:
        return 'やるべきことは終わったか？ 終わっていなければ着手してはならない。';
    }
  }

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'],
      userId: json['user_id'],
      title: json['title'],
      description: json['description'],
      taskType: TaskType.values.firstWhere(
        (e) => e.toString().split('.').last == json['task_type'],
        orElse: () => TaskType.routine,
      ),
      deadline:
          json['deadline'] != null ? DateTime.parse(json['deadline']) : null,
      isCompleted: json['is_completed'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'title': title,
      'description': description,
      'task_type': taskType.toString().split('.').last,
      'deadline': deadline?.toIso8601String(),
      'is_completed': isCompleted,
    };
  }

  TaskModel copyWith({bool? isCompleted}) {
    return TaskModel(
      id: id,
      userId: userId,
      title: title,
      description: description,
      taskType: taskType,
      deadline: deadline,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt,
    );
  }
}
