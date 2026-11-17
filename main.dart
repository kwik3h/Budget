import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0xFF0F172A),
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0F172A),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const PocketLedgerApp());
}

class PocketLedgerApp extends StatelessWidget {
  const PocketLedgerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PocketLedger',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        primaryColor: const Color(0xFF3B82F6),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF3B82F6),
          secondary: Color(0xFF10B981),
          surface: Color(0xFF1E293B),
          error: Color(0xFFEF4444),
        ),
        useMaterial3: true,
      ),
      home: const BudgetHomeScreen(),
    );
  }
}

class BudgetCategory {
  String id;
  String name;
  double limit;
  int colorValue;

  BudgetCategory({
    required this.id,
    required this.name,
    required this.limit,
    required this.colorValue,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'limit': limit,
        'colorValue': colorValue,
      };

  factory BudgetCategory.fromJson(Map<String, dynamic> json) {
    return BudgetCategory(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Category',
      limit: (json['limit'] as num?)?.toDouble() ?? 0.0,
      colorValue: (json['colorValue'] as num?)?.toInt() ?? 0xFF3B82F6,
    );
  }
}

class BudgetTransaction {
  String id;
  String type; // 'expense' or 'income'
  double amount;
  String date; // YYYY-MM-DD
  String note;
  String? categoryId;
  int createdAt;

  BudgetTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    required this.note,
    this.categoryId,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'amount': amount,
        'date': date,
        'note': note,
        'categoryId': categoryId,
        'createdAt': createdAt,
      };

  factory BudgetTransaction.fromJson(Map<String, dynamic> json) {
    return BudgetTransaction(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'expense',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      date: json['date']?.toString() ?? '2026-11-01',
      note: json['note']?.toString() ?? '',
      categoryId: json['categoryId']?.toString(),
      createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
    );
  }
}

class RecurringTemplate {
  String id;
  String type;
  double amount;
  String note;
  String? categoryId;

  RecurringTemplate({
    required this.id,
    required this.type,
    required this.amount,
    required this.note,
    this.categoryId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'amount': amount,
        'note': note,
        'categoryId': categoryId,
      };

  factory RecurringTemplate.fromJson(Map<String, dynamic> json) {
    return RecurringTemplate(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'expense',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      note: json['note']?.toString() ?? '',
      categoryId: json['categoryId']?.toString(),
    );
  }
}

class BudgetHomeScreen extends StatefulWidget {
  const BudgetHomeScreen({super.key});

  @override
  State<BudgetHomeScreen> createState() => _BudgetHomeScreenState();
}

class _BudgetHomeScreenState extends State<BudgetHomeScreen> {
  static const String storageKey = 'pocketledger_native_v1';

  static const List<int> paletteColors = [
    0xFF10B981, // Emerald
    0xFF3B82F6, // Blue
    0xFFF59E0B, // Amber
    0xFF8B5CF6, // Purple
    0xFFEC4899, // Pink
    0xFF06B6D4, // Cyan
    0xFFEF4444, // Red
    0xFF84CC16, // Lime
    0xFFF97316, // Orange
    0xFF64748B, // Slate
  ];

  int _currentTabIndex = 0;
  late String _activeYearMonth;
  bool _isLoading = true;

  List<BudgetCategory> _categories = [];
  List<BudgetTransaction> _transactions = [];
  List<RecurringTemplate> _recurring = [];

  // Search and Filter state for History tab
  String _searchQuery = '';
  String _filterType = 'all';
  final TextEditingController _searchController = TextEditingController();

  // Category Form state for Budgets tab
  String? _editingCategoryId;
  final TextEditingController _catNameController = TextEditingController();
  final TextEditingController _catLimitController = TextEditingController();
  int _selectedCatColor = paletteColors[0];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _activeYearMonth =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _catNameController.dispose();
    _catLimitController.dispose();
    super.dispose();
  }

  List<BudgetCategory> _getDefaultCategories() {
    return [
      BudgetCategory(
        id: 'cat_groceries',
        name: 'Groceries',
        limit: 800.0,
        colorValue: 0xFF10B981,
      ),
      BudgetCategory(
        id: 'cat_bills',
        name: 'Utilities & Bills',
        limit: 450.0,
        colorValue: 0xFF3B82F6,
      ),
      BudgetCategory(
        id: 'cat_transport',
        name: 'Fuel & Transport',
        limit: 300.0,
        colorValue: 0xFFF59E0B,
      ),
      BudgetCategory(
        id: 'cat_kids',
        name: 'Family & Kids',
        limit: 400.0,
        colorValue: 0xFF8B5CF6,
      ),
      BudgetCategory(
        id: 'cat_dining',
        name: 'Dining & Takeaway',
        limit: 200.0,
        colorValue: 0xFFEC4899,
      ),
      BudgetCategory(
        id: 'cat_investing',
        name: 'Investing & Savings',
        limit: 500.0,
        colorValue: 0xFF06B6D4,
      ),
      BudgetCategory(
        id: 'cat_misc',
        name: 'Discretionary / Misc',
        limit: 250.0,
        colorValue: 0xFF64748B,
      ),
    ];
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw == null || raw.isEmpty) {
        setState(() {
          _categories = _getDefaultCategories();
          _transactions = [];
          _recurring = [];
          _isLoading = false;
        });
        await _saveData();
        return;
      }

      final Map<String, dynamic> decoded = jsonDecode(raw);
      final List<dynamic> catList = decoded['categories'] ?? [];
      final List<dynamic> txList = decoded['transactions'] ?? [];
      final List<dynamic> recList = decoded['recurring'] ?? [];

      setState(() {
        _categories = catList
            .map((e) => BudgetCategory.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        if (_categories.isEmpty) {
          _categories = _getDefaultCategories();
        }
        _transactions = txList
            .map((e) =>
                BudgetTransaction.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _recurring = recList
            .map((e) =>
                RecurringTemplate.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _categories = _getDefaultCategories();
        _transactions = [];
        _recurring = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode({
      'categories': _categories.map((e) => e.toJson()).toList(),
      'transactions': _transactions.map((e) => e.toJson()).toList(),
      'recurring': _recurring.map((e) => e.toJson()).toList(),
    });
    await prefs.setString(storageKey, payload);
  }

  String _formatCurrency(double value) {
    final bool isNeg = value < 0;
    final double absVal = value.abs();
    final String fixed = absVal.toStringAsFixed(2);
    final List<String> parts = fixed.split('.');
    final String intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '${isNeg ? '-' : ''}\$$intPart.${parts[1]}';
  }

  String _formatYearMonthLabel(String ym) {
    final parts = ym.split('-');
    if (parts.length != 2) return ym;
    final int year = int.tryParse(parts[0]) ?? 2026;
    final int month = int.tryParse(parts[1]) ?? 1;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final String mName = months[(month - 1).clamp(0, 11)];
    return '$mName $year';
  }

  void _shiftMonth(int delta) {
    final parts = _activeYearMonth.split('-');
    final int year = int.tryParse(parts[0]) ?? 2026;
    final int month = int.tryParse(parts[1]) ?? 1;
    final DateTime shifted = DateTime(year, month + delta, 1);
    setState(() {
      _activeYearMonth =
          '${shifted.year}-${shifted.month.toString().padLeft(2, '0')}';
    });
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  List<BudgetTransaction> _getMonthTransactions() {
    final list = _transactions
        .where((t) => t.date.startsWith(_activeYearMonth))
        .toList();
    list.sort((a, b) {
      final int cmp = b.date.compareTo(a.date);
      if (cmp != 0) return cmp;
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  BudgetCategory _getCategoryById(String? id) {
    if (id == null) {
      return BudgetCategory(
        id: 'other',
        name: 'Other',
        limit: 0,
        colorValue: 0xFF64748B,
      );
    }
    for (final c in _categories) {
      if (c.id == id) return c;
    }
    return BudgetCategory(
      id: 'other',
      name: 'Other',
      limit: 0,
      colorValue: 0xFF64748B,
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _applyRecurringToMonth() {
    if (_recurring.isEmpty) {
      _showSnack(
        'No recurring templates saved yet. Check "Repeat monthly" when adding a transaction.',
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Load Recurring Items'),
        content: Text(
          'Add ${_recurring.length} recurring transaction(s) into ${_formatYearMonthLabel(_activeYearMonth)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              final int nowMs = DateTime.now().millisecondsSinceEpoch;
              final String dateStr = '$_activeYearMonth-01';
              setState(() {
                for (int i = 0; i < _recurring.length; i++) {
                  final r = _recurring[i];
                  _transactions.add(
                    BudgetTransaction(
                      id: 'tx_${nowMs}_$i',
                      type: r.type,
                      amount: r.amount,
                      date: dateStr,
                      note: r.note,
                      categoryId: r.categoryId,
                      createdAt: nowMs + i,
                    ),
                  );
                }
              });
              _saveData();
              _showSnack('Recurring transactions added!');
            },
            child: const Text('Load Items'),
          ),
        ],
      ),
    );
  }

  void _openTransactionModal({
    BudgetTransaction? existingTx,
    String? preselectedCategoryId,
  }) {
    final bool isEditing = existingTx != null;
    String txType = existingTx?.type ?? 'expense';
    final TextEditingController amountCtrl = TextEditingController(
      text: existingTx != null ? existingTx.amount.toStringAsFixed(2) : '',
    );
    final TextEditingController noteCtrl = TextEditingController(
      text: existingTx?.note ?? '',
    );

    final String today = _todayString();
    String selectedDate = existingTx?.date ??
        (today.startsWith(_activeYearMonth) ? today : '$_activeYearMonth-01');

    String selectedCategoryId = preselectedCategoryId ??
        existingTx?.categoryId ??
        (_categories.isNotEmpty ? _categories.first.id : '');
    if (!_categories.any((c) => c.id == selectedCategoryId) &&
        _categories.isNotEmpty) {
      selectedCategoryId = _categories.first.id;
    }

    bool saveAsRecurring = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 20,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEditing ? 'Edit Transaction' : 'New Transaction',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Expense / Income Toggle
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  setModalState(() => txType = 'expense'),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: txType == 'expense'
                                      ? const Color(0xFFEF4444)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Expense',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: txType == 'expense'
                                        ? Colors.white
                                        : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  setModalState(() => txType = 'income'),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: txType == 'income'
                                      ? const Color(0xFF10B981)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Income',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: txType == 'income'
                                        ? Colors.white
                                        : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: amountCtrl,
                            autofocus: !isEditing,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Amount (\$)',
                              prefixText: '\$ ',
                              filled: true,
                              fillColor: const Color(0xFF0F172A),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final DateTime initial =
                                  DateTime.tryParse(selectedDate) ??
                                      DateTime.now();
                              final DateTime? picked = await showDatePicker(
                                context: modalCtx,
                                initialDate: initial,
                                firstDate: DateTime(2020),
                            
