import '../../../core/supabase/supabase_service.dart';
import '../domain/case_models.dart';

class CaseRepository {
  const CaseRepository();

  Future<List<CaseScenario>> listActiveScenarios({int limit = 30}) async {
    final rows = await SupabaseService.client
        .from('case_scenarios')
        .select('id,prompt,left_text,right_text')
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(limit);

    return (rows as List)
        .map((e) => CaseScenario.fromMap(e as Map<String, dynamic>))
        .where((s) => s.id.isNotEmpty && s.prompt.trim().isNotEmpty)
        .toList(growable: false);
  }

  Future<void> submitChoice({
    required String scenarioId,
    required CaseChoice choice,
  }) async {
    final c = choice == CaseChoice.left ? 'left' : 'right';
    await SupabaseService.client.rpc(
      'submit_case_response',
      params: {
        'p_scenario_id': scenarioId,
        'p_choice': c,
      },
    );
  }
}

