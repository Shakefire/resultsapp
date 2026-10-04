// test/polling_unit_dashboard_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_electoral_results_app/core/theme/app_theme.dart';
import 'package:smart_electoral_results_app/features/authentication/controllers/auth_controller.dart';
import 'package:smart_electoral_results_app/features/authentication/services/mock_auth_service.dart';
import 'package:smart_electoral_results_app/features/polling_unit/controllers/polling_unit_dashboard_controller.dart';
import 'package:smart_electoral_results_app/features/polling_unit/models/polling_unit_assignment.dart';
import 'package:smart_electoral_results_app/features/polling_unit/models/result_submission.dart';
import 'package:smart_electoral_results_app/features/polling_unit/models/voter_register.dart';
import 'package:smart_electoral_results_app/features/polling_unit/repositories/mock_polling_unit_repository.dart';
import 'package:smart_electoral_results_app/features/polling_unit/presentation/screens/polling_unit_dashboard_screen.dart';
import 'package:smart_electoral_results_app/features/polling_unit/presentation/widgets/dashboard_header.dart';

void main() {
  group('DashboardHeader Greeting Logic', () {
    test('dynamic greeting returns appropriate time string', () {
      final greeting = DashboardHeader.getGreeting();
      expect(
        greeting,
        anyOf(['Good morning', 'Good afternoon', 'Good evening']),
      );
    });
  });

  group('ResultStatus Model & Extension', () {
    test('notSubmitted has correct titles and actions', () {
      const status = ResultStatus.notSubmitted;
      expect(status.displayTitle, equals('Not submitted'));
      expect(status.actionLabel, equals('SUBMIT RESULT'));
    });

    test('returned has correction action and title', () {
      const status = ResultStatus.returned;
      expect(status.displayTitle, equals('Correction required'));
      expect(status.actionLabel, equals('CORRECT & RESUBMIT'));
    });

    test('verified has view result action', () {
      const status = ResultStatus.verified;
      expect(status.displayTitle, equals('Verified'));
      expect(status.actionLabel, equals('VIEW RESULT'));
    });

    test('wardReview has view submission action', () {
      const status = ResultStatus.wardReview;
      expect(status.displayTitle, equals('Under Ward Review'));
      expect(status.actionLabel, equals('VIEW SUBMISSION'));
    });
  });

  group('VoterRegisterStatus Model & Extension', () {
    test('notUploaded has upload register action', () {
      const status = VoterRegisterStatus.notUploaded;
      expect(status.displayTitle, equals('Not uploaded'));
      expect(status.actionLabel, equals('UPLOAD REGISTER'));
    });

    test('uploadFailed has retry action', () {
      const status = VoterRegisterStatus.uploadFailed;
      expect(status.displayTitle, equals('Upload failed'));
      expect(status.actionLabel, equals('TRY AGAIN'));
    });

    test('uploaded has view register action', () {
      const status = VoterRegisterStatus.uploaded;
      expect(status.displayTitle, equals('Uploaded'));
      expect(status.actionLabel, equals('VIEW REGISTER'));
    });
  });

  group('PollingUnitDashboard Widget Tests', () {
    late MockPollingUnitRepository mockRepo;
    late PollingUnitDashboardController dashboardController;
    late AuthController authController;

    setUp(() {
      mockRepo = MockPollingUnitRepository(
        initialAssignment: const PollingUnitAssignment(
          pollingUnitId: 'PU 0047',
          pollingUnitName: 'Gwarinpa Primary School',
          ward: 'Ward 03',
          lga: 'AMAC',
          state: 'FCT',
          location: 'Gwarinpa Primary School, Abuja',
        ),
        initialResult: ResultSubmission.initial(),
        initialRegister: VoterRegister.initial(),
        initialActivity: [],
      );
      dashboardController = PollingUnitDashboardController(repository: mockRepo);
      authController = AuthController(authService: MockAuthService());
    });

    Widget createWidgetUnderTest() {
      return MaterialApp(
        theme: AppTheme.light,
        home: PollingUnitDashboardScreen(
          authController: authController,
          dashboardController: dashboardController,
        ),
      );
    }

    testWidgets('Renders assignment and not-submitted initial state correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Initial loading state
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Finish async load
      await tester.pumpAndSettle();

      // Check Assignment section
      expect(find.text('POLLING UNIT'), findsOneWidget);
      expect(find.text('PU 0047'), findsOneWidget);
      expect(find.text('Ward 03 · AMAC'), findsOneWidget);
      expect(find.text('Gwarinpa Primary School'), findsOneWidget);

      // Check Result section (Not submitted)
      expect(find.text('RESULT'), findsOneWidget);
      expect(find.text('Not submitted'), findsNWidgets(2)); // badge + card title
      expect(find.text('SUBMIT RESULT'), findsOneWidget);

      // Check Voter Register section (Not uploaded)
      expect(find.text('VOTER REGISTER'), findsOneWidget);
      expect(find.text('Not uploaded'), findsNWidgets(2));
      expect(find.text('UPLOAD REGISTER'), findsOneWidget);

      // Check Recent Activity empty state
      expect(find.text('RECENT ACTIVITY'), findsOneWidget);
      expect(find.text('No recent activity'), findsOneWidget);

      // Check Bottom Nav tabs
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Results'), findsOneWidget);
      expect(find.text('Alerts'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('Updates UI when result is returned with correction note',
        (WidgetTester tester) async {
      mockRepo.setResult(const ResultSubmission(
        id: 'res_123',
        status: ResultStatus.returned,
        returnReason: 'Discrepancy in accredited voter count.',
      ));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Check Returned state
      expect(find.text('Correction required'), findsNWidgets(2));
      expect(find.text('Reason: Discrepancy in accredited voter count.'), findsOneWidget);
      expect(find.text('CORRECT & RESUBMIT'), findsOneWidget);
    });

    testWidgets('Updates UI when result is verified',
        (WidgetTester tester) async {
      mockRepo.setResult(const ResultSubmission(
        id: 'res_123',
        status: ResultStatus.verified,
      ));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Check Verified state
      expect(find.text('Verified'), findsNWidgets(2));
      expect(find.text('VIEW RESULT'), findsOneWidget);
    });

    testWidgets('Updates UI when voter register is uploaded',
        (WidgetTester tester) async {
      mockRepo.setVoterRegister(VoterRegister(
        status: VoterRegisterStatus.uploaded,
        uploadedAt: DateTime(2026, 9, 21),
        fileName: 'PU0047_VOTER_REGISTER.pdf',
      ));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Uploaded'), findsNWidgets(2));
      expect(find.text('VIEW REGISTER'), findsOneWidget);
    });

    testWidgets('Bottom navigation tab switching functions properly',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Switch to Results tab
      await tester.tap(find.text('Results'));
      await tester.pumpAndSettle();
      expect(find.text('Results & Submission History'), findsOneWidget);

      // Switch to Alerts tab
      await tester.tap(find.text('Alerts'));
      await tester.pumpAndSettle();
      expect(find.text('Operational Alerts'), findsOneWidget);

      // Switch to Profile tab
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Staff Profile'), findsOneWidget);
      expect(find.text('LOGOUT'), findsOneWidget);

      // Switch back to Home tab
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.text('POLLING UNIT'), findsOneWidget);
    });

    testWidgets('Displays error state with working retry',
        (WidgetTester tester) async {
      mockRepo.shouldFail = true;

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Unable to load dashboard'), findsOneWidget);
      expect(find.text('TRY AGAIN'), findsOneWidget);

      // Fix failure and tap retry
      mockRepo.shouldFail = false;
      await tester.tap(find.text('TRY AGAIN'));
      await tester.pump(); // Start loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle(); // Loaded

      expect(find.text('POLLING UNIT'), findsOneWidget);
    });
  });
}
