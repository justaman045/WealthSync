// lib/Screens/upi_payment_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:pattern_formatter/pattern_formatter.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Components/glass_container.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Controllers/transaction_controller.dart';
import 'package:money_control/Services/error_handler.dart';
import 'package:money_control/Utils/upi_apps.dart';

class UpiPaymentScreen extends StatefulWidget {
  final String? initialVpa;
  final String? initialName;
  final double? initialAmount;
  final String? initialNote;

  const UpiPaymentScreen({
    super.key,
    this.initialVpa,
    this.initialName,
    this.initialAmount,
    this.initialNote,
  });

  @override
  State<UpiPaymentScreen> createState() => _UpiPaymentScreenState();
}

class _UpiPaymentScreenState extends State<UpiPaymentScreen> {
  late final TransactionController _transactionController;

  final TextEditingController _amount = TextEditingController();
  final TextEditingController _vpa = TextEditingController();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _note = TextEditingController();

  String? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  Worker? _categoryAutoSelectWorker;

  // Platform channel for UPI — uses startActivityForResult so we get the result back
  static const _upiChannel = MethodChannel('money_control/upi');

  static const _upiApps = <UpiAppDescriptor>[
    UpiAppDescriptor(
      name: 'GPay',
      package: 'com.google.android.apps.nbu.paisa.user',
      icon: 'G',
      color: Color(0xFF4285F4),
    ),
    UpiAppDescriptor(
      name: 'PhonePe',
      package: 'com.phonepe.app',
      icon: 'P',
      color: Color(0xFF5F259F),
    ),
    UpiAppDescriptor(
      name: 'Paytm',
      package: 'net.one97.paytm',
      icon: 'P',
      color: Color(0xFF002970),
    ),
    UpiAppDescriptor(
      name: 'BHIM',
      package: 'in.org.npci.upiapp',
      icon: 'B',
      color: Color(0xFF0033A0),
    ),
    UpiAppDescriptor(
      name: 'CRED',
      package: 'com.dreamplug.androidapp',
      icon: 'C',
      color: AppColors.darkBackground,
    ),
    UpiAppDescriptor(
      name: 'Any UPI',
      package: null,
      icon: 'U',
      color: AppColors.primary,
    ),
  ];

  // 0 = amount + VPA entry, 1 = app chooser, 2 = details & save
  int _step = 0;
  bool _paying = false;
  String _txnId = '';
  String _approvalRef = '';
  String _appName = '';
  bool _pending = false;

  // Apps actually installed on the device (null = still loading). Falls back
  // to [_upiApps] when the platform channel is unavailable (web/iOS).
  List<UpiAppDescriptor>? _displayApps;

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<TransactionController>()) {
      Get.put(TransactionController());
    }
    _transactionController = Get.find<TransactionController>();

    _vpa.text = widget.initialVpa ?? '';
    _name.text = widget.initialName ?? '';
    _note.text = widget.initialNote ?? '';
    if (widget.initialAmount != null) {
      _amount.text = widget.initialAmount!.toStringAsFixed(2);
    }

    if (_transactionController.categories.isNotEmpty) {
      _selectedCategory = _transactionController.categories.first.name;
    } else {
      _categoryAutoSelectWorker = ever(_transactionController.categories, (
        cats,
      ) {
        if (cats.isNotEmpty && _selectedCategory == null && mounted) {
          setState(() => _selectedCategory = cats.first.name);
          _categoryAutoSelectWorker?.dispose();
          _categoryAutoSelectWorker = null;
        }
      });
    }

    _loadInstalledApps();
  }

  @override
  void dispose() {
    _categoryAutoSelectWorker?.dispose();
    _amount.dispose();
    _vpa.dispose();
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  String get _vpaLocalPart {
    final local = _vpa.text.trim().split('@').first.trim();
    return local.isEmpty ? 'Recipient' : local;
  }

  void _goToAppChooser() {
    final amount = double.tryParse(_amount.text.replaceAll(',', '')) ?? 0;
    if (amount <= 0) {
      ErrorHandler.showError("Enter amount before paying via UPI.");
      return;
    }
    if (_vpa.text.trim().isEmpty) {
      ErrorHandler.showError("Enter the payee's UPI ID (VPA) before paying via UPI.");
      return;
    }
    setState(() => _step = 1);
  }

  Future<void> _loadInstalledApps() async {
    try {
      final raw = await _upiChannel.invokeMethod<List<dynamic>>(
        'installedUpiApps',
      );
      final installed = <String, String>{};
      for (final e in raw ?? const <dynamic>[]) {
        if (e is Map) {
          final pkg = e['package'];
          final label = e['label'];
          if (pkg is String && pkg.isNotEmpty) {
            installed[pkg] = label is String ? label : pkg;
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _displayApps = filterInstalledUpiApps(
          pinned: _upiApps,
          installedPackages: installed,
          fallbackColor: AppColors.primary,
        );
      });
    } on MissingPluginException {
      if (!mounted) return;
      setState(() => _displayApps = _upiApps);
    } on PlatformException {
      if (!mounted) return;
      setState(() => _displayApps = _upiApps);
    }
  }

  void _goBack() {
    if (_step > 0) {
      setState(() => _step--);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _initiateUpiPayment({
    required String appName,
    String? packageName,
  }) async {
    final amount = double.tryParse(_amount.text.replaceAll(',', '')) ?? 0;
    final vpa = _vpa.text.trim();

    setState(() => _paying = true);
    try {
      final response = await _upiChannel.invokeMethod<String>('pay', {
        if (packageName != null) 'packageName': packageName,
        'payeeVpa': vpa,
        'amount': amount.toStringAsFixed(2),
        'payeeName': _vpaLocalPart,
        'note': 'Payment',
      });
      if (!mounted) return;
      setState(() => _paying = false);
      _handleUpiResponse(response ?? '', appName);
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() => _paying = false);
      if (e.code == 'APP_NOT_FOUND' && packageName != null) {
        // Specific app not installed — retry with Android system UPI chooser
        await _initiateUpiPayment(appName: 'UPI', packageName: null);
      } else if (e.code == 'TIMEOUT') {
        ErrorHandler.showError('UPI app did not respond. Please try again.');
      } else if (e.code == 'UPI_FAILED' || e.code == 'INVALID_AMOUNT') {
        ErrorHandler.showError(
          'Could not start UPI payment. Please try again.',
        );
      } else {
        ErrorHandler.showError(
          'No UPI app found. Please install GPay, PhonePe or Paytm.',
        );
      }
    } on MissingPluginException {
      // The channel has no native implementation on this platform (iOS/desktop).
      // Uncaught, this left `_paying` true forever — a permanently spinning
      // button. UPI is Android-only, so the entry points gate on
      // `Platform.isAndroid`, and this is the belt-and-braces path.
      if (!mounted) return;
      setState(() => _paying = false);
      ErrorHandler.showError('UPI payments are only available on Android.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _paying = false);
      ErrorHandler.showError('Could not start UPI payment. Please try again.');
    }
  }

  void _handleUpiResponse(String response, String appName) {
    if (response.isEmpty) return; // user pressed back — cancelled silently

    // Response is a query-string: "Status=SUCCESS&txnId=XXX&txnRef=YYY&..."
    final params = Map.fromEntries(
      response.split('&').where((s) => s.contains('=')).map((kv) {
        final i = kv.indexOf('=');
        return MapEntry(kv.substring(0, i).toLowerCase(), kv.substring(i + 1));
      }),
    );

    final status = (params['status'] ?? '').toUpperCase();
    final txnId = params['txnid'] ?? params['txnref'] ?? '';
    final approvalRef = params['approvalrefno'] ?? '';

    if (status == 'SUCCESS' || status == 'SUBMITTED') {
      setState(() {
        _step = 2;
        _txnId = txnId;
        _approvalRef = approvalRef;
        _appName = appName;
        _pending = status == 'SUBMITTED';
      });
    } else {
      ErrorHandler.showError(
        'Payment ${status.isEmpty ? "failed or cancelled" : status.toLowerCase()}.',
      );
    }
  }

  Future<void> _saveTransaction() async {
    if (_selectedCategory == null) {
      ErrorHandler.showError("Select a category before saving.");
      return;
    }

    final amount = double.tryParse(_amount.text.replaceAll(',', '')) ?? 0;
    final name = _name.text.trim().isEmpty
        ? _vpaLocalPart
        : _name.text.trim();
    final note = _note.text.trim().isEmpty
        ? (_txnId.isNotEmpty ? 'UPI:$_txnId' : 'UPI payment')
        : _note.text.trim();

    final success = await _transactionController.saveTransaction(
      amount: amount,
      name: name,
      note: note,
      category: _selectedCategory!,
      date: _selectedDate,
      type: 'send',
      currency: CurrencyController.to.currencyCode.value,
    );

    if (success && mounted) {
      ErrorHandler.showSuccess("Transaction saved.");
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Pay with UPI",
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.colorScheme.onSurface),
          onPressed: _goBack,
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark ? AppColors.darkGradient : AppColors.lightGradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
                child: _step == 0
                    ? _buildEntryStep(theme)
                    : _step == 1
                    ? _buildAppChooserStep(theme)
                    : _buildDetailsStep(theme),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEntryStep(ThemeData theme) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel("Amount", theme),
          _amountField(theme),
          SizedBox(height: 8.h),
          _fieldLabel("UPI ID (VPA)", theme),
          _inputField(
            controller: _vpa,
            hint: "yourname@upi",
            theme: theme,
          ),
          SizedBox(height: 40.h),
          _primaryButton(
            label: "Continue",
            isDark: isDark,
            onTap: _goToAppChooser,
          ),
          SizedBox(height: 12.h),
          Center(
            child: Text(
              "No name or other details needed — just enter the amount and UPI ID.",
              style: TextStyle(
                color: isDark ? Colors.white54 : AppColors.lightTextSecondary,
                fontSize: 12.sp,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppChooserStep(ThemeData theme) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sym = CurrencyController.to.currencySymbol.value;
    final amount = double.tryParse(_amount.text.replaceAll(',', '')) ?? 0;
    final amountStr = amount.toStringAsFixed(2);
    final vpa = _vpa.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Choose UPI App",
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.lightTextPrimary,
            fontSize: 17.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          "Pay $sym$amountStr to $vpa",
          style: TextStyle(
            color: isDark ? Colors.white60 : AppColors.lightTextSecondary,
            fontSize: 13.sp,
          ),
        ),
        SizedBox(height: 16.h),
        Expanded(
          child: _displayApps == null
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : ListView(
                  children: _displayApps!.map((app) {
                    return Padding(
                      padding: EdgeInsets.only(bottom: 10.h),
                      child: GestureDetector(
                        onTap: _paying
                            ? null
                            : () {
                                _initiateUpiPayment(
                                  appName: app.name,
                                  packageName: app.package,
                                );
                              },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 12.h,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.042),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : AppColors.lightBorder.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34.w,
                          height: 34.w,
                          decoration: BoxDecoration(
                            color: app.color,
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            app.icon,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : AppColors.lightTextPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13.sp,
                            ),
                          ),
                        ),
                        SizedBox(width: 14.w),
                        Text(
                          app.name,
                          style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : AppColors.lightTextPrimary,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        if (_paying)
                          SizedBox(
                            width: 18.sp,
                            height: 18.sp,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          )
                        else
                          Icon(
                            Icons.arrow_forward_ios,
                            color: isDark
                                ? Colors.white24
                                : Colors.black.withValues(alpha: 0.2),
                            size: 14.sp,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsStep(ThemeData theme) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            decoration: BoxDecoration(
              color: (_pending ? Colors.amber : Colors.greenAccent)
                  .withValues(alpha: isDark ? 0.15 : 0.2),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _pending
                          ? Icons.access_time_rounded
                          : Icons.check_circle_rounded,
                      color: _pending ? Colors.amber : Colors.greenAccent,
                      size: 22.sp,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        _pending ? 'Payment Pending' : 'Payment Successful',
                        style: TextStyle(
                          color: isDark
                              ? Colors.white
                              : AppColors.lightTextPrimary,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  'via $_appName',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : AppColors.lightTextSecondary,
                    fontSize: 12.sp,
                  ),
                ),
                if (_txnId.isNotEmpty) ...[
                  SizedBox(height: 8.h),
                  _resultRow('Transaction ID', _txnId, theme),
                ],
                if (_approvalRef.isNotEmpty) ...[
                  SizedBox(height: 4.h),
                  _resultRow('Approval Ref', _approvalRef, theme),
                ],
              ],
            ),
          ),
          _fieldLabel("Category", theme),
          _categoryField(theme),
          _fieldLabel("Name", theme),
          _inputField(
            controller: _name,
            hint: _vpaLocalPart,
            theme: theme,
          ),
          _fieldLabel("Note", theme),
          _inputField(
            controller: _note,
            hint: _txnId.isNotEmpty ? 'UPI:$_txnId' : 'Note',
            theme: theme,
          ),
          _fieldLabel("Date", theme),
          _dateField(theme),
          SizedBox(height: 40.h),
          Obx(
            () => _primaryButton(
              label: "Save Transaction",
              isDark: isDark,
              onTap: _saveTransaction,
              saving: _transactionController.isSaving.value,
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultRow(String label, String value, ThemeData theme) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            color: isDark ? Colors.white54 : AppColors.lightTextSecondary,
            fontSize: 12.sp,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _fieldLabel(String text, ThemeData theme) {
    return Padding(
      padding: EdgeInsets.only(top: 20.h, bottom: 10.h),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required ThemeData theme,
    int maxLines = 1,
  }) {
    return GlassContainer(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.4),
            fontSize: 18.sp,
            fontWeight: FontWeight.w500,
          ),
          contentPadding: EdgeInsets.zero,
        ),
        style: TextStyle(
          fontSize: 18.sp,
          color: theme.textTheme.bodyLarge?.color,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _amountField(ThemeData theme) {
    return GlassContainer(
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Obx(
              () => Text(
                CurrencyController.to.currencyCode.value,
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 15.sp,
                ),
              ),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [ThousandsFormatter(allowFraction: true)],
              decoration: InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: "0.00",
                hintStyle: TextStyle(
                  color: theme.textTheme.bodyMedium?.color?.withValues(
                    alpha: 0.4,
                  ),
                  fontSize: 22.sp,
                ),
              ),
              style: TextStyle(
                fontSize: 22.sp,
                color: theme.textTheme.bodyLarge?.color,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryField(ThemeData theme) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Obx(() {
      final cats = _transactionController.categories;
      if (cats.isEmpty) {
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : AppColors.lightSurfaceCard,
            borderRadius: BorderRadius.circular(14.r),
          ),
          child: Text(
            "No categories available.",
            style: TextStyle(
              color: isDark ? Colors.white54 : AppColors.lightTextSecondary,
              fontSize: 14.sp,
            ),
          ),
        );
      }
      return GlassContainer(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedCategory,
            isExpanded: true,
            dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
            icon: Icon(Icons.arrow_drop_down_rounded, color: AppColors.primary),
            items: cats
                .map(
                  (c) => DropdownMenuItem(
                    value: c.name,
                    child: Text(
                      c.name,
                      style: TextStyle(
                        color: isDark ? Colors.white : AppColors.lightTextPrimary,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _selectedCategory = v),
          ),
        ),
      );
    });
  }

  Widget _dateField(ThemeData theme) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2015),
          lastDate: DateTime(2100),
        );
        if (picked != null && mounted) {
          setState(() => _selectedDate = picked);
        }
      },
      child: GlassContainer(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h),
        child: Row(
          children: [
            Text(
              "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}",
              style: TextStyle(
                fontSize: 18.sp,
                color: theme.textTheme.bodyLarge?.color,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Icon(Icons.calendar_today_outlined, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required bool isDark,
    required VoidCallback onTap,
    bool saving = false,
  }) {
    return GestureDetector(
      onTap: saving ? null : () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        width: double.infinity,
        height: 54.h,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.secondary],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(27.r),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 15.w,
              offset: Offset(0, 8.w),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: saving
            ? SizedBox(
                width: 24.sp,
                height: 24.sp,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                ),
              )
            : Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16.sp,
                  letterSpacing: 1.5,
                ),
              ),
      ),
    );
  }
}
