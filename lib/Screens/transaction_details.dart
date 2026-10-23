// lib/Screens/transaction_details.dart

import 'package:money_control/l10n/app_localizations.dart';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:money_control/Models/transaction.dart';
import 'package:money_control/Controllers/privacy_controller.dart';
import 'package:money_control/Components/feature_gate.dart';
import 'package:money_control/Screens/edit_transaction.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Controllers/transaction_controller.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'package:money_control/Services/error_handler.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Utils/responsive.dart';

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
        final l10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          backgroundColor: dlgIsDark
              ? AppColors.darkSurface
              : AppColors.lightSurface,
          title: Text(
            l10n.deleteTransaction,
            style: AppType.titleMedium(
              dlgIsDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          content: Text(
            l10n.sureWantDeleteTransaction,
            style: AppType.bodyMedium(
              dlgIsDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                l10n.delete,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    if (!mounted) return;

    if (!Get.isRegistered<TransactionController>()) return;
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
      final Uint8List? image = await _ssController.capture(
        pixelRatio: 2.0,
      );
      if (image != null) {
        // ignore: deprecated_member_use
        await Share.shareXFiles([
          XFile.fromData(image, mimeType: 'image/png', name: 'transaction.png'),
        ]);
      }
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.showError(
        AppLocalizations.of(context)!.shareScreenshotFailed(e.toString()),
      );
    }
  }

  // ----------------------------------------------------------------------
  // PDF FILE GENERATION
  // ----------------------------------------------------------------------
  Future<void> _savePDF() async {
    final tx = widget.transaction;
    final l10n = AppLocalizations.of(context)!;
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                l10n.transactionReceipt,
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Divider(),
              pw.SizedBox(height: 12),
              _pdfRow(l10n.transactionId, tx.id),
              _pdfRow(l10n.date, tx.date.toLocal().toString()),
              _pdfRow(l10n.recipient, tx.recipientName),
              _pdfRow(
                l10n.amount,
                "${CurrencyController.to.currencySymbol.value}${tx.amount.abs().toStringAsFixed(2)}",
              ),
              _pdfRow(l10n.tax, tx.tax.toStringAsFixed(2)),
              _pdfRow(l10n.total, tx.total.toStringAsFixed(2)),
              _pdfRow(l10n.currency, tx.currency),
              _pdfRow(l10n.category, tx.category ?? "-"),
              if (tx.note != null && tx.note!.isNotEmpty)
                _pdfRow(l10n.note, tx.note!),
              _pdfRow(l10n.status, tx.status ?? "-"),
              pw.SizedBox(height: 24),
              pw.Text(
                l10n.transactionPdfFooter,
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
          title: Text(AppLocalizations.of(context)!.transactionDetails),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                if (!ensureFeatureVisible(context, 'transactions')) return;
                await Get.to(
                  () => TransactionEditScreen(transaction: widget.transaction),
                );
                if (mounted) setState(() {});
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                if (!ensureFeatureVisible(context, 'transactions')) return;
                _deleteTransaction();
              },
            ),
          ],
        ),
        body: Screenshot(
          controller: _ssController,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark ? AppColors.darkGradient : AppColors.lightGradient,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: _buildBody(context, widget.transaction),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, TransactionModel tx) {
    final user = FirebaseAuth.instance.currentUser;
    final isReceived = user != null && tx.recipientId == user.uid;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 10.h),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
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
                    label: AppLocalizations.of(context)!.share,
                    onTap: _shareScreenshot,
                  ),
                  SizedBox(width: 16.w),
                  _capsuleButton(
                    icon: Icons.picture_as_pdf,
                    label: AppLocalizations.of(context)!.savePdf,
                    onTap: _savePDF,
                  ),
                ],
              ),

              SizedBox(height: 30.h),
              _detailsCard(tx, isReceived),

              SizedBox(height: 30.h),
              SizedBox(
                width: double.infinity,
                height: 54.h,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(AppLocalizations.of(context)!.back),
                ),
              ),
              SizedBox(height: 20.h),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------- Icon + Title ---------------------------

  Widget _statusIcon(bool isReceived) {
    final t = widget.type;

    if (t == TransactionResultType.failed) {
      return _buildIconContainer(Icons.close_rounded, AppColors.error);
    }
    if (t == TransactionResultType.inProgress) {
      return _buildIconContainer(
        Icons.hourglass_empty_rounded,
        AppColors.warning,
      );
    }

    if (isReceived) {
      return _buildIconContainer(
        Icons.arrow_downward_rounded,
        AppColors.success,
      );
    }
    return _buildIconContainer(Icons.check_rounded, AppColors.primary);
  }

  /// One saturated circle per outcome.
  ///
  /// The four outcomes used to each hand-pick a two-stop gradient from a
  /// different colour family (neon cyan/green, neon pink/red, orange), so the
  /// same screen spoke four visual languages. The second stop is now derived
  /// from the semantic colour.
  Widget _buildIconContainer(IconData icon, Color color) {
    return Container(
      width: 90.r,
      height: 90.r,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.72)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: AppElevation.floating(isDark: isDark, tint: color),
      ),
      child: Center(
        child: Container(
          padding: EdgeInsets.all(4.r),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context).colorScheme.onPrimary,
              width: 2,
            ),
          ),
          child: Icon(
            icon,
            size: 40.sp,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
      ),
    );
  }

  Widget _titleText(bool isReceived) {
    final t = widget.type;
    final l10n = AppLocalizations.of(context)!;
    String text;
    if (t == TransactionResultType.success) {
      text = isReceived ? l10n.moneyReceived : l10n.moneySent;
    } else if (t == TransactionResultType.failed) {
      text = l10n.transactionFailed;
    } else {
      text = l10n.processingTransaction;
    }

    return Text(
      text,
      style: AppType.titleLarge(
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      ),
    );
  }

  Widget _subtitleText(bool isReceived) {
    final t = widget.type;
    final l10n = AppLocalizations.of(context)!;
    String text;
    if (t == TransactionResultType.success) {
      text = isReceived ? l10n.moneyReceivedSuccess : l10n.moneySentSuccess;
    } else if (t == TransactionResultType.failed) {
      text = l10n.paymentCouldNotComplete;
    } else {
      text = l10n.paymentProcessing;
    }

    return Text(
      text,
      textAlign: TextAlign.center,
      style: AppType.bodyMedium(
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
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
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightActionSurface,
        borderRadius: BorderRadius.circular(AppRadius.pill.r),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: AppElevation.raised(isDark: isDark),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill.r),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: AppColors.primary,
                size: 20.sp,
              ),
              SizedBox(width: 8.w),
              Text(
                label,
                style: AppType.titleSmall(
                  isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
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
      padding: EdgeInsets.symmetric(
        horizontal: AppSpace.s20.w,
        vertical: AppSpace.s24.h,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.xl.r),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: AppElevation.raised(isDark: isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.transactionDetails,
            style: AppType.titleMedium(
              isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          SizedBox(height: AppSpace.s16.h),
          Divider(
            color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
          ),
          SizedBox(height: AppSpace.s16.h),
          _detailRow(AppLocalizations.of(context)!.transactionId, tx.id),
          _detailRow(
            AppLocalizations.of(context)!.date,
            tx.date.toLocal().toString().split('.')[0],
          ),

          if (isReceived)
            _detailRow(
              AppLocalizations.of(context)!.sender,
              tx.recipientName.isNotEmpty
                  ? tx.recipientName
                  : AppLocalizations.of(context)!.unknown,
            ),
          if (!isReceived)
            _detailRow(
              AppLocalizations.of(context)!.recipient,
              tx.recipientName,
            ),

          _detailRow(
            AppLocalizations.of(context)!.amount,
            "${CurrencyController.to.currencySymbol.value}${tx.amount.abs().toStringAsFixed(2)}",
            valueColor: isReceived ? AppColors.success : AppColors.error,
            masked: true,
          ),

          _detailRow(
            AppLocalizations.of(context)!.tax,
            "${CurrencyController.to.currencySymbol.value}${tx.tax.toStringAsFixed(2)}",
            masked: true,
          ),
          _detailRow(
            AppLocalizations.of(context)!.total,
            "${CurrencyController.to.currencySymbol.value}${tx.total.toStringAsFixed(2)}",
            bold: true,
            masked: true,
          ),
          _detailRow(AppLocalizations.of(context)!.currency, tx.currency),
          _detailRow(
            AppLocalizations.of(context)!.category,
            tx.category ?? "-",
          ),
          if (tx.note != null && tx.note!.isNotEmpty)
            _detailRow(AppLocalizations.of(context)!.note, tx.note!),
          _detailRow(
            AppLocalizations.of(context)!.status,
            tx.status ?? "-",
          ),
        ],
      ),
    );
  }

  Widget _detailRow(
    String name,
    String value, {
    bool bold = false,
    Color? valueColor,
    bool masked = false,
  }) {
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final TextStyle style =
        (bold
                ? AppType.titleSmall(textColor)
                : AppType.bodyMedium(textColor.withValues(alpha: 0.9)))
            .copyWith(color: valueColor);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.h), // More spacing
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              name,
              style: AppType.bodySmall(
                isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: masked
                ? Align(
                    alignment: Alignment.centerRight,
                    child: PrivacyText(value, style: style),
                  )
                : Text(
                    value,
                    textAlign: TextAlign.right,
                    style: style,
                  ),
          ),
        ],
      ),
    );
  }
}
