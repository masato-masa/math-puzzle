import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'course.dart';

/// assets/levels/*.json（コース単位のファイル）を読み込む。
/// コースを追加するときは [kCourseFiles] にファイル名を足すだけでよい。
const List<String> kCourseFiles = [
  'assets/levels/main_course.json',
];

class LevelRepository {
  List<Course>? _cache;

  Future<List<Course>> loadCourses() async {
    final cached = _cache;
    if (cached != null) return cached;

    final courses = <Course>[];
    for (final path in kCourseFiles) {
      final raw = await rootBundle.loadString(path);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      for (final c in json['courses'] as List) {
        courses.add(Course.fromJson(c as Map<String, dynamic>));
      }
    }
    _cache = courses;
    return courses;
  }
}
