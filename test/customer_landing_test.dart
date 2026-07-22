import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:p4u_customer_app/src/features/auth/data/auth_repository.dart';
import 'package:p4u_customer_app/src/features/auth/domain/customer_user.dart';
import 'package:p4u_customer_app/src/features/customer/data/customer_providers.dart';
import 'package:p4u_customer_app/src/features/customer/presentation/pages/commerce_pages.dart';

const _customer = CustomerUser(
  id: 'customer-1',
  name: 'Test Customer',
  email: 'customer@example.com',
  mobile: '+919999999999',
);

GoRouter _router() => GoRouter(
      initialLocation: '/app',
      routes: [
        GoRoute(
          path: '/app',
          builder: (_, __) => const CustomerLandingPage(),
        ),
        GoRoute(
          path: '/app/login',
          builder: (_, __) => const Scaffold(body: Text('OTP login')),
        ),
        for (final route in const [
          '/app/home',
          '/app/browse',
          '/app/social',
          '/app/services',
          '/app/classifieds',
          '/app/wallet',
          '/app/emergency',
          '/app/support',
          '/app/quick-assist',
          '/app/profile',
        ])
          GoRoute(
            path: route,
            builder: (_, __) => Scaffold(body: Text('destination:$route')),
          ),
      ],
    );

Widget _app(GoRouter router, CustomerUser? customer) => ProviderScope(
      overrides: [
        customerAuthStateProvider.overrideWith(
          (ref) => Stream<CustomerUser?>.value(customer),
        ),
        landingWalletProvider.overrideWith(
          (ref) async => <String, dynamic>{'balance': 829},
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    );

Future<void> _useReferenceViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(393, 879);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('valid session opens the customer Home landing page',
      (tester) async {
    await _useReferenceViewport(tester);
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(_app(router, _customer));
    await tester.pumpAndSettle();

    expect(find.text('Welcome!'), findsOneWidget);
    for (final label in const ['Shop', 'Socio', 'Services', 'Classifieds']) {
      expect(find.text(label), findsOneWidget);
    }
    for (final label in const [
      'Wallet',
      'Emergency',
      'Help',
      'Quick Assist',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(tester.getRect(find.text('Quick Assist')).bottom, lessThan(879));
    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile('goldens/customer_landing_716x1600.png'),
    );
  });

  testWidgets('missing session still opens the guest welcome page',
      (tester) async {
    await _useReferenceViewport(tester);
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(_app(router, null));
    await tester.pumpAndSettle();

    expect(find.text('Welcome!'), findsOneWidget);
    expect(find.text('OTP login'), findsNothing);
    expect(router.routeInformationProvider.value.uri.path, '/app');
  });

  testWidgets('all Home modules navigate to their destination routes',
      (tester) async {
    await _useReferenceViewport(tester);
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router, _customer));
    await tester.pumpAndSettle();

    const destinations = <String, String>{
      'Home': '/app/home',
      'Shop': '/app/browse',
      'Socio': '/app/social',
      'Services': '/app/services',
      'Classifieds': '/app/classifieds',
      'Wallet': '/app/wallet',
      'Emergency': '/app/emergency',
      'Help': '/app/support',
      'Quick Assist': '/app/quick-assist',
    };

    for (final entry in destinations.entries) {
      final action = find.text(entry.key);
      await tester.scrollUntilVisible(
        action,
        220,
        scrollable: find.byType(Scrollable).first,
      );
      final card = find.byKey(ValueKey<String>('landing:${entry.value}'));
      expect(card, findsOneWidget);
      tester.widget<InkWell>(card).onTap!.call();
      await tester.pumpAndSettle();
      expect(find.text('destination:${entry.value}'), findsOneWidget);
      router.go('/app');
      await tester.pumpAndSettle();
    }
  });

  testWidgets('welcome layout matches the reference frame', (tester) async {
    await _useReferenceViewport(tester);
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(_app(router, null));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(CustomerLandingPage),
      matchesGoldenFile('goldens/customer_landing_reference.png'),
    );
  });
}
