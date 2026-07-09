import 'dart:convert';

import '../../../core/utils/map_ext.dart';

class CustomerHomeData {
  const CustomerHomeData({
    required this.banners,
    required this.categories,
    required this.serviceCategories,
    required this.products,
    required this.services,
    required this.storeBanners,
    required this.assets,
  });

  final List<Map<String, dynamic>> banners;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> serviceCategories;
  final List<Map<String, dynamic>> products;
  final List<Map<String, dynamic>> services;
  final List<Map<String, dynamic>> storeBanners;
  final Map<String, String> assets;

  static const empty = CustomerHomeData(
    banners: [],
    categories: [],
    serviceCategories: [],
    products: [],
    services: [],
    storeBanners: [],
    assets: {},
  );
}

class CartItem {
  const CartItem({
    required this.id,
    required this.productId,
    required this.title,
    required this.price,
    required this.qty,
    required this.vendor,
    required this.vendorId,
    this.image,
    this.parentItemId,
    this.variantId,
    this.selectedAttributes,
    this.tax = 0,
    this.discount = 0,
    this.maxPoints = 0,
  });

  final String id;
  final String productId;
  final String title;
  final num price;
  final int qty;
  final String vendor;
  final String vendorId;
  final String? image;
  final String? parentItemId;
  final String? variantId;
  final Map<String, String>? selectedAttributes;
  final num tax;
  final num discount;
  final int maxPoints;

  num get lineTotal => (price - discount + tax) * qty;

  CartItem copyWith({int? qty}) => CartItem(
        id: id,
        productId: productId,
        title: title,
        price: price,
        qty: qty ?? this.qty,
        vendor: vendor,
        vendorId: vendorId,
        image: image,
        parentItemId: parentItemId,
        variantId: variantId,
        selectedAttributes: selectedAttributes,
        tax: tax,
        discount: discount,
        maxPoints: maxPoints,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'product_id': productId,
        'title': title,
        'price': price,
        'qty': qty,
        'vendor': vendor,
        'vendor_id': vendorId,
        'image': image,
        'parent_item_id': parentItemId,
        'variant_id': variantId,
        'selected_attributes': selectedAttributes,
        'tax': tax,
        'discount': discount,
        'max_points': maxPoints,
      };

  factory CartItem.fromJson(Map<String, dynamic> json) {
    final attrs = json['selected_attributes'];
    return CartItem(
      id: json.s('id'),
      productId: json.s('product_id', json.s('productId', json.s('id'))),
      title: json.s('title'),
      price: json.n('price'),
      qty: json.i('qty', 1),
      vendor: json.s('vendor'),
      vendorId: json.s('vendor_id'),
      image: json['image']?.toString(),
      parentItemId: json['parent_item_id']?.toString(),
      variantId: json['variant_id']?.toString(),
      selectedAttributes: attrs is Map
          ? attrs
              .map((key, value) => MapEntry(key.toString(), value.toString()))
          : null,
      tax: json.n('tax'),
      discount: json.n('discount'),
      maxPoints: json.i('max_points', json.i('maxPoints')),
    );
  }
}

class CartSummary {
  const CartSummary({
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.discount,
    required this.platformFee,
    required this.pointsUsed,
  });

  final List<CartItem> items;
  final num subtotal;
  final num tax;
  final num discount;
  final num platformFee;
  final int pointsUsed;

  num get total => subtotal + tax + platformFee - discount - pointsUsed;
  int get count => items.fold(0, (sum, item) => sum + item.qty);
}

String encodeCart(List<CartItem> items) =>
    jsonEncode(items.map((item) => item.toJson()).toList());

List<CartItem> decodeCart(String? encoded) {
  if (encoded == null || encoded.isEmpty) return [];
  final value = jsonDecode(encoded);
  if (value is! List) return [];
  return value
      .whereType<Map>()
      .map((item) => CartItem.fromJson(Map<String, dynamic>.from(item)))
      .toList();
}
