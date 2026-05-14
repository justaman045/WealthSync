import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:money_control/Models/loan_model.dart';

class LoanRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userEmail => _auth.currentUser?.email;

  CollectionReference get _ref {
    if (_userEmail == null) throw Exception("User not logged in");
    return _firestore.collection('users').doc(_userEmail).collection('loans');
  }

  Future<List<LoanModel>> getLoans() async {
    final snap = await _ref
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs
        .map((doc) => LoanModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
        .toList();
  }

  Stream<List<LoanModel>> getLoansStream() {
    return _ref
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .handleError((e) => debugPrint('LoansStream error: $e'))
        .map((snap) => snap.docs
            .map((doc) =>
                LoanModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
            .toList());
  }

  Future<DocumentReference> addLoan(LoanModel loan) => _ref.add(loan.toMap());

  Future<void> updateLoan(LoanModel loan) =>
      _ref.doc(loan.id).update(loan.toMap());

  Future<void> deleteLoan(String id) =>
      _ref.doc(id).update({'isActive': false});
}
