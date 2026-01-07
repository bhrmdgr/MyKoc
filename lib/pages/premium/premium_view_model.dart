import 'package:flutter/material.dart';
import 'package:mykoc/firebase/premium/premium_service.dart';
import 'package:mykoc/services/storage/local_storage_service.dart';

class PremiumViewModel extends ChangeNotifier {
  final PremiumService _premiumService = PremiumService();
  final LocalStorageService _localStorage = LocalStorageService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  int _selectedPlanIndex = 1; // Varsayılan yıllık plan
  int get selectedPlanIndex => _selectedPlanIndex;

  /// Kullanıcının Premium olup olmadığını local storage'dan kontrol eder
  bool get isPremium {
    final mentorData = _localStorage.getMentorData();
    return (mentorData?['subscriptionTier'] ?? 'free') == 'premium';
  }

  void selectPlan(int index) {
    _selectedPlanIndex = index;
    notifyListeners();
  }

  /// PRO'ya Geç butonuna basıldığında çalışır
  Future<bool> handleSubscriptionAction() async {
    _isLoading = true;
    notifyListeners();

    try {
      final uid = _localStorage.getUid();
      if (uid == null) return false;

      // 1. ADIM: Ödeme Simülasyonu (2 saniye bekleme)
      await Future.delayed(const Duration(seconds: 2));

      // 2. ADIM: Firebase'de Premium yap
      final success = await _premiumService.upgradeToPremium(uid);

      if (success) {
        // 3. ADIM: Güncel veriyi Firestore'dan temizlenmiş şekilde al
        final newData = await _premiumService.getMentorData(uid);
        if (newData != null) {
          // 4. ADIM: Local Storage'ı güncelle (Böylece tüm uygulama Premium olduğumuzu bilir)
          await _localStorage.saveMentorData(newData);
        }
        notifyListeners(); // UI'ı güncelle
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("❌ ViewModel Subscription Error: $e");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Abonelik İptal İşlemi
  Future<bool> cancelSubscription() async {
    _isLoading = true;
    notifyListeners();

    try {
      final uid = _localStorage.getUid();
      if (uid == null) return false;

      final success = await _premiumService.cancelSubscription(uid);

      if (success) {
        final newData = await _premiumService.getMentorData(uid);
        if (newData != null) {
          await _localStorage.saveMentorData(newData);
        }
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("❌ ViewModel Cancel Error: $e");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}