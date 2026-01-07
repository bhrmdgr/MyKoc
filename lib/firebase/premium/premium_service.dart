import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class PremiumService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Kullanıcıyı Firestore'da Premium yapar ve limitleri tanımlar
  Future<bool> upgradeToPremium(String uid) async {
    try {
      await _firestore.collection('mentors').doc(uid).update({
        'subscriptionTier': 'premium',
        'maxClasses': 15,
        'maxStudentsPerClass': 30,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('❌ PremiumService Upgrade Error: $e');
      return false;
    }
  }

  /// Aboneliği ücretsiz plana geri çeker
  Future<bool> cancelSubscription(String uid) async {
    try {
      await _firestore.collection('mentors').doc(uid).update({
        'subscriptionTier': 'free',
        'maxClasses': 1,
        'maxStudentsPerClass': 5,
        'subscriptionEndDate': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('❌ PremiumService Cancel Error: $e');
      return false;
    }
  }

  /// Firestore'dan veriyi çeker ve Timestamp hatasını önlemek için veriyi temizler
  Future<Map<String, dynamic>?> getMentorData(String uid) async {
    try {
      final doc = await _firestore.collection('mentors').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final data = Map<String, dynamic>.from(doc.data()!);

        // JSON hatasını (Timestamp hatası) engellemek için dönüşüm yapıyoruz
        data.forEach((key, value) {
          if (value is Timestamp) {
            data[key] = value.toDate().toIso8601String();
          }
        });
        return data;
      }
      return null;
    } catch (e) {
      debugPrint('❌ PremiumService GetData Error: $e');
      return null;
    }
  }
}