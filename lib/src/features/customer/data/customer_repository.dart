import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/api_client.dart';
import '../../../core/utils/map_ext.dart';
import '../../../core/utils/media_url.dart';
import '../domain/customer_models.dart';
import 'customer_api.dart';

class CustomerRepository {
  CustomerRepository({ApiClient? api}) : _gateway = CustomerApi(api: api);

  final CustomerApi _gateway;
  static const _cartKey = 'p4u_customer_cart';
  static const _wishlistKey = 'p4u_customer_wishlist';
  static const _serviceWishlistKey = 'p4u_customer_service_wishlist';
  static const _locationKey = 'p4u_customer_location';
  static const _selectedAddressKey = 'p4u_selected_address_id';
  static const _recentProductsKey = 'p4u_customer_recent_products';
  static const _latitudeKey = 'p4u_customer_latitude';
  static const _longitudeKey = 'p4u_customer_longitude';

  Future<CustomerHomeData> getHome() async {
    Map<String, dynamic> content = <String, dynamic>{};
    try {
      content = await _gateway.homeContent();
    } catch (_) {
      // Catalogue data still produces a useful Home if CMS is temporarily down.
    }

    var banners = apiItems(content['banners']);
    if (banners.isEmpty) banners = await _gateway.banners(limit: 20);
    var storeBanners = apiItems(content['popups']);
    if (storeBanners.isEmpty) {
      storeBanners = await _gateway.popups(limit: 10);
    }

    final categories = await _gateway.categories(limit: 200, kind: 'product');
    final serviceCategories =
        await _gateway.categories(limit: 100, kind: 'service');
    final catalogueProducts =
        await _gateway.browseProducts(limit: 24, sort: 'latest');
    final catalogueServices = await _gateway.services(limit: 40);

    final products = catalogueProducts
        .map(_normalizeProduct)
        .where((row) => row.s('id').isNotEmpty)
        .toList();
    products.sort((a, b) {
      final featured =
          (b['isFeatured'] == true || b['is_featured'] == true ? 1 : 0)
              .compareTo(
                  a['isFeatured'] == true || a['is_featured'] == true ? 1 : 0);
      if (featured != 0) return featured;
      final orders = b
          .n('orderCount', b.n('order_count'))
          .compareTo(a.n('orderCount', a.n('order_count')));
      if (orders != 0) return orders;
      return b.n('rating').compareTo(a.n('rating'));
    });

    final trending = [...products]..sort((a, b) {
        final rating = b
            .n('rating', b.n('avgRating'))
            .compareTo(a.n('rating', a.n('avgRating')));
        if (rating != 0) return rating;
        return b
            .n('reviews', b.n('reviewCount'))
            .compareTo(a.n('reviews', a.n('reviewCount')));
      });
    final deals = products.where((row) {
      final original = row.n('originalPrice', row.n('original_price'));
      return row['isDealOfDay'] == true ||
          row['is_deal_of_day'] == true ||
          row.n('discount') > 0 ||
          (original > row.n('price') && row.n('price') > 0);
    }).toList();
    final recent = await _recentViewedProducts();

    return CustomerHomeData(
      banners: banners,
      categories: categories.map(_normalizeCategory).toList(),
      serviceCategories: serviceCategories.map(_normalizeCategory).toList(),
      products: products.take(20).toList(),
      trendingProducts: trending.take(12).toList(),
      dealProducts: deals.take(12).toList(),
      recentProducts: recent,
      services: catalogueServices
          .map(_normalizeService)
          .where((row) => row.s('id').isNotEmpty)
          .take(20)
          .toList(),
      storeBanners: storeBanners,
      brands: apiItems(content['brands']),
      classified:
          apiItems(content['classified']).map(_normalizeClassified).toList(),
      assets: _assetMap(content),
    );
  }

  Future<List<Map<String, dynamic>>> browseProducts(
      {String? category,
      String? subcategory,
      String? search,
      String? sort,
      int limit = 24,
      int offset = 0}) async {
    final q = search?.trim() ?? '';
    List<Map<String, dynamic>> rows;
    if (q.isNotEmpty) {
      // Catalog search returns mixed types; keep products only (web parity).
      final raw = await _gateway.searchCatalog(
          query: q, type: 'product', limit: limit, offset: offset);
      rows = raw
          .where((row) =>
              row.s('type', 'product').toLowerCase() == 'product' ||
              row['type'] == null)
          .toList();
    } else {
      rows = await _gateway.browseProducts(
          categoryId: category,
          subcategoryId: subcategory,
          limit: limit,
          offset: offset);
    }
    var products = rows.map(_normalizeProduct).toList();
    if (q.isNotEmpty &&
        ((category != null && category.isNotEmpty) ||
            (subcategory != null && subcategory.isNotEmpty))) {
      products = products.where((p) {
        final categoryMatches = category == null ||
            category.isEmpty ||
            p.s('category_id', p.s('categoryId')) == category;
        final subcategoryMatches = subcategory == null ||
            subcategory.isEmpty ||
            p.s('subcategory_id', p.s('subcategoryId')) == subcategory;
        return categoryMatches && subcategoryMatches;
      }).toList();
    }
    return _sortProducts(products, sort);
  }

  List<Map<String, dynamic>> _sortProducts(
      List<Map<String, dynamic>> products, String? sort) {
    final copy = [...products];
    switch (sort) {
      case 'price_low':
        copy.sort((a, b) => a.n('price').compareTo(b.n('price')));
      case 'price_high':
        copy.sort((a, b) => b.n('price').compareTo(a.n('price')));
      case 'rating':
        copy.sort((a, b) => b
            .n('rating', b.n('avgRating'))
            .compareTo(a.n('rating', a.n('avgRating'))));
      case 'latest':
      default:
        copy.sort((a, b) {
          final ad = DateTime.tryParse(a.s('created_at', a.s('createdAt'))) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final bd = DateTime.tryParse(b.s('created_at', b.s('createdAt'))) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return bd.compareTo(ad);
        });
    }
    return copy;
  }

  Future<Map<String, dynamic>?> product(String id) async {
    final data = await _gateway.product(id);
    final product = _normalizeProduct(data);
    await _rememberProduct(product);
    return product;
  }

  Future<List<Map<String, dynamic>>> productVariants(String productId) async {
    final product = await this.product(productId);
    final variants = product?['variants'];
    return variants is List ? apiItems(variants) : [];
  }

  Future<List<Map<String, dynamic>>> categories() async {
    return catalogCategories(kind: 'product');
  }

  Future<List<Map<String, dynamic>>> catalogCategories(
      {required String kind}) async {
    final rows = await _gateway.categories(limit: 200, kind: kind);
    return rows.map(_normalizeCategory).toList();
  }

  Future<List<Map<String, dynamic>>> categoryChildren(String categoryId,
      {required String kind}) async {
    final rows = await _gateway.categoryChildren(categoryId, kind: kind);
    return rows.map(_normalizeCategory).toList();
  }

  Future<String?> checkVendorPhoneUnique(String phone) async {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) return null;
    try {
      final data = await _gateway.vendorPhoneStatus('+91$digits');
      if (data['available'] == false) {
        return 'This mobile number is already registered as a vendor.';
      }
      final status = data.s('status').toLowerCase();
      if (['registered', 'pending', 'submitted', 'approved'].contains(status)) {
        return 'A vendor account or application with this phone number already exists.';
      }
    } catch (_) {
      // Submission remains authoritative if this optional check is unavailable.
    }
    return null;
  }

  Future<String?> checkVendorEmailUnique(String email) async => null;

  Future<String> uploadRegistrationFile(
      File file, String field, String contentType) async {
    final data = await _gateway.uploadVendorRegistrationFile(file, contentType);
    final url = data.s('url', data.s('fileUrl', data.s('path'))).trim();
    if (url.isEmpty) {
      throw const ApiException('The document upload did not return a URL.');
    }
    return resolveMediaUrl(url);
  }

  Future<void> submitVendorApplication(Map<String, dynamic> form) async {
    final kind = form.s('category', 'product').toLowerCase() == 'service'
        ? 'service'
        : 'product';
    final categoryOrService = form.s('subcategory').trim();
    final address = form.s('shop_address').trim();
    String normalizedPhone(String value) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      return digits.length == 10 ? '+91$digits' : value;
    }

    final accountNumber = form.s('bank_account_number').trim();
    final bankAccounts = accountNumber.isEmpty &&
            form.s('bank_holder_name').trim().isEmpty &&
            form.s('bank_ifsc').trim().isEmpty
        ? <Map<String, dynamic>>[]
        : <Map<String, dynamic>>[
            {
              'id': 'primary-${DateTime.now().millisecondsSinceEpoch}',
              'bankName': '',
              'accountHolderName': form.s('bank_holder_name').trim(),
              'accountNumber': accountNumber,
              'ifscCode': form.s('bank_ifsc').trim().toUpperCase(),
              'accountType': 'savings',
              'isPrimary': true,
            }
          ];

    String? optional(String key) {
      final value = form.s(key).trim();
      return value.isEmpty ? null : value;
    }

    await _gateway.submitVendorApplication({
      'vendorKind': kind,
      'vendorType': kind == 'service' ? 'SERVICE' : 'PRODUCT',
      'ownerName': form.s('name').trim(),
      'businessName': form.s('business_name').trim(),
      'email': optional('email'),
      'phone': normalizedPhone(form.s('phone')),
      'gst': optional('gst_number'),
      'pan': optional('pan_number'),
      'categoriesJson': kind == 'product' && categoryOrService.isNotEmpty
          ? [categoryOrService]
          : null,
      'servicesJson': kind == 'service' && categoryOrService.isNotEmpty
          ? [categoryOrService]
          : null,
      'addressJson': {
        'state': optional('state'),
        'stateName': optional('state'),
        'district': optional('district'),
        'areaLocality': address.isEmpty ? null : address,
        'address': address.isEmpty ? null : address,
        'secondaryPhone': form.s('secondary_phone').trim().isEmpty
            ? null
            : normalizedPhone(form.s('secondary_phone')),
        'facebook': optional('fb_link'),
        'instagram': optional('instagram_link'),
        'latitude': form['latitude'],
        'longitude': form['longitude'],
      },
      'documentsJson': {
        'storeLogo': optional('store_logo_url'),
        'gstCertificateFileName': optional('gst_certificate_url'),
        'gstCertificate': optional('gst_certificate_url'),
        'gstCertificateUrl': optional('gst_certificate_url'),
        'fssai': optional('fssai_url'),
        'panCardFileName': optional('pan_image_url'),
        'panImage': optional('pan_image_url'),
        'panCardUrl': optional('pan_image_url'),
        'aadhaarFront': optional('aadhaar_front_url'),
        'aadhaarBack': optional('aadhaar_back_url'),
        'aadhaarCardUrl': optional('aadhaar_front_url'),
      },
      'bankJson': {'version': 1, 'accounts': bankAccounts},
    });
  }

  Future<List<Map<String, dynamic>>> services(
      {String? category,
      String? subcategory,
      String? search,
      String? sort}) async {
    final q = search?.trim() ?? '';
    List<Map<String, dynamic>> rows;
    if (q.isNotEmpty) {
      final raw = await _gateway.searchCatalog(query: q, limit: 50);
      rows =
          raw.where((row) => row.s('type').toLowerCase() == 'service').toList();
    } else {
      rows = await _gateway.services(
          categoryId: category,
          subcategoryId: subcategory,
          query: null,
          limit: 200);
    }
    final normalized = rows.map(_normalizeService).toList();
    if (sort == 'low') {
      normalized.sort((a, b) => a.n('price').compareTo(b.n('price')));
    } else if (sort == 'high') {
      normalized.sort((a, b) => b.n('price').compareTo(a.n('price')));
    } else if (sort == 'newest') {
      normalized.sort((a, b) => (int.tryParse(b.s('id')) ?? 0)
          .compareTo(int.tryParse(a.s('id')) ?? 0));
    }
    return normalized;
  }

  Future<Set<String>> serviceWishlist() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_serviceWishlistKey);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    return decoded is List ? decoded.map((e) => e.toString()).toSet() : {};
  }

  Future<void> toggleServiceWishlist(String serviceId) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await serviceWishlist();
    if (!items.add(serviceId)) items.remove(serviceId);
    await prefs.setString(_serviceWishlistKey, jsonEncode(items.toList()));
  }

  Future<Map<String, dynamic>?> service(String id) async {
    final data = await _gateway.service(id);
    return _normalizeService(data);
  }

  Future<List<Map<String, dynamic>>> serviceReviews(String serviceId) async {
    if (!await apiSession.hasToken()) return [];
    return _gateway.reviews(targetType: 'service', targetId: serviceId);
  }

  Future<void> bookService({
    required String customerId,
    required Map<String, dynamic> service,
    required DateTime date,
    required String timeSlot,
    required String addressId,
    String? addressLabel,
    String? notes,
    String? vendorId,
  }) async {
    final resolvedVendor = (vendorId != null && vendorId.trim().isNotEmpty)
        ? vendorId.trim()
        : await resolveVendorIdForService(service);
    if (resolvedVendor == null || resolvedVendor.isEmpty) {
      throw const ApiException('This service is not linked to a provider yet.');
    }
    await _gateway.createServiceBooking(
      {
        'vendorId': resolvedVendor,
        'serviceId': service.s('id', service.s('serviceId')),
        'bookingDate': date.toIso8601String().split('T').first,
        'timeSlot': timeSlot,
        'addressId': addressId,
        if (addressLabel != null && addressLabel.isNotEmpty)
          'address': addressLabel,
        'notes': notes,
        'totalAmount': service.n('price').toStringAsFixed(2),
      },
    );
  }

  /// Same resolve order as user-web `resolveServiceVendor.ts`.
  Future<String?> resolveVendorIdForService(
      Map<String, dynamic> service) async {
    final explicit = service.s('vendor_id', service.s('vendorId')).trim();
    if (explicit.isNotEmpty) return explicit;
    final serviceId = service.s('id', service.s('serviceId'));
    if (serviceId.isEmpty) return null;
    try {
      final offers = await _gateway.serviceVendorOffers(serviceId);
      for (final offer in offers) {
        final vendor = offer['vendor'];
        if (vendor is Map) {
          final id = vendor['id']?.toString().trim() ?? '';
          if (id.isNotEmpty) return id;
        }
        final vid = offer.s('vendorId', offer.s('vendor_id'));
        if (vid.isNotEmpty) return vid;
      }
    } catch (_) {}
    return null;
  }

  Future<List<Map<String, dynamic>>> availableSlots({
    String? vendorId,
    String? serviceId,
    String? date,
  }) async {
    if (!await apiSession.hasToken()) return [];
    final v = vendorId?.trim() ?? '';
    if (v.isEmpty) return [];
    final rows = await _gateway.availableSlots(
        vendorId: v, serviceId: serviceId, date: date);
    // Keep only bookable slots; normalize label/value like web.
    return rows
        .where((row) => row['available'] != false)
        .map((row) {
          final value = row.s('value',
              row.s('timeSlot', row.s('slot', row.s('start', row.s('time')))));
          final label = row.s('label', value);
          return {
            ...row,
            'value': value,
            'label': label.isNotEmpty ? label : value,
          };
        })
        .where((row) => (row['value'] as String).isNotEmpty)
        .toList();
  }

  Future<Map<String, dynamic>?> vendor(String id) async {
    final data = await _gateway.vendor(id);
    return _normalizeVendor(data);
  }

  Future<List<Map<String, dynamic>>> vendorProducts(String id) async {
    final rows = await _gateway.vendorProducts(id, limit: 50);
    return rows.map(_normalizeProduct).toList();
  }

  Future<List<Map<String, dynamic>>> orders(String customerId) async {
    if (!await apiSession.hasToken()) return [];
    // Match web: list by JWT customer_id/sub (orders are created under that id).
    final jwtId = customerIdFromAccessToken(await apiSession.accessToken());
    final prefsId = await apiSession.customerId();
    final ids = <String>[
      if (jwtId != null && jwtId.isNotEmpty) jwtId,
      if (prefsId != null && prefsId.isNotEmpty) prefsId,
      if (customerId.isNotEmpty) customerId,
    ];
    final seen = <String>{};
    Object? lastError;
    for (final id in ids) {
      if (!seen.add(id)) continue;
      try {
        final rows = await _gateway.customerOrders(id);
        final normalized = rows.map(_normalizeOrder).toList();
        return await Future.wait(normalized.map(_hydrateOrder));
      } catch (e) {
        lastError = e;
      }
    }
    if (lastError != null) throw lastError;
    return [];
  }

  Future<List<Map<String, dynamic>>> bookings(String customerId) async {
    if (!await apiSession.hasToken()) return [];
    final rows = await _gateway.myBookings();
    return rows.map(_normalizeBooking).toList();
  }

  Future<Map<String, dynamic>> serviceCompletionOtp(String bookingId) =>
      _gateway.serviceCompletionOtp(bookingId);
  Future<void> confirmServiceCompletion(String bookingId, bool accept,
      {String? reason}) async {
    await _gateway.confirmServiceCompletion(bookingId, accept, reason: reason);
  }

  Future<void> disputeService(String bookingId, String reason) async {
    await _gateway.disputeService(bookingId, reason);
  }

  Future<void> cancelBooking(String bookingId) async {
    await _gateway.cancelBooking(bookingId);
  }

  Future<void> cancelOrder(String orderId) async {
    await _gateway.cancelOrder(orderId);
  }

  Future<Map<String, dynamic>> productTracking(String orderId) =>
      _gateway.productTracking(orderId);

  Future<void> confirmProductDelivery(String orderId) async {
    await _gateway.confirmProductDelivery(orderId);
  }

  Future<void> requestProductReturn(String orderId, String reason) async {
    await _gateway.requestProductReturn(orderId, reason);
  }

  Future<Map<String, dynamic>?> order(String id) async {
    final data = await _gateway.order(id);
    return _hydrateOrder(_normalizeOrder(data));
  }

  Future<Map<String, dynamic>?> profile(String customerId) async {
    if (!await apiSession.hasToken()) return null;
    final data = await _gateway.myProfile();
    final raw = apiObject(data['profile'] ??
            data['customer'] ??
            data['user'] ??
            data['data'] ??
            data) ??
        data;
    final profile = _normalizeProfile(raw);
    // Persist commerce customer id from JWT when missing (never clobber JWT with profile id).
    final jwtId = customerIdFromAccessToken(await apiSession.accessToken());
    if (jwtId != null && jwtId.isNotEmpty) {
      await apiSession.setCustomerId(jwtId);
    } else {
      final pid = profile.s('id', profile.s('customerId'));
      if (pid.isNotEmpty) {
        final prefsId = await apiSession.customerId();
        if (prefsId == null || prefsId.isEmpty) {
          await apiSession.setCustomerId(pid);
        }
      }
    }
    await apiSession.saveProfile(profile);
    return profile;
  }

  Future<Map<String, dynamic>> profileWithStats(String customerId) async {
    final customer = await profile(customerId) ?? {};
    var orderCount = 0;
    var addressCount = 0;
    var adsCount = 0;
    num points = 0;
    try {
      orderCount = (await orders(customerId)).length;
    } catch (_) {}
    try {
      addressCount = (await customerAddresses(customerId)).length;
    } catch (_) {}
    try {
      adsCount =
          0; // "my ads" API not wired; don't count public classified browse
    } catch (_) {}
    try {
      final reward = await rewardPoints(customerId);
      points =
          reward.n('displayAmount', reward.n('balance', reward.n('points')));
    } catch (_) {}
    if (points == 0) {
      try {
        final wallet = await _gateway.walletSummary();
        final walletObj = apiObject(wallet) ?? wallet;
        points = walletObj.n(
            'displayAmount', walletObj.n('balance', walletObj.n('points')));
      } catch (_) {}
    }
    return {
      ...customer,
      'total_orders': orderCount,
      'saved_addresses': addressCount,
      'total_ads': adsCount,
      'wallet_points': points.round(),
    };
  }

  Map<String, dynamic> _normalizeProfile(Map<String, dynamic> row) {
    final meta = row['metadata'] is Map
        ? Map<String, dynamic>.from(row['metadata'] as Map)
        : <String, dynamic>{};
    final name = row.s('fullName', row.s('name', row.s('displayName')));
    final phone = row.s('phone', row.s('mobile'));
    final dob = row.s('dob', meta.s('dob'));
    final gender = row.s('gender', meta.s('gender'));
    final avatar = meta.s(
        'avatarUrl', meta.s('avatar', row.s('avatarUrl', row.s('avatar'))));
    return {
      ...row,
      'id': row.s('id', row.s('customerId')),
      'name': name,
      'fullName': name,
      'email': row.s('email'),
      'phone': phone,
      'mobile': phone,
      'dob': dob,
      'gender': gender,
      'occupationId': row.s('occupationId', row.s('occupation_id')),
      'metadata': {
        ...meta,
        if (dob.isNotEmpty) 'dob': dob,
        if (gender.isNotEmpty) 'gender': gender,
        if (avatar.isNotEmpty) 'avatarUrl': resolveMediaUrl(avatar),
        if (avatar.isNotEmpty) 'avatar': resolveMediaUrl(avatar),
      },
      'avatarUrl': avatar.isEmpty ? '' : resolveMediaUrl(avatar),
      'avatar': avatar.isEmpty ? '' : resolveMediaUrl(avatar),
    };
  }

  Future<void> updateProfile(
      String customerId, Map<String, dynamic> data) async {
    final metadata = <String, dynamic>{};
    if (data['avatar'] != null ||
        data['avatar_url'] != null ||
        data['avatarUrl'] != null) {
      metadata['avatarUrl'] =
          data['avatar'] ?? data['avatar_url'] ?? data['avatarUrl'];
      metadata['avatar'] =
          data['avatar'] ?? data['avatar_url'] ?? data['avatarUrl'];
    }
    if (data['bio'] != null) metadata['bio'] = data['bio'];
    if (data['occupation'] != null) metadata['occupation'] = data['occupation'];
    if (data['kycDocuments'] != null) {
      metadata['kycDocuments'] = data['kycDocuments'];
    }
    final payload = {
      if (data['name'] != null) 'fullName': data['name'],
      if (data['fullName'] != null) 'fullName': data['fullName'],
      if (data['email'] != null) 'email': data['email'],
      if (data['phone'] != null) 'phone': data['phone'],
      if (data['mobile'] != null) 'phone': data['mobile'],
      if (data['dob'] != null) 'dob': data['dob'],
      if (data['gender'] != null) 'gender': data['gender'],
      if (data['occupationId'] != null) 'occupationId': data['occupationId'],
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
    final updated = await _gateway.updateMyProfile(payload);
    await apiSession.saveProfile(apiObject(updated) ?? updated);
  }

  /// Public occupation options for the profile form (same source as user web:
  /// GET /api/auth/public/occupations?purpose=all).
  Future<List<Map<String, dynamic>>> occupations() async {
    final rows = await _gateway.occupations(purpose: 'all');
    return rows
        .map((row) => {
              'id': row.s('id'),
              'name': row.s('name'),
            })
        .where((row) => (row['id'] as String).isNotEmpty)
        .toList();
  }

  /// Uploads a profile photo and returns an absolute URL (same upload endpoint
  /// the web uses for avatars: POST /api/v1/social/upload).
  Future<String> uploadAvatar(File file) async {
    final data = await _gateway.uploadSocialMedia(file);
    final raw = data.s(
        'url',
        data.s('fileUrl',
            data.s('file_url', data.s('path', data.s('publicUrl')))));
    if (raw.isEmpty) return '';
    if (raw.startsWith('http') || raw.startsWith('assets/')) return raw;
    final normalized = raw.startsWith('/') ? raw : '/$raw';
    return '${ApiClient.baseUrl}$normalized';
  }

  Future<List<Map<String, dynamic>>> customerAddresses(
      String customerId) async {
    if (!await apiSession.hasToken()) return [];
    final rows = await _gateway.addresses();
    return rows.map(_normalizeAddress).toList();
  }

  Future<Map<String, dynamic>> saveAddress(
      String customerId, Map<String, dynamic> address) async {
    final payload = _addressPayload(address);
    final id = address['id']?.toString();
    final saved = id == null || id.isEmpty
        ? await _gateway.createAddress(payload)
        : await _gateway.updateAddress(id, payload);
    return _normalizeAddress(saved);
  }

  Future<void> deleteAddress(String id) async {
    await _gateway.deleteAddress(id);
  }

  Future<String?> selectedAddressId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedAddressKey);
  }

  Future<void> saveSelectedAddressId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null || id.isEmpty) {
      await prefs.remove(_selectedAddressKey);
    } else {
      await prefs.setString(_selectedAddressKey, id);
    }
  }

  Future<List<Map<String, dynamic>>> walletTransactions(
      String customerId) async {
    if (!await apiSession.hasToken()) return [];
    List<Map<String, dynamic>> history = [];
    // Web: prefer GET /me/wallet recentTransactions, fall back to reward-points.
    try {
      final wallet = await _gateway.walletSummary();
      history = apiItems(wallet['recentTransactions'] ??
          wallet['recentHistory'] ??
          wallet['transactions'] ??
          wallet['items']);
    } catch (_) {}
    if (history.isEmpty) {
      try {
        final reward = await _gateway.rewardPoints();
        history = apiItems(reward['recentHistory'] ??
            reward['history'] ??
            reward['recentTransactions'] ??
            reward['transactions']);
      } catch (_) {}
    }
    return history.where((row) => !_isPointsReversal(row)).toList();
  }

  Future<Map<String, dynamic>> rewardPoints(String customerId) async {
    if (!await apiSession.hasToken()) return {};
    Map<String, dynamic> data = {};
    try {
      data = await _gateway.rewardPoints();
    } catch (_) {}

    // Web wallet page overlays displayAmount from GET /me/wallet when available.
    Map<String, dynamic>? wallet;
    try {
      wallet = await _gateway.walletSummary();
    } catch (_) {}

    var history = apiItems((wallet != null
            ? (wallet['recentTransactions'] ??
                wallet['recentHistory'] ??
                wallet['transactions'])
            : null) ??
        data['recentHistory'] ??
        data['history']);
    history = history.where((row) => !_isPointsReversal(row)).toList();

    // Prefer live reward-points balance; wallet summary may report cash 0
    // while points still exist (match web home fallback behavior).
    final rewardBalance =
        data.n('balance', data.n('displayAmount', data.n('points')));
    final walletBalance = wallet == null
        ? 0
        : wallet.n('displayAmount', wallet.n('balance', wallet.n('points')));
    final balance = walletBalance > 0 ? walletBalance : rewardBalance;

    num earned = 0;
    num redeemed = 0;
    for (final row in history) {
      final pts = row.n('points', row.n('amount'));
      if (pts > 0) {
        earned += pts;
      } else if (pts < 0) {
        redeemed += pts.abs();
      }
    }

    // Match web bucket cards (positive earns by type only).
    const bucketDefs = [
      ('Welcome Bonus', 'welcome_bonus'),
      ('Post Share', 'post_share'),
      ('Vendor Referral', 'referral_bonus'),
      ('Customer Referral', 'customer_referral'),
      ('Post Liked', 'post_like'),
      ('Story Liked', 'story_like'),
    ];
    final buckets = bucketDefs.map((def) {
      final type = def.$2;
      num pts = 0;
      for (final row in history) {
        if (row.s('type').toLowerCase() == type &&
            row.n('points', row.n('amount')) > 0) {
          pts += row.n('points', row.n('amount'));
        }
      }
      return {'label': def.$1, 'type': type, 'points': pts, 'balance': pts};
    }).toList();

    return {
      ...data,
      if (wallet != null) ...wallet,
      'points': balance,
      'balance': balance,
      'displayAmount': balance,
      'earned': earned,
      'totalEarned': earned,
      'redeemed': redeemed,
      'totalRedeemed': redeemed,
      'recentHistory': history,
      'buckets': buckets,
    };
  }

  bool _isPointsReversal(Map<String, dynamic> row) {
    final type = row.s('type').toLowerCase();
    final desc = row.s('description', row.s('reason')).toLowerCase();
    return type.contains('reversal') || desc.contains('reversal');
  }

  Future<List<Map<String, dynamic>>> referrals(String customerId) async {
    if (!await apiSession.hasToken()) return [];
    final data = await _gateway.referralInfo();
    return apiItems(data['referrals'] ?? data['items'] ?? data);
  }

  Future<List<Map<String, dynamic>>> kycDocuments(String customerId) async {
    final profile = await this.profile(customerId) ?? {};
    final meta = _metadataOf(profile);
    final docs =
        apiObject(meta['kycDocuments'] ?? profile['kycDocuments']) ?? {};
    return docs.entries.map((entry) {
      final value = entry.value is Map
          ? Map<String, dynamic>.from(entry.value as Map)
          : <String, dynamic>{};
      return {
        ...value,
        'document_type': entry.key.toString(),
        'status': value.s('status', 'submitted'),
      };
    }).toList();
  }

  Future<void> submitKyc(
      String customerId, Map<String, dynamic> payload) async {
    final type = payload
            .s('document_type', payload.s('documentType', 'aadhaar'))
            .trim()
            .isEmpty
        ? 'aadhaar'
        : payload
            .s('document_type', payload.s('documentType', 'aadhaar'))
            .trim();
    final current = await profile(customerId) ?? {};
    final meta = _metadataOf(current);
    final docs =
        apiObject(meta['kycDocuments'] ?? current['kycDocuments']) ?? {};
    docs[type] = {
      ...(docs[type] is Map
          ? Map<String, dynamic>.from(docs[type] as Map)
          : <String, dynamic>{}),
      'documentNumber':
          payload.s('document_number', payload.s('documentNumber')),
      if (payload.s('url', payload.s('fileUrl')).isNotEmpty)
        'url': payload.s('url', payload.s('fileUrl')),
      'status': 'submitted',
      'submittedAt': DateTime.now().toIso8601String(),
    };
    await _updateProfileMetadata(customerId, {'kycDocuments': docs});
  }

  Future<List<Map<String, dynamic>>> classifieds(
      {String? category, String? search}) async {
    final rows = await _gateway.classifiedContent(
        categoryId: category, query: search, limit: 50);
    return rows.map(_normalizeClassified).toList();
  }

  Future<List<Map<String, dynamic>>> classifiedCategories() async {
    final rows = await _gateway.classifiedCategories();
    return rows.map(_normalizeCategory).toList();
  }

  Future<Map<String, dynamic>?> classified(String id) async {
    final data = await _gateway.classifiedItem(id);
    return _normalizeClassified(data);
  }

  Future<void> createClassified(
      String customerId, Map<String, dynamic> data) async {
    await _gateway.createClassified({
      'name': data.s('title', data.s('name')),
      'description': data.s('description'),
      'price': data['price'],
      'categoryId': data.s('categoryId', data.s('category')),
      'city': data.s('city', data.s('location')),
      'area': data.s('area'),
      'contactPhone': data.s('contactPhone', data.s('phone')),
      'imageUrls': data['imageUrls'] ?? data['image_urls'] ?? [],
    });
  }

  Future<List<Map<String, dynamic>>> supportTickets(String customerId) =>
      _gateway.supportTickets();

  Future<void> createSupportTicket(
      String customerId, Map<String, dynamic> data) async {
    await _gateway.createSupportTicket(data);
  }

  Future<Map<String, dynamic>> supportTicket(String id) =>
      _gateway.supportTicket(id);
  Future<Map<String, dynamic>> sendSupportMessage(String id, String message) =>
      _gateway.sendSupportMessage(id, message);
  Future<Map<String, dynamic>> closeSupportTicket(String id) =>
      _gateway.closeSupportTicket(id);
  Future<List<Map<String, dynamic>>> properties(
          {String? transactionType, String? propertyType, String? search}) =>
      _gateway.properties(
          query: search, type: transactionType, propertyType: propertyType);
  Future<Map<String, dynamic>?> property(String id) async =>
      _gateway.property(id);

  Future<void> createProperty(
      String customerId, Map<String, dynamic> data) async {
    await _gateway.createProperty(data);
  }

  Future<List<Map<String, dynamic>>> myProperties() => _gateway.myProperties();
  Future<void> updateProperty(String id, Map<String, dynamic> data) async {
    await _gateway.updateProperty(id, data);
  }

  Future<void> deleteProperty(String id) async {
    await _gateway.deleteProperty(id);
  }

  Future<void> inquireProperty(String propertyId, String message) async {
    await _gateway.inquireProperty(propertyId, message);
  }

  Future<List<Map<String, dynamic>>> savedSearches(String customerId) =>
      _gateway.propertySavedSearches();

  Future<void> savePropertySearch(Map<String, dynamic> data) async {
    await _gateway.savePropertySearch(data);
  }

  Future<List<Map<String, dynamic>>> propertyMessages(String customerId) =>
      _gateway.propertyMessages();

  Future<List<Map<String, dynamic>>> rentTrackers(String customerId) =>
      _gateway.propertyRentTrackers();

  Future<void> saveRentTracker(
      String customerId, Map<String, dynamic> data) async {
    await _gateway.savePropertyRentTracker(data);
  }

  Future<Map<String, num>> estimatePropertyValue(
      {required String propertyType, int? bhk, String? city}) async {
    final row = await _gateway.estimateProperty(
        {'propertyType': propertyType, 'bhk': bhk, 'city': city});
    return {
      'low': row.n('low'),
      'average': row.n('average'),
      'high': row.n('high')
    };
  }

  Future<List<Map<String, dynamic>>> socialFeed() async {
    final authed = await apiSession.hasToken();
    final rows = authed ? await _gateway.feed() : await _gateway.publicFeed();
    return rows.map(_normalizeSocialPost).toList();
  }

  Future<Map<String, dynamic>?> socialPost(String postId) async {
    if (!await apiSession.hasToken()) return null;
    return _normalizeSocialPost(await _gateway.post(postId));
  }

  Future<List<Map<String, dynamic>>> socialComments(String postId) async {
    if (!await apiSession.hasToken()) return [];
    final rows = await _gateway.comments(postId);
    return rows.map(_normalizeSocialComment).toList();
  }

  Map<String, dynamic> _normalizeSocialComment(Map<String, dynamic> row) {
    final author = row['author'] is Map
        ? Map<String, dynamic>.from(row['author'] as Map)
        : row['user'] is Map
            ? Map<String, dynamic>.from(row['user'] as Map)
            : <String, dynamic>{};
    return {
      ...row,
      'id': row.s('id', row.s('commentId')),
      'user_id':
          row.s('user_id', row.s('userId', row.s('authorId', author.s('id')))),
      'username': row.s(
          'username',
          row.s(
              'userName',
              row.s('authorName',
                  author.s('name', author.s('username', 'Planext user'))))),
      'avatar': resolveMediaUrl(row.s(
          'userAvatar',
          row.s('avatarUrl',
              row.s('avatar', author.s('avatar', author.s('avatarUrl')))))),
      'content': row.s(
          'content', row.s('contentText', row.s('comment', row.s('body')))),
      'created_at': row.s('created_at', row.s('createdAt')),
    };
  }

  /// Sponsored feed ads (web getSocioAds → GET /social/feed/ads). Returns [] on
  /// any failure so the feed still renders.
  Future<List<Map<String, dynamic>>> socialFeedAds() async {
    if (!await apiSession.hasToken()) return [];
    try {
      final rows = await _gateway.feedAds();
      return rows
          .map((row) => {
                ...row,
                'id': row.s('id'),
                'title': row.s('title'),
                'caption': row.s('caption'),
                'advertiser': row.s('advertiser'),
                'image': resolveMediaUrl(
                    row.s('mobileImage', row.s('image', row.s('imageUrl')))),
                'redirect_url': row.s('redirectUrl', row.s('redirect_url')),
              })
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> socialAdConfig() async {
    if (!await apiSession.hasToken()) {
      return const {'adEveryN': 5, 'mode': 'prefer_admin_then_admob'};
    }
    try {
      final row = await _gateway.feedAdConfig();
      final every = row.i('adEveryN', 5).clamp(1, 100);
      const modes = {
        'prefer_admin_then_admob',
        'alternate',
        'admin_only',
        'admob_only',
      };
      final mode = row.s('mode', 'prefer_admin_then_admob');
      return {
        'adEveryN': every,
        'mode': modes.contains(mode) ? mode : 'prefer_admin_then_admob',
      };
    } catch (_) {
      return const {'adEveryN': 5, 'mode': 'prefer_admin_then_admob'};
    }
  }

  Future<void> createSocialPost(
      String userId, Map<String, dynamic> data) async {
    final media = (data['media_urls'] ?? data['mediaUrls'] ?? const []) as List;
    // Mirror the web create-post body exactly (lib/api/social.ts createPost).
    await _gateway.createPost(
      {
        'contentText': data['content_text'] ??
            data['contentText'] ??
            data['caption'] ??
            '',
        'mediaUrls': media,
        'visibility': data['visibility'] ?? 'followers',
        'postType': data['post_type'] ??
            data['postType'] ??
            (media.isNotEmpty ? 'image' : 'text'),
        'location': data['location'],
        'tags': data['tags'] ?? const [],
        'category': data['category'] ?? 'general',
        'linkedProducts':
            data['linkedProducts'] ?? data['linked_products'] ?? const [],
        'hideLikeCount':
            data['hideLikeCount'] ?? data['hide_like_count'] ?? false,
        'commentPermission': data['commentPermission'] ??
            data['comment_permission'] ??
            'everyone',
      },
    ).timeout(
      const Duration(seconds: 45),
      onTimeout: () =>
          throw const ApiException('Post creation timed out. Please retry.'),
    );
  }

  // ── Stories ────────────────────────────────────────────────────────────
  Map<String, dynamic> _normalizeStory(Map<String, dynamic> row) {
    final mediaUrl = resolveMediaUrl(
        row.s('mediaUrl', row.s('media_url', row.s('url', row.s('fileUrl')))));
    return {
      ...row,
      'id': row.s('id', row.s('storyId')),
      'user_id': row.s(
          'user_id', row.s('authorId', row.s('userId', row.s('author_id')))),
      'username': row.s(
          'username', row.s('userName', row.s('authorName', 'Planext user'))),
      'avatar': resolveMediaUrl(row.s('userAvatar',
          row.s('avatarUrl', row.s('avatar', row.s('user_avatar'))))),
      'media_url': mediaUrl,
      'media_type': row.s('mediaType', row.s('media_type', 'image')),
      'created_at': row.s('createdAt', row.s('created_at')),
      'expires_at': row.s('expiresAt', row.s('expires_at')),
      'viewed': row['viewed'] == true || row['isViewed'] == true,
      'view_count': row.i('viewCount', row.i('view_count')),
    };
  }

  bool _storyAlive(Map<String, dynamic> s) {
    DateTime? expiry;
    final exp = s.s('expires_at');
    if (exp.isNotEmpty) expiry = DateTime.tryParse(exp);
    if (expiry == null) {
      final created = DateTime.tryParse(s.s('created_at'));
      if (created != null) expiry = created.add(const Duration(hours: 24));
    }
    return expiry == null || expiry.isAfter(DateTime.now());
  }

  /// Returns `{ 'mine': [segments], 'groups': [ {user_id, username, avatar,
  /// segments:[...]} ] }` — expired segments removed, unviewed groups first
  /// (mirrors the web story rail built by buildStoryItems).
  Future<Map<String, dynamic>> socialStories() async {
    if (!await apiSession.hasToken()) {
      return {
        'mine': <Map<String, dynamic>>[],
        'groups': <Map<String, dynamic>>[]
      };
    }
    final fetched = await Future.wait([
      _gateway.myStories().catchError((_) => <Map<String, dynamic>>[]),
      _gateway.storyFeed().catchError((_) => <Map<String, dynamic>>[]),
    ]);
    final mine = fetched[0].map(_normalizeStory).where(_storyAlive).toList();
    final others = fetched[1].map(_normalizeStory).where(_storyAlive).toList();

    final grouped = <String, Map<String, dynamic>>{};
    for (final s in others) {
      final uid = s.s('user_id');
      if (uid.isEmpty) continue;
      final g = grouped.putIfAbsent(
          uid,
          () => {
                'user_id': uid,
                'username': s.s('username', 'Planext user'),
                'avatar': s.s('avatar'),
                'segments': <Map<String, dynamic>>[],
              });
      (g['segments'] as List).add(s);
    }
    final groups = grouped.values.toList();
    // Unviewed groups first.
    groups.sort((a, b) {
      bool allViewed(Map<String, dynamic> g) =>
          (g['segments'] as List).every((e) => (e as Map)['viewed'] == true);
      final av = allViewed(a), bv = allViewed(b);
      return av == bv ? 0 : (av ? 1 : -1);
    });
    return {'mine': mine, 'groups': groups};
  }

  Future<void> createSocialStory({
    required String mediaUrl,
    required String mediaType,
    String? textOverlay,
  }) async {
    await _gateway.createStory({
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      if (textOverlay != null && textOverlay.trim().isNotEmpty)
        'textOverlay': textOverlay.trim(),
    }).timeout(
      const Duration(seconds: 45),
      onTimeout: () =>
          throw const ApiException('Story creation timed out. Please retry.'),
    );
  }

  Future<void> viewSocialStory(String storyId) async {
    try {
      await _gateway.viewStory(storyId);
    } catch (_) {}
  }

  Future<void> deleteSocialStory(String storyId) =>
      _gateway.deleteStory(storyId);

  /// Uploads a social media file and returns `{ 'url', 'type' }` (type is the
  /// backend-detected 'image' | 'video'), matching web's uploadMedia response.
  Future<Map<String, dynamic>> uploadSocialMediaFile(File file,
      {String? contentType}) async {
    final data = await _gateway
        .uploadSocialMedia(file, contentType: contentType)
        .timeout(
          const Duration(minutes: 2),
          onTimeout: () =>
              throw const ApiException('Media upload timed out. Please retry.'),
        );
    final payload = apiObject(data['data'] ?? data) ?? data;
    final url =
        payload.s('url', payload.s('fileUrl', payload.s('path'))).trim();
    if (url.isEmpty) {
      throw const ApiException('The media upload did not return a file URL.');
    }
    final type =
        payload.s('mediaType', payload.s('media_type', 'image')).toLowerCase();
    return {
      'id': payload.s('id', payload.s('mediaId')),
      'url': url,
      'type': type == 'video' ? 'video' : 'image',
    };
  }

  Future<void> deleteUploadedSocialMedia(String mediaId) async {
    if (mediaId.trim().isEmpty) return;
    await _gateway.deleteSocialMedia(mediaId.trim());
  }

  /// Product search for the create-post "link products" field (web uses
  /// catalogApi.search, limit 8). Returns normalized products.
  Future<List<Map<String, dynamic>>> socialProductSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final raw =
        await _gateway.searchCatalog(query: q, type: 'product', limit: 8);
    return raw
        .where((row) =>
            row.s('type', 'product').toLowerCase() == 'product' ||
            row['type'] == null)
        .map(_normalizeProduct)
        .toList();
  }

  Future<List<Map<String, dynamic>>> socialProfiles({String? search}) async {
    if (!await apiSession.hasToken()) return [];
    final rows = await _gateway.suggestions(query: search);
    return rows;
  }

  Future<Map<String, dynamic>?> socialProfile(String userId) async {
    if (!await apiSession.hasToken()) return null;
    return userId == 'me'
        ? _gateway.mySocialProfile()
        : _gateway.userSocialProfile(userId);
  }

  Future<List<Map<String, dynamic>>> socialUserPosts(String userId) async {
    if (!await apiSession.hasToken()) return [];
    final rows = await _gateway.userPosts(userId);
    return rows.map(_normalizeSocialPost).toList();
  }

  Future<List<Map<String, dynamic>>> socialSavedPosts() async {
    if (!await apiSession.hasToken()) return [];
    final rows = await _gateway.savedPosts();
    return rows.map(_normalizeSocialPost).toList();
  }

  Future<List<Map<String, dynamic>>> socialFollowers(String userId) async {
    if (!await apiSession.hasToken()) return [];
    return _gateway.followers(userId);
  }

  Future<List<Map<String, dynamic>>> socialFollowing(String userId) async {
    if (!await apiSession.hasToken()) return [];
    return _gateway.following(userId);
  }

  Future<Map<String, dynamic>> socialSettings() async {
    if (!await apiSession.hasToken()) return {};
    try {
      return await _gateway.mySocialSettings();
    } catch (_) {
      return {};
    }
  }

  Future<void> updateSocialSettings(Map<String, dynamic> patch) async {
    if (!await apiSession.hasToken()) return;
    await _gateway.updateMySocialSettings(patch);
  }

  /// Updates the socio profile (name/bio/avatar) — web edit-profile uploads the
  /// avatar via /social/upload then patches the shared profile.
  Future<void> updateSocialProfile({
    String? name,
    String? bio,
    String? avatarUrl,
  }) async {
    final id = await apiSession.customerId() ?? '';
    await updateProfile(id, {
      if (name != null) 'name': name,
      if (bio != null) 'bio': bio,
      if (avatarUrl != null) 'avatar': avatarUrl,
    });
  }

  Future<List<Map<String, dynamic>>> socialNotifications(String userId) async {
    if (!await apiSession.hasToken()) return [];
    return _gateway.socialNotifications();
  }

  Future<List<Map<String, dynamic>>> socialConversations(String userId) async {
    if (!await apiSession.hasToken()) return [];
    return _gateway.conversations();
  }

  Future<List<Map<String, dynamic>>> socialMessages(
      String conversationId) async {
    if (!await apiSession.hasToken()) return [];
    return _gateway.conversationMessages(conversationId);
  }

  Future<void> deleteSocialPost(String postId) => _gateway.deletePost(postId);
  Future<void> likeSocialPost(String postId) => _gateway.likePost(postId);
  Future<void> unlikeSocialPost(String postId) => _gateway.unlikePost(postId);
  Future<void> saveSocialPost(String postId) => _gateway.savePost(postId);
  Future<void> unsaveSocialPost(String postId) => _gateway.unsavePost(postId);
  Future<void> shareSocialPost(String postId) => _gateway.sharePost(postId);

  Future<Map<String, dynamic>> repostSocialPost(String postId, {String? caption}) =>
      _gateway.repostPost(postId, caption: caption);
  Future<void> followSocialUser(String userId) => _gateway.followUser(userId);
  Future<void> unfollowSocialUser(String userId) =>
      _gateway.unfollowUser(userId);

  Future<void> createSocialComment(String postId, String content) async {
    await _gateway.createComment(postId, {
      'content': content,
      'contentText': content,
      'body': content,
    });
  }

  Future<String> openSocialConversation(String participantId) async {
    final row = await _gateway.openConversation(participantId);
    return row.s('id', row.s('conversationId'));
  }

  Future<void> sendSocialMessage(String conversationId, String content) async {
    await _gateway.sendMessage(conversationId, {
      'content': content,
      'contentText': content,
      'body': content,
      'message': content,
    });
  }

  Future<String> uploadSocialFile(File file) async {
    final data = await _gateway.uploadSocialMedia(file);
    return data.s('url', data.s('fileUrl', data.s('path')));
  }

  Future<void> accountDeletionRequest(String customerId) async {
    await _updateProfileMetadata(customerId, {
      'accountDeletionRequest': {
        'status': 'requested',
        'requestedAt': DateTime.now().toIso8601String(),
      }
    });
  }

  Future<List<CartItem>> cartItems() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await apiSession.hasToken()) {
      return decodeCart(prefs.getString(_cartKey));
    }
    final local = decodeCart(prefs.getString(_cartKey));
    if (local.isNotEmpty) {
      try {
        await _gateway.mergeCart(local
            .map((item) => {
                  'productId': item.productId,
                  'quantity': item.qty,
                  'unitPrice': item.price,
                  'vendorId': item.vendorId,
                  if (item.variantId != null && item.variantId!.isNotEmpty)
                    'variationId': item.variantId,
                  'metadata': {
                    'productName': item.title,
                    'productImage': item.image,
                    'vendorName': item.vendor,
                    'variantId': item.variantId,
                    'selectedAttributes': item.selectedAttributes,
                  },
                })
            .toList());
        await prefs.remove(_cartKey);
      } catch (_) {
        // Keep local cart if merge fails; still load remote below.
      }
    }
    final remote = apiItems(await _gateway.cart());
    final items = remote.map(_cartItemFromApi).toList();
    await _saveCart(items);
    return items;
  }

  Future<void> _saveCart(List<CartItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cartKey, encodeCart(items));
  }

  Future<void> addToCart(Map<String, dynamic> product,
      {int qty = 1,
      Map<String, String>? selectedAttributes,
      String? variantId}) async {
    if (await apiSession.hasToken()) {
      await _gateway.addCartItem({
        'productId': product.s('id'),
        'quantity': qty,
        'unitPrice':
            product.n('price', product.n('sellPrice', product.n('finalPrice'))),
        'vendorId': product.s('vendor_id', product.s('vendorId')),
        if (variantId != null && variantId.isNotEmpty) 'variationId': variantId,
        'metadata': {
          'selectedAttributes': selectedAttributes,
          'variantId': variantId,
          'productName': product.s('title', product.s('name')),
          'productImage': product.s('image', product.s('thumbnailUrl')),
          'vendorName': product.s('vendor_name', product.s('vendorName')),
        },
      });
      await _saveCart([]);
      return;
    }
    final cart = await cartItems();
    final parentId = product['parent_item_id']?.toString();
    if (parentId != null && parentId.isNotEmpty) {
      final conflict = cart.where((item) =>
          item.parentItemId == parentId &&
          item.vendorId != product.s('vendor_id') &&
          item.productId != product.s('id'));
      if (conflict.isNotEmpty) {
        throw const ApiException(
            'This product is already added from another vendor. Please remove it first.');
      }
    }
    final productId = product.s('id');
    final cartId = variantId == null ? productId : '${productId}__$variantId';
    final index = cart.indexWhere((item) => item.id == cartId);
    if (index >= 0) {
      cart[index] = cart[index].copyWith(qty: cart[index].qty + qty);
    } else {
      cart.add(CartItem(
        id: cartId,
        productId: productId,
        title: product.s('title', product.s('name')),
        price:
            product.n('price', product.n('sellPrice', product.n('finalPrice'))),
        qty: qty,
        vendor: product.s('vendor_name', product.s('vendorName')),
        vendorId: product.s('vendor_id', product.s('vendorId')),
        image: product.s('image', product.s('thumbnailUrl')).isEmpty
            ? null
            : product.s('image', product.s('thumbnailUrl')),
        parentItemId: parentId,
        variantId: variantId,
        selectedAttributes: selectedAttributes,
        tax: product.n('tax'),
        discount: product.n('discount', product.n('discountAmount')),
        maxPoints: product.i(
            'max_points_redeemable', product.i('maxPointsRedeemable')),
      ));
    }
    await _saveCart(cart);
  }

  Future<void> updateCartItem(String itemId, int qty) async {
    if (await apiSession.hasToken()) {
      if (qty <= 0) {
        await _gateway.removeCartItem(itemId);
      } else {
        await _gateway.updateCartItemQuantity(itemId, qty);
      }
      await _saveCart([]);
      return;
    }
    final cart = await cartItems();
    final index = cart.indexWhere((item) => item.id == itemId);
    if (index < 0) return;
    if (qty <= 0) {
      cart.removeAt(index);
    } else {
      cart[index] = cart[index].copyWith(qty: qty);
    }
    await _saveCart(cart);
  }

  Future<void> clearCart() async {
    await _saveCart([]);
    if (await apiSession.hasToken()) {
      await _gateway.clearCart();
    }
  }

  Future<CartSummary> cartSummary(
      {int pointsUsed = 0, num couponDiscount = 0, String? couponCode}) async {
    final items = await cartItems();
    final subtotal =
        items.fold<num>(0, (sum, item) => sum + item.price * item.qty);
    final tax = items.fold<num>(0, (sum, item) => sum + item.tax * item.qty);
    final discount =
        items.fold<num>(0, (sum, item) => sum + item.discount * item.qty);
    var platformFee = 0.0;
    var deliveryFee = 0.0;
    var gstOnPlatformFee = 0.0;
    var surgeCost = 0.0;
    var pointsRedeemedValue = 0.0;
    var walletBalanceBefore = 0.0;
    var maxRedeemableValue = 0.0;
    var meetsMinCart = true;
    var appliedCouponDiscount = couponDiscount;
    num? grandTotal;
    if (await apiSession.hasToken() && items.isNotEmpty) {
      final quote = await _gateway.quoteCart(
        redeemPoints: pointsUsed,
        couponCode: couponCode,
      );
      platformFee = quote.n('platformFee', quote.n('platform_fee')).toDouble();
      deliveryFee = quote.n('deliveryFee', quote.n('delivery_fee')).toDouble();
      gstOnPlatformFee = quote
          .n('gstOnPlatformFee', quote.n('gst_on_platform_fee'))
          .toDouble();
      surgeCost = quote.n('surgeCost', quote.n('surge_cost')).toDouble();
      pointsRedeemedValue = quote
          .n('pointsRedeemedValue', quote.n('points_redeemed_value'))
          .toDouble();
      walletBalanceBefore = quote
          .n('walletBalanceBefore', quote.n('wallet_balance_before'))
          .toDouble();
      maxRedeemableValue = quote
          .n('maxRedeemableValue', quote.n('max_redeemable_value'))
          .toDouble();
      meetsMinCart = quote['meetsMinCart'] != false;
      appliedCouponDiscount = quote.n('discount', couponDiscount);
      final gt = quote['grandTotal'] ?? quote['grand_total'];
      if (gt != null) {
        grandTotal = quote.n('grandTotal', quote.n('grand_total'));
        if (grandTotal < 0) grandTotal = 0;
      }
    }
    return CartSummary(
      items: items,
      subtotal: subtotal,
      tax: tax,
      discount: discount,
      platformFee: platformFee,
      pointsUsed: pointsUsed,
      deliveryFee: deliveryFee,
      gstOnPlatformFee: gstOnPlatformFee,
      surgeCost: surgeCost,
      pointsRedeemedValue: pointsRedeemedValue,
      couponDiscount: appliedCouponDiscount,
      grandTotal: grandTotal,
      walletBalanceBefore: walletBalanceBefore,
      maxRedeemableValue: maxRedeemableValue,
      meetsMinCart: meetsMinCart,
    );
  }

  Future<num> validateCouponCode(String code, num cartTotal) async {
    final result = await _gateway.validateCoupon({
      'code': code.trim(),
      'cartTotal': cartTotal,
    });
    final discount = result.n('discount', result.n('discountAmount'));
    if (discount > 0) return discount;
    if (result['valid'] == false) {
      throw ApiException(result.s('message', 'Invalid coupon'));
    }
    return result.n('discountValue', result.n('amount'));
  }

  /// Places order and returns the created order map (with `id`).
  Future<Map<String, dynamic>> placeOrder({
    required String customerId,
    required CartSummary summary,
    required Map<String, dynamic>? address,
    String paymentMode = 'cod',
    String? couponCode,
    Map<String, dynamic>? deliverySchedule,
  }) async {
    if (summary.items.isEmpty) throw const ApiException('Cart is empty.');
    final addressId = address?.s('id');
    if (addressId == null || addressId.isEmpty) {
      throw const ApiException('Select a delivery address before placing the order.');
    }
    final shippingAddress = <String, dynamic>{
      'id': addressId,
      'label': address?.s('label'),
      'fullName': address?.s('name', address?.s('fullName') ?? ''),
      'phone': address?.s('phone'),
      'line1': address?.s('address_line', address?.s('line1') ?? ''),
      'line2': address?.s('line2'),
      'city': address?.s('city'),
      'state': address?.s('state'),
      'pincode': address?.s('pincode'),
      'country': address?.s('country', 'IN'),
    };
    Map<String, dynamic> order;
    if (await apiSession.hasToken()) {
      order = await _gateway.createOrderFromCart(
        redeemPoints: summary.pointsUsed,
        vendorId:
            summary.items.length == 1 ? summary.items.first.vendorId : null,
        couponCode: couponCode,
        addressId: addressId,
        shippingAddress: shippingAddress,
        paymentMode: paymentMode == 'online' ? 'razorpay' : paymentMode,
        deliverySchedule: deliverySchedule,
      );
    } else {
      order = await _gateway.createDirectOrder({
        'items': summary.items
            .map((item) => {
                  'productId': item.productId,
                  'quantity': item.qty,
                  'price': item.price,
                  'vendorId': item.vendorId,
                  'metadata': {
                    'productName': item.title,
                    'variantId': item.variantId
                  },
                })
            .toList(),
        'addressId': addressId,
        'address': shippingAddress,
        'shippingAddress': shippingAddress,
        'paymentMode': paymentMode,
        'redeemPoints': summary.pointsUsed,
        if (couponCode != null && couponCode.trim().isNotEmpty)
          'couponCode': couponCode.trim(),
        if (deliverySchedule != null) 'deliverySchedule': deliverySchedule,
      });
    }
    if (paymentMode == 'cod') {
      await clearCart();
    }
    return _normalizeOrder(order);
  }

  Future<Map<String, dynamic>> createOrderPayment(String orderId) =>
      _gateway.createOrderPayment(orderId);

  Future<Map<String, dynamic>> createPaymentIntentForOrder({
    required String orderId,
    required num amount,
  }) =>
      _gateway.createPaymentIntent({
        'orderId': orderId,
        'amount': amount.toStringAsFixed(2),
        'currency': 'INR',
        'metadata': {
          'orderType': 'product',
          'domain': 'product',
          'productOrderId': orderId,
        },
      });

  Future<Map<String, dynamic>> verifyPaymentPayload(
          Map<String, dynamic> body) =>
      _gateway.verifyPayment(body);

  Future<Map<String, dynamic>> paymentIntentStatus(String intentId) =>
      _gateway.paymentIntent(intentId);

  Future<void> clearCartAfterPaid() => clearCart();

  Future<Map<String, dynamic>?> myReferralCode() async {
    if (!await apiSession.hasToken()) return null;
    return _gateway.referralCode();
  }

  Future<List<Map<String, dynamic>>> productReviews(String productId) async {
    return _gateway.reviews(targetType: 'product', targetId: productId);
  }

  Future<Map<String, dynamic>> productReviewSummary(String productId) async {
    return _gateway.reviewSummary(targetType: 'product', targetId: productId);
  }

  Future<List<Map<String, dynamic>>> mergedNotifications(String userId) async {
    if (!await apiSession.hasToken()) return [];
    final system = await _gateway.notifications();
    final social = await _gateway.socialNotifications();
    final rows = <Map<String, dynamic>>[
      ...system.map((n) => {...n, 'source': 'system'}),
      ...social.map((n) => {...n, 'source': 'social'}),
    ];
    rows.sort((a, b) {
      final ad = DateTime.tryParse(a.s('created_at', a.s('createdAt'))) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bd = DateTime.tryParse(b.s('created_at', b.s('createdAt'))) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });
    return rows;
  }

  Future<void> markSystemNotificationRead(String id) =>
      _gateway.markNotificationRead(id);

  Future<Set<String>> wishlist() async {
    if (await apiSession.hasToken()) {
      final rows = await _gateway.wishlist();
      if (rows.isNotEmpty) {
        return rows
            .map((row) => row.s('productId', row.s('product_id', row.s('id'))))
            .where((id) => id.isNotEmpty)
            .toSet();
      }
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_wishlistKey);
    if (raw == null) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! List) return {};
    return decoded.map((e) => e.toString()).toSet();
  }

  Future<void> toggleWishlist(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await wishlist();
    final remove = items.contains(id);
    if (remove) {
      items.remove(id);
    } else {
      items.add(id);
    }
    await prefs.setString(_wishlistKey, jsonEncode(items.toList()));
    if (await apiSession.hasToken()) {
      if (remove) {
        await _gateway.removeWishlistItem(id);
      } else {
        await _gateway.addWishlistItem(id);
      }
    }
  }

  Future<List<Map<String, dynamic>>> wishlistProducts() async {
    if (await apiSession.hasToken()) {
      final rows = await _gateway.wishlist();
      final productIds = <String>{};
      for (final row in rows) {
        if (row['product'] is Map) continue;
        final productId = row.s('productId', row.s('product_id'));
        if (productId.isNotEmpty) productIds.add(productId);
      }
      final productMap = <String, Map<String, dynamic>>{};
      await Future.wait(productIds.map((pid) async {
        try {
          final hydrated =
              await product(pid).timeout(const Duration(seconds: 8));
          if (hydrated != null) productMap[pid] = hydrated;
        } catch (_) {}
      }));

      final products = <Map<String, dynamic>>[];
      for (final row in rows) {
        if (row['product'] is Map) {
          products.add(_normalizeProduct(
              Map<String, dynamic>.from(row['product'] as Map)));
          continue;
        }
        final productId = row.s('productId', row.s('product_id', row.s('id')));
        if (productId.isEmpty) continue;
        final hydrated = productMap[productId];
        // Web merges wishlist metadata even when catalog hydrate fails.
        final fallbackTitle = hydrated == null
            ? 'Product'
            : hydrated.s('title', hydrated.s('name', 'Product'));
        final fallbackImage = hydrated == null ? '' : hydrated.s('image');
        final fallbackPrice = hydrated == null
            ? 0
            : hydrated.n('price', hydrated.n('finalPrice'));
        products.add(_normalizeProduct({
          if (hydrated != null) ...hydrated,
          'id': productId,
          'productId': productId,
          'name': row.s('productName', row.s('name', fallbackTitle)),
          'title': row.s('productName', row.s('title', fallbackTitle)),
          'image': row.s('productImage', row.s('image', fallbackImage)),
          'price': row.n('productPrice', row.n('price', fallbackPrice)),
        }));
      }
      return products;
    }
    final ids = (await wishlist()).toList();
    final products = <Map<String, dynamic>>[];
    await Future.wait(ids.map((id) async {
      try {
        final item = await product(id).timeout(const Duration(seconds: 8));
        if (item != null) products.add(item);
      } catch (_) {}
    }));
    return products;
  }

  Future<String?> selectedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_locationKey);
  }

  Future<void> saveSelectedLocation(String value,
      {double? latitude, double? longitude}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_locationKey, value);
    if (latitude != null && longitude != null) {
      await prefs.setDouble(_latitudeKey, latitude);
      await prefs.setDouble(_longitudeKey, longitude);
    } else {
      await prefs.remove(_latitudeKey);
      await prefs.remove(_longitudeKey);
    }
  }

  CartItem _cartItemFromApi(Map<String, dynamic> row) {
    final product = row['product'] is Map
        ? Map<String, dynamic>.from(row['product'] as Map)
        : <String, dynamic>{};
    final merged = {...product, ...row};
    final meta = merged['metadata'] is Map
        ? Map<String, dynamic>.from(merged['metadata'] as Map)
        : <String, dynamic>{};
    // Line UUID from commerce API (`id`) — required for DELETE/PATCH cart item.
    final lineId = merged.s('id', merged.s('itemId', merged.s('item_id')));
    final productId = merged.s('productId', merged.s('product_id'));
    final variantId = merged.s('variationId',
        merged.s('variation_id', meta.s('variantId', meta.s('variationId'))));
    final title = merged.s(
        'title',
        merged.s('name',
            merged.s('productName', meta.s('productName', meta.s('title')))));
    final image = merged.s(
        'image',
        merged.s('thumbnailUrl',
            meta.s('productImage', meta.s('thumbnailUrl', meta.s('image')))));
    final vendor =
        merged.s('vendorName', merged.s('vendor_name', meta.s('vendorName')));
    return CartItem(
      id: lineId.isNotEmpty ? lineId : productId,
      productId: productId.isNotEmpty ? productId : lineId,
      title: title.isNotEmpty ? title : 'Item',
      price: merged.n('unitPrice', merged.n('price', merged.n('finalPrice'))),
      qty: merged.i('quantity', merged.i('qty', 1)),
      vendor: vendor,
      vendorId: merged.s('vendorId', merged.s('vendor_id')),
      image: image.isEmpty ? null : image,
      tax: merged.n('tax'),
      discount: merged.n('discount', merged.n('discountAmount')),
      variantId: variantId.isEmpty ? null : variantId,
    );
  }

  Future<void> _updateProfileMetadata(
      String customerId, Map<String, dynamic> patch) async {
    final current = await profile(customerId) ?? {};
    final existing = _metadataOf(current);
    await _gateway.updateMyProfile({
      'metadata': {...existing, ...patch}
    });
    final refreshed = await profile(customerId);
    if (refreshed != null) await apiSession.saveProfile(refreshed);
  }

  Map<String, dynamic> _metadataOf(Map<String, dynamic> row) {
    final raw = row['metadata'];
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  Future<void> subscribeNewsletter(String email) async {
    await _gateway.newsletterSubscribe(email.trim());
  }

  Future<List<Map<String, dynamic>>> _recentViewedProducts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recentProductsKey);
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw);
      return decoded is List
          ? decoded
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .take(4)
              .toList()
          : <Map<String, dynamic>>[];
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _rememberProduct(Map<String, dynamic> product) async {
    final id = product.s('id');
    if (id.isEmpty) return;
    final rows = await _recentViewedProducts();
    rows.removeWhere((row) => row.s('id') == id);
    rows.insert(0, product);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _recentProductsKey, jsonEncode(rows.take(4).toList()));
  }

  Map<String, dynamic> _normalizeProduct(Map<String, dynamic> row) {
    final vendor = row['vendor'] is Map
        ? Map<String, dynamic>.from(row['vendor'] as Map)
        : <String, dynamic>{};
    final image = _imageFrom(row, const [
      'image',
      'imageUrl',
      'image_url',
      'thumbnailUrl',
      'thumbnail_url',
      'primaryImageUrl',
      'primary_image_url',
      'fileUrl',
      'file_url'
    ]);
    return {
      ...row,
      'id': row.s('id', row.s('productId')),
      'title': row.s('title', row.s('name', row.s('productName'))),
      'price': row.n('price', row.n('sellPrice', row.n('finalPrice'))),
      'discount': row.n('discount', row.n('discountAmount')),
      'tax': row.n('tax'),
      'stock': row.i('stock', row.i('availableStock')),
      'image': image.isNotEmpty
          ? image
          : _imageFrom(row, const [
              'bannerUrls',
              'images',
              'imageUrls',
              'mediaUrls',
              'media_urls',
              'attachments'
            ]),
      'vendor_id': row.s('vendor_id', row.s('vendorId', vendor.s('id'))),
      'vendor_name': row.s(
          'vendor_name',
          row.s('vendorName',
              vendor.s('businessName', vendor.s('business_name')))),
      'category_name': row.s('category_name', row.s('categoryName')),
      'category_id': row.s('category_id', row.s('categoryId')),
      'subcategory_id': row.s('subcategory_id', row.s('subcategoryId')),
      'status':
          row.s('status', row['isActive'] == false ? 'inactive' : 'active'),
    };
  }

  Map<String, dynamic> _normalizeService(Map<String, dynamic> row) {
    return {
      ...row,
      'id': row.s('id', row.s('serviceId')),
      'title': row.s('title', row.s('displayName', row.s('name'))),
      'price': row.n('price', row.n('basePrice')),
      'original_price': row.n('originalPrice',
          row.n('original_price', row.n('price', row.n('basePrice')))),
      'image': _imageFrom(row, const [
        'image',
        'imageUrl',
        'image_url',
        'iconUrl',
        'icon_url',
        'thumbnailUrl',
        'thumbnail_url',
        'mediaUrls',
        'images'
      ]),
      'vendor_id': row.s('vendor_id', row.s('vendorId')),
      'category_name': row.s('category_name', row.s('categoryName')),
      'category_id': row.s('category_id', row.s('categoryId')),
      'subcategory_id': row.s('subcategory_id', row.s('subcategoryId')),
      'duration': row.s('duration', row.s('durationMinutes')),
      'status':
          row.s('status', row['isActive'] == false ? 'inactive' : 'active'),
    };
  }

  Map<String, dynamic> _normalizeCategory(Map<String, dynamic> row) => {
        ...row,
        'id': row.s('id', row.s('categoryId')),
        'name': row.s('name', row.s('title')),
        'image': _imageFrom(row, const [
          'image',
          'imageUrl',
          'image_url',
          'iconUrl',
          'icon_url',
          'thumbnailUrl',
          'thumbnail_url'
        ]),
      };

  Map<String, dynamic> _normalizeClassified(Map<String, dynamic> row) {
    final meta = row['metadata'] is Map
        ? Map<String, dynamic>.from(row['metadata'] as Map)
        : <String, dynamic>{};
    return {
      ...row,
      'id': row.s('id', row.s('classifiedId')),
      'title': row.s('title', row.s('name')),
      'price': row.n('price', row.n('amount')),
      'contactPhone': row.s(
          'contactPhone',
          row.s('contact_phone',
              row.s('phone', row.s('mobile', meta.s('contactPhone'))))),
      'image': _imageFrom(row, const [
        'image',
        'imageUrl',
        'image_url',
        'thumbnailUrl',
        'thumbnail_url',
        'coverImage',
        'cover_image',
        'mediaUrls',
        'media_urls',
        'images',
        'attachments'
      ]),
    };
  }

  Map<String, dynamic> _normalizeSocialPost(Map<String, dynamic> row) {
    final author = row['author'] is Map
        ? Map<String, dynamic>.from(row['author'] as Map)
        : row['user'] is Map
            ? Map<String, dynamic>.from(row['user'] as Map)
            : <String, dynamic>{};
    final meta = row['metadata'] is Map
        ? Map<String, dynamic>.from(row['metadata'] as Map)
        : <String, dynamic>{};
    final media = _mediaList(row)
        .map(resolveMediaUrl)
        .where((u) => u.isNotEmpty)
        .toList();
    final postType = row.s('post_type',
        row.s('postType', row.s('media_type', row.s('mediaType'))));
    // Linked products (metadata.linkedProducts on the server) → {id,name,image,price,vendorId}.
    final rawLinked = (row['linkedProducts'] ??
        row['linked_products'] ??
        meta['linkedProducts'] ??
        meta['linked_products']);
    final linkedProducts = rawLinked is List
        ? rawLinked.whereType<Map>().map((e) {
            final p = Map<String, dynamic>.from(e);
            return {
              'id': p.s('id', p.s('productId')),
              'name': p.s('name', p.s('title')),
              'image': resolveMediaUrl(p.s('image', p.s('imageUrl'))),
              'price': p.n('price'),
              'vendorId': p.s('vendorId', p.s('vendor_id')),
            };
          }).toList()
        : const <Map<String, dynamic>>[];
    final rawTags = (row['tags'] ?? meta['tags']);
    final tags = rawTags is List
        ? rawTags.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : const <String>[];
    return {
      ...row,
      'avatar': resolveMediaUrl(row.s(
          'userAvatar',
          row.s(
              'avatarUrl',
              row.s(
                  'avatar',
                  row.s(
                      'authorAvatar',
                      author.s('avatar',
                          author.s('avatarUrl', author.s('userAvatar')))))))),
      'is_following': row['isFollowing'] == true ||
          row['isFollowingAuthor'] == true ||
          row['following'] == true,
      'is_self': row['isSelf'] == true || row['self'] == true,
      'category': row.s('category', meta.s('category')),
      'tags': tags,
      'linked_products': linkedProducts,
      'hide_like_count': row['hideLikeCount'] == true ||
          meta['hideLikeCount'] == true ||
          row['hide_like_count'] == true,
      'comment_permission': row.s('commentPermission',
          row.s('comment_permission', meta.s('commentPermission', 'everyone'))),
      'shares_count': row.i('shares_count',
          row.i('share_count', row.i('sharesCount', row.i('shareCount')))),
      'id': row.s('id', row.s('postId')),
      'user_id': row.s(
          'user_id',
          row.s(
              'authorId', row.s('userId', author.s('id', author.s('userId'))))),
      'username': row.s(
          'username',
          row.s(
              'userName',
              row.s('authorName',
                  author.s('name', author.s('username', 'Planext user'))))),
      'caption': row.s(
          'caption', row.s('content', row.s('contentText', row.s('body')))),
      'created_at': row.s('created_at', row.s('createdAt')),
      'post_type': postType,
      'postType': postType,
      'media_type': row.s('media_type', row.s('mediaType')),
      'media_urls': media,
      'image_url': media.isNotEmpty
          ? media.first
          : resolveMediaUrl(_imageFrom(row, const [
              'imageUrl',
              'image_url',
              'thumbnailUrl',
              'thumbnail_url'
            ])),
      'likes_count': row.i('likes_count',
          row.i('like_count', row.i('likesCount', row.i('likeCount')))),
      'comments_count': row.i(
          'comments_count',
          row.i(
              'comment_count', row.i('commentsCount', row.i('commentCount')))),
      'liked': row['liked'] == true ||
          row['isLiked'] == true ||
          row['is_liked'] == true ||
          row['has_liked'] == true ||
          row['hasLiked'] == true,
      'saved': row['saved'] == true ||
          row['isSaved'] == true ||
          row['is_saved'] == true ||
          row['has_saved'] == true ||
          row['hasSaved'] == true,
    };
  }

  Map<String, dynamic> _normalizeOrder(Map<String, dynamic> row) {
    final meta = row['metadata'] is Map
        ? Map<String, dynamic>.from(row['metadata'] as Map)
        : <String, dynamic>{};
    var items = row['items'];
    if (items is! List || items.isEmpty) {
      items = meta['lines'] ?? meta['items'];
    }
    final normalizedItems = <Map<String, dynamic>>[];
    if (items is List) {
      for (final raw in items) {
        if (raw is! Map) continue;
        final item = Map<String, dynamic>.from(raw);
        final itemMeta = item['metadata'] is Map
            ? Map<String, dynamic>.from(item['metadata'] as Map)
            : <String, dynamic>{};
        normalizedItems.add({
          ...item,
          'title': item.s(
              'title',
              item.s('name',
                  item.s('productName', itemMeta.s('productName', 'Item')))),
          'qty': item.i('qty', item.i('quantity', 1)),
          'price': item.n('price', item.n('unitPrice', item.n('sellPrice'))),
        });
      }
    }
    return {
      ...row,
      'id': row.s('id', row.s('orderId')),
      'total': row.n('total', row.n('totalAmount', row.n('grandTotal'))),
      'created_at': row.s('created_at', row.s('createdAt')),
      'payment_status': row.s('payment_status', row.s('paymentStatus')),
      'payment_ref': row.s(
          'payment_ref',
          row.s(
              'paymentRefId', row.s('paymentReferenceId', row.s('paymentId')))),
      'vendor_id': row.s('vendor_id', row.s('vendorId', meta.s('vendorId'))),
      'vendor_name': () {
        final direct =
            row.s('vendor_name', row.s('vendorName', meta.s('vendorName')));
        if (direct.isNotEmpty) return direct;
        final lines = meta['lines'];
        if (lines is List && lines.isNotEmpty && lines.first is Map) {
          final lm = Map<String, dynamic>.from(lines.first as Map);
          final lmeta = lm['metadata'] is Map
              ? Map<String, dynamic>.from(lm['metadata'] as Map)
              : <String, dynamic>{};
          return lmeta.s('vendorName');
        }
        return '';
      }(),
      'items': normalizedItems,
      'delivery_fee':
          row.n('delivery_fee', row.n('deliveryFee', meta.n('deliveryFee'))),
      'platform_fee':
          row.n('platform_fee', row.n('platformFee', meta.n('platformFee'))),
      'gst':
          row.n('gst', row.n('gstOnPlatformFee', meta.n('gstOnPlatformFee'))),
      'subtotal':
          row.n('subtotal', row.n('itemSubtotal', meta.n('itemSubtotal'))),
    };
  }

  /// Orders persist only productId/qty/price — the product name, image and price,
  /// plus the vendor's business name, are resolved from the catalog at read time
  /// (same approach as [wishlistProducts]). Legacy lines saved with price 0 fall
  /// back to the current catalog price so nothing renders as "Item"/₹0.
  Future<Map<String, dynamic>> _hydrateOrder(Map<String, dynamic> order) async {
    final items = order['items'];
    if (items is! List || items.isEmpty) return order;

    final productIds = <String>{};
    for (final raw in items) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final pid = item.s('productId', item.s('product_id', item.s('id')));
      if (pid.isNotEmpty) productIds.add(pid);
    }

    final productMap = <String, Map<String, dynamic>>{};
    await Future.wait(productIds.map((pid) async {
      try {
        final hydrated = await product(pid).timeout(const Duration(seconds: 8));
        if (hydrated != null) productMap[pid] = hydrated;
      } catch (_) {}
    }));

    String vendorIdForName = '';
    final hydratedItems = <Map<String, dynamic>>[];
    for (final raw in items) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final pid = item.s('productId', item.s('product_id', item.s('id')));
      final p = productMap[pid];
      final currentTitle = item.s('title');
      final title =
          (currentTitle.isEmpty || currentTitle == 'Item') && p != null
              ? p.s('title', 'Item')
              : (currentTitle.isEmpty ? 'Item' : currentTitle);
      final currentImage = item.s('image');
      final image =
          currentImage.isNotEmpty ? currentImage : (p?.s('image') ?? '');
      final currentPrice = item.n('price');
      final price = currentPrice > 0 ? currentPrice : (p?.n('price') ?? 0);
      if (vendorIdForName.isEmpty) vendorIdForName = p?.s('vendor_id') ?? '';
      hydratedItems.add({
        ...item,
        'title': title,
        'image': image,
        'price': price,
      });
    }
    order['items'] = hydratedItems;

    // Resolve the vendor business name from the catalog when the order carries
    // only a vendor id/code. Prefer the catalog vendor id from a hydrated product
    // (guaranteed to match) over the order's stored vendor id.
    if (order.s('vendor_name').isEmpty) {
      final orderVendorId = order.s('vendor_id');
      final tryId =
          (vendorIdForName.isNotEmpty ? vendorIdForName : orderVendorId).trim();
      if (tryId.isNotEmpty) {
        try {
          final v = await vendor(tryId).timeout(const Duration(seconds: 8));
          if (v != null) {
            final name = v.s('vendor_name',
                v.s('name', v.s('businessName', v.s('business_name'))));
            if (name.isNotEmpty) order['vendor_name'] = name;
          }
        } catch (_) {}
      }
    }
    return order;
  }

  Map<String, dynamic> _normalizeVendor(Map<String, dynamic> row) {
    final banners = <String>[];
    for (final key in const ['banners', 'bannerUrls', 'banner_urls']) {
      final raw = row[key];
      if (raw is List) {
        for (final e in raw) {
          final url = e is Map
              ? (e['url'] ?? e['imageUrl'] ?? e['image'] ?? '').toString()
              : e.toString();
          if (url.isNotEmpty) banners.add(url);
        }
      }
    }
    final banner = _imageFrom(row, const [
      'banner',
      'bannerUrl',
      'banner_url',
      'coverImage',
      'cover_image',
      'background_image'
    ]);
    if (banner.isNotEmpty && !banners.contains(banner)) {
      banners.insert(0, banner);
    }
    return {
      ...row,
      'id': row.s('id', row.s('vendorId')),
      'business_name': row.s('business_name', row.s('businessName')),
      'name': row.s('name', row.s('ownerName')),
      'mobile': row.s('mobile', row.s('phone')),
      'email': row.s('email'),
      'rating': row.n('rating', row.n('avgRating', row.n('averageRating'))),
      'logo': _imageFrom(
          row, const ['logo', 'logoUrl', 'thumbnailUrl', 'thumbnail_url']),
      'banners': banners,
    };
  }

  Map<String, dynamic> _normalizeBooking(Map<String, dynamic> row) {
    final meta = row['metadata'] is Map
        ? Map<String, dynamic>.from(row['metadata'] as Map)
        : <String, dynamic>{};
    return {
      ...row,
      'id': row.s('id', row.s('bookingId')),
      'service_id': row.s('service_id', row.s('serviceId')),
      'service_name': row.s(
          'service_name',
          row.s(
              'serviceName',
              row.s('serviceTitle',
                  meta.s('serviceName', meta.s('serviceTitle'))))),
      'vendor_name':
          row.s('vendor_name', row.s('vendorName', meta.s('vendorName'))),
      'booking_date': row.s('booking_date', row.s('bookingDate')),
      'time_slot': row.s('time_slot', row.s('timeSlot')),
      'total_amount': row.n('total_amount', row.n('totalAmount')),
      'status': row.s('status', 'pending'),
    };
  }

  Map<String, dynamic> _normalizeAddress(Map<String, dynamic> row) => {
        ...row,
        'id': row.s('id', row.s('addressId')),
        'label': row.s('label', row.s('name', 'Home')),
        'name': row.s('fullName', row.s('name', row.s('label'))),
        'fullName': row.s('fullName', row.s('name')),
        'mobile': row.s('mobile', row.s('phone')),
        'phone': row.s('phone', row.s('mobile')),
        'address_line':
            row.s('address_line', row.s('line1', row.s('addressLine1'))),
        'line1': row.s('line1', row.s('addressLine1', row.s('address_line'))),
        'line2': row.s('line2', row.s('addressLine2')),
        'city': row.s('city'),
        'state': row.s('state'),
        'pincode': row.s('pincode', row.s('postalCode')),
        'country': row.s('country', 'India'),
        'is_default': row['is_default'] ?? row['isDefault'] ?? false,
      };

  Map<String, dynamic> _addressPayload(Map<String, dynamic> address) {
    final line2 = address.s('line2').trim();
    final latitude = address['latitude'];
    final longitude = address['longitude'];
    return {
      'label': address.s('label', address.s('name', 'Home')).trim(),
      'fullName': address.s('fullName', address.s('name', 'Customer')).trim(),
      'phone': address.s('phone', address.s('mobile')).trim(),
      'addressLine1': address.s('line1', address.s('address_line')).trim(),
      'addressLine2': line2.isEmpty ? null : line2,
      'city': address.s('city').trim(),
      'state': address.s('state').trim(),
      'postalCode': address.s('pincode', address.s('postalCode')).trim(),
      'country': address.s('country', 'India').trim(),
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'isDefault': address['is_default'] ?? address['isDefault'] ?? false,
    };
  }

  Map<String, String> _assetMap(Map<String, dynamic> home) {
    final assets = <String, String>{};
    final rawAssets = home['assets'];
    if (rawAssets is Map) {
      for (final entry in rawAssets.entries) {
        assets[entry.key.toString()] = entry.value.toString();
      }
    }
    return assets;
  }

  String _imageFrom(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      final direct = _firstString(value);
      if (direct.isNotEmpty) return direct;
    }
    return '';
  }

  List<String> _mediaList(Map<String, dynamic> row) {
    final values = <String>[];
    for (final key in const [
      'media_urls',
      'mediaUrls',
      'imageUrls',
      'images',
      'attachments',
      'media'
    ]) {
      final value = row[key];
      if (value is List) {
        for (final item in value) {
          final found = _firstString(item);
          if (found.isNotEmpty) values.add(found);
        }
      } else {
        final found = _firstString(value);
        if (found.isNotEmpty) values.add(found);
      }
    }
    final fallback = _firstString(
        row['image_url'] ?? row['imageUrl'] ?? row['thumbnailUrl']);
    if (values.isEmpty && fallback.isNotEmpty) values.add(fallback);
    return values;
  }

  String _firstString(Object? value) {
    if (value == null) return '';
    if (value is String) return value.trim();
    if (value is List) {
      for (final item in value) {
        final found = _firstString(item);
        if (found.isNotEmpty) return found;
      }
      return '';
    }
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      for (final key in const [
        'url',
        'fileUrl',
        'file_url',
        'imageUrl',
        'image_url',
        'thumbnailUrl',
        'path'
      ]) {
        final found = _firstString(map[key]);
        if (found.isNotEmpty) return found;
      }
      return '';
    }
    return value.toString().trim();
  }

  Future<List<Map<String, dynamic>>> socialCalls() => _gateway.socialCalls();
  Future<Map<String, dynamic>> socialCall(String id) => _gateway.socialCall(id);
  Future<Map<String, dynamic>> startSocialCall(
          String conversationId, String type,
          {String? offerSdp}) =>
      _gateway.startSocialCall(conversationId, type, offerSdp: offerSdp);
  Future<Map<String, dynamic>> acceptSocialCall(String id,
          {String? answerSdp}) =>
      _gateway.acceptSocialCall(id, answerSdp: answerSdp);
  Future<Map<String, dynamic>> rejectSocialCall(String id) =>
      _gateway.rejectSocialCall(id);
  Future<Map<String, dynamic>> endSocialCall(String id) =>
      _gateway.endSocialCall(id);
}
