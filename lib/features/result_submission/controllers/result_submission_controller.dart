// lib/features/result_submission/controllers/result_submission_controller.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../polling_unit/repositories/polling_unit_repository.dart';
import '../../polling_unit/services/polling_unit_remote_service.dart';
import '../models/location_snapshot.dart';
import '../models/result_figures.dart';
import '../models/evidence_metadata.dart';
import '../models/submission_state.dart';
import '../models/result_submission_payload.dart';
import '../services/device_location_service.dart';
import '../services/evidence_composer_service.dart';
import '../services/local_draft_storage_service.dart';

/// Controller coordinating the 5-step Polling Unit evidence capture and result submission workflow (Section 37).
class ResultSubmissionController extends ChangeNotifier {
  ResultSubmissionController({
    required this.pollingUnitId,
    this.electionId = 'ELEC-2026-PRESIDENTIAL',
    DeviceLocationService? locationService,
    EvidenceComposerService? composerService,
    LocalDraftStorageService? draftStorage,
    PollingUnitRemoteService? remoteService,
    PollingUnitRepository? repository,
  })  : _locationService = locationService ?? DeviceLocationService(),
        _composerService = composerService ?? EvidenceComposerService(),
        _draftStorage = draftStorage ?? LocalDraftStorageService(),
        _remoteService = remoteService ?? PollingUnitRemoteService(),
        _testRepository = repository;

  final String pollingUnitId;
  String electionId;

  final DeviceLocationService _locationService;
  final EvidenceComposerService _composerService;
  final LocalDraftStorageService _draftStorage;
  final PollingUnitRemoteService _remoteService;
  final PollingUnitRepository? _testRepository;

  late ResultSubmissionDraft _draft;
  bool _isInitialized = false;
  bool _isProcessing = false;
  String? _processingMessage;
  String? _configurationError;
  int _currentStep = 1; // 1: Figures, 2: Photo, 3: Video, 4: Location, 5: Review

  // ─── Getters ─────────────────────────────────────────────────────────────
  ResultSubmissionDraft get draft => _draft;
  bool get isInitialized => _isInitialized;
  bool get isProcessing => _isProcessing;
  String? get processingMessage => _processingMessage;
  String? get configurationError => _configurationError;
  int get currentStep => _currentStep;

  ResultFigures get figures => _draft.figures;
  EvidenceMetadata? get resultPhoto => _draft.resultPhoto;
  EvidenceMetadata? get declarationVideo => _draft.declarationVideo;
  LocationSnapshot? get location => _draft.location;
  SubmissionLifecycleState get state => _draft.state;

  // ─── Initialization & Recovery (Section 25) ──────────────────────────────

  Future<void> initialize() async {
    final existingDraft = await _draftStorage.loadDraft(pollingUnitId);
    if (_testRepository == null) {
      try {
        final openElection = await _remoteService.getOpenElectionCode();
        if (openElection == null) {
          _configurationError = 'There is no open election. Contact your administrator before submitting a result.';
        } else {
          electionId = openElection;
          _configurationError = null;
        }
      } catch (_) {
        _configurationError = 'Unable to load the active election. Check your connection and try again.';
      }
    }
    if (existingDraft != null) {
      _draft = existingDraft;
      _draft.electionId = electionId;
    } else {
      ResultFigures figures = const ResultFigures();
      if (_testRepository == null) {
        try { figures = await _remoteService.getReturnedFigures() ?? figures; } catch (_) {}
      }
      _draft = ResultSubmissionDraft(
        pollingUnitId: pollingUnitId,
        electionId: electionId,
        figures: figures,
      );
    }
    _isInitialized = true;
    notifyListeners();
  }

  void setStep(int step) {
    if (step >= 1 && step <= 5) {
      _currentStep = step;
      notifyListeners();
    }
  }

  // ─── Step 1: Figures ──────────────────────────────────────────────────────

  Future<void> saveFigures(ResultFigures newFigures) async {
    _draft.figures = newFigures;
    _draft.deviceTimestamp = DateTime.now();
    await _draftStorage.saveDraft(_draft);
    notifyListeners();
  }

  // ─── Step 2: Result Form Camera Capture (Section 12–17) ───────────────────

  Future<void> processAndAttachResultPhoto(String capturedPath) async {
    _isProcessing = true;
    _processingMessage = 'Acquiring GPS and composing evidence...';
    notifyListeners();

    try {
      // 1. Capture real device location at this exact moment (Section 26)
      LocationSnapshot loc;
      try {
        loc = await _locationService.getCurrentLocation();
      } catch (_) {
        rethrow;
      }
      if (loc.isMock || !loc.isAccurate) throw StateError('A real GPS fix with accuracy of 25 metres or better is required.');

      final timestamp = DateTime.now();

      // 2. Compose top-right metadata overlay onto image (Section 12–15)
      final metadata = await _composerService.composeResultSheetEvidence(
        sourceImagePath: capturedPath,
        pollingUnitId: pollingUnitId,
        location: loc,
        deviceTimestamp: timestamp,
      );

      _draft.resultPhoto = metadata;
      _draft.location ??= loc; // seed initial location
      _draft.deviceTimestamp = timestamp;

      await _draftStorage.saveDraft(_draft);
    } finally {
      _isProcessing = false;
      _processingMessage = null;
      notifyListeners();
    }
  }

  // ─── Step 3: Declaration Video (Section 18–20) ────────────────────────────

  Future<void> attachDeclarationVideo(String videoPath, int durationSeconds) async {
    _isProcessing = true;
    _processingMessage = 'Securing declaration video metadata...';
    notifyListeners();

    try {
      int fileSize = 0;
      if (!kIsWeb) {
        final file = File(videoPath);
        fileSize = await file.exists() ? await file.length() : 0;
      } else {
        fileSize = 2048;
      }

      LocationSnapshot loc;
      try {
        loc = await _locationService.getCurrentLocation();
      } catch (_) {
        loc = _draft.location ?? (throw StateError('A real GPS fix is required to capture evidence.'));
      }
      if (loc.isMock || !loc.isAccurate) throw StateError('A real GPS fix with accuracy of 25 metres or better is required.');

      final metadata = EvidenceMetadata(
        localPath: videoPath,
        mimeType: 'video/mp4',
        fileSize: fileSize,
        location: loc,
        capturedAt: DateTime.now(),
        durationSeconds: durationSeconds,
      );

      _draft.declarationVideo = metadata;
      await _draftStorage.saveDraft(_draft);
    } finally {
      _isProcessing = false;
      _processingMessage = null;
      notifyListeners();
    }
  }

  // ─── Step 4: Location & Timestamp Verification (Section 26 & 27) ──────────

  Future<LocationSnapshot> refreshCurrentLocation() async {
    _isProcessing = true;
    _processingMessage = 'Acquiring high-accuracy GPS coordinates...';
    notifyListeners();

    try {
      final loc = await _locationService.getCurrentLocation();
      if (loc.isMock || !loc.isAccurate) throw StateError('A real GPS fix with accuracy of 25 metres or better is required.');
      _draft.location = loc;
      _draft.deviceTimestamp = DateTime.now();
      await _draftStorage.saveDraft(_draft);
      return loc;
    } finally {
      _isProcessing = false;
      _processingMessage = null;
      notifyListeners();
    }
  }

  // ─── Step 5: Final Submission (Section 22–24) ─────────────────────────────

  Future<bool> submitFinalResult() async {
    if (_configurationError != null && _testRepository == null) {
      _draft.uploadError = _configurationError;
      notifyListeners();
      return false;
    }
    if (!_draft.isComplete) {
      _draft.uploadError = 'Please complete all required evidence steps.';
      notifyListeners();
      return false;
    }

    _draft.state = SubmissionLifecycleState.uploading;
    _draft.uploadError = null;
    _isProcessing = true;
    _processingMessage = 'Uploading evidence directly to secure storage...';
    notifyListeners();

    try {
      _draft.state = SubmissionLifecycleState.submitting;
      _processingMessage = 'Submitting result and verifying stored evidence...';
      notifyListeners();

      // Build transmission payload (Section 31)
      final payload = ResultSubmissionPayload(
        electionId: electionId,
        pollingUnitId: pollingUnitId,
        figures: _draft.figures,
        resultPhoto: _draft.resultPhoto!,
        declarationVideo: _draft.declarationVideo!,
        location: _draft.location!,
        deviceTimestamp: _draft.deviceTimestamp,
      );
      assert(payload.pollingUnitId.isNotEmpty);

      if (_testRepository != null) {
        throw StateError('A live backend is required to submit official results.');
      }
      final receipt = await _remoteService.submitResult(
        electionId: payload.electionId,
        figures: payload.figures,
        resultPhoto: payload.resultPhoto,
        declarationVideo: payload.declarationVideo,
        location: payload.location,
      );
      _draft.serverConfirmationCode = receipt.confirmationCode;
      _draft.state = SubmissionLifecycleState.submitted;

      // Clear local draft upon confirmed receipt (Section 22)
      await _draftStorage.clearDraft(pollingUnitId);

      _isProcessing = false;
      _processingMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _draft.state = SubmissionLifecycleState.uploadFailed;
      _draft.uploadError =
          'Submission could not be completed. Your result has been saved securely on this device.';
      await _draftStorage.saveDraft(_draft);
      _isProcessing = false;
      _processingMessage = null;
      notifyListeners();
      return false;
    }
  }
}
