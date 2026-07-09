import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/customer_models.dart';
import 'customer_repository.dart';

final customerRepositoryProvider = Provider((ref) => CustomerRepository());

final homeProvider = FutureProvider<CustomerHomeData>((ref) {
  return ref.watch(customerRepositoryProvider).getHome();
});

final cartSummaryProvider = FutureProvider<CartSummary>((ref) {
  return ref.watch(customerRepositoryProvider).cartSummary();
});

final selectedLocationProvider = FutureProvider<String?>((ref) {
  return ref.watch(customerRepositoryProvider).selectedLocation();
});

final landingWalletProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return ref.watch(customerRepositoryProvider).rewardPoints('');
});
