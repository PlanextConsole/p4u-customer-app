import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/map_ext.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/customer_scaffold.dart';
import '../../../../core/widgets/remote_image.dart';
import '../../data/customer_providers.dart';

enum _CatalogStep { categories, subcategories, results }

class CustomerShopCatalogPage extends ConsumerWidget {
  const CustomerShopCatalogPage({
    this.initialCategoryId,
    this.initialSearch,
    super.key,
  });

  final String? initialCategoryId;
  final String? initialSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _CatalogFlowPage(
        kind: 'product',
        initialCategoryId: initialCategoryId,
        initialSearch: initialSearch,
      );
}

class CustomerServiceCatalogPage extends ConsumerWidget {
  const CustomerServiceCatalogPage({
    this.initialCategoryId,
    this.initialSearch,
    super.key,
  });

  final String? initialCategoryId;
  final String? initialSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _CatalogFlowPage(
        kind: 'service',
        initialCategoryId: initialCategoryId,
        initialSearch: initialSearch,
      );
}

class _CatalogFlowPage extends ConsumerStatefulWidget {
  const _CatalogFlowPage({
    required this.kind,
    this.initialCategoryId,
    this.initialSearch,
  });

  final String kind;
  final String? initialCategoryId;
  final String? initialSearch;

  @override
  ConsumerState<_CatalogFlowPage> createState() => _CatalogFlowPageState();
}

class _CatalogFlowPageState extends ConsumerState<_CatalogFlowPage> {
  final _search = TextEditingController();
  _CatalogStep _step = _CatalogStep.categories;
  List<Map<String, dynamic>> _categories = const [];
  List<Map<String, dynamic>> _subcategories = const [];
  List<Map<String, dynamic>> _results = const [];
  Map<String, dynamic>? _category;
  Map<String, dynamic>? _subcategory;
  Object? _error;
  bool _loading = true;
  bool _grid = true;
  bool _gpsOn = false;
  bool _offersOnly = false;
  double _minimumRating = 0;
  String _sort = 'latest';
  Set<String> _productWishlist = const {};
  Set<String> _serviceWishlist = const {};

  bool get _isShop => widget.kind == 'product';
  String get _plural => _isShop ? 'Products' : 'Services';

  @override
  void initState() {
    super.initState();
    _search.text = widget.initialSearch ?? '';
    _bootstrap();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _isRoot(Map<String, dynamic> row) {
    final parent = row.s('parentId', row.s('parent_id'));
    return parent.isEmpty;
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(customerRepositoryProvider);
      final values = await Future.wait<Object>([
        repo.catalogCategories(kind: widget.kind),
        if (_isShop) repo.wishlist() else repo.serviceWishlist(),
      ]);
      final roots =
          (values[0] as List<Map<String, dynamic>>).where(_isRoot).toList();
      if (!mounted) return;
      setState(() {
        _categories = roots;
        if (_isShop) {
          _productWishlist = values[1] as Set<String>;
        } else {
          _serviceWishlist = values[1] as Set<String>;
        }
      });

      final requestedId = widget.initialCategoryId?.trim() ?? '';
      final requested =
          roots.where((row) => row.s('id') == requestedId).firstOrNull;
      if (requested != null) {
        await _selectCategory(requested);
      } else if (_search.text.trim().isNotEmpty) {
        await _showAllResults();
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  Future<void> _selectCategory(Map<String, dynamic> category) async {
    setState(() {
      _category = category;
      _subcategory = null;
      _subcategories = const [];
      _loading = true;
      _error = null;
    });
    try {
      final rows = await ref
          .read(customerRepositoryProvider)
          .categoryChildren(category.s('id'), kind: widget.kind);
      if (!mounted) return;
      setState(() {
        _subcategories = rows;
        _step =
            rows.isEmpty ? _CatalogStep.results : _CatalogStep.subcategories;
        // When children exist there is no follow-up results request to clear
        // this flag. Without this assignment the subcategory page displays a
        // permanent progress indicator even though its data has arrived.
        _loading = rows.isEmpty;
      });
      if (rows.isEmpty) await _loadResults();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  Future<void> _selectSubcategory(Map<String, dynamic> subcategory) async {
    setState(() {
      _subcategory = subcategory;
      _step = _CatalogStep.results;
    });
    await _loadResults();
  }

  Future<void> _showAllResults({bool insideCategory = false}) async {
    setState(() {
      if (!insideCategory) {
        _category = null;
        _subcategory = null;
      }
      _step = _CatalogStep.results;
    });
    await _loadResults();
  }

  Future<void> _loadResults() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(customerRepositoryProvider);
      final rows = _isShop
          ? await repo.browseProducts(
              category: _subcategory == null ? _category?.s('id') : null,
              subcategory: _subcategory?.s('id'),
              search: _search.text.trim(),
              sort: _sort,
            )
          : await repo.services(
              category: _subcategory == null ? _category?.s('id') : null,
              subcategory: _subcategory?.s('id'),
              search: _search.text.trim(),
              sort: _sort,
            );
      if (!mounted) return;
      setState(() {
        _results = rows;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  void _backOneStep() {
    setState(() {
      _error = null;
      if (_step == _CatalogStep.results && _category != null) {
        _step = _subcategories.isEmpty
            ? _CatalogStep.categories
            : _CatalogStep.subcategories;
        _subcategory = null;
      } else {
        _step = _CatalogStep.categories;
        _category = null;
        _subcategory = null;
      }
      _loading = false;
    });
  }

  List<Map<String, dynamic>> get _visibleResults {
    return _results.where((row) {
      final original = row.n('original_price', row.n('originalPrice'));
      final hasOffer =
          row.n('discount') > 0 || (original > 0 && original > row.n('price'));
      final rating = row.n('rating', row.n('avgRating'));
      return (!_offersOnly || hasOffer) && rating >= _minimumRating;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return CustomerScaffold(
      title: _isShop ? 'Shop' : 'Services',
      bottomNavIndex: _isShop ? 1 : 2,
      child: RefreshIndicator(
        onRefresh: _step == _CatalogStep.categories
            ? _bootstrap
            : (_step == _CatalogStep.subcategories
                ? () => _selectCategory(_category!)
                : _loadResults),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            if (_step != _CatalogStep.categories)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _backOneStep,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: Text(
                      _step == _CatalogStep.results && _subcategories.isNotEmpty
                          ? 'Subcategories'
                          : 'Categories'),
                ),
              ),
            _Heading(
              title: _heading,
              subtitle: _subtitle,
              icon: _isShop
                  ? Icons.shopping_bag_rounded
                  : Icons.home_repair_service_rounded,
            ),
            const SizedBox(height: 16),
            if (_step == _CatalogStep.results) ...[
              TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _loadResults(),
                decoration: InputDecoration(
                  hintText: 'Search ${_plural.toLowerCase()}',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    tooltip: 'Search',
                    onPressed: _loadResults,
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _resultToolbar(),
              const SizedBox(height: 14),
            ],
            if (_loading)
              const SizedBox(
                height: 320,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              EmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'Could not load $_plural',
                message: _error.toString(),
                action: FilledButton(
                  onPressed: _step == _CatalogStep.categories
                      ? _bootstrap
                      : _loadResults,
                  child: const Text('Retry'),
                ),
              )
            else if (_step == _CatalogStep.categories)
              _categoryGrid(_categories, _selectCategory, includeAll: true)
            else if (_step == _CatalogStep.subcategories)
              _categoryGrid(_subcategories, _selectSubcategory,
                  includeAll: true)
            else
              _resultsView(),
          ],
        ),
      ),
    );
  }

  String get _heading {
    if (_step == _CatalogStep.categories) {
      return _isShop ? 'Shop by Category' : 'Service Categories';
    }
    if (_step == _CatalogStep.subcategories) {
      return _category?.s('name', 'Subcategories') ?? 'Subcategories';
    }
    return _subcategory?.s('name') ?? _category?.s('name') ?? 'All $_plural';
  }

  String get _subtitle {
    if (_step == _CatalogStep.categories) {
      return 'Choose a category to continue';
    }
    if (_step == _CatalogStep.subcategories) {
      return 'Choose a subcategory or browse all';
    }
    return '${_visibleResults.length} ${_plural.toLowerCase()} available';
  }

  Widget _categoryGrid(
    List<Map<String, dynamic>> rows,
    Future<void> Function(Map<String, dynamic>) onSelect, {
    required bool includeAll,
  }) {
    if (rows.isEmpty && _step == _CatalogStep.categories) {
      return EmptyState(
        icon: Icons.category_outlined,
        title: 'No categories available',
        message: 'Pull down to refresh.',
        action: FilledButton(onPressed: _bootstrap, child: const Text('Retry')),
      );
    }
    final count = rows.length + (includeAll ? 1 : 0);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: .82,
      ),
      itemBuilder: (context, index) {
        if (includeAll && index == 0) {
          return _CategoryCard(
            name: 'All $_plural',
            icon: Icons.apps_rounded,
            onTap: () => _showAllResults(
                insideCategory: _step == _CatalogStep.subcategories),
          );
        }
        final row = rows[index - (includeAll ? 1 : 0)];
        return _CategoryCard(
          name: row.s('name', 'Category'),
          image: row.s('image'),
          icon: _isShop
              ? Icons.inventory_2_outlined
              : Icons.miscellaneous_services_rounded,
          onTap: () => onSelect(row),
        );
      },
    );
  }

  Widget _resultToolbar() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _showFilters,
                icon: const Icon(Icons.tune_rounded, size: 19),
                label: const Text('Filter & sort'),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filledTonal(
              tooltip: _grid ? 'List view' : 'Grid view',
              onPressed: () => setState(() => _grid = !_grid),
              icon: Icon(
                  _grid ? Icons.view_list_rounded : Icons.grid_view_rounded),
            ),
          ],
        ),
        if (!_isShop) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: _gpsOn
                ? FilledButton.icon(
                    onPressed: _useGps,
                    icon: const Icon(Icons.navigation_rounded),
                    label: const Text('Using current location'),
                  )
                : OutlinedButton.icon(
                    onPressed: _useGps,
                    icon: const Icon(Icons.navigation_rounded),
                    label: const Text('Use GPS'),
                  ),
          ),
        ],
      ],
    );
  }

  Future<void> _useGps() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Turn on location services and try again.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception(
            'Location permission is required to show nearby services.');
      }
      final position = await Geolocator.getCurrentPosition();
      await ref.read(customerRepositoryProvider).saveSelectedLocation(
            'Current location',
            latitude: position.latitude,
            longitude: position.longitude,
          );
      if (!mounted) return;
      setState(() => _gpsOn = true);
      await _loadResults();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _showFilters() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, updateSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Filter and sort',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _sort,
                decoration: const InputDecoration(labelText: 'Sort by'),
                items: [
                  const DropdownMenuItem(
                      value: 'latest', child: Text('Newest')),
                  DropdownMenuItem(
                      value: _isShop ? 'price_low' : 'low',
                      child: const Text('Price: Low to High')),
                  DropdownMenuItem(
                      value: _isShop ? 'price_high' : 'high',
                      child: const Text('Price: High to Low')),
                  if (_isShop)
                    const DropdownMenuItem(
                        value: 'rating', child: Text('Popularity / rating')),
                ],
                onChanged: (value) {
                  if (value != null) updateSheet(() => _sort = value);
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Offers only'),
                value: _offersOnly,
                onChanged: (value) => updateSheet(() => _offersOnly = value),
              ),
              Text('Minimum rating: ${_minimumRating.toStringAsFixed(0)}+'),
              Slider(
                value: _minimumRating,
                min: 0,
                max: 4,
                divisions: 4,
                label: _minimumRating.toStringAsFixed(0),
                onChanged: (value) => updateSheet(() => _minimumRating = value),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    setState(() {});
                    _loadResults();
                  },
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultsView() {
    final rows = _visibleResults;
    if (rows.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No $_plural found',
        message: 'Try another search, category, or filter.',
        action: OutlinedButton(
          onPressed: () {
            setState(() {
              _search.clear();
              _offersOnly = false;
              _minimumRating = 0;
            });
            _loadResults();
          },
          child: const Text('Clear filters'),
        ),
      );
    }
    if (_isShop && _grid) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: rows.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: .54,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemBuilder: (_, index) => _productCard(rows[index]),
      );
    }
    return Column(
      children: rows
          .map((row) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _isShop ? _productCard(row) : _serviceCard(row),
              ))
          .toList(),
    );
  }

  Widget _productCard(Map<String, dynamic> product) {
    final id = product.s('id');
    final wished = _productWishlist.contains(id);
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () => context.push('/app/product/$id'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(children: [
            RemoteImage(
                url: product.s('image'),
                width: double.infinity,
                height: _grid ? 145 : 190),
            Positioned(
              right: 6,
              top: 6,
              child: IconButton.filledTonal(
                tooltip: wished ? 'Remove from wishlist' : 'Add to wishlist',
                onPressed: () => _toggleProductWishlist(id),
                icon: Icon(wished
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded),
              ),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.all(11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.s('title', 'Product'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(product.s('vendor_name', product.s('category_name')),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 12)),
                const SizedBox(height: 8),
                Text(money(product.n('price')),
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: OutlinedButton(
                          onPressed: () => _addToCart(product),
                          child: const Text('ADD'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: FilledButton(
                          onPressed: () => _buyNow(product),
                          child: const Text('BUY'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _serviceCard(Map<String, dynamic> service) {
    final id = service.s('id');
    final wished = _serviceWishlist.contains(id);
    return AppCard(
      onTap: () => context.push('/app/service/$id'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RemoteImage(url: service.s('image'), width: 100, height: 100),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(service.s('title', 'Service'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                  ),
                  IconButton(
                    tooltip:
                        wished ? 'Remove from wishlist' : 'Add to wishlist',
                    onPressed: () => _toggleServiceWishlist(id),
                    icon: Icon(wished
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded),
                    color: wished ? AppColors.danger : AppColors.muted,
                  ),
                ]),
                Text(service.s('category_name'),
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 12)),
                const SizedBox(height: 8),
                Text(money(service.n('price')),
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 17,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                const Text('View providers and book',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleProductWishlist(String id) async {
    await ref.read(customerRepositoryProvider).toggleWishlist(id);
    final values = await ref.read(customerRepositoryProvider).wishlist();
    if (mounted) setState(() => _productWishlist = values);
  }

  Future<void> _toggleServiceWishlist(String id) async {
    await ref.read(customerRepositoryProvider).toggleServiceWishlist(id);
    final values = await ref.read(customerRepositoryProvider).serviceWishlist();
    if (mounted) setState(() => _serviceWishlist = values);
  }

  Future<void> _addToCart(Map<String, dynamic> product) async {
    try {
      await ref.read(customerRepositoryProvider).addToCart(product);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.s('title', 'Product')} added to cart'),
          action: SnackBarAction(
            label: 'VIEW',
            onPressed: () => context.push('/app/cart'),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _buyNow(Map<String, dynamic> product) async {
    try {
      final repo = ref.read(customerRepositoryProvider);
      await repo.clearCart();
      await repo.addToCart(product);
      if (mounted) context.push('/app/cart');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}

class _Heading extends StatelessWidget {
  const _Heading({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900)),
              Text(subtitle, style: const TextStyle(color: AppColors.muted)),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.name,
    required this.icon,
    required this.onTap,
    this.image,
  });

  final String name;
  final String? image;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipOval(
            child: image == null || image!.isEmpty
                ? Container(
                    width: 68,
                    height: 68,
                    color: AppColors.accent,
                    child: Icon(icon, color: AppColors.primary, size: 30),
                  )
                : RemoteImage(
                    url: image, width: 68, height: 68, borderRadius: 34),
          ),
          const SizedBox(height: 9),
          Text(name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
