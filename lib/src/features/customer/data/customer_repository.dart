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
  static const _locationKey = 'p4u_customer_location';

  Future<CustomerHomeData> getHome() async {
    // Keep the home screen gentle on the public API. Parallel bursts can hit IP rate limits.
    final banners = await _gateway.banners(limit: 20);
    final categories = await _gateway.categories(limit: 50, kind: 'product');
    final serviceCategories =
        await _gateway.categories(limit: 50, kind: 'service');
    final featuredProducts = await _gateway.featuredProducts(limit: 20);
    final serviceHighlights = await _gateway.serviceHighlights(limit: 12);
    final popups = await _gateway.popups(limit: 10);
    final home = await _gateway.homeContent();
    final products = featuredProducts.map(_normalizeProduct).toList();
    final services = serviceHighlights.map(_normalizeService).toList();
    return CustomerHomeData(
      banners: banners,
      categories: categories.map(_normalizeCategory).toList(),
      serviceCategories: serviceCategories.map(_normalizeCategory).toList(),
      products: products.take(10).toList(),
      services: services.take(10).toList(),
      storeBanners: popups,
      assets: _assetMap(home),
    );
  }

  Future<List<Map<String, dynamic>>> browseProducts(
      {String? category, String? search, String? sort}) async {
    final q = search?.trim() ?? '';
    List<Map<String, dynamic>> rows;
    if (q.isNotEmpty) {
      // /browse/products ignores `q`/`sort`; catalog search is the search path.
      rows = await _gateway.searchCatalog(query: q, type: 'product', limit: 50);
    } else {
      rows = await _gateway.browseProducts(
          categoryId: category, limit: 50);
    }
    var products = rows.map(_normalizeProduct).toList();
    if (q.isNotEmpty && category != null && category.isNotEmpty) {
      products = products
          .where((p) =>
              p.s('category_id', p.s('categoryId')) == category ||
              p.s('category_name', p.s('categoryName'))
                  .toLowerCase()
                  .contains(category.toLowerCase()))
          .toList();
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
    return _normalizeProduct(data);
  }

  Future<List<Map<String, dynamic>>> productVariants(String productId) async {
    final product = await this.product(productId);
    final variants = product?['variants'];
    return variants is List ? apiItems(variants) : [];
  }

  Future<List<Map<String, dynamic>>> categories() async {
    final rows = await _gateway.categories(limit: 100, kind: 'product');
    return rows.map(_normalizeCategory).toList();
  }

  Future<List<Map<String, dynamic>>> services(
      {String? category, String? search}) async {
    final rows =
        await _gateway.services(categoryId: category, query: search, limit: 50);
    return rows.map(_normalizeService).toList();
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
  }) async {
    await _gateway.createServiceBooking(
      {
        'vendorId': service.s('vendor_id', service.s('vendorId')),
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

  Future<List<Map<String, dynamic>>> availableSlots({
    String? vendorId,
    String? serviceId,
    String? date,
  }) async {
    if (!await apiSession.hasToken()) return [];
    return _gateway.availableSlots(
        vendorId: vendorId, serviceId: serviceId, date: date);
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
    final id = await apiSession.customerId() ?? customerId;
    if (id.isEmpty) return [];
    try {
      final rows = await _gateway.customerOrders(id);
      return rows.map(_normalizeOrder).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> bookings(String customerId) async {
    if (!await apiSession.hasToken()) return [];
    final rows = await _gateway.myBookings();
    return rows.map(_normalizeBooking).toList();
  }

  Future<void> cancelBooking(String bookingId) async {
    await _gateway.cancelBooking(bookingId);
  }

  Future<void> cancelOrder(String orderId) async {
    await _gateway.cancelOrder(orderId);
  }

  Future<Map<String, dynamic>?> order(String id) async {
    final data = await _gateway.order(id);
    return _normalizeOrder(data);
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
    // Persist customer id from profile when session is missing it.
    final pid = profile.s('id', profile.s('customerId'));
    if (pid.isNotEmpty) {
      final prefsId = await apiSession.customerId();
      if (prefsId == null || prefsId.isEmpty) {
        await apiSession.setCustomerId(pid);
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
      adsCount = (await classifieds()).length;
    } catch (_) {}
    try {
      final wallet = await _gateway.walletSummary();
      final walletObj = apiObject(wallet) ?? wallet;
      points = walletObj.n('displayAmount',
          walletObj.n('balance', walletObj.n('points')));
    } catch (_) {}
    if (points == 0) {
      try {
        final reward = await rewardPoints(customerId);
        points = reward.n(
            'displayAmount', reward.n('balance', reward.n('points')));
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
    final avatar = meta.s('avatarUrl',
        meta.s('avatar', row.s('avatarUrl', row.s('avatar'))));
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
    final raw = data.s('url',
        data.s('fileUrl', data.s('file_url', data.s('path', data.s('publicUrl')))));
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

  Future<void> saveAddress(
      String customerId, Map<String, dynamic> address) async {
    final payload = _addressPayload(address);
    final id = address['id']?.toString();
    if (id == null || id.isEmpty) {
      await _gateway.createAddress(payload);
    } else {
      await _gateway.updateAddress(id, payload);
    }
  }

  Future<void> deleteAddress(String id) async {
    await _gateway.deleteAddress(id);
  }

  Future<List<Map<String, dynamic>>> walletTransactions(
      String customerId) async {
    if (!await apiSession.hasToken()) return [];
    final data = await _gateway.walletSummary();
    return apiItems(data['recentTransactions'] ??
        data['transactions'] ??
        data['items'] ??
        data);
  }

  Future<List<Map<String, dynamic>>> referrals(String customerId) async {
    if (!await apiSession.hasToken()) return [];
    final data = await _gateway.referralInfo();
    return apiItems(data['referrals'] ?? data['items'] ?? data);
  }

  Future<Map<String, dynamic>> rewardPoints(String customerId) async {
    if (!await apiSession.hasToken()) return {};
    final data = await _gateway.rewardPoints();
    return {...data, 'points': data['balance'] ?? data['points'] ?? 0};
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

  Future<List<Map<String, dynamic>>> supportTickets(String customerId) async {
    final profile = await this.profile(customerId) ?? {};
    return apiItems(_metadataOf(profile)['supportTickets']);
  }

  Future<void> createSupportTicket(
      String customerId, Map<String, dynamic> data) async {
    final profile = await this.profile(customerId) ?? {};
    final tickets = apiItems(_metadataOf(profile)['supportTickets']);
    tickets.insert(0, {
      ...data,
      'id': 'ticket-',
      'status': 'open',
      'created_at': DateTime.now().toIso8601String(),
    });
    await _updateProfileMetadata(customerId, {'supportTickets': tickets});
  }

  Future<List<Map<String, dynamic>>> properties(
      {String? transactionType, String? search}) async {
    final localRows = await _localPropertyListings();
    final filteredLocal = localRows.where((row) {
      final typeOk = transactionType == null ||
          transactionType.isEmpty ||
          row.s('transaction_type', row.s('listingType')) == transactionType;
      final q = search?.trim().toLowerCase() ?? '';
      final queryOk = q.isEmpty ||
          [
            row.s('title'),
            row.s('city'),
            row.s('locality'),
            row.s('description')
          ].join(' ').toLowerCase().contains(q);
      return typeOk && queryOk;
    }).toList();
    if (search == null || search.isEmpty) return filteredLocal;
    final remoteRows = await _gateway.searchCatalog(
        query: search, type: transactionType ?? 'property', limit: 50);
    return [...filteredLocal, ...remoteRows];
  }

  Future<Map<String, dynamic>?> property(String id) async {
    final localRows = await _localPropertyListings();
    for (final row in localRows) {
      if (row.s('id') == id) return row;
    }
    final rows =
        await _gateway.searchCatalog(query: id, type: 'property', limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> createProperty(
      String customerId, Map<String, dynamic> data) async {
    final profile = await this.profile(customerId) ?? {};
    final properties = apiItems(_metadataOf(profile)['propertyListings']);
    properties.insert(0, {
      ...data,
      'id': 'property-',
      'user_id': customerId,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    });
    await _updateProfileMetadata(customerId, {'propertyListings': properties});
  }

  Future<List<Map<String, dynamic>>> savedSearches(String customerId) async {
    final profile = await this.profile(customerId) ?? {};
    return apiItems(_metadataOf(profile)['savedSearches']);
  }

  Future<List<Map<String, dynamic>>> propertyMessages(String customerId) async {
    return socialConversations(customerId);
  }

  Future<List<Map<String, dynamic>>> rentTrackers(String customerId) async {
    final profile = await this.profile(customerId) ?? {};
    return apiItems(_metadataOf(profile)['rentTrackers']);
  }

  Future<void> saveRentTracker(
      String customerId, Map<String, dynamic> data) async {
    final profile = await this.profile(customerId) ?? {};
    final trackers = apiItems(_metadataOf(profile)['rentTrackers']);
    trackers.insert(0, {
      ...data,
      'id': data.s('id', 'rent-'),
      'updated_at': DateTime.now().toIso8601String(),
    });
    await _updateProfileMetadata(customerId, {'rentTrackers': trackers});
  }

  Future<List<Map<String, dynamic>>> _localPropertyListings() async {
    if (!await apiSession.hasToken()) return [];
    final profile =
        await this.profile(await apiSession.customerId() ?? '') ?? {};
    return apiItems(_metadataOf(profile)['propertyListings']);
  }

  Future<Map<String, num>> estimatePropertyValue(
      {required String propertyType, int? bhk, String? city}) async {
    final rows = await _gateway.searchCatalog(
        query: [propertyType, bhk, city]
            .where((value) => value != null && value.toString().isNotEmpty)
            .join(' '),
        type: 'property',
        limit: 20);
    final prices = rows
        .map((row) => row.n('price'))
        .where((price) => price > 0)
        .toList()
      ..sort();
    if (prices.isEmpty) return {};
    final avg =
        prices.fold<num>(0, (sum, price) => sum + price) / prices.length;
    return {'low': prices.first, 'average': avg, 'high': prices.last};
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
    return _gateway.comments(postId);
  }

  Future<void> createSocialPost(
      String userId, Map<String, dynamic> data) async {
    await _gateway.createPost(
      {
        'contentText': data['content_text'] ??
            data['contentText'] ??
            data['caption'] ??
            '',
        'mediaUrls': data['media_urls'] ?? data['mediaUrls'] ?? [],
        'postType': data['post_type'] ?? data['postType'] ?? 'text',
        'visibility': data['visibility'] ?? 'public',
        'location': data['location'],
        'tags': data['tags'] ?? [],
        'category': data['category'] ?? 'general',
      },
    );
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

  Future<void> likeSocialPost(String postId) => _gateway.likePost(postId);
  Future<void> unlikeSocialPost(String postId) => _gateway.unlikePost(postId);
  Future<void> saveSocialPost(String postId) => _gateway.savePost(postId);
  Future<void> unsaveSocialPost(String postId) => _gateway.unsavePost(postId);
  Future<void> shareSocialPost(String postId) => _gateway.sharePost(postId);
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
          'variantId': variantId
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

  Future<CartSummary> cartSummary({int pointsUsed = 0, num couponDiscount = 0}) async {
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
    num? grandTotal;
    if (await apiSession.hasToken() && items.isNotEmpty) {
      final quote = await _gateway.quoteCart(redeemPoints: pointsUsed);
      platformFee =
          quote.n('platformFee', quote.n('platform_fee')).toDouble();
      deliveryFee =
          quote.n('deliveryFee', quote.n('delivery_fee')).toDouble();
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
      final gt = quote['grandTotal'] ?? quote['grand_total'];
      if (gt != null) {
        grandTotal = quote.n('grandTotal', quote.n('grand_total')) -
            couponDiscount;
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
      couponDiscount: couponDiscount,
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
  }) async {
    if (summary.items.isEmpty) throw const ApiException('Cart is empty.');
    Map<String, dynamic> order;
    if (await apiSession.hasToken()) {
      order = await _gateway.createOrderFromCart(
        redeemPoints: summary.pointsUsed,
        vendorId:
            summary.items.length == 1 ? summary.items.first.vendorId : null,
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
        'addressId': address?.s('id'),
        'address': address,
        'paymentMode': paymentMode,
        'redeemPoints': summary.pointsUsed,
      });
    }
    if (paymentMode == 'cod') {
      await clearCart();
    }
    return _normalizeOrder(order);
  }

  Future<Map<String, dynamic>> createPaymentIntentForOrder({
    required String orderId,
    required num amount,
  }) =>
      _gateway.createPaymentIntent({
        'orderId': orderId,
        'amount': amount.toStringAsFixed(2),
        'currency': 'INR',
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
      final products = rows
          .map((row) => row['product'] is Map
              ? Map<String, dynamic>.from(row['product'] as Map)
              : row)
          .toList();
      return products.map(_normalizeProduct).toList();
    }
    final ids = (await wishlist()).toList();
    final products = <Map<String, dynamic>>[];
    for (final id in ids) {
      final item = await product(id);
      if (item != null) products.add(item);
    }
    return products;
  }

  Future<String?> selectedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_locationKey);
  }

  Future<void> saveSelectedLocation(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_locationKey, value);
  }

  CartItem _cartItemFromApi(Map<String, dynamic> row) {
    final product = row['product'] is Map
        ? Map<String, dynamic>.from(row['product'] as Map)
        : <String, dynamic>{};
    final merged = {...product, ...row};
    final productId =
        merged.s('productId', merged.s('product_id', merged.s('id')));
    final meta = merged['metadata'] is Map
        ? Map<String, dynamic>.from(merged['metadata'] as Map)
        : <String, dynamic>{};
    final variantId = merged.s(
        'variationId',
        merged.s(
            'variation_id', meta.s('variantId', meta.s('variationId'))));
    return CartItem(
      id: merged.s('itemId', merged.s('item_id', productId)),
      productId: productId,
      title: merged.s('title', merged.s('name', merged.s('productName'))),
      price: merged.n('unitPrice', merged.n('price', merged.n('finalPrice'))),
      qty: merged.i('quantity', merged.i('qty', 1)),
      vendor: merged.s('vendorName', merged.s('vendor_name')),
      vendorId: merged.s('vendorId', merged.s('vendor_id')),
      image: merged.s('image', merged.s('thumbnailUrl')),
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
    final media = _mediaList(row).map(resolveMediaUrl).where((u) => u.isNotEmpty).toList();
    final postType =
        row.s('post_type', row.s('postType', row.s('media_type', row.s('mediaType'))));
    return {
      ...row,
      'id': row.s('id', row.s('postId')),
      'user_id': row.s('user_id', row.s('userId', author.s('id'))),
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
      'likes_count':
          row.i('likes_count', row.i('like_count', row.i('likesCount'))),
      'comments_count': row.i(
          'comments_count', row.i('comment_count', row.i('commentsCount'))),
      'liked': row['liked'] == true ||
          row['isLiked'] == true ||
          row['hasLiked'] == true,
      'saved': row['saved'] == true ||
          row['isSaved'] == true ||
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
          row.s('paymentRefId',
              row.s('paymentReferenceId', row.s('paymentId')))),
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
      'gst': row.n('gst', row.n('gstOnPlatformFee', meta.n('gstOnPlatformFee'))),
      'subtotal':
          row.n('subtotal', row.n('itemSubtotal', meta.n('itemSubtotal'))),
    };
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

  Map<String, dynamic> _normalizeBooking(Map<String, dynamic> row) => {
        ...row,
        'id': row.s('id', row.s('bookingId')),
        'service_id': row.s('service_id', row.s('serviceId')),
        'service_name':
            row.s('service_name', row.s('serviceName', row.s('serviceTitle'))),
        'vendor_name': row.s('vendor_name', row.s('vendorName')),
        'booking_date': row.s('booking_date', row.s('bookingDate')),
        'time_slot': row.s('time_slot', row.s('timeSlot')),
        'total_amount': row.n('total_amount', row.n('totalAmount')),
        'status': row.s('status', 'pending'),
      };
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

  Map<String, dynamic> _addressPayload(Map<String, dynamic> address) => {
        'label': address.s('label', address.s('name', 'Home')),
        'fullName': address.s('fullName', address.s('name', 'Customer')),
        'phone': address.s('phone', address.s('mobile')),
        'addressLine1': address.s('line1', address.s('address_line')),
        'addressLine2': address.s('line2'),
        'city': address.s('city'),
        'state': address.s('state'),
        'postalCode': address.s('pincode', address.s('postalCode')),
        'country': address.s('country', 'India'),
        'latitude': address['latitude'],
        'longitude': address['longitude'],
        'isDefault': address['is_default'] ?? address['isDefault'] ?? false,
      };

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
}
