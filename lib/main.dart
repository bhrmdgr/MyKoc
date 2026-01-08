import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart'; // ✅ Provider eklendi
import 'package:mykoc/firebase_options.dart';
import 'package:mykoc/pages/auth/sign_in/signIn.dart';
import 'package:mykoc/pages/main/main_screen.dart';
import 'package:mykoc/services/storage/local_storage_service.dart';
import 'package:mykoc/firebase/messaging/fcm_service.dart';
import 'package:mykoc/pages/home/homeViewModel.dart'; // ✅ ViewModel eklendi

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // Localization mutlaka başlamalı
  await EasyLocalization.ensureInitialized();

  // Firebase'i başlat
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    // Yan servisleri başlat
    _initSideServices();

    debugPrint('✅ Firebase ana modülü hazır');
  } catch (e) {
    debugPrint('❌ Firebase başlatılamadı: $e');
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('tr', 'TR'), Locale('en', 'US')],
      path: 'assets/translations',
      fallbackLocale: const Locale('tr', 'TR'),
      child: MultiProvider( // ✅ MultiProvider ile sarmalandı
        providers: [
          ChangeNotifierProvider(create: (_) => HomeViewModel()), // ✅ Global HomeViewModel
        ],
        child: const MyApp(),
      ),
    ),
  );
}

void _initSideServices() async {
  try {
    // 1. Önce LocalStorage
    await LocalStorageService().init();
    debugPrint('✅ LocalStorage hazır');

    // 2. FCM Temel Ayarları
    await FCMService().initialize();
    debugPrint('✅ FCM Temel Kurulum hazır');

    // 3. Kullanıcı giriş yapmışsa FCM işlemleri
    final uid = LocalStorageService().getUid();
    if (uid != null) {
      debugPrint('🚀 Giriş yapılmış kullanıcı bulundu, FCM Token alınıyor...');
      await FCMService().getToken();
      debugPrint('✅ FCM Token kontrolü tamamlandı');
    }
  } catch (e) {
    debugPrint('❌ Yan servisler başlatılırken hata: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6366F1)),
      ),
      home: const AuthStateHandler(),
    );
  }
}

class AuthStateHandler extends StatelessWidget {
  const AuthStateHandler({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        final user = snapshot.data;
        final localUid = LocalStorageService().getUid();

        if (user != null && localUid != null) {
          return const MainScreen();
        }

        return const Signin();
      },
    );
  }
}