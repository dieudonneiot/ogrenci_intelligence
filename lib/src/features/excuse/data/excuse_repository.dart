import '../../../core/supabase/supabase_service.dart';
import '../domain/excuse_models.dart';

class ExcuseRepository {
  const ExcuseRepository();

  Future<List<AcceptedInternshipOption>> listMyAcceptedInternships({
    required String userId,
  }) async {
    final rows = await SupabaseService.client
        .from('internship_applications')
        .select('id, status, internships(title, company_name)')
        .eq('user_id', userId)
        .eq('status', 'accepted')
        .order('applied_at', ascending: false);

    return (rows as List)
        .map((e) {
          final m = e as Map<String, dynamic>;
          final internship =
              (m['internships'] as Map?)?.cast<String, dynamic>() ?? const {};
          return AcceptedInternshipOption(
            applicationId: (m['id'] ?? '').toString(),
            internshipTitle: (internship['title'] ?? '').toString(),
            companyName: (internship['company_name'] ?? '').toString(),
          );
        })
        .where((e) => e.applicationId.isNotEmpty)
        .toList(growable: false);
  }

  Future<String> createExcuseRequest({
    required String internshipApplicationId,
    required String reasonType,
    required String details,
  }) async {
    final id = await SupabaseService.client.rpc(
      'create_excuse_request',
      params: {
        'p_internship_application_id': internshipApplicationId,
        'p_reason_type': reasonType,
        'p_details': details,
      },
    );
    return (id ?? '').toString();
  }

  Future<List<MyExcuseRequest>> listMyRequests({required String userId}) async {
    final rows = await SupabaseService.client
        .from('excuse_requests')
        .select(
          'id, reason_type, details, status, created_at, reviewed_at, reviewer_note',
        )
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50);

    return (rows as List)
        .map((e) => MyExcuseRequest.fromMap(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<CompanyExcuseRequest>> listCompanyRequests({
    required String companyId,
    String? status,
    int limit = 200,
  }) async {
    final raw = await SupabaseService.client.rpc(
      'list_company_excuse_requests',
      params: {'p_company_id': companyId, 'p_status': status, 'p_limit': limit},
    );

    final list = (raw is List) ? raw : const <dynamic>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(CompanyExcuseRequest.fromMap)
        .toList(growable: false);
  }

  Future<void> reviewRequest({
    required String requestId,
    required String newStatus, // approved / rejected
    String? reviewerNote,
  }) async {
    await SupabaseService.client.rpc(
      'review_excuse_request',
      params: {
        'p_request_id': requestId,
        'p_new_status': newStatus,
        'p_reviewer_note': reviewerNote,
      },
    );
  }
}
