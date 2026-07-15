import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/auth_pages.dart';
import 'features/customer/presentation/pages/account_pages.dart';
import 'features/customer/presentation/pages/commerce_pages.dart';
import 'features/customer/presentation/pages/property_pages.dart';
import 'features/customer/presentation/pages/service_classified_pages.dart';
import 'features/customer/presentation/pages/social_pages.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final protectedPaths = <String>[
    '/app/cart',
    '/app/payment',
    '/app/orders',
    '/app/bookings',
    '/app/profile',
    '/app/kyc',
    '/app/wallet',
    '/app/wishlist',
    '/app/referrals',
    '/app/classifieds/post',
    '/app/vendor-register',
    '/app/support',
    '/app/change-password',
    '/app/account-control',
    '/app/social',
    '/app/find-home/post',
    '/app/find-home/my-properties',
    '/app/find-home/saved',
    '/app/find-home/saved-searches',
    '/app/find-home/messages',
    '/app/find-home/rent-tracker',
  ];

  return GoRouter(
    initialLocation: '/app',
    redirect: (context, state) {
      final auth = ref.read(customerAuthStateProvider).valueOrNull;
      final path = state.uri.path;
      final needsAuth = protectedPaths.any(
          (protected) => path == protected || path.startsWith('$protected/'));
      if (needsAuth && auth == null) {
        final returnTo = Uri.encodeComponent(state.uri.toString());
        return '/app/login?returnTo=$returnTo';
      }
      if ((path == '/app/login' || path == '/app/register') && auth != null) {
        final returnTo = state.uri.queryParameters['returnTo'];
        if (returnTo != null &&
            returnTo.startsWith('/app') &&
            !returnTo.startsWith('/app/login') &&
            !returnTo.startsWith('/app/register')) {
          return returnTo;
        }
        return '/app';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', redirect: (_, __) => '/app'),
      GoRoute(
          path: '/auth/callback', builder: (_, __) => const CustomerHomePage()),
      GoRoute(path: '/app', builder: (_, __) => const CustomerHomePage()),
      GoRoute(path: '/app/home', redirect: (_, __) => '/app'),
      GoRoute(
          path: '/app/login', builder: (_, __) => const CustomerLoginPage()),
      GoRoute(
          path: '/app/phone-login',
          builder: (_, __) => const CustomerLoginPage()),
      GoRoute(
          path: '/app/register',
          builder: (_, __) => const CustomerRegisterPage()),
      GoRoute(
          path: '/app/forgot-password',
          builder: (_, __) => const ForgotPasswordPage()),
      GoRoute(
          path: '/app/reset-password',
          builder: (_, __) => const ResetPasswordPage()),
      GoRoute(
          path: '/app/set-password',
          builder: (_, __) => const SetPasswordPage()),
      GoRoute(
          path: '/app/set-location',
          builder: (_, __) => const SetLocationPage()),
      GoRoute(path: '/app/terms', builder: (_, __) => const TermsPage()),
      GoRoute(
          path: '/app/privacy', builder: (_, __) => const PrivacyPolicyPage()),
      GoRoute(
          path: '/app/cms/:slug',
          builder: (_, state) =>
              CustomerCMSPage(slug: state.pathParameters['slug']!)),
      GoRoute(
          path: '/app/browse', builder: (_, __) => const CustomerBrowsePage()),
      GoRoute(
          path: '/app/product/:id',
          builder: (_, state) =>
              CustomerProductPage(id: state.pathParameters['id']!)),
      GoRoute(
          path: '/app/vendor/:id',
          builder: (_, state) =>
              CustomerVendorPage(id: state.pathParameters['id']!)),
      GoRoute(path: '/app/cart', builder: (_, __) => const CustomerCartPage()),
      GoRoute(path: '/app/payment', builder: (_, __) => const PaymentPage()),
      GoRoute(
          path: '/app/orders', builder: (_, __) => const CustomerOrdersPage()),
      GoRoute(
          path: '/app/bookings',
          builder: (_, __) => const CustomerBookingsPage()),
      GoRoute(
          path: '/app/orders/:orderId',
          builder: (_, state) => CustomerOrderDetailPage(
              orderId: state.pathParameters['orderId']!)),
      GoRoute(
          path: '/app/profile',
          builder: (_, __) => const CustomerProfilePage()),
      GoRoute(
          path: '/app/profile/edit',
          builder: (_, __) => const CustomerProfileEditPage()),
      GoRoute(path: '/app/kyc', builder: (_, __) => const CustomerKYCPage()),
      GoRoute(
          path: '/app/wallet', builder: (_, __) => const CustomerWalletPage()),
      GoRoute(
          path: '/app/wishlist',
          builder: (_, __) => const CustomerWishlistPage()),
      GoRoute(
          path: '/app/referrals',
          builder: (_, __) => const CustomerReferralPage()),
      GoRoute(
          path: '/app/services',
          builder: (_, __) => const CustomerServicesPage()),
      GoRoute(
          path: '/app/service/:id',
          builder: (_, state) =>
              CustomerServiceDetailPage(id: state.pathParameters['id']!)),
      GoRoute(
          path: '/app/classifieds',
          builder: (_, __) => const CustomerClassifiedsPage()),
      GoRoute(
          path: '/app/classifieds/post',
          builder: (_, __) => const CustomerPostAdPage()),
      GoRoute(
          path: '/app/classifieds/:id',
          builder: (_, state) =>
              CustomerClassifiedDetailPage(id: state.pathParameters['id']!)),
      GoRoute(
          path: '/app/vendor-register',
          builder: (_, __) => const VendorRegisterPage()),
      GoRoute(
          path: '/app/support',
          builder: (_, __) => const CustomerSupportPage()),
      GoRoute(
          path: '/app/change-password',
          builder: (_, __) => const CustomerChangePasswordPage()),
      GoRoute(
          path: '/app/account-control',
          builder: (_, __) => const AccountControlPage()),
      GoRoute(path: '/app/social', builder: (_, __) => const SocialFeedPage()),
      GoRoute(
          path: '/app/social/create',
          builder: (_, __) => const SocialCreatePostPage()),
      GoRoute(
          path: '/app/social/add-story',
          builder: (_, __) => const SocialAddStoryPage()),
      GoRoute(
          path: '/app/social/profile',
          builder: (_, __) => const SocialProfilePage()),
      GoRoute(
          path: '/app/social/explore',
          builder: (_, __) => const SocialExplorePage()),
      GoRoute(
          path: '/app/social/reels',
          builder: (_, __) => const SocialReelsPage()),
      GoRoute(
          path: '/app/social/stories/:userId',
          builder: (_, state) =>
              SocialStoryViewerPage(userId: state.pathParameters['userId']!)),
      GoRoute(
          path: '/app/social/messages',
          builder: (_, __) => const SocialDMPage()),
      GoRoute(
          path: '/app/social/messages/:recipientId',
          builder: (_, state) => SocioDMChatPage(
              recipientId: state.pathParameters['recipientId']!)),
      GoRoute(
          path: '/app/social/notifications',
          builder: (_, __) => const SocialNotificationsPage()),
      GoRoute(
          path: '/app/social/settings',
          builder: (_, __) => const SocialSettingsPage()),
      GoRoute(
          path: '/app/social/@:username',
          builder: (_, state) =>
              SocialProfilePage(username: state.pathParameters['username'])),
      GoRoute(
          path: '/app/social/profile/:userId',
          builder: (_, state) =>
              SocialProfilePage(userId: state.pathParameters['userId']!)),
      GoRoute(
          path: '/app/social/post/:postId',
          builder: (_, state) =>
              SocialPostDetailPage(postId: state.pathParameters['postId']!)),
      GoRoute(
          path: '/app/social/user/:userId/posts/:postId',
          builder: (_, state) => SocialUserPostsPage(
              userId: state.pathParameters['userId']!,
              postId: state.pathParameters['postId']!)),
      GoRoute(
          path: '/app/social/comments/:postId',
          builder: (_, state) =>
              SocialCommentsPage(postId: state.pathParameters['postId']!)),
      GoRoute(
          path: '/app/social/:username/followers',
          builder: (_, state) =>
              SocialFollowersPage(userId: state.pathParameters['username']!)),
      GoRoute(
          path: '/app/social/:username/following',
          builder: (_, state) => SocialFollowersPage(
              userId: state.pathParameters['username']!, following: true)),
      GoRoute(
          path: '/app/social/profile/:userId/followers',
          builder: (_, state) =>
              SocialFollowersPage(userId: state.pathParameters['userId']!)),
      GoRoute(
          path: '/app/social/profile/:userId/following',
          builder: (_, state) => SocialFollowersPage(
              userId: state.pathParameters['userId']!, following: true)),
      GoRoute(
          path: '/app/social/saved',
          builder: (_, __) => const SocialSavedPostsPage()),
      GoRoute(
          path: '/app/social/edit-profile',
          builder: (_, __) => const SocialEditProfilePage()),
      GoRoute(
          path: '/app/social/dashboard',
          builder: (_, __) => const SocialCreatorDashboardPage()),
      GoRoute(
          path: '/app/social/live', builder: (_, __) => const SocialLivePage()),
      GoRoute(
          path: '/app/social/channels',
          builder: (_, __) => const SocialBroadcastPage()),
      GoRoute(
          path: '/app/social/change-password',
          builder: (_, __) => const SocialChangePasswordPage()),
      GoRoute(
          path: '/app/social/privacy',
          builder: (_, __) => const SocialPrivacyPage()),
      GoRoute(
          path: '/app/social/security',
          builder: (_, __) => const SocialSecurityPage()),
      GoRoute(
          path: '/app/social/notification-settings',
          builder: (_, __) => const SocialNotificationSettingsPage()),
      GoRoute(
          path: '/app/social/help',
          builder: (_, __) => const SocialHelpCenterPage()),
      GoRoute(
          path: '/app/social/shop', builder: (_, __) => const SocialShopPage()),
      GoRoute(
          path: '/app/social/suggestions',
          builder: (_, __) => const SocialSuggestionsPage()),
      GoRoute(
          path: '/app/social/friends',
          builder: (_, __) => const SocialFriendsPage()),
      GoRoute(
          path: '/app/find-home', builder: (_, __) => const PropertyHomePage()),
      GoRoute(
          path: '/app/find-home/post',
          builder: (_, __) => const PostPropertyPage()),
      GoRoute(
          path: '/app/find-home/emi',
          builder: (_, __) => const PropertyEMIPage()),
      GoRoute(
          path: '/app/find-home/my-properties',
          builder: (_, __) => const MyPropertiesPage()),
      GoRoute(
          path: '/app/find-home/saved',
          builder: (_, __) => const MyPropertiesPage()),
      GoRoute(
          path: '/app/find-home/saved-searches',
          builder: (_, __) => const SavedSearchesPage()),
      GoRoute(
          path: '/app/find-home/messages',
          builder: (_, __) => const PropertyMessagesPage()),
      GoRoute(
          path: '/app/find-home/rent-tracker',
          builder: (_, __) => const RentTrackerPage()),
      GoRoute(
          path: '/app/find-home/value-estimator',
          builder: (_, __) => const PropertyValueEstimatorPage()),
      GoRoute(
          path: '/app/find-home/:id',
          builder: (_, state) =>
              PropertyDetailPage(id: state.pathParameters['id']!)),
    ],
    errorBuilder: (_, __) => const CustomerHomePage(),
  );
});

class CustomerApp extends ConsumerWidget {
  const CustomerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Planext4u',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: AppColors.primary,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
