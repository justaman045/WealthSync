import 'package:money_control/Components/profile_avatar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:money_control/Controllers/profile_controller.dart';
import 'package:money_control/Controllers/tutorial_controller.dart';
import 'package:money_control/Services/error_handler.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Utils/responsive.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final ProfileController _profileController;
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  // final TextEditingController _ageController = TextEditingController(); // Replaced by DOB
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  DateTime? _dob;
  String? _gender;

  bool _isLoading = false;

  // Fetch Firestore data for the current user
  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('users').doc(user.email).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;

        if (mounted) {
          setState(() {
            _firstNameController.text = data['firstName'] ?? user.displayName;
            _lastNameController.text = data['lastName'] ?? '';
            _phoneController.text = data['phone'] ?? '';
            _addressController.text = data['address'] ?? '';
            _gender = data['gender'] as String?;

            final dob = data['dob'];
            if (dob is Timestamp) {
              _dob = dob.toDate();
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading user data: $e");
    }
  }

  Future<void> _saveUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _firestore.collection('users').doc(user.email).set({
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'gender': _gender,
        'dob': _dob != null ? Timestamp.fromDate(_dob!) : null,
        'age': _dob != null ? _calculateAge(_dob!) : null,
        'email': user.email, // auto from auth
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); // keep existing fields

      if (mounted && !TutorialController.isTestMode) {
        ErrorHandler.showSuccess("Profile updated successfully");
      }
      if (mounted) setState(() => _isLoading = false);
      await _profileController.refreshFromFirestore();
    } catch (e) {
      debugPrint("Error saving user data: $e");
      if (mounted) setState(() => _isLoading = false);

      ErrorHandler.showError("Error saving profile: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<ProfileController>()) {
      Get.put(ProfileController());
    }
    _profileController = Get.find<ProfileController>();
    _loadUserData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark ? AppColors.darkGradient : AppColors.lightGradient,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleSpacing: 0,
          iconTheme: IconThemeData(
            color: isDark ? Colors.white : AppColors.lightTextPrimary,
          ),
          title: Text(
            "Edit Profile",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
              fontSize: 18.sp,
              letterSpacing: 0.5,
            ),
          ),
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
              size: 19.sp,
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
            ),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          centerTitle: true,
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: Responsive.contentMaxWidth(context),
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: 20.w,
                      vertical: 10.h,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          SizedBox(height: 20.h),

                          // Avatar with Glow
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Obx(() {
                                final url = _profileController.photoURL.value;
                                final isLoading =
                                    _profileController.isLoading.value;
                                return Hero(
                                  tag: 'profile_pic',
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary.withValues(
                                            alpha: 0.3,
                                          ),
                                          blurRadius: 20.w,
                                          spreadRadius: 2.w,
                                        ),
                                      ],
                                    ),
                                    child: AppAvatar(
                                      url: url,
                                      size: 100.r,
                                      overlay: isLoading
                                          ? Padding(
                                              padding: EdgeInsets.all(24.r),
                                              child: const Center(
                                                child:
                                                    CircularProgressIndicator(
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            )
                                          : null,
                                    ),
                                  ),
                                );
                              }),
                              GestureDetector(
                                onTap: _profileController.pickAndUploadImage,
                                child: Container(
                                  height: 32.r,
                                  width: 32.r,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    border: Border.all(
                                      color: AppColors.darkBackground,
                                      width: 3,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.camera_alt_rounded,
                                    size: 16.sp,
                                    color: AppColors.darkBackground,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 40.h),

                          // Editable fields
                          _buildGlassTextField(
                            label: "First Name",
                            controller: _firstNameController,
                            isDark: isDark,
                            validator: (value) {
                              final v = value?.trim() ?? '';
                              if (v.isEmpty) return "First name is required";
                              if (v.length > 50) return "Max 50 characters";
                              return null;
                            },
                          ),
                          _buildGlassTextField(
                            label: "Last Name",
                            controller: _lastNameController,
                            isDark: isDark,
                            validator: (value) {
                              final v = value?.trim() ?? '';
                              if (v.length > 50) return "Max 50 characters";
                              return null;
                            },
                          ),
                          _buildDatePickerField(
                            label: "Date of Birth",
                            selectedDate: _dob,
                            isDark: isDark,
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _dob ?? DateTime(2000),
                                firstDate: DateTime(1900),
                                lastDate: DateTime.now(),
                                builder: (context, child) {
                                  final isDark = Get.isDarkMode;
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: isDark
                                          ? const ColorScheme.dark(
                                              primary: AppColors.secondary,
                                              onPrimary: Colors.black,
                                              surface: AppColors.darkSurface,
                                              onSurface:
                                                  AppColors.darkTextPrimary,
                                            )
                                          : const ColorScheme.light(
                                              primary: AppColors.primary,
                                              onPrimary: Colors.white,
                                              surface: AppColors.lightSurface,
                                              onSurface:
                                                  AppColors.lightTextPrimary,
                                            ),
                                      dialogTheme: DialogThemeData(
                                        backgroundColor: isDark
                                            ? AppColors.darkSurface
                                            : AppColors.lightSurface,
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null) {
                                setState(() => _dob = picked);
                              }
                            },
                          ),
                          // Show Age separately if needed, or integrated into the label above?
                          // User said "only dob is visible to the user".
                          // But also "getting the dob ... then calculating the age".
                          // I'll show Age as a read-only info snippet below DOB or inside it.
                          if (_dob != null)
                            Padding(
                              padding: EdgeInsets.only(bottom: 20.h),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  "Age: ${_calculateAge(_dob!)} years",
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          _buildGenderPicker(isDark: isDark),
                          _buildGlassTextField(
                            label: "Email",
                            value: user?.email ?? '',
                            enabled: false,
                            isDark: isDark,
                          ),
                          _buildGlassTextField(
                            label: "Phone Number",
                            controller: _phoneController,
                            isDark: isDark,
                            validator: (value) {
                              final v = value?.trim() ?? '';
                              if (v.isEmpty) return null;
                              if (!RegExp(r'^\+?\d{6,13}$').hasMatch(v)) {
                                return "Enter a valid phone number";
                              }
                              return null;
                            },
                          ),
                          _buildGlassTextField(
                            label: "Address",
                            controller: _addressController,
                            isDark: isDark,
                            validator: (value) {
                              final v = value?.trim() ?? '';
                              if (v.length > 200) return "Max 200 characters";
                              return null;
                            },
                          ),

                          SizedBox(height: 32.h),

                          // Save Button
                          GestureDetector(
                            onTap: _saveUserData,
                            child: Container(
                              width: double.infinity,
                              height: 56.h,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    AppColors.primary,
                                    AppColors.primary,
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(28.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.4,
                                    ),
                                    blurRadius: 15.w,
                                    offset: Offset(0, 8.w),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "SAVE CHANGES",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16.sp,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: 20.h),

                          // Change Password
                          SizedBox(
                            width: double.infinity,
                            height: 56.h,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: BorderSide(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.3)
                                      : AppColors.lightBorder,
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28.r),
                                ),
                              ),
                              onPressed: () async {
                                final email = user?.email;
                                if (email != null) {
                                  await _auth.sendPasswordResetEmail(
                                    email: email,
                                  );
                                  ErrorHandler.showSuccess(
                                    'Password reset link sent to your email',
                                  );
                                }
                              },
                              child: Text(
                                "Change Password",
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.lightTextPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15.sp,
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: 30.h),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildGlassTextField({
    required String label,
    TextEditingController? controller,
    String? value,
    bool enabled = true,
    bool isDark = true,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8.h),
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.2),
            ),
          ),
          child: TextFormField(
            controller: controller,
            enabled: enabled,
            initialValue: controller == null ? value ?? '' : null,
            validator: enabled ? validator : null,
            style: TextStyle(
              fontSize: 16.sp,
              color: enabled
                  ? (isDark ? Colors.white : AppColors.lightTextPrimary)
                  : (isDark ? Colors.white38 : AppColors.lightTextSecondary),
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 16.h,
              ),
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              hintStyle: TextStyle(
                fontSize: 16.sp,
                color: isDark ? Colors.white24 : AppColors.lightTextTertiary,
              ),
            ),
          ),
        ),
        SizedBox(height: 20.h),
      ],
    );
  }

  Widget _buildGenderPicker({required bool isDark}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Gender",
          style: TextStyle(
            color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.2),
            ),
          ),
          child: DropdownButton<String>(
            value: _gender,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            icon: Icon(
              Icons.arrow_drop_down_rounded,
              color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
            ),
            dropdownColor: isDark
                ? AppColors.darkSurface
                : AppColors.lightSurface,
            style: TextStyle(
              fontSize: 16.sp,
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
            ),
            items: const [
              DropdownMenuItem(value: 'male', child: Text("Male")),
              DropdownMenuItem(value: 'female', child: Text("Female")),
              DropdownMenuItem(value: 'other', child: Text("Other")),
              DropdownMenuItem(
                value: 'prefer_not_to_say',
                child: Text("Prefer not to say"),
              ),
            ],
            onChanged: (val) {
              setState(() => _gender = val);
            },
            hint: Text(
              "Select Gender",
              style: TextStyle(
                fontSize: 16.sp,
                color: isDark ? Colors.white38 : AppColors.lightTextSecondary,
              ),
            ),
          ),
        ),
        SizedBox(height: 20.h),
      ],
    );
  }

  Widget _buildDatePickerField({
    required String label,
    required DateTime? selectedDate,
    required VoidCallback onTap,
    bool isDark = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8.h),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  selectedDate != null
                      ? "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}"
                      : "Select Date",
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: selectedDate != null
                        ? (isDark ? Colors.white : AppColors.lightTextPrimary)
                        : (isDark
                              ? Colors.white38
                              : AppColors.lightTextSecondary),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Icon(
                  Icons.calendar_today_rounded,
                  color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
                  size: 20.sp,
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 20.h),
      ],
    );
  }

  int _calculateAge(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }
}
