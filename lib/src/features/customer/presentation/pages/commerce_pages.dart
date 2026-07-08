import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/map_ext.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/customer_scaffold.dart';
import '../../../../core/widgets/remote_image.dart';
import '../../../auth/data/auth_repository.dart';
import '../../data/customer_providers.dart';
import '../../domain/customer_models.dart';
import '../widgets/customer_tiles.dart';

class CustomerHomePage extends ConsumerWidget {
  const CustomerHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeProvider);
    final location = ref.watch(selectedLocationProvider).valueOrNull ?? 'Set your location';
    return CustomerScaffold(
      title: 'Planext4u',
      bottomNavIndex: 0,
      child: home.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(icon: Icons.cloud_off_rounded, title: 'Home unavailable', message: e.toString()),
        data: (data) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(homeProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _HomeSearch(location: location),
              const SizedBox(height: 14),
              _HeroBanners(data: data),
              const SectionHeader(title: 'Explore Planext4u', subtitle: 'Everything from shopping to homes in one app'),
              GridView.count(
                crossAxisCount: 3,
                childAspectRatio: .95,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: const [
                  _HomeAction('Shop', Icons.shopping_bag_rounded, '/app/browse', AppColors.primary),
                  _HomeAction('Services', Icons.home_repair_service_rounded, '/app/services', AppColors.warning),
                  _HomeAction('Socio', Icons.groups_rounded, '/app/social', AppColors.info),
                  _HomeAction('Find Home', Icons.apartment_rounded, '/app/find-home', AppColors.success),
                  _HomeAction('Classifieds', Icons.campaign_rounded, '/app/classifieds', AppColors.primaryDark),
                  _HomeAction('Wallet', Icons.account_balance_wallet_rounded, '/app/wallet', AppColors.brandDark),
                ],
              ),
              const SectionHeader(title: 'Shop by Category'),
              SizedBox(
                height: 126,
                child: data.categories.isEmpty
                    ? const EmptyState(icon: Icons.category_rounded, title: 'No categories', message: 'Categories will appear when the API returns them.')
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: data.categories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) => _CategoryPill(category: data.categories[index]),
                      ),
              ),
              const SectionHeader(title: 'Featured Products'),
              if (data.products.isEmpty)
                const EmptyState(icon: Icons.inventory_2_rounded, title: 'No products yet', message: 'Products will appear here when vendors publish them.')
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: data.products.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: .68, crossAxisSpacing: 12, mainAxisSpacing: 12),
                  itemBuilder: (context, index) => ProductTile(product: data.products[index]),
                ),
              const SectionHeader(title: 'Popular Services'),
              ...data.services.map((service) => Padding(padding: const EdgeInsets.only(bottom: 10), child: ServiceTile(service: service))),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeSearch extends StatelessWidget {
  const _HomeSearch({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController();
    return Column(
      children: [
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          onTap: () => context.go('/app/set-location'),
          child: Row(
            children: [
              const Icon(Icons.location_on_rounded, color: AppColors.warning),
              const SizedBox(width: 8),
              Expanded(child: Text(location, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
              const Icon(Icons.keyboard_arrow_down_rounded),
            ],
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          onSubmitted: (value) => context.go('/app/browse?search=${Uri.encodeComponent(value)}'),
          decoration: InputDecoration(
            hintText: 'Search products, services, homes',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: IconButton(onPressed: () => context.go('/app/browse?search=${Uri.encodeComponent(controller.text)}'), icon: const Icon(Icons.arrow_forward_rounded)),
          ),
        ),
      ],
    );
  }
}

class _HeroBanners extends StatelessWidget {
  const _HeroBanners({required this.data});

  final CustomerHomeData data;

  @override
  Widget build(BuildContext context) {
    final banners = data.banners;
    if (banners.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 154,
      child: PageView.builder(
        controller: PageController(viewportFraction: .92),
        itemCount: banners.length,
        itemBuilder: (context, index) {
          final banner = banners[index];
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Stack(
              fit: StackFit.expand,
              children: [
                RemoteImage(url: banner.s('image', banner.s('image_url')), borderRadius: 18),
                Container(
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), gradient: LinearGradient(colors: [Colors.black.withValues(alpha: .45), Colors.transparent])),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Text(banner.s('title', 'Planext4u'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HomeAction extends StatelessWidget {
  const _HomeAction(this.label, this.icon, this.route, this.color);
  final String label;
  final IconData icon;
  final String route;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.go(route),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          FittedBox(child: Text(label, maxLines: 1, style: const TextStyle(fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.category});
  final Map<String, dynamic> category;

  @override
  Widget build(BuildContext context) {
    final name = category.s('name', 'Category');
    return InkWell(
      onTap: () => context.go('/app/browse?category=${Uri.encodeComponent(name)}'),
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 92,
        child: Column(
          children: [
            RemoteImage(url: category.s('image'), width: 68, height: 68),
            const SizedBox(height: 6),
            SizedBox(
              height: 42,
              child: Center(
                child: Text(
                  name,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, height: 1.08),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomerBrowsePage extends ConsumerStatefulWidget {
  const CustomerBrowsePage({super.key});

  @override
  ConsumerState<CustomerBrowsePage> createState() => _CustomerBrowsePageState();
}

class _CustomerBrowsePageState extends ConsumerState<CustomerBrowsePage> {
  late final TextEditingController _search;
  String _sort = 'latest';
  String? _category;
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController();
    _future = Future.value([]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uri = GoRouterState.of(context).uri;
    _search.text = uri.queryParameters['search'] ?? _search.text;
    _category = uri.queryParameters['category'] ?? _category;
    _load();
  }

  void _load() {
    _future = ref.read(customerRepositoryProvider).browseProducts(search: _search.text.trim(), category: _category, sort: _sort);
  }

  @override
  Widget build(BuildContext context) {
    return CustomerScaffold(
      title: 'Shop',
      bottomNavIndex: 1,
      child: RefreshIndicator(
        onRefresh: () async => setState(_load),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => setState(_load),
              decoration: InputDecoration(
                hintText: 'Search products',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(icon: const Icon(Icons.tune_rounded), onPressed: () => _showFilters(context)),
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox(height: 320, child: Center(child: CircularProgressIndicator()));
                final products = snapshot.data ?? [];
                if (products.isEmpty) {
                  return const EmptyState(icon: Icons.search_off_rounded, title: 'No products found', message: 'Try a different search, category, or sort.');
                }
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: products.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: .68, crossAxisSpacing: 12, mainAxisSpacing: 12),
                  itemBuilder: (context, index) => ProductTile(product: products[index]),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFilters(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sort products', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            _SortOption(label: 'Latest', value: 'latest', selected: _sort, onTap: _applySort),
            _SortOption(label: 'Price: Low to High', value: 'price_low', selected: _sort, onTap: _applySort),
            _SortOption(label: 'Price: High to Low', value: 'price_high', selected: _sort, onTap: _applySort),
            _SortOption(label: 'Rating', value: 'rating', selected: _sort, onTap: _applySort),
          ],
        ),
      ),
    );
  }

  void _applySort(String sort) {
    setState(() {
      _sort = sort;
      _load();
    });
    context.pop();
  }
}

class CustomerProductPage extends ConsumerWidget {
  const CustomerProductPage({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomerScaffold(
      title: 'Product',
      showBack: true,
      child: FutureBuilder<Map<String, dynamic>?>(
        future: ref.read(customerRepositoryProvider).product(id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final product = snapshot.data;
          if (product == null) return const EmptyState(icon: Icons.inventory_2_rounded, title: 'Product not found', message: 'This product may no longer be available.');
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              RemoteImage(url: product.s('image'), height: 280, width: double.infinity, borderRadius: 18),
              const SizedBox(height: 16),
              Text(product.s('title'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(product.s('vendor_name'), style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(money(product.n('price')), style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: 24)),
                  if (product.n('discount') > 0) ...[
                    const SizedBox(width: 8),
                    StatusBadge('${money(product.n('discount'))} off'),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Text(product.s('description', product.s('long_description', 'No description available.'))),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        try {
                          await ref.read(customerRepositoryProvider).addToCart(product);
                          ref.invalidate(cartSummaryProvider);
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to cart')));
                        } catch (e) {
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                        }
                      },
                      icon: const Icon(Icons.add_shopping_cart_rounded),
                      label: const Text('Add to Cart'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    onPressed: () async {
                      await ref.read(customerRepositoryProvider).toggleWishlist(id);
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wishlist updated')));
                    },
                    icon: const Icon(Icons.favorite_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: product.s('vendor_id').isEmpty ? null : () => context.go('/app/vendor/${product.s('vendor_id')}'),
                icon: const Icon(Icons.storefront_rounded),
                label: const Text('View Seller'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class CustomerCartPage extends ConsumerWidget {
  const CustomerCartPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(customerAuthStateProvider).valueOrNull;
    final summary = ref.watch(cartSummaryProvider);
    return CustomerScaffold(
      title: 'Cart',
      showBack: true,
      child: summary.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(icon: Icons.shopping_cart_rounded, title: 'Cart unavailable', message: e.toString()),
        data: (cart) {
          if (cart.items.isEmpty) {
            return EmptyState(
              icon: Icons.shopping_cart_rounded,
              title: 'Your cart is empty',
              message: 'Add products from the shop to checkout.',
              action: FilledButton(onPressed: () => context.go('/app/browse'), child: const Text('Shop Now')),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final item in cart.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    child: Row(
                      children: [
                        RemoteImage(url: item.image, width: 70, height: 70),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                              Text(money(item.price), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                        _QtyStepper(
                          qty: item.qty,
                          onChanged: (qty) async {
                            await ref.read(customerRepositoryProvider).updateCartItem(item.id, qty);
                            ref.invalidate(cartSummaryProvider);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              AppCard(
                child: Column(
                  children: [
                    _TotalRow('Subtotal', cart.subtotal),
                    _TotalRow('Tax', cart.tax),
                    _TotalRow('Platform fee', cart.platformFee),
                    _TotalRow('Discount', -cart.discount),
                    const Divider(),
                    _TotalRow('Total', cart.total, bold: true),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: auth == null ? () => context.go('/app/login') : () => context.go('/app/payment'),
                icon: const Icon(Icons.payment_rounded),
                label: Text(auth == null ? 'Login to Checkout' : 'Proceed to Payment'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class PaymentPage extends ConsumerWidget {
  const PaymentPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(customerAuthStateProvider).valueOrNull;
    if (auth == null) return const _LoginRequired();
    return CustomerScaffold(
      title: 'Payment',
      showBack: true,
      child: FutureBuilder<(CartSummary, List<Map<String, dynamic>>)>(
        future: _paymentData(ref, auth.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final data = snapshot.data;
          if (data == null || data.$1.items.isEmpty) {
            return const EmptyState(icon: Icons.shopping_cart_rounded, title: 'Cart is empty', message: 'Add products before payment.');
          }
          final summary = data.$1;
          final address = data.$2.isEmpty ? null : data.$2.first;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionHeader(title: 'Delivery Address'),
              AppCard(
                child: address == null
                    ? const Text('No saved address. Add one from profile edit or set location.')
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(address.s('name', auth.name), style: const TextStyle(fontWeight: FontWeight.w900)),
                        Text(address.s('address_line', address.s('address'))),
                        Text('${address.s('city')} ${address.s('pincode')}'),
                      ]),
              ),
              const SectionHeader(title: 'Order Summary'),
              AppCard(
                child: Column(
                  children: [
                    _TotalRow('Items', summary.count),
                    _TotalRow('Subtotal', summary.subtotal),
                    _TotalRow('Tax', summary.tax),
                    _TotalRow('Platform fee', summary.platformFee),
                    const Divider(),
                    _TotalRow('Payable', summary.total, bold: true),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () async {
                  await ref.read(customerRepositoryProvider).placeOrder(customerId: auth.id, summary: summary, address: address);
                  ref.invalidate(cartSummaryProvider);
                  if (context.mounted) context.go('/app/orders');
                },
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text('Place Order'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<(CartSummary, List<Map<String, dynamic>>)> _paymentData(WidgetRef ref, String customerId) async {
    final repo = ref.read(customerRepositoryProvider);
    return (await repo.cartSummary(), await repo.customerAddresses(customerId));
  }
}

class CustomerOrdersPage extends ConsumerWidget {
  const CustomerOrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(customerAuthStateProvider).valueOrNull;
    if (auth == null) return const _LoginRequired();
    return CustomerScaffold(
      title: 'Orders',
      showBack: true,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: ref.read(customerRepositoryProvider).orders(auth.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final orders = snapshot.data ?? [];
          if (orders.isEmpty) return const EmptyState(icon: Icons.receipt_long_rounded, title: 'No orders', message: 'Your orders will appear here.');
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final order = orders[index];
              return AppCard(
                onTap: () => context.go('/app/orders/${order.s('id')}'),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long_rounded, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(order.s('id'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text(shortDate(order['created_at']), style: const TextStyle(color: AppColors.muted)),
                        ],
                      ),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(money(order.n('total')), style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      StatusBadge(order.s('status', 'placed')),
                    ]),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class CustomerOrderDetailPage extends ConsumerWidget {
  const CustomerOrderDetailPage({required this.orderId, super.key});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomerScaffold(
      title: 'Order Details',
      showBack: true,
      child: FutureBuilder<Map<String, dynamic>?>(
        future: ref.read(customerRepositoryProvider).order(orderId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final order = snapshot.data;
          if (order == null) return const EmptyState(icon: Icons.receipt_long_rounded, title: 'Order not found', message: 'Please check the order again.');
          final items = order['items'] is List ? (order['items'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [Expanded(child: Text(order.s('id'), style: const TextStyle(fontWeight: FontWeight.w900))), StatusBadge(order.s('status', 'placed'))]),
                    const SizedBox(height: 8),
                    Text('Placed on ${shortDate(order['created_at'])}'),
                    const SizedBox(height: 8),
                    Text(money(order.n('total')), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 22)),
                  ],
                ),
              ),
              const SectionHeader(title: 'Items'),
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    child: Row(
                      children: [
                        Expanded(child: Text(item.s('title'), style: const TextStyle(fontWeight: FontWeight.w800))),
                        Text('${item.i('qty', 1)} x ${money(item.n('price'))}'),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class CustomerVendorPage extends ConsumerWidget {
  const CustomerVendorPage({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomerScaffold(
      title: 'Seller',
      showBack: true,
      child: FutureBuilder<(Map<String, dynamic>?, List<Map<String, dynamic>>)>(
        future: _vendorData(ref),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final vendor = snapshot.data?.$1;
          final products = snapshot.data?.$2 ?? [];
          if (vendor == null) return const EmptyState(icon: Icons.storefront_rounded, title: 'Seller not found', message: 'This seller is unavailable.');
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Row(
                  children: [
                    RemoteImage(url: vendor.s('logo'), width: 72, height: 72),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(vendor.s('business_name', vendor.s('name')), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                        Text(vendor.s('city'), style: const TextStyle(color: AppColors.muted)),
                        const SizedBox(height: 6),
                        StatusBadge(vendor.s('status', 'active')),
                      ]),
                    ),
                  ],
                ),
              ),
              const SectionHeader(title: 'Seller Products'),
              if (products.isEmpty)
                const EmptyState(icon: Icons.inventory_2_rounded, title: 'No products', message: 'This seller has no active products.')
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: products.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: .68, crossAxisSpacing: 12, mainAxisSpacing: 12),
                  itemBuilder: (context, index) => ProductTile(product: products[index]),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<(Map<String, dynamic>?, List<Map<String, dynamic>>)> _vendorData(WidgetRef ref) async {
    final repo = ref.read(customerRepositoryProvider);
    return (await repo.vendor(id), await repo.vendorProducts(id));
  }
}

class CustomerCMSPage extends StatelessWidget {
  const CustomerCMSPage({required this.slug, super.key});
  final String slug;

  @override
  Widget build(BuildContext context) {
    return CustomerScaffold(
      title: slug.replaceAll('-', ' '),
      showBack: true,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(child: Text('CMS content API for "$slug" is not defined in the customer Postman collection.')),
        ],
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({required this.qty, required this.onChanged});
  final int qty;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(onPressed: () => onChanged(qty - 1), icon: const Icon(Icons.remove_rounded)),
        SizedBox(width: 28, child: Text('$qty', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900))),
        IconButton.filledTonal(onPressed: () => onChanged(qty + 1), icon: const Icon(Icons.add_rounded)),
      ],
    );
  }
}

class _SortOption extends StatelessWidget {
  const _SortOption({required this.label, required this.value, required this.selected, required this.onTap});

  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final active = value == selected;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: TextStyle(fontWeight: active ? FontWeight.w900 : FontWeight.w500)),
      trailing: active ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
      onTap: () => onTap(value),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow(this.label, this.value, {this.bold = false});
  final String label;
  final Object value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w600, fontSize: bold ? 17 : 14);
    final formatted = value is num ? money(value as num) : value.toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [Expanded(child: Text(label, style: style)), Text(formatted, style: style)]),
    );
  }
}

class _LoginRequired extends StatelessWidget {
  const _LoginRequired();

  @override
  Widget build(BuildContext context) {
    return CustomerScaffold(
      title: 'Login Required',
      child: EmptyState(
        icon: Icons.lock_rounded,
        title: 'Please login',
        message: 'This section is available for registered customers.',
        action: FilledButton(onPressed: () => context.go('/app/login'), child: const Text('Login')),
      ),
    );
  }
}
