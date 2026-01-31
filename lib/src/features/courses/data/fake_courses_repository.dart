import 'dart:math';
import '../domain/course.dart';
import 'courses_repository.dart';

class FakeCoursesRepository implements CoursesRepository {
  FakeCoursesRepository() {
    _courses = _seed();
  }

  late final List<Course> _courses;

  @override
  Future<List<Course>> fetchCourses({String? department}) async {
    // simulate latency
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (department == null || department.trim().isEmpty) return _courses;
    return _courses.where((c) => c.department == department).toList();
  }

  @override
  Future<Course?> fetchCourseById(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    try {
      return _courses.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  List<Course> _seed() {
    final rng = Random(42);
    double r() => (rng.nextInt(17) + 30) / 10.0; // 3.0..4.6

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
