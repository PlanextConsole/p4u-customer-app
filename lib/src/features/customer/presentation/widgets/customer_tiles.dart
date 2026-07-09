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
      onTap: () => context.go('/app/product/${product.s('id')}'),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RemoteImage(
            url: product.s('image'),
            height: compact ? 100 : 134,
            width: double.infinity,
            borderRadius: 14,
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.s('title', 'Product'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(product.s('vendor_name'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 12)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                        child: Text(money(product.n('price')),
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary))),
                    if (product.n('rating') > 0) _Rating(product.n('rating')),
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
      onTap: () => context.go('/app/service/${service.s('id')}'),
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
      onTap: () => context.go('/app/classifieds/${ad.s('id')}'),
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

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.go('/app/find-home/${property.s('id')}'),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RemoteImage(
              url: property.s('image_url', property.s('cover_image')),
              height: 150,
              width: double.infinity),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                        child: Text(property.s('title', 'Property'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(fontWeight: FontWeight.w900))),
                    StatusBadge(property.s('transaction_type', 'sale')),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                    '${property.s('bhk')} BHK - ${property.s('locality', property.s('city'))}',
                    style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 8),
                Text(money(property.n('price')),
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                        fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Rating extends StatelessWidget {
  const _Rating(this.value);
  final num value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: .15),
          borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          const Icon(Icons.star_rounded, size: 13, color: AppColors.warning),
          const SizedBox(width: 2),
          Text(value.toStringAsFixed(1),
              style:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
