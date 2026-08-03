/// eラーニング コース + 受講状況モデル。
///
/// `social-commerce-hub`:
/// - `course.list` → `{success, courses: [hub_data 行]}`
///   実フィールド `metadata.title` / `description` / `level` / `language`。
/// - `course.progress` → `{success, enrollments: [hub_data 行]}`
///   実フィールド `metadata.course_id` / `metadata.progress`。
///
/// 旧実装のバグ:
/// - コース一覧: flat `c['title']` 等 + EF 非存在の `instructor`/`rating`/
///   `emoji`/`enrolled` を読み名称捏造・レベル消失。
/// - 学習中タブ: 応答キー `enrollments` を `courses` で読み**常に空**。
///   さらに enrollment は course_id しか持たないので course と join が必要。
library;

import 'hub_data_parsing.dart';

class ELearningCourse {
  const ELearningCourse({
    required this.id,
    required this.title,
    required this.description,
    required this.level,
    required this.language,
    this.progress = 0,
  });

  final String id;
  final String title;
  final String description;
  final String level;
  final String language;

  /// 受講進捗 0-100 (course.progress と join した場合のみ非 0)。
  final num progress;

  ELearningCourse withProgress(num p) => ELearningCourse(
        id: id,
        title: title,
        description: description,
        level: level,
        language: language,
        progress: p,
      );

  factory ELearningCourse.fromMap(Map<String, dynamic> raw) {
    return ELearningCourse(
      id: hubString(raw['id']),
      title: hubString(hubField(raw, 'title')),
      description: hubString(hubField(raw, 'description')),
      level: hubString(hubField(raw, 'level')),
      language: hubString(hubField(raw, 'language')),
    );
  }

  static List<ELearningCourse> listFromResponse(dynamic data) =>
      hubRowsFromResponse(data, 'courses')
          .map(ELearningCourse.fromMap)
          .toList();

  /// `course.progress` の enrollments を course_id→progress へ畳む。
  static Map<String, num> progressByCourseId(dynamic data) {
    final result = <String, num>{};
    for (final row in hubRowsFromResponse(data, 'enrollments')) {
      final courseId = hubString(hubField(row, 'course_id'));
      if (courseId.isEmpty) continue;
      result[courseId] = hubNum(hubField(row, 'progress'));
    }
    return result;
  }

  /// コース一覧に受講進捗を join し、受講中 (progress>0) のみ返す。
  static List<ELearningCourse> inProgress(
    List<ELearningCourse> courses,
    Map<String, num> progressById,
  ) {
    final out = <ELearningCourse>[];
    for (final c in courses) {
      final p = progressById[c.id];
      if (p != null && p > 0) out.add(c.withProgress(p));
    }
    return out;
  }
}
