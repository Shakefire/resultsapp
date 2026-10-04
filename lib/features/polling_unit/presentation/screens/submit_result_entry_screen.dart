import 'package:flutter/material.dart';
import '../../../../core/constants/route_names.dart';
import '../../controllers/polling_unit_dashboard_controller.dart';

/// Compatibility entry point that opens the real, authenticated submission flow.
class SubmitResultEntryScreen extends StatelessWidget {
  const SubmitResultEntryScreen({super.key, required this.controller});
  final PollingUnitDashboardController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Submit result')),
        body: Center(
          child: FilledButton.icon(
            onPressed: () => Navigator.of(context).pushNamed(RouteNames.submitResult),
            icon: const Icon(Icons.assignment_outlined),
            label: const Text('Open result submission'),
          ),
        ),
      );
}
