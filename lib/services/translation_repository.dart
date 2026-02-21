import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TranslationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<Map<String, dynamic>?> checkCache(String hash) async {
    final docRef = _firestore.collection('translated_files').doc(hash);
    final docSnapshot = await docRef.get();
    if (docSnapshot.exists) {
      return docSnapshot.data();
    }
    return null;
  }

  /// Global önbellekte (diğer kullanıcıların çevirileri) arama yapar
  Future<Map<String, dynamic>?> checkGlobalCache({
    required String sourceHash,
    required String targetLanguage,
  }) async {
    try {
      final docRef = _firestore
          .collection('global_translations')
          .doc('${sourceHash}_$targetLanguage');
      
      final doc = await docRef.get();
      if (doc.exists) {
        return doc.data();
      }
    } catch (e) {
      // Hata durumunda null dön, akışı bozma
    }
    return null;
  }

  /// Başarılı çeviriyi global önbelleğe kaydeder
  Future<void> saveToGlobalCache({
    required String sourceHash,
    required String sourceContent,
    required String translatedContent,
    required String originalName,
    required String targetLanguage,
    String? encodingDetected,
  }) async {
    final user = _auth.currentUser;
    // Anonim kullanıcılar da cache'e katkıda bulunabilir veya okuyabilir
    
    try {
      await _firestore.collection('global_translations').doc('${sourceHash}_$targetLanguage').set({
        'sourceHash': sourceHash,
        'translatedContent': translatedContent,
        'originalName': originalName,
        'targetLanguage': targetLanguage,
        'encoding': encodingDetected,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user?.uid ?? 'anonymous',
      });
    } catch (_) {}
  }

  /// Kullanıcının kişisel geçmişine ekler
  Future<void> addToUserHistory({
    required String sourceHash,
    required String fileName,
    required String targetLanguage,
    bool isPartial = false,
    String? encodingDetected,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return; // Sadece giriş yapmış kullanıcılar için history tutulur

    try {
      // Dosya yolunu ID olarak kullanmak yerine hash+lang veya unique ID kullanılabilir
      // Ancak mevcut yapıda ID yönetimi ProjectManager tarafında yapılıyor olabilir.
      // Burada sadece log tutuyoruz.
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('history')
          .add({
        'fileName': fileName,
        'sourceHash': sourceHash,
        'targetLanguage': targetLanguage,
        'isPartial': isPartial,
        'encoding': encodingDetected,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // Proje silme işlemleri için placeholder (ProjectManager kullanıyor)
  Future<void> deleteFromUserHistory({required String historyDocId}) async {
    // Implementation needed based on ID structure
  }

  Future<void> clearAllUserHistory() async {
    // Implementation needed
  }
}