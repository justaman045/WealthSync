import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:money_control/Models/transaction.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Services/budget_service.dart';
import 'package:money_control/Services/error_handler.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Services/receipt_platform.dart';
import 'package:universal_io/io.dart';

class ReceiptScanPage extends StatefulWidget {
  const ReceiptScanPage({super.key});

  @override
  State<ReceiptScanPage> createState() => _ReceiptScanPageState();
}

class _ReceiptScanPageState extends State<ReceiptScanPage> {
  File? _imageFile;
  String? _recognizedText;
  bool _scanning = false;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    if (kIsWeb) {
      ErrorHandler.showError("Camera and gallery not available in browser");
      return;
    }
    final pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 80,
    );
    if (pickedFile == null) return;

    setState(() {
      _imageFile = File(pickedFile.path);
      _recognizedText = null;
      _scanning = true;
    });

    await _performTextRecognition(_imageFile!);
  }

  Future<void> _performTextRecognition(File imageFile) async {
    if (kIsWeb) return;
    final inputImage = InputImage.fromFile(imageFile);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );
      if (mounted) {
        setState(() {
          _recognizedText = recognizedText.text;
          _scanning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _recognizedText = "Failed to recognize text: $e";
          _scanning = false;
        });
      }
    } finally {
      textRecognizer.close();
    }
  }

  void _onSave() async {
    if (_recognizedText == null || _recognizedText!.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No scanned text to save.")));
      return;
    }

    double? amount = _extractAmount(_recognizedText!);
    String category = _extractCategory(_recognizedText!) ?? 'General';
    DateTime date = _extractDate(_recognizedText!) ?? DateTime.now();
    String note = _recognizedText!;

    if (amount == null) {
      ErrorHandler.showError("Unable to extract amount. Please edit manually.");
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.email)
          .collection('transactions')
          .doc();

      final transaction = TransactionModel(
        id: docRef.id,
        senderId: user.uid, // assuming user is sender (expense)
        recipientId: '', // unknown recipient
        recipientName: 'Transaction Added from Receipt',
        amount: amount,
        currency: CurrencyController.to.currencyCode.value,
        tax: 0,
        note: note,
        category: category,
        date: date,
      );

      await docRef.set(transaction.toMap());

      // Check Budget Limit
      final email = user.email;
      if (category.isNotEmpty && email != null) {
        BudgetService.checkBudgetExceeded(
          userId: email,
          category: category,
        );
      }

      ErrorHandler.showSuccess("Transaction saved successfully.");
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ErrorHandler.showError("Failed to save transaction: $e");
    }
  }

  // Helper parsers:

  double? _extractAmount(String text) {
    final lower = text.toLowerCase();
    final numRegex = RegExp(r'[\d,]+(?:\.\d{1,2})?');

    // Stage 1: find amount near common total keywords (most specific first)
    const totalKeywords = [
      'grand total', 'total amount', 'net amount', 'amount payable',
      'total payable', 'bill amount', 'payable', 'total',
    ];
    for (final kw in totalKeywords) {
      final idx = lower.indexOf(kw);
      if (idx == -1) continue;
      final snippet = text.substring(idx, (idx + 60).clamp(0, text.length));
      final m = numRegex.firstMatch(snippet);
      if (m != null) {
        final val = double.tryParse(m.group(0)!.replaceAll(',', ''));
        if (val != null && val > 0) return val;
      }
    }

    // Stage 2: return the largest number in the full text
    double largest = 0;
    for (final m in numRegex.allMatches(text)) {
      final val = double.tryParse(m.group(0)!.replaceAll(',', '')) ?? 0;
      if (val > largest) largest = val;
    }
    return largest > 0 ? largest : null;
  }

  String? _extractCategory(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('grocery')) return 'Groceries';
    if (lower.contains('fuel') || lower.contains('petrol')) return 'Fuel';
    if (lower.contains('restaurant') || lower.contains('dining')) {
      return 'Dining';
    }
    if (lower.contains('rent')) return 'Rent';
    if (lower.contains('shopping')) return 'Shopping';
    return null;
  }

  DateTime? _extractDate(String text) {
    final dateRegex = RegExp(r'(\d{2}[\/\-]\d{2}[\/\-]\d{2,4})');
    final match = dateRegex.firstMatch(text);
    if (match != null) {
      try {
        final parts = match.group(1)!.split(RegExp(r'[\/\-]'));
        int day = int.parse(parts[0]);
        int month = int.parse(parts[1]);
        int year = int.parse(parts[2].length == 2 ? '20${parts[2]}' : parts[2]);
        return DateTime(year, month, day);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
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
          title: Text(
            "Receipt Scanner",
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18.sp,
              letterSpacing: 0.5,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: isDark ? Colors.white : AppColors.lightTextPrimary),
        ),
        body: Padding(
          padding: EdgeInsets.all(20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Container
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.035),
                    borderRadius: BorderRadius.circular(24.r),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.lightBorder.withValues(alpha: 0.1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24.r),
                    child: _imageFile == null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.image_search_rounded,
                                  size: 48.sp,
                                  color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.2),
                                ),
                                SizedBox(height: 16.h),
                                Text(
                                  "No image selected",
                                  style: TextStyle(
                                    color: isDark ? Colors.white38 : AppColors.lightTextTertiary,
                                    fontSize: 14.sp,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Image.file(_imageFile!, fit: BoxFit.cover),
                  ),
                ),
              ),

              SizedBox(height: 24.h),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: _glassButton(
                      icon: Icons.camera_alt_outlined,
                      label: "Camera",
                      onTap: () => _pickImage(ImageSource.camera),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: _glassButton(
                      icon: Icons.photo_library_outlined,
                      label: "Gallery",
                      onTap: () => _pickImage(ImageSource.gallery),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 24.h),

              // Scanned Text Area
              Expanded(
                flex: 1,
                child: Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: isDark ? Colors.white12 : AppColors.lightBorder.withValues(alpha: 0.12)),
                  ),
                  child: _scanning
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF00E5FF),
                          ),
                        )
                      : SingleChildScrollView(
                          child: Text(
                            _recognizedText ?? "Scanned text will appear here.",
                            style: TextStyle(
                              color: _recognizedText == null
                                  ? (isDark ? Colors.white38 : AppColors.lightTextTertiary)
                                  : (isDark ? Colors.white70 : AppColors.lightTextSecondary),
                              fontSize: 14.sp,
                              height: 1.5,
                            ),
                          ),
                        ),
                ),
              ),

              SizedBox(height: 24.h),

              // Save Button
              GestureDetector(
                onTap: _onSave,
                child: Container(
                  width: double.infinity,
                  height: 56.h,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF00E5FF)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(28.r),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C63FF).withValues(alpha: 0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "SAVE TRANSACTION",
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glassButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50.h,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.lightBorder.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF00E5FF), size: 20.sp),
            SizedBox(width: 8.w),
            Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
