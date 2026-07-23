import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/map_ext.dart';
import '../../../auth/data/auth_repository.dart';
import '../../data/customer_providers.dart';

class CustomerAddressHeader extends ConsumerWidget {
  const CustomerAddressHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addressState = ref.watch(customerAddressProvider);
    final selected = addressState.valueOrNull?.selectedAddress;
    final label = addressState.isLoading
        ? 'Loading address...'
        : customerAddressHeaderLabel(selected);
    return ColoredBox(
      color: AppColors.primary,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Material(
          color: Colors.white.withValues(alpha: .12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFF78D5B0)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => showCustomerAddressSelector(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    color: Color(0xFFFFDC3D),
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showCustomerAddressSelector(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => const _CustomerAddressSheet(),
  );
}

class _CustomerAddressSheet extends ConsumerWidget {
  const _CustomerAddressSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(customerAuthStateProvider).valueOrNull;
    final addressState = ref.watch(customerAddressProvider);
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .72,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Select Location',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFF7FAF9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.softGreen,
                    child: Icon(Icons.near_me_rounded, color: AppColors.primary),
                  ),
                  title: const Text(
                    'Use My Current Location',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text(
                    'Enable your current location for better services',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.push('/app/set-location');
                    },
                    child: const Text('Enable'),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Saved Address',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: addressState.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          error.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.danger),
                        ),
                        TextButton.icon(
                          onPressed: () => ref
                              .read(customerAddressProvider.notifier)
                              .refresh(),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                  data: (state) {
                    if (auth == null) {
                      return Center(
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            context.push('/app/login');
                          },
                          icon: const Icon(Icons.login_rounded),
                          label: const Text('Login to view saved addresses'),
                        ),
                      );
                    }
                    if (state.addresses.isEmpty) {
                      return const Center(
                        child: Text(
                          'No saved addresses yet.\nAdd one from Profile for faster checkout.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.muted),
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: state.addresses.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final address = state.addresses[index];
                        final id = address.s('id');
                        final selected = id == state.selectedAddressId;
                        return Material(
                          color: selected ? AppColors.softGreen : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.border,
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              await ref
                                  .read(customerAddressProvider.notifier)
                                  .selectAddress(id);
                              if (context.mounted) Navigator.of(context).pop();
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.brandDark,
                                          borderRadius: BorderRadius.circular(5),
                                        ),
                                        child: const Text(
                                          'P4U',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 7),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDDF8E8),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          address.s('label', 'Address'),
                                          style: const TextStyle(
                                            color: Color(0xFF187342),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      if (address.b('is_default')) ...[
                                        const SizedBox(width: 7),
                                        const Text(
                                          'DEFAULT',
                                          style: TextStyle(
                                            color: AppColors.primary,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                      const Spacer(),
                                      if (selected)
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          color: AppColors.primary,
                                          size: 19,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    formatCustomerAddress(address),
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 12,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              if (auth != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push('/app/profile/edit');
                  },
                  icon: const Icon(Icons.manage_accounts_rounded),
                  label: const Text('Manage saved addresses'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}