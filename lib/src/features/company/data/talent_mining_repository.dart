import '../../../core/supabase/supabase_service.dart';
import '../domain/talent_models.dart';

class TalentMiningRepository {
  const TalentMiningRepository();

  Future<List<TalentCandidate>> listTalentPool({
    required String companyId,
    String? department,
    required int minScore,
    required int maxScore,
    List<String>? badges,
    int limit = 50,
    int offset = 0,
  }) async {
    final raw = await SupabaseService.client.rpc(
      'company_list_talent_pool',
      params: {
        'p_company_id': companyId,
        'p_department': department,
        'p_min_score': minScore,
        'p_max_score': maxScore,
        'p_badges': badges,
        'p_limit': limit,
        'p_offset': offset,
      },
    );

    final list = (raw is List) ? raw : const <dynamic>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(TalentCandidate.fromMap)
        .where((e) => e.userId.isNotEmpty)
        .toList(growable: false);
  }
}
