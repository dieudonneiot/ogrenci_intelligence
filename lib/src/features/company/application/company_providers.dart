import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_service.dart';
import '../data/company_repository.dart';

final companyRepositoryProvider = Provider<CompanyRepository>((ref) {
  final client = SupabaseService.client;
  return CompanyRepository(client);
});

final companyClientProvider = Provider<SupabaseClient>((ref) {
  return SupabaseService.client;
});

