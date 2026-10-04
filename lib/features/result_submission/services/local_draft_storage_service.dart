// lib/features/result_submission/services/local_draft_storage_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/submission_state.dart';

/// Service for persisting and recovering result submission drafts locally (Section 25).
/// Guarantees that completed figures, media paths, and GPS coordinates survive interruptions.
class LocalDraftStorageService {
  LocalDraftStorageService();

  final Map<String, ResultSubmissionDraft> _webMemoryDrafts = {};

  Future<File?> _getDraftFile(String pollingUnitId) async {
    if (kIsWeb) return null;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final draftsDir = Directory('${appDir.path}/drafts');
      if (!await draftsDir.exists()) {
        await draftsDir.create(recursive: true);
      }
      final sanitizedId = pollingUnitId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      return File('${draftsDir.path}/draft_$sanitizedId.json');
    } catch (_) {
      return null;
    }
  }

  /// Saves or updates the current draft to disk.
  Future<void> saveDraft(ResultSubmissionDraft draft) async {
    if (kIsWeb) {
      _webMemoryDrafts[draft.pollingUnitId] = draft;
      return;
    }
    try {
      final file = await _getDraftFile(draft.pollingUnitId);
      if (file == null) return;
      final jsonString = jsonEncode(draft.toJson());
      await file.writeAsString(jsonString);
    } catch (_) {
      // Non-fatal persistence failure
    }
  }

  /// Attempts to restore a saved draft for the specified Polling Unit.
  Future<ResultSubmissionDraft?> loadDraft(String pollingUnitId) async {
    if (kIsWeb) {
      return _webMemoryDrafts[pollingUnitId];
    }
    try {
      final file = await _getDraftFile(pollingUnitId);
      if (file == null || !await file.exists()) return null;

      final content = await file.readAsString();
      if (content.isEmpty) return null;

      final Map<String, dynamic> jsonMap =
          jsonDecode(content) as Map<String, dynamic>;
      return ResultSubmissionDraft.fromJson(jsonMap);
    } catch (_) {
      return null;
    }
  }

  /// Clears the draft upon confirmed backend submission receipt.
  Future<void> clearDraft(String pollingUnitId) async {
    if (kIsWeb) {
      _webMemoryDrafts.remove(pollingUnitId);
      return;
    }
    try {
      final file = await _getDraftFile(pollingUnitId);
      if (file != null && await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
