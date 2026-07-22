import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:p4u_customer_app/src/features/auth/data/auth_repository.dart';
import 'package:p4u_customer_app/src/features/auth/domain/customer_user.dart';
import 'package:p4u_customer_app/src/features/customer/data/customer_providers.dart';
import 'package:p4u_customer_app/src/features/customer/domain/customer_models.dart';
import 'package:p4u_customer_app/src/features/customer/presentation/pages/customer_home_page.dart';

const _user = CustomerUser(
    id: 'c-1',
    name: 'Customer',
    email: 'c@example.com',
    mobile: '+919999999999');

final _home = CustomerHomeData(
  banners: const [
    {
      'id': 'b-1',
      'title': 'Live banner',
      'imageUrl': 'assets/images/banners/hero-banner-1.jpg',
      'redirectUrl': '/app/browse'
    },
  ],
  categories: const [
    {
      'id': 'cat-1',
      'name': 'Groceries',
      'image': 'assets/images/categories/groceries.jpg',
      'is_trending': true
    },
    {
      'id': 'cat-2',
      'name': 'Electronics',
      'image': 'assets/images/categories/electronics.jpg'
    },
    {
      'id': 'sub-1',
      'parent_id': 'cat-1',
      'name': 'Fruits and Nuts',
      'image': 'assets/images/categories/organic-products.jpg'
    },
  ],
  serviceCategories: const [
    {
      'id': 'sc-1',
      'name': 'Appliance Repair',
      'image': 'assets/images/categories/carpenter.jpg'
    },
  ],
  products: const [
    {
      'id': 'p-1',
      'title': 'Live Product',
      'price': 499,
      'image': 'assets/images/products/fair-and-lovely.jpg'
    },
  ],
  trendingProducts: const [
    {
      'id': 'p-1',
      'title': 'Live Product',
      'price': 499,
      'image': 'assets/images/products/fair-and-lovely.jpg'
    },
  ],
  dealProducts: const [
    {
      'id': 'p-1',
      'title': 'Live Product',
      'price': 399,
      'discount': 100,
      'image': 'assets/images/products/fair-and-lovely.jpg'
    },
  ],
  recentProducts: const [],
  services: const [
    {
      'id': 's-1',
      'title': 'Live Service',
      'price': 349,
      'duration': '1 hour',
      'image': 'assets/images/categories/carpenter.jpg'
    },
  ],
  storeBanners: const [
    {
      'id': 'store-1',
      'title': 'Grocery Store',
      'imageUrl': 'assets/images/categories/groceries.jpg',
      'redirectUrl': '/app/browse'
    },
  ],
  brands: const [],
  classified: const [
    {
      'id': 'ad-1',
      'title': 'Live classified',
      'image': 'assets/images/onboarding-shop.jpg'
    },
  ],
  assets: const {},
);

GoRouter _router() => GoRouter(initialLocation: '/app', routes: [
      GoRoute(
          path: '/app', builder: (_, __) => const CustomerReferenceHomePage()),
      for (final route in const [
        '/app/login',
        '/app/set-location',
        '/app/wallet',
        '/app/profile',
        '/app/browse',
        '/app/social',
        '/app/services',
        '/app/find-home',
        '/app/classifieds',
        '/app/classifieds/post'
      ])
        GoRoute(
            path: route,
            builder: (_, state) =>
                Scaffold(body: Text('destination:${state.uri.path}'))),
      GoRoute(
          path: '/app/product/:id',
          builder: (_, state) =>
              Scaffold(body: Text('product:${state.pathParameters['id']}'))),
      GoRoute(
          path: '/app/service/:id',
          builder: (_, state) =>
              Scaffold(body: Text('service:${state.pathParameters['id']}'))),
    ]);

Widget _app(GoRouter router, {CustomerUser? user = _user}) => ProviderScope(
      overrides: [
        customerAuthStateProvider
            .overrideWith((ref) => Stream<CustomerUser?>.value(user)),
        selectedLocationProvider.overrideWith((ref) async => 'Chennai, TN'),
        landingWalletProvider
            .overrideWith((ref) async => <String, dynamic>{'balance': 829}),
        homeProvider.overrideWith((ref) async => _home),
      ],
      child: MaterialApp.router(routerConfig: router),
    );

void main() {
  testWidgets('Home renders all live-data sections in reference order',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    expect(find.text('Chennai, TN'), findsOneWidget);
    expect(find.text('829'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-search')), findsOneWidget);
    expect(find.text('Groceries'), findsWidgets);


    for (final title in const [
      'Best of Products',
      'Shop by Category',
      'Trending Categories',
      'Shop Groceries',
      'Top Services',
      'Pick up where you left off',
      'Trending Now',
      'Deals of the Day',
      'Home Services',
      'SUBSCRIBE NOW',
      'Buy & Sell Locally'
    ]) {
      final finder = find.textContaining(title);
      await tester.scrollUntilVisible(finder, 300,
          scrollable: find.byType(Scrollable).last);
      expect(finder, findsWidgets);
    }
  });

  testWidgets('Home location, wallet and search open functional routes',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    tester
        .widget<InkWell>(find.byKey(const ValueKey('home-location')))
        .onTap!
        .call();
    await tester.pumpAndSettle();
    expect(find.text('destination:/app/set-location'), findsOneWidget);

    router.go('/app');
    await tester.pumpAndSettle();
    tester
        .widget<InkWell>(find.byKey(const ValueKey('home-wallet')))
        .onTap!
        .call();
    await tester.pumpAndSettle();
    expect(find.text('destination:/app/wallet'), findsOneWidget);

    router.go('/app');
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('home-search')), 'shampoo');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('destination:/app/browse'), findsOneWidget);
  });

  testWidgets('Guests can browse Home without an OTP session', (tester) async {
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router, user: null));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-search')), findsOneWidget);
    expect(find.text('destination:/app/login'), findsNothing);
  });
}
