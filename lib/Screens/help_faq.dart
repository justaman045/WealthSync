import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:money_control/Components/bottom_nav_bar.dart';

class HelpFAQScreen extends StatefulWidget {
  const HelpFAQScreen({super.key});

  @override
  State<HelpFAQScreen> createState() => _HelpFAQScreenState();
}

class _HelpFAQScreenState extends State<HelpFAQScreen> {
  int? openedIndex;

  final List<Map<String, String>> faqs = [
    {
      "q": "How do I add a new transaction?",
      "a":
          "Tap the '+' or 'Add Transaction' button on the Home screen or the Quick Send section. Fill the details and tap 'Save'.",
    },
    {
      "q": "How do I edit or delete an existing transaction?",
      "a":
          "Open any transaction in your history and use the edit or delete options on the top right.",
    },
    {
      "q": "How do I manage or add custom categories?",
      "a":
          "You can add categories when adding/editing a transaction using the category dropdown.",
    },
    {
      "q": "Does the app work offline?",
      "a":
          "Yes! All changes will be saved locally and synced automatically once you're online again.",
    },
    {
      "q": "How do I switch between Dark and Light mode?",
      "a": "Go to Settings → Dark Mode to toggle theme appearance.",
    },
    {
      "q": "Can I export or download my transaction history?",
      "a":
          "Yes! Go to Analytics → tap the download icon → choose CSV or PDF. Pro members get full transaction history exports.",
    },
    {
      "q": "How do I reset my password?",
      "a":
          "Go to Settings → Change Password. A reset link will be emailed to you.",
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final gradientColors = isDark
        ? [
            const Color(0xFF1A1A2E), // Midnight Void
            const Color(0xFF16213E).withValues(alpha: 0.95),
          ]
        : [
            const Color(0xFFF5F7FA), // Premium Light
            const Color(0xFFC3CFE2),
          ];

    final textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final secondaryTextColor = isDark
        ? Colors.white.withValues(alpha: 0.6)
        : const Color(0xFF1A1A2E).withValues(alpha: 0.6);

    final cardColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.white.withValues(alpha: 0.6);

    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.white.withValues(alpha: 0.4);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: Text(
            "Help / FAQ",
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 18.sp,
            ),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: textColor, size: 20.sp),
            onPressed: () => Navigator.pop(context),
          ),
          toolbarHeight: 64.h,
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 8.h),
          child: Column(
            children: [
              ...List.generate(
                faqs.length,
                (index) => _FAQTile(
                  question: faqs[index]["q"]!,
                  answer: faqs[index]["a"]!,
                  isOpen: openedIndex == index,
                  surface: cardColor,
                  border: borderColor,
                  textColor: textColor,
                  secondary: secondaryTextColor,
                  isDark: isDark,
                  onTap: () {
                    setState(() {
                      openedIndex = openedIndex == index ? null : index;
                    });
                  },
                ),
              ),
              SizedBox(height: 30.h),

              // Contact section
              Center(
                child: Text(
                  "Still have questions?\nContact support at:",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: secondaryTextColor, fontSize: 13.sp),
                ),
              ),
              SizedBox(height: 6.h),
              SelectableText(
                "work.amanojha30@gmail.com",
                style: TextStyle(
                  color: textColor, // Vibrant accent or primary color
                  fontWeight: FontWeight.w600,
                  fontSize: 14.sp,
                ),
              ),
              SizedBox(height: 24.h),
            ],
          ),
        ),
        bottomNavigationBar: const BottomNavBar(currentIndex: 3),
      ),
    );
  }
}

class _FAQTile extends StatelessWidget {
  final String question;
  final String answer;
  final bool isOpen;
  final VoidCallback onTap;
  final Color surface;
  final Color border;
  final Color textColor;
  final Color secondary;
  final bool isDark;

  const _FAQTile({
    required this.question,
    required this.answer,
    required this.isOpen,
    required this.onTap,
    required this.surface,
    required this.border,
    required this.textColor,
    required this.secondary,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        margin: EdgeInsets.only(bottom: 14.h),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isOpen ? border.withValues(alpha: 0.8) : border,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question Row
            Row(
              children: [
                Expanded(
                  child: Text(
                    question,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15.sp,
                      color: isOpen
                          ? (isDark
                                ? const Color(0xFF6C63FF)
                                : Colors.deepPurple)
                          : textColor,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: isOpen ? 0.5 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: isOpen
                        ? (isDark ? const Color(0xFF6C63FF) : Colors.deepPurple)
                        : textColor.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),

            // Animated Answer
            AnimatedCrossFade(
              firstChild: const SizedBox(),
              secondChild: Padding(
                padding: EdgeInsets.only(top: 10.h),
                child: Text(
                  answer,
                  style: TextStyle(
                    color: secondary,
                    fontSize: 13.5.sp,
                    height: 1.5,
                  ),
                ),
              ),
              crossFadeState: isOpen
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),
          ],
        ),
      ),
    );
  }
}
