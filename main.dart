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
  String type;
  double amount;
  String date;
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
    0xFF10B981,
    0xFF3B82F6,
    0xFFF59E0B,
    0xFF8B5CF6,
    0xFFEC4899,
    0xFF06B6D4,
    0xFFEF4444,
    0xFF84CC16,
    0xFFF97316,
    0xFF64748B,
  ];

  int _currentTabIndex = 0;
  late String _activeYearMonth;
  bool _isLoading = true;

  List<BudgetCategory> _categories = [];
  List<BudgetTransaction> _transactions = [];
  List<RecurringTemplate> _recurring = [];

  String _searchQuery = '';
  String _filterType = 'all';
  final TextEditingController _searchController = TextEditingController();

  String? _editingCategoryId;
  final TextEditingController _catNameController = TextEditingController();
  final TextEditingController _catLimitController = TextEditingController();
  int _selectedCatColor = paletteColors[0];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _activeYearMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
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
      BudgetCategory(id: 'cat_groceries', name: 'Groceries', limit: 800.0, colorValue: 0xFF10B981),
      BudgetCategory(id: 'cat_bills', name: 'Utilities & Bills', limit: 450.0, colorValue: 0xFF3B82F6),
      BudgetCategory(id: 'cat_transport', name: 'Fuel & Transport', limit: 300.0, colorValue: 0xFFF59E0B),
      BudgetCategory(id: 'cat_kids', name: 'Family & Kids', limit: 400.0, colorValue: 0xFF8B5CF6),
      BudgetCategory(id: 'cat_dining', name: 'Dining & Takeaway', limit: 200.0, colorValue: 0xFFEC4899),
      BudgetCategory(id: 'cat_investing', name: 'Investing & Savings', limit: 500.0, colorValue: 0xFF06B6D4),
      BudgetCategory(id: 'cat_misc', name: 'Discretionary / Misc', limit: 250.0, colorValue: 0xFF64748B),
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
        _categories = catList.map((e) => BudgetCategory.fromJson(Map<String, dynamic>.from(e))).toList();
        if (_categories.isEmpty) _categories = _getDefaultCategories();
        _transactions = txList.map((e) => BudgetTransaction.fromJson(Map<String, dynamic>.from(e))).toList();
        _recurring = recList.map((e) => RecurringTemplate.fromJson(Map<String, dynamic>.from(e))).toList();
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
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[(month - 1).clamp(0, 11)]} $year';
  }

  void _shiftMonth(int delta) {
    final parts = _activeYearMonth.split('-');
    final int year = int.tryParse(parts[0]) ?? 2026;
    final int month = int.tryParse(parts[1]) ?? 1;
    final DateTime shifted = DateTime(year, month + delta, 1);
    setState(() {
      _activeYearMonth = '${shifted.year}-${shifted.month.toString().padLeft(2, '0')}';
    });
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  List<BudgetTransaction> _getMonthTransactions() {
    final list = _transactions.where((t) => t.date.startsWith(_activeYearMonth)).toList();
    list.sort((a, b) {
      final int cmp = b.date.compareTo(a.date);
      if (cmp != 0) return cmp;
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  BudgetCategory _getCategoryById(String? id) {
    if (id == null) return BudgetCategory(id: 'other', name: 'Other', limit: 0, colorValue: 0xFF64748B);
    for (final c in _categories) {
      if (c.id == id) return c;
    }
    return BudgetCategory(id: 'other', name: 'Other', limit: 0, colorValue: 0xFF64748B);
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)),
    );
  }

  void _applyRecurringToMonth() {
    if (_recurring.isEmpty) {
      _showSnack('No recurring templates saved yet. Check "Repeat monthly" when adding a transaction.');
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Load Recurring Items'),
        content: Text('Add ${_recurring.length} recurring transaction(s) into ${_formatYearMonthLabel(_activeYearMonth)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              final int nowMs = DateTime.now().millisecondsSinceEpoch;
              final String dateStr = '$_activeYearMonth-01';
              setState(() {
                for (int i = 0; i < _recurring.length; i++) {
                  final r = _recurring[i];
                  _transactions.add(BudgetTransaction(
                    id: 'tx_${nowMs}_$i',
                    type: r.type,
                    amount: r.amount,
                    date: dateStr,
                    note: r.note,
                    categoryId: r.categoryId,
                    createdAt: nowMs + i,
                  ));
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
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _openTransactionModal(preselectedCategoryId: cat.id),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: Color(cat.colorValue),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              cat.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF94A3B8),
                            ),
                            children: [
                              TextSpan(
                                text: _formatCurrency(spent),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(text: ' / ${_formatCurrency(limit)}'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: const Color(0xFF0F172A),
                        valueColor: AlwaysStoppedAnimation<Color>(barColor),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          left >= 0
                              ? '${_formatCurrency(left)} left (Tap to log)'
                              : '${_formatCurrency(left.abs())} over budget',
                          style: TextStyle(
                            fontSize: 12,
                            color: left >= 0
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFFEF4444),
                          ),
                        ),
                        Text(
                          limit > 0 ? '$pct%' : '-',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF94A3B8),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsTab() {
    final monthTxs = _getMonthTransactions();
    final filtered = monthTxs.where((t) {
      if (_filterType != 'all' && t.type != _filterType) return false;
      if (_searchQuery.isEmpty) return true;
      final String q = _searchQuery.toLowerCase();
      final String catName = t.type == 'income'
          ? 'income'
          : _getCategoryById(t.categoryId).name.toLowerCase();
      return t.note.toLowerCase().contains(q) || catName.contains(q);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                decoration: InputDecoration(
                  hintText: 'Search notes or category...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildFilterChip('All', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Expenses', 'expense'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Income', 'income'),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'No transactions in ${_formatYearMonthLabel(_activeYearMonth)}.',
                    style: const TextStyle(color: Color(0xFF94A3B8)),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, idx) {
                    final tx = filtered[idx];
                    final bool isIncome = tx.type == 'income';
                    final BudgetCategory cat = isIncome
                        ? BudgetCategory(
                            id: 'inc',
                            name: 'Income',
                            limit: 0,
                            colorValue: 0xFF10B981,
                          )
                        : _getCategoryById(tx.categoryId);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Color(cat.colorValue),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tx.note,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      tx.date,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF334155),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        cat.name,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${isIncome ? '+' : '-'}${_formatCurrency(tx.amount)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isIncome
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFEF4444),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            onPressed: () =>
                                _openTransactionModal(existingTx: tx),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: Color(0xFFEF4444),
                            ),
                            onPressed: () => _confirmDeleteTransaction(tx),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final bool selected = _filterType == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: const Color(0xFF3B82F6),
      onSelected: (_) => setState(() => _filterType = value),
    );
  }
  Widget _buildCategoriesTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _editingCategoryId == null
                    ? 'Add Category Envelope'
                    : 'Edit Category Envelope',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _catNameController,
                decoration: InputDecoration(
                  labelText: 'Category Name',
                  hintText: 'e.g., Groceries',
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _catLimitController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Monthly Target (\$)',
                  prefixText: '\$ ',
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Envelope Color',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: paletteColors.map((colorVal) {
                  final bool isSelected = _selectedCatColor == colorVal;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCatColor = colorVal),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Color(colorVal),
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              size: 18,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _saveCategoryFromForm,
                      child: Text(
                        _editingCategoryId == null
                            ? 'Save Category'
                            : 'Update Category',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  if (_editingCategoryId != null) ...[
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: _resetCategoryForm,
                      child: const Text('Cancel'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Active Categories',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        ..._categories.map((cat) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Color(cat.colorValue),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cat.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'Monthly Target: ${_formatCurrency(cat.limit)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () {
                    setState(() {
                      _editingCategoryId = cat.id;
                      _catNameController.text = cat.name;
                      _catLimitController.text = cat.limit.toStringAsFixed(2);
                      _selectedCatColor = cat.colorValue;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: Color(0xFFEF4444),
                  ),
                  onPressed: () => _deleteCategory(cat),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  void _saveCategoryFromForm() {
    final String name = _catNameController.text.trim();
    final double limit =
        double.tryParse(_catLimitController.text.trim()) ?? 0.0;
    if (name.isEmpty) {
      _showSnack('Please enter a category name.');
      return;
    }

    setState(() {
      if (_editingCategoryId != null) {
        final idx = _categories.indexWhere((c) => c.id == _editingCategoryId);
        if (idx != -1) {
          _categories[idx] = BudgetCategory(
            id: _editingCategoryId!,
            name: name,
            limit: limit,
            colorValue: _selectedCatColor,
          );
        }
      } else {
        _categories.add(
          BudgetCategory(
            id: 'cat_${DateTime.now().millisecondsSinceEpoch}',
            name: name,
            limit: limit,
            colorValue: _selectedCatColor,
          ),
        );
      }
      _resetCategoryForm();
    });
    _saveData();
    _showSnack('Category saved!');
  }

  void _resetCategoryForm() {
    setState(() {
      _editingCategoryId = null;
      _catNameController.clear();
      _catLimitController.clear();
      _selectedCatColor = paletteColors[0];
    });
  }

  void _deleteCategory(BudgetCategory cat) {
    if (_categories.length <= 1) {
      _showSnack('You must keep at least one category.');
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Delete Category'),
        content: Text('Delete "${cat.name}"? Existing transactions stay safe.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _categories.removeWhere((c) => c.id == cat.id));
              _saveData();
              _showSnack('Category deleted.');
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Backup & Spreadsheet Export',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'All data is stored privately on your Android device. Copy a JSON backup or CSV export to your clipboard anytime.',
                style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _copyJsonBackup,
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy Full JSON Backup to Clipboard'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF334155)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _copyCsvExport,
                icon: const Icon(Icons.table_chart_outlined, size: 18),
                label: const Text('Copy All Transactions as CSV'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF334155)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _openRestoreJsonDialog,
                icon: const Icon(Icons.restore, size: 18),
                label: const Text('Restore from JSON Backup'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Recurring Monthly Templates (${_recurring.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Load these into any month with one tap on the Dashboard.',
                style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 12),
              if (_recurring.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No recurring templates saved yet.',
                    style: TextStyle(color: Color(0xFF94A3B8)),
                  ),
                )
              else
                ..._recurring.map((r) {
                  final bool isInc = r.type == 'income';
                  final String catName = isInc
                      ? 'Income'
                      : _getCategoryById(r.categoryId).name;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      r.note,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '$catName • ${isInc ? 'Income' : 'Expense'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatCurrency(r.amount),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isInc
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Color(0xFFEF4444),
                          ),
                          onPressed: () {
                            setState(() =>
                                _recurring.removeWhere((item) => item.id == r.id));
                            _saveData();
                          },
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFEF4444)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Danger Zone',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFEF4444),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Permanently erase all transactions and reset categories to defaults.',
                style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                ),
                onPressed: _confirmFactoryReset,
                child: const Text('Factory Reset All Data'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _copyJsonBackup() {
    final String jsonStr = const JsonEncoder.withIndent('  ').convert({
      'categories': _categories.map((e) => e.toJson()).toList(),
      'transactions': _transactions.map((e) => e.toJson()).toList(),
      'recurring': _recurring.map((e) => e.toJson()).toList(),
    });
    Clipboard.setData(ClipboardData(text: jsonStr));
    _showSnack('JSON backup copied to clipboard!');
  }

  void _copyCsvExport() {
    final List<String> rows = ['Date,Type,Category,Description,Amount'];
    final sorted = List<BudgetTransaction>.from(_transactions)
      ..sort((a, b) => b.date.compareTo(a.date));
    for (final t in sorted) {
      final String catName =
          t.type == 'income' ? 'Income' : _getCategoryById(t.categoryId).name;
      final String safeCat = '"${catName.replaceAll('"', '""')}"';
      final String safeNote = '"${t.note.replaceAll('"', '""')}"';
      final String signedAmt = t.type == 'income'
          ? t.amount.toStringAsFixed(2)
          : (-t.amount).toStringAsFixed(2);
      rows.add('${t.date},${t.type},$safeCat,$safeNote,$signedAmt');
    }
    Clipboard.setData(ClipboardData(text: rows.join('\n')));
    _showSnack('CSV transactions copied to clipboard!');
  }

  void _openRestoreJsonDialog() {
    final TextEditingController jsonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Restore JSON Backup'),
        content: TextField(
          controller: jsonCtrl,
          maxLines: 6,
          decoration: InputDecoration(
            hintText: 'Paste your PocketLedger JSON backup here...',
            filled: true,
            fillColor: const Color(0xFF0F172A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
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
              try {
                final Map<String, dynamic> parsed =
                    jsonDecode(jsonCtrl.text.trim());
                final List<dynamic> catList = parsed['categories'] ?? [];
                final List<dynamic> txList = parsed['transactions'] ?? [];
                final List<dynamic> recList = parsed['recurring'] ?? [];

                setState(() {
                  _categories = catList
                      .map((e) =>
                          BudgetCategory.fromJson(Map<String, dynamic>.from(e)))
                      .toList();
                  _transactions = txList
                      .map((e) => BudgetTransaction.fromJson(
                          Map<String, dynamic>.from(e)))
                      .toList();
                  _recurring = recList
                      .map((e) => RecurringTemplate.fromJson(
                          Map<String, dynamic>.from(e)))
                      .toList();
                });
                _saveData();
                Navigator.pop(ctx);
                _showSnack('Backup restored!');
              } catch (e) {
                _showSnack('Invalid JSON backup format.');
       

