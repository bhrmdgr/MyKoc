import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:mykoc/firebase_options.dart';
import 'package:mykoc/pages/auth/sign_in/signIn.dart';
import 'package:mykoc/pages/main/main_screen.dart';
import 'package:mykoc/services/storage/local_storage_service.dart';
import 'package:mykoc/firebase/messaging/fcm_service.dart';
import 'package:mykoc/pages/home/homeViewModel.dart';

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

    // Yan servisleri başlat ve bitmesini bekle
    await _initSideServices();

    debugPrint('✅ Firebase ana modülü hazır');
  } catch (e) {
    debugPrint('❌ Firebase başlatılamadı: $e');
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('tr', 'TR'), Locale('en', 'US')],
      path: 'assets/translations',
      fallbackLocale: const Locale('tr', 'TR'),
      child: const MyApp(),
    ),
  );
}

Future<void> _initSideServices() async {
  try {
    // 1. Önce LocalStorage
    await LocalStorageService().init();
    debugPrint('✅ LocalStorage hazır');

    // 2. FCM Temel Ayarları (Bildirim izinleri ve kanal kurulumu)
    await FCMService().initialize();
    debugPrint('✅ FCM Temel Kurulum hazır');

    // NOT: getToken() çağrısını buraya koymuyoruz,
    // çünkü henüz Auth durumu netleşmedi.
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
      // ✅ UniqueKey ile her locale değişiminde yeniden inşa et
      home: AuthStateHandler(key: ValueKey(context.locale.toString())),
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
        // Firebase User varsa, MainScreen'e yönlendir
        if (user != null) {
          // ✅ Her dil değişikliğinde yeni bir HomeViewModel instance'ı oluştur
          return ChangeNotifierProvider(
            create: (_) => HomeViewModel(),
            child: MainScreen(key: ValueKey(context.locale.toString())),
          );
        }

        return const Signin();
      },
    );
  }
}