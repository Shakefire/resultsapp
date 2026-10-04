import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:camera/camera.dart';

import '../../../core/services/vercel_api_client.dart';
import '../../result_submission/models/evidence_metadata.dart';
import '../../result_submission/models/location_snapshot.dart';
import '../../result_submission/models/result_figures.dart';

class RemoteSubmissionReceipt {
  const RemoteSubmissionReceipt({required this.submissionId, required this.confirmationCode, required this.revision});
  final String submissionId;
  final String confirmationCode;
  final int revision;
}

class PollingUnitRemoteService {
  PollingUnitRemoteService({VercelApiClient? api}) : _api = api ?? VercelApiClient.instance;
  final VercelApiClient _api;

  Future<Map<String, dynamic>> getMyRecords() => _api.get('/api/v1/workflow/my-records');

  Future<String?> getOpenElectionCode() async {
    final response = await _api.get('/api/v1/elections/open');
    final election = response['election'];
    return election is Map<String, dynamic> ? election['election_code'] as String? : null;
  }

  Future<ResultFigures?> getReturnedFigures() async {
    final response = await getMyRecords();
    final submissions = response['submissions'] as List<dynamic>? ?? const [];
    if (submissions.isEmpty) return null;
    final latest = Map<String, dynamic>.from(submissions.first as Map);
    if (latest['status'] != 'returned') return null;
    return ResultFigures.fromJson(Map<String, dynamic>.from(latest['figures'] as Map? ?? const {}));
  }

  Future<RemoteSubmissionReceipt> submitResult({
    required String electionId,
    required ResultFigures figures,
    required EvidenceMetadata resultPhoto,
    required EvidenceMetadata declarationVideo,
    required LocationSnapshot location,
  }) async {
    final photoKey = await _uploadEvidence(resultPhoto, 'result_photo', electionId);
    final videoKey = await _uploadEvidence(declarationVideo, 'declaration_video', electionId);
    final response = await _api.post('/api/v1/workflow/submissions', {
      'electionId': electionId,
      'figures': figures.toJson(),
      'location': location.toJson(),
      'evidence': [
        {'objectKey': photoKey, 'purpose': 'result_photo', 'contentType': resultPhoto.mimeType, 'capturedAt': resultPhoto.capturedAt.toIso8601String(), 'fileName': resultPhoto.localPath.split(RegExp(r'[\\/]')).last},
        {'objectKey': videoKey, 'purpose': 'declaration_video', 'contentType': declarationVideo.mimeType, 'capturedAt': declarationVideo.capturedAt.toIso8601String(), 'fileName': declarationVideo.localPath.split(RegExp(r'[\\/]')).last},
      ],
    });
    return RemoteSubmissionReceipt(
      submissionId: response['submissionId'] as String,
      confirmationCode: response['confirmationCode'] as String,
      revision: response['revision'] as int,
    );
  }

  Future<String> uploadVoterRegister(String path, {List<int>? bytes, String? fileName}) async {
    final int size;
    final String resolvedFileName;

    if (kIsWeb || bytes != null) {
      if (bytes == null) {
        throw const VercelApiException('Voter register file bytes are required on the web.');
      }
      size = bytes.length;
      resolvedFileName = fileName ?? 'voter_register.pdf';
    } else {
      final file = File(path);
      size = await file.length();
      resolvedFileName = fileName ?? path.split(RegExp(r'[\\/]')).last;
    }

    if (size <= 0 || size > 25 * 1024 * 1024) throw const VercelApiException('The voter register PDF must be under 25 MB.');
    final authorization = await _api.post('/api/v1/evidence/upload-url', {'purpose': 'voter_register'});
    final key = authorization['objectKey'] as String;
    await _api.putFile(authorization['uploadUrl'] as String, path,
      contentType: authorization['contentType'] as String, contentLength: size, bytes: bytes);
    final response = await _api.post('/api/v1/evidence/voter-register', {
      'objectKey': key,
      'fileName': resolvedFileName,
      'fileSizeBytes': size,
    });
    return response['evidenceId'] as String;
  }

  Future<String> getDownloadUrl(String objectKey) async {
    final response = await _api.get('/api/v1/evidence/download-url?objectKey=${Uri.encodeQueryComponent(objectKey)}');
    return response['url'] as String;
  }

  Future<String> _uploadEvidence(EvidenceMetadata metadata, String purpose, String electionId) async {
    final int size;
    List<int>? fileBytes;
    if (kIsWeb) {
      final xfile = XFile(metadata.localPath);
      fileBytes = await xfile.readAsBytes();
      size = fileBytes.length;
    } else {
      final file = File(metadata.localPath);
      if (!await file.exists()) {
        try {
          final xfile = XFile(metadata.localPath);
          fileBytes = await xfile.readAsBytes();
          size = fileBytes.length;
        } catch (_) {
          throw const VercelApiException('A required evidence file is no longer available on this device.');
        }
      } else {
        size = await file.length();
      }
    }
    final maximumBytes = purpose == 'result_photo' ? 15 * 1024 * 1024 : 150 * 1024 * 1024;
    if (size <= 0 || size > maximumBytes) {
      throw VercelApiException('The $purpose file must be between 1 byte and ${maximumBytes ~/ (1024 * 1024)} MB.');
    }
    final authorization = await _api.post('/api/v1/evidence/upload-url', {
      'purpose': purpose,
      'electionId': electionId,
    });
    final contentType = authorization['contentType'] as String;
    if (metadata.mimeType != contentType) throw const VercelApiException('Evidence file type does not match the required format.');
    await _api.putFile(authorization['uploadUrl'] as String, metadata.localPath,
      contentType: contentType, contentLength: size, bytes: fileBytes);
    return authorization['objectKey'] as String;
  }
}
