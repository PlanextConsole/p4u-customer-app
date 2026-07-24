import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

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
  String _propertyType = '';
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(customerRepositoryProvider).properties();
  }

  void _load() {
    _future = ref.read(customerRepositoryProvider).properties(
          transactionType: _type,
          propertyType: _propertyType,
          search: _search.text.trim(),
        );
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
              runSpacing: 8,
              children: [
                ChoiceChip(
                    label: const Text('All',
                        style: TextStyle(
                            color: AppColors.brandDark,
                            fontWeight: FontWeight.w800)),
                    selected: _type.isEmpty,
                    labelStyle: const TextStyle(
                        color: AppColors.brandDark, fontWeight: FontWeight.w800),
                    onSelected: (_) => setState(() {
                          _type = '';
                          _load();
                        })),
                ChoiceChip(
                    label: const Text('Buy',
                        style: TextStyle(
                            color: AppColors.brandDark,
                            fontWeight: FontWeight.w800)),
                    selected: _type == 'sale',
                    labelStyle: const TextStyle(
                        color: AppColors.brandDark, fontWeight: FontWeight.w800),
                    onSelected: (_) => setState(() {
                          _type = 'sale';
                          _load();
                        })),
                ChoiceChip(
                    label: const Text('Rent',
                        style: TextStyle(
                            color: AppColors.brandDark,
                            fontWeight: FontWeight.w800)),
                    selected: _type == 'rent',
                    labelStyle: const TextStyle(
                        color: AppColors.brandDark, fontWeight: FontWeight.w800),
                    onSelected: (_) => setState(() {
                          _type = 'rent';
                          _load();
                        })),
                PopupMenuButton<String>(
                  tooltip: 'Property type',
                  initialValue: _propertyType,
                  onSelected: (value) => setState(() {
                    _propertyType = value;
                    _load();
                  }),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: '', child: Text('All property types')),
                    PopupMenuItem(value: 'Apartment', child: Text('Apartment')),
                    PopupMenuItem(value: 'House', child: Text('House')),
                    PopupMenuItem(value: 'Plot', child: Text('Plot')),
                    PopupMenuItem(
                        value: 'Commercial', child: Text('Commercial')),
                  ],
                  child: Chip(
                    avatar: const Icon(Icons.apartment_rounded,
                        size: 18, color: AppColors.primary),
                    label: Text(
                      _propertyType.isEmpty ? 'Property type' : _propertyType,
                      style: const TextStyle(
                        color: AppColors.brandDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                ActionChip(
                    label: const Text('Save search',
                        style: TextStyle(
                            color: AppColors.brandDark,
                            fontWeight: FontWeight.w800)),
                    onPressed: () async {
                      await ref
                          .read(customerRepositoryProvider)
                          .savePropertySearch({
                        'name': _search.text.trim().isEmpty
                            ? 'Property search'
                            : _search.text.trim(),
                        'query': {
                          'q': _search.text.trim(),
                          'type': _type,
                          'propertyType': _propertyType,
                        },
                        'notify': true
                      });
                      if (mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(content: Text('Search saved')));
                      }
                    }),
                ActionChip(
                    label: const Text('EMI',
                        style: TextStyle(
                            color: AppColors.brandDark,
                            fontWeight: FontWeight.w800)),
                    onPressed: () => context.push('/app/find-home/emi')),
                ActionChip(
                    label: const Text('Estimate',
                        style: TextStyle(
                            color: AppColors.brandDark,
                            fontWeight: FontWeight.w800)),
                    onPressed: () =>
                        context.push('/app/find-home/value-estimator')),
                ActionChip(
                    label: const Text('My properties',
                        style: TextStyle(
                            color: AppColors.brandDark,
                            fontWeight: FontWeight.w800)),
                    onPressed: () =>
                        context.push('/app/find-home/my-properties')),
                ActionChip(
                    label: const Text('Saved',
                        style: TextStyle(
                            color: AppColors.brandDark,
                            fontWeight: FontWeight.w800)),
                    onPressed: () =>
                        context.push('/app/find-home/saved-searches')),
                ActionChip(
                    label: const Text('Messages',
                        style: TextStyle(
                            color: AppColors.brandDark,
                            fontWeight: FontWeight.w800)),
                    onPressed: () => context.push('/app/find-home/messages')),
                ActionChip(
                    label: const Text('Rent tracker',
                        style: TextStyle(
                            color: AppColors.brandDark,
                            fontWeight: FontWeight.w800)),
                    onPressed: () =>
                        context.push('/app/find-home/rent-tracker')),
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
                if (snapshot.hasError) {
                  return EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Could not load properties',
                    message: snapshot.error.toString(),
                  );
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
          final images = property['images'];
          var cover = property.s('image_url', property.s('cover_image', property.s('coverImage')));
          if (cover.isEmpty && images is List && images.isNotEmpty) {
            final first = images.first;
            cover = first is String
                ? first.trim()
                : first is Map
                    ? (first['url'] ?? first['src'] ?? first['imageUrl'] ?? '').toString()
                    : '';
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              RemoteImage(
                  url: cover,
                  height: 250,
                  width: double.infinity,
                  borderRadius: 18),
              const SizedBox(height: 16),
              Text(property.s('title'),
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF334155),
                      )),
              const SizedBox(height: 8),
              Text(money(property.n('price')),
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 22)),
              const SizedBox(height: 8),
              Text(
                  '${property.s('bhk')} BHK - ${property.s('area_sqft')} sqft - ${property.s('locality', property.s('city'))}',
                  style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 14),
              Text(property.s('description')),
              const SizedBox(height: 14),
              FilledButton.icon(
                  onPressed: () async {
                    final controller = TextEditingController(
                        text: 'I am interested in this property');
                    final message = await showDialog<String>(
                        context: context,
                        builder: (_) => AlertDialog(
                                title: const Text('Contact owner'),
                                content: TextField(
                                    controller: controller,
                                    minLines: 2,
                                    maxLines: 4),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancel')),
                                  FilledButton(
                                      onPressed: () => Navigator.pop(
                                          context, controller.text.trim()),
                                      child: const Text('Send'))
                                ]));
                    controller.dispose();
                    if (message != null && message.isNotEmpty) {
                      await ref
                          .read(customerRepositoryProvider)
                          .inquireProperty(id, message);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Inquiry sent')));
                      }
                    }
                  },
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
  final _bhk = TextEditingController();
  final _description = TextEditingController();
  String _type = 'sale';
  String _propertyType = 'Apartment';
  bool _submitting = false;
  bool _uploadingImage = false;
  String? _imageUrl;
  String? _localPreviewPath;

  @override
  void dispose() {
    _title.dispose();
    _price.dispose();
    _city.dispose();
    _locality.dispose();
    _area.dispose();
    _bhk.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked =
        await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked == null) return;
    setState(() {
      _localPreviewPath = picked.path;
      _uploadingImage = true;
    });
    try {
      final url = await ref
          .read(customerRepositoryProvider)
          .uploadSocialFile(File(picked.path));
      if (!mounted) return;
      setState(() => _imageUrl = url);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _localPreviewPath = null;
        _imageUrl = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not upload photo. $error')),
      );
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _submit(String customerId) async {
    final title = _title.text.trim();
    final price = num.tryParse(_price.text.trim()) ?? 0;
    if (title.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Enter a title with at least 5 characters.')),
      );
      return;
    }
    if (price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid property price.')),
      );
      return;
    }
    if ((_imageUrl ?? '').trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a property photo.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(customerRepositoryProvider).createProperty(customerId, {
        'title': title,
        'transaction_type': _type,
        'price': price,
        'city': _city.text.trim(),
        'locality': _locality.text.trim(),
        'area_sqft': int.tryParse(_area.text.trim()) ?? 0,
        'bhk': int.tryParse(_bhk.text.trim()) ?? 0,
        'description': _description.text.trim(),
        'property_type': _propertyType,
        'posted_by': 'Owner',
        'images': [_imageUrl!.trim()],
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Property submitted for review.')),
      );
      context.go('/app/find-home');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit property. $error')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

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
                DropdownButtonFormField<String>(
                  initialValue: _propertyType,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.apartment_rounded),
                    labelText: 'Property type',
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'Apartment', child: Text('Apartment')),
                    DropdownMenuItem(value: 'House', child: Text('House')),
                    DropdownMenuItem(value: 'Plot', child: Text('Plot')),
                    DropdownMenuItem(
                        value: 'Commercial', child: Text('Commercial')),
                  ],
                  onChanged: (value) =>
                      setState(() => _propertyType = value ?? _propertyType),
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
                    controller: _bhk,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.bed_rounded), hintText: 'BHK')),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _uploadingImage ? null : _pickImage,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: double.infinity,
                    height: 180,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F4F8),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFD8E2EA)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _uploadingImage
                        ? const Center(child: CircularProgressIndicator())
                        : _localPreviewPath != null
                            ? Image.file(File(_localPreviewPath!),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 180)
                            : _imageUrl != null
                                ? RemoteImage(
                                    url: _imageUrl,
                                    height: 180,
                                    width: double.infinity,
                                    borderRadius: 14)
                                : const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_a_photo_rounded,
                                          color: AppColors.primary, size: 32),
                                      SizedBox(height: 8),
                                      Text('Upload property photo',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF334155))),
                                      SizedBox(height: 4),
                                      Text('Camera or gallery',
                                          style: TextStyle(
                                              color: Color(0xFF64748B),
                                              fontSize: 13)),
                                    ],
                                  ),
                  ),
                ),
                if (_imageUrl != null || _localPreviewPath != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _uploadingImage ? null : _pickImage,
                      icon: const Icon(Icons.sync_rounded),
                      label: const Text('Change photo'),
                    ),
                  ),
                ],
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
                  onPressed: (_submitting || _uploadingImage)
                      ? null
                      : () => _submit(auth.id),
                  icon: _submitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(_submitting ? 'Submitting...' : 'Submit Listing'),
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

class MyPropertiesPage extends ConsumerStatefulWidget {
  const MyPropertiesPage({super.key});

  @override
  ConsumerState<MyPropertiesPage> createState() => _MyPropertiesPageState();
}

class _MyPropertiesPageState extends ConsumerState<MyPropertiesPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(customerRepositoryProvider).myProperties();
  }

  void _reload() {
    setState(() {
      _future = ref.read(customerRepositoryProvider).myProperties();
    });
  }

  Future<void> _edit(Map<String, dynamic> property) async {
    final title = TextEditingController(text: property.s('title'));
    final price = TextEditingController(text: property.s('price'));
    final update = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit property'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 12),
            TextField(
              controller: price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Price'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, {
              'title': title.text.trim(),
              'price': num.tryParse(price.text.trim()) ?? 0,
            }),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    title.dispose();
    price.dispose();
    if (update == null) return;
    try {
      await ref
          .read(customerRepositoryProvider)
          .updateProperty(property.s('id'), update);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Property updated and submitted for review.')),
      );
      _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update property. $error')),
      );
    }
  }

  Future<void> _delete(Map<String, dynamic> property) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete property?'),
        content: Text('Delete "${property.s('title', 'this property')}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(customerRepositoryProvider)
          .deleteProperty(property.s('id'));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Property deleted.')),
      );
      _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete property. $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(customerAuthStateProvider).valueOrNull;
    if (auth == null) return const LoginRequiredPage();
    return CustomerScaffold(
      title: 'My Properties',
      showBack: true,
      actions: [
        IconButton(
          tooltip: 'Post property',
          onPressed: () => context.push('/app/find-home/post'),
          icon: const Icon(Icons.add_home_work_rounded),
        ),
      ],
      child: RefreshIndicator(
        onRefresh: () async {
          _reload();
          await _future;
        },
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  SizedBox(
                    height: 420,
                    child: EmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: 'Could not load properties',
                      message: snapshot.error.toString(),
                    ),
                  ),
                ],
              );
            }
            final rows = snapshot.data ?? [];
            if (rows.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(
                    height: 420,
                    child: EmptyState(
                      icon: Icons.apartment_rounded,
                      title: 'No property listings',
                      message: 'Post your property to see it here.',
                    ),
                  ),
                ],
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: rows
                  .map(
                    (property) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        children: [
                          PropertyTile(property: property),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (['pending', 'rejected']
                                  .contains(property.s('status')))
                                TextButton.icon(
                                  onPressed: () => _edit(property),
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('Edit'),
                                ),
                              TextButton.icon(
                                onPressed: () => _delete(property),
                                icon: const Icon(Icons.delete_outline_rounded),
                                label: const Text('Delete'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
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
