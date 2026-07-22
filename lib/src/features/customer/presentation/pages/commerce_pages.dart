import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

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

class CustomerLandingPage extends ConsumerWidget {
  const CustomerLandingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(customerAuthStateProvider);
    final auth = authState.valueOrNull;
    if (authState.isLoading) return const _LandingSessionLoader();
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/welcome-bg.png',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xDB089B96),
                  Color(0xA1089B96),
                  Color(0x38089B96),
                  Color(0xB8ECFAF7),
                  Color(0xEBECFAF7),
                ],
                stops: [0, .25, .43, .58, 1],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0x29006F6B),
                  Colors.transparent,
                  Color(0x1F006F6B),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _LandingLogo(),
                        _LandingAccountButton(
                          authName: auth?.name,
                          customerId: auth?.id,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Welcome!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        shadows: [Shadow(color: Colors.black26, blurRadius: 5)],
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Everything you need, in one place.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        shadows: [Shadow(color: Colors.black26, blurRadius: 6)],
                      ),
                    ),
                    const SizedBox(height: 21),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: 1,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          children: const [
                            _LandingCard(
                              title: 'Shop',
                              body: 'Find everything you need',
                              icon: Icons.shopping_bag_outlined,
                              route: '/app/browse',
                            ),
                            _LandingCard(
                              title: 'Socio',
                              body: 'Connect with your community',
                              icon: Icons.people_outline_rounded,
                              route: '/app/social',
                            ),
                            _LandingCard(
                              title: 'Services',
                              body: 'Book trusted services',
                              icon: Icons.business_center_outlined,
                              route: '/app/services',
                            ),
                            _LandingCard(
                              title: 'Classifieds',
                              body: 'Buy, sell & discover near you',
                              icon: Icons.sell_outlined,
                              route: '/app/classifieds',
                            ),
                          ],
                        ),
                        const _LandingHomeButton(),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _LandingWallet(authenticated: auth != null),
                    const SizedBox(height: 8),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _LandingQuickLink(
                          label: 'Emergency',
                          icon: Icons.emergency_outlined,
                          route: '/app/emergency',
                        ),
                        _LandingQuickLink(
                          label: 'Help',
                          icon: Icons.support_outlined,
                          route: '/app/support',
                        ),
                        _LandingQuickLink(
                          label: 'Quick Assist',
                          icon: Icons.electric_bolt_outlined,
                          route: '/app/quick-assist',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingSessionLoader extends StatelessWidget {
  const _LandingSessionLoader();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/images/welcome-bg.png',
                fit: BoxFit.cover, alignment: Alignment.topCenter),
            Container(color: const Color(0xDB089B96)),
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          ],
        ),
      );
}

class _LandingLogo extends StatelessWidget {
  const _LandingLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child:
          Image.asset('assets/images/p4u-welcome-logo.png', fit: BoxFit.cover),
    );
  }
}

class _LandingAccountButton extends ConsumerWidget {
  const _LandingAccountButton({this.authName, this.customerId});
  final String? authName;
  final String? customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loggedIn = authName != null;
    final fallback = loggedIn
        ? Text(
            authName!.trim().isEmpty
                ? 'U'
                : authName!.trim().characters.first.toUpperCase(),
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          )
        : const Icon(
            Icons.person_outline_rounded,
            color: AppColors.primary,
            size: 24,
          );
    return InkWell(
      onTap: () => context.push(loggedIn ? '/app/profile' : '/app/login'),
      customBorder: const CircleBorder(),
      child: Container(
        width: 44,
        height: 44,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: !loggedIn || customerId == null
            ? Center(child: fallback)
            : FutureBuilder<Map<String, dynamic>>(
                future: ref
                    .read(customerRepositoryProvider)
                    .profileWithStats(customerId!),
                builder: (context, snapshot) {
                  final profile = snapshot.data ?? const <String, dynamic>{};
                  final rawMeta = profile['metadata'];
                  final meta = rawMeta is Map
                      ? Map<String, dynamic>.from(rawMeta)
                      : const <String, dynamic>{};
                  final avatar = (meta['avatarUrl'] ??
                          meta['avatar'] ??
                          profile.s('avatarUrl', profile.s('avatar')))
                      .toString();
                  if (avatar.isEmpty) return Center(child: fallback);
                  return RemoteImage(url: avatar, width: 44, height: 44);
                },
              ),
      ),
    );
  }
}

class _LandingCard extends StatelessWidget {
  const _LandingCard({
    required this.title,
    required this.body,
    required this.icon,
    required this.route,
  });

  final String title;
  final String body;
  final IconData icon;
  final String route;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey<String>('landing:$route'),
      borderRadius: BorderRadius.circular(20),
      onTap: () => context.push(route),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: .20),
              const Color(0xFFFAF7E5).withValues(alpha: .60),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: .80),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(icon, color: Colors.white, size: 25),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.brandDark,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 105,
              height: 22,
              child: Text(
                body,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.05,
                  color: AppColors.brandDark,
                ),
              ),
            ),
            const SizedBox(height: 7),
            const _LandingArrow(),
          ],
        ),
      ),
    );
  }
}

class _LandingHomeButton extends StatelessWidget {
  const _LandingHomeButton();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const ValueKey<String>('landing:/app/home'),
      onTap: () => context.push('/app/home'),
      customBorder: const CircleBorder(),
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: .72),
            width: 6,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .22),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: .6),
              blurRadius: 0,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.home_outlined, color: Colors.white, size: 27),
            SizedBox(height: 2),
            Text(
              'Home',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LandingWallet extends ConsumerWidget {
  const _LandingWallet({required this.authenticated});
  final bool authenticated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = authenticated ? ref.watch(landingWalletProvider) : null;
    return InkWell(
      key: const ValueKey<String>('landing:/app/wallet'),
      borderRadius: BorderRadius.circular(22),
      onTap: () => context.push(authenticated ? '/app/wallet' : '/app/login'),
      child: Container(
        constraints: const BoxConstraints(minHeight: 84),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: .20),
              const Color(0xFFFAF7E5).withValues(alpha: .60),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Wallet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.brandDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    authenticated
                        ? 'Secure payments made easy'
                        : 'Login to view balance',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.15,
                      color: AppColors.brandDark,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (authenticated)
                  Container(
                    constraints: const BoxConstraints(minWidth: 54),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .24),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white70),
                    ),
                    child: Text(
                      balance?.maybeWhen(
                            data: (row) =>
                                '\u20B9${row.n('displayAmount', row.n('balance')).round()}',
                            loading: () => '...',
                            orElse: () => '\u20B90',
                          ) ??
                          '',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                const _LandingArrow(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LandingQuickLink extends StatelessWidget {
  const _LandingQuickLink({
    required this.label,
    required this.icon,
    required this.route,
  });
  final String label;
  final IconData icon;
  final String route;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey<String>('landing:$route'),
      borderRadius: BorderRadius.circular(50),
      onTap: () => context.push(route),
      child: SizedBox(
        width: 96,
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: .58),
                  width: 3,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.brandDark,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LandingArrow extends StatelessWidget {
  const _LandingArrow();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: .20),
        border: Border.all(color: Colors.white70),
      ),
      child: const Icon(
        Icons.arrow_forward_rounded,
        color: AppColors.primary,
        size: 16,
      ),
    );
  }
}

class CustomerHomePage extends ConsumerWidget {
  const CustomerHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeProvider);
    final location =
        ref.watch(selectedLocationProvider).valueOrNull ?? 'Set your location';
    return CustomerScaffold(
      title: 'Planext4u',
      bottomNavIndex: 0,
      child: home.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Home unavailable',
          message: e.toString(),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(homeProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            children: [
              _HomeSearch(location: location),
              const SizedBox(height: 12),
              _HeroBanners(data: data),
              const SectionHeader(
                title: 'Shop by service',
                subtitle: 'Everything you need, delivered simply',
              ),
              GridView.count(
                crossAxisCount: 3,
                childAspectRatio: 1.0,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: const [
                  _HomeAction(
                    'Shop',
                    Icons.shopping_bag_rounded,
                    '/app/browse',
                    AppColors.primary,
                  ),
                  _HomeAction(
                    'Services',
                    Icons.home_repair_service_rounded,
                    '/app/services',
                    AppColors.warning,
                  ),
                  _HomeAction(
                    'Socio',
                    Icons.groups_rounded,
                    '/app/social',
                    AppColors.info,
                  ),
                  _HomeAction(
                    'Classifieds',
                    Icons.campaign_rounded,
                    '/app/classifieds',
                    AppColors.primaryDark,
                  ),
                  _HomeAction(
                    'Wallet',
                    Icons.account_balance_wallet_rounded,
                    '/app/wallet',
                    AppColors.brandDark,
                  ),
                ],
              ),
              const SectionHeader(title: 'Shop by Category'),
              SizedBox(
                height: 126,
                child: data.categories.isEmpty
                    ? const EmptyState(
                        icon: Icons.category_rounded,
                        title: 'No categories',
                        message:
                            'Categories will appear when the API returns them.',
                      )
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: data.categories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) =>
                            _CategoryPill(category: data.categories[index]),
                      ),
              ),
              const SectionHeader(title: 'Featured Products'),
              if (data.products.isEmpty)
                const EmptyState(
                  icon: Icons.inventory_2_rounded,
                  title: 'No products yet',
                  message:
                      'Products will appear here when vendors publish them.',
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: data.products.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: .68,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (context, index) =>
                      ProductTile(product: data.products[index]),
                ),
              const SectionHeader(title: 'Popular Services'),
              ...data.services.map(
                (service) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ServiceTile(service: service),
                ),
              ),
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
        InkWell(
          onTap: () => context.push('/app/set-location'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.timer_rounded,
                  color: AppColors.primary,
                  size: 21,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Delivery in 10 minutes',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          onSubmitted: (value) =>
              context.push('/app/browse?search=${Uri.encodeComponent(value)}'),
          decoration: InputDecoration(
            hintText: 'Search for products and more',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: IconButton(
              onPressed: () => context.push(
                '/app/browse?search=${Uri.encodeComponent(controller.text)}',
              ),
              icon: const Icon(Icons.arrow_forward_rounded),
            ),
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
                RemoteImage(
                  url: banner.s('image', banner.s('image_url')),
                  borderRadius: 18,
                ),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: .45),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Text(
                      banner.s('title', 'Planext4u'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
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
      onTap: () => context.push(route),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          FittedBox(
            child: Text(
              label,
              maxLines: 1,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
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
    final id = category.s('id');
    return InkWell(
      onTap: () => context.push(
        '/app/browse?category=${Uri.encodeComponent(id.isNotEmpty ? id : name)}',
      ),
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 92,
        child: Column(
          children: [
            RemoteImage(url: category.s('image'), width: 68, height: 68),
            const SizedBox(height: 6),
            SizedBox(
              height: 38,
              child: Center(
                child: Text(
                  name,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    height: 1.08,
                  ),
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
    _future = ref.read(customerRepositoryProvider).browseProducts(
          search: _search.text.trim(),
          category: _category,
          sort: _sort,
        );
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
                suffixIcon: IconButton(
                  icon: const Icon(Icons.tune_rounded),
                  onPressed: () => _showFilters(context),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 320,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final products = snapshot.data ?? [];
                if (products.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No products found',
                    message: 'Try a different search, category, or sort.',
                  );
                }
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: products.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: .68,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (context, index) =>
                      ProductTile(product: products[index]),
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
            const Text(
              'Sort products',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            _SortOption(
              label: 'Latest',
              value: 'latest',
              selected: _sort,
              onTap: _applySort,
            ),
            _SortOption(
              label: 'Price: Low to High',
              value: 'price_low',
              selected: _sort,
              onTap: _applySort,
            ),
            _SortOption(
              label: 'Price: High to Low',
              value: 'price_high',
              selected: _sort,
              onTap: _applySort,
            ),
            _SortOption(
              label: 'Rating',
              value: 'rating',
              selected: _sort,
              onTap: _applySort,
            ),
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

class CustomerProductPage extends ConsumerStatefulWidget {
  const CustomerProductPage({required this.id, super.key});

  final String id;

  @override
  ConsumerState<CustomerProductPage> createState() =>
      _CustomerProductPageState();
}

class _CustomerProductPageState extends ConsumerState<CustomerProductPage> {
  late Future<
      (
        Map<String, dynamic>?,
        List<Map<String, dynamic>>,
        Map<String, dynamic>,
        List<Map<String, dynamic>>,
      )> _productFuture;
  int _qty = 1;
  int _imageIndex = 0;
  Map<String, String> _attrs = {};
  Map<String, dynamic>? _matchedVariant;

  @override
  void initState() {
    super.initState();
    _productFuture = _load();
  }

  @override
  void didUpdateWidget(covariant CustomerProductPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _qty = 1;
      _imageIndex = 0;
      _attrs = {};
      _matchedVariant = null;
      _productFuture = _load();
    }
  }

  void _retryLoad() => setState(() => _productFuture = _load());

  List<String> _gallery(Map<String, dynamic> product) {
    final urls = <String>[];
    for (final key in const [
      'images',
      'imageUrls',
      'bannerUrls',
      'mediaUrls',
      'media_urls',
    ]) {
      final raw = product[key];
      if (raw is List) {
        for (final e in raw) {
          final url = e is Map
              ? (e['url'] ?? e['imageUrl'] ?? e['image'] ?? '').toString()
              : e.toString();
          if (url.isNotEmpty && !urls.contains(url)) urls.add(url);
        }
      }
    }
    final primary = product.s('image');
    if (primary.isNotEmpty && !urls.contains(primary)) urls.insert(0, primary);
    return urls;
  }

  List<Map<String, dynamic>> _variantsOf(Map<String, dynamic> product) {
    final raw = product['variants'] ?? product['variations'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  void _matchVariant(List<Map<String, dynamic>> variants) {
    if (variants.isEmpty || _attrs.isEmpty) {
      _matchedVariant = null;
      return;
    }
    for (final v in variants) {
      final attrs = v['attributes'] ?? v['selectedAttributes'] ?? v['options'];
      if (attrs is! Map) continue;
      final map = attrs.map((k, val) => MapEntry(k.toString(), val.toString()));
      final matches = _attrs.entries.every((e) => map[e.key] == e.value);
      if (matches) {
        _matchedVariant = v;
        return;
      }
    }
    _matchedVariant = null;
  }

  Set<String> _attrKeys(List<Map<String, dynamic>> variants) {
    final keys = <String>{};
    for (final v in variants) {
      final attrs = v['attributes'] ?? v['selectedAttributes'] ?? v['options'];
      if (attrs is Map) keys.addAll(attrs.keys.map((e) => e.toString()));
    }
    return keys;
  }

  List<String> _attrValues(List<Map<String, dynamic>> variants, String key) {
    final values = <String>{};
    for (final v in variants) {
      final attrs = v['attributes'] ?? v['selectedAttributes'] ?? v['options'];
      if (attrs is Map && attrs[key] != null) {
        values.add(attrs[key].toString());
      }
    }
    return values.toList();
  }

  @override
  Widget build(BuildContext context) {
    return CustomerScaffold(
      title: 'Product',
      showBack: true,
      child: FutureBuilder<
          (
            Map<String, dynamic>?,
            List<Map<String, dynamic>>,
            Map<String, dynamic>,
            List<Map<String, dynamic>>,
          )>(
        future: _productFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Product unavailable',
              message: snapshot.error.toString(),
              action: FilledButton.icon(
                onPressed: _retryLoad,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            );
          }
          final product = snapshot.data?.$1;
          if (product == null) {
            return const EmptyState(
              icon: Icons.inventory_2_rounded,
              title: 'Product not found',
              message: 'This product may no longer be available.',
            );
          }
          final variants = snapshot.data?.$2 ?? _variantsOf(product);
          final summary = snapshot.data?.$3 ?? {};
          final reviews = snapshot.data?.$4 ?? [];
          final gallery = _gallery(product);
          num price = product.n('price');
          final variant = _matchedVariant;
          if (variant != null) {
            price = variant.n(
              'finalPrice',
              variant.n('sellPrice', variant.n('price', price)),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.productSurface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    RemoteImage(
                      url: gallery.isEmpty
                          ? product.s('image')
                          : gallery[_imageIndex.clamp(
                              0,
                              gallery.length - 1,
                            )],
                      height: 310,
                      width: double.infinity,
                      borderRadius: 12,
                    ),
                    if (gallery.length > 1) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 64,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: gallery.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) => GestureDetector(
                            onTap: () => setState(() => _imageIndex = i),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: i == _imageIndex
                                      ? AppColors.primary
                                      : AppColors.border,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: RemoteImage(
                                url: gallery[i],
                                width: 64,
                                height: 64,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                product.s('title'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (summary.n('average', summary.n('avgRating')) > 0)
                    StatusBadge(
                      '${summary.n('average', summary.n('avgRating')).toStringAsFixed(1)} ★',
                    ),
                  const SizedBox(width: 8),
                  Text(
                    product.s('vendor_name').isEmpty
                        ? '1 unit'
                        : product.s('vendor_name'),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                money(price),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.brandDark,
                  fontSize: 24,
                ),
              ),
              if (variants.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (final key in _attrKeys(variants)) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      key,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: _attrValues(variants, key)
                        .map(
                          (v) => ChoiceChip(
                            label: Text(v),
                            selected: _attrs[key] == v,
                            onSelected: (_) => setState(() {
                              _attrs = {..._attrs, key: v};
                              _matchVariant(variants);
                            }),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text(
                    'Qty',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 12),
                  _QtyStepper(
                    qty: _qty,
                    onChanged: (q) => setState(() => _qty = q < 1 ? 1 : q),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                product.s(
                  'description',
                  product.s(
                    'long_description',
                    'No description available.',
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _addToCart(product, buyNow: false),
                      icon: const Icon(Icons.add_shopping_cart_rounded),
                      label: const Text('Add to Cart'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _addToCart(product, buyNow: true),
                      icon: const Icon(Icons.flash_on_rounded),
                      label: const Text('Buy Now'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    onPressed: () async {
                      await ref
                          .read(customerRepositoryProvider)
                          .toggleWishlist(widget.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Wishlist updated')),
                        );
                      }
                    },
                    icon: const Icon(Icons.favorite_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: product.s('vendor_id').isEmpty
                    ? null
                    : () => context.push(
                          '/app/vendor/${product.s('vendor_id')}',
                        ),
                icon: const Icon(Icons.storefront_rounded),
                label: const Text('View Seller'),
              ),
              const SectionHeader(title: 'Reviews'),
              if (reviews.isEmpty)
                const Text(
                  'No reviews yet.',
                  style: TextStyle(color: AppColors.muted),
                )
              else
                ...reviews.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(r.s('customer_name', 'Customer')),
                        subtitle: Text(
                          r.s('comment', r.s('review', r.s('body'))),
                        ),
                        trailing: Text('${r.i('rating')} ★'),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<
      (
        Map<String, dynamic>?,
        List<Map<String, dynamic>>,
        Map<String, dynamic>,
        List<Map<String, dynamic>>,
      )> _load() async {
    final repo = ref.read(customerRepositoryProvider);
    final product = await repo.product(widget.id);
    final variants = product == null
        ? <Map<String, dynamic>>[]
        : await repo.productVariants(widget.id);
    final summary = await repo.productReviewSummary(widget.id);
    final reviews = await repo.productReviews(widget.id);
    return (product, variants, summary, reviews);
  }

  Future<void> _addToCart(
    Map<String, dynamic> product, {
    required bool buyNow,
  }) async {
    try {
      final repo = ref.read(customerRepositoryProvider);
      if (buyNow) await repo.clearCart();
      final variantId = _matchedVariant?.s('id');
      final priced = {
        ...product,
        if (_matchedVariant != null)
          'price': _matchedVariant!.n(
            'finalPrice',
            _matchedVariant!.n('sellPrice', product.n('price')),
          ),
      };
      await repo.addToCart(
        priced,
        qty: _qty,
        selectedAttributes: _attrs.isEmpty ? null : _attrs,
        variantId: variantId?.isEmpty == true ? null : variantId,
      );
      ref.invalidate(cartSummaryProvider);
      if (!mounted) return;
      if (buyNow) {
        context.push('/app/payment');
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Added to cart')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
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
        error: (e, _) => EmptyState(
          icon: Icons.shopping_cart_rounded,
          title: 'Cart unavailable',
          message: e.toString(),
        ),
        data: (cart) {
          if (cart.items.isEmpty) {
            return EmptyState(
              icon: Icons.shopping_cart_rounded,
              title: 'Your cart is empty',
              message: 'Add products from the shop to checkout.',
              action: FilledButton(
                onPressed: () => context.push('/app/browse'),
                child: const Text('Shop Now'),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.accent,
                      child: Icon(
                        Icons.timer_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Delivery in 10 minutes',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                            ),
                          ),
                          Text(
                            'Shipment of all items',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
                              Text(
                                item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                money(item.price),
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _QtyStepper(
                          qty: item.qty,
                          onChanged: (qty) async {
                            try {
                              await ref
                                  .read(customerRepositoryProvider)
                                  .updateCartItem(item.id, qty);
                              ref.invalidate(cartSummaryProvider);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            }
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
                    if (cart.tax > 0) _TotalRow('Tax', cart.tax),
                    if (cart.platformFee > 0)
                      _TotalRow('Platform fee', cart.platformFee),
                    if (cart.gstOnPlatformFee > 0)
                      _TotalRow('GST on fee', cart.gstOnPlatformFee),
                    if (cart.deliveryFee > 0)
                      _TotalRow('Delivery', cart.deliveryFee),
                    if (cart.surgeCost > 0) _TotalRow('Surge', cart.surgeCost),
                    if (cart.discount > 0)
                      _TotalRow('Discount', -cart.discount),
                    if (cart.pointsRedeemedValue > 0)
                      _TotalRow('Points redeemed', -cart.pointsRedeemedValue),
                    if (cart.couponDiscount > 0)
                      _TotalRow('Coupon', -cart.couponDiscount),
                    const Divider(),
                    _TotalRow('Total', cart.total, bold: true),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: auth == null
                    ? () => context.push('/app/login')
                    : () => context.push('/app/payment'),
                icon: const Icon(Icons.payment_rounded),
                label: Text(
                  auth == null ? 'Login to Checkout' : 'Proceed to Payment',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class PaymentPage extends ConsumerStatefulWidget {
  const PaymentPage({super.key});

  @override
  ConsumerState<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends ConsumerState<PaymentPage> {
  CartSummary? _summary;
  List<Map<String, dynamic>> _addresses = const [];
  final _coupon = TextEditingController();
  final _points = TextEditingController(text: '0');
  String _payMethod = 'cod';
  num _couponDiscount = 0;
  bool _loading = true;
  bool _placing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _coupon.dispose();
    _points.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final auth = ref.read(customerAuthStateProvider).valueOrNull;
    if (auth == null) return;
    setState(() => _loading = true);
    try {
      final points = int.tryParse(_points.text.trim()) ?? 0;
      final repo = ref.read(customerRepositoryProvider);
      final summary = await repo.cartSummary(
        pointsUsed: points,
        couponDiscount: _couponDiscount,
      );
      final addresses = await repo.customerAddresses(auth.id);
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _addresses = addresses;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(customerAuthStateProvider).valueOrNull;
    if (auth == null) return const _LoginRequired();
    if (_loading) {
      return const CustomerScaffold(
        title: 'Payment',
        showBack: true,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final summary = _summary;
    if (summary == null || summary.items.isEmpty) {
      return const CustomerScaffold(
        title: 'Payment',
        showBack: true,
        child: EmptyState(
          icon: Icons.shopping_cart_rounded,
          title: 'Cart is empty',
          message: 'Add products before payment.',
        ),
      );
    }
    final address = _addresses.isEmpty ? null : _addresses.first;
    return CustomerScaffold(
      title: 'Payment',
      showBack: true,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeader(title: 'Delivery Address'),
          AppCard(
            child: address == null
                ? const Text(
                    'No saved address. Add one from profile edit or set location.',
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        address.s('name', auth.name),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(address.s('address_line', address.s('address'))),
                      Text('${address.s('city')} ${address.s('pincode')}'),
                    ],
                  ),
          ),
          const SectionHeader(title: 'Rewards & coupon'),
          AppCard(
            child: Column(
              children: [
                TextField(
                  controller: _points,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Redeem points',
                    hintText:
                        'Max ${summary.maxRedeemableValue.round()} pts / balance ${summary.walletBalanceBefore.round()}',
                    prefixIcon: const Icon(Icons.stars_rounded),
                    suffixIcon: TextButton(
                      onPressed: _load,
                      child: const Text('Apply'),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _coupon,
                  decoration: InputDecoration(
                    labelText: 'Coupon code',
                    prefixIcon: const Icon(Icons.local_offer_outlined),
                    suffixIcon: TextButton(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          final discount = await ref
                              .read(customerRepositoryProvider)
                              .validateCouponCode(
                                _coupon.text,
                                summary.subtotal,
                              );
                          setState(() => _couponDiscount = discount);
                          await _load();
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Coupon applied: ${money(discount)} off',
                              ),
                            ),
                          );
                        } catch (e) {
                          messenger.showSnackBar(SnackBar(content: Text('$e')));
                        }
                      },
                      child: const Text('Apply'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'Order Summary'),
          AppCard(
            child: Column(
              children: [
                _TotalRow('Items', summary.count),
                _TotalRow('Subtotal', summary.subtotal),
                if (summary.tax > 0) _TotalRow('Tax', summary.tax),
                if (summary.platformFee > 0)
                  _TotalRow('Platform fee', summary.platformFee),
                if (summary.gstOnPlatformFee > 0)
                  _TotalRow('GST on fee', summary.gstOnPlatformFee),
                if (summary.deliveryFee > 0)
                  _TotalRow('Delivery', summary.deliveryFee),
                if (summary.surgeCost > 0)
                  _TotalRow('Surge', summary.surgeCost),
                if (summary.discount > 0)
                  _TotalRow('Discount', -summary.discount),
                if (summary.pointsRedeemedValue > 0)
                  _TotalRow('Points redeemed', -summary.pointsRedeemedValue),
                if (summary.couponDiscount > 0)
                  _TotalRow('Coupon', -summary.couponDiscount),
                const Divider(),
                _TotalRow('Payable', summary.total, bold: true),
              ],
            ),
          ),
          const SectionHeader(title: 'Payment method'),
          AppCard(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Cash on Delivery'),
                  leading: Icon(
                    _payMethod == 'cod'
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: AppColors.primary,
                  ),
                  onTap: () => setState(() => _payMethod = 'cod'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Online (Razorpay)'),
                  subtitle: const Text(
                    'Creates a payment intent and confirms after capture',
                  ),
                  leading: Icon(
                    _payMethod == 'online'
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: AppColors.primary,
                  ),
                  onTap: () => setState(() => _payMethod = 'online'),
                ),
              ],
            ),
          ),
          if (!summary.meetsMinCart)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Cart does not meet the minimum order amount.',
                style: TextStyle(color: Colors.red),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _placing || !summary.meetsMinCart
                ? null
                : () => _place(auth.id, summary, address),
            icon: const Icon(Icons.check_circle_rounded),
            label: Text(_placing ? 'Placing...' : 'Place Order'),
          ),
        ],
      ),
    );
  }

  Future<void> _place(
    String customerId,
    CartSummary summary,
    Map<String, dynamic>? address,
  ) async {
    setState(() {
      _placing = true;
      _error = null;
    });
    try {
      final repo = ref.read(customerRepositoryProvider);
      final order = await repo.placeOrder(
        customerId: customerId,
        summary: summary,
        address: address,
        paymentMode: _payMethod,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Order placed: ${order.s('orderRef', order.s('id'))}',
            ),
          ),
        );
      }
      if (_payMethod == 'online') {
        final intent = await repo.createPaymentIntentForOrder(
          orderId: order.s('id'),
          amount: summary.total,
        );
        final intentId = intent.s('id');
        var paid = false;
        for (var i = 0; i < 8; i++) {
          await Future<void>.delayed(const Duration(seconds: 2));
          final status = await repo.paymentIntentStatus(intentId);
          final st = status.s('status').toLowerCase();
          if (st == 'succeeded' || st == 'completed' || st == 'captured') {
            paid = true;
            break;
          }
          if (st == 'failed' || st == 'cancelled') break;
        }
        if (!paid) {
          // Still leave the order pending; user can pay from My Orders later.
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Order created. Complete payment from My Orders if needed.',
                ),
              ),
            );
          }
        } else {
          await repo.clearCartAfterPaid();
        }
      }
      ref.invalidate(cartSummaryProvider);
      if (mounted) context.go('/app/orders');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }
}

class CustomerOrdersPage extends ConsumerStatefulWidget {
  const CustomerOrdersPage({super.key});

  @override
  ConsumerState<CustomerOrdersPage> createState() => _CustomerOrdersPageState();
}

class _CustomerOrdersPageState extends ConsumerState<CustomerOrdersPage> {
  Future<List<Map<String, dynamic>>>? _future;
  String? _customerId;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(customerAuthStateProvider).valueOrNull;
    if (auth == null) return const _LoginRequired();
    if (_future == null || _customerId != auth.id) {
      _customerId = auth.id;
      _future = ref.read(customerRepositoryProvider).orders(auth.id);
    }
    return CustomerScaffold(
      title: 'Orders',
      showBack: true,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Could not load orders',
              message: snapshot.error.toString(),
            );
          }
          final orders = snapshot.data ?? [];
          if (orders.isEmpty) {
            return const EmptyState(
              icon: Icons.receipt_long_rounded,
              title: 'No orders',
              message: 'Your orders will appear here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final order = orders[index];
              final orderItems = order['items'] is List
                  ? (order['items'] as List).whereType<Map>().toList()
                  : const <Map>[];
              final firstImage = orderItems.isNotEmpty
                  ? Map<String, dynamic>.from(orderItems.first).s('image')
                  : '';
              final itemCount = orderItems.length;
              return AppCard(
                onTap: () => context.push('/app/orders/${order.s('id')}'),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: firstImage.isNotEmpty
                          ? RemoteImage(url: firstImage, width: 44, height: 44)
                          : const SizedBox(
                              width: 44,
                              height: 44,
                              child: Icon(
                                Icons.receipt_long_rounded,
                                color: AppColors.primary,
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.s(
                              'orderRef',
                              order.s('order_ref', order.s('id')),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '${shortDate(order['created_at'])} · $itemCount item${itemCount == 1 ? '' : 's'}',
                            style: const TextStyle(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          money(order.n('total')),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        StatusBadge(order.s('status', 'placed')),
                      ],
                    ),
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

class CustomerOrderDetailPage extends ConsumerStatefulWidget {
  const CustomerOrderDetailPage({required this.orderId, super.key});

  final String orderId;

  @override
  ConsumerState<CustomerOrderDetailPage> createState() =>
      _CustomerOrderDetailPageState();
}

class _CustomerOrderDetailPageState
    extends ConsumerState<CustomerOrderDetailPage> {
  @override
  Widget build(BuildContext context) {
    final orderId = widget.orderId;
    return CustomerScaffold(
      title: 'Order Details',
      showBack: true,
      child: FutureBuilder<(Map<String, dynamic>?, Map<String, dynamic>?)>(
        future: _load(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final order = snapshot.data?.$1;
          final tracking = snapshot.data?.$2 ?? <String, dynamic>{};
          if (order == null) {
            return const EmptyState(
              icon: Icons.receipt_long_rounded,
              title: 'Order not found',
              message: 'Please check the order again.',
            );
          }
          final items = order['items'] is List
              ? (order['items'] as List)
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList()
              : <Map<String, dynamic>>[];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.s(
                              'orderRef',
                              order.s('order_ref', order.s('id')),
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        StatusBadge(order.s('status', 'placed')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Placed on ${shortDate(order['created_at'])}'),
                    const SizedBox(height: 8),
                    Text(
                      money(order.n('total')),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      ),
                    ),
                  ],
                ),
              ),
              const SectionHeader(title: 'Delivery & returns'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.local_shipping_outlined,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Status: ${tracking.s('status', order.s('status')).replaceAll('_', ' ')}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    if (tracking.s('shippingType').isNotEmpty)
                      Text('Shipping: ${tracking.s('shippingType')}'),
                    if (tracking.s('courierName').isNotEmpty)
                      Text('Courier: ${tracking.s('courierName')}'),
                    if (tracking.s('trackingNumber').isNotEmpty)
                      Text('Tracking / AWB: ${tracking.s('trackingNumber')}'),
                    if (tracking['history'] is List) ...[
                      const SizedBox(height: 8),
                      for (final entry
                          in (tracking['history'] as List).whereType<Map>())
                        Text(
                          '• ${entry['status']?.toString().replaceAll('_', ' ')}  ${shortDate(entry['at'])}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                    ],
                    if (tracking['returnRequest'] is Map) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Return: ${(tracking['returnRequest'] as Map)['status']?.toString().replaceAll('_', ' ')}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (const {
                          'shipped',
                          'out_for_delivery',
                        }.contains(order.s('status').toLowerCase()))
                          FilledButton.icon(
                            onPressed: _confirmDelivery,
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Confirm delivery'),
                          ),
                        if (const {
                              'delivered',
                              'completed',
                            }.contains(order.s('status').toLowerCase()) &&
                            tracking['returnRequest'] == null)
                          OutlinedButton.icon(
                            onPressed: _requestReturn,
                            icon: const Icon(Icons.keyboard_return_rounded),
                            label: const Text('Request return'),
                          ),
                      ],
                    ),
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
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: RemoteImage(
                            url: item.s('image'),
                            width: 48,
                            height: 48,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.s('title'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${item.i('qty', 1)} x ${money(item.n('price'))}',
                                style: const TextStyle(color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          money(item.n('price') * item.i('qty', 1)),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
              const SectionHeader(title: 'Bill details'),
              AppCard(
                child: Column(
                  children: [
                    if (order.n('subtotal') > 0)
                      _TotalRow('Subtotal', order.n('subtotal')),
                    if (order.n('platform_fee') > 0)
                      _TotalRow('Platform fee', order.n('platform_fee')),
                    if (order.n('gst') > 0) _TotalRow('GST', order.n('gst')),
                    if (order.n('delivery_fee') > 0)
                      _TotalRow('Delivery', order.n('delivery_fee')),
                    const Divider(),
                    _TotalRow('Grand total', order.n('total'), bold: true),
                  ],
                ),
              ),
              const SectionHeader(title: 'Payment'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status: ${order.s('payment_status', 'pending')}'),
                    if (order.s('payment_ref').isNotEmpty)
                      Text('Ref: ${order.s('payment_ref')}'),
                  ],
                ),
              ),
              if (order.s('vendor_name').isNotEmpty ||
                  order.s('vendor_id').isNotEmpty) ...[
                const SectionHeader(title: 'Seller'),
                AppCard(
                  onTap: order.s('vendor_id').isEmpty
                      ? null
                      : () =>
                          context.push('/app/vendor/${order.s('vendor_id')}'),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.storefront_rounded,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          order.s('vendor_name', 'Seller'),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (order.s('vendor_id').isNotEmpty)
                        const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final buf = StringBuffer()
                    ..writeln('P4U Order Invoice')
                    ..writeln('Order: ${order.s('id')}')
                    ..writeln('Date: ${order.s('created_at')}')
                    ..writeln('Status: ${order.s('status')}')
                    ..writeln('---');
                  for (final item in items) {
                    buf.writeln(
                      '${item.s('title')} x${item.i('qty', 1)} = ${money(item.n('price') * item.i('qty', 1))}',
                    );
                  }
                  buf.writeln('Total: ${money(order.n('total'))}');
                  await Clipboard.setData(ClipboardData(text: buf.toString()));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Invoice copied to clipboard'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Copy invoice'),
              ),
              if (_canCancel(order.s('status', 'placed'))) ...[
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Cancel order?'),
                        content: const Text(
                          'This will cancel the order if it has not shipped.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Keep'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Cancel order'),
                          ),
                        ],
                      ),
                    );
                    if (ok != true) return;
                    await ref
                        .read(customerRepositoryProvider)
                        .cancelOrder(orderId);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Order cancelled')),
                      );
                      context.pop();
                    }
                  },
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancel Order'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<(Map<String, dynamic>?, Map<String, dynamic>?)> _load() async {
    final repo = ref.read(customerRepositoryProvider);
    final order = await repo.order(widget.orderId);
    Map<String, dynamic>? tracking;
    try {
      tracking = await repo.productTracking(widget.orderId);
    } catch (_) {
      // Tracking is supplementary. A legacy order or temporarily unavailable
      // tracking endpoint must not make an otherwise valid order disappear.
    }
    return (order, tracking);
  }

  Future<void> _confirmDelivery() async {
    try {
      await ref
          .read(customerRepositoryProvider)
          .confirmProductDelivery(widget.orderId);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Delivery confirmed')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _requestReturn() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Request return'),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Reason (minimum 5 characters)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || reason.length < 5) return;
    try {
      await ref
          .read(customerRepositoryProvider)
          .requestProductReturn(widget.orderId, reason);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Return requested')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }
}

bool _canCancel(String status) {
  const blocked = {
    'cancelled',
    'canceled',
    'shipped',
    'delivered',
    'completed',
  };
  return !blocked.contains(status.toLowerCase());
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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final vendor = snapshot.data?.$1;
          final products = snapshot.data?.$2 ?? [];
          if (vendor == null) {
            return const EmptyState(
              icon: Icons.storefront_rounded,
              title: 'Seller not found',
              message: 'This seller is unavailable.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if ((vendor['banners'] is List) &&
                  (vendor['banners'] as List).isNotEmpty)
                SizedBox(
                  height: 160,
                  child: PageView(
                    children: [
                      for (final b in (vendor['banners'] as List))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: RemoteImage(
                            url: b.toString(),
                            height: 160,
                            width: double.infinity,
                            borderRadius: 14,
                          ),
                        ),
                    ],
                  ),
                ),
              AppCard(
                child: Row(
                  children: [
                    RemoteImage(url: vendor.s('logo'), width: 72, height: 72),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vendor.s('business_name', vendor.s('name')),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            vendor.s('city'),
                            style: const TextStyle(color: AppColors.muted),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            children: [
                              StatusBadge(vendor.s('status', 'active')),
                              if (vendor.n('rating') > 0)
                                StatusBadge(
                                  '${vendor.n('rating').toStringAsFixed(1)} ★',
                                ),
                            ],
                          ),
                          if (vendor.s('mobile').isNotEmpty ||
                              vendor.s('email').isNotEmpty) ...[
                            const SizedBox(height: 8),
                            if (vendor.s('mobile').isNotEmpty)
                              InkWell(
                                onTap: () => launchUrl(
                                  Uri(scheme: 'tel', path: vendor.s('mobile')),
                                ),
                                child: Text(
                                  vendor.s('mobile'),
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            if (vendor.s('email').isNotEmpty)
                              InkWell(
                                onTap: () => launchUrl(
                                  Uri(
                                    scheme: 'mailto',
                                    path: vendor.s('email'),
                                  ),
                                ),
                                child: Text(
                                  vendor.s('email'),
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SectionHeader(title: 'Seller Products'),
              if (products.isEmpty)
                const EmptyState(
                  icon: Icons.inventory_2_rounded,
                  title: 'No products',
                  message: 'This seller has no active products.',
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: products.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: .68,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (context, index) =>
                      ProductTile(product: products[index]),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<(Map<String, dynamic>?, List<Map<String, dynamic>>)> _vendorData(
    WidgetRef ref,
  ) async {
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
          AppCard(child: Text('This page content is currently unavailable.')),
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
        IconButton.filledTonal(
          onPressed: () => onChanged(qty - 1),
          icon: const Icon(Icons.remove_rounded),
        ),
        SizedBox(
          width: 28,
          child: Text(
            '$qty',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        IconButton.filledTonal(
          onPressed: () => onChanged(qty + 1),
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }
}

class _SortOption extends StatelessWidget {
  const _SortOption({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final active = value == selected;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: TextStyle(
          fontWeight: active ? FontWeight.w900 : FontWeight.w500,
        ),
      ),
      trailing: active
          ? const Icon(Icons.check_rounded, color: AppColors.primary)
          : null,
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
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
      fontSize: bold ? 17 : 14,
    );
    final formatted = value is num ? money(value as num) : value.toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(formatted, style: style),
        ],
      ),
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
        action: FilledButton(
          onPressed: () => context.push('/app/login'),
          child: const Text('Login'),
        ),
      ),
    );
  }
}
