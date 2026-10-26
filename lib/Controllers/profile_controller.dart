import 'dart:async';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:money_control/Models/user_model.dart';
import 'package:money_control/Services/cache_service.dart';

class ProfileController extends GetxController {
  static ProfileController get to => Get.find();

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  String? get _userEmail => _auth.currentUser?.email;
  String get _cacheKey => 'profile_${_userEmail ?? ''}';

  Rxn<User> currentUser = Rxn<User>();
  Rxn<UserModel> userProfile = Rxn<UserModel>();
  RxString photoURL = ''.obs;

  StreamSubscription? _userSub;
  late final Worker _workerUpdateUser;

  @override
  void onInit() {
    super.onInit();
    _userSub = _auth.userChanges().listen(
      (user) => currentUser.value = user,
      onError: (e) => log('ProfileController userChanges stream error: $e'),
    );
    _workerUpdateUser = ever(currentUser, _updateUser);

    _loadFromCache();
    final email = _userEmail;
    if (email != null) {
      _fetchFromFirestore(email);
    }
  }

  @override
  void onClose() {
    _workerUpdateUser.dispose();
    _userSub?.cancel();
    super.onClose();
  }

  void _loadFromCache() {
    final cached = LocalCacheService.get(_cacheKey);
    if (cached is Map) {
      final map = LocalCacheService.hiveRestore(Map<String, dynamic>.from(cached));
      userProfile.value = UserModel.fromMap(map['_id']?.toString() ?? '', map);
    }
    LocalCacheService.invalidate(_cacheKey);
  }

  /// Re-fetches the user's Firestore document so UI (e.g. home name) reflects
  /// edits saved by the profile screen without an app restart.
  Future<void> refreshFromFirestore() async {
    final email = _userEmail;
    if (email == null) return;
    await _fetchFromFirestore(email);
  }

  Future<void> _fetchFromFirestore(String email) async {
    try {
      final snapshot = await _firestore.collection('users').doc(email).get();
      if (snapshot.exists && snapshot.data() != null) {
        userProfile.value = UserModel.fromMap(snapshot.id, snapshot.data());
        final cacheMap = LocalCacheService.hiveSafe(snapshot.data()!);
        cacheMap['_id'] = snapshot.id;
        await LocalCacheService.put(_cacheKey, cacheMap, ttl: LocalCacheService.slow5m);
      }
    } catch (e) {
      log('ProfileController._fetchFromFirestore error: $e');
    }
  }

  void _updateUser(User? user) {
    if (user != null) {
      photoURL.value = user.photoURL ?? '';
    } else {
      photoURL.value = '';
    }
  }
}
