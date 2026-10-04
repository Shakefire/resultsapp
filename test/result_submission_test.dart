// test/result_submission_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_electoral_results_app/features/result_submission/models/location_snapshot.dart';
import 'package:smart_electoral_results_app/features/result_submission/models/result_figures.dart';
import 'package:smart_electoral_results_app/features/result_submission/models/evidence_metadata.dart';
import 'package:smart_electoral_results_app/features/result_submission/models/submission_state.dart';
import 'package:smart_electoral_results_app/features/result_submission/models/result_submission_payload.dart';
import 'package:smart_electoral_results_app/features/result_submission/controllers/result_submission_controller.dart';
import 'package:smart_electoral_results_app/features/polling_unit/repositories/mock_polling_unit_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ─── 1. ResultFigures Calculations & Validation ───────────────────────────
  group('ResultFigures', () {
    test('calculates total party votes and total votes cast correctly', () {
      final figures = ResultFigures(
        registeredVoters: 500,
        accreditedVoters: 250,
        partyVotes: {
          'APC': 100,
          'LP': 80,
          'NNPP': 20,
          'PDP': 40,
        },
        rejectedVotes: 5,
      );

      expect(figures.totalValidVotes, equals(240));
      expect(figures.totalVotesCast, equals(245));
    });

    test('validates when totalVotesCast <= accreditedVoters and accredited <= registered', () {
      final validFigures = ResultFigures(
        registeredVoters: 500,
        accreditedVoters: 300,
        partyVotes: {'APC': 150, 'LP': 100},
        rejectedVotes: 10,
      );

      expect(validFigures.isValid, isTrue);
      expect(validFigures.isAccreditedValid, isTrue);
      expect(validFigures.isVotesCastValid, isTrue);
    });

    test('detects over-voting when totalVotesCast > accreditedVoters', () {
      final invalidFigures = ResultFigures(
        registeredVoters: 500,
        accreditedVoters: 200,
        partyVotes: {'APC': 150, 'LP': 60}, // 210 party votes
        rejectedVotes: 5, // total 215 > 200 accredited
      );

      expect(invalidFigures.isVotesCastValid, isFalse);
      expect(invalidFigures.isValid, isFalse);
    });

    test('detects invalid accreditedVoters > registeredVoters', () {
      final invalidFigures = ResultFigures(
        registeredVoters: 200,
        accreditedVoters: 250,
        partyVotes: {'APC': 100},
        rejectedVotes: 0,
      );

      expect(invalidFigures.isAccreditedValid, isFalse);
      expect(invalidFigures.isValid, isFalse);
    });

    test('serializes and deserializes cleanly with JSON', () {
      final figures = ResultFigures(
        registeredVoters: 600,
        accreditedVoters: 350,
        partyVotes: {'APC': 180, 'LP': 120, 'PDP': 40},
        rejectedVotes: 8,
      );

      final jsonMap = figures.toJson();
      final restored = ResultFigures.fromJson(jsonMap);

      expect(restored.registeredVoters, equals(600));
      expect(restored.accreditedVoters, equals(350));
      expect(restored.partyVotes['APC'], equals(180));
      expect(restored.partyVotes['LP'], equals(120));
      expect(restored.rejectedVotes, equals(8));
      expect(restored.totalVotesCast, equals(348));
    });
  });

  // ─── 2. LocationSnapshot Verification ──────────────────────────────────────
  group('LocationSnapshot', () {
    test('flags accurate locations (<= 25m)', () {
      final accurate = LocationSnapshot(
        latitude: 9.0765,
        longitude: 7.3986,
        accuracyMeters: 8.5,
        capturedAt: DateTime(2026, 2, 28, 14, 30),
      );

      expect(accurate.isAccurate, isTrue);
      expect(accurate.latitudeFormatted, equals('9.07650'));
      expect(accurate.longitudeFormatted, equals('7.39860'));
      expect(accurate.accuracyFormatted, equals('±9 m'));
    });

    test('flags inaccurate locations (> 25m)', () {
      final inaccurate = LocationSnapshot(
        latitude: 9.0765,
        longitude: 7.3986,
        accuracyMeters: 45.0,
        capturedAt: DateTime(2026, 2, 28, 14, 30),
      );

      expect(inaccurate.isAccurate, isFalse);
    });

    test('serializes and deserializes LocationSnapshot', () {
      final loc = LocationSnapshot(
        latitude: 6.5244,
        longitude: 3.3792,
        accuracyMeters: 12.0,
        capturedAt: DateTime(2026, 3, 1, 10, 0),
        isMock: false,
      );

      final json = loc.toJson();
      final restored = LocationSnapshot.fromJson(json);

      expect(restored.latitude, equals(6.5244));
      expect(restored.longitude, equals(3.3792));
      expect(restored.accuracyMeters, equals(12.0));
      expect(restored.capturedAt, equals(DateTime(2026, 3, 1, 10, 0)));
      expect(restored.isMock, isFalse);
    });
  });

  // ─── 3. EvidenceMetadata Validation ────────────────────────────────────────
  group('EvidenceMetadata', () {
    test('serializes and deserializes photo metadata', () {
      final meta = EvidenceMetadata(
        localPath: '/data/user/0/app/cache/photo.jpg',
        originalPath: '/data/user/0/app/cache/raw_photo.jpg',
        mimeType: 'image/jpeg',
        hash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        fileSize: 2048576,
        capturedAt: DateTime(2026, 2, 28, 15, 0),
        location: LocationSnapshot(
          latitude: 9.05,
          longitude: 7.45,
          accuracyMeters: 5.0,
          capturedAt: DateTime(2026, 2, 28, 15, 0),
        ),
      );

      final json = meta.toJson();
      final restored = EvidenceMetadata.fromJson(json);

      expect(restored.localPath, equals(meta.localPath));
      expect(restored.originalPath, equals(meta.originalPath));
      expect(restored.hash, equals(meta.hash));
      expect(restored.fileSize, equals(2048576));
      expect(restored.fileSizeFormatted, contains('MB'));
      expect(restored.location?.isAccurate, isTrue);
    });
  });

  // ─── 4. ResultSubmissionDraft & State Transitions ─────────────────────────
  group('ResultSubmissionDraft', () {
    test('isComplete returns true only when all components are present', () {
      final incompleteDraft = ResultSubmissionDraft(
        pollingUnitId: 'PU-01-01-001',
        electionId: 'ELEC-2026-PRESIDENTIAL',
      );
      expect(incompleteDraft.isComplete, isFalse);
      expect(incompleteDraft.hasFigures, isFalse);
      expect(incompleteDraft.hasPhoto, isFalse);
      expect(incompleteDraft.hasVideo, isFalse);
      expect(incompleteDraft.hasLocation, isFalse);
      expect(incompleteDraft.completionRatio, equals(0.0));

      final figures = ResultFigures(
        registeredVoters: 500,
        accreditedVoters: 250,
        partyVotes: {'APC': 150, 'PDP': 90},
        rejectedVotes: 5,
      );
      final location = LocationSnapshot(
        latitude: 9.0,
        longitude: 7.0,
        accuracyMeters: 10.0,
        capturedAt: DateTime.now(),
      );
      final photo = EvidenceMetadata(
        localPath: '/tmp/photo.jpg',
        mimeType: 'image/jpeg',
        hash: 'hash123',
        fileSize: 1024,
        capturedAt: DateTime.now(),
      );
      final video = EvidenceMetadata(
        localPath: '/tmp/video.mp4',
        mimeType: 'video/mp4',
        hash: 'hash456',
        fileSize: 4096,
        capturedAt: DateTime.now(),
        durationSeconds: 25,
      );

      final completeDraft = ResultSubmissionDraft(
        pollingUnitId: 'PU-01-01-001',
        electionId: 'ELEC-2026-PRESIDENTIAL',
        figures: figures,
        location: location,
        resultPhoto: photo,
        declarationVideo: video,
      );

      expect(completeDraft.isComplete, isTrue);
      expect(completeDraft.completionRatio, equals(1.0));
      expect(completeDraft.hasFigures, isTrue);
      expect(completeDraft.hasPhoto, isTrue);
      expect(completeDraft.hasVideo, isTrue);
      expect(completeDraft.hasLocation, isTrue);
    });

    test('builds transmission payload correctly', () {
      final figures = ResultFigures(
        registeredVoters: 400,
        accreditedVoters: 200,
        partyVotes: {'APC': 120, 'LP': 75},
        rejectedVotes: 5,
      );
      final location = LocationSnapshot(
        latitude: 9.0,
        longitude: 7.0,
        accuracyMeters: 5.0,
        capturedAt: DateTime.now(),
      );
      final photo = EvidenceMetadata(
        localPath: '/tmp/photo.jpg',
        mimeType: 'image/jpeg',
        hash: 'photohash',
        fileSize: 1024,
        capturedAt: DateTime.now(),
      );
      final video = EvidenceMetadata(
        localPath: '/tmp/video.mp4',
        mimeType: 'video/mp4',
        hash: 'videohash',
        fileSize: 2048,
        capturedAt: DateTime.now(),
        durationSeconds: 15,
      );

      final payload = ResultSubmissionPayload(
        electionId: 'ELEC-2026-PRESIDENTIAL',
        pollingUnitId: 'PU-01-01-001',
        figures: figures,
        location: location,
        resultPhoto: photo,
        declarationVideo: video,
        deviceTimestamp: DateTime.now(),
      );

      final json = payload.toJson();
      expect(json['electionId'], equals('ELEC-2026-PRESIDENTIAL'));
      expect(json['pollingUnitId'], equals('PU-01-01-001'));
      expect(json['figures']['registeredVoters'], equals(400));
      expect(json['resultPhoto']['hash'], equals('photohash'));
      expect(json['declarationVideo']['durationSeconds'], equals(15));
    });
  });

  // ─── 5. ResultSubmissionController State Management ────────────────────────
  group('ResultSubmissionController', () {
    late MockPollingUnitRepository mockRepo;
    late ResultSubmissionController controller;

    setUp(() {
      mockRepo = MockPollingUnitRepository.instance();
      controller = ResultSubmissionController(
        pollingUnitId: 'PU-01-01-001',
        repository: mockRepo,
      );
    });

    test('initial state defaults correctly before and after initialize()', () async {
      expect(controller.pollingUnitId, equals('PU-01-01-001'));
      expect(controller.currentStep, equals(1));
      expect(controller.isInitialized, isFalse);

      await controller.initialize();

      expect(controller.isInitialized, isTrue);
      expect(controller.state, equals(SubmissionLifecycleState.draft));
      expect(controller.resultPhoto, isNull);
      expect(controller.declarationVideo, isNull);
      expect(controller.location, isNull);
    });

    test('step progression and navigation constraints', () async {
      await controller.initialize();

      expect(controller.currentStep, equals(1));

      controller.setStep(3);
      expect(controller.currentStep, equals(3));

      // Out of bounds step changes are ignored
      controller.setStep(6);
      expect(controller.currentStep, equals(3));
      controller.setStep(0);
      expect(controller.currentStep, equals(3));
    });

    test('saveFigures updates figures and deviceTimestamp', () async {
      await controller.initialize();

      final newFigures = ResultFigures(
        registeredVoters: 500,
        accreditedVoters: 200,
        partyVotes: {'APC': 190},
        rejectedVotes: 10,
      );

      await controller.saveFigures(newFigures);

      expect(controller.figures.registeredVoters, equals(500));
      expect(controller.figures.accreditedVoters, equals(200));
      expect(controller.figures.totalVotesCast, equals(200));
    });
  });
}
