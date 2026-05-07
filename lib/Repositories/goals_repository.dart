import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:money_control/Models/goal_model.dart';

class GoalsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userEmail => _auth.currentUser?.email;

  CollectionReference get _ref {
    if (_userEmail == null) throw Exception("User not logged in");
    return _firestore.collection('users').doc(_userEmail).collection('goals');
  }

  Stream<List<GoalModel>> getGoalsStream() {
    return _ref
        .orderBy('createdAt', descending: true)
        .snapshots()
        .handleError((e) => debugPrint('GoalsStream error: $e'))
        .map((snap) => snap.docs
            .map((doc) => GoalModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
            .toList());
  }

  Future<DocumentReference> addGoal(GoalModel goal) => _ref.add(goal.toMap());

  Future<void> updateGoal(GoalModel goal) =>
      _ref.doc(goal.id).update(goal.toMap());

  Future<void> deleteGoal(String id) => _ref.doc(id).delete();

  Future<GoalModel?> addProgress(String id, double addAmount) {
    return _firestore.runTransaction<GoalModel?>((txn) async {
      final docRef = _ref.doc(id);
      final snap = await txn.get(docRef);
      if (!snap.exists) return null;
      final goal = GoalModel.fromMap(snap.id, snap.data() as Map<String, dynamic>);
      final newAmount = (goal.currentAmount + addAmount).clamp(0.0, goal.targetAmount);
      final completed = newAmount >= goal.targetAmount;
      final updated = goal.copyWith(currentAmount: newAmount, isCompleted: completed);
      txn.update(docRef, {'currentAmount': newAmount, 'isCompleted': completed});
      return updated;
    });
  }
}
