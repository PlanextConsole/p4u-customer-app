import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/config/feature_flags.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/map_ext.dart';
import '../../../../core/widgets/remote_image.dart';
import '../../../auth/data/auth_repository.dart';
import '../../data/customer_providers.dart';
import '../../data/customer_repository.dart';
import '../../domain/customer_models.dart';

class CustomerReferenceHomePage extends ConsumerStatefulWidget {
  const CustomerReferenceHomePage({super.key});
  @override
  ConsumerState<CustomerReferenceHomePage> createState() =>
      _CustomerReferenceHomePageState();
}

class _CustomerReferenceHomePageState
    extends ConsumerState<CustomerReferenceHomePage> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(customerAuthStateProvider).valueOrNull;
    final location =
        ref.watch(selectedLocationProvider).valueOrNull ?? 'Set your location';
    final wallet = ref.watch(landingWalletProvider);
    final home = ref.watch(homeProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _HomeHeader(
              location: location,
              wallet: wallet,
              userName: user?.name ?? 'Guest',
            ),
            Expanded(
              child: home.when(
                loading: () => const _HomeSkeleton(),
                error: (error, _) => _HomeError(
                  message: error.toString(),
                  onRetry: () => ref.invalidate(homeProvider),
                ),
                data: (data) => RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async {
                    ref.invalidate(homeProvider);
                    ref.invalidate(landingWalletProvider);
                    ref.invalidate(selectedLocationProvider);
                    await ref.read(homeProvider.future);
                  },
                  child: _HomeContent(data: data),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const _ReferenceBottomNav(),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.location,
    required this.wallet,
    required this.userName,
  });
  final String location;
  final AsyncValue<Map<String, dynamic>> wallet;
  final String userName;
  static const _tabs = <(String, String)>[
    ('Home', '/app/home'),
    ('Shop', '/app/browse'),
    ('Socio', '/app/social'),
    ('Services', '/app/services'),
    ('Find Home', '/app/find-home'),
    ('Classified', '/app/classifieds'),
    if (kFoodModuleEnabled) ('Food', '/app/food'),
  ];

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: AppColors.primary,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 43,
                  height: 43,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Image.asset(
                    'assets/images/p4u-logo.png',
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.home_rounded,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    key: const ValueKey('home-location'),
                    onTap: () => context.push('/app/set-location'),
                    borderRadius: BorderRadius.circular(10),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          color: Colors.white,
                          size: 23,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const Text(
                                'Tap to update location',
                                style: TextStyle(
                                  color: Color(0xFFBCE3E1),
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Color(0xFFBCE3E1),
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  key: const ValueKey('home-wallet'),
                  onTap: () => context.push('/app/wallet'),
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    height: 39,
                    constraints: const BoxConstraints(minWidth: 88),
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.account_balance_wallet_outlined,
                          color: Colors.white,
                          size: 19,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          wallet.maybeWhen(
                            data: (row) => row
                                .n(
                                  'displayAmount',
                                  row.n('balance', row.n('points')),
                                )
                                .round()
                                .toString(),
                            loading: () => '...',
                            orElse: () => '0',
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => context.push('/app/profile'),
                  customBorder: const CircleBorder(),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white,
                    child: Text(
                      userName.trim().isEmpty
                          ? 'U'
                          : userName.trim().characters.first.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 39,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _tabs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 7),
                itemBuilder: (context, index) {
                  final tab = _tabs[index];
                  final active = index == 0;
                  return InkWell(
                    key: ValueKey('home-tab-${tab.$1}'),
                    onTap: active ? null : () => context.push(tab.$2),
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: active
                            ? Colors.white
                            : Colors.white.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Text(
                        tab.$1,
                        style: TextStyle(
                          color: active
                              ? AppColors.primaryDark
                              : const Color(0xFFF2FFFE),
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          shadows: active
                              ? null
                              : const [
                                  Shadow(
                                    color: Color(0x66000000),
                                    blurRadius: 2,
                                    offset: Offset(0, 0.5),
                                  ),
                                ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            const _HomeSearchField(),
          ],
        ),
      );
}

class _HomeSearchField extends StatefulWidget {
  const _HomeSearchField();
  @override
  State<_HomeSearchField> createState() => _HomeSearchFieldState();
}

class _HomeSearchFieldState extends State<_HomeSearchField> {
  final _controller = TextEditingController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final query = _controller.text.trim();
    context.push(
      query.isEmpty
          ? '/app/browse'
          : '/app/browse?search=${Uri.encodeComponent(query)}',
    );
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 49,
        child: TextField(
          key: const ValueKey('home-search'),
          controller: _controller,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            hintText: 'Search for "Groceries"',
            hintStyle: const TextStyle(color: Color(0xFF637982), fontSize: 15),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: Color(0xFF536D78),
              size: 25,
            ),
            suffixIcon: IconButton(
              onPressed: _submit,
              icon: const Icon(Icons.arrow_forward_rounded),
            ),
            filled: true,
            fillColor: const Color(0xFF8DD0CD),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Colors.white70),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Colors.white70),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Colors.white, width: 1.5),
            ),
          ),
        ),
      );
}

class _HomeContent extends ConsumerWidget {
  const _HomeContent({required this.data});
  final CustomerHomeData data;
  bool _isRoot(Map<String, dynamic> row) =>
      row.s('parentId', row.s('parent_id')).isEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parents = data.categories.where(_isRoot).toList()
      ..sort(
        (a, b) => a
            .i('displayOrder', a.i('display_order', 999))
            .compareTo(b.i('displayOrder', b.i('display_order', 999))),
      );
    final trendingCategories = parents
        .where((row) => row['isTrending'] == true || row['is_trending'] == true)
        .toList();
    final children = <String, List<Map<String, dynamic>>>{};
    for (final row in data.categories.where((row) => !_isRoot(row))) {
      children
          .putIfAbsent(row.s('parentId', row.s('parent_id')), () => [])
          .add(row);
    }
    final recent = data.recentProducts.isEmpty
        ? data.products.take(4).toList()
        : data.recentProducts;
    return ListView(
      key: const PageStorageKey('customer-home-scroll'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (parents.isNotEmpty) _CategoryStrip(categories: parents),
        if (data.banners.isNotEmpty) _HeroCarousel(banners: data.banners),
        if (data.storeBanners.isNotEmpty)
          _StoreBannerGrid(items: data.storeBanners),
        const _RideActions(),
        if (data.products.isNotEmpty)
          _ProductSlider(title: 'Best of Products', products: data.products),
        if (parents.isNotEmpty)
          _CategoryGridSection(title: 'Shop by Category', categories: parents),
        if (trendingCategories.isNotEmpty)
          _CategoryGridSection(
            title: '🔥  Trending Categories',
            categories: trendingCategories,
            horizontal: true,
            hot: true,
          ),
        for (final parent in parents)
          if ((children[parent.s('id')] ?? const []).isNotEmpty)
            _SubcategoryStrip(
              parent: parent,
              categories: children[parent.s('id')]!,
            ),
        if (data.services.isNotEmpty)
          _ServiceSlider(title: 'Top Services', services: data.services),
        if (recent.isNotEmpty ||
            data.trendingProducts.isNotEmpty ||
            data.dealProducts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
            child: Column(
              children: [
                if (recent.isNotEmpty)
                  _ProductMosaic(
                    title: 'Pick up where you left off',
                    products: recent,
                    route: '/app/browse',
                  ),
                if (data.trendingProducts.isNotEmpty)
                  _ProductMosaic(
                    title: 'Trending Now',
                    products: data.trendingProducts,
                    route: '/app/browse?sort=rating',
                  ),
                if (data.dealProducts.isNotEmpty)
                  _ProductMosaic(
                    title: 'Deals of the Day',
                    products: data.dealProducts,
                    route: '/app/browse?sort=latest',
                  ),
              ],
            ),
          ),
        if (data.serviceCategories.isNotEmpty)
          _HomeServices(categories: data.serviceCategories),
        _NewsletterCard(repository: ref.read(customerRepositoryProvider)),
        const _TrustBar(),
        if (data.classified.isNotEmpty)
          _ClassifiedBanner(item: data.classified.first),
      ],
    );
  }
}

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({required this.categories});
  final List<Map<String, dynamic>> categories;
  @override
  Widget build(BuildContext context) {
    final rows = categories.take(8).toList();
    return SizedBox(
      height: 95,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
        scrollDirection: Axis.horizontal,
        itemCount: rows.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 11),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _CategoryIcon(
              label: 'All',
              icon: Icons.shopping_bag_outlined,
              selected: true,
              onTap: () => context.push('/app/browse'),
            );
          }
          final row = rows[index - 1];
          return _CategoryIcon(
            label: row.s('name'),
            image: row.s('image'),
            onTap: () => context.push('/app/browse?category=${row.s('id')}'),
          );
        },
      ),
    );
  }
}

class _CategoryIcon extends StatelessWidget {
  const _CategoryIcon({
    required this.label,
    required this.onTap,
    this.image,
    this.icon,
    this.selected = false,
  });
  final String label;
  final String? image;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: SizedBox(
          width: 61,
          child: Column(
            children: [
              Container(
                width: 58,
                height: 58,
                padding: selected ? const EdgeInsets.all(10) : EdgeInsets.zero,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: selected ? AppColors.primary : AppColors.border,
                    width: selected ? 2 : 1,
                  ),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 5),
                  ],
                ),
                child: icon != null
                    ? Icon(icon, color: AppColors.primary, size: 28)
                    : RemoteImage(url: image, borderRadius: 16),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  color: selected ? AppColors.primaryDark : AppColors.brandDark,
                ),
              ),
            ],
          ),
        ),
      );
}

class _HeroCarousel extends StatefulWidget {
  const _HeroCarousel({required this.banners});
  final List<Map<String, dynamic>> banners;
  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> {
  final _controller = PageController();
  int _index = 0;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 3, 14, 10),
        child: SizedBox(
          height: 154,
          child: Stack(
            children: [
              PageView.builder(
                controller: _controller,
                itemCount: widget.banners.length,
                onPageChanged: (value) => setState(() => _index = value),
                itemBuilder: (context, index) {
                  final row = widget.banners[index];
                  return InkWell(
                    onTap: () => _openContentLink(
                      context,
                      row.s('redirectUrl', row.s('redirect_url')),
                      fallback: '/app/browse',
                    ),
                    child: RemoteImage(
                      url:
                          row.s('image', row.s('imageUrl', row.s('image_url'))),
                      width: double.infinity,
                      height: 154,
                      borderRadius: 14,
                    ),
                  );
                },
              ),
              if (widget.banners.length > 1)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 8,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(widget.banners.length, (index) {
                      final active = index == _index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: active ? 28 : 8,
                        height: 7,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: active ? Colors.white : Colors.white60,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      );
                    }),
                  ),
                ),
            ],
          ),
        ),
      );
}

class _StoreBannerGrid extends StatelessWidget {
  const _StoreBannerGrid({required this.items});
  final List<Map<String, dynamic>> items;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.take(6).length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1.14,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemBuilder: (context, index) {
            final row = items[index];
            return InkWell(
              onTap: () => _openContentLink(
                context,
                row.s('redirectUrl', row.s('redirect_url')),
                fallback: '/app/browse',
              ),
              borderRadius: BorderRadius.circular(13),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: RemoteImage(
                        url: row.s(
                            'image', row.s('imageUrl', row.s('image_url'))),
                        width: double.infinity,
                        borderRadius: 12,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 4,
                      ),
                      child: Text(
                        row.s('title', row.s('name')),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
}

class _RideActions extends StatelessWidget {
  const _RideActions();
  static const _items = <(String, String, String)>[
    ('🛺', 'Auto Ride', 'auto ride'),
    ('🏍️', 'Bike Ride', 'bike ride'),
    ('🚗', 'Car Ride', 'car ride'),
  ];
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 2, 14, 14),
        child: Row(
          children: [
            for (var i = 0; i < _items.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => context.push(
                    '/app/services?search=${Uri.encodeComponent(_items[i].$3)}',
                  ),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: i == 0
                            ? const [Color(0xFFDDF5EE), Color(0xFFEAF9F6)]
                            : i == 1
                                ? const [Color(0xFFD5F0EE), Color(0xFFE8F8F6)]
                                : const [Color(0xFFCFE9E7), Color(0xFFE6F5F3)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 5,
                          right: 5,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'SOON',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 7,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _items[i].$1,
                                style: const TextStyle(fontSize: 24),
                              ),
                              Text(
                                _items[i].$2,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.onViewAll});
  final String title;
  final VoidCallback? onViewAll;
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
          ),
          if (onViewAll != null)
            TextButton.icon(
              onPressed: onViewAll,
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.chevron_right_rounded, size: 18),
              label: const Text('View All'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      );
}

class _ProductSlider extends StatefulWidget {
  const _ProductSlider({required this.title, required this.products});
  final String title;
  final List<Map<String, dynamic>> products;
  @override
  State<_ProductSlider> createState() => _ProductSliderState();
}

class _ProductSliderState extends State<_ProductSlider> {
  final _controller = ScrollController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _move(double delta) => _controller.animateTo(
        (_controller.offset + delta)
            .clamp(0, _controller.position.maxScrollExtent),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        padding: const EdgeInsets.fromLTRB(16, 11, 0, 15),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _SliderButton(
                    icon: Icons.chevron_left, onTap: () => _move(-180)),
                const SizedBox(width: 6),
                _SliderButton(
                    icon: Icons.chevron_right, onTap: () => _move(180)),
                const SizedBox(width: 13),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 188,
              child: ListView.separated(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                itemCount: widget.products.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) =>
                    _HomeProductCard(product: widget.products[index]),
              ),
            ),
          ],
        ),
      );
}

class _SliderButton extends StatelessWidget {
  const _SliderButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: CircleAvatar(
          radius: 18,
          backgroundColor: Colors.white.withValues(alpha: .2),
          child: Icon(icon, color: Colors.white),
        ),
      );
}

class _HomeProductCard extends StatelessWidget {
  const _HomeProductCard({required this.product});
  final Map<String, dynamic> product;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => context.push('/app/product/${product.s('id')}'),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 145,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RemoteImage(
                url: product.s('image'),
                width: 145,
                height: 116,
                borderRadius: 0,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 8, 0),
                child: Text(
                  product.s('title', 'Product'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 5, 8, 0),
                child: Text(
                  money(product.n('price')),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _CategoryGridSection extends StatelessWidget {
  const _CategoryGridSection({
    required this.title,
    required this.categories,
    this.horizontal = false,
    this.hot = false,
  });
  final String title;
  final List<Map<String, dynamic>> categories;
  final bool horizontal;
  final bool hot;
  @override
  Widget build(BuildContext context) {
    final rows = categories.take(12).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        children: [
          _SectionTitle(
            title: title,
            onViewAll: () => context.push('/app/browse'),
          ),
          if (horizontal)
            SizedBox(
              height: 112,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) =>
                    _LargeCategory(category: rows[index], hot: hot),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rows.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: .75,
                mainAxisSpacing: 10,
                crossAxisSpacing: 8,
              ),
              itemBuilder: (context, index) =>
                  _LargeCategory(category: rows[index]),
            ),
        ],
      ),
    );
  }
}

class _LargeCategory extends StatelessWidget {
  const _LargeCategory({required this.category, this.hot = false});
  final Map<String, dynamic> category;
  final bool hot;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => context.push('/app/browse?category=${category.s('id')}'),
        borderRadius: BorderRadius.circular(15),
        child: SizedBox(
          width: 78,
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child:
                        RemoteImage(url: category.s('image'), borderRadius: 15),
                  ),
                  if (hot)
                    Positioned(
                      top: 4,
                      right: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Text(
                          'HOT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                category.s('name'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 10.5, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      );
}

class _SubcategoryStrip extends StatelessWidget {
  const _SubcategoryStrip({required this.parent, required this.categories});
  final Map<String, dynamic> parent;
  final List<Map<String, dynamic>> categories;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: Column(
          children: [
            _SectionTitle(
              title: 'Shop ${parent.s('name')}',
              onViewAll: () =>
                  context.push('/app/browse?category=${parent.s('id')}'),
            ),
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: categories.take(10).length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final row = categories[index];
                  return _CategoryIcon(
                    label: row.s('name'),
                    image: row.s('image'),
                    onTap: () => context.push(
                      '/app/browse?category=${parent.s('id')}&subcategory=${row.s('id')}',
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
}

class _ServiceSlider extends StatefulWidget {
  const _ServiceSlider({required this.title, required this.services});
  final String title;
  final List<Map<String, dynamic>> services;
  @override
  State<_ServiceSlider> createState() => _ServiceSliderState();
}

class _ServiceSliderState extends State<_ServiceSlider> {
  final _controller = ScrollController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _move(double delta) => _controller.animateTo(
        (_controller.offset + delta)
            .clamp(0, _controller.position.maxScrollExtent),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        padding: const EdgeInsets.fromLTRB(16, 10, 0, 15),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _SliderButton(
                    icon: Icons.chevron_left, onTap: () => _move(-210)),
                const SizedBox(width: 6),
                _SliderButton(
                    icon: Icons.chevron_right, onTap: () => _move(210)),
                const SizedBox(width: 13),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 228,
              child: ListView.separated(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                itemCount: widget.services.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final service = widget.services[index];
                  return InkWell(
                    onTap: () =>
                        context.push('/app/service/${service.s('id')}'),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 174,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RemoteImage(
                            url: service.s('image'),
                            width: 174,
                            height: 132,
                            borderRadius: 0,
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
                            child: Text(
                              service.s('title'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              service.s(
                                  'vendor_name', service.s('category_name')),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 4, 10, 9),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    money(service.n('price')),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                if (service.s('duration').isNotEmpty)
                                  Text(
                                    service.s('duration'),
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 9,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
}

class _ProductMosaic extends StatelessWidget {
  const _ProductMosaic({
    required this.title,
    required this.products,
    required this.route,
  });
  final String title;
  final List<Map<String, dynamic>> products;
  final String route;
  @override
  Widget build(BuildContext context) {
    final rows = products.take(4).toList();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.border),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rows.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.7,
              crossAxisSpacing: 8,
              mainAxisSpacing: 9,
            ),
            itemBuilder: (context, index) {
              final product = rows[index];
              return InkWell(
                onTap: () => context.push('/app/product/${product.s('id')}'),
                borderRadius: BorderRadius.circular(11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: RemoteImage(
                        url: product.s('image'),
                        width: double.infinity,
                        borderRadius: 11,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      product.s('title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          TextButton(
            onPressed: () => context.push(route),
            child: const Text('Explore More →'),
          ),
        ],
      ),
    );
  }
}

class _HomeServices extends StatelessWidget {
  const _HomeServices({required this.categories});
  final List<Map<String, dynamic>> categories;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Home Services',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => context.push('/app/services'),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF12AAA1), Color(0xFF063A68)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Book a Service',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Professional services at your doorstep',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 15),
                    FilledButton(
                      onPressed: () => context.push('/app/services'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.brandDark,
                        minimumSize: const Size(150, 45),
                        shape: const StadiumBorder(),
                      ),
                      child: const Text('View All Services'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 11),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: categories.take(8).length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.45,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                final row = categories[index];
                return InkWell(
                  onTap: () =>
                      context.push('/app/services?category=${row.s('id')}'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        RemoteImage(
                          url: row.s('image'),
                          width: 44,
                          height: 44,
                          borderRadius: 22,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row.s('name'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const Text(
                                'View providers',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 8.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );
}

class _NewsletterCard extends StatefulWidget {
  const _NewsletterCard({required this.repository});
  final CustomerRepository repository;
  @override
  State<_NewsletterCard> createState() => _NewsletterCardState();
}

class _NewsletterCardState extends State<_NewsletterCard> {
  final _email = TextEditingController();
  bool _loading = false;
  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final value = _email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
      _message('Enter a valid email address');
      return;
    }
    setState(() => _loading = true);
    try {
      await widget.repository.subscribeNewsletter(value);
      if (mounted) {
        _email.clear();
        _message('Subscribed successfully');
      }
    } catch (error) {
      if (mounted) _message(error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String value) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(value)));
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 16),
        padding: const EdgeInsets.fromLTRB(24, 25, 24, 24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3DBA8B), Color(0xFF5AC5A8)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'Get '),
                  TextSpan(
                    text: '20% Discount',
                    style: TextStyle(color: Color(0xFFB8FFF8)),
                  ),
                  TextSpan(text: ' On Your\nFirst Purchase'),
                ],
              ),
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                height: 1.15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 15),
            const Text(
              'Sign up for offers and product updates',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'Email Address',
                filled: true,
                fillColor: Colors.white.withValues(alpha: .17),
                hintStyle: const TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Colors.white38),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loading ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF062B47),
                minimumSize: const Size(155, 46),
                shape: const StadiumBorder(),
              ),
              child: Text(_loading ? 'SUBSCRIBING...' : 'SUBSCRIBE NOW'),
            ),
          ],
        ),
      );
}

class _TrustBar extends StatelessWidget {
  const _TrustBar();
  static const _items = <(IconData, String, String)>[
    (Icons.shield_outlined, '100% Genuine', 'Verified vendors'),
    (Icons.schedule_rounded, 'Fast Delivery', 'Live order tracking'),
    (Icons.auto_awesome_outlined, 'Earn Rewards', 'On eligible orders'),
  ];
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
        child: Row(
          children: [
            for (var i = 0; i < _items.length; i++) ...[
              if (i > 0) const SizedBox(width: 7),
              Expanded(
                child: Container(
                  height: 94,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 4),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_items[i].$1, color: AppColors.primary, size: 23),
                      const SizedBox(height: 7),
                      Text(
                        _items[i].$2,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        _items[i].$3,
                        maxLines: 1,
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 8),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      );
}

class _ClassifiedBanner extends StatelessWidget {
  const _ClassifiedBanner({required this.item});
  final Map<String, dynamic> item;
  @override
  Widget build(BuildContext context) => Container(
        height: 240,
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 22),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            RemoteImage(
              url: item.s('image'),
              width: double.infinity,
              height: 240,
              borderRadius: 16,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Buy & Sell Locally',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text(
                    'Discover live classified listings near you',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton(
                        onPressed: () => context.push('/app/classifieds'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.brandDark,
                          minimumSize: const Size(105, 42),
                          shape: const StadiumBorder(),
                        ),
                        child: const Text('Browse Ads'),
                      ),
                      FilledButton(
                        onPressed: () => context.push('/app/classifieds/post'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.brandDark,
                          minimumSize: const Size(105, 42),
                          shape: const StadiumBorder(),
                        ),
                        child: const Text('Post Ad Free'),
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

class _ReferenceBottomNav extends StatelessWidget {
  const _ReferenceBottomNav();
  static const _items = <(String, IconData, String)>[
    ('Home', Icons.home_outlined, '/app/home'),
    ('Shop', Icons.shopping_bag_outlined, '/app/browse'),
    ('Socio', Icons.campaign_outlined, '/app/social'),
    ('Services', Icons.handyman_outlined, '/app/services'),
    ('Homes', Icons.apartment_outlined, '/app/find-home'),
    ('Ads', Icons.newspaper_outlined, '/app/classifieds'),
    if (kFoodModuleEnabled) ('Food', Icons.restaurant_outlined, '/app/food'),
  ];
  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Container(
          height: 72,
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: i == 0 ? null : () => context.push(_items[i].$3),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _items[i].$2,
                              size: 22,
                              color: i == 0
                                  ? AppColors.primary
                                  : AppColors.brandDark.withValues(alpha: 0.72),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _items[i].$1,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight:
                                    i == 0 ? FontWeight.w900 : FontWeight.w700,
                                color: i == 0
                                    ? AppColors.primaryDark
                                    : AppColors.brandDark.withValues(alpha: 0.78),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();
  @override
  Widget build(BuildContext context) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(14),
        children: List.generate(
          5,
          (index) => Container(
            height: index == 1 ? 160 : 100,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: AppColors.border),
            ),
          ),
        ),
      );
}

class _HomeError extends StatelessWidget {
  const _HomeError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 54, color: AppColors.primary),
          const SizedBox(height: 12),
          const Text(
            'Home is temporarily unavailable',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 18),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      );
}

Future<void> _openContentLink(
  BuildContext context,
  String raw, {
  required String fallback,
}) async {
  final value = raw.trim();
  if (value.isEmpty) {
    context.push(fallback);
    return;
  }
  if (value.startsWith('/app')) {
    context.push(value);
    return;
  }
  if (value.startsWith('/shop') || value.startsWith('/home')) {
    context.push('/app/browse');
    return;
  }
  final uri = Uri.tryParse(value);
  if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    return;
  }
  if (context.mounted) context.push(fallback);
}
