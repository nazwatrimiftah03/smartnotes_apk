import 'package:flutter/material.dart';

import '../../core/app_error.dart';
import '../../core/app_events.dart';
import '../../models/category.dart';
import '../../services/category_service.dart';
import '../../widgets/soft_card.dart';
import 'category_form_sheet.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  final _service = CategoryService();
  late final TabController _tabC;

  List<Category> _categories = [];
  bool _loading = true;
  String? _error;

  String get _currentType => _tabC.index == 0 ? 'expense' : 'income';

  @override
  void initState() {
    super.initState();
    _tabC = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (!_tabC.indexIsChanging) setState(() {});
      });
    AppEvents.dataVersion.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    AppEvents.dataVersion.removeListener(_load);
    _tabC.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await _service.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = data;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorMessage(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kategori'),
        bottom: TabBar(
          controller: _tabC,
          tabs: const [
            Tab(text: 'Pengeluaran'),
            Tab(text: 'Pemasukan'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCategoryForm(context, type: _currentType),
        icon: const Icon(Icons.add_rounded),
        label: Text(
          _currentType == 'expense' ? 'Kategori pengeluaran' : 'Kategori pemasukan',
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null && _categories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Coba lagi')),
            ],
          ),
        ),
      );
    }

    return TabBarView(
      controller: _tabC,
      children: [
        _buildList('expense'),
        _buildList('income'),
      ],
    );
  }

  Widget _buildList(String type) {
    final scheme = Theme.of(context).colorScheme;
    final list = _categories.where((c) => c.type == type).toList();

    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Belum ada kategori.\nTap tombol di bawah untuk menambah.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
        children: [
          SoftCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < list.length; i++) ...[
                  InkWell(
                    onTap: () => showCategoryForm(
                      context,
                      type: type,
                      category: list[i],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: list[i].colorValue.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              list[i].iconData,
                              color: list[i].colorValue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              list[i].name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: scheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (i != list.length - 1)
                    Divider(
                      height: 1,
                      indent: 72,
                      endIndent: 16,
                      color: scheme.outlineVariant,
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Tap kategori untuk mengubah ikon, warna, atau menghapus.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}