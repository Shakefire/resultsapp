// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:device_preview/device_preview.dart';
import 'core/constants/route_names.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/authentication/controllers/auth_controller.dart';
import 'features/authentication/services/vercel_auth_service.dart';

void main() {
  // Device Preview registers service extensions in debug builds. Open Flutter
  // DevTools' Device Preview panel while running with `flutter run -d chrome`.
  // The simulator is disabled in release builds and does not ship to users.
  DevicePreview.enable(enabled: kDebugMode);

  // Lock orientation to portrait — typical for a mobile data entry app
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  runApp(const SmartElectoralResultsApp());
}

class SmartElectoralResultsApp extends StatefulWidget {
  const SmartElectoralResultsApp({super.key});

  @override
  State<SmartElectoralResultsApp> createState() =>
      _SmartElectoralResultsAppState();
}

class _SmartElectoralResultsAppState extends State<SmartElectoralResultsApp> {
  // Single shared AuthController for the entire app lifetime
  late final AuthController _authController;
  late final AppRouter _router;

  @override
  void initState() {
    super.initState();
    _authController = AuthController(authService: VercelAuthService());
    _router = AppRouter(authController: _authController);
  }

  @override
  void dispose() {
    _authController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Electoral Results App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: RouteNames.splash,
      onGenerateRoute: _router.generateRoute,
    );
  }
}
