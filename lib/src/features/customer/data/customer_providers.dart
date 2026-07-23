import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/map_ext.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/customer_models.dart';
import 'customer_repository.dart';

final customerRepositoryProvider = Provider((ref) => CustomerRepository());

final homeProvider = FutureProvider<CustomerHomeData>((ref) {
  return ref.watch(customerRepositoryProvider).getHome();
});

final cartSummaryProvider = FutureProvider<CartSummary>((ref) {
  return ref.watch(customerRepositoryProvider).cartSummary();
});

class CustomerAddressState {
  const CustomerAddressState({
    this.addresses = const [],
    this.selectedAddressId,
  });

  final List<Map<String, dynamic>> addresses;
  final String? selectedAddressId;

  Map<String, dynamic>? get selectedAddress {
    if (addresses.isEmpty) return null;
    if (selectedAddressId != null) {
      for (final address in addresses) {
        if (address.s('id') == selectedAddressId) return address;
      }
    }
    for (final address in addresses) {
      if (address.b('is_default')) return address;
    }
    return addresses.first;
  }

  CustomerAddressState copyWith({
    List<Map<String, dynamic>>? addresses,
    String? selectedAddressId,
  }) =>
      CustomerAddressState(
        addresses: addresses ?? this.addresses,
        selectedAddressId: selectedAddressId ?? this.selectedAddressId,
      );
}

String formatCustomerAddress(Map<String, dynamic>? address) {
  if (address == null) return '';
  return [
    address.s('address_line', address.s('line1')),
    address.s('line2'),
    address.s('city'),
    address.s('state'),
    address.s('pincode'),
  ].where((part) => part.trim().isNotEmpty).join(', ');
}

String customerAddressHeaderLabel(Map<String, dynamic>? address) {
  if (address == null) return 'Set your location';
  final place = [address.s('city'), address.s('state')]
      .where((part) => part.trim().isNotEmpty)
      .join(', ');
  if (place.isNotEmpty) return place;
  final label = address.s('label');
  return label.isNotEmpty ? label : formatCustomerAddress(address);
}

final customerAddressProvider =
    AsyncNotifierProvider<CustomerAddressController, CustomerAddressState>(
  CustomerAddressController.new,
);

class CustomerAddressController extends AsyncNotifier<CustomerAddressState> {
  CustomerRepository get _repository => ref.read(customerRepositoryProvider);

  Map<String, dynamic>? _addressById(
    CustomerAddressState current,
    String id,
  ) {
    for (final address in current.addresses) {
      if (address.s('id') == id) return address;
    }
    return null;
  }

  @override
  Future<CustomerAddressState> build() async {
    final customer = await ref.watch(customerAuthStateProvider.future);
    if (customer == null) return const CustomerAddressState();
    return _load(customer.id);
  }

  Future<CustomerAddressState> _load(
    String customerId, {
    String? preferredAddressId,
  }) async {
    final addresses = await _repository.customerAddresses(customerId);
    final persisted = preferredAddressId ?? await _repository.selectedAddressId();
    String? selectedId;
    if (persisted != null &&
        addresses.any((address) => address.s('id') == persisted)) {
      selectedId = persisted;
    } else {
      for (final address in addresses) {
        if (address.b('is_default')) {
          selectedId = address.s('id');
          break;
        }
      }
      if ((selectedId == null || selectedId.isEmpty) && addresses.isNotEmpty) {
        selectedId = addresses.first.s('id');
      }
    }
    await _repository.saveSelectedAddressId(selectedId);
    return CustomerAddressState(
      addresses: addresses,
      selectedAddressId: selectedId,
    );
  }

  Future<void> refresh() async {
    final customer = ref.read(customerAuthStateProvider).valueOrNull;
    if (customer == null) {
      state = const AsyncData(CustomerAddressState());
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _load(customer.id));
  }

  Future<Map<String, dynamic>> saveAddress(
    Map<String, dynamic> address,
  ) async {
    final customer = ref.read(customerAuthStateProvider).valueOrNull;
    if (customer == null) throw StateError('Login is required to save an address.');
    final previousId = address.s('id');
    final saved = await _repository.saveAddress(customer.id, address);
    final nextId = previousId.isEmpty ? saved.s('id') : state.valueOrNull?.selectedAddressId;
    state = AsyncData(await _load(customer.id, preferredAddressId: nextId));
    return saved;
  }

  Future<void> selectAddress(String id) async {
    final current = state.valueOrNull;
    if (current == null ||
        !current.addresses.any((address) => address.s('id') == id)) {
      return;
    }
    await _repository.saveSelectedAddressId(id);
    state = AsyncData(current.copyWith(selectedAddressId: id));
  }

  Future<void> setDefaultAddress(String id) async {
    final customer = ref.read(customerAuthStateProvider).valueOrNull;
    final current = state.valueOrNull;
    if (customer == null || current == null) return;
    final address = _addressById(current, id);
    if (address == null) return;
    await _repository.saveAddress(customer.id, {
      ...address,
      'id': id,
      'is_default': true,
    });
    state = AsyncData(await _load(customer.id, preferredAddressId: id));
  }

  Future<void> deleteAddress(String id) async {
    final customer = ref.read(customerAuthStateProvider).valueOrNull;
    final current = state.valueOrNull;
    if (customer == null || current == null) return;
    final removed = _addressById(current, id);
    await _repository.deleteAddress(id);
    var refreshed = await _load(
      customer.id,
      preferredAddressId: current.selectedAddressId == id
          ? null
          : current.selectedAddressId,
    );
    if (removed?.b('is_default') == true &&
        refreshed.addresses.isNotEmpty &&
        !refreshed.addresses.any((item) => item.b('is_default'))) {
      final replacement = refreshed.addresses.first;
      await _repository.saveAddress(customer.id, {
        ...replacement,
        'id': replacement.s('id'),
        'is_default': true,
      });
      refreshed = await _load(
        customer.id,
        preferredAddressId: refreshed.selectedAddressId,
      );
    }
    state = AsyncData(refreshed);
  }
}

final selectedLocationProvider = FutureProvider<String?>((ref) {
  final selected = ref.watch(customerAddressProvider).valueOrNull?.selectedAddress;
  final formatted = formatCustomerAddress(selected);
  if (formatted.isNotEmpty) return Future.value(formatted);
  return ref.watch(customerRepositoryProvider).selectedLocation();
});

final landingWalletProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return ref.watch(customerRepositoryProvider).rewardPoints('');
});