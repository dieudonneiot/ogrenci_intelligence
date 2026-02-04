import 'dart:math';

import 'package:file_selector/file_selector.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_service.dart';
import '../../focus_check/domain/focus_models.dart';
import '../domain/evidence_models.dart';

class EvidenceRepository {
  const EvidenceRepository();

  Future<List<EvidenceItem>> listMyEvidence({required String userId, int limit = 50}) async {
    final rows = await SupabaseService.client
        .from('evidence_items')
        .select(
          'id,user_id,company_id,internship_application_id,title,description,file_path,mime_type,size_bytes,status,created_at,updated_at',
        )
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);

    return (rows as List)
        .map((e) => EvidenceItem.fromMap(e as Map<String, dynamic>))
        .where((e) => e.id.isNotEmpty && e.filePath.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<EvidenceItem>> listCompanyPendingEvidence({required String companyId, int limit = 80}) async {
    final rows = await SupabaseService.client
        .from('evidence_items')
        .select(
          'id,user_id,company_id,internship_application_id,title,description,file_path,mime_type,size_bytes,status,created_at,updated_at',
        )
        .eq('company_id', companyId)
        .eq('status', 'pending')
        .order('created_at', ascending: false)
        .limit(limit);

    return (rows as List)
        .map((e) => EvidenceItem.fromMap(e as Map<String, dynamic>))
        .where((e) => e.id.isNotEmpty && e.filePath.isNotEmpty)
        .toList(growable: false);
  }

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

  Future<EvidenceItem> pickFileAndUpload({
    required String userId,
    required EvidenceUploadDraft draft,
  }) async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Files',
          extensions: <String>[
            'pdf',
            'png',
            'jpg',
            'jpeg',
            'doc',
            'docx',
            'ppt',
            'pptx',
            'zip',
          ],
        ),
      ],
    );

    if (file == null) {
      throw Exception('No file selected');
    }

    final bytes = await file.readAsBytes();
    final safeName = _safeName(file.name);
    final stamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    final rand = Random().nextInt(1 << 20);
    final path = '$userId/${stamp}_${rand}_$safeName';

    await SupabaseService.client.storage.from('evidence').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: false,
            contentType: _contentTypeFromName(file.name),
          ),
        );

    final evidenceId = await SupabaseService.client.rpc(
      'create_evidence_item',
      params: {
        'p_internship_application_id': draft.internshipApplicationId,
        'p_title': draft.title,
        'p_description': draft.description,
        'p_file_path': path,
        'p_mime_type': _contentTypeFromName(file.name),
        'p_size_bytes': bytes.length,
      },
    );

    final id = evidenceId?.toString() ?? '';
    if (id.isEmpty) throw Exception('Failed to create evidence row');

    final row = await SupabaseService.client
        .from('evidence_items')
        .select(
          'id,user_id,company_id,internship_application_id,title,description,file_path,mime_type,size_bytes,status,created_at,updated_at',
        )
        .eq('id', id)
        .maybeSingle();

    if (row == null) {
      return EvidenceItem.fromMap({
        'id': id,
        'user_id': userId,
        'company_id': '',
        'internship_application_id': draft.internshipApplicationId,
        'file_path': path,
        'status': 'pending',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    }
    return EvidenceItem.fromMap(row);
  }

  Future<String> createSignedUrl({required String filePath, int seconds = 600}) async {
    final url = await SupabaseService.client.storage.from('evidence').createSignedUrl(filePath, seconds);
    return url;
  }

  Future<void> reviewEvidence({
    required String evidenceId,
    required String status, // approved|rejected
    String? reason,
  }) async {
    await SupabaseService.client.rpc(
      'review_evidence',
      params: {
        'p_evidence_id': evidenceId,
        'p_status': status,
        'p_reason': reason,
      },
    );
  }

  static String _safeName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'file';
    final cleaned = trimmed.replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_');
    return cleaned.isEmpty ? 'file' : cleaned;
  }

  static String? _contentTypeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.zip')) return 'application/zip';
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lower.endsWith('.ppt')) return 'application/vnd.ms-powerpoint';
    if (lower.endsWith('.pptx')) {
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    }
    return null;
  }
}
