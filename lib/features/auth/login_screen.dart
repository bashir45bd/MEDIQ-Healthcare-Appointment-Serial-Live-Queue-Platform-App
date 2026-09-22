import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/constants.dart';
import '../../state/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  final AuthProvider auth;

  const LoginScreen({Key? key, required this.auth}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Mode: true = Sign In, false = Register
  bool _isSignInMode = true;
  bool _obscurePassword = true;
  bool _obscureRegPassword = true;
  bool _obscureRegConfirmPassword = true;
  DateTime? _lastBackPressTime;

  // Sign In controllers
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isDoctorRole = false;

  // Register controllers (Simplified: Name, Phone, Password, Confirm Password, Role)
  final _regNameController = TextEditingController();
  final _regPhoneController = TextEditingController();
  final _regPasswordController = TextEditingController();
  final _regConfirmPasswordController = TextEditingController();
  bool _isDoctorRegister = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _regNameController.dispose();
    _regPhoneController.dispose();
    _regPasswordController.dispose();
    _regConfirmPasswordController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Sign In Action
  // ---------------------------------------------------------------------------
  Future<void> _handleLogin() async {
    final phone = _phoneController.text.trim();
    final pass = _passwordController.text;

    if (phone.isEmpty || pass.isEmpty) {
      _showError('Please enter mobile number and password');
      return;
    }

    final success = await widget.auth.login(phone, pass);
    if (!success && mounted) {
      _showError(widget.auth.errorMessage ?? 'Login failed. Check phone and password.');
    }
  }

  // ---------------------------------------------------------------------------
  // Registration Initiation -> Sends OTP
  // ---------------------------------------------------------------------------
  Future<void> _handleRegisterInitiate() async {
    final name = _regNameController.text.trim();
    final phone = _regPhoneController.text.trim();
    final pass = _regPasswordController.text;
    final confirmPass = _regConfirmPasswordController.text;

    if (name.isEmpty) {
      _showError('Please enter your full name');
      return;
    }
    if (phone.length < 11) {
      _showError('Please enter a valid mobile number (min 11 digits)');
      return;
    }
    if (pass.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }
    if (pass != confirmPass) {
      _showError('Password and Confirm Password do not match');
      return;
    }

    final payload = {
      'role': _isDoctorRegister ? 'DOCTOR' : 'PATIENT',
      'full_name': name,
      'phone': phone,
      'password': pass,
      'confirm_password': confirmPass,
    };

    final res = await widget.auth.sendRegistrationOtp(payload);
    if (!mounted) return;

    if (res != null) {
      final devOtp = res['otp']?.toString();
      _showOtpVerificationSheet(phone, devOtp);
    } else {
      _showError(widget.auth.errorMessage ?? 'Failed to send verification code. Please try again.');
    }
  }

  // ---------------------------------------------------------------------------
  // OTP Verification Modal Sheet
  // ---------------------------------------------------------------------------
  void _showOtpVerificationSheet(String phone, String? devOtp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _OtpVerificationSheet(
          auth: widget.auth,
          phone: phone,
          initialDevOtp: devOtp,
          onSuccess: (isDoctorPending) {
            Navigator.pop(sheetContext);
            if (isDoctorPending && mounted) {
              _showDoctorPendingApprovalDialog();
            }
          },
        );
      },
    );
  }

  void _showDoctorPendingApprovalDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.cardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primaryLightColor(context),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_user_outlined, color: AppColors.primary, size: 36),
              ),
              const SizedBox(height: 16),
              Text('Account Created & Mobile Verified!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textColor(context))),
              const SizedBox(height: 10),
              Text(
                widget.auth.infoMessage ??
                    'Your doctor account has been registered and verified. It is now awaiting administrator credential approval before you can log in.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMutedColor(context), fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 22),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _isSignInMode = true;
                    _isDoctorRole = true;
                    _phoneController.text = _regPhoneController.text;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  elevation: 0,
                ),
                child: const Text('Back to Login', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Forgot Password Flow
  // ---------------------------------------------------------------------------
  void _showForgotPasswordSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _ForgotPasswordSheet(
          auth: widget.auth,
          initialPhone: _phoneController.text.trim(),
          onSuccess: (phone) {
            Navigator.pop(sheetContext);
            setState(() {
              _phoneController.text = phone;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Password reset successfully! Please sign in with your new password.'),
                backgroundColor: AppColors.success,
                duration: Duration(seconds: 4),
              ),
            );
          },
        );
      },
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.danger),
    );
  }

  // ---------------------------------------------------------------------------
  // Build Main Screen
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final auth = widget.auth;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (!_isSignInMode) {
          setState(() => _isSignInMode = true);
          return;
        }
        final now = DateTime.now();
        if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit MEDIQ'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.bg(context),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Action Row (Back button & Theme Toggle)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (!_isSignInMode)
                          IconButton(
                            icon: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 20,
                              color: AppColors.textColor(context),
                            ),
                            onPressed: () => setState(() => _isSignInMode = true),
                          )
                        else
                          const SizedBox.shrink(),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Brand Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.favorite_rounded, size: 22, color: Colors.white),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'MEDIQ',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Main Title
                    Text(
                      _isSignInMode ? 'Login to Your Account' : 'Create New Account',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textColor(context),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isSignInMode
                          ? 'Welcome back! Please enter credentials to sign in.'
                          : 'Quick registration with mobile verification.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMutedColor(context),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Error Banner if Auth Failed
                    if (auth.errorMessage != null && auth.errorMessage!.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.dangerLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                auth.errorMessage!,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.danger,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Main Card (Sign In / Register)
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: AppColors.cardColor(context),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.borderColor(context)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Mode Selector: Sign In vs Register
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.isDark(context) ? AppDarkColors.background : AppColors.primarySuperLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => _isSignInMode = true),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: _isSignInMode
                                            ? (AppColors.isDark(context) ? AppDarkColors.cardElevated : Colors.white)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: _isSignInMode
                                            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                            : null,
                                      ),
                                      child: Text(
                                        'Sign In',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: _isSignInMode ? AppColors.primary : AppColors.textMutedColor(context),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => _isSignInMode = false),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: !_isSignInMode
                                            ? (AppColors.isDark(context) ? AppDarkColors.cardElevated : Colors.white)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: !_isSignInMode
                                            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                            : null,
                                      ),
                                      child: Text(
                                        'Register',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: !_isSignInMode ? AppColors.primary : AppColors.textMutedColor(context),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Form Body
                          if (_isSignInMode)
                            _buildSignInForm(auth)
                          else
                            _buildRegisterForm(auth),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sign In Form View
  // ---------------------------------------------------------------------------
  Widget _buildSignInForm(AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Role Switcher for Sign In
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.isDark(context) ? AppDarkColors.background : AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderColor(context)),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isDoctorRole = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: !_isDoctorRole ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_rounded, size: 16, color: !_isDoctorRole ? Colors.white : AppColors.textMutedColor(context)),
                        const SizedBox(width: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Patient',
                            style: TextStyle(
                              color: !_isDoctorRole ? Colors.white : AppColors.textMutedColor(context),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isDoctorRole = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: _isDoctorRole ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.medical_services_rounded, size: 16, color: _isDoctorRole ? Colors.white : AppColors.textMutedColor(context)),
                        const SizedBox(width: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Doctor',
                            style: TextStyle(
                              color: _isDoctorRole ? Colors.white : AppColors.textMutedColor(context),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'Mobile Phone',
            hintText: '01XXXXXXXXX',
            prefixIcon: const Icon(Icons.phone_iphone_rounded, color: AppColors.primary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 14),

        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Password',
            hintText: '••••••••',
            prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.primary),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.textMutedColor(context)),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 14),

        // Remember me & Forgot Password (100% responsive)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Remember me',
                      style: TextStyle(fontSize: 12.5, color: AppColors.textMutedColor(context), fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _showForgotPasswordSheet,
              child: const Text(
                'Forgot Password?',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),

        // Submit Button
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: auth.isLoading ? null : _handleLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
              elevation: 0,
            ),
            child: auth.isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    _isDoctorRole ? 'Sign In as Doctor' : 'Sign In as Patient',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
          ),
        ),
        const SizedBox(height: 18),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Don't have an account? ", style: TextStyle(fontSize: 13, color: AppColors.textMutedColor(context))),
            GestureDetector(
              onTap: () => setState(() => _isSignInMode = false),
              child: const Text('Register Now', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Register Form View (Simplified: Name, Phone, Password, Confirm Password)
  // ---------------------------------------------------------------------------
  Widget _buildRegisterForm(AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Role Switcher for Registration
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.isDark(context) ? AppDarkColors.background : AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderColor(context)),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isDoctorRegister = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: !_isDoctorRegister ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_rounded, size: 16, color: !_isDoctorRegister ? Colors.white : AppColors.textMutedColor(context)),
                        const SizedBox(width: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Patient',
                            style: TextStyle(
                              color: !_isDoctorRegister ? Colors.white : AppColors.textMutedColor(context),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isDoctorRegister = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: _isDoctorRegister ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.medical_services_rounded, size: 16, color: _isDoctorRegister ? Colors.white : AppColors.textMutedColor(context)),
                        const SizedBox(width: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Doctor',
                            style: TextStyle(
                              color: _isDoctorRegister ? Colors.white : AppColors.textMutedColor(context),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Full Name
        TextField(
          controller: _regNameController,
          decoration: InputDecoration(
            labelText: _isDoctorRegister ? 'Doctor Full Name' : 'Full Name',
            hintText: _isDoctorRegister ? 'Dr. Firstname Lastname' : 'Full Name',
            prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.primary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 12),

        // Mobile Phone
        TextField(
          controller: _regPhoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'Mobile Number',
            hintText: '01XXXXXXXXX',
            prefixIcon: const Icon(Icons.phone_iphone_rounded, color: AppColors.primary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 12),

        // Password
        TextField(
          controller: _regPasswordController,
          obscureText: _obscureRegPassword,
          decoration: InputDecoration(
            labelText: 'Password',
            hintText: 'Min 6 characters',
            prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.primary),
            suffixIcon: IconButton(
              icon: Icon(_obscureRegPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.textMutedColor(context)),
              onPressed: () => setState(() => _obscureRegPassword = !_obscureRegPassword),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 12),

        // Confirm Password
        TextField(
          controller: _regConfirmPasswordController,
          obscureText: _obscureRegConfirmPassword,
          decoration: InputDecoration(
            labelText: 'Confirm Password',
            hintText: 'Re-enter password',
            prefixIcon: const Icon(Icons.lock_reset_rounded, color: AppColors.primary),
            suffixIcon: IconButton(
              icon: Icon(_obscureRegConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.textMutedColor(context)),
              onPressed: () => setState(() => _obscureRegConfirmPassword = !_obscureRegConfirmPassword),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 12),

        // Informative note that detailed info can be updated later
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.isDark(context) ? AppColors.primary.withValues(alpha: 0.15) : AppColors.primarySuperLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.isDark(context) ? AppColors.primary.withValues(alpha: 0.3) : AppColors.primaryLight),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isDoctorRegister
                      ? 'BMDC certificate, consultation fees, and chamber details can be updated anytime from your profile.'
                      : 'Medical records, blood group, and emergency contact can be updated anytime from your profile.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.isDark(context) ? const Color(0xFF93C5FD) : AppColors.primary,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Submit Button
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: auth.isLoading ? null : _handleRegisterInitiate,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
              elevation: 0,
            ),
            child: auth.isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    _isDoctorRegister ? 'Verify Phone & Create Doctor Account' : 'Verify Phone & Create Patient Account',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
          ),
        ),
        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Already have an account? ", style: TextStyle(fontSize: 13, color: AppColors.textMutedColor(context))),
            GestureDetector(
              onTap: () => setState(() => _isSignInMode = true),
              child: const Text('Sign In', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ),
          ],
        ),
      ],
    );
  }
}

// =============================================================================
// OTP VERIFICATION BOTTOM SHEET WIDGET
// =============================================================================
class _OtpVerificationSheet extends StatefulWidget {
  final AuthProvider auth;
  final String phone;
  final String? initialDevOtp;
  final Function(bool isDoctorPending) onSuccess;

  const _OtpVerificationSheet({
    required this.auth,
    required this.phone,
    this.initialDevOtp,
    required this.onSuccess,
  });

  @override
  State<_OtpVerificationSheet> createState() => _OtpVerificationSheetState();
}

class _OtpVerificationSheetState extends State<_OtpVerificationSheet> {
  final _otpController = TextEditingController();
  int _countdown = 60;
  Timer? _timer;
  bool _isVerifying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialDevOtp != null) {
      _otpController.text = widget.initialDevOtp!;
    }
    _startTimer();
  }

  void _startTimer() {
    _countdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length < 4) {
      setState(() => _error = 'Please enter the valid OTP code');
      return;
    }

    setState(() {
      _isVerifying = true;
      _error = null;
    });

    final success = await widget.auth.verifyRegistrationOtp(widget.phone, otp);
    if (!mounted) return;

    setState(() => _isVerifying = false);

    if (success) {
      widget.onSuccess(widget.auth.pendingApproval);
    } else {
      setState(() {
        _error = widget.auth.errorMessage ?? 'Invalid verification code. Please try again.';
      });
    }
  }

  Future<void> _resendOtp() async {
    if (_countdown > 0) return;
    setState(() => _error = null);

    // Call sendRegistrationOtp again
    final res = await widget.auth.sendRegistrationOtp({
      'phone': widget.phone,
      'full_name': 'Patient/Doctor',
      'password': 'placeholder_resend',
      'role': 'PATIENT',
    });

    if (res != null && mounted) {
      final devOtp = res['otp']?.toString();
      if (devOtp != null) {
        _otpController.text = devOtp;
      }
      _startTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('New verification code sent to ${widget.phone}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.isDark(context) ? const Color(0xFF475569) : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title & Icon
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.isDark(context) ? AppDarkColors.background : AppColors.primarySuperLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mark_email_read_outlined, color: AppColors.primary, size: 30),
            ),
          ),
          const SizedBox(height: 14),

          Text(
            'Verify Mobile Number',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textColor(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'We sent a 6-digit verification code to:\n${widget.phone}',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textMutedColor(context), height: 1.4),
          ),

          if (widget.initialDevOtp != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Demo / Test Code: ${widget.initialDevOtp}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),

          const SizedBox(height: 20),

          if (_error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.dangerLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),

          // OTP Input
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 8),
            decoration: InputDecoration(
              counterText: '',
              hintText: '••••••',
              hintStyle: TextStyle(color: AppColors.textLightColor(context), letterSpacing: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 18),

          // Verify Button
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _isVerifying ? null : _verifyOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                elevation: 0,
              ),
              child: _isVerifying
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Verify & Create Account',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
            ),
          ),
          const SizedBox(height: 14),

          // Resend Timer
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Didn't receive code? ", style: TextStyle(fontSize: 13, color: AppColors.textMutedColor(context))),
              GestureDetector(
                onTap: _countdown == 0 ? _resendOtp : null,
                child: Text(
                  _countdown > 0 ? 'Resend in ${_countdown}s' : 'Resend Code',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _countdown == 0 ? AppColors.primary : AppColors.textMutedColor(context),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// FORGOT PASSWORD BOTTOM SHEET WIDGET
// =============================================================================
class _ForgotPasswordSheet extends StatefulWidget {
  final AuthProvider auth;
  final String initialPhone;
  final Function(String phone) onSuccess;

  const _ForgotPasswordSheet({
    required this.auth,
    required this.initialPhone,
    required this.onSuccess,
  });

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  int _step = 1; // 1 = enter phone, 2 = enter OTP + new password
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _obscureNewPass = true;
  bool _obscureConfirmPass = true;
  bool _isLoading = false;
  String? _error;
  String? _devOtp;

  @override
  void initState() {
    super.initState();
    _phoneCtrl.text = widget.initialPhone;
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestResetOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length < 11) {
      setState(() => _error = 'Please enter a valid mobile number');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final res = await widget.auth.sendForgotPasswordOtp(phone);
    if (!mounted) return;

    setState(() => _isLoading = false);

    if (res != null) {
      setState(() {
        _step = 2;
        _devOtp = res['otp']?.toString();
        if (_devOtp != null) {
          _otpCtrl.text = _devOtp!;
        }
      });
    } else {
      setState(() {
        _error = widget.auth.errorMessage ?? 'No account registered with this phone number.';
      });
    }
  }

  Future<void> _submitPasswordReset() async {
    final phone = _phoneCtrl.text.trim();
    final otp = _otpCtrl.text.trim();
    final newPass = _newPassCtrl.text;
    final confirmPass = _confirmPassCtrl.text;

    if (otp.length < 4) {
      setState(() => _error = 'Please enter the verification code');
      return;
    }
    if (newPass.length < 6) {
      setState(() => _error = 'New password must be at least 6 characters');
      return;
    }
    if (newPass != confirmPass) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final success = await widget.auth.resetPassword(phone, otp, newPass, confirmPass);
    if (!mounted) return;

    setState(() => _isLoading = false);

    if (success) {
      widget.onSuccess(phone);
    } else {
      setState(() {
        _error = widget.auth.errorMessage ?? 'Failed to reset password. Check OTP code.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.isDark(context) ? const Color(0xFF475569) : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.lock_reset_rounded, color: AppColors.warning, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _step == 1 ? 'Forgot Password?' : 'Set New Password',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textColor(context),
                      ),
                    ),
                    Text(
                      _step == 1
                          ? 'Enter your phone number to receive OTP'
                          : 'Enter the OTP code & your new password',
                      style: TextStyle(fontSize: 12, color: AppColors.textMutedColor(context)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (_error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.dangerLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),

          if (_step == 1) ...[
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Registered Mobile Number',
                hintText: '01XXXXXXXXX',
                prefixIcon: const Icon(Icons.phone_iphone_rounded, color: AppColors.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _requestResetOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Send Verification Code 📲',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
              ),
            ),
          ] else ...[
            if (_devOtp != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Demo / Test Code: $_devOtp',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),

            TextField(
              controller: _otpCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 6),
              decoration: InputDecoration(
                counterText: '',
                labelText: '6-Digit OTP Code',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _newPassCtrl,
              obscureText: _obscureNewPass,
              decoration: InputDecoration(
                labelText: 'New Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.primary),
                suffixIcon: IconButton(
                  icon: Icon(_obscureNewPass ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.textMutedColor(context)),
                  onPressed: () => setState(() => _obscureNewPass = !_obscureNewPass),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _confirmPassCtrl,
              obscureText: _obscureConfirmPass,
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                prefixIcon: const Icon(Icons.lock_reset_rounded, color: AppColors.primary),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirmPass ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.textMutedColor(context)),
                  onPressed: () => setState(() => _obscureConfirmPass = !_obscureConfirmPass),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitPasswordReset,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Reset Password & Sign In 🔑',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
