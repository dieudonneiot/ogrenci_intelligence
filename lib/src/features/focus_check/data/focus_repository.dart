import '../../../core/supabase/supabase_service.dart';
import '../domain/focus_models.dart';

class FocusRepository {
  const FocusRepository();

  Future<List<AcceptedInternshipApplication>> listMyAcceptedInternships({
    required String userId,
    int limit = 20,
  }) async {
    final rows = await SupabaseService.client
        .from('internship_applications')
        .select('id,internship_id,status, internship:internships(id,title,company_id,company_name)')
        .eq('user_id', userId)
        .eq('status', 'accepted')
        .order('applied_at', ascending: false)
        .limit(limit);

    return (rows as List)
        .map((e) => AcceptedInternshipApplication.fromMap(e as Map<String, dynamic>))
        .where((e) => e.applicationId.isNotEmpty && e.companyId.isNotEmpty)
        .toList(growable: false);
  }

  Future<FocusCheckSession> startFocusCheck({
    required String internshipApplicationId,
  }) async {
    final result = await SupabaseService.client.rpc(
      'start_focus_check',
      params: {'p_internship_application_id': internshipApplicationId},
    );

    // Supabase Dart returns either a map or list depending on RPC return.
    if (result is List && result.isNotEmpty) {
      return FocusCheckSession.fromMap(result.first as Map<String, dynamic>);
    }
    if (result is Map<String, dynamic>) {
      return FocusCheckSession.fromMap(result);
    }
    throw Exception('Unexpected start_focus_check response');
  }

  Future<FocusCheckSession> fetchFocusCheckById({required String focusCheckId}) async {
    final row = await SupabaseService.client
        .from('focus_checks')
        .select('id, question, expires_at')
        .eq('id', focusCheckId)
        .maybeSingle();

    if (row == null) {
      throw Exception('Focus check not found');
    }
    return FocusCheckSession.fromMap(row);
  }

  Future<void> markSentFocusCheckStarted({required String focusCheckId}) async {
    try {
      await SupabaseService.client.rpc(
        'start_sent_focus_check',
        params: {'p_focus_check_id': focusCheckId},
      );
    } catch (_) {
      // best effort
    }
  }

  Future<void> submitFocusAnswer({
    required String focusCheckId,
    required String answer,
  }) async {
    await SupabaseService.client.rpc(
      'submit_focus_answer',
      params: {
        'p_focus_check_id': focusCheckId,
        'p_answer': answer,
      },
    );
  }
}
