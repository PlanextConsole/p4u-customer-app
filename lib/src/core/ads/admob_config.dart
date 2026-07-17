import 'package:flutter/foundation.dart';

abstract final class AdMobConfig {
  static const publisherId = 'pub-6006362146695296';
  static const productionAppId =
      'ca-app-pub-6006362146695296~2940657010';
  static const productionBannerAdUnitId =
      'ca-app-pub-6006362146695296/8328252043';
  static const debugAppId =
      'ca-app-pub-3940256099942544~3347511713';
  static const debugBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';

  static String get bannerAdUnitId =>
      kReleaseMode ? productionBannerAdUnitId : debugBannerAdUnitId;
}
