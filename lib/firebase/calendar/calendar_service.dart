import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:mykoc/pages/calendar/calendar_note_model.dart';

class CalendarService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Not kaydet veya güncelle
  Future<bool> saveNote({
    required String userId,
    required DateTime date,
    required String content,
  }) async {
    try {
      // Tarihi saatten arındır (Sadece Yıl-Ay-Gün önemli)
      final normalizedDate = DateTime(date.year, date.month, date.day);
      final docId = '${userId}_${normalizedDate.millisecondsSinceEpoch}';

      await _firestore.collection('calendar_notes').doc(docId).set({
        'id': docId,
        'userId': userId,
        'date': Timestamp.fromDate(normalizedDate),
        'content': content,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Note saved to Firebase');
      return true;
    } catch (e) {
      debugPrint('❌ Error saving note: $e');
      return false;
    }
  }

  /// Not sil
  Future<bool> deleteNote(String userId, DateTime date) async {
    try {
      final normalizedDate = DateTime(date.year, date.month, date.day);
      final docId = '${userId}_${normalizedDate.millisecondsSinceEpoch}';

      await _firestore.collection('calendar_notes').doc(docId).delete();
      debugPrint('✅ Note deleted from Firebase');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting note: $e');
      return false;
    }
  }

  /// Kullanıcının tüm notlarını çek (Genellikle ay değiştiğinde veya ilk açılışta çağrılır)
  Future<List<CalendarNoteModel>> getUserNotes(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('calendar_notes')
          .where('userId', isEqualTo: userId)
          .get();

      return snapshot.docs
          .map((doc) => CalendarNoteModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching notes: $e');
      return [];
    }
  }
}