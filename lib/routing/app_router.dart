import 'package:flutter/material.dart';
import '../state/auth_provider.dart';
import '../features/auth/login_screen.dart';
import '../features/patient/patient_shell.dart';
import '../features/doctor/doctor_shell.dart';

class AppRouter extends StatefulWidget {
  final AuthProvider auth;

  const AppRouter({Key? key, required this.auth}) : super(key: key);

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  @override
  void initState() {
    super.initState();
    widget.auth.tryAutoLogin();
  }

  @override
  Widget build(BuildContext context) {
    // Wait until local session check finishes (takes ~1-5ms)
    if (!widget.auth.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }

    // Direct navigation to LoginScreen if not authenticated
    if (!widget.auth.isAuthenticated) {
      return LoginScreen(auth: widget.auth);
    }

    // Direct navigation to user shell if authenticated
    final user = widget.auth.currentUser!;
    if (user.isDoctor) {
      return DoctorShell(auth: widget.auth);
    } else {
      return PatientShell(auth: widget.auth);
    }
  }
}
