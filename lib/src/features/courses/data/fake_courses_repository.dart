import 'dart:math';
import '../domain/course_models.dart';

class FakeCoursesRepository {
  FakeCoursesRepository() : _courses = _seed();

  final List<Course> _courses;

  Future<List<Course>> listCourses({
    String? search,
    String? department,
    String? level,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));

    Iterable<Course> out = _courses;

    final q = (search ?? '').trim().toLowerCase();
    if (q.isNotEmpty) {
      out = out.where((c) => c.title.toLowerCase().contains(q));
    }

    final dep = (department ?? '').trim();
    if (dep.isNotEmpty) {
      out = out.where((c) => (c.department ?? '') == dep);
    }

    final lev = (level ?? '').trim();
    if (lev.isNotEmpty) {
      out = out.where((c) => (c.level ?? '') == lev);
    }

    return out.toList();
  }

  Future<Course?> getCourseById(String courseId) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    try {
      return _courses.firstWhere((c) => c.id == courseId);
    } catch (_) {
      return null;
    }
  }

  static List<Course> _seed() {
    final rng = Random(42);
    // ignore: unused_element
    double r() => (rng.nextInt(17) + 30) / 10.0; // 3.0..4.6
    // using r() is optional; keeping seed constant is fine

    return const [
      Course(
        id: 'c-001',
        title: 'Programlamaya Giriş',
        description: 'Algoritma mantığı, temel veri tipleri, koşullar ve döngüler.',
        department: 'Bilgisayar Mühendisliği',
        duration: '4 saat',
        level: 'Başlangıç',
        instructor: 'Dr. A. Yılmaz',
        category: 'Temel Dersler',
        rating: 4.4,
        totalRatings: 128,
        enrolledCount: 1240,
        videoUrl: 'https://example.com/video1',
      ),
      Course(
        id: 'c-002',
        title: 'Veri Yapıları',
        description: 'Liste, yığın, kuyruk, ağaç ve karmaşıklık analizi.',
        department: 'Bilgisayar Mühendisliği',
        duration: '6 saat',
        level: 'Orta',
        instructor: 'Doç. B. Kaya',
        category: 'Alan Dersleri',
        rating: 4.6,
        totalRatings: 221,
        enrolledCount: 980,
        videoUrl: 'https://example.com/video2',
      ),
      Course(
        id: 'c-003',
        title: 'SQL Temelleri',
        description: 'SELECT, JOIN, indeks mantığı, normalizasyon ve pratik örnekler.',
        department: 'Bilgisayar Mühendisliği',
        duration: '3 saat',
        level: 'Başlangıç',
        instructor: 'M. Demir',
        category: 'Yazılım',
        rating: 4.2,
        totalRatings: 87,
        enrolledCount: 1540,
      ),
      Course(
        id: 'c-004',
        title: 'Staj Başvuru Rehberi',
        description: 'CV, mülakat, portföy ve başvuru stratejileri.',
        department: 'Bilgisayar Mühendisliği',
        duration: '2 saat',
        level: 'Herkes',
        instructor: 'Kariyer Ofisi',
        category: 'Kariyer',
        rating: 4.1,
        totalRatings: 54,
        enrolledCount: 720,
      ),
      Course(
        id: 'c-005',
        title: 'Flutter ile Mobil UI',
        description: 'Widget mantığı, layout, state, komponentleşme ve best practices.',
        department: 'Bilgisayar Mühendisliği',
        duration: '5 saat',
        level: 'Orta',
        instructor: 'Eng. C. Aslan',
        category: 'Yazılım',
        rating: 4.5,
        totalRatings: 199,
        enrolledCount: 610,
      ),
      Course(
        id: 'c-006',
        title: 'Veri Bilimine Giriş',
        description: 'Temel istatistik, veri hazırlama, basit modelleme.',
        department: 'Bilgisayar Mühendisliği',
        duration: '4 saat',
        level: 'Başlangıç',
        instructor: 'Dr. D. Şahin',
        category: 'Veri Bilimi',
        rating: 4.0,
        totalRatings: 73,
        enrolledCount: 430,
      ),
    ];
  }
}
