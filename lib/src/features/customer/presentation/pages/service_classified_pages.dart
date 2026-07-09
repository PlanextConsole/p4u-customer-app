import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  String _slot = '10:00 AM - 12:00 PM';
  final _address = TextEditingController();
  final _notes = TextEditingController();

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
                        if (picked != null) setState(() => _date = picked);
                      },
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: _slot,
                      decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.schedule_rounded),
                          hintText: 'Time Slot'),
                      items: const [
                        DropdownMenuItem(
                            value: '10:00 AM - 12:00 PM',
                            child: Text('10:00 AM - 12:00 PM')),
                        DropdownMenuItem(
                            value: '12:00 PM - 02:00 PM',
                            child: Text('12:00 PM - 02:00 PM')),
                        DropdownMenuItem(
                            value: '03:00 PM - 05:00 PM',
                            child: Text('03:00 PM - 05:00 PM')),
                      ],
                      onChanged: (value) =>
                          setState(() => _slot = value ?? _slot),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                        controller: _address,
                        minLines: 2,
                        maxLines: 3,
                        decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.location_on_rounded),
                            hintText: 'Service address')),
                    const SizedBox(height: 12),
                    TextField(
                        controller: _notes,
                        decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.notes_rounded),
                            hintText: 'Notes')),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: auth == null
                          ? () => context.go('/app/login')
                          : () async {
                              await ref
                                  .read(customerRepositoryProvider)
                                  .bookService(
                                      customerId: auth.id,
                                      service: service,
                                      date: _date,
                                      timeSlot: _slot,
                                      address: _address.text.trim(),
                                      notes: _notes.text.trim());
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('Service booking created')));
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
      bottomNavIndex: 5,
      actions: [
        IconButton(
            onPressed: () => context.go('/app/classifieds/post'),
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
                  onPressed: () {},
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
  final _category = TextEditingController();
  final _price = TextEditingController();
  final _location = TextEditingController();
  final _description = TextEditingController();

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
                TextField(
                    controller: _category,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.category_rounded),
                        hintText: 'Category')),
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
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () async {
                    await ref
                        .read(customerRepositoryProvider)
                        .createClassified(auth.id, {
                      'title': _title.text.trim(),
                      'category': _category.text.trim(),
                      'price': num.tryParse(_price.text.trim()) ?? 0,
                      'location': _location.text.trim(),
                      'description': _description.text.trim(),
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
