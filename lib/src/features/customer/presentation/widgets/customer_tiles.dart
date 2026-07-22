import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/map_ext.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/remote_image.dart';

class ProductTile extends StatelessWidget {
  const ProductTile({required this.product, this.compact = false, super.key});

  final Map<String, dynamic> product;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push('/app/product/${product.s('id')}'),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                color: AppColors.productSurface,
                child: RemoteImage(
                  url: product.s('image'),
                  height: compact ? 100 : 140,
                  width: double.infinity,
                  borderRadius: 12,
                ),
              ),
              const Positioned(
                right: 7,
                top: 7,
                child: Icon(Icons.favorite_border_rounded,
                    size: 20, color: AppColors.muted),
              ),
              Positioned(
                left: 7,
                bottom: 7,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(5),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 4)
                    ],
                  ),
                  child: const Row(children: [
                    Icon(Icons.timer_outlined, size: 11),
                    SizedBox(width: 3),
                    Text('10 MINS',
                        style: TextStyle(
                            fontSize: 9, fontWeight: FontWeight.w900)),
                  ]),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(9, 9, 9, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.s('title', 'Product'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, height: 1.15)),
                const SizedBox(height: 4),
                Text(
                    product.s('vendor_name').isEmpty
                        ? '1 unit'
                        : product.s('vendor_name'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 12)),
                if (product.containsKey('orderCount') ||
                    product.containsKey('order_count')) ...[
                  const SizedBox(height: 3),
                  Text(
                    '${product.i('orderCount', product.i('order_count'))} completed orders',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                        child: Text(money(product.n('price')),
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: AppColors.brandDark))),
                    SizedBox(
                      height: 34,
                      child: OutlinedButton(
                        onPressed: () =>
                            context.push('/app/product/${product.s('id')}'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(64, 34),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        child: const Text('ADD'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ServiceTile extends StatelessWidget {
  const ServiceTile({required this.service, super.key});

  final Map<String, dynamic> service;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push('/app/service/${service.s('id')}'),
      child: Row(
        children: [
          RemoteImage(url: service.s('image'), width: 82, height: 82),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service.s('title', 'Service'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(service.s('category_name'),
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 12)),
                if (service.containsKey('bookingCount') ||
                    service.containsKey('booking_count')) ...[
                  const SizedBox(height: 3),
                  Text(
                    '${service.i('bookingCount', service.i('booking_count'))} completed bookings',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ],
                const SizedBox(height: 6),
                Text(money(service.n('price')),
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, color: AppColors.primary)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class ClassifiedTile extends StatelessWidget {
  const ClassifiedTile({required this.ad, super.key});

  final Map<String, dynamic> ad;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push('/app/classifieds/${ad.s('id')}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RemoteImage(
              url: ad.s('image_url', ad.s('image')), width: 88, height: 88),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ad.s('title', 'Classified'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(ad.s('category'),
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 12)),
                const SizedBox(height: 6),
                Text(
                    ad.n('price') > 0 ? money(ad.n('price')) : ad.s('location'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, color: AppColors.primary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PropertyTile extends StatelessWidget {
  const PropertyTile({required this.property, super.key});

  final Map<String, dynamic> property;

  String get _cover {
    final direct = property.s('image_url', property.s('cover_image', property.s('coverImage')));
    if (direct.isNotEmpty) return direct;
    final images = property['images'];
    if (images is List && images.isNotEmpty) {
      final first = images.first;
      if (first is String && first.trim().isNotEmpty) return first.trim();
      if (first is Map) {
        return (first['url'] ?? first['src'] ?? first['imageUrl'] ?? '').toString();
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final bhk = property.s('bhk');
    final place = property.s('locality', property.s('city'));
    final metaBits = <String>[
      if (bhk.isNotEmpty && bhk != '0') '$bhk BHK',
      if (place.isNotEmpty) place,
    ];
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/app/find-home/${property.s('id')}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: RemoteImage(
                url: _cover,
                height: 168,
                width: double.infinity,
                borderRadius: 0,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          property.s('title', 'Property'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusBadge(property.s('transaction_type', 'sale')),
                    ],
                  ),
                  if (metaBits.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      metaBits.join(' · '),
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    money(property.n('price')),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
