import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'dart:convert';
import 'dart:developer';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:money_control/Repositories/category_rules_repository.dart';
import 'package:money_control/Services/category_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SmsTransaction {
  final String sender;
  final String body;
  final DateTime date;
  final double amount;
  final String merchant;
  final bool isDebit; // true for Debit, false for Credit
  final String category;

  SmsTransaction({
    required this.sender,
    required this.body,
    required this.date,
    required this.amount,
    this.merchant = 'Unknown',
    required this.isDebit,
    this.category = 'Uncategorized',
  });
}

class SmsService {
  final SmsQuery _query = SmsQuery();
  final CategoryRulesRepository _rulesRepository = CategoryRulesRepository();

  Map<String, List<String>> _currentRules = {};
  bool _rulesLoaded = false;

  // Merchant → category corrections learned from user edits (loaded on initRules)
  static Map<String, String> _correctionCache = {};

  // Merchant → category learned from past Firestore transactions
  static Map<String, String> _historyCache = {};
  static bool _historyLoaded = false;

  // Default rules — also exposed statically so BackgroundWorker can use them without an instance
  static const Map<String, List<String>> defaultRules = {
    'Food': [
      'zomato',
      'swiggy',
      'kfc',
      'mcdonald',
      'pizza',
      'burger',
      'restaurant',
      'cafe',
      'dining',
      'starbucks',
      'domino',
      'biryani',
      'food',
    ],
    'Travel': [
      'uber',
      'ola',
      'rapido',
      'irctc',
      'railway',
      'flight',
      'indigo',
      'airasia',
      'petrol',
      'fuel',
      'shell',
      'hpcl',
      'bpcl',
      'toll',
      'fastag',
      'metro',
    ],
    'Shopping': [
      'amazon',
      'flipkart',
      'myntra',
      'jiomart',
      'retail',
      'store',
      'mall',
      'mart',
      'fashion',
      'clothing',
      'ajio',
      'trends',
      'zudio',
      'decathlon',
    ],
    'Groceries': [
      'bigbasket',
      'blinkit',
      'instamart',
      'zepto',
      'dmart',
      'reliance fresh',
      'vegetable',
      'fruit',
      'grocery',
      'milk',
      'dairy',
    ],
    'Entertainment': [
      'netflix',
      'spotify',
      'prime',
      'cinema',
      'movie',
      'pvr',
      'inox',
      'hotstar',
      'youtube',
      'subscription',
      'game',
      'steam',
    ],
    'Health': [
      'pharmacy',
      'hospital',
      'clinic',
      'medical',
      'dr ',
      'health',
      'medplus',
      'apollo',
      '1mg',
      'pharmeasy',
      'medicine',
    ],
    'Utilities': [
      'bill',
      'electricity',
      'water',
      'gas',
      'broadband',
      'wifi',
      'airtel',
      'jio',
      'vi',
      'bsnl',
      'recharge',
      'dth',
      'mobile',
    ],
    'Investment': [
      'zerodha',
      'groww',
      'upstox',
      'sip',
      'mutual fund',
      'stock',
      'invest',
    ],
  };

  SmsService() {
    _currentRules = Map.from(defaultRules);
  }

  // ---- Static helpers used by BackgroundWorker (no plugin/Firebase deps) ----

  static bool isBankSms(String body) {
    if (body.isEmpty) return false;
    final lower = body.toLowerCase();
    if (lower.contains('otp')) return false;
    return lower.contains('debited') ||
        lower.contains('credited') ||
        lower.contains('spent') ||
        lower.contains('sent') ||
        lower.contains('paid') ||
        lower.contains('received') ||
        lower.contains('txn') ||
        lower.contains('withdraw') ||
        lower.contains('purchase') ||
        lower.contains('alert') ||
        lower.contains('transferred');
  }

  static String _getCategoryStatic(
    String merchant,
    String body,
    Map<String, List<String>> rules,
  ) {
    final lowerBody = body.toLowerCase();
    final lowerMerchant = merchant.toLowerCase();
    for (final entry in rules.entries) {
      for (final keyword in entry.value) {
        if (lowerMerchant.contains(keyword.toLowerCase()) ||
            lowerBody.contains(keyword.toLowerCase())) {
          return entry.key;
        }
      }
    }
    // Fall back to user-correction cache
    if (_correctionCache.containsKey(lowerMerchant)) {
      return _correctionCache[lowerMerchant]!;
    }
    // Fall back to history-based category
    final historyCategory = _getCategoryFromHistory(merchant);
    if (historyCategory != null) return historyCategory;
    return 'Uncategorized';
  }

  static String? _getCategoryFromHistory(String merchant) {
    if (!_historyLoaded || _historyCache.isEmpty) return null;
    final lowerMerchant = merchant.toLowerCase().trim();
    // Exact match
    if (_historyCache.containsKey(lowerMerchant)) return _historyCache[lowerMerchant]!;
    // Substring match: check if any cached merchant is contained in or contains the query
    for (final entry in _historyCache.entries) {
      final cachedMerchant = entry.key;
      if (lowerMerchant.contains(cachedMerchant) ||
          cachedMerchant.contains(lowerMerchant)) {
        return entry.value;
      }
    }
    return null;
  }

  /// Build a merchant→category cache from past Firestore transactions.
  /// Called during initRules (foreground) or by background worker before parsing.
  static Future<void> buildHistoryCache() async {
    if (_historyLoaded) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) return;
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.email)
          .collection('transactions')
          .orderBy('date', descending: true)
          .limit(500)
          .get();

      final frequency = <String, Map<String, int>>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final category = data['category'] as String?;
        final recipientName = data['recipientName'] as String?;
        if (category == null || category.isEmpty) continue;
        if (recipientName == null || recipientName.isEmpty || recipientName == 'Unknown' || recipientName == 'External' || recipientName == 'Self') continue;
        if (category == 'Income' || category == 'Refund' || category == 'Transfer' || category == 'Loan/EMI' || category == 'Salary') continue;
        final key = recipientName.toLowerCase().trim();
        frequency[key] ??= {};
        frequency[key]![category] = (frequency[key]![category] ?? 0) + 1;
      }

      _historyCache = {};
      frequency.forEach((merchant, catCounts) {
        // Pick the most frequent category for this merchant
        String? bestCat;
        int bestCount = 0;
        catCounts.forEach((cat, count) {
          if (count > bestCount) {
            bestCount = count;
            bestCat = cat;
          }
        });
        if (bestCat != null && bestCount >= 2) {
          _historyCache[merchant] = bestCat!;
        }
      });
      _historyLoaded = true;
    } catch (e) {
      log("Error building history cache: $e");
    }
  }

  static String _getCreditCategory(String body) {
    final lower = body.toLowerCase();
    const loanKeywords = [
      'emi', 'loan', 'payoff', 'pay off', 'installment',
      'lender', 'towards loan', 'loan repay', 'mortgage',
      'noc', 'settlement', 'disburs', 'advance emi',
    ];
    for (final kw in loanKeywords) {
      if (lower.contains(kw)) return 'Loan/EMI';
    }
    const transferKeywords = ['neft', 'imps', 'rtgs', 'self transfer'];
    for (final kw in transferKeywords) {
      if (lower.contains(kw)) return 'Transfer';
    }
    if (lower.contains('refund') || lower.contains('cashback')) return 'Refund';
    const salaryKeywords = ['salary', 'sal ', 'payroll', 'wages', 'stipend', 'remuneration'];
    for (final kw in salaryKeywords) {
      if (lower.contains(kw)) return 'Salary';
    }
    return 'Income';
  }

  static SmsTransaction? parseMessage(
    String body,
    String sender,
    DateTime date, {
    Map<String, List<String>> rules = defaultRules,
  }) {
    final lower = body.toLowerCase();

    final amountRegex = RegExp(
      r'(?:Rs\.?|INR|MRP|Amt|Amount)\W*(\d+(?:,\d+)*(?:\.\d{1,2})?)',
      caseSensitive: false,
    );
    var match = amountRegex.firstMatch(body);

    // Fallback: match bare amount if no currency prefix found
    if (match == null) {
      final bareAmountRegex = RegExp(r'(?:^|[^\d])(\d{2,}(?:,\d{3})*(?:\.\d{1,2})?)(?:\b|$)');
      match = bareAmountRegex.firstMatch(body);
    }

    if (match == null) return null;

    String amountStr = (match.group(1) ?? '0').replaceAll(',', '');
    final double amount = double.tryParse(amountStr) ?? 0;
    if (amount == 0) return null;

    bool isDebit = true;

    // Explicit debit signals — check first so they win over ambiguous keywords
    final hasDebitSignal = lower.contains('debited') ||
        lower.contains('deducted') ||
        lower.contains('withdrawn') ||
        lower.contains('spent') ||
        lower.contains('sent');

    // Unambiguous credit signals
    final hasCreditSignal = lower.contains('credited') ||
        lower.contains('deposit');

    if (lower.contains('refund') || lower.contains('cashback')) {
      isDebit = false;
    } else if (hasDebitSignal) {
      isDebit = true;
    } else if (hasCreditSignal) {
      isDebit = false;
    } else if (lower.contains('received')) {
      // "received by MERCHANT" → debit (merchant received money FROM you)
      // "received by you" / "received in/to/into/from" → credit (money came INTO your account)
      if (lower.contains('received by')) {
        final afterBy = lower.split('received by').last.trimLeft();
        final creditSelf = afterBy.startsWith('you') ||
            afterBy.startsWith('your') ||
            afterBy.startsWith('me');
        isDebit = !creditSelf;
      } else if (lower.contains('received in') ||
          lower.contains('received to') ||
          lower.contains('received into') ||
          lower.contains('received from')) {
        isDebit = false;
      } else {
        // bare "received" → credit (you received money)
        isDebit = false;
      }
    }

    String merchant = 'Unknown';

    String? findEntity(List<String> prepositions, {bool allowGenerics = false}) {
      final pattern =
          '(?:${prepositions.join('|')}|@)\\s+([A-Za-z0-9\\s\\.\\*\\-&]{3,25})(?:\\s+(?:on|via|using|ref)|\\.|\\,|\$|\\;)';
      final reg = RegExp(pattern, caseSensitive: false);
      for (final m in reg.allMatches(body)) {
        final val = m.group(1)?.trim();
        if (val != null &&
            !val.toLowerCase().contains('rs.') &&
            !val.toLowerCase().contains('inr') &&
            !val.startsWith(RegExp(r'[0-9]'))) {
          if (!allowGenerics) {
            if (val.toLowerCase().contains(' card') ||
                val.toLowerCase().contains(' account') ||
                val.toLowerCase().contains(' a/c') ||
                val.toLowerCase().contains(' bank')) {
              continue;
            }
          }
          return val;
        }
      }
      return null;
    }

    if (isDebit) {
      final bMatch = RegExp(
        r'([A-Za-z0-9\s\.\*\-&]{3,25})\s+(?:credited|received)',
        caseSensitive: false,
      ).firstMatch(body);
      if (bMatch != null) {
        final c = bMatch.group(1)?.trim();
        if (c != null &&
            !c.toLowerCase().contains('account') &&
            !c.toLowerCase().contains('you') &&
            !c.toLowerCase().contains('msg')) {
          merchant = c;
        }
      }
      merchant = merchant == 'Unknown'
          ? findEntity(['to', 'at', 'via', 'for']) ?? 'Unknown'
          : merchant;
      merchant = merchant == 'Unknown'
          ? findEntity(['using', 'via'], allowGenerics: true) ?? 'Unknown'
          : merchant;
    } else {
      merchant = findEntity(['from', 'by'], allowGenerics: true) ?? 'Unknown';
    }

    if ((merchant == 'Unknown') &&
        !RegExp(r'\d').hasMatch(sender) &&
        sender.length > 2) {
      merchant = sender;
    }
    if (merchant.length > 20) merchant = merchant.substring(0, 20);

    final category = isDebit
        ? _getCategoryStatic(merchant, body, rules)
        : _getCreditCategory(body);

    return SmsTransaction(
      sender: sender,
      body: body,
      date: date,
      amount: amount,
      merchant: merchant,
      isDebit: isDebit,
      category: category,
    );
  }

  static const String _userRulesKey = 'user_custom_sms_rules';

  static Future<Map<String, List<String>>> loadUserCustomRules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_userRulesKey);
      if (json == null) return {};
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, List<String>.from(v as List)));
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveUserCustomRules(Map<String, List<String>> rules) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userRulesKey, jsonEncode(rules));
  }

  Future<void> initRules() async {
    if (_rulesLoaded) return;
    try {
      final fetched = await _rulesRepository.fetchRules();
      if (fetched.isNotEmpty) {
        fetched.forEach((key, value) {
          _currentRules[key] = value;
        });
      }
      // Merge user custom rules (stored locally, no Firebase cost)
      final userRules = await loadUserCustomRules();
      userRules.forEach((key, keywords) {
        _currentRules[key] = [...(_currentRules[key] ?? []), ...keywords];
      });
      // Load correction cache for merchant-level fallback
      final corrections = await CategoryService.getPendingSuggestions();
      _correctionCache = {
        for (final s in corrections)
          (s['merchant'] as String).toLowerCase(): s['category'] as String,
      };
      // Build category cache from past transactions
      await buildHistoryCache();
      _rulesLoaded = true;
    } catch (e) {
      log("Error initializing rules: $e");
    }
  }

  /// Request permissions and fetch SMS. Returns parsed transactions.
  /// Returns null if permission is denied (caller should show settings prompt).
  Future<List<SmsTransaction>?> scanMessages({int limit = 50}) async {
    await initRules();

    var status = await Permission.sms.status;
    if (!status.isGranted) {
      if (status.isPermanentlyDenied) {
        return null;
      }
      status = await Permission.sms.request();
      if (!status.isGranted) {
        return status.isPermanentlyDenied ? null : [];
      }
    }

    try {
      final messages = await _query.querySms(
        kinds: [SmsQueryKind.inbox],
        count: limit,
      );

      final List<SmsTransaction> transactions = [];
      for (final msg in messages) {
        if (isBankSms(msg.body ?? '')) {
          final tx = parseMessage(
            msg.body ?? '',
            msg.sender ?? 'Unknown',
            msg.date ?? DateTime.now(),
            rules: _currentRules,
          );
          if (tx != null) transactions.add(tx);
        }
      }
      return transactions;
    } catch (e) {
      log("Error scanning SMS: $e");
      return [];
    }
  }
}
