import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/map_ext.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/customer_scaffold.dart';
import '../../../../core/widgets/remote_image.dart';
import '../../../auth/data/auth_repository.dart';
import '../../data/customer_providers.dart';
import '../widgets/customer_tiles.dart';
import 'account_pages.dart';

class CustomerServicesPage extends ConsumerStatefulWidget {
  const CustomerServicesPage({super.key});

  @override
  ConsumerState<CustomerServicesPage> createState() =>
      _CustomerServicesPageState();
}

class _CustomerServicesPageState extends ConsumerState<CustomerServicesPage> {
  final _search = TextEditingController();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = Future.value([]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final query = GoRouterState.of(context).uri.queryParameters['search'];
    if (query != null && query != _search.text) {
      _search.text = query;
    }
    _load();
  }

  void _load() {
    _future = ref
        .read(customerRepositoryProvider)
        .services(search: _search.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return CustomerScaffold(
      title: 'Services',
      bottomNavIndex: 2,
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
                  hintText: 'Search services',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                      onPressed: () => setState(_load),
                      icon: const Icon(Icons.arrow_forward_rounded))),
            ),
            const SizedBox(height: 14),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                      height: 300,
                      child: Center(child: CircularProgressIndicator()));
                }
                final services = snapshot.data ?? [];
                if (services.isEmpty) {
                  return const EmptyState(
                      icon: Icons.home_repair_service_rounded,
                      title: 'No services found',
                      message: 'Try another search.');
                }
                return Column(
                    children: services
                        .map((service) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: ServiceTile(service: service)))
                        .toList());
              },
            ),
          ],
        ),
      ),
    );
  }
}

class CustomerServiceDetailPage extends ConsumerStatefulWidget {
  const CustomerServiceDetailPage({required this.id, super.key});
  final String id;

  @override
  ConsumerState<CustomerServiceDetailPage> createState() =>
      _CustomerServiceDetailPageState();
}

class _CustomerServiceDetailPageState
    extends ConsumerState<CustomerServiceDetailPage> {
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  String? _slot; // slot value sent to API
  String? _addressId;
  String? _vendorId;
  String? _vendorError;
  List<Map<String, String>> _slots = const []; // {label,value}
  List<Map<String, dynamic>> _addresses = const [];
  final _notes = TextEditingController();
  bool _loadingSlots = false;
  bool _bootstrapped = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _bootstrap(Map<String, dynamic> service) async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    final auth = ref.read(customerAuthStateProvider).valueOrNull;
    if (auth != null) {
      final rows =
          await ref.read(customerRepositoryProvider).customerAddresses(auth.id);
      if (mounted) {
        setState(() {
          _addresses = rows;
          if (_addressId == null && rows.isNotEmpty) {
            _addressId = rows.first.s('id', rows.first.s('addressId'));
          }
        });
      }
    }
    final vendorId = await ref
        .read(customerRepositoryProvider)
        .resolveVendorIdForService(service);
    if (!mounted) return;
    setState(() {
      _vendorId = vendorId;
      _vendorError = (vendorId == null || vendorId.isEmpty)
          ? 'This service is not linked to a provider yet.'
          : null;
    });
    await _loadSlots(service);
  }

  Future<void> _loadSlots(Map<String, dynamic> service) async {
    setState(() => _loadingSlots = true);
    try {
      final vendorId = _vendorId ??
          await ref
              .read(customerRepositoryProvider)
              .resolveVendorIdForService(service);
      if (vendorId == null || vendorId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _slots = const [];
          _slot = null;
          _vendorError = 'This service is not linked to a provider yet.';
        });
        return;
      }
      final date = _date.toIso8601String().split('T').first;
      final rows = await ref.read(customerRepositoryProvider).availableSlots(
            vendorId: vendorId,
            serviceId: service.s('id', service.s('serviceId')),
            date: date,
          );
      final slots = <Map<String, String>>[];
      for (final row in rows) {
        final value = row.s('value');
        final label = row.s('label', value);
        if (value.isEmpty) continue;
        slots.add({'label': label.isNotEmpty ? label : value, 'value': value});
      }
      if (!mounted) return;
      setState(() {
        _vendorId = vendorId;
        _vendorError = null;
        _slots = slots;
        if (_slot == null || !slots.any((s) => s['value'] == _slot)) {
          _slot = slots.isNotEmpty ? slots.first['value'] : null;
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _slots = const [];
          _slot = null;
          _vendorError = e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _loadingSlots = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(customerAuthStateProvider).valueOrNull;
    return CustomerScaffold(
      title: 'Service Detail',
      showBack: true,
      child: FutureBuilder<Map<String, dynamic>?>(
        future: ref.read(customerRepositoryProvider).service(widget.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final service = snapshot.data;
          if (service == null) {
            return const EmptyState(
                icon: Icons.home_repair_service_rounded,
                title: 'Service not found',
                message: 'This service is unavailable.');
          }
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _bootstrap(service));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              RemoteImage(
                  url: service.s('image'),
                  height: 230,
                  width: double.infinity,
                  borderRadius: 18),
              const SizedBox(height: 16),
              Text(service.s('title'),
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(service.s('description', service.s('short_description')),
                  style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 12),
              Text(money(service.n('price')),
                  style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                      fontSize: 24)),
              const SectionHeader(title: 'Book Service'),
              AppCard(
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_month_rounded),
                      title: Text(shortDate(_date.toIso8601String())),
                      trailing: const Icon(Icons.edit_calendar_rounded),
                      onTap: () async {
                        final picked = await showDatePicker(
                            context: context,
                            firstDate: DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 60)),
                            initialDate: _date);
                        if (picked != null) {
                          setState(() {
                            _date = picked;
                            _slot = null;
                            _slots = const [];
                          });
                          await _loadSlots(service);
                        }
                      },
                    ),
                    if (_loadingSlots)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: LinearProgressIndicator(),
                      )
                    else
                      DropdownButtonFormField<String>(
                        key: ValueKey(
                            'slot-${_slots.map((s) => s['value']).join('|')}'),
                        initialValue:
                            _slots.any((s) => s['value'] == _slot) ? _slot : null,
                        decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.schedule_rounded),
                            hintText: 'Time Slot'),
                        items: _slots
                            .map((s) => DropdownMenuItem(
                                  value: s['value'],
                                  child: Text(s['label'] ?? s['value'] ?? ''),
                                ))
                            .toList(),
                        onChanged: (value) => setState(() => _slot = value),
                      ),
                    if (_vendorError != null && !_loadingSlots)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(_vendorError!,
                            style: const TextStyle(color: Colors.red)),
                      )
                    else if (_slots.isEmpty && !_loadingSlots)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('No slots available for this date.',
                            style: TextStyle(color: AppColors.muted)),
                      ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey(
                          'addr-${_addresses.length}-$_addressId'),
                      initialValue: _addresses.any((a) =>
                              a.s('id', a.s('addressId')) == _addressId)
                          ? _addressId
                          : null,
                      decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.location_on_rounded),
                          hintText: 'Service address'),
                      items: _addresses
                          .map((a) => DropdownMenuItem(
                                value: a.s('id', a.s('addressId')),
                                child: Text(
                                  a.s(
                                      'label',
                                      a.s('addressLine1',
                                          a.s('line1', a.s('address')))),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: (value) => setState(() => _addressId = value),
                    ),
                    if (_addresses.isEmpty && auth != null)
                      TextButton(
                        onPressed: () => context.push('/app/profile'),
                        child: const Text('Add an address'),
                      ),
                    const SizedBox(height: 12),
                    TextField(
                        controller: _notes,
                        decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.notes_rounded),
                            hintText: 'Notes')),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: auth == null
                          ? () => context.push('/app/login')
                          : () async {
                              if ((_slot ?? '').isEmpty ||
                                  (_addressId ?? '').isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Select a time slot and address')));
                                return;
                              }
                              final addr = _addresses.firstWhere(
                                (a) =>
                                    a.s('id', a.s('addressId')) == _addressId,
                                orElse: () => <String, dynamic>{},
                              );
                              try {
                                await ref
                                    .read(customerRepositoryProvider)
                                    .bookService(
                                      customerId: auth.id,
                                      service: service,
                                      date: _date,
                                      timeSlot: _slot!,
                                      addressId: _addressId!,
                                      vendorId: _vendorId,
                                      addressLabel: addr.s(
                                          'label',
                                          addr.s('addressLine1',
                                              addr.s('address'))),
                                      notes: _notes.text.trim(),
                                    );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Service booking created')));
                                  context.push('/app/bookings');
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(e.toString())));
                                }
                              }
                            },
                      icon: const Icon(Icons.check_circle_rounded),
                      label: Text(auth == null ? 'Login to Book' : 'Book Now'),
                    ),
                  ],
                ),
              ),
              const SectionHeader(title: 'Reviews'),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: ref
                    .read(customerRepositoryProvider)
                    .serviceReviews(widget.id),
                builder: (context, reviews) {
                  final rows = reviews.data ?? [];
                  if (rows.isEmpty) {
                    return const Text('No reviews yet.',
                        style: TextStyle(color: AppColors.muted));
                  }
                  return Column(
                      children: rows
                          .map((r) => AppCard(
                              child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(r.s('customer_name', 'Customer')),
                                  subtitle: Text(r.s('review')),
                                  trailing: Text('${r.i('rating')} star'))))
                          .toList());
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class CustomerClassifiedsPage extends ConsumerStatefulWidget {
  const CustomerClassifiedsPage({super.key});

  @override
  ConsumerState<CustomerClassifiedsPage> createState() =>
      _CustomerClassifiedsPageState();
}

class _CustomerClassifiedsPageState
    extends ConsumerState<CustomerClassifiedsPage> {
  final _search = TextEditingController();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(customerRepositoryProvider).classifieds();
  }

  void _load() {
    _future = ref
        .read(customerRepositoryProvider)
        .classifieds(search: _search.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return CustomerScaffold(
      title: 'Classifieds',
      bottomNavIndex: 4,
      actions: [
        IconButton(
            onPressed: () => context.push('/app/classifieds/post'),
            icon: const Icon(Icons.add_rounded)),
      ],
      child: RefreshIndicator(
        onRefresh: () async => setState(_load),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
                controller: _search,
                onSubmitted: (_) => setState(_load),
                decoration: InputDecoration(
                    hintText: 'Search classifieds',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(
                        onPressed: () => setState(_load),
                        icon: const Icon(Icons.arrow_forward_rounded)))),
            const SizedBox(height: 14),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                      height: 300,
                      child: Center(child: CircularProgressIndicator()));
                }
                final ads = snapshot.data ?? [];
                if (ads.isEmpty) {
                  return const EmptyState(
                      icon: Icons.campaign_rounded,
                      title: 'No ads found',
                      message: 'Post the first classified ad.');
                }
                return Column(
                    children: ads
                        .map((ad) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: ClassifiedTile(ad: ad)))
                        .toList());
              },
            ),
          ],
        ),
      ),
    );
  }
}

class CustomerClassifiedDetailPage extends ConsumerWidget {
  const CustomerClassifiedDetailPage({required this.id, super.key});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomerScaffold(
      title: 'Classified',
      showBack: true,
      child: FutureBuilder<Map<String, dynamic>?>(
        future: ref.read(customerRepositoryProvider).classified(id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final ad = snapshot.data;
          if (ad == null) {
            return const EmptyState(
                icon: Icons.campaign_rounded,
                title: 'Ad not found',
                message: 'This ad is unavailable.');
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              RemoteImage(
                  url: ad.s('image_url', ad.s('image')),
                  height: 240,
                  width: double.infinity,
                  borderRadius: 18),
              const SizedBox(height: 16),
              Text(ad.s('title'),
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(ad.n('price') > 0 ? money(ad.n('price')) : ad.s('location'),
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 22,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Text(ad.s('description')),
              const SizedBox(height: 14),
              FilledButton.icon(
                  onPressed: () async {
                    final phone = ad
                        .s('contactPhone', ad.s('phone', ad.s('mobile')))
                        .replaceAll(RegExp(r'[^\d+]'), '');
                    if (phone.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Seller phone not available')));
                      return;
                    }
                    final digits = phone.replaceAll(RegExp(r'\D'), '');
                    final uri = Uri.parse('https://wa.me/$digits');
                    if (!await launchUrl(uri,
                        mode: LaunchMode.externalApplication)) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Could not open WhatsApp')));
                      }
                    }
                  },
                  icon: const Icon(Icons.call_rounded),
                  label: const Text('Contact Seller')),
            ],
          );
        },
      ),
    );
  }
}

class CustomerPostAdPage extends ConsumerStatefulWidget {
  const CustomerPostAdPage({super.key});

  @override
  ConsumerState<CustomerPostAdPage> createState() => _CustomerPostAdPageState();
}

class _CustomerPostAdPageState extends ConsumerState<CustomerPostAdPage> {
  final _title = TextEditingController();
  final _price = TextEditingController();
  final _location = TextEditingController();
  final _description = TextEditingController();
  final _phone = TextEditingController();
  String? _categoryId;
  List<Map<String, dynamic>> _categories = const [];
  final List<String> _imageUrls = [];
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final rows =
        await ref.read(customerRepositoryProvider).classifiedCategories();
    if (!mounted) return;
    setState(() {
      _categories = rows;
      if (_categoryId == null && rows.isNotEmpty) {
        _categoryId = rows.first.s('id');
      }
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _price.dispose();
    _location.dispose();
    _description.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;
    setState(() => _uploading = true);
    try {
      for (final file in picked) {
        final url = await ref
            .read(customerRepositoryProvider)
            .uploadSocialFile(File(file.path));
        if (url.isNotEmpty) _imageUrls.add(url);
      }
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(customerAuthStateProvider).valueOrNull;
    if (auth == null) return const LoginRequiredPage();
    return CustomerScaffold(
      title: 'Post Ad',
      showBack: true,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Column(
              children: [
                TextField(
                    controller: _title,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.title_rounded),
                        hintText: 'Title')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey('cat-${_categories.length}-$_categoryId'),
                  initialValue: _categories.any((c) => c.s('id') == _categoryId)
                      ? _categoryId
                      : null,
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.category_rounded),
                      hintText: 'Category'),
                  items: _categories
                      .map((c) => DropdownMenuItem(
                            value: c.s('id'),
                            child: Text(c.s('name', 'Category')),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _categoryId = v),
                ),
                const SizedBox(height: 12),
                TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.phone_rounded),
                        hintText: 'Contact phone')),
                const SizedBox(height: 12),
                TextField(
                    controller: _price,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.currency_rupee_rounded),
                        hintText: 'Price')),
                const SizedBox(height: 12),
                TextField(
                    controller: _location,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.location_on_rounded),
                        hintText: 'Location')),
                const SizedBox(height: 12),
                TextField(
                    controller: _description,
                    minLines: 4,
                    maxLines: 6,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.description_rounded),
                        hintText: 'Description')),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _uploading ? null : _pickImages,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(_uploading
                      ? 'Uploading...'
                      : 'Add photos (${_imageUrls.length})'),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () async {
                    if ((_categoryId ?? '').isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Select a category')));
                      return;
                    }
                    await ref
                        .read(customerRepositoryProvider)
                        .createClassified(auth.id, {
                      'title': _title.text.trim(),
                      'categoryId': _categoryId,
                      'price': num.tryParse(_price.text.trim()) ?? 0,
                      'location': _location.text.trim(),
                      'description': _description.text.trim(),
                      'contactPhone': _phone.text.trim(),
                      'imageUrls': _imageUrls,
                    });
                    if (context.mounted) context.go('/app/classifieds');
                  },
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Submit for Review'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
