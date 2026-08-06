import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/provider.dart';

/// Accès à la collection Firestore `providers` (cahier des charges §5).
///
/// Les grilles tarifaires vivent en base plutôt que dans le code pour
/// pouvoir être mises à jour à distance sans repasser par la review
/// Apple/Google (§6).
class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _providersRef =>
      _firestore.collection('providers');

  Future<List<TpeProvider>> getProviders() async {
    final snapshot = await _providersRef.get();
    return snapshot.docs.map(TpeProvider.fromFirestore).toList();
  }

  Stream<List<TpeProvider>> watchProviders() {
    return _providersRef
        .snapshots()
        .map((s) => s.docs.map(TpeProvider.fromFirestore).toList());
  }

  Future<TpeProvider?> getProvider(String id) async {
    final doc = await _providersRef.doc(id).get();
    if (!doc.exists) return null;
    return TpeProvider.fromFirestore(doc);
  }
}
