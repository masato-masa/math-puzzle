import 'models.dart';

/// レベルの束（コース）。今は「基本コース」1 本だが、上級コースや
/// 追加パックを増やすときはこの単位で assets/levels/*.json を増やすだけでよい
/// （ルールエンジン側は一切変更不要）。
class Course {
  final String courseId;
  final String title;
  final List<Level> levels;

  const Course({
    required this.courseId,
    required this.title,
    required this.levels,
  });

  factory Course.fromJson(Map<String, dynamic> json) => Course(
        courseId: json['courseId'] as String,
        title: json['title'] as String,
        levels: (json['levels'] as List)
            .map((l) => Level.fromJson(l as Map<String, dynamic>))
            .toList(),
      );
}
