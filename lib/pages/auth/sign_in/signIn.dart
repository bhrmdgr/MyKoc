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
    // Post-frame callback kullanarak navigation'ı güvenli hale getir
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkExistingSession();
    });
  }

  Future<void> _checkExistingSession() async {
    if (!mounted) return;

    try {
      debugPrint('🔍 Checking existing session...');

      // Firebase current user kontrolü
      final currentUser = FirebaseAuth.instance.currentUser;
      final localUid = _localStorage.getUid();

      debugPrint('🔥 Firebase User: ${currentUser?.uid}');
      debugPrint('📦 Local UID: $localUid');

      // Eğer Firebase'de kullanıcı yoksa local'i temizle
      if (currentUser == null) {
        debugPrint('⚠️ No Firebase user, clearing local storage');
        await _localStorage.clearAll();
        if (mounted) {
          setState(() => _isCheckingSession = false);
        }
        return;
      }

      // Eğer Firebase'de kullanıcı var ama local'de yoksa
      if (localUid == null) {
        debugPrint('⚠️ Firebase user exists but local storage is empty, signing out');
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          setState(() => _isCheckingSession = false);
        }
        return;
      }

      // Her ikisi de varsa ve eşleşiyorsa
      if (currentUser.uid == localUid) {
        debugPrint('✅ Valid session found, navigating to home');
        if (mounted) {
          // setState kullanmadan direkt navigate et
          Future.microtask(() {
            if (mounted) {
              navigateToHome(context);
            }
          });
        }
        return;
      } else {
        debugPrint('⚠️ UID mismatch, clearing storage');
        await _localStorage.clearAll();
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          setState(() => _isCheckingSession = false);
        }
      }
    } catch (e) {
      debugPrint('❌ Error during session check: $e');
      // Hata durumunda her şeyi temizle
      await _localStorage.clearAll();
      try {
        await FirebaseAuth.instance.signOut();
      } catch (logoutError) {
        debugPrint('❌ Error during cleanup logout: $logoutError');
      }
      if (mounted) {
        setState(() => _isCheckingSession = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (_emailController.text.trim().isEmpty) {
      _showError('Lütfen e-posta adresinizi girin');
      return;
    }

    if (_passwordController.text.isEmpty) {
      _showError('Lütfen şifrenizi girin');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _firebaseSignIn.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        navigateToHome(context);
      }
    } catch (e) {
      if (mounted) {
        _showError(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Session kontrol edilirken loading göster
    if (_isCheckingSession) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildLogo(),
                const SizedBox(height: 48),
                _buildEmailField(),
                const SizedBox(height: 16),
                _buildPasswordField(),
                const SizedBox(height: 32),
                _buildSignInButton(),
                const SizedBox(height: 16),
                _buildSignUpLink(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.school_rounded,
            size: 40,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'MyKoc',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Mentörlük Platformu',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return TextField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        labelText: 'E-posta',
        hintText: 'ornek@email.com',
        prefixIcon: const Icon(Icons.email_outlined),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
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
        labelText: 'Şifre',
        hintText: '••••••••',
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(
            _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
          ),
          onPressed: () {
            setState(() => _isPasswordVisible = !_isPasswordVisible);
          },
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
      child: _isLoading
          ? const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      )
          : const Text(
        'Giriş Yap',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSignUpLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Hesabınız yok mu? ',
          style: TextStyle(color: Color(0xFF6B7280)),
        ),
        TextButton(
          onPressed: () {
            navigateToSignUp(context);
          },
          child: const Text(
            'Kayıt Ol',
            style: TextStyle(
              color: Color(0xFF6366F1),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}