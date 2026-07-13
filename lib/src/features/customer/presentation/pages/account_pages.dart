import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/map_ext.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/customer_scaffold.dart';
import '../../../auth/data/auth_repository.dart';
import '../../data/customer_providers.dart';
import '../widgets/customer_tiles.dart';

class LoginRequiredPage extends StatelessWidget {
  const LoginRequiredPage({super.key});

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
            child: const Text('Login')),
      ),
    );
  }
}

class CustomerProfilePage extends ConsumerWidget {
  const CustomerProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(customerAuthStateProvider).valueOrNull;
    if (auth == null) return const LoginRequiredPage();
    return CustomerScaffold(
      title: 'Profile',
      showBack: true,
      child: FutureBuilder<Map<String, dynamic>>(
        future: ref.read(customerRepositoryProvider).profileWithStats(auth.id),
        builder: (context, snapshot) {
          final profile = snapshot.data ?? {};
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Row(
                  children: [
                    CircleAvatar(
                        radius: 34,
                        backgroundColor: AppColors.accent,
                        child: Text(
                            auth.name.isEmpty
                                ? 'U'
                                : auth.name.characters.first.toUpperCase(),
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary))),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                profile.s(
                                    'name', profile.s('fullName', auth.name)),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900, fontSize: 19)),
                            Text(profile.s('email', auth.email),
                                style: const TextStyle(color: AppColors.muted)),
                            Text(
                                profile.s(
                                    'mobile', profile.s('phone', auth.mobile)),
                                style: const TextStyle(color: AppColors.muted)),
                          ]),
                    ),
                    IconButton(
                        onPressed: () => context.push('/app/profile/edit'),
                        icon: const Icon(Icons.edit_rounded)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: _StatCard('Orders', profile.i('total_orders'))),
                  const SizedBox(width: 10),
                  Expanded(child: _StatCard('Ads', profile.i('total_ads'))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _StatCard('Points', profile.i('wallet_points'))),
                ],
              ),
              const SectionHeader(title: 'Account'),
              _MenuTile('Orders', Icons.receipt_long_rounded, '/app/orders'),
              _MenuTile(
                  'My Bookings', Icons.calendar_month_rounded, '/app/bookings'),
              _MenuTile('Wishlist', Icons.favorite_rounded, '/app/wishlist'),
              _MenuTile('Wallet & Points', Icons.account_balance_wallet_rounded,
                  '/app/wallet'),
              _MenuTile(
                  'Referrals', Icons.card_giftcard_rounded, '/app/referrals'),
              _MenuTile(
                  'KYC Verification', Icons.verified_user_rounded, '/app/kyc'),
              _MenuTile('Support', Icons.support_agent_rounded, '/app/support'),
              _MenuTile('Account Ownership & Control',
                  Icons.admin_panel_settings_rounded, '/app/account-control'),
              _MenuTile('Become a Seller', Icons.storefront_rounded,
                  '/app/vendor-register'),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(authRepositoryProvider).signOut();
                  ref.invalidate(customerAuthStateProvider);
                  if (context.mounted) context.go('/app');
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Logout'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class CustomerProfileEditPage extends ConsumerStatefulWidget {
  const CustomerProfileEditPage({super.key});

  @override
  ConsumerState<CustomerProfileEditPage> createState() =>
      _CustomerProfileEditPageState();
}

class _CustomerProfileEditPageState
    extends ConsumerState<CustomerProfileEditPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _mobile = TextEditingController();
  final _label = TextEditingController(text: 'Home');
  final _recipient = TextEditingController();
  final _addressPhone = TextEditingController();
  final _line1 = TextEditingController();
  final _line2 = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _pincode = TextEditingController();
  bool _profileLoading = false;
  bool _addressLoading = false;
  bool _isDefaultAddress = false;
  bool _initialized = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _mobile.dispose();
    _label.dispose();
    _recipient.dispose();
    _addressPhone.dispose();
    _line1.dispose();
    _line2.dispose();
    _city.dispose();
    _state.dispose();
    _pincode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(customerAuthStateProvider).valueOrNull;
    if (auth == null) return const LoginRequiredPage();
    return CustomerScaffold(
      title: 'Edit Profile',
      showBack: true,
      child: FutureBuilder<Map<String, dynamic>?>(
        future: ref.read(customerRepositoryProvider).profile(auth.id),
        builder: (context, snapshot) {
          final profile = snapshot.data;
          if (profile != null && !_initialized) {
            _initialized = true;
            _name.text = profile.s('name', profile.s('fullName', auth.name));
            _email.text = profile.s('email', auth.email);
            _mobile.text =
                _digits(profile.s('phone', profile.s('mobile', auth.mobile)));
            _recipient.text = _name.text;
            _addressPhone.text = _mobile.text;
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.person_rounded),
                            labelText: 'Full Name *',
                            hintText: 'Enter your name')),
                    const SizedBox(height: 12),
                    TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.mail_rounded),
                            labelText: 'Email *',
                            hintText: 'your@email.com')),
                    const SizedBox(height: 12),
                    TextField(
                        controller: _mobile,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.phone_rounded),
                            labelText: 'Mobile *',
                            hintText: '10-digit number',
                            counterText: '')),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.center,
                      child: FilledButton.icon(
                        onPressed: _profileLoading
                            ? null
                            : () => _saveProfile(auth.id),
                        icon: const Icon(Icons.save_rounded),
                        label: Text(
                            _profileLoading ? 'Saving...' : 'Save Profile'),
                      ),
                    ),
                  ],
                ),
              ),
              const SectionHeader(title: 'Saved Addresses'),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: ref
                    .read(customerRepositoryProvider)
                    .customerAddresses(auth.id),
                builder: (context, snapshot) {
                  final addresses = snapshot.data ?? [];
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(18),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (addresses.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: EmptyState(
                        icon: Icons.location_off_rounded,
                        title: 'No saved addresses',
                        message: 'Add one for faster checkout.',
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final address in addresses)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppCard(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.location_on_rounded,
                                    color: AppColors.primary),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              address.s('label', 'Home'),
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w900),
                                            ),
                                          ),
                                          if (address.b('is_default'))
                                            const StatusBadge('default'),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        [
                                          address.s('address_line'),
                                          address.s('line2'),
                                          address.s('city'),
                                          address.s('state'),
                                          address.s('pincode'),
                                        ]
                                            .where((v) => v.trim().isNotEmpty)
                                            .join(', '),
                                        style: const TextStyle(
                                            color: AppColors.muted),
                                      ),
                                      if (address.s('name').isNotEmpty ||
                                          address.s('mobile').isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          [
                                            address.s('name'),
                                            address.s('mobile')
                                          ]
                                              .where((v) => v.trim().isNotEmpty)
                                              .join(' - '),
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.muted),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                        controller: _label,
                        decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.label_rounded),
                            labelText: 'Address label',
                            hintText: 'Home, Office')),
                    const SizedBox(height: 12),
                    TextField(
                        controller: _recipient,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.person_pin_rounded),
                            labelText: 'Recipient full name *')),
                    const SizedBox(height: 12),
                    TextField(
                        controller: _addressPhone,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.phone_rounded),
                            labelText: 'Mobile number *',
                            counterText: '')),
                    const SizedBox(height: 12),
                    TextField(
                        controller: _line1,
                        decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.home_rounded),
                            labelText: 'Address line 1 *',
                            hintText: 'Flat, house no., street')),
                    const SizedBox(height: 12),
                    TextField(
                        controller: _line2,
                        decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.place_outlined),
                            labelText: 'Address line 2',
                            hintText: 'Area, landmark')),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                              controller: _city,
                              textCapitalization: TextCapitalization.words,
                              decoration:
                                  const InputDecoration(labelText: 'City *')),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                              controller: _state,
                              textCapitalization: TextCapitalization.words,
                              decoration:
                                  const InputDecoration(labelText: 'State *')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                        controller: _pincode,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.pin_drop_rounded),
                            labelText: 'PIN code *',
                            counterText: '')),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _isDefaultAddress,
                      onChanged: (value) =>
                          setState(() => _isDefaultAddress = value ?? false),
                      title: const Text('Set as default delivery address'),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: OutlinedButton.icon(
                        onPressed: _addressLoading
                            ? null
                            : () => _saveAddress(auth.id),
                        icon: const Icon(Icons.add_location_alt_rounded),
                        label: Text(
                            _addressLoading ? 'Saving...' : 'Save Address'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveProfile(String customerId) async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final phone = _digits(_mobile.text);
    if (name.isEmpty) return _snack('Full name is required');
    if (email.isEmpty || !RegExp(r'\S+@\S+\.\S+').hasMatch(email)) {
      return _snack('Enter a valid email address');
    }
    if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
      return _snack('Enter a valid 10-digit mobile number');
    }
    setState(() => _profileLoading = true);
    try {
      await ref.read(customerRepositoryProvider).updateProfile(customerId, {
        'name': name,
        'email': email,
        'phone': phone,
      });
      ref.invalidate(customerAuthStateProvider);
      _snack('Profile updated');
    } catch (e) {
      _snack('Could not update profile. Please try again.');
    } finally {
      if (mounted) setState(() => _profileLoading = false);
    }
  }

  Future<void> _saveAddress(String customerId) async {
    final phone = _digits(_addressPhone.text);
    if (_recipient.text.trim().isEmpty) {
      return _snack('Recipient name is required');
    }
    if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
      return _snack('Enter a valid 10-digit address phone number');
    }
    if (_line1.text.trim().isEmpty) {
      return _snack('Address line 1 is required');
    }
    if (_city.text.trim().isEmpty) {
      return _snack('City is required');
    }
    if (_state.text.trim().isEmpty) {
      return _snack('State is required');
    }
    if (!RegExp(r'^\d{6}$').hasMatch(_digits(_pincode.text))) {
      return _snack('Enter a valid 6-digit PIN code');
    }
    setState(() => _addressLoading = true);
    try {
      await ref.read(customerRepositoryProvider).saveAddress(customerId, {
        'label': _label.text.trim().isEmpty ? 'Home' : _label.text.trim(),
        'fullName': _recipient.text.trim(),
        'phone': phone,
        'line1': _line1.text.trim(),
        'line2': _line2.text.trim(),
        'city': _city.text.trim(),
        'state': _state.text.trim(),
        'pincode': _digits(_pincode.text),
        'country': 'India',
        'isDefault': _isDefaultAddress,
      });
      _line1.clear();
      _line2.clear();
      _city.clear();
      _state.clear();
      _pincode.clear();
      _isDefaultAddress = false;
      _snack('Address saved');
      setState(() {});
    } catch (e) {
      _snack('Could not save address. Please try again.');
    } finally {
      if (mounted) setState(() => _addressLoading = false);
    }
  }

  String _digits(String value) => value
      .replaceAll(RegExp(r'\D'), '')
      .replaceFirst(RegExp(r'^91(?=\d{10}$)'), '');

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class CustomerWalletPage extends ConsumerWidget {
  const CustomerWalletPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(customerAuthStateProvider).valueOrNull;
    if (auth == null) return const LoginRequiredPage();
    return CustomerScaffold(
      title: 'Wallet',
      showBack: true,
      child: FutureBuilder<(Map<String, dynamic>?, List<Map<String, dynamic>>)>(
        future: _data(ref, auth.id),
        builder: (context, snapshot) {
          final profile = snapshot.data?.$1 ?? {};
          final txns = snapshot.data?.$2 ?? [];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Wallet Points',
                          style: TextStyle(color: AppColors.muted)),
                      const SizedBox(height: 4),
                      Text(
                          '${profile.n('displayAmount', profile.n('balance', profile.n('wallet_points'))).round()} pts',
                          style: const TextStyle(
                              fontSize: 34,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w900)),
                    ]),
              ),
              const SectionHeader(title: 'Transactions'),
              if (txns.isEmpty)
                const EmptyState(
                    icon: Icons.account_balance_wallet_rounded,
                    title: 'No transactions',
                    message: 'Points activity will appear here.')
              else
                ...txns.map((txn) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        child: Row(
                          children: [
                            Icon(
                                txn.n('points') < 0
                                    ? Icons.remove_circle_rounded
                                    : Icons.add_circle_rounded,
                                color: txn.n('points') < 0
                                    ? AppColors.danger
                                    : AppColors.success),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(txn.s('description', txn.s('type')),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700))),
                            Text('${txn.n('points').round()} pts',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                    )),
            ],
          );
        },
      ),
    );
  }

  Future<(Map<String, dynamic>?, List<Map<String, dynamic>>)> _data(
      WidgetRef ref, String id) async {
    final repo = ref.read(customerRepositoryProvider);
    return (await repo.profile(id), await repo.walletTransactions(id));
  }
}

class CustomerBookingsPage extends ConsumerWidget {
  const CustomerBookingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(customerAuthStateProvider).valueOrNull;
    if (auth == null) return const LoginRequiredPage();
    return CustomerScaffold(
      title: 'My Bookings',
      showBack: true,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: ref.read(customerRepositoryProvider).bookings(auth.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final bookings = snapshot.data ?? [];
          if (bookings.isEmpty) {
            return const EmptyState(
              icon: Icons.calendar_month_rounded,
              title: 'No bookings yet',
              message: 'Your service bookings will appear here.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final booking = bookings[index];
              final status = booking.s('status', 'pending');
              final canCancel = !['cancelled', 'completed', 'rejected']
                  .contains(status.toLowerCase());
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.home_repair_service_rounded,
                              color: AppColors.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              booking.s('service_name', 'Service Booking'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900, fontSize: 16),
                            ),
                          ),
                          StatusBadge(status),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(booking.s('vendor_name'),
                          style: const TextStyle(color: AppColors.muted)),
                      const SizedBox(height: 6),
                      Text(
                        '${shortDate(booking.s('booking_date'))}  ${booking.s('time_slot')}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(money(booking.n('total_amount')),
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w900)),
                      if (canCancel) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await ref
                                  .read(customerRepositoryProvider)
                                  .cancelBooking(booking.s('id'));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Booking cancelled')));
                                context.go('/app/bookings');
                              }
                            },
                            icon: const Icon(Icons.cancel_outlined),
                            label: const Text('Cancel'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class CustomerWishlistPage extends ConsumerWidget {
  const CustomerWishlistPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(customerAuthStateProvider).valueOrNull;
    if (auth == null) return const LoginRequiredPage();
    return CustomerScaffold(
      title: 'Wishlist',
      showBack: true,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: ref.read(customerRepositoryProvider).wishlistProducts(),
        builder: (context, snapshot) {
          final products = snapshot.data ?? [];
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (products.isEmpty) {
            return const EmptyState(
                icon: Icons.favorite_rounded,
                title: 'Wishlist is empty',
                message: 'Save products you like for later.');
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: products.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: .68,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12),
            itemBuilder: (context, index) =>
                ProductTile(product: products[index]),
          );
        },
      ),
    );
  }
}

class CustomerReferralPage extends ConsumerWidget {
  const CustomerReferralPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(customerAuthStateProvider).valueOrNull;
    if (auth == null) return const LoginRequiredPage();
    return CustomerScaffold(
      title: 'Referrals',
      showBack: true,
      child: FutureBuilder<(Map<String, dynamic>?, List<Map<String, dynamic>>)>(
        future: _data(ref, auth.id),
        builder: (context, snapshot) {
          final profile = snapshot.data?.$1 ?? {};
          final referrals = snapshot.data?.$2 ?? [];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Your referral code',
                          style: TextStyle(color: AppColors.muted)),
                      const SizedBox(height: 8),
                      SelectableText(
                        profile.s('referral_code', profile.s('referralCode')),
                        style: const TextStyle(
                            fontSize: 24,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w900),
                      ),
                    ]),
              ),
              const SectionHeader(title: 'Referral Activity'),
              if (referrals.isEmpty)
                const EmptyState(
                    icon: Icons.card_giftcard_rounded,
                    title: 'No referrals yet',
                    message: 'Share your referral code with friends.')
              else
                ...referrals.map((referral) {
                  final name = referral.s(
                    'name',
                    referral.s('fullName', referral.s('customerName')),
                  );
                  final joinedAt =
                      referral.s('createdAt', referral.s('joinedAt'));
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      child: Row(
                        children: [
                          const Icon(Icons.person_add_alt_1_rounded,
                              color: AppColors.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name.isEmpty
                                      ? 'Referral ${referral.s('id').isEmpty ? '' : '#${referral.s('id')}'}'
                                      : name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900),
                                ),
                                if (joinedAt.isNotEmpty)
                                  Text(shortDate(joinedAt),
                                      style: const TextStyle(
                                          color: AppColors.muted)),
                              ],
                            ),
                          ),
                          StatusBadge(referral.s('status', 'joined')),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  Future<(Map<String, dynamic>?, List<Map<String, dynamic>>)> _data(
      WidgetRef ref, String id) async {
    final repo = ref.read(customerRepositoryProvider);
    return (await repo.profile(id), await repo.referrals(id));
  }
}

class CustomerKYCPage extends ConsumerStatefulWidget {
  const CustomerKYCPage({super.key});

  @override
  ConsumerState<CustomerKYCPage> createState() => _CustomerKYCPageState();
}

class _CustomerKYCPageState extends ConsumerState<CustomerKYCPage> {
  final _docType = TextEditingController(text: 'aadhaar');
  final _docNumber = TextEditingController();
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(customerAuthStateProvider).valueOrNull;
    if (auth == null) return const LoginRequiredPage();
    return CustomerScaffold(
      title: 'KYC Verification',
      showBack: true,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Column(
              children: [
                TextField(
                    controller: _docType,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.badge_rounded),
                        hintText: 'Document type')),
                const SizedBox(height: 12),
                TextField(
                    controller: _docNumber,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.numbers_rounded),
                        hintText: 'Document number')),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _loading
                      ? null
                      : () async {
                          setState(() => _loading = true);
                          await ref
                              .read(customerRepositoryProvider)
                              .submitKyc(auth.id, {
                            'document_type': _docType.text.trim(),
                            'document_number': _docNumber.text.trim(),
                          });
                          if (mounted) setState(() => _loading = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('KYC submitted')));
                          }
                        },
                  icon: const Icon(Icons.upload_file_rounded),
                  label: Text(_loading ? 'Submitting...' : 'Submit KYC'),
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'Submitted Documents'),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: ref.read(customerRepositoryProvider).kycDocuments(auth.id),
            builder: (context, snapshot) {
              final docs = snapshot.data ?? [];
              if (docs.isEmpty) {
                return const EmptyState(
                    icon: Icons.verified_user_rounded,
                    title: 'No documents',
                    message: 'Submit a document for verification.');
              }
              return Column(
                  children: docs
                      .map((doc) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppCard(
                              child: Row(children: [
                            Expanded(child: Text(doc.s('document_type'))),
                            StatusBadge(doc.s('status', 'pending'))
                          ]))))
                      .toList());
            },
          ),
        ],
      ),
    );
  }
}

class CustomerSupportPage extends ConsumerStatefulWidget {
  const CustomerSupportPage({super.key});

  @override
  ConsumerState<CustomerSupportPage> createState() =>
      _CustomerSupportPageState();
}

class _CustomerSupportPageState extends ConsumerState<CustomerSupportPage> {
  final _subject = TextEditingController();
  final _message = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(customerAuthStateProvider).valueOrNull;
    if (auth == null) return const LoginRequiredPage();
    return CustomerScaffold(
      title: 'Help & Support',
      showBack: true,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Column(
              children: [
                TextField(
                    controller: _subject,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.subject_rounded),
                        hintText: 'Subject')),
                const SizedBox(height: 12),
                TextField(
                    controller: _message,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.message_rounded),
                        hintText: 'Message')),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () async {
                    await ref
                        .read(customerRepositoryProvider)
                        .createSupportTicket(auth.id, {
                      'subject': _subject.text.trim(),
                      'message': _message.text.trim(),
                      'name': auth.name,
                      'email': auth.email,
                      'phone': auth.mobile
                    });
                    _subject.clear();
                    _message.clear();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Ticket created')));
                    }
                    setState(() {});
                  },
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Create Ticket'),
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'Your Tickets'),
          FutureBuilder<List<Map<String, dynamic>>>(
            future:
                ref.read(customerRepositoryProvider).supportTickets(auth.id),
            builder: (context, snapshot) {
              final tickets = snapshot.data ?? [];
              if (tickets.isEmpty) {
                return const EmptyState(
                    icon: Icons.support_agent_rounded,
                    title: 'No tickets',
                    message: 'Create a ticket when you need help.');
              }
              return Column(
                  children: tickets
                      .map((ticket) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppCard(
                              child: Row(children: [
                            Expanded(
                                child: Text(ticket.s('subject'),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800))),
                            StatusBadge(ticket.s('status', 'open'))
                          ]))))
                      .toList());
            },
          ),
        ],
      ),
    );
  }
}

class AccountControlPage extends ConsumerWidget {
  const AccountControlPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(customerAuthStateProvider).valueOrNull;
    if (auth == null) return const LoginRequiredPage();
    return CustomerScaffold(
      title: 'Account Control',
      showBack: true,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Account ownership and deletion',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 8),
              const Text(
                  'Request account deletion or sign out from this device. Admin review may be required before permanent deletion.'),
              const SizedBox(height: 14),
              FilledButton.icon(
                style:
                    FilledButton.styleFrom(backgroundColor: AppColors.danger),
                onPressed: () async {
                  await ref
                      .read(customerRepositoryProvider)
                      .accountDeletionRequest(auth.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Deletion request submitted')));
                  }
                },
                icon: const Icon(Icons.delete_forever_rounded),
                label: const Text('Request Deletion'),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class CustomerChangePasswordPage extends ConsumerWidget {
  const CustomerChangePasswordPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final password = TextEditingController();
    final confirm = TextEditingController();
    final auth = ref.watch(customerAuthStateProvider).valueOrNull;
    if (auth == null) return const LoginRequiredPage();
    return CustomerScaffold(
      title: 'Change Password',
      showBack: true,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Column(
              children: [
                TextField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.lock_rounded),
                        hintText: 'New password')),
                const SizedBox(height: 12),
                TextField(
                    controller: confirm,
                    obscureText: true,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.lock_outline_rounded),
                        hintText: 'Confirm password')),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () async {
                    if (password.text.length < 8 ||
                        password.text != confirm.text) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Check password and confirmation')));
                      return;
                    }
                    await ref
                        .read(authRepositoryProvider)
                        .updatePassword(password.text);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Password updated')));
                    }
                  },
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Save Password'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class VendorRegisterPage extends ConsumerStatefulWidget {
  const VendorRegisterPage({super.key});

  @override
  ConsumerState<VendorRegisterPage> createState() => _VendorRegisterPageState();
}

class _VendorRegisterPageState extends ConsumerState<VendorRegisterPage> {
  final _business = TextEditingController();
  final _category = TextEditingController();
  final _notes = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(customerAuthStateProvider).valueOrNull;
    if (auth == null) return const LoginRequiredPage();
    return CustomerScaffold(
      title: 'Become a Seller',
      showBack: true,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Column(
              children: [
                TextField(
                    controller: _business,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.storefront_rounded),
                        hintText: 'Business name')),
                const SizedBox(height: 12),
                TextField(
                    controller: _category,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.category_rounded),
                        hintText: 'Category')),
                const SizedBox(height: 12),
                TextField(
                    controller: _notes,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.notes_rounded),
                        hintText: 'Tell us about your business')),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'Vendor registration requires the vendor API flow from the collection.')));
                  },
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Submit Application'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.label, this.value);
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Text('$value',
              style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: AppColors.primary)),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile(this.label, this.icon, this.route);
  final String label;
  final IconData icon;
  final String route;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        onTap: () => context.push(route),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
                child: Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w800))),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
