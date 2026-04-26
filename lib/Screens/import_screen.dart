import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Services/import_service.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  List<List<dynamic>>? _csvData;
  List<String> _headers = [];
  bool _isLoading = false;

  // Column Mapping state
  String? _dateColumn;
  String? _amountColumn;
  String? _noteColumn;
  String? _categoryColumn;

  Future<void> _pickFile() async {
    setState(() => _isLoading = true);
    final data = await ImportService.pickAndParseCSV();

    if (data != null && data.isNotEmpty) {
      setState(() {
        _csvData = data;
        // Assume first row is headers
        _headers = data[0].map((e) => e.toString()).toList();

        // Auto-detect columns (fuzzy match)
        _dateColumn = _findSimilarHeader(['date', 'time', 'timestamp']);
        _amountColumn = _findSimilarHeader([
          'amount',
          'cost',
          'value',
          'price',
          'spending',
        ]);
        _noteColumn = _findSimilarHeader([
          'description',
          'note',
          'details',
          'memo',
        ]);
        _categoryColumn = _findSimilarHeader(['category', 'tag', 'type']);
      });
    }
    setState(() => _isLoading = false);
  }

  String? _findSimilarHeader(List<String> keywords) {
    for (var header in _headers) {
      if (keywords.any((k) => header.toLowerCase().contains(k))) {
        return header;
      }
    }
    return null;
  }

  Future<void> _importData() async {
    if (_dateColumn == null || _amountColumn == null) {
      Get.snackbar(
        "Missing Data",
        "Please map at least Date and Amount columns.",
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final headerMap = {
        'date': _headers.indexOf(_dateColumn!),
        'amount': _headers.indexOf(_amountColumn!),
        'note': _noteColumn != null ? _headers.indexOf(_noteColumn!) : -1,
        'category': _categoryColumn != null
            ? _headers.indexOf(_categoryColumn!)
            : -1,
      };

      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception("User not logged in");

      final transactions = ImportService.processCSVData(
        _csvData!,
        headerMap,
        userId,
        currency: CurrencyController.to.currencyCode.value,
      );

      await ImportService.saveTransactionsToFirestore(transactions, userId);

      // Success Feedback
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            title: const Text(
              "Success",
              style: TextStyle(color: Color(0xFF00E5FF)),
            ),
            content: Text(
              "Imported ${transactions.length} transactions successfully.",
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                child: const Text("OK"),
                onPressed: () {
                  Navigator.pop(context); // Close Dialog
                  Navigator.pop(context); // Close Screen
                },
              ),
            ],
          ),
        );
      }
    } catch (e) {
      Get.snackbar(
        "Import Failed",
        e.toString(),
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1A1A2E), // Midnight Void
            const Color(0xFF16213E).withValues(alpha: 0.95),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text("Import Data"),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
              )
            : SingleChildScrollView(
                padding: EdgeInsets.all(20.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStepHeader("1. Select File", Icons.attach_file),
                    SizedBox(height: 10.h),

                    _buildNavCard(
                      title: _csvData == null
                          ? "Tap to Upload CSV"
                          : "File Selected: ${_csvData!.length - 1} rows",
                      icon: Icons.upload_file,
                      onTap: _pickFile,
                      isHighlight: _csvData == null,
                    ),

                    if (_csvData != null) ...[
                      SizedBox(height: 30.h),
                      _buildStepHeader("2. Map Columns", Icons.low_priority),
                      Center(
                        child: Text(
                          "Match CSV headers to app fields",
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 12.sp,
                          ),
                        ),
                      ),
                      SizedBox(height: 15.h),

                      _buildMappingDropdown(
                        "Date Column *",
                        _dateColumn,
                        (val) => setState(() => _dateColumn = val),
                      ),
                      _buildMappingDropdown(
                        "Amount Column *",
                        _amountColumn,
                        (val) => setState(() => _amountColumn = val),
                      ),
                      _buildMappingDropdown(
                        "Description/Note",
                        _noteColumn,
                        (val) => setState(() => _noteColumn = val),
                      ),
                      _buildMappingDropdown(
                        "Category",
                        _categoryColumn,
                        (val) => setState(() => _categoryColumn = val),
                      ),

                      SizedBox(height: 40.h),
                      _buildGradientButton("IMPORT DATA", _importData),

                      SizedBox(height: 20.h),
                      Center(
                        child: Text(
                          "Previewing first 5 rows:",
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(height: 10.h),
                      _buildPreviewTable(),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStepHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF00E5FF), size: 18.sp),
        SizedBox(width: 8.w),
        Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildNavCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    bool isHighlight = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 20.w),
        decoration: BoxDecoration(
          color: isHighlight
              ? const Color(0xFF00E5FF).withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isHighlight
                ? const Color(0xFF00E5FF)
                : Colors.white.withValues(alpha: 0.1),
            width: isHighlight ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isHighlight ? const Color(0xFF00E5FF) : Colors.white70,
              size: 30.sp,
            ),
            SizedBox(height: 10.h),
            Text(
              title,
              style: TextStyle(
                color: isHighlight ? const Color(0xFF00E5FF) : Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMappingDropdown(
    String label,
    String? value,
    Function(String?) onChanged,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(color: Colors.white70, fontSize: 14.sp),
            ),
            DropdownButton<String>(
              value: _headers.contains(value) ? value : null,
              dropdownColor: const Color(0xFF1E1E2C),
              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF00E5FF)),
              underline: const SizedBox(),
              hint: Text(
                "Select Column",
                style: TextStyle(color: Colors.white24, fontSize: 12.sp),
              ),
              style: TextStyle(color: Colors.white, fontSize: 14.sp),
              items: _headers
                  .map((h) => DropdownMenuItem(value: h, child: Text(h)))
                  .toList(),
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientButton(String text, VoidCallback onPressed) {
    return Container(
      width: double.infinity,
      height: 55.h,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00E5FF), Color(0xFF7B2CBF)],
        ),
        borderRadius: BorderRadius.circular(30.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30.r),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewTable() {
    if (_csvData == null || _csvData!.isEmpty) return const SizedBox();

    // Show top 5 rows
    final previewRows = _csvData!.take(6).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingTextStyle: TextStyle(
          color: const Color(0xFF00E5FF),
          fontWeight: FontWeight.bold,
          fontSize: 12.sp,
        ),
        dataTextStyle: TextStyle(color: Colors.white70, fontSize: 12.sp),
        border: TableBorder.all(color: Colors.white10),
        columns: _headers.map((h) => DataColumn(label: Text(h))).toList(),
        rows: previewRows.skip(1).map((row) {
          return DataRow(
            cells: row
                .map(
                  (cell) => DataCell(
                    Text(
                      cell.toString().substring(
                        0,
                        cell.toString().length > 20
                            ? 20
                            : cell.toString().length,
                      ),
                    ),
                  ),
                )
                .toList(),
          );
        }).toList(),
      ),
    );
  }
}
