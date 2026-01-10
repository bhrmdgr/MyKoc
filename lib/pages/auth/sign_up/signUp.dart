import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:mykoc/firebase/auth/firebaseSignUp.dart';
import 'package:mykoc/routers/appRouter.dart';

import '../../../policy/legal_content_sheet.dart';

class Signup extends StatefulWidget {
  const Signup({super.key});

  @override
  State<Signup> createState() => _SignupState();
}

class _SignupState extends State<Signup> {
  final _firebaseSignUp = FirebaseSignUp();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _classCodeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  String _fullPhoneNumber = "";
  String _verificationId = "";
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  bool _isPolicyAccepted = false; // Politika onay durumu

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _classCodeController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // Politika Sheet'ini gösteren yardımcı metod
  void _showPolicy(String titleKey, String contentKey) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LegalContentSheet(
        titleKey: titleKey,
        contentKey: contentKey,
      ),
    );
  }

  // 1. ADIM: Telefon Doğrulama Başlatma
  Future<void> _handleSignUp() async {
    // Politika Onay Kontrolü
    if (!_isPolicyAccepted) {
      _showError('error_accept_policies'.tr());
      return;
    }

    if (_nameController.text.trim().isEmpty) { _showError('error_empty_name'.tr()); return; }
    if (_emailController.text.trim().isEmpty) { _showError('error_empty_email'.tr()); return; }
    if (_passwordController.text.length < 6) { _showError('error_password_length'.tr()); return; }
    if (_passwordController.text != _confirmPasswordController.text) { _showError('error_password_mismatch'.tr()); return; }
    if (_fullPhoneNumber.isEmpty) { _showError('error_empty_phone'.tr()); return; }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: _fullPhoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Bazı Android cihazlarda otomatik doğrulama yapabilir
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint("🔥 SMS HATASI GELDİ: ${e.code}");
          debugPrint("🔥 HATA MESAJI: ${e.message}");

          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("SMS Hatası: ${e.message}")),
            );
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _isLoading = false;
            _verificationId = verificationId;
          });
          _showOTPDialog();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showError(e.toString());
    }
  }

  // 2. ADIM: OTP Giriş Diyaloğu
  void _showOTPDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('verify_phone'.tr(), textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('enter_otp_sent'.tr(args: [_fullPhoneNumber])),
            const SizedBox(height: 20),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: "000000",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr(), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => _completeRegistration(),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
            child: Text('verify_and_register'.tr()),
          ),
        ],
      ),
    );
  }

  // 3. ADIM: Son Kayıt İşlemi
  Future<void> _completeRegistration() async {
    Navigator.pop(context);
    setState(() => _isLoading = true);

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: _otpController.text.trim(),
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      await _firebaseSignUp.signUpWithEmailAndPassword(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        phone: _fullPhoneNumber,
        classCode: _classCodeController.text.trim().isNotEmpty
            ? _classCodeController.text.trim()
            : null,
      );

      if (mounted) {
        _showSuccess('success_signup'.tr());
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) navigateToHome(context);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String errorMessage;
        switch (e.code) {
          case 'invalid-verification-code':
            errorMessage = 'error_invalid_otp'.tr();
            break;
          case 'session-expired':
            errorMessage = 'error_otp_expired'.tr();
            break;
          default:
            errorMessage = e.message ?? 'error_unknown'.tr();
        }
        _showError(errorMessage);
      }
    } catch (e) {
      if (mounted) {
        final errorString = e.toString();
        if (errorString.contains('STUDENT_LIMIT_REACHED')) {
          _showLimitErrorDialog();
        } else {
          _showError(errorString);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showLimitErrorDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Text('limit_reached'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
          ],
        ),
        content: Text('student_signup_limit_info'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('ok'.tr(), style: const TextStyle(color: Color(0xFF6366F1)))),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Color(0xFF1F2937)), onPressed: () => goBack(context)),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 32),
                _buildNameField(),
                const SizedBox(height: 16),
                _buildPhoneField(),
                const SizedBox(height: 16),
                _buildEmailField(),
                const SizedBox(height: 16),
                _buildPasswordField(),
                const SizedBox(height: 16),
                _buildConfirmPasswordField(),
                const SizedBox(height: 24),
                _buildInfoCard(),
                const SizedBox(height: 16),
                _buildClassCodeField(),
                const SizedBox(height: 16),
                _buildPolicyCheckbox(), // Onay kutusu eklendi
                const SizedBox(height: 24),
                _buildSignUpButton(),
                const SizedBox(height: 16),
                _buildSignInLink(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(children: [
      Text('create_account'.tr(), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
      const SizedBox(height: 8),
      Text('join_community'.tr(), style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
    ]);
  }

  Widget _buildNameField() {
    return TextField(
      controller: _nameController,
      keyboardType: TextInputType.name,
      decoration: InputDecoration(
        labelText: 'full_name'.tr(),
        hintText: 'enter_name'.tr(),
        prefixIcon: const Icon(Icons.person_outline),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
      ),
    );
  }

  Widget _buildPhoneField() {
    return IntlPhoneField(
      controller: _phoneController,
      initialCountryCode: 'TR',
      languageCode: context.locale.languageCode,
      onChanged: (phone) => _fullPhoneNumber = phone.completeNumber,
      decoration: InputDecoration(
        labelText: 'phone_optional'.tr(),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        counterText: '',
      ),
    );
  }

  Widget _buildEmailField() {
    return TextField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        labelText: 'email'.tr(),
        hintText: 'email_hint'.tr(),
        prefixIcon: const Icon(Icons.email_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordController,
      obscureText: !_isPasswordVisible,
      decoration: InputDecoration(
        labelText: 'password'.tr(),
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
      ),
    );
  }

  Widget _buildConfirmPasswordField() {
    return TextField(
      controller: _confirmPasswordController,
      obscureText: !_isConfirmPasswordVisible,
      decoration: InputDecoration(
        labelText: 'confirm_password'.tr(),
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(_isConfirmPasswordVisible ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
      ),
    );
  }

  Widget _buildClassCodeField() {
    return TextField(
      controller: _classCodeController,
      keyboardType: TextInputType.number,
      maxLength: 6,
      decoration: InputDecoration(
        labelText: 'class_code_optional'.tr(),
        prefixIcon: const Icon(Icons.key_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        counterText: '',
      ),
    );
  }

  Widget _buildPolicyCheckbox() {
    return Row(
      children: [
        SizedBox(
          height: 24,
          width: 24,
          child: Checkbox(
            value: _isPolicyAccepted,
            activeColor: const Color(0xFF6366F1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            onChanged: (value) => setState(() => _isPolicyAccepted = value ?? false),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(
            children: [
              Text('accept_terms_text'.tr(), style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              GestureDetector(
                onTap: () => _showPolicy('terms_of_service_title', 'terms_of_use_content'),
                child: Text(
                  'terms_of_service_title'.tr(),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6366F1), fontWeight: FontWeight.bold),
                ),
              ),
              Text('and'.tr(), style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              GestureDetector(
                onTap: () => _showPolicy('privacy_policy_title', 'privacy_policy_content'),
                child: Text(
                  'privacy_policy_title'.tr(),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6366F1), fontWeight: FontWeight.bold),
                ),
              ),
              Text('confirm_read_text'.tr(), style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.info_outline, color: Color(0xFF6366F1), size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text('mentor_info_text'.tr(), style: const TextStyle(fontSize: 12, color: Color(0xFF4338CA)))),
      ]),
    );
  }

  Widget _buildSignUpButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handleSignUp,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: _isLoading
          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Text('register_now'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildSignInLink() {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('already_have_account'.tr(), style: const TextStyle(color: Color(0xFF6B7280))),
      TextButton(onPressed: () => goBack(context), child: Text('login'.tr(), style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.w600))),
    ]);
  }
}