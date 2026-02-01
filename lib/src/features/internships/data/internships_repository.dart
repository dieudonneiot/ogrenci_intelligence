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

    return (row?['department'] as String?)?.trim();
  }

  Future<List<Internship>> fetchInternships({
    required String department,
    required String search,
    required String selectedLocation,
    required String selectedDuration,
    int limit = 100,
  }) async {
    var q = SupabaseService.client
        .from('internships')
        .select(
          'id,title,description,department,company_name,location,duration_months,is_remote,deadline,is_paid,monthly_stipend,provides_certificate,possibility_of_employment,requirements,benefits,created_at',
        )
        .eq('is_active', true)
        .eq('department', department);

    final s = search.trim();
    if (s.isNotEmpty) {
      // title/company/location ilike
      q = q.or(
        'title.ilike.%$s%,company_name.ilike.%$s%,location.ilike.%$s%',
      );
    }

    if (selectedLocation != 'all') {
      q = q.eq('location', selectedLocation);
    }

    if (selectedDuration != 'all') {
      // React: 1-3, 3-6, 6-12, 12+
      if (selectedDuration == '12+') {
        q = q.gte('duration_months', 12);
      } else {
        final parts = selectedDuration.split('-');
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

  Future<Set<String>> fetchFavoriteInternshipIds({required String userId}) async {
    final rows = await SupabaseService.client
        .from('favorites')
        .select('internship_id')
        .eq('user_id', userId)
        .eq('type', 'internship');

    return (rows as List)
        .map((e) => (e as Map<String, dynamic>)['internship_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Future<Map<String, InternshipApplication>> fetchMyApplicationsByInternshipId({
    required String userId,
  }) async {
    final rows = await SupabaseService.client
        .from('internship_applications')
        .select('id, internship_id, status, applied_at')
        .eq('user_id', userId);

    final apps = (rows as List)
        .map((e) => InternshipApplication.fromMap(e as Map<String, dynamic>))
        .toList(growable: false);

    return {for (final a in apps) a.internshipId: a};
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
    });
  }

  Future<Internship?> fetchInternshipById({required String internshipId}) async {
    final row = await SupabaseService.client
        .from('internships')
        .select(
          'id,title,description,department,company_name,location,duration_months,is_remote,deadline,is_paid,monthly_stipend,provides_certificate,possibility_of_employment,requirements,benefits,created_at',
        )
        .eq('id', internshipId)
        .maybeSingle();

    if (row == null) return null;
    return Internship.fromMap(row);
  }

  Future<InternshipApplication?> fetchMyApplication({
    required String userId,
    required String internshipId,
  }) async {
    final row = await SupabaseService.client
        .from('internship_applications')
        .select('id, internship_id, status, applied_at')
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

  Future<void> applyToInternship({
    required String userId,
    required String internshipId,
    required String motivationLetter,
  }) async {
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
      'motivation_letter': motivationLetter,
      // status defaults to 'pending'
    });
  }
}
