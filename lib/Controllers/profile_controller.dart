import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Models/user_model.dart';
import 'package:money_control/Services/cache_service.dart';

class ProfileController extends GetxController {
  static ProfileController get to => Get.find();

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _picker = ImagePicker();

  String? get _userEmail => _auth.currentUser?.email;
  String get _cacheKey => 'profile_${_userEmail ?? ''}';

  Rxn<User> currentUser = Rxn<User>();
  Rxn<UserModel> userProfile = Rxn<UserModel>();
  RxString photoURL = ''.obs;
  RxBool isLoading = false.obs;

  StreamSubscription? _userSub;
  late final Worker _workerUpdateUser;

  @override
  void onInit() {
    super.onInit();
    _userSub = _auth.userChanges().listen((user) => currentUser.value = user);
    _workerUpdateUser = ever(currentUser, _updateUser);

    _loadFromCache();
    if (_auth.currentUser != null && _auth.currentUser?.email != null) {
      _fetchFromFirestore(_auth.currentUser!.email!);
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
    if (cached != null) {
      final map = LocalCacheService.hiveRestore(Map<String, dynamic>.from(cached as Map));
      userProfile.value = UserModel.fromMap(map['_id'] as String? ?? '', map);
    }
  }

  Future<void> _fetchFromFirestore(String email) async {
    try {
      final snapshot = await _firestore.collection('users').doc(email).get();
      if (snapshot.exists && snapshot.data() != null) {
        userProfile.value = UserModel.fromMap(snapshot.id, snapshot.data());
        final cacheMap = LocalCacheService.hiveSafe(snapshot.data()!);
        cacheMap['_id'] = snapshot.id;
        LocalCacheService.put(_cacheKey, cacheMap, ttl: LocalCacheService.slow5m);
      }
    } catch (_) {
    }
  }

  void _updateUser(User? user) {
    if (user != null) {
      photoURL.value = user.photoURL ?? '';
    } else {
      photoURL.value = '';
    }
  }

  Future<void> pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 512,
        maxHeight: 512,
      );

      if (image == null) return;

      final user = _auth.currentUser;
      if (user == null) return;

      isLoading.value = true;
      final File file = File(image.path);
      final String refPath = 'users/${user.uid}/profile.jpg';

      // 1. Upload to Storage
      final ref = _storage.ref().child(refPath);
      await ref.putFile(file);
      final String downloadUrl = await ref.getDownloadURL();

      // 2. Update Auth (so currentUser.photoURL updates automatically)
      await user.updatePhotoURL(downloadUrl);
      await user.reload();
      photoURL.value = downloadUrl;

      // 3. Update Firestore (optional, but good for redundancy)
      await _firestore.collection('users').doc(user.email).set({
        'photoURL': downloadUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      Get.snackbar(
        "Success",
        "Profile picture updated!",
        backgroundColor: AppColors.success,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(20),
        borderRadius: 20,
      );
    } catch (e) {
      Get.snackbar(
        "Error",
        "Failed to upload image: $e",
        backgroundColor: AppColors.error,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(20),
        borderRadius: 20,
      );
    } finally {
      isLoading.value = false;
    }
  }
}
