import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/api_client.dart';
import '../../../core/utils/map_ext.dart';
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
    final rows = await _gateway.browseProducts(
        categoryId: category, query: search, sort: sort, limit: 50);
    return rows.map(_normalizeProduct).toList();
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
    required String address,
    String? notes,
  }) async {
    await _gateway.createServiceBooking(
      {
        'vendorId': service.s('vendor_id', service.s('vendorId')),
        'serviceId': service.s('id', service.s('serviceId')),
        'bookingDate': date.toIso8601String().split('T').first,
        'timeSlot': timeSlot,
        'address': address,
        'notes': notes,
        'totalAmount': service.n('price').toStringAsFixed(2),
      },
    );
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
    final rows = await _gateway.customerOrders(id);
    return rows.map(_normalizeOrder).toList();
  }

  Future<List<Map<String, dynamic>>> bookings(String customerId) async {
    if (!await apiSession.hasToken()) return [];
    final rows = await _gateway.myBookings();
    return rows.map(_normalizeBooking).toList();
  }

  Future<void> cancelBooking(String bookingId) async {
    await _gateway.cancelBooking(bookingId);
  }

  Future<Map<String, dynamic>?> order(String id) async {
    final data = await _gateway.order(id);
    return _normalizeOrder(data);
  }

  Future<void> placeOrder({
    required String customerId,
    required CartSummary summary,
    required Map<String, dynamic>? address,
    String paymentMode = 'cod',
  }) async {
    if (summary.items.isEmpty) throw const ApiException('Cart is empty.');
    if (await apiSession.hasToken()) {
      await _gateway.createOrderFromCart(
        redeemPoints: summary.pointsUsed,
        vendorId:
            summary.items.length == 1 ? summary.items.first.vendorId : null,
      );
    } else {
      await _gateway.createDirectOrder({
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
    await clearCart();
  }

  Future<Map<String, dynamic>?> profile(String customerId) async {
    if (!await apiSession.hasToken()) return null;
    final data = await _gateway.myProfile();
    final profile =
        apiObject(data['profile'] ?? data['customer'] ?? data['user'] ?? data);
    if (profile != null) await apiSession.saveProfile(profile);
    return profile;
  }

  Future<Map<String, dynamic>> profileWithStats(String customerId) async {
    final customer = await profile(customerId) ?? {};
    final orderCount = await orders(customerId);
    final addresses = await customerAddresses(customerId);
    final reward = await rewardPoints(customerId);
    return {
      ...customer,
      'total_orders': orderCount.length,
      'saved_addresses': addresses.length,
      if (reward['points'] != null) 'wallet_points': reward['points'],
    };
  }

  Future<void> updateProfile(
      String customerId, Map<String, dynamic> data) async {
    final payload = {
      if (data['name'] != null) 'fullName': data['name'],
      if (data['fullName'] != null) 'fullName': data['fullName'],
      if (data['email'] != null) 'email': data['email'],
      if (data['avatar_url'] != null) 'avatarUrl': data['avatar_url'],
      if (data['avatarUrl'] != null) 'avatarUrl': data['avatarUrl'],
      'metadata': data,
    };
    await _gateway.updateMyProfile(payload);
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
    return apiItems(data['transactions'] ?? data['items'] ?? data);
  }

  Future<List<Map<String, dynamic>>> referrals(String customerId) async {
    if (!await apiSession.hasToken()) return [];
    return apiItems(await _gateway.referralInfo());
  }

  Future<Map<String, dynamic>> rewardPoints(String customerId) async {
    if (!await apiSession.hasToken()) return {};
    return _gateway.rewardPoints();
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
      'status': 'submitted',
      'submittedAt': DateTime.now().toIso8601String(),
    };
    await _updateProfileMetadata(customerId, {'kycDocuments': docs});
  }

  Future<List<Map<String, dynamic>>> classifieds(
      {String? category, String? search}) async {
    final rows = await _gateway.classifiedContent(
        category: category, query: search, limit: 50);
    return rows.map(_normalizeClassified).toList();
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

  Future<CartSummary> cartSummary({int pointsUsed = 0}) async {
    final items = await cartItems();
    final subtotal =
        items.fold<num>(0, (sum, item) => sum + item.price * item.qty);
    final tax = items.fold<num>(0, (sum, item) => sum + item.tax * item.qty);
    final discount =
        items.fold<num>(0, (sum, item) => sum + item.discount * item.qty);
    var platformFee = 0;
    if (await apiSession.hasToken()) {
      final quote = await _gateway.quoteCart(redeemPoints: pointsUsed);
      platformFee = quote.i('platformFee', quote.i('platform_fee'));
    }
    return CartSummary(
        items: items,
        subtotal: subtotal,
        tax: tax,
        discount: discount,
        platformFee: platformFee,
        pointsUsed: pointsUsed);
  }

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

  Map<String, dynamic> _normalizeClassified(Map<String, dynamic> row) => {
        ...row,
        'id': row.s('id', row.s('classifiedId')),
        'title': row.s('title', row.s('name')),
        'price': row.n('price', row.n('amount')),
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

  Map<String, dynamic> _normalizeSocialPost(Map<String, dynamic> row) {
    final author = row['author'] is Map
        ? Map<String, dynamic>.from(row['author'] as Map)
        : row['user'] is Map
            ? Map<String, dynamic>.from(row['user'] as Map)
            : <String, dynamic>{};
    final media = _mediaList(row);
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
      'media_urls': media,
      'image_url': media.isNotEmpty
          ? media.first
          : _imageFrom(row,
              const ['imageUrl', 'image_url', 'thumbnailUrl', 'thumbnail_url']),
      'likes_count':
          row.i('likes_count', row.i('like_count', row.i('likesCount'))),
      'comments_count': row.i(
          'comments_count', row.i('comment_count', row.i('commentsCount'))),
    };
  }

  Map<String, dynamic> _normalizeVendor(Map<String, dynamic> row) => {
        ...row,
        'id': row.s('id', row.s('vendorId')),
        'business_name': row.s('business_name', row.s('businessName')),
        'name': row.s('name', row.s('ownerName')),
        'mobile': row.s('mobile', row.s('phone')),
      };

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

  Map<String, dynamic> _normalizeOrder(Map<String, dynamic> row) => {
        ...row,
        'id': row.s('id', row.s('orderId')),
        'total': row.n('total', row.n('totalAmount', row.n('grandTotal'))),
        'created_at': row.s('created_at', row.s('createdAt')),
        'payment_status': row.s('payment_status', row.s('paymentStatus')),
      };

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
        'name': row.s('name', row.s('label')),
        'mobile': row.s('mobile', row.s('phone')),
        'address_line': row.s('address_line', row.s('line1')),
        'is_default': row['is_default'] ?? row['isDefault'] ?? false,
      };

  Map<String, dynamic> _addressPayload(Map<String, dynamic> address) => {
        'label': address.s('label', address.s('name', 'Home')),
        'line1': address.s('line1', address.s('address_line')),
        'line2': address.s('line2'),
        'city': address.s('city'),
        'state': address.s('state'),
        'pincode': address.s('pincode'),
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
