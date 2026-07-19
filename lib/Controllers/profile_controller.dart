import 'dart:async';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Models/user_model.dart';
import 'package:money_control/Services/cache_service.dart';
import 'package:universal_io/io.dart';

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
    _userSub = _auth.userChanges().listen(
      (user) => currentUser.value = user,
      onError: (e) => debugPrint('ProfileController userChanges stream error: $e'),
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

  Future<void> pickAndUploadImage() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      isLoading.value = true;

      final String refPath = 'users/${user.uid}/profile.jpg';

      Uint8List imageBytes;
      if (kIsWeb) {
        final picked = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 70,
          maxWidth: 512,
          maxHeight: 512,
        );
        if (picked == null) {
          isLoading.value = false;
          return;
        }
        imageBytes = await picked.readAsBytes();
      } else {
        final XFile? image = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 70,
          maxWidth: 512,
          maxHeight: 512,
        );
        if (image == null) {
          isLoading.value = false;
          return;
        }
        final File file = File(image.path);
        imageBytes = await file.readAsBytes();
      }

      // 1. Upload to Storage
      final ref = _storage.ref().child(refPath);
      await ref.putData(imageBytes);
      final String downloadUrl = await ref.getDownloadURL();

      // 2. Update Auth (so currentUser.photoURL updates automatically)
      await user.updatePhotoURL(downloadUrl);
      await user.reload();
      photoURL.value = downloadUrl;

      final email = _userEmail;
      if (email == null) return;
      // 3. Update Firestore (optional, but good for redundancy)
      await _firestore.collection('users').doc(email).set({
        'photoURL': downloadUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      Get.snackbar(
        "Success",
        "Profile picture updated!",
        backgroundColor: AppColors.success,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: EdgeInsets.all(20.w),
        borderRadius: 20.r,
      );
    } catch (e) {
      Get.snackbar(
        "Error",
        "Failed to upload image: $e",
        backgroundColor: AppColors.error,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: EdgeInsets.all(20.w),
        borderRadius: 20.r,
      );
    } finally {
      isLoading.value = false;
    }
  }
}
