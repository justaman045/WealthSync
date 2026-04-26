import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Models/user_model.dart';

class ProfileController extends GetxController {
  static ProfileController get to => Get.find();

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _picker = ImagePicker();

  Rxn<User> currentUser = Rxn<User>();
  Rxn<UserModel> userProfile = Rxn<UserModel>(); // Added userProfile
  RxString photoURL = ''.obs;
  RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    currentUser.bindStream(_auth.userChanges());
    ever(currentUser, _updateUser);

    // Bind user profile stream
    if (_auth.currentUser != null) {
      _bindUserProfile(_auth.currentUser!.email);
    }

    // Re-bind if user changes (e.g. login/logout)
    ever(currentUser, (user) {
      if (user != null) {
        _bindUserProfile(user.email);
      } else {
        userProfile.value = null;
      }
    });
  }

  void _bindUserProfile(String? email) {
    if (email == null) return;
    userProfile.bindStream(
      _firestore.collection('users').doc(email).snapshots().map((snapshot) {
        if (snapshot.exists) {
          return UserModel.fromMap(snapshot.id, snapshot.data());
        }
        return null;
      }),
    );
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
        imageQuality: 70, // Optimize size
        maxWidth: 512,
        maxHeight: 512,
      );

      if (image == null) return;

      isLoading.value = true;
      final File file = File(image.path);
      final String uid = _auth.currentUser!.uid;
      final String refPath = 'users/$uid/profile.jpg';

      // 1. Upload to Storage
      final ref = _storage.ref().child(refPath);
      await ref.putFile(file);
      final String downloadUrl = await ref.getDownloadURL();

      // 2. Update Auth (so currentUser.photoURL updates automatically)
      await _auth.currentUser!.updatePhotoURL(downloadUrl);
      await _auth.currentUser!.reload(); // Refresh local user
      photoURL.value = downloadUrl;

      // 3. Update Firestore (optional, but good for redundancy)
      await _firestore.collection('users').doc(_auth.currentUser!.email).set({
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
