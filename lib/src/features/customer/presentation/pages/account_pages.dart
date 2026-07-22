import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/api_client.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/map_ext.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/customer_scaffold.dart';
import '../../../../core/widgets/remote_image.dart';
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
                    Builder(builder: (context) {
                      final meta = profile['metadata'];
                      final metaMap = meta is Map
                          ? Map<String, dynamic>.from(meta)
                          : <String, dynamic>{};
                      final avatar = (metaMap['avatarUrl'] ??
                              metaMap['avatar'] ??
                              profile.s('avatarUrl', profile.s('avatar')))
                          .toString();
                      if (avatar.isEmpty) {
                        return CircleAvatar(
                            radius: 34,
                            backgroundColor: AppColors.accent,
                            child: Text(
                                auth.name.isEmpty
                                    ? 'U'
                                    : auth.name.characters.first.toUpperCase(),
                                style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primary)));
                      }
                      return ClipOval(
                        child: RemoteImage(url: avatar, width: 68, height: 68),
                      );
                    }),
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
  Future<Map<String, dynamic>?>? _profileFuture;
  Future<List<Map<String, dynamic>>>? _addressesFuture;
  String? _loadedCustomerId;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _mobile = TextEditingController();
  final _bio = TextEditingController();
  final _label = TextEditingController(text: 'Home');
  final _recipient = TextEditingController();
  final _addressPhone = TextEditingController();
  final _line1 = TextEditingController();
  final _line2 = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _pincode = TextEditingController();
  String _dob = ''; // ISO yyyy-MM-dd
  String? _gender;
  String? _occupationId;
  String _occupationName = '';
  String _avatarUrl = '';
  List<Map<String, dynamic>> _occupations = [];
  bool _profileLoading = false;
  bool _addressLoading = false;
  bool _avatarUploading = false;
  bool _isDefaultAddress = false;
  bool _initialized = false;

  void _ensureDataFutures(String customerId) {
    if (_loadedCustomerId == customerId &&
        _profileFuture != null &&
        _addressesFuture != null) {
      return;
    }
    _loadedCustomerId = customerId;
    final repo = ref.read(customerRepositoryProvider);
    _profileFuture = repo.profile(customerId);
    _addressesFuture = repo.customerAddresses(customerId);
  }

  void _reloadProfile(String customerId) {
    _profileFuture = ref.read(customerRepositoryProvider).profile(customerId);
  }

  void _reloadAddresses(String customerId) {
    _addressesFuture =
        ref.read(customerRepositoryProvider).customerAddresses(customerId);
  }

  @override
  void initState() {
    super.initState();
    _loadOccupations();
  }

  Future<void> _loadOccupations() async {
    try {
      final list = await ref.read(customerRepositoryProvider).occupations();
      if (mounted) setState(() => _occupations = list);
    } catch (_) {
      // Occupations are optional — leave the dropdown empty on failure.
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _mobile.dispose();
    _bio.dispose();
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
    _ensureDataFutures(auth.id);
    return CustomerScaffold(
      title: 'Edit Profile',
      showBack: true,
      child: FutureBuilder<Map<String, dynamic>?>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !_initialized) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError && !_initialized) {
            return EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Profile unavailable',
              message: snapshot.error.toString(),
              action: FilledButton.icon(
                onPressed: () => setState(() {
                  _profileFuture =
                      ref.read(customerRepositoryProvider).profile(auth.id);
                }),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            );
          }
          final profile = snapshot.data;
          if (!_initialized &&
              snapshot.connectionState == ConnectionState.done) {
            _initialized = true;
            final p = profile ?? <String, dynamic>{};
            _name.text = p.s('name', p.s('fullName', auth.name));
            _email.text = p.s('email', auth.email);
            _mobile.text = _digits(p.s('phone', p.s('mobile', auth.mobile)));
            final meta = p['metadata'];
            final metaMap = meta is Map
                ? Map<String, dynamic>.from(meta)
                : <String, dynamic>{};
            _dob = _isoDate(p.s('dob', metaMap.s('dob')));
            final gender = p.s('gender', metaMap.s('gender'));
            _gender = _genders.contains(gender) ? gender : null;
            final occId = p.s('occupationId', p.s('occupation_id'));
            _occupationId = occId.isEmpty ? null : occId;
            _occupationName = metaMap['occupation']?.toString() ?? '';
            _bio.text = metaMap['bio']?.toString() ?? '';
            _avatarUrl = metaMap['avatarUrl']?.toString() ??
                metaMap['avatar']?.toString() ??
                p.s('avatarUrl', p.s('avatar'));
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
                    Center(
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              ClipOval(
                                child: SizedBox(
                                  width: 92,
                                  height: 92,
                                  child: _avatarUrl.isEmpty
                                      ? Container(
                                          color: AppColors.softGreen,
                                          child: const Icon(
                                              Icons.person_rounded,
                                              size: 44,
                                              color: AppColors.primary),
                                        )
                                      : RemoteImage(
                                          url: _avatarUrl,
                                          width: 92,
                                          height: 92),
                                ),
                              ),
                              Material(
                                color: AppColors.primary,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: _avatarUploading ? null : _pickAvatar,
                                  child: Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: _avatarUploading
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white))
                                        : const Icon(Icons.camera_alt_rounded,
                                            size: 16, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                              _avatarUploading
                                  ? 'Uploading...'
                                  : 'Change photo',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.muted)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
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
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _pickDob,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.cake_rounded),
                            labelText: 'Date of Birth'),
                        child: Text(
                          _dob.isEmpty ? 'Select date' : _prettyDate(_dob),
                          style: TextStyle(
                              color: _dob.isEmpty
                                  ? AppColors.muted
                                  : AppColors.brandDark),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _gender,
                      decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.wc_rounded),
                          labelText: 'Gender'),
                      items: _genders
                          .map(
                              (g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (v) => setState(() => _gender = v),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _occupations
                              .any((o) => o['id']?.toString() == _occupationId)
                          ? _occupationId
                          : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.work_rounded),
                          labelText: 'Occupation'),
                      items: _occupations
                          .map((o) => DropdownMenuItem(
                                value: o['id']?.toString(),
                                child: Text(o['name']?.toString() ?? '',
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() {
                        _occupationId = v;
                        _occupationName = _occupations
                                .firstWhere(
                                  (o) => o['id']?.toString() == v,
                                  orElse: () => const {},
                                )['name']
                                ?.toString() ??
                            '';
                      }),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                        controller: _bio,
                        minLines: 2,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.info_outline_rounded),
                            labelText: 'About',
                            hintText: 'A short bio',
                            alignLabelWithHint: true)),
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
                future: _addressesFuture,
                builder: (context, snapshot) {
                  final addresses = snapshot.data ?? [];
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(18),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return EmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: 'Addresses unavailable',
                      message: snapshot.error.toString(),
                      action: TextButton.icon(
                        onPressed: () => setState(() {
                          _reloadAddresses(auth.id);
                        }),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                      ),
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
        if (_dob.isNotEmpty) 'dob': _dob,
        if (_gender != null) 'gender': _gender,
        if (_occupationId != null) 'occupationId': _occupationId,
        if (_occupationName.isNotEmpty) 'occupation': _occupationName,
        if (_bio.text.trim().isNotEmpty) 'bio': _bio.text.trim(),
        if (_avatarUrl.isNotEmpty) 'avatar': _avatarUrl,
      });
      ref.invalidate(customerAuthStateProvider);
      if (mounted) setState(() => _reloadProfile(customerId));
      _snack('Profile updated');
    } catch (e) {
      _snack('Could not update profile. Please try again.');
    } finally {
      if (mounted) setState(() => _profileLoading = false);
    }
  }

  static const _genders = ['Male', 'Female', 'Other'];

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 82);
    if (picked == null) return;
    setState(() => _avatarUploading = true);
    try {
      final url = await ref
          .read(customerRepositoryProvider)
          .uploadAvatar(File(picked.path));
      if (url.isNotEmpty && mounted) setState(() => _avatarUrl = url);
    } catch (_) {
      _snack('Could not upload photo. Please try again.');
    } finally {
      if (mounted) setState(() => _avatarUploading = false);
    }
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    DateTime initial = DateTime(now.year - 20);
    final parsed = DateTime.tryParse(_dob);
    if (parsed != null) initial = parsed;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1920),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (picked != null) {
      setState(() => _dob =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
    }
  }

  /// Normalises any incoming date (ISO or with time) to `yyyy-MM-dd`.
  String _isoDate(String value) {
    if (value.isEmpty) return '';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return '';
    return '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
  }

  /// Displays `yyyy-MM-dd` as `dd-MM-yyyy` (matches the user web).
  String _prettyDate(String iso) {
    final parts = iso.split('-');
    if (parts.length != 3) return iso;
    return '${parts[2]}-${parts[1]}-${parts[0]}';
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
      setState(() => _reloadAddresses(customerId));
    } catch (e) {
      final message = e.toString().replaceFirst('ApiException: ', '').trim();
      _snack(message.isEmpty
          ? 'Could not save address. Please try again.'
          : 'Could not save address: $message');
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

class CustomerWalletPage extends ConsumerStatefulWidget {
  const CustomerWalletPage({super.key});

  @override
  ConsumerState<CustomerWalletPage> createState() => _CustomerWalletPageState();
}

class _CustomerWalletPageState extends ConsumerState<CustomerWalletPage> {
  Future<(Map<String, dynamic>, List<Map<String, dynamic>>)>? _future;
  String? _customerId;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(customerAuthStateProvider).valueOrNull;
    if (auth == null) return const LoginRequiredPage();
    if (_future == null || _customerId != auth.id) {
      _customerId = auth.id;
      _future = _load(auth.id);
    }
    return CustomerScaffold(
      title: 'Wallet',
      showBack: true,
      child: FutureBuilder<(Map<String, dynamic>, List<Map<String, dynamic>>)>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Could not load wallet',
              message: snapshot.error.toString(),
            );
          }
          final reward = snapshot.data?.$1 ?? {};
          final txns = snapshot.data?.$2 ?? [];
          final buckets = reward['buckets'] is List
              ? (reward['buckets'] as List)
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
                      const Text('Reward points',
                          style: TextStyle(color: AppColors.muted)),
                      const SizedBox(height: 4),
                      Text(
                          '${reward.n('displayAmount', reward.n('balance', reward.n('points'))).round()} pts',
                          style: const TextStyle(
                              fontSize: 34,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      Text(
                          'Earned ${reward.n('earned', reward.n('totalEarned')).round()} · Redeemed ${reward.n('redeemed', reward.n('totalRedeemed')).round()}',
                          style: const TextStyle(color: AppColors.muted)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: () => context.push('/app/payment'),
                              child: const Text('Redeem at checkout'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => context.push('/app/referrals'),
                              child: const Text('Refer & earn'),
                            ),
                          ),
                        ],
                      ),
                    ]),
              ),
              if (buckets.isNotEmpty) ...[
                const SectionHeader(title: 'Points by activity'),
                ...buckets.map((b) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        child: Row(
                          children: [
                            Expanded(
                                child: Text(b.s('label', b.s('type', 'Bucket')),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800))),
                            Text('${b.n('balance', b.n('points')).round()} pts',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                    )),
              ],
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

  Future<(Map<String, dynamic>, List<Map<String, dynamic>>)> _load(
      String id) async {
    final repo = ref.read(customerRepositoryProvider);
    Map<String, dynamic> reward = {};
    List<Map<String, dynamic>> txns = [];
    try {
      reward = await repo.rewardPoints(id);
    } catch (_) {}
    try {
      txns = await repo.walletTransactions(id);
    } catch (_) {
      txns = apiItems(reward['recentHistory']);
    }
    if (txns.isEmpty) {
      txns = apiItems(reward['recentHistory']);
    }
    return (reward, txns);
  }
}

class CustomerBookingsPage extends ConsumerStatefulWidget {
  const CustomerBookingsPage({super.key});

  @override
  ConsumerState<CustomerBookingsPage> createState() =>
      _CustomerBookingsPageState();
}

class _CustomerBookingsPageState extends ConsumerState<CustomerBookingsPage> {
  Future<List<Map<String, dynamic>>>? _future;
  String? _customerId;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(customerAuthStateProvider).valueOrNull;
    if (auth == null) return const LoginRequiredPage();
    if (_future == null || _customerId != auth.id) {
      _customerId = auth.id;
      _future = ref.read(customerRepositoryProvider).bookings(auth.id);
    }
    return CustomerScaffold(
      title: 'My Bookings',
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
              title: 'Could not load bookings',
              message: snapshot.error.toString(),
            );
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
              final canCancel = ['pending', 'approved', 'confirmed', 'in_progress']
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
                      if (status == 'completion_pending') ...[
                        const SizedBox(height: 12),
                        FilledButton.tonalIcon(
                            onPressed: () =>
                                _showCompletionOtp(booking.s('id')),
                            icon: const Icon(Icons.password_rounded),
                            label: const Text('Show completion OTP')),
                      ],
                      if (status == 'completion_pending_confirmation') ...[
                        const SizedBox(height: 12),
                        Wrap(spacing: 8, children: [
                          FilledButton.icon(
                              onPressed: () => _confirmService(booking.s('id')),
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Confirm service')),
                          OutlinedButton.icon(
                              onPressed: () => _disputeService(booking.s('id'),
                                  pending: true),
                              icon: const Icon(Icons.report_problem_outlined),
                              label: const Text('Dispute')),
                        ]),
                      ],
                      if (status == 'completed') ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                            onPressed: () => _disputeService(booking.s('id')),
                            icon: const Icon(Icons.report_problem_outlined),
                            label: const Text('Report issue')),
                      ],
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
                                setState(() {
                                  _future = ref
                                      .read(customerRepositoryProvider)
                                      .bookings(auth.id);
                                });
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

  void _refreshBookings() {
    final id = _customerId;
    if (id == null) return;
    setState(() => _future = ref.read(customerRepositoryProvider).bookings(id));
  }

  Future<void> _showCompletionOtp(String bookingId) async {
    try {
      final data = await ref
          .read(customerRepositoryProvider)
          .serviceCompletionOtp(bookingId);
      if (!mounted) return;
      await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
                  title: const Text('Completion OTP'),
                  content: SelectableText(data.s('otp'),
                      style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 8)),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'))
                  ]));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _confirmService(String bookingId) async {
    await ref
        .read(customerRepositoryProvider)
        .confirmServiceCompletion(bookingId, true);
    _refreshBookings();
  }

  Future<void> _disputeService(String bookingId, {bool pending = false}) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
                title: const Text('Report service issue'),
                content: TextField(
                    controller: controller,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: 'Reason')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () =>
                          Navigator.pop(context, controller.text.trim()),
                      child: const Text('Submit'))
                ]));
    controller.dispose();
    if (reason == null || reason.length < 5) return;
    if (pending) {
      await ref
          .read(customerRepositoryProvider)
          .confirmServiceCompletion(bookingId, false, reason: reason);
    } else {
      await ref
          .read(customerRepositoryProvider)
          .disputeService(bookingId, reason);
    }
    _refreshBookings();
  }
}

class CustomerWishlistPage extends ConsumerStatefulWidget {
  const CustomerWishlistPage({super.key});

  @override
  ConsumerState<CustomerWishlistPage> createState() =>
      _CustomerWishlistPageState();
}

class _CustomerWishlistPageState extends ConsumerState<CustomerWishlistPage> {
  Future<List<Map<String, dynamic>>>? _future;
  String? _customerId;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(customerAuthStateProvider).valueOrNull;
    if (auth == null) return const LoginRequiredPage();
    if (_future == null || _customerId != auth.id) {
      _customerId = auth.id;
      _future = ref.read(customerRepositoryProvider).wishlistProducts();
    }
    return CustomerScaffold(
      title: 'Wishlist',
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
              title: 'Could not load wishlist',
              message: snapshot.error.toString(),
            );
          }
          final products = snapshot.data ?? [];
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
      child: FutureBuilder<(String, List<Map<String, dynamic>>)>(
        future: _data(ref, auth.id),
        builder: (context, snapshot) {
          final code = snapshot.data?.$1 ?? '';
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
                        code.isEmpty ? '—' : code,
                        style: const TextStyle(
                            fontSize: 24,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: code.isEmpty
                                  ? null
                                  : () async {
                                      await Clipboard.setData(
                                          ClipboardData(text: code));
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                                content: Text('Code copied')));
                                      }
                                    },
                              icon: const Icon(Icons.copy_rounded),
                              label: const Text('Copy'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: code.isEmpty
                                  ? null
                                  : () async {
                                      final text =
                                          'Join Planext4u with my referral code $code and earn rewards!';
                                      final uri = Uri.parse(
                                          'https://wa.me/?text=${Uri.encodeComponent(text)}');
                                      await launchUrl(uri,
                                          mode: LaunchMode.externalApplication);
                                    },
                              icon: const Icon(Icons.share_rounded),
                              label: const Text('Share'),
                            ),
                          ),
                        ],
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

  Future<(String, List<Map<String, dynamic>>)> _data(
      WidgetRef ref, String id) async {
    final repo = ref.read(customerRepositoryProvider);
    final codeRow = await repo.myReferralCode();
    final code = (codeRow == null)
        ? ''
        : codeRow.s(
            'code', codeRow.s('referralCode', codeRow.s('referral_code')));
    final profile = await repo.profile(id) ?? {};
    final fallback = code.isNotEmpty
        ? code
        : profile.s(
            'referral_code', profile.s('referralCode', profile.s('code')));
    return (fallback, await repo.referrals(id));
  }
}

class CustomerKYCPage extends ConsumerStatefulWidget {
  const CustomerKYCPage({super.key});

  @override
  ConsumerState<CustomerKYCPage> createState() => _CustomerKYCPageState();
}

class _CustomerKYCPageState extends ConsumerState<CustomerKYCPage> {
  String _docType = 'aadhaar';
  final _docNumber = TextEditingController();
  String? _fileUrl;
  bool _loading = false;

  @override
  void dispose() {
    _docNumber.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() => _loading = true);
    try {
      final url = await ref
          .read(customerRepositoryProvider)
          .uploadSocialFile(File(picked.path));
      if (mounted) setState(() => _fileUrl = url);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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
                DropdownButtonFormField<String>(
                  initialValue: _docType,
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.badge_rounded),
                      labelText: 'Document type'),
                  items: const [
                    DropdownMenuItem(value: 'aadhaar', child: Text('Aadhaar')),
                    DropdownMenuItem(value: 'pan', child: Text('PAN')),
                  ],
                  onChanged: (v) => setState(() => _docType = v ?? 'aadhaar'),
                ),
                const SizedBox(height: 12),
                TextField(
                    controller: _docNumber,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.numbers_rounded),
                        hintText: 'Document number')),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _pickFile,
                  icon: const Icon(Icons.upload_file_rounded),
                  label: Text(_fileUrl == null
                      ? 'Upload document image'
                      : 'Document attached'),
                ),
                if (_fileUrl != null) ...[
                  const SizedBox(height: 8),
                  RemoteImage(
                      url: _fileUrl, height: 120, width: double.infinity),
                ],
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _loading
                      ? null
                      : () async {
                          setState(() => _loading = true);
                          await ref
                              .read(customerRepositoryProvider)
                              .submitKyc(auth.id, {
                            'document_type': _docType,
                            'document_number': _docNumber.text.trim(),
                            if (_fileUrl != null) 'url': _fileUrl,
                          });
                          if (mounted) setState(() => _loading = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('KYC submitted')));
                          }
                        },
                  icon: const Icon(Icons.verified_user_rounded),
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
                              child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(doc.s('document_type')),
                            subtitle: Text(doc.s(
                                'documentNumber', doc.s('document_number'))),
                            trailing: StatusBadge(doc.s('status', 'pending')),
                            onTap: doc.s('url').isEmpty
                                ? null
                                : () => launchUrl(Uri.parse(doc.s('url'))),
                          ))))
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

  Future<void> _openTicket(Map<String, dynamic> ticket) async {
    var detail = await ref.read(customerRepositoryProvider).supportTicket(ticket.s('id'));
    if (!mounted) return;
    final reply = TextEditingController();
    await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, update) {
      final messages = apiItems(detail['messages']);
      final terminal = ['closed', 'resolved'].contains(detail.s('status'));
      return AlertDialog(title: Text(detail.s('subject')), content: SizedBox(width: 480, child: Column(mainAxisSize: MainAxisSize.min, children: [
        Flexible(child: ListView(shrinkWrap: true, children: messages.map((m) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: m.s('sender_type') == 'admin' ? Colors.teal.shade50 : Colors.grey.shade100, borderRadius: BorderRadius.circular(10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(m.s('sender_type') == 'admin' ? 'Support' : 'You', style: const TextStyle(fontWeight: FontWeight.bold)), Text(m.s('message'))]))).toList())),
        if (!terminal) Row(children: [Expanded(child: TextField(controller: reply, decoration: const InputDecoration(hintText: 'Reply to support'))), IconButton(onPressed: () async { if (reply.text.trim().length < 2) return; detail = await ref.read(customerRepositoryProvider).sendSupportMessage(detail.s('id'), reply.text.trim()); reply.clear(); update(() {}); setState(() {}); }, icon: const Icon(Icons.send_rounded))])
      ])), actions: [if (!terminal) TextButton(onPressed: () async { detail = await ref.read(customerRepositoryProvider).closeSupportTicket(detail.s('id')); update(() {}); setState(() {}); }, child: const Text('Close ticket')), TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Done'))]);
    }));
  }
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
                              child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(ticket.s('subject'), style: const TextStyle(fontWeight: FontWeight.w800)),
                            subtitle: Text('${ticket.s('category')} · ${ticket.s('priority')}'),
                            trailing: StatusBadge(ticket.s('status', 'open')),
                            onTap: () => _openTicket(ticket),
                          ))))
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
