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

class PropertyHomePage extends ConsumerStatefulWidget {
  const PropertyHomePage({super.key});

  @override
  ConsumerState<PropertyHomePage> createState() => _PropertyHomePageState();
}

class _PropertyHomePageState extends ConsumerState<PropertyHomePage> {
  final _search = TextEditingController();
  String _type = '';
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(customerRepositoryProvider).properties();
  }

  void _load() {
    _future = ref
        .read(customerRepositoryProvider)
        .properties(transactionType: _type, search: _search.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return CustomerScaffold(
      title: 'Find Home',
      showBack: true,
      actions: [
        IconButton(
            onPressed: () => context.push('/app/find-home/post'),
            icon: const Icon(Icons.add_home_work_rounded))
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
                    hintText: 'Search city, locality, property',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(
                        onPressed: () => setState(_load),
                        icon: const Icon(Icons.arrow_forward_rounded)))),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                    label: const Text('All'),
                    selected: _type.isEmpty,
                    onSelected: (_) => setState(() {
                          _type = '';
                          _load();
                        })),
                ChoiceChip(
                    label: const Text('Buy'),
                    selected: _type == 'sale',
                    onSelected: (_) => setState(() {
                          _type = 'sale';
                          _load();
                        })),
                ChoiceChip(
                    label: const Text('Rent'),
                    selected: _type == 'rent',
                    onSelected: (_) => setState(() {
                          _type = 'rent';
                          _load();
                        })),
                ActionChip(
                    label: const Text('EMI'),
                    onPressed: () => context.push('/app/find-home/emi')),
                ActionChip(
                    label: const Text('Estimate'),
                    onPressed: () =>
                        context.push('/app/find-home/value-estimator')),
              ],
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
                final properties = snapshot.data ?? [];
                if (properties.isEmpty) {
                  return const EmptyState(
                      icon: Icons.apartment_rounded,
                      title: 'No properties found',
                      message: 'Try another location or filter.');
                }
                return Column(
                    children: properties
                        .map((property) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: PropertyTile(property: property)))
                        .toList());
              },
            ),
          ],
        ),
      ),
    );
  }
}

class PropertyDetailPage extends ConsumerWidget {
  const PropertyDetailPage({required this.id, super.key});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomerScaffold(
      title: 'Property',
      showBack: true,
      child: FutureBuilder<Map<String, dynamic>?>(
        future: ref.read(customerRepositoryProvider).property(id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final property = snapshot.data;
          if (property == null) {
            return const EmptyState(
                icon: Icons.apartment_rounded,
                title: 'Property not found',
                message: 'This listing is unavailable.');
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              RemoteImage(
                  url: property.s('image_url', property.s('cover_image')),
                  height: 250,
                  width: double.infinity,
                  borderRadius: 18),
              const SizedBox(height: 16),
              Text(property.s('title'),
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(money(property.n('price')),
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 24)),
              const SizedBox(height: 8),
              Text(
                  '${property.s('bhk')} BHK - ${property.s('area_sqft')} sqft - ${property.s('locality', property.s('city'))}',
                  style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 14),
              Text(property.s('description')),
              const SizedBox(height: 14),
              FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.message_rounded),
                  label: const Text('Contact Owner')),
            ],
          );
        },
      ),
    );
  }
}

class PostPropertyPage extends ConsumerStatefulWidget {
  const PostPropertyPage({super.key});

  @override
  ConsumerState<PostPropertyPage> createState() => _PostPropertyPageState();
}

class _PostPropertyPageState extends ConsumerState<PostPropertyPage> {
  final _title = TextEditingController();
  final _price = TextEditingController();
  final _city = TextEditingController();
  final _locality = TextEditingController();
  final _area = TextEditingController();
  final _description = TextEditingController();
  String _type = 'sale';

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(customerAuthStateProvider).valueOrNull;
    if (auth == null) return const LoginRequiredPage();
    return CustomerScaffold(
      title: 'Post Property',
      showBack: true,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Column(
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'sale', label: Text('Sale')),
                    ButtonSegment(value: 'rent', label: Text('Rent'))
                  ],
                  selected: {_type},
                  onSelectionChanged: (value) =>
                      setState(() => _type = value.first),
                ),
                const SizedBox(height: 12),
                TextField(
                    controller: _title,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.title_rounded),
                        hintText: 'Title')),
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
                    controller: _city,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.location_city_rounded),
                        hintText: 'City')),
                const SizedBox(height: 12),
                TextField(
                    controller: _locality,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.location_on_rounded),
                        hintText: 'Locality')),
                const SizedBox(height: 12),
                TextField(
                    controller: _area,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.square_foot_rounded),
                        hintText: 'Area sqft')),
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
                        .createProperty(auth.id, {
                      'title': _title.text.trim(),
                      'transaction_type': _type,
                      'price': num.tryParse(_price.text.trim()) ?? 0,
                      'city': _city.text.trim(),
                      'locality': _locality.text.trim(),
                      'area_sqft': int.tryParse(_area.text.trim()) ?? 0,
                      'description': _description.text.trim(),
                      'property_type': 'apartment',
                      'posted_by': 'owner',
                    });
                    if (context.mounted) context.go('/app/find-home');
                  },
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Submit Listing'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PropertyEMIPage extends StatefulWidget {
  const PropertyEMIPage({super.key});

  @override
  State<PropertyEMIPage> createState() => _PropertyEMIPageState();
}

class _PropertyEMIPageState extends State<PropertyEMIPage> {
  final _amount = TextEditingController(text: '5000000');
  final _rate = TextEditingController(text: '8.5');
  final _years = TextEditingController(text: '20');

  @override
  Widget build(BuildContext context) {
    final principal = num.tryParse(_amount.text) ?? 0;
    final rate = (num.tryParse(_rate.text) ?? 0) / 12 / 100;
    final months = (num.tryParse(_years.text) ?? 0) * 12;
    final emi = rate == 0 || months == 0
        ? 0
        : principal *
            rate *
            _pow(1 + rate, months) /
            (_pow(1 + rate, months) - 1);
    return CustomerScaffold(
      title: 'EMI Calculator',
      showBack: true,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Column(
              children: [
                TextField(
                    controller: _amount,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration:
                        const InputDecoration(labelText: 'Loan amount')),
                const SizedBox(height: 12),
                TextField(
                    controller: _rate,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration:
                        const InputDecoration(labelText: 'Interest rate')),
                const SizedBox(height: 12),
                TextField(
                    controller: _years,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration:
                        const InputDecoration(labelText: 'Tenure years')),
                const SizedBox(height: 18),
                Text(money(emi),
                    style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary)),
                const Text('Estimated monthly EMI'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  num _pow(num base, num exponent) {
    var result = 1.0;
    for (var i = 0; i < exponent; i++) {
      result *= base;
    }
    return result;
  }
}

class MyPropertiesPage extends ConsumerWidget {
  const MyPropertiesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(customerAuthStateProvider).valueOrNull;
    if (auth == null) return const LoginRequiredPage();
    return CustomerScaffold(
      title: 'My Properties',
      showBack: true,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: ref.read(customerRepositoryProvider).properties(),
        builder: (context, snapshot) {
          final rows = (snapshot.data ?? [])
              .where((p) => p.s('user_id') == auth.id)
              .toList();
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (rows.isEmpty) {
            return const EmptyState(
                icon: Icons.apartment_rounded,
                title: 'No property listings',
                message: 'Post your property to see it here.');
          }
          return ListView(
              padding: const EdgeInsets.all(16),
              children: rows
                  .map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: PropertyTile(property: p)))
                  .toList());
        },
      ),
    );
  }
}

class SavedSearchesPage extends ConsumerWidget {
  const SavedSearchesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(customerAuthStateProvider).valueOrNull;
    if (auth == null) return const LoginRequiredPage();
    return CustomerScaffold(
      title: 'Saved Searches',
      showBack: true,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: ref.read(customerRepositoryProvider).savedSearches(auth.id),
        builder: (context, snapshot) {
          final rows = snapshot.data ?? [];
          if (rows.isEmpty) {
            return const EmptyState(
                icon: Icons.bookmark_rounded,
                title: 'No saved searches',
                message: 'Saved property searches will appear here.');
          }
          return ListView(
              padding: const EdgeInsets.all(16),
              children: rows
                  .map((s) => AppCard(
                      child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(s.s('name', 'Saved search')),
                          subtitle: Text(s.s('query')),
                          trailing: StatusBadge(
                              s.b('notify') ? 'alerts on' : 'alerts off'))))
                  .toList());
        },
      ),
    );
  }
}

class PropertyMessagesPage extends ConsumerWidget {
  const PropertyMessagesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(customerAuthStateProvider).valueOrNull;
    if (auth == null) return const LoginRequiredPage();
    return CustomerScaffold(
      title: 'Property Messages',
      showBack: true,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: ref.read(customerRepositoryProvider).propertyMessages(auth.id),
        builder: (context, snapshot) {
          final rows = snapshot.data ?? [];
          if (rows.isEmpty) {
            return const EmptyState(
                icon: Icons.message_rounded,
                title: 'No messages',
                message: 'Property enquiries will appear here.');
          }
          return ListView(
              padding: const EdgeInsets.all(16),
              children: rows
                  .map((m) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(child: Text(m.s('message')))))
                  .toList());
        },
      ),
    );
  }
}

class RentTrackerPage extends ConsumerStatefulWidget {
  const RentTrackerPage({super.key});

  @override
  ConsumerState<RentTrackerPage> createState() => _RentTrackerPageState();
}

class _RentTrackerPageState extends ConsumerState<RentTrackerPage> {
  final _property = TextEditingController();
  final _rent = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(customerAuthStateProvider).valueOrNull;
    if (auth == null) return const LoginRequiredPage();
    return CustomerScaffold(
      title: 'Rent Tracker',
      showBack: true,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Column(children: [
              TextField(
                  controller: _property,
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.home_rounded),
                      hintText: 'Property name')),
              const SizedBox(height: 12),
              TextField(
                  controller: _rent,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.currency_rupee_rounded),
                      hintText: 'Monthly rent')),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  await ref
                      .read(customerRepositoryProvider)
                      .saveRentTracker(auth.id, {
                    'property_name': _property.text.trim(),
                    'monthly_rent': num.tryParse(_rent.text) ?? 0,
                    'paid_months': []
                  });
                  setState(() {});
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Tracker'),
              ),
            ]),
          ),
          const SectionHeader(title: 'Trackers'),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: ref.read(customerRepositoryProvider).rentTrackers(auth.id),
            builder: (context, snapshot) {
              final rows = snapshot.data ?? [];
              if (rows.isEmpty) {
                return const EmptyState(
                    icon: Icons.payments_rounded,
                    title: 'No trackers',
                    message: 'Track monthly rent payments here.');
              }
              return Column(
                  children: rows
                      .map((r) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppCard(
                              child: Row(children: [
                            Expanded(
                                child: Text(r.s('property_name'),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800))),
                            Text(money(r.n('monthly_rent')))
                          ]))))
                      .toList());
            },
          ),
        ],
      ),
    );
  }
}

class PropertyValueEstimatorPage extends ConsumerStatefulWidget {
  const PropertyValueEstimatorPage({super.key});

  @override
  ConsumerState<PropertyValueEstimatorPage> createState() =>
      _PropertyValueEstimatorPageState();
}

class _PropertyValueEstimatorPageState
    extends ConsumerState<PropertyValueEstimatorPage> {
  final _city = TextEditingController();
  String _propertyType = 'apartment';
  int _bhk = 2;
  Map<String, num>? _estimate;

  @override
  Widget build(BuildContext context) {
    return CustomerScaffold(
      title: 'Value Estimator',
      showBack: true,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _propertyType,
                  decoration: const InputDecoration(labelText: 'Property type'),
                  items: const [
                    DropdownMenuItem(
                        value: 'apartment', child: Text('Apartment')),
                    DropdownMenuItem(value: 'villa', child: Text('Villa')),
                    DropdownMenuItem(value: 'plot', child: Text('Plot'))
                  ],
                  onChanged: (v) =>
                      setState(() => _propertyType = v ?? _propertyType),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _bhk,
                  decoration: const InputDecoration(labelText: 'BHK'),
                  items: const [1, 2, 3, 4, 5]
                      .map((v) =>
                          DropdownMenuItem(value: v, child: Text('$v BHK')))
                      .toList(),
                  onChanged: (v) => setState(() => _bhk = v ?? _bhk),
                ),
                const SizedBox(height: 12),
                TextField(
                    controller: _city,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.location_city_rounded),
                        hintText: 'City')),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () async {
                    final result = await ref
                        .read(customerRepositoryProvider)
                        .estimatePropertyValue(
                            propertyType: _propertyType,
                            bhk: _bhk,
                            city: _city.text.trim());
                    setState(() => _estimate = result);
                  },
                  icon: const Icon(Icons.insights_rounded),
                  label: const Text('Estimate Value'),
                ),
              ],
            ),
          ),
          if (_estimate != null) ...[
            const SectionHeader(title: 'Estimated Range'),
            Row(
              children: [
                Expanded(child: _EstimateCard('Low', _estimate!['low'] ?? 0)),
                const SizedBox(width: 8),
                Expanded(
                    child:
                        _EstimateCard('Average', _estimate!['average'] ?? 0)),
                const SizedBox(width: 8),
                Expanded(child: _EstimateCard('High', _estimate!['high'] ?? 0)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EstimateCard extends StatelessWidget {
  const _EstimateCard(this.label, this.value);
  final String label;
  final num value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
        child: Column(children: [
      Text(label, style: const TextStyle(color: AppColors.muted)),
      Text(money(value),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              color: AppColors.primary, fontWeight: FontWeight.w900))
    ]));
  }
}
