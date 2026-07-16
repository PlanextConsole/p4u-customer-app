import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/api_client.dart';

class CustomerApi {
  CustomerApi({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  Future<Map<String, Object?>> _catalogLocationQuery() async {
    final prefs = await SharedPreferences.getInstance();
    final latitude = prefs.getDouble('p4u_customer_latitude');
    final longitude = prefs.getDouble('p4u_customer_longitude');
    Map<String, dynamic> profile = const {};
    final profileJson = prefs.getString('p4u_customer_profile');
    if (profileJson != null) {
      try {
        final decoded = jsonDecode(profileJson);
        if (decoded is Map) profile = Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return {
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (profile['district']?.toString().trim().isNotEmpty == true)
        'district': profile['district'].toString().trim(),
      if (profile['state']?.toString().trim().isNotEmpty == true)
        'state': profile['state'].toString().trim(),
    };
  }

  Future<Map<String, dynamic>> authHealth() =>
      _api.getJson('/api/auth/public/health');
  Future<List<Map<String, dynamic>>> occupations({String purpose = 'all'}) =>
      _api.getList('/api/auth/public/occupations', query: {'purpose': purpose});
  Future<Map<String, dynamic>> phoneOtpExchange(String idToken) =>
      _api.postJson(
        '/api/auth/public/phone/exchange',
        body: {'idToken': idToken, 'intendedRole': 'CUSTOMER'},
      );
  Future<Map<String, dynamic>> registerCustomerByPhone(
          Map<String, dynamic> body) =>
      _api.postJson('/api/auth/public/customer/register-by-phone', body: body);
  Future<Map<String, dynamic>> refreshToken(String refreshToken) =>
      _api.postJson('/api/auth/public/refresh',
          body: {'refreshToken': refreshToken});
  Future<Map<String, dynamic>> logout(String? refreshToken) =>
      _api.postJson('/api/auth/logout',
          body: {'refreshToken': refreshToken}, auth: true);

  Future<Map<String, dynamic>> catalogHealth() =>
      _api.getJson('/api/v1/catalog/public/health');
  Future<List<Map<String, dynamic>>> categories(
          {String? kind,
          int limit = 20,
          int offset = 0,
          bool includeInactive = false}) =>
      _api.getList('/api/v1/catalog/categories', query: {
        'limit': limit,
        'offset': offset,
        'kind': kind,
        'includeInactive': includeInactive
      });
  Future<List<Map<String, dynamic>>> categoryChildren(String categoryId,
          {String? kind}) =>
      _api.getList('/api/v1/catalog/categories/$categoryId/children',
          query: {'kind': kind});
  Future<List<Map<String, dynamic>>> vendors(
          {String? vendorKind, int limit = 20, int offset = 0}) async =>
      _api.getList('/api/v1/catalog/vendors', query: {
        'limit': limit,
        'offset': offset,
        'vendorKind': vendorKind,
        ...await _catalogLocationQuery()
      });
  Future<Map<String, dynamic>> vendor(String vendorId) async =>
      _api.getJson('/api/v1/catalog/vendors/$vendorId',
          query: await _catalogLocationQuery());
  Future<List<Map<String, dynamic>>> vendorProducts(String vendorId,
          {int limit = 20, int offset = 0}) async =>
      _api.getList('/api/v1/catalog/vendors/$vendorId/products', query: {
        'limit': limit,
        'offset': offset,
        ...await _catalogLocationQuery()
      });
  Future<Map<String, dynamic>> product(String productId) async =>
      _api.getJson('/api/v1/catalog/products/$productId',
          query: await _catalogLocationQuery());
  Future<List<Map<String, dynamic>>> services(
          {String? categoryId,
          String? query,
          int limit = 20,
          int offset = 0}) =>
      _api.getList('/api/v1/catalog/services', query: {
        'limit': limit,
        'offset': offset,
        'categoryId': categoryId,
        'q': query
      });
  Future<List<Map<String, dynamic>>> browseProducts(
          {String? categoryId,
          String? query,
          String? sort,
          int limit = 20,
          int offset = 0}) async =>
      _api.getList('/api/v1/catalog/browse/products', query: {
        'limit': limit,
        'offset': offset,
        'categoryId': categoryId,
        'q': query,
        'sort': sort,
        ...await _catalogLocationQuery()
      });
  Future<Map<String, dynamic>> service(String serviceId) =>
      _api.getJson('/api/v1/catalog/services/$serviceId');
  Future<List<Map<String, dynamic>>> serviceVendorOffers(String serviceId,
          {int limit = 20, int offset = 0}) async =>
      _api.getList('/api/v1/catalog/browse/services/$serviceId/vendors',
          query: {
            'limit': limit,
            'offset': offset,
            ...await _catalogLocationQuery()
          });
  Future<List<Map<String, dynamic>>> searchCatalog(
          {required String query,
          String? type,
          int limit = 20,
          int offset = 0}) async =>
      _api.getList('/api/v1/catalog/search', query: {
        'q': query,
        'type': type,
        'limit': limit,
        'offset': offset,
        ...await _catalogLocationQuery()
      });

  Future<Map<String, dynamic>> profileHealth() =>
      _api.getJson('/api/v1/profile/public/health');
  Future<Map<String, dynamic>> myProfile() =>
      _api.getJson('/api/v1/profile/me', auth: true);
  Future<Map<String, dynamic>> updateMyProfile(Map<String, dynamic> body) =>
      _api.patchJson('/api/v1/profile/me', body: body, auth: true);
  Future<List<Map<String, dynamic>>> addresses() =>
      _api.getList('/api/v1/profile/me/addresses', auth: true);
  Future<Map<String, dynamic>> createAddress(Map<String, dynamic> body) =>
      _api.postJson('/api/v1/profile/me/addresses', body: body, auth: true);
  Future<Map<String, dynamic>> updateAddress(
          String addressId, Map<String, dynamic> body) =>
      _api.putJson('/api/v1/profile/me/addresses/$addressId',
          body: body, auth: true);
  Future<Map<String, dynamic>> deleteAddress(String addressId) =>
      _api.deleteJson('/api/v1/profile/me/addresses/$addressId', auth: true);
  Future<List<Map<String, dynamic>>> wishlist() =>
      _api.getList('/api/v1/profile/me/wishlist', auth: true);
  Future<Map<String, dynamic>> addWishlistItem(String productId) =>
      _api.postJson('/api/v1/profile/me/wishlist',
          body: {'productId': productId}, auth: true);
  Future<Map<String, dynamic>> removeWishlistItem(String productId) =>
      _api.deleteJson('/api/v1/profile/me/wishlist/$productId', auth: true);
  Future<List<Map<String, dynamic>>> serviceWishlist() =>
      _api.getList('/api/v1/profile/me/service-wishlist', auth: true);
  Future<Map<String, dynamic>> referralInfo() =>
      _api.getJson('/api/v1/profile/me/referrals', auth: true);
  Future<Map<String, dynamic>> referralCode() =>
      _api.getJson('/api/v1/profile/me/referral-code', auth: true);
  Future<Map<String, dynamic>> rewardPoints() =>
      _api.getJson('/api/v1/profile/me/reward-points', auth: true);
  Future<Map<String, dynamic>> walletSummary() =>
      _api.getJson('/api/v1/profile/me/wallet', auth: true);

  Future<Map<String, dynamic>> commerceHealth() =>
      _api.getJson('/api/v1/commerce/public/health');
  Future<Map<String, dynamic>> cart() =>
      _api.getJson('/api/v1/commerce/cart', auth: true);
  Future<Map<String, dynamic>> replaceCart(List<Map<String, dynamic>> items) =>
      _api.putJson('/api/v1/commerce/cart', body: {'items': items}, auth: true);
  Future<Map<String, dynamic>> addCartItem(Map<String, dynamic> body) =>
      _api.postJson('/api/v1/commerce/cart/items', body: body, auth: true);
  Future<Map<String, dynamic>> updateCartItemQuantity(
          String itemId, int quantity) =>
      _api.patchJson('/api/v1/commerce/cart/items/$itemId',
          body: {'quantity': quantity}, auth: true);
  Future<Map<String, dynamic>> removeCartItem(String itemId) =>
      _api.deleteJson('/api/v1/commerce/cart/items/$itemId', auth: true);
  Future<Map<String, dynamic>> clearCart() =>
      _api.deleteJson('/api/v1/commerce/cart', auth: true);
  Future<Map<String, dynamic>> mergeCart(List<Map<String, dynamic>> items) =>
      _api.postJson('/api/v1/commerce/cart/merge',
          body: {'items': items}, auth: true);
  Future<Map<String, dynamic>> quoteCart({int redeemPoints = 0}) =>
      _api.postJson('/api/v1/commerce/cart/quote',
          body: {'redeemPoints': redeemPoints}, auth: true);
  Future<Map<String, dynamic>> createOrderFromCart(
      {int redeemPoints = 0, String? vendorId}) {
    final body = <String, dynamic>{};
    if (redeemPoints > 0) body['redeemPoints'] = redeemPoints;
    final v = vendorId?.trim();
    if (v != null && v.isNotEmpty) body['vendorId'] = v;
    return _api.postJson('/api/v1/commerce/orders/from-cart',
        body: body, auth: true);
  }

  Future<Map<String, dynamic>> createDirectOrder(Map<String, dynamic> body) =>
      _api.postJson('/api/v1/commerce/orders', body: body, auth: true);
  Future<List<Map<String, dynamic>>> customerOrders(String customerId) =>
      _api.getList('/api/v1/commerce/customers/$customerId/orders', auth: true);
  Future<Map<String, dynamic>> order(String orderId) =>
      _api.getJson('/api/v1/commerce/orders/$orderId', auth: true);
  Future<Map<String, dynamic>> cancelOrder(String orderId) =>
      _api.postJson('/api/v1/commerce/orders/$orderId/cancel', auth: true);
  Future<Map<String, dynamic>> checkoutQuote(Map<String, dynamic> body) =>
      _api.postJson('/api/v1/commerce/checkout/quote', body: body, auth: true);
  Future<Map<String, dynamic>> validateCoupon(Map<String, dynamic> body) => _api
      .postJson('/api/v1/commerce/coupons/validate', body: body, auth: true);
  Future<Map<String, dynamic>> createServiceBooking(
          Map<String, dynamic> body) =>
      _api.postJson('/api/v1/commerce/bookings', body: body, auth: true);
  Future<List<Map<String, dynamic>>> myBookings() =>
      _api.getList('/api/v1/commerce/bookings', auth: true);
  Future<Map<String, dynamic>> cancelBooking(String bookingId) =>
      _api.postJson('/api/v1/commerce/bookings/$bookingId/cancel', auth: true);
  Future<List<Map<String, dynamic>>> vendorBookingsFromCommerce() =>
      _api.getList('/api/v1/commerce/bookings/vendor', auth: true);
  Future<List<Map<String, dynamic>>> availableSlots(
      {String? vendorId, String? serviceId, String? date}) async {
    final data = await _api.getJson('/api/v1/commerce/bookings/available-slots',
        query: {'vendorId': vendorId, 'serviceId': serviceId, 'date': date},
        auth: true);
    final body = apiObject(data) ?? data;
    if (body['slots'] is List) return apiItems(body['slots']);
    if (data['slots'] is List) return apiItems(data['slots']);
    return apiItems(body);
  }

  Future<Map<String, dynamic>> createReview(Map<String, dynamic> body) =>
      _api.postJson('/api/v1/commerce/reviews', body: body, auth: true);
  Future<List<Map<String, dynamic>>> reviews(
          {String? targetType, String? targetId}) =>
      _api.getList('/api/v1/commerce/reviews',
          query: {'targetType': targetType, 'targetId': targetId}, auth: true);
  Future<Map<String, dynamic>> reviewSummary(
          {String? targetType, String? targetId}) =>
      _api.getJson('/api/v1/commerce/reviews/summary',
          query: {'targetType': targetType, 'targetId': targetId}, auth: true);

  Future<Map<String, dynamic>> paymentHealth() =>
      _api.getJson('/api/v1/payments/public/health');
  Future<Map<String, dynamic>> createPaymentIntent(Map<String, dynamic> body) =>
      _api.postJson('/api/v1/payments/intents', body: body, auth: true);
  Future<Map<String, dynamic>> paymentIntent(String intentId) =>
      _api.getJson('/api/v1/payments/intents/$intentId', auth: true);
  Future<Map<String, dynamic>> verifyPayment(Map<String, dynamic> body) =>
      _api.postJson('/api/v1/payments/verify', body: body, auth: true);

  Future<Map<String, dynamic>> contentHealth() =>
      _api.getJson('/api/v1/content/public/health');
  Future<List<Map<String, dynamic>>> banners(
          {int limit = 20, int offset = 0}) =>
      _api.getList('/api/v1/content/banners',
          query: {'limit': limit, 'offset': offset});
  Future<List<Map<String, dynamic>>> popups({int limit = 20, int offset = 0}) =>
      _api.getList('/api/v1/content/popups',
          query: {'limit': limit, 'offset': offset});
  Future<List<Map<String, dynamic>>> reels({int limit = 20, int offset = 0}) =>
      _api.getList('/api/v1/content/reels',
          query: {'limit': limit, 'offset': offset});
  Future<List<Map<String, dynamic>>> classifiedContent(
          {String? category,
          String? categoryId,
          String? query,
          int limit = 20,
          int offset = 0}) =>
      _api.getList('/api/v1/content/classified', query: {
        'category': category,
        'categoryId': categoryId,
        'q': query,
        'limit': limit,
        'offset': offset
      });
  Future<Map<String, dynamic>> classifiedItem(String id) =>
      _api.getJson('/api/v1/content/classified/$id');
  Future<List<Map<String, dynamic>>> classifiedCategories() =>
      _api.getList('/api/v1/content/classified/categories');
  Future<Map<String, dynamic>> createClassified(Map<String, dynamic> body) =>
      _api.postJson('/api/v1/content/classified', body: body, auth: true);
  Future<Map<String, dynamic>> homeContent() =>
      _api.getJson('/api/v1/content/home');
  Future<List<Map<String, dynamic>>> brands({int limit = 20, int offset = 0}) =>
      _api.getList('/api/v1/content/brands',
          query: {'limit': limit, 'offset': offset});
  Future<List<Map<String, dynamic>>> featuredProducts(
          {int limit = 20, int offset = 0}) =>
      _api.getList('/api/v1/content/featured-products',
          query: {'limit': limit, 'offset': offset});
  Future<List<Map<String, dynamic>>> serviceHighlights(
          {int limit = 20, int offset = 0}) =>
      _api.getList('/api/v1/content/service-highlights',
          query: {'limit': limit, 'offset': offset});
  Future<Map<String, dynamic>> newsletterSubscribe(String email) => _api
      .postJson('/api/v1/content/newsletter/subscribe', body: {'email': email});

  Future<Map<String, dynamic>> notificationsHealth() =>
      _api.getJson('/api/v1/notifications/public/health');
  Future<List<Map<String, dynamic>>> notifications() =>
      _api.getList('/api/v1/notifications/me', auth: true);
  Future<Map<String, dynamic>> markNotificationRead(String notificationId) =>
      _api.postJson('/api/v1/notifications/me/$notificationId/read',
          auth: true);
  Future<Map<String, dynamic>> registerDeviceToken(
          {required String deviceToken, required String platform}) =>
      _api.postJson('/api/v1/notifications/devices/register',
          body: {'deviceToken': deviceToken, 'platform': platform}, auth: true);

  Future<Map<String, dynamic>> socialHealth() =>
      _api.getJson('/api/v1/social/public/health');
  Future<List<Map<String, dynamic>>> feed() =>
      _api.getList('/api/v1/social/feed', auth: true);
  Future<List<Map<String, dynamic>>> publicFeed() =>
      _api.getList('/api/v1/social/feed/public');
  Future<Map<String, dynamic>> post(String postId) =>
      _api.getJson('/api/v1/social/posts/$postId', auth: true);
  Future<Map<String, dynamic>> createPost(Map<String, dynamic> body) =>
      _api.postJson('/api/v1/social/posts', body: body, auth: true);
  Future<Map<String, dynamic>> deletePost(String postId) =>
      _api.deleteJson('/api/v1/social/posts/$postId', auth: true);
  Future<Map<String, dynamic>> likePost(String postId) =>
      _api.postJson('/api/v1/social/posts/$postId/like', auth: true);
  Future<Map<String, dynamic>> unlikePost(String postId) =>
      _api.deleteJson('/api/v1/social/posts/$postId/like', auth: true);
  Future<Map<String, dynamic>> sharePost(String postId) =>
      _api.postJson('/api/v1/social/posts/$postId/share', auth: true);
  Future<Map<String, dynamic>> savePost(String postId) =>
      _api.postJson('/api/v1/social/posts/$postId/save', auth: true);
  Future<Map<String, dynamic>> unsavePost(String postId) =>
      _api.deleteJson('/api/v1/social/posts/$postId/save', auth: true);
  Future<List<Map<String, dynamic>>> savedPosts() =>
      _api.getList('/api/v1/social/posts/saved', auth: true);
  Future<List<Map<String, dynamic>>> trendingTags() =>
      _api.getList('/api/v1/social/explore/tags');
  Future<List<Map<String, dynamic>>> trendingPlaces() =>
      _api.getList('/api/v1/social/explore/places');
  Future<Map<String, dynamic>> mySocialProfile() =>
      _api.getJson('/api/v1/social/users/me/profile', auth: true);
  Future<Map<String, dynamic>> userSocialProfile(String userId) =>
      _api.getJson('/api/v1/social/users/$userId/profile', auth: true);
  Future<List<Map<String, dynamic>>> userPosts(String userId) =>
      _api.getList('/api/v1/social/users/$userId/posts', auth: true);
  Future<Map<String, dynamic>> followUser(String userId) =>
      _api.postJson('/api/v1/social/users/$userId/follow', auth: true);
  Future<Map<String, dynamic>> unfollowUser(String userId) =>
      _api.deleteJson('/api/v1/social/users/$userId/follow', auth: true);
  Future<List<Map<String, dynamic>>> followers(String userId) =>
      _api.getList('/api/v1/social/users/$userId/followers', auth: true);
  Future<List<Map<String, dynamic>>> following(String userId) =>
      _api.getList('/api/v1/social/users/$userId/following', auth: true);
  Future<List<Map<String, dynamic>>> suggestions({String? query}) =>
      _api.getList('/api/v1/social/users/suggestions',
          query: {'q': query}, auth: true);
  Future<List<Map<String, dynamic>>> comments(String postId) =>
      _api.getList('/api/v1/social/posts/$postId/comments', auth: true);
  Future<Map<String, dynamic>> createComment(
          String postId, Map<String, dynamic> body) =>
      _api.postJson('/api/v1/social/posts/$postId/comments',
          body: body, auth: true);
  Future<List<Map<String, dynamic>>> conversations() =>
      _api.getList('/api/v1/social/messages/conversations', auth: true);
  Future<Map<String, dynamic>> openConversation(String participantId) =>
      _api.postJson('/api/v1/social/messages/conversations',
          body: {'participantId': participantId}, auth: true);
  Future<List<Map<String, dynamic>>> conversationMessages(
          String conversationId) =>
      _api.getList(
          '/api/v1/social/messages/conversations/$conversationId/messages',
          auth: true);
  Future<Map<String, dynamic>> sendMessage(
          String conversationId, Map<String, dynamic> body) =>
      _api.postJson(
          '/api/v1/social/messages/conversations/$conversationId/messages',
          body: body,
          auth: true);
  Future<Map<String, dynamic>> markConversationRead(String conversationId) =>
      _api.postJson(
          '/api/v1/social/messages/conversations/$conversationId/read',
          auth: true);
  Future<Map<String, dynamic>> typing(String conversationId, bool isTyping) =>
      _api.postJson(
          '/api/v1/social/messages/conversations/$conversationId/typing',
          body: {'isTyping': isTyping},
          auth: true);
  Future<List<Map<String, dynamic>>> storyFeed() =>
      _api.getList('/api/v1/social/stories/feed', auth: true);
  Future<List<Map<String, dynamic>>> myStories() =>
      _api.getList('/api/v1/social/stories/me', auth: true);
  Future<Map<String, dynamic>> createStory(Map<String, dynamic> body) =>
      _api.postJson('/api/v1/social/stories', body: body, auth: true);
  Future<Map<String, dynamic>> deleteStory(String storyId) =>
      _api.deleteJson('/api/v1/social/stories/$storyId', auth: true);
  Future<List<Map<String, dynamic>>> feedAds({int limit = 5}) => _api
      .getList('/api/v1/social/feed/ads', query: {'limit': limit}, auth: true);
  Future<Map<String, dynamic>> uploadSocialMedia(File file) =>
      _api.uploadFile('/api/v1/social/upload', file, auth: true);
  Future<Map<String, dynamic>> uploadMultipleSocialMedia(List<File> files) =>
      _api.uploadFiles('/api/v1/social/upload/multiple', files, auth: true);
  Future<Map<String, dynamic>> viewStory(String storyId) =>
      _api.postJson('/api/v1/social/stories/$storyId/view', auth: true);
  Future<List<Map<String, dynamic>>> socialNotifications() =>
      _api.getList('/api/v1/social/notifications/me', auth: true);
  Future<Map<String, dynamic>> mySocialSettings() =>
      _api.getJson('/api/v1/social/users/me/settings', auth: true);
  Future<Map<String, dynamic>> updateMySocialSettings(
          Map<String, dynamic> body) =>
      _api.patchJson('/api/v1/social/users/me/settings',
          body: body, auth: true);
  Future<Map<String, dynamic>> likeStory(String storyId) =>
      _api.postJson('/api/v1/social/stories/$storyId/like', auth: true);
  Future<Map<String, dynamic>> deleteSocialMedia(String mediaId) =>
      _api.deleteJson('/api/v1/social/media/$mediaId', auth: true);
  String publicSocialMediaFileUrl(String mediaId) =>
      '${ApiClient.baseUrl}/socio-uploads/media/$mediaId';
}
