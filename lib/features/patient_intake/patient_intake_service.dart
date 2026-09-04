import 'package:apexo/services/login.dart';
import 'package:pocketbase/pocketbase.dart';

import 'patient_intake_submission.dart';

class PatientIntakeSession {
  const PatientIntakeSession({required this.id, required this.expiresAt});

  final String id;
  final DateTime? expiresAt;
}

class PatientIntakeService {
  const PatientIntakeService();

  Future<PatientIntakeSession> createSession({String deviceLabel = ''}) async {
    final pb = login.pb;
    if (pb == null || !pb.authStore.isValid) {
      throw StateError('Apexo must be online and authenticated.');
    }
    final response = Map<String, dynamic>.from(await pb.send(
      '/api/apexo/intake/sessions',
      method: 'POST',
      body: {'device_label': deviceLabel},
    ) as Map);
    return PatientIntakeSession(
      id: response['session_id']?.toString() ?? '',
      expiresAt:
          DateTime.tryParse(response['expires_at']?.toString() ?? '')?.toUtc(),
    );
  }

  Future<List<PatientIntakeSubmission>> pendingSubmissions() async {
    final pb = login.pb;
    if (pb == null || !pb.authStore.isValid) {
      throw StateError('Apexo must be online and authenticated.');
    }
    final response = Map<String, dynamic>.from(
      await pb.send('/api/apexo/intake/submissions') as Map,
    );
    return (response['items'] as List<dynamic>? ?? const [])
        .map((item) => PatientIntakeSubmission.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList(growable: false);
  }

  Future<Uri> protectedPdfUrl(PatientIntakeSubmission submission) async {
    final pb = login.pb;
    if (pb == null || !pb.authStore.isValid) {
      throw StateError('Apexo must be online and authenticated.');
    }
    if (!submission.hasPdf) {
      throw StateError('This intake submission has no generated PDF.');
    }
    final token = await pb.files.getToken();
    final record = RecordModel({
      'id': submission.id,
      'collectionName': 'intake_submissions',
    });
    return pb.files.getURL(
      record,
      submission.pdfFile,
      token: token,
    );
  }

  Future<void> markImported({
    required String submissionId,
    required String patientId,
  }) async {
    final pb = login.pb;
    if (pb == null || !pb.authStore.isValid) {
      throw StateError('Apexo must be online and authenticated.');
    }
    await pb.send(
      '/api/apexo/intake/submissions/$submissionId/imported',
      method: 'POST',
      body: {'patient_id': patientId},
    );
  }

  Future<void> reject(String submissionId) async {
    final pb = login.pb;
    if (pb == null || !pb.authStore.isValid) {
      throw StateError('Apexo must be online and authenticated.');
    }
    await pb.send(
      '/api/apexo/intake/submissions/$submissionId/rejected',
      method: 'POST',
    );
  }
}
