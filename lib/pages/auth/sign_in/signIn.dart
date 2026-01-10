import 'package:easy_localization/easy_localization.dart' show StringTranslateExtension, BuildContextEasyLocalizationExtension;
import 'package:flutter/material.dart';
import 'package:mykoc/routers/appRouter.dart';
import 'package:mykoc/firebase/auth/firebaseSignIn.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mykoc/services/storage/local_storage_service.dart';

class Signin extends StatefulWidget {
  const Signin({super.key});

  @override
  State<Signin> createState() => _SigninState();
}

class _SigninState extends State<Signin> {
  final _firebaseSignIn = FirebaseSignIn();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _localStorage = LocalStorageService();

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isCheckingSession = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkExistingSession();
    });
  }

  // --- DİL SEÇİMİ ---
  void _showLanguagePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20), // Düzeltildi
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'select_language'.tr(),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              _buildLanguageOption("🇹🇷", "Türkçe", const Locale('tr', 'TR')),
              _buildLanguageOption("🇺🇸", "English", const Locale('en', 'US')),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption(String flag, String title, Locale locale) {
    bool isSelected = context.locale == locale;
    return ListTile(
      leading: Text(flag, style: const TextStyle(fontSize: 24)),
      title: Text(title, style: TextStyle(
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? const Color(0xFF6366F1) : Colors.black87,
      )),
      trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFF6366F1)) : null,
      onTap: () {
        context.setLocale(locale);
        Navigator.pop(context);
      },
    );
  }

  // --- ŞİFRE SIFIRLAMA DİYALOĞU ---
  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController();
    if (_emailController.text.isNotEmpty) {
      resetEmailController.text = _emailController.text;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('reset_password'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('reset_password_info'.tr()),
            const SizedBox(height: 16),
            TextField(
              controller: resetEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'email'.tr(),
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
            onPressed: () async {
              if (resetEmailController.text.isEmpty) return;
              Navigator.pop(context);
              try {
                // Servisinizdeki fonksiyonu çağırıyoruz
                await _firebaseSignIn.resetPassword(email: resetEmailController.text.trim());
                _showSuccess('password_reset_sent'.tr());
              } catch (e) {
                _showError(e.toString());
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
            child: Text('send'.tr()),
          ),
        ],
      ),
    );
  }

  // --- OTURUM KONTROLÜ ---
  Future<void> _checkExistingSession() async {
    if (!mounted) return;
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final localUid = _localStorage.getUid();
      if (currentUser == null) {
        await _localStorage.clearAll();
        if (mounted) setState(() => _isCheckingSession = false);
        return;
      }
      if (localUid == null) {
        await FirebaseAuth.instance.signOut();
        if (mounted) setState(() => _isCheckingSession = false);
        return;
      }
      if (currentUser.uid == localUid) {
        if (mounted) Future.microtask(() => navigateToHome(context));
        return;
      } else {
        await _localStorage.clearAll();
        await FirebaseAuth.instance.signOut();
        if (mounted) setState(() => _isCheckingSession = false);
      }
    } catch (e) {
      await _localStorage.clearAll();
      try { await FirebaseAuth.instance.signOut(); } catch (_) {}
      if (mounted) setState(() => _isCheckingSession = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (_emailController.text.trim().isEmpty) { _showError('error_empty_email'.tr()); return; }
    if (_passwordController.text.isEmpty) { _showError('error_empty_password'.tr()); return; }
    setState(() => _isLoading = true);
    try {
      await _firebaseSignIn.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted) navigateToHome(context);
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingSession) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _showLanguagePicker,
            icon: const Icon(Icons.language, size: 20, color: Color(0xFF6366F1)),
            label: Text(
              context.locale.languageCode.toUpperCase(),
              style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildLogo(),
              const SizedBox(height: 48),
              _buildEmailField(),
              const SizedBox(height: 16),
              _buildPasswordField(),
              _buildForgotPassword(), // Şifremi unuttum butonu
              const SizedBox(height: 24),
              _buildSignInButton(),
              const SizedBox(height: 16),
              _buildSignUpLink(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(color: const Color(0xFF6366F1), borderRadius: BorderRadius.circular(20)),
          child: const Icon(Icons.school_rounded, size: 40, color: Colors.white),
        ),
        const SizedBox(height: 16),
        const Text('MyKoc', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
        const SizedBox(height: 8),
        Text('mentorship_platform'.tr(), style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
      ],
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
        filled: true, fillColor: const Color(0xFFF9FAFB),
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordController,
      obscureText: !_isPasswordVisible,
      decoration: InputDecoration(
        labelText: 'password'.tr(),
        hintText: '••••••••',
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true, fillColor: const Color(0xFFF9FAFB),
      ),
    );
  }

  Widget _buildForgotPassword() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: _showForgotPasswordDialog,
        child: Text(
          'forgot_password_question'.tr(),
          style: const TextStyle(
            color: Color(0xFF6366F1),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildSignInButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handleSignIn,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      child: _isLoading
          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
          : Text('login_button'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildSignUpLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('no_account'.tr(), style: const TextStyle(color: Color(0xFF6B7280))),
        TextButton(
          onPressed: () => navigateToSignUp(context),
          child: Text('register_now'.tr(), style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}