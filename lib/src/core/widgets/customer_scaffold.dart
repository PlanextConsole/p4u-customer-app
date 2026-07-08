import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/auth_repository.dart';
import '../theme/app_theme.dart';

class CustomerScaffold extends ConsumerWidget {
  const CustomerScaffold({
    required this.title,
    required this.child,
    this.actions,
    this.showBack = false,
    this.bottomNavIndex,
    super.key,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;
  final bool showBack;
  final int? bottomNavIndex;

  static const nav = [
    _NavItem('Home', Icons.home_rounded, '/app'),
    _NavItem('Shop', Icons.shopping_bag_rounded, '/app/browse'),
    _NavItem('Services', Icons.home_repair_service_rounded, '/app/services'),
    _NavItem('Socio', Icons.groups_rounded, '/app/social'),
    _NavItem('Homes', Icons.apartment_rounded, '/app/find-home'),
    _NavItem('Ads', Icons.campaign_rounded, '/app/classifieds'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(customerAuthStateProvider);
    final customer = auth.valueOrNull;
    final interceptBack = bottomNavIndex != null && !showBack;
    return PopScope(
      canPop: !interceptBack,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !interceptBack) return;
        final currentPath = GoRouterState.of(context).uri.path;
        if (currentPath != '/app') {
          context.go('/app');
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are already on Home')),
        );
      },
      child: Scaffold(
        appBar: AppBar(
          leading: showBack ? IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_back_rounded)) : null,
          titleSpacing: showBack ? 0 : 16,
          title: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Image.asset('assets/images/p4u-logo.png', fit: BoxFit.contain),
              ),
              const SizedBox(width: 8),
              Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Cart',
              onPressed: () => context.go('/app/cart'),
              icon: const Icon(Icons.shopping_cart_rounded),
            ),
            if (customer == null)
              TextButton(
                onPressed: () => context.go('/app/login'),
                child: const Text('Login', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              )
            else
              IconButton(
                tooltip: 'Profile',
                onPressed: () => context.go('/app/profile'),
                icon: CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.white.withValues(alpha: .18),
                  child: Text(customer.name.isEmpty ? 'U' : customer.name.characters.first.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ),
            ...?actions,
          ],
        ),
        body: child,
        bottomNavigationBar: bottomNavIndex == null ? null : _CustomerBottomNav(selectedIndex: bottomNavIndex!),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.label, this.icon, this.route);
  final String label;
  final IconData icon;
  final String route;
}

class _CustomerBottomNav extends StatelessWidget {
  const _CustomerBottomNav({required this.selectedIndex});

  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    final selected = selectedIndex.clamp(0, CustomerScaffold.nav.length - 1).toInt();
    return SafeArea(
      top: false,
      child: Container(
        height: 70,
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
        decoration: const BoxDecoration(
          color: Color(0xFFF7FAFA),
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            for (var index = 0; index < CustomerScaffold.nav.length; index++)
              Expanded(
                child: _BottomNavItem(
                  item: CustomerScaffold.nav[index],
                  selected: index == selected,
                  onTap: () => context.go(CustomerScaffold.nav[index].route),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 34,
            width: selected ? 48 : 40,
            decoration: BoxDecoration(
              color: selected ? AppColors.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(item.icon, size: 23, color: selected ? AppColors.primary : AppColors.brandDark.withValues(alpha: .72)),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              item.label,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                color: selected ? AppColors.primary : AppColors.brandDark.withValues(alpha: .72),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PageShell extends StatelessWidget {
  const PageShell({required this.children, this.padding = const EdgeInsets.all(16), super.key});

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView(
        padding: padding,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
          ),
        ],
      ),
    );
  }
}
