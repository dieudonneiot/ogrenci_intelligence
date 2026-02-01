import '../../../core/supabase/supabase_service.dart';
import '../domain/internship_models.dart';

class InternshipsRepository {
  const InternshipsRepository();

  Future<String?> fetchMyDepartment({required String userId}) async {
    final row = await SupabaseService.client
        .from('profiles')
        .select('department')
        .eq('id', userId)
        .maybeSingle();

    final dept = (row?['department'] as String?)?.trim();
    return (dept == null || dept.isEmpty) ? null : dept;
  }

  Future<List<Internship>> fetchInternships({
    required String userId,
    String? department,
    required String search,
    required String locationFilter,
    required String durationFilter,
    int limit = 80,
  }) async {
    // Reserved for future user-scoped queries (keeps API parity with React).
    final _ = userId;
    var q = SupabaseService.client
        .from('internships')
        .select(
          'id,title,description,department,company_name,location,duration_months,is_remote,deadline,is_paid,monthly_stipend,provides_certificate,possibility_of_employment,requirements,benefits,created_at,is_active',
        )
        .eq('is_active', true);

    final dept = department?.trim();
    if (dept != null && dept.isNotEmpty) {
      q = q.eq('department', dept);
    }

    final s = search.trim();
    if (s.isNotEmpty) {
      final esc = s.replaceAll('%', '').replaceAll(',', ' ');
      // title/company/description ilike (match React)
      q = q.or(
        'title.ilike.%$esc%,company_name.ilike.%$esc%,description.ilike.%$esc%',
      );
    }

    if (locationFilter == 'remote') {
      q = q.eq('is_remote', true);
    } else if (locationFilter != 'all') {
      q = q.eq('location', locationFilter);
    }

    if (durationFilter != 'all') {
      // React: 1-3, 3-6, 6-12, 12+
      if (durationFilter == '12+') {
        q = q.gte('duration_months', 12);
      } else if (durationFilter == '6+') {
        q = q.gte('duration_months', 6);
      } else {
        final parts = durationFilter.split('-');
        final min = int.tryParse(parts.first.trim()) ?? 0;
        final max = int.tryParse(parts.last.trim()) ?? 999;
        q = q.gte('duration_months', min).lte('duration_months', max);
      }
    }

    final rows = await q.order('created_at', ascending: false).limit(limit);

    return (rows as List)
        .map((e) => Internship.fromMap(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<Set<String>> fetchMyFavoriteInternshipIds({required String userId}) async {
    final rows = await SupabaseService.client
        .from('favorites')
        .select('internship_id')
        .eq('user_id', userId)
        .eq('type', 'internship');

    return (rows as List)
        .map((e) => (e as Map<String, dynamic>)['internship_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Future<Map<String, String>> fetchMyApplicationStatusByInternshipId({
    required String userId,
  }) async {
    final rows = await SupabaseService.client
        .from('internship_applications')
        .select('internship_id, status')
        .eq('user_id', userId);

    final map = <String, String>{};
    for (final r in (rows as List)) {
      final m = r as Map<String, dynamic>;
      final id = (m['internship_id'] ?? '').toString();
      if (id.isEmpty) continue;
      map[id] = (m['status'] ?? 'pending').toString();
    }
    return map;
  }

  Future<void> toggleFavorite({
    required String userId,
    required String internshipId,
  }) async {
    final existing = await SupabaseService.client
        .from('favorites')
        .select('id')
        .eq('user_id', userId)
        .eq('type', 'internship')
        .eq('internship_id', internshipId)
        .maybeSingle();

    if (existing != null) {
      await SupabaseService.client
          .from('favorites')
          .delete()
          .eq('id', existing['id']);
      return;
    }

    await SupabaseService.client.from('favorites').insert({
      'user_id': userId,
      'type': 'internship',
      'internship_id': internshipId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<Internship> fetchInternshipById({required String internshipId}) async {
    final row = await SupabaseService.client
        .from('internships')
        .select(
          'id,title,description,department,company_name,location,duration_months,is_remote,deadline,is_paid,monthly_stipend,provides_certificate,possibility_of_employment,requirements,benefits,created_at,is_active',
        )
        .eq('id', internshipId)
        .maybeSingle();

    if (row == null) {
      throw Exception('Internship not found: $internshipId');
    }
    return Internship.fromMap(row);
  }

  Future<InternshipApplication?> fetchMyApplication({
    required String userId,
    required String internshipId,
  }) async {
    final row = await SupabaseService.client
        .from('internship_applications')
        .select('id, user_id, internship_id, status, applied_at, motivation_letter')
        .eq('user_id', userId)
        .eq('internship_id', internshipId)
        .maybeSingle();

    if (row == null) return null;
    return InternshipApplication.fromMap(row);
  }

  Future<bool> isFavorite({
    required String userId,
    required String internshipId,
  }) async {
    final row = await SupabaseService.client
        .from('favorites')
        .select('id')
        .eq('user_id', userId)
        .eq('type', 'internship')
        .eq('internship_id', internshipId)
        .maybeSingle();
    return row != null;
  }

  Future<void> apply({
    required String userId,
    required String internshipId,
    required String motivation,
  }) async {
    final text = motivation.trim();
    if (text.length < 100) {
      throw Exception('Motivasyon metni en az 100 karakter olmalı.');
    }

    // prevent duplicates
    final existing = await SupabaseService.client
        .from('internship_applications')
        .select('id')
        .eq('user_id', userId)
        .eq('internship_id', internshipId)
        .maybeSingle();

    if (existing != null) {
      throw Exception('Bu staja zaten başvurdun.');
    }

    await SupabaseService.client.from('internship_applications').insert({
      'user_id': userId,
      'internship_id': internshipId,
      'motivation_letter': text,
      'status': 'pending',
      'applied_at': DateTime.now().toIso8601String(),
    });
  }
}
