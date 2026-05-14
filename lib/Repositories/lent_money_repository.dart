import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:money_control/Models/lent_money_model.dart';

class LentMoneyRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userEmail => _auth.currentUser?.email;

  CollectionReference get _userLentMoneyRef {
    if (_userEmail == null) throw Exception("User not logged in");
    return _firestore
        .collection('users')
        .doc(_userEmail)
        .collection('lent_money');
  }

  Future<DocumentReference> addEntry(LentMoneyModel entry) async {
    return await _userLentMoneyRef.add(entry.toMap());
  }

  Future<void> updateEntry(LentMoneyModel entry) async {
    if (entry.id.isEmpty) throw Exception("Entry ID is empty");
    await _userLentMoneyRef.doc(entry.id).update(entry.toMap());
  }

  Future<void> deleteEntry(String id) async {
    await _userLentMoneyRef.doc(id).delete();
  }

  Future<List<LentMoneyModel>> getEntries() async {
    final snap = await _userLentMoneyRef
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((doc) {
      return LentMoneyModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
    }).toList();
  }

  Stream<List<LentMoneyModel>> getEntriesStream() {
    return _userLentMoneyRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .handleError((e) => debugPrint('LentMoneyStream error: $e'))
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return LentMoneyModel.fromMap(
              doc.id,
              doc.data() as Map<String, dynamic>,
            );
          }).toList();
        });
  }
}
