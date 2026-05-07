import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:money_control/Models/challenge_model.dart';

class ChallengeRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _col {
    final email = _auth.currentUser?.email;
    if (email == null) throw Exception("Not logged in");
    return _db.collection('users').doc(email).collection('challenges');
  }

  Stream<List<SavingsChallengeModel>> getChallengesStream() {
    return _col
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .handleError((e) => debugPrint('ChallengesStream error: $e'))
        .map((snap) => snap.docs
            .map((d) => SavingsChallengeModel.fromMap(d.id, d.data()))
            .toList());
  }

  Future<DocumentReference> addChallenge(SavingsChallengeModel c) {
    return _col.add(c.toMap());
  }

  Future<void> updateChallenge(SavingsChallengeModel c) {
    return _col.doc(c.id).update(c.toMap());
  }

  Future<void> deleteChallenge(String id) {
    return _col.doc(id).delete();
  }
}
