// lib/Screens/transaction_details.dart

import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:money_control/Models/transaction.dart';
import 'package:money_control/Screens/edit_transaction.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Controllers/transaction_controller.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'package:money_control/Services/error_handler.dart';
import 'package:money_control/Components/colors.dart';

// ----------------------------------------------------------------------

enum TransactionResultType { success, failed, inProgress }

class TransactionResultScreen extends StatefulWidget {
  final TransactionResultType type;
  final TransactionModel transaction;
  final VoidCallback? onAction;

  const TransactionResultScreen({
    super.key,
    required this.type,
    required this.transaction,
    this.onAction,
  });

  @override
  State<TransactionResultScreen> createState() =>
      _TransactionResultScreenState();
}

// ----------------------------------------------------------------------

class _TransactionResultScreenState extends State<TransactionResultScreen> {
  final ScreenshotController _ssController = ScreenshotController();
  bool isDark = false;

  // ----------------------------------------------------------------------
  // DELETE TRANSACTION (OFFLINE SAFE)
  // ----------------------------------------------------------------------
  Future<void> _deleteTransaction() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dlgIsDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: dlgIsDark ? AppColors.darkSurface : AppColors.lightSurface,
          title: Text("Delete Transaction", style: TextStyle(color: dlgIsDark ? Colors.white : AppColors.lightTextPrimary)),
          content: Text("Are you sure you want to delete this transaction?", style: TextStyle(color: dlgIsDark ? Colors.white70 : AppColors.lightTextSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text("Cancel", style: TextStyle(color: dlgIsDark ? Colors.white70 : AppColors.lightTextSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text("Delete", style: TextStyle(color: AppColors.error)),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    if (!mounted) return;

    final ctrl = Get.find<TransactionController>();
    final success = await ctrl.deleteTransaction(widget.transaction);

    if (success && mounted) {
      Navigator.pop(context);
    }
  }

  // ----------------------------------------------------------------------
  // SHARE SCREENSHOT
  // ----------------------------------------------------------------------
  Future<void> _shareScreenshot() async {
    try {
      final Uint8List? image = await _ssController.capture();
      if (image != null) {
        // ignore: deprecated_member_use
        await Share.shareXFiles([
          XFile.fromData(image, mimeType: 'image/png', name: 'transaction.png'),
        ]);
      }
    } catch (e) {
      ErrorHandler.showError('Failed to share screenshot: $e');
    }
  }

  // ----------------------------------------------------------------------
  // PDF FILE GENERATION
  // ----------------------------------------------------------------------
  Future<void> _savePDF() async {
    final tx = widget.transaction;
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "Transaction Receipt",
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Divider(),
              pw.SizedBox(height: 12),
              _pdfRow("Transaction ID", tx.id),
              _pdfRow("Date", tx.date.toLocal().toString()),
              _pdfRow("Recipient", tx.recipientName),
              _pdfRow(
                "Amount",
                "${CurrencyController.to.currencySymbol.value}${tx.amount.abs().toStringAsFixed(2)}",
              ),
              _pdfRow("Tax", tx.tax.toStringAsFixed(2)),
              _pdfRow("Total", tx.total.toStringAsFixed(2)),
              _pdfRow("Currency", tx.currency),
              _pdfRow("Category", tx.category ?? "-"),
              if (tx.note != null && tx.note!.isNotEmpty)
                _pdfRow("Note", tx.note!),
              _pdfRow("Status", tx.status ?? "-"),
              pw.SizedBox(height: 24),
              pw.Text(
                "Generated using Money Control App",
                style: pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
              ),
            ],
          );
        },
      ),
    );

    final bytes = await pdf.save();

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: "application/pdf", name: "Transaction_${tx.id}.pdf")],
      ),
    );
  }

  pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13),
          ),
          pw.Text(value, style: const pw.TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------------
  // BUILD UI
  // ----------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    isDark = Theme.of(context).brightness == Brightness.dark;
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
            "Transaction Details",
            style: TextStyle(color: isDark ? Colors.white : AppColors.lightTextPrimary, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: isDark ? Colors.white : AppColors.lightTextPrimary),
          actions: [
            IconButton(
              icon: Icon(Icons.edit, color: isDark ? Colors.white : AppColors.lightTextPrimary),
              onPressed: () async {
                await Get.to(
                  () => TransactionEditScreen(transaction: widget.transaction),
                );
                if (mounted) setState(() {});
              },
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: isDark ? Colors.white : AppColors.lightTextPrimary),
              onPressed: _deleteTransaction,
            ),
          ],
        ),
        body: Screenshot(
          controller: _ssController,
          child: _buildBody(context, widget.transaction),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, TransactionModel tx) {
    final user = FirebaseAuth.instance.currentUser;
    final isReceived = user != null && tx.recipientId == user.uid;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 10.h),
      child: Column(
        children: [
          SizedBox(height: 20.h),
          _statusIcon(isReceived),
          SizedBox(height: 16.h),
          _titleText(isReceived),
          SizedBox(height: 6.h),
          _subtitleText(isReceived),
          SizedBox(height: 30.h),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _capsuleButton(
                icon: Icons.share_outlined,
                label: "Share",
                onTap: _shareScreenshot,
              ),
              SizedBox(width: 16.w),
              _capsuleButton(
                icon: Icons.picture_as_pdf,
                label: "Save PDF",
                onTap: _savePDF,
              ),
            ],
          ),

          SizedBox(height: 30.h),
          _detailsCard(tx, isReceived),

          SizedBox(height: 30.h),
          Container(
            width: double.infinity,
            height: 54.h,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF6A11CB),
                  Color(0xFF2575FC),
                ], // Neon Blue/Purple
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28.r),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2575FC).withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28.r),
                ),
              ),
              child: Text(
                "Back",
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16.sp,
                ),
              ),
            ),
          ),
          SizedBox(height: 20.h),
        ],
      ),
    );
  }

  // --------------------------- Icon + Title ---------------------------

  Widget _statusIcon(bool isReceived) {
    final t = widget.type;

    if (t == TransactionResultType.failed) {
      return _buildIconContainer(
        Icons.close_rounded,
        [const Color(0xFFE53935), const Color(0xFFB71C1C)], // Red for Failure
      );
    } else if (t == TransactionResultType.inProgress) {
      return _buildIconContainer(
        Icons.hourglass_empty_rounded,
        [
          const Color(0xFFFFA726),
          const Color(0xFFF57C00),
        ], // Orange for Progress
      );
    }

    // Success Case
    if (isReceived) {
      return _buildIconContainer(
        Icons.arrow_downward_rounded,
        [
          const Color(0xFF00E5FF),
          const Color(0xFF00BFA5),
        ], // Neon Cyan/Green for Received
      );
    } else {
      return _buildIconContainer(
        Icons.check_rounded,
        [
          const Color(0xFFFF2975),
          const Color(0xFFC2185B),
        ], // Neon Pink/Red for Sent
      );
    }
  }

  Widget _buildIconContainer(IconData icon, List<Color> colors) {
    return Container(
      width: 90.r,
      height: 90.r,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 20,
            offset: const Offset(0, 8),
            color: colors.first.withValues(alpha: 0.4),
          ),
          BoxShadow(blurRadius: 10, color: Colors.black.withValues(alpha: 0.2)),
        ],
      ),
      child: Center(
        child: Container(
          padding: EdgeInsets.all(4.r),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: isDark ? Colors.white : AppColors.lightTextPrimary, width: 2),
          ),
          child: Icon(icon, size: 40.sp, color: isDark ? Colors.white : AppColors.lightTextPrimary),
        ),
      ),
    );
  }

  Widget _titleText(bool isReceived) {
    final t = widget.type;
    String text;
    if (t == TransactionResultType.success) {
      text = isReceived ? "Money Received!" : "Money Sent!";
    } else if (t == TransactionResultType.failed) {
      text = "Transaction Failed!";
    } else {
      text = "Processing Transaction";
    }

    return Text(
      text,
      style: TextStyle(
        fontSize: 20.sp,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : AppColors.lightTextPrimary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _subtitleText(bool isReceived) {
    final t = widget.type;
    String text;
    if (t == TransactionResultType.success) {
      text = isReceived
          ? "You received money successfully."
          : "Your payment has been sent successfully.";
    } else if (t == TransactionResultType.failed) {
      text = "Payment could not be completed.";
    } else {
      text = "Your payment is being processed.";
    }

    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 14.sp,
        color: isDark ? Colors.white60 : AppColors.lightTextSecondary,
      ),
    );
  }

  // --------------------------- UI Components ---------------------------

  Widget _capsuleButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 48.h,
      width: 140.w,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.lightBorder.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24.r),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: const Color(0xFF8E99F3),
                size: 20.sp,
              ),
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
      ),
    );
  }

  Widget _detailsCard(TransactionModel tx, bool isReceived) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.lightBorder.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Transaction Details",
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
            ),
          ),
          SizedBox(height: 16.h),
          Divider(color: isDark ? Colors.white.withValues(alpha: 0.15) : AppColors.lightDivider),
          SizedBox(height: 16.h),
          _detailRow("Transaction ID", tx.id),
          _detailRow("Date", tx.date.toLocal().toString().split('.')[0]),

          if (isReceived)
            _detailRow(
              "Sender",
              tx.recipientName.isNotEmpty ? tx.recipientName : "Unknown",
            ),
          if (!isReceived) _detailRow("Recipient", tx.recipientName),

          _detailRow(
            "Amount",
            "${CurrencyController.to.currencySymbol.value}${tx.amount.abs().toStringAsFixed(2)}",
            valueColor: isReceived
                ? const Color(0xFF00E5FF)
                : const Color(0xFFFF2975),
          ),

          _detailRow(
            "Tax",
            "${CurrencyController.to.currencySymbol.value}${tx.tax.toStringAsFixed(2)}",
          ),
          _detailRow(
            "Total",
            "${CurrencyController.to.currencySymbol.value}${tx.total.toStringAsFixed(2)}",
            bold: true,
          ),
          _detailRow("Currency", tx.currency),
          _detailRow("Category", tx.category ?? "-"),
          if (tx.note != null && tx.note!.isNotEmpty)
            _detailRow("Note", tx.note!),
          _detailRow("Status", tx.status ?? "-"),
        ],
      ),
    );
  }

  Widget _detailRow(
    String name,
    String value, {
    bool bold = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.h), // More spacing
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              name,
              style: TextStyle(
                color: isDark ? Colors.white60 : AppColors.lightTextSecondary,
                fontSize: 13.5.sp,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: bold ? 15.sp : 13.5.sp,
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                color: valueColor ??
                    (bold
                        ? (isDark ? Colors.white : AppColors.lightTextPrimary)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.9)
                            : AppColors.lightTextPrimary.withValues(alpha: 0.9))),
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
