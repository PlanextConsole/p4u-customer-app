import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/services/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/map_ext.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/customer_scaffold.dart';
import '../../../../core/widgets/remote_image.dart';
import '../../../../core/widgets/social_video.dart';
import '../../../../core/ads/admob_banner_card.dart';
import '../../../auth/data/auth_repository.dart';
import '../../data/customer_providers.dart';
import 'account_pages.dart';

class SocialFeedPage extends ConsumerStatefulWidget {
  const SocialFeedPage({super.key});

  @override
  ConsumerState<SocialFeedPage> createState() => _SocialFeedPageState();
}

class _SocialFeedPageState extends ConsumerState<SocialFeedPage> {
  static const _defaultAdConfig = <String, dynamic>{
    'adEveryN': 5,
    'mode': 'prefer_admin_then_admob',
  };

  late Future<List<Map<String, dynamic>>> _feedFuture;
  List<Map<String, dynamic>> _ads = const [];
  Map<String, dynamic> _adConfig = _defaultAdConfig;

  @override
  void initState() {
    super.initState();
    _feedFuture = _loadFeed();
    unawaited(_loadAdContent());
  }

  Future<List<Map<String, dynamic>>> _loadFeed() =>
      ref.read(customerRepositoryProvider).socialFeed();

  Future<List<Map<String, dynamic>>> _safeAds() async {
    try {
      return await ref
          .read(customerRepositoryProvider)
          .socialFeedAds()
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      return const [];
    }
  }

  Future<Map<String, dynamic>> _safeAdConfig() async {
    try {
      return await ref
          .read(customerRepositoryProvider)
          .socialAdConfig()
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      return _defaultAdConfig;
    }
  }

  Future<void> _loadAdContent() async {
    final values = await Future.wait<dynamic>([_safeAds(), _safeAdConfig()]);
    if (!mounted) return;
    setState(() {
      _ads = values[0] as List<Map<String, dynamic>>;
      _adConfig = values[1] as Map<String, dynamic>;
    });
  }

  Future<void> _refreshFeed() async {
    final next = _loadFeed();
    setState(() => _feedFuture = next);
    unawaited(_loadAdContent());
    await next;
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(customerAuthStateProvider).valueOrNull;
    if (auth == null) return const LoginRequiredPage();
    return CustomerScaffold(
      title: 'Socio',
      bottomNavIndex: 3,
      actions: [
        IconButton(
            onPressed: () => context.push('/app/social/create'),
            icon: const Icon(Icons.add_box_rounded)),
        IconButton(
            onPressed: () => context.push('/app/social/notifications'),
            icon: const Icon(Icons.notifications_rounded)),
        IconButton(
            onPressed: () => context.push('/app/social/messages'),
            icon: const Icon(Icons.send_rounded)),
      ],
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _feedFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return RefreshIndicator(
              onRefresh: _refreshFeed,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * .55,
                    child: EmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: 'Could not load Socio',
                      message: snapshot.error.toString(),
                      action: FilledButton(
                        onPressed: _refreshFeed,
                        child: const Text('Retry'),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          final posts = snapshot.data ?? const <Map<String, dynamic>>[];
          final ads = _ads;
          final config = _adConfig;
          final adEveryN = (config['adEveryN'] as int? ?? 5).clamp(1, 100);
          final feedChildren = <Widget>[];
          for (var i = 0; i < posts.length; i++) {
            feedChildren.add(Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SocialPostCard(
                  key: ValueKey(posts[i]['id']),
                  post: posts[i],
                )));
            if ((i + 1) % adEveryN == 0) {
              feedChildren.add(Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _HybridSocioAdSlot(
                    slotIndex: (i + 1) ~/ adEveryN - 1,
                    ads: ads,
                    config: config,
                  )));
            }
          }
          return RefreshIndicator(
            onRefresh: _refreshFeed,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                _SocialStoryRail(ads: ads, config: config),
                const SizedBox(height: 12),
                _SocialQuickNav(),
                const SizedBox(height: 12),
                if (posts.isEmpty)
                  const EmptyState(
                      icon: Icons.groups_rounded,
                      title: 'No posts yet',
                      message: 'Create the first Socio post.')
                else
                  ...feedChildren,
              ],
            ),
          );
        },
      ),
    );
  }
}

class SocialPostCard extends ConsumerStatefulWidget {
  const SocialPostCard({required this.post, super.key});
  final Map<String, dynamic> post;

  @override
  ConsumerState<SocialPostCard> createState() => _SocialPostCardState();
}

class _SocialPostCardState extends ConsumerState<SocialPostCard> {
  late bool _liked;
  late bool _saved;
  late bool _following;
  late int _likes;
  late int _comments;
  late int _shares;
  bool _likeBusy = false;
  bool _saveBusy = false;
  bool _followBusy = false;
  bool _shareBusy = false;

  @override
  void initState() {
    super.initState();
    final post = widget.post;
    _liked = post['liked'] == true;
    _saved = post['saved'] == true;
    _following = post['is_following'] == true;
    _likes = post.i('likes_count', post.i('like_count'));
    _comments = post.i('comments_count', post.i('comment_count'));
    _shares = post.i('shares_count', post.i('share_count'));
  }

  @override
  void didUpdateWidget(covariant SocialPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_likeBusy) return;
    final oldId = oldWidget.post.s('id');
    final newId = widget.post.s('id');
    if (oldId != newId || oldWidget.post != widget.post) {
      _liked = widget.post['liked'] == true;
      _likes = widget.post.i('likes_count', widget.post.i('like_count'));
      _saved = widget.post['saved'] == true;
      _following = widget.post['is_following'] == true;
      _comments =
          widget.post.i('comments_count', widget.post.i('comment_count'));
      _shares = widget.post.i('shares_count', widget.post.i('share_count'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final mediaList = post['media_urls'] is List
        ? (post['media_urls'] as List).map((e) => e.toString()).toList()
        : <String>[];
    // Prefer a video URL when the post has one (same rule as the web feed).
    final media = mediaList.firstWhere(isVideoUrl,
        orElse: () =>
            mediaList.isNotEmpty ? mediaList.first : post.s('image_url'));
    final isVideo = isVideoUrl(media) ||
        post.s('post_type') == 'video' ||
        post.s('postType') == 'video' ||
        post.s('media_type') == 'video' ||
        post.s('mediaType') == 'video';
    final postId = post.s('id');
    final auth = ref.watch(customerAuthStateProvider).valueOrNull;
    final myId = auth?.supabaseUid ?? auth?.id ?? '';
    final isSelf = post['is_self'] == true ||
        (myId.isNotEmpty && post.s('user_id') == myId);
    final avatar = post.s('avatar');
    final category = post.s('category');
    final tags = (post['tags'] is List)
        ? (post['tags'] as List).map((e) => e.toString()).toList()
        : const <String>[];
    final linked = (post['linked_products'] is List)
        ? (post['linked_products'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : const <Map<String, dynamic>>[];
    final hideLikeCount = post['hide_like_count'] == true && !isSelf;
    final commentPermission = post.s('comment_permission', 'everyone');
    final canComment = commentPermission == 'none'
        ? false
        : commentPermission == 'followers'
            ? (_following || isSelf)
            : true;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            onTap: () =>
                context.push('/app/social/profile/${post.s('user_id')}'),
            leading: CircleAvatar(
              backgroundColor: AppColors.accent,
              backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
              child: avatar.isEmpty
                  ? const Icon(Icons.person_rounded, color: AppColors.primary)
                  : null,
            ),
            title: Text(post.s('username', 'Planext user'),
                style: const TextStyle(fontWeight: FontWeight.w900)),
            subtitle: Text(shortDate(post['created_at'])),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isSelf)
                  TextButton(
                    onPressed: _followBusy
                        ? null
                        : () => _toggleFollow(post.s('user_id')),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 0),
                    ),
                    child: Text(_following ? 'Following' : 'Follow',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _following
                                ? AppColors.muted
                                : AppColors.primary)),
                  ),
                IconButton(
                    onPressed: () =>
                        context.push('/app/social/post/${post.s('id')}'),
                    icon: const Icon(Icons.more_horiz_rounded)),
              ],
            ),
          ),
          if (media.isNotEmpty)
            isVideo
                ? SocialVideo(url: media, height: 300)
                : RemoteImage(
                    url: media,
                    height: 280,
                    width: double.infinity,
                    borderRadius: 0),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(post.s('caption', post.s('content')),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                if (category.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Category: $category',
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12)),
                ],
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(tags.map((t) => '#$t').join(' '),
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600)),
                ],
                if (linked.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 96,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final p in linked)
                          GestureDetector(
                            onTap: p.s('id').isEmpty
                                ? null
                                : () =>
                                    context.push('/app/product/${p.s('id')}'),
                            child: Container(
                              width: 80,
                              margin: const EdgeInsets.only(right: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: RemoteImage(
                                        url: p.s('image'),
                                        width: 80,
                                        height: 56),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(p.s('name', 'Product'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11)),
                                  Text(money(p.n('price')),
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    IconButton(
                        onPressed: _likeBusy ? null : () => _toggleLike(postId),
                        icon: Icon(
                          _liked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: _liked ? Colors.red : null,
                        )),
                    if (!hideLikeCount) Text('$_likes'),
                    IconButton(
                        onPressed:
                            canComment ? () => _openComments(postId) : null,
                        icon: const Icon(Icons.mode_comment_outlined)),
                    Text('$_comments'),
                    IconButton(
                        onPressed: _shareBusy ? null : () => _share(postId),
                        icon: const Icon(Icons.share_outlined)),
                    if (_shares > 0) Text('$_shares'),
                    const Spacer(),
                    IconButton(
                        onPressed: _saveBusy ? null : () => _toggleSave(postId),
                        icon: Icon(_saved
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleFollow(String userId) async {
    if (userId.isEmpty || _followBusy) return;
    final repo = ref.read(customerRepositoryProvider);
    final was = _following;
    setState(() {
      _followBusy = true;
      _following = !was;
      widget.post['is_following'] = !was;
    });
    try {
      if (was) {
        await repo.unfollowSocialUser(userId);
      } else {
        await repo.followSocialUser(userId);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _following = was;
          widget.post['is_following'] = was;
        });
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not update follow: $error')));
      }
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  Future<void> _toggleLike(String postId) async {
    if (postId.isEmpty || _likeBusy) return;
    final repo = ref.read(customerRepositoryProvider);
    final wasLiked = _liked;
    setState(() {
      _likeBusy = true;
      _liked = !wasLiked;
      _likes += wasLiked ? -1 : 1;
      if (_likes < 0) _likes = 0;
      widget.post['liked'] = _liked;
      widget.post['likes_count'] = _likes;
    });
    try {
      if (wasLiked) {
        await repo.unlikeSocialPost(postId);
      } else {
        await repo.likeSocialPost(postId);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _liked = wasLiked;
        _likes += wasLiked ? 1 : -1;
        if (_likes < 0) _likes = 0;
        widget.post['liked'] = _liked;
        widget.post['likes_count'] = _likes;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update like: $error')),
      );
    } finally {
      if (mounted) setState(() => _likeBusy = false);
    }
  }

  Future<void> _toggleSave(String postId) async {
    if (postId.isEmpty || _saveBusy) return;
    final repo = ref.read(customerRepositoryProvider);
    final wasSaved = _saved;
    setState(() {
      _saveBusy = true;
      _saved = !wasSaved;
      widget.post['saved'] = _saved;
    });
    try {
      if (wasSaved) {
        await repo.unsaveSocialPost(postId);
      } else {
        await repo.saveSocialPost(postId);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saved = wasSaved;
        widget.post['saved'] = wasSaved;
      });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update saved post: $error')));
    } finally {
      if (mounted) setState(() => _saveBusy = false);
    }
  }

  Future<void> _share(String postId) async {
    if (postId.isEmpty || _shareBusy) return;
    setState(() {
      _shareBusy = true;
      _shares += 1;
      widget.post['shares_count'] = _shares;
    });
    try {
      await ref.read(customerRepositoryProvider).shareSocialPost(postId);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Post shared')));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _shares = (_shares - 1).clamp(0, 1 << 31);
          widget.post['shares_count'] = _shares;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _shareBusy = false);
    }
  }

  Future<void> _openComments(String postId) async {
    if (postId.isEmpty) return;
    await context.push('/app/social/comments/$postId');
    if (!mounted) return;
    try {
      final refreshed =
          await ref.read(customerRepositoryProvider).socialPost(postId);
      if (!mounted || refreshed == null) return;
      setState(() {
        _comments = refreshed.i(
            'comments_count', refreshed.i('comment_count', _comments));
        widget.post['comments_count'] = _comments;
      });
    } catch (_) {
      // The comments themselves were already saved; a count refresh can wait
      // for the next pull-to-refresh when the network is unavailable.
    }
  }
}

class SocialCreatePostPage extends ConsumerStatefulWidget {
  const SocialCreatePostPage({super.key});

  @override
  ConsumerState<SocialCreatePostPage> createState() =>
      _SocialCreatePostPageState();
}

/// Sponsored ad card interleaved into the feed (web SponsoredAdCard).
Future<void> _openAdminSocioAd(
    BuildContext context, Map<String, dynamic> ad) async {
  final target = ad.s('targetType', ad.s('target_type')).toLowerCase();
  final productId = ad.s('productId', ad.s('product_id'));
  final vendorId = ad.s('vendorId', ad.s('vendor_id'));
  if (target == 'product' && productId.isNotEmpty) {
    await context.push('/app/product/$productId');
    return;
  }
  if (target == 'vendor' && vendorId.isNotEmpty) {
    await context.push('/app/vendor/$vendorId');
    return;
  }
  final redirect = ad.s('redirect_url', ad.s('redirectUrl'));
  if (redirect.isEmpty) return;
  if (redirect.startsWith('/app/')) {
    await context.push(redirect);
    return;
  }
  final uri = Uri.tryParse(redirect);
  if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _HybridSocioAdSlot extends StatelessWidget {
  const _HybridSocioAdSlot({
    required this.slotIndex,
    required this.ads,
    required this.config,
    this.compact = false,
  });

  final int slotIndex;
  final List<Map<String, dynamic>> ads;
  final Map<String, dynamic> config;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final mode = config['mode'] as String? ?? 'prefer_admin_then_admob';
    final admin = ads.isEmpty ? null : ads[slotIndex % ads.length];
    final wantsAdmin = mode == 'admin_only' ||
        mode == 'prefer_admin_then_admob' ||
        (mode == 'alternate' && slotIndex.isEven);
    if (wantsAdmin && admin != null) {
      return SponsoredAdCard(ad: admin, compact: compact);
    }
    if (mode == 'admin_only') return const SizedBox.shrink();
    return AdMobBannerCard(compact: compact);
  }
}

class SponsoredAdCard extends StatelessWidget {
  const SponsoredAdCard({required this.ad, this.compact = false, super.key});
  final Map<String, dynamic> ad;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final image = ad.s('image');
    if (compact) {
      return SizedBox(
        width: 260,
        child: AppCard(
          padding: EdgeInsets.zero,
          onTap: () => _openAdminSocioAd(context, ad),
          child: Row(
            children: [
              if (image.isNotEmpty)
                RemoteImage(url: image, height: 88, width: 92, borderRadius: 0),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Sponsored',
                          style: TextStyle(
                              fontSize: 10, color: AppColors.primary)),
                      const SizedBox(height: 4),
                      Text(ad.s('advertiser', ad.s('title', 'Advertisement')),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () => _openAdminSocioAd(context, ad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(ad.s('advertiser', ad.s('title', 'Sponsored')),
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('Sponsored',
                      style: TextStyle(fontSize: 10, color: AppColors.primary)),
                ),
              ],
            ),
          ),
          if (image.isNotEmpty)
            RemoteImage(
                url: image,
                height: 200,
                width: double.infinity,
                borderRadius: 0),
          if (ad.s('caption').isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(ad.s('caption')),
            ),
        ],
      ),
    );
  }
}

/// Post categories — mirror web POST_CATEGORIES (SocialPage.tsx).
const List<String> _kPostCategories = [
  'Lifestyle',
  'Shopping',
  'Services',
  'Classifieds',
  'Food',
  'Travel',
  'Education',
  'Business',
  'Community',
];

class _SocialCreatePostPageState extends ConsumerState<SocialCreatePostPage> {
  final _caption = TextEditingController();
  final _location = TextEditingController();
  final _tags = TextEditingController();
  final _productSearch = TextEditingController();

  XFile? _picked;
  bool _isVideo = false;
  String? _category;
  String _audience = 'public'; // public | private
  String _commentPermission = 'everyone'; // everyone | followers | none
  bool _hideLikeCount = false;
  final List<Map<String, dynamic>> _linkedProducts = [];
  List<Map<String, dynamic>> _searchResults = const [];
  bool _searching = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _caption.dispose();
    _location.dispose();
    _tags.dispose();
    _productSearch.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    final pickVideo = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose photo'),
              onTap: () => Navigator.pop(context, false),
            ),
            ListTile(
              leading: const Icon(Icons.video_library_rounded),
              title: const Text('Choose video'),
              onTap: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ),
    );
    if (pickVideo == null) return;
    try {
      final picker = ImagePicker();
      final file = pickVideo
          ? await picker.pickVideo(source: ImageSource.gallery)
          : await picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;
      final bytes = await file.length();
      if (bytes <= 0) throw Exception('The selected file is empty.');
      if (bytes > 50 * 1024 * 1024) {
        throw Exception('Post media must be smaller than 50 MB.');
      }
      if (!mounted) return;
      setState(() {
        _picked = file;
        _isVideo = pickVideo;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not select media: $e');
    }
  }

  Future<void> _runProductSearch(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _searchResults = const []);
      return;
    }
    setState(() => _searching = true);
    try {
      final rows =
          await ref.read(customerRepositoryProvider).socialProductSearch(q);
      if (mounted) setState(() => _searchResults = rows);
    } catch (_) {
      if (mounted) setState(() => _searchResults = const []);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _toggleProduct(Map<String, dynamic> p) {
    final id = p.s('id');
    setState(() {
      final existing = _linkedProducts.indexWhere((e) => e.s('id') == id);
      if (existing >= 0) {
        _linkedProducts.removeAt(existing);
      } else {
        _linkedProducts.add({
          'id': id,
          'name': p.s('title', p.s('name')),
          'image': p.s('image'),
          'price': p.n('price'),
          'vendorId': p.s('vendor_id'),
        });
      }
    });
  }

  Future<void> _submit(dynamic auth) async {
    if (_busy) return;
    if (_category == null) {
      setState(() => _error = 'Please select a category');
      return;
    }
    if (_picked == null) {
      setState(() => _error = 'Please add a photo or video');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    String uploadedMediaId = '';
    try {
      final repo = ref.read(customerRepositoryProvider);
      final uploaded = await repo.uploadSocialMediaFile(
        File(_picked!.path),
        contentType: _picked!.mimeType,
      );
      uploadedMediaId = uploaded.s('id');
      final url = uploaded.s('url');
      if (url.isEmpty) throw Exception('Upload failed');
      final tags = _tags.text
          .split(RegExp(r'[,\s#]+'))
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      await repo.createSocialPost(auth.supabaseUid ?? auth.id, {
        'contentText': _caption.text.trim(),
        'mediaUrls': [url],
        'postType': uploaded.s('type', _isVideo ? 'video' : 'image'),
        'visibility': _audience,
        'location':
            _location.text.trim().isEmpty ? null : _location.text.trim(),
        'tags': tags,
        'category': _category,
        'linkedProducts': _linkedProducts,
        'hideLikeCount': _hideLikeCount,
        'commentPermission': _commentPermission,
      });
      if (mounted) context.go('/app/social');
    } catch (e) {
      final statusCode = e is ApiException ? e.statusCode : null;
      if (uploadedMediaId.isNotEmpty &&
          statusCode != null &&
          statusCode >= 400 &&
          statusCode < 500) {
        try {
          await ref
              .read(customerRepositoryProvider)
              .deleteUploadedSocialMedia(uploadedMediaId);
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not create post: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(customerAuthStateProvider).valueOrNull;
    if (auth == null) return const LoginRequiredPage();
    return CustomerScaffold(
      title: 'Create Post',
      showBack: true,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Media picker (required)
                GestureDetector(
                  onTap: _busy ? null : _pickMedia,
                  child: Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: _picked == null
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_photo_alternate_rounded,
                                    size: 36, color: AppColors.muted),
                                SizedBox(height: 6),
                                Text('Add a photo or video',
                                    style: TextStyle(color: AppColors.muted)),
                              ],
                            ),
                          )
                        : _isVideo
                            ? const Center(
                                child: Icon(Icons.videocam_rounded, size: 48))
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(File(_picked!.path),
                                    fit: BoxFit.cover, width: double.infinity),
                              ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                    controller: _caption,
                    minLines: 3,
                    maxLines: 8,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.edit_rounded),
                        hintText: 'Write a caption…')),
                const SizedBox(height: 12),
                // Category (required)
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.category_rounded),
                      hintText: 'Select a category'),
                  items: [
                    for (final c in _kPostCategories)
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) => setState(() => _category = v),
                ),
                const SizedBox(height: 12),
                TextField(
                    controller: _location,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.location_on_outlined),
                        hintText: 'Add location (optional)')),
                const SizedBox(height: 12),
                TextField(
                    controller: _tags,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.tag_rounded),
                        hintText: 'Tag people (@username), comma separated')),
                const SizedBox(height: 16),
                // Linked products
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Link products (optional)',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _productSearch,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: 'Search products to tag',
                    suffixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : null,
                  ),
                  onChanged: _runProductSearch,
                ),
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final p in _searchResults)
                          ListTile(
                            dense: true,
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: RemoteImage(
                                  url: p.s('image'), width: 40, height: 40),
                            ),
                            title: Text(p.s('title', p.s('name', 'Product')),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(money(p.n('price'))),
                            trailing: Icon(
                              _linkedProducts.any((e) => e.s('id') == p.s('id'))
                                  ? Icons.check_circle_rounded
                                  : Icons.add_circle_outline_rounded,
                              color: AppColors.primary,
                            ),
                            onTap: () => _toggleProduct(p),
                          ),
                      ],
                    ),
                  ),
                if (_linkedProducts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final p in _linkedProducts)
                          Chip(
                            label: Text(p.s('name', 'Product')),
                            onDeleted: () => _toggleProduct(p),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                // Audience
                DropdownButtonFormField<String>(
                  initialValue: _audience,
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.visibility_outlined),
                      labelText: 'Audience'),
                  items: const [
                    DropdownMenuItem(value: 'public', child: Text('Public')),
                    DropdownMenuItem(value: 'private', child: Text('Private')),
                  ],
                  onChanged: (v) => setState(() => _audience = v ?? 'public'),
                ),
                const SizedBox(height: 12),
                // Comment permission
                DropdownButtonFormField<String>(
                  initialValue: _commentPermission,
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.mode_comment_outlined),
                      labelText: 'Who can comment'),
                  items: const [
                    DropdownMenuItem(
                        value: 'everyone', child: Text('Everyone')),
                    DropdownMenuItem(
                        value: 'followers', child: Text('Followers Only')),
                    DropdownMenuItem(value: 'none', child: Text('No One')),
                  ],
                  onChanged: (v) =>
                      setState(() => _commentPermission = v ?? 'everyone'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Hide like count'),
                  value: _hideLikeCount,
                  onChanged: (v) => setState(() => _hideLikeCount = v),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(_error!,
                        style: const TextStyle(color: AppColors.danger)),
                  ),
                FilledButton.icon(
                  onPressed: _busy ? null : () => _submit(auth),
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send_rounded),
                  label: Text(_busy ? 'Posting…' : 'Share'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SocialExplorePage extends ConsumerStatefulWidget {
  const SocialExplorePage({super.key});

  @override
  ConsumerState<SocialExplorePage> createState() => _SocialExplorePageState();
}

class _SocialExplorePageState extends ConsumerState<SocialExplorePage> {
  final _search = TextEditingController();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(customerRepositoryProvider).socialProfiles();
  }

  @override
  Widget build(BuildContext context) {
    return CustomerScaffold(
      title: 'Explore',
      showBack: true,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _search,
            onSubmitted: (_) => setState(() => _future = ref
                .read(customerRepositoryProvider)
                .socialProfiles(search: _search.text.trim())),
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search people or hashtags'),
          ),
          const SizedBox(height: 14),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Search unavailable',
                  message: snapshot.error.toString(),
                );
              }
              final rows = snapshot.data ?? [];
              if (rows.isEmpty) {
                return const EmptyState(
                    icon: Icons.search_rounded,
                    title: 'Start exploring',
                    message: 'Find people and creators.');
              }
              return Column(
                  children: rows
                      .map((u) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppCard(
                              onTap: () {
                                final id = u.s('user_id',
                                    u.s('userId', u.s('id', u.s('authorId'))));
                                if (id.isEmpty) return;
                                context.push('/app/social/profile/$id');
                              },
                              child: _ProfileRow(profile: u))))
                      .toList());
            },
          ),
        ],
      ),
    );
  }
}

class SocialProfilePage extends ConsumerWidget {
  const SocialProfilePage({this.userId, this.username, super.key});

  final String? userId;
  final String? username;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(customerAuthStateProvider).valueOrNull;
    if (auth == null) return const LoginRequiredPage();
    final target = userId ?? auth.supabaseUid ?? auth.id;
    return CustomerScaffold(
      title: 'Socio Profile',
      showBack: true,
      actions: [
        IconButton(
            onPressed: () => context.push('/app/social/settings'),
            icon: const Icon(Icons.settings_rounded))
      ],
      child: FutureBuilder<Map<String, dynamic>?>(
        future: ref.read(customerRepositoryProvider).socialProfile(target),
        builder: (context, snapshot) {
          final profile = snapshot.data ??
              {
                'user_id': target,
                'username': username ?? auth.name,
                'display_name': auth.name
              };
          final displayName = profile
              .s('display_name',
                  profile.s('userName', profile.s('name', auth.name)))
              .trim();
          final safeDisplayName = displayName.isEmpty ? 'User' : displayName;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Column(
                  children: [
                    CircleAvatar(
                        radius: 42,
                        backgroundColor: AppColors.accent,
                        child: Text(
                            safeDisplayName.characters.first.toUpperCase(),
                            style: const TextStyle(
                                fontSize: 30,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w900))),
                    const SizedBox(height: 10),
                    Text(safeDisplayName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 20)),
                    Text(
                        '@${profile.s('username', auth.name.toLowerCase().replaceAll(' ', ''))}',
                        style: const TextStyle(color: AppColors.muted)),
                    const SizedBox(height: 12),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _Count(
                              'Posts',
                              profile.i('posts_count',
                                  profile.i('postCount', profile.i('posts')))),
                          GestureDetector(
                            onTap: () => context
                                .push('/app/social/profile/$target/followers'),
                            child: _Count(
                                'Followers',
                                profile.i(
                                    'followers_count',
                                    profile.i('followerCount',
                                        profile.i('followers')))),
                          ),
                          GestureDetector(
                            onTap: () => context
                                .push('/app/social/profile/$target/following'),
                            child: _Count(
                                'Following',
                                profile.i(
                                    'following_count',
                                    profile.i('followingCount',
                                        profile.i('following')))),
                          ),
                        ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: (target == (auth.supabaseUid ?? auth.id) ||
                                profile['isSelf'] == true)
                            ? OutlinedButton(
                                onPressed: () =>
                                    context.push('/app/social/edit-profile'),
                                child: const Text('Edit Profile'))
                            : _ProfileFollowButton(
                                userId: target,
                                initialFollowing:
                                    profile['isFollowing'] == true),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                          child: FilledButton(
                              onPressed: () =>
                                  context.push('/app/social/messages/$target'),
                              child: const Text('Message'))),
                    ]),
                  ],
                ),
              ),
              const SectionHeader(title: 'Posts'),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: ref
                    .read(customerRepositoryProvider)
                    .socialUserPosts(target),
                builder: (context, posts) {
                  final rows = posts.data ?? [];
                  if (rows.isEmpty) {
                    return const EmptyState(
                        icon: Icons.grid_on_rounded,
                        title: 'No posts',
                        message: 'Posts from this profile will appear here.');
                  }
                  return Column(
                      children: rows
                          .map((post) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: SocialPostCard(post: post)))
                          .toList());
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class SocialPostDetailPage extends ConsumerWidget {
  const SocialPostDetailPage({required this.postId, super.key});
  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomerScaffold(
      title: 'Post',
      showBack: true,
      child: FutureBuilder<Map<String, dynamic>?>(
        future: ref.read(customerRepositoryProvider).socialPost(postId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final post = snapshot.data;
          if (post == null) {
            return const EmptyState(
                icon: Icons.post_add_rounded,
                title: 'Post not found',
                message: 'This post is unavailable.');
          }
          return ListView(padding: const EdgeInsets.all(16), children: [
            SocialPostCard(post: post),
            const SizedBox(height: 12),
            FilledButton(
                onPressed: () => context.push('/app/social/comments/$postId'),
                child: const Text('View Comments'))
          ]);
        },
      ),
    );
  }
}

class SocialCommentsPage extends ConsumerStatefulWidget {
  const SocialCommentsPage({required this.postId, super.key});
  final String postId;

  @override
  ConsumerState<SocialCommentsPage> createState() => _SocialCommentsPageState();
}

class _SocialCommentsPageState extends ConsumerState<SocialCommentsPage> {
  final _composer = TextEditingController();
  late Future<List<Map<String, dynamic>>> _future;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _future =
        ref.read(customerRepositoryProvider).socialComments(widget.postId);
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomerScaffold(
      title: 'Comments',
      showBack: true,
      child: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                final rows = snapshot.data ?? [];
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Comments unavailable',
                    message: snapshot.error.toString(),
                    action: FilledButton.icon(
                      onPressed: () => setState(() {
                        _future = ref
                            .read(customerRepositoryProvider)
                            .socialComments(widget.postId);
                      }),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  );
                }
                if (rows.isEmpty) {
                  return const EmptyState(
                      icon: Icons.mode_comment_rounded,
                      title: 'No comments',
                      message: 'Be the first to comment.');
                }
                return ListView(
                    padding: const EdgeInsets.all(16),
                    children: rows.map((c) {
                      final avatar = c.s('avatar');
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppCard(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: AppColors.accent,
                                backgroundImage: avatar.isNotEmpty
                                    ? NetworkImage(avatar)
                                    : null,
                                child: avatar.isEmpty
                                    ? const Icon(Icons.person_rounded,
                                        size: 18, color: AppColors.primary)
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(c.s('username', 'Planext user'),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700)),
                                        const SizedBox(width: 8),
                                        Text(shortDate(c['created_at']),
                                            style: const TextStyle(
                                                color: AppColors.muted,
                                                fontSize: 11)),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(c.s('content',
                                        c.s('comment', c.s('contentText')))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList());
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _composer,
                      decoration:
                          const InputDecoration(hintText: 'Add a comment'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(customerRepositoryProvider)
          .createSocialComment(widget.postId, text);
      _composer.clear();
      setState(() {
        _future =
            ref.read(customerRepositoryProvider).socialComments(widget.postId);
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not add comment: $error')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

class SocialDMPage extends ConsumerWidget {
  const SocialDMPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(customerAuthStateProvider).valueOrNull;
    if (auth == null) return const LoginRequiredPage();
    final userId = auth.supabaseUid ?? auth.id;
    return CustomerScaffold(
      title: 'Messages',
      showBack: true,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future:
            ref.read(customerRepositoryProvider).socialConversations(userId),
        builder: (context, snapshot) {
          final rows = snapshot.data ?? [];
          if (rows.isEmpty) {
            return const EmptyState(
                icon: Icons.send_rounded,
                title: 'No conversations',
                message: 'Start a conversation from a profile.');
          }
          return ListView(
              padding: const EdgeInsets.all(16),
              children: rows
                  .map((c) => AppCard(
                      onTap: () =>
                          context.push('/app/social/messages/${c.s('id')}'),
                      child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.chat_rounded),
                          title: Text(c.s(
                              'participantName',
                              c.s('participant_name',
                                  c.s('title', 'Conversation')))),
                          subtitle: Text(() {
                            final last = c.s(
                                'lastMessage',
                                c.s('last_message',
                                    c.s('preview', c.s('message'))));
                            final when = c['lastMessageAt'] ??
                                c['last_message_at'] ??
                                c['updated_at'] ??
                                c['updatedAt'];
                            final date = shortDate(when);
                            if (last.isEmpty) return date;
                            return date.isEmpty ? last : '$last · $date';
                          }()))))
                  .toList());
        },
      ),
    );
  }
}

class SocioDMChatPage extends ConsumerStatefulWidget {
  const SocioDMChatPage({required this.recipientId, super.key});
  final String recipientId;

  @override
  ConsumerState<SocioDMChatPage> createState() => _SocioDMChatPageState();
}

class _SocioDMChatPageState extends ConsumerState<SocioDMChatPage> {
  final _controller = TextEditingController();
  String? _conversationId;
  late Future<List<Map<String, dynamic>>> _messages;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _conversationId = widget.recipientId;
    _messages =
        ref.read(customerRepositoryProvider).socialMessages(widget.recipientId);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomerScaffold(
      title: 'Chat',
      showBack: true,
      child: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _messages,
              builder: (context, snapshot) {
                final rows = snapshot.data ?? [];
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (rows.isEmpty) {
                  return const EmptyState(
                      icon: Icons.chat_bubble_rounded,
                      title: 'No messages',
                      message: 'Send the first message.');
                }
                return ListView(
                    padding: const EdgeInsets.all(16),
                    children: rows
                        .map((m) => Align(
                            alignment: Alignment.centerLeft,
                            child: AppCard(
                                child: Text(m.s('content',
                                    m.s('message', m.s('contentText')))))))
                        .toList());
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                      child: TextField(
                          controller: _controller,
                          decoration:
                              const InputDecoration(hintText: 'Message'))),
                  const SizedBox(width: 8),
                  IconButton.filled(
                      onPressed: _sending ? null : _send,
                      icon: const Icon(Icons.send_rounded)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      var conversationId = _conversationId ?? widget.recipientId;
      // Lists pass conversation id; profile Message may pass participant id.
      try {
        await ref
            .read(customerRepositoryProvider)
            .sendSocialMessage(conversationId, text);
      } catch (_) {
        conversationId = await ref
            .read(customerRepositoryProvider)
            .openSocialConversation(widget.recipientId);
        _conversationId = conversationId;
        await ref
            .read(customerRepositoryProvider)
            .sendSocialMessage(conversationId, text);
      }
      _controller.clear();
      setState(() {
        _messages =
            ref.read(customerRepositoryProvider).socialMessages(conversationId);
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

class SocialNotificationsPage extends ConsumerWidget {
  const SocialNotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(customerAuthStateProvider).valueOrNull;
    if (auth == null) return const LoginRequiredPage();
    return CustomerScaffold(
      title: 'Notifications',
      showBack: true,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: ref
            .read(customerRepositoryProvider)
            .mergedNotifications(auth.supabaseUid ?? auth.id),
        builder: (context, snapshot) {
          final rows = snapshot.data ?? [];
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (rows.isEmpty) {
            return const EmptyState(
                icon: Icons.notifications_rounded,
                title: 'No notifications',
                message: 'Notifications will appear here.');
          }
          return ListView(
              padding: const EdgeInsets.all(16),
              children: rows
                  .map((n) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                          onTap: () async {
                            final id = n.s('id');
                            if (n.s('source') == 'system' && id.isNotEmpty) {
                              await ref
                                  .read(customerRepositoryProvider)
                                  .markSystemNotificationRead(id);
                            }
                          },
                          child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                  n.s('source') == 'system'
                                      ? Icons.campaign_rounded
                                      : Icons.notifications_rounded,
                                  color: AppColors.primary),
                              title: Text(
                                  n.s('message', n.s('title', n.s('type')))),
                              subtitle: Text(
                                  '${n.s('source', 'social')} · ${shortDate(n['created_at'] ?? n['createdAt'])}')))))
                  .toList());
        },
      ),
    );
  }
}

class SocialReelsPage extends ConsumerWidget {
  const SocialReelsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomerScaffold(
      title: 'Reels',
      showBack: true,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: ref.read(customerRepositoryProvider).socialFeed(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final reels = (snapshot.data ?? []).where((post) {
            final list = post['media_urls'];
            final urls = list is List
                ? list.map((e) => e.toString()).toList()
                : <String>[];
            return urls.any(isVideoUrl) ||
                post.s('post_type') == 'video' ||
                post.s('postType') == 'video' ||
                post.s('media_type') == 'video';
          }).toList();
          if (reels.isEmpty) {
            return const _SocialPlaceholder(
                title: 'Reels',
                icon: Icons.movie_rounded,
                message: 'No reels yet. Video posts will appear here.');
          }
          return PageView.builder(
            scrollDirection: Axis.vertical,
            itemCount: reels.length,
            itemBuilder: (context, index) {
              final post = reels[index];
              final list = post['media_urls'];
              final urls = list is List
                  ? list.map((e) => e.toString()).toList()
                  : <String>[];
              final url = urls.firstWhere(isVideoUrl,
                  orElse: () => urls.isNotEmpty ? urls.first : '');
              return Stack(
                fit: StackFit.expand,
                children: [
                  SocialVideo(url: url, height: double.infinity),
                  Positioned(
                    right: 8,
                    bottom: 90,
                    child: _ReelActions(post: post),
                  ),
                  Positioned(
                    left: 16,
                    right: 72,
                    bottom: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(post.s('username', 'Planext user'),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 15)),
                        if (post
                            .s('caption', post.s('content'))
                            .isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(post.s('caption', post.s('content')),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70)),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Right-side action rail for a reel: like / comment / share / save — the same
/// endpoints as feed posts (web ReelCard).
class _ReelActions extends ConsumerStatefulWidget {
  const _ReelActions({required this.post});
  final Map<String, dynamic> post;

  @override
  ConsumerState<_ReelActions> createState() => _ReelActionsState();
}

class _ReelActionsState extends ConsumerState<_ReelActions> {
  late bool _liked = widget.post['liked'] == true;
  late bool _saved = widget.post['saved'] == true;
  late int _likes = widget.post.i('likes_count', widget.post.i('like_count'));
  late int _comments =
      widget.post.i('comments_count', widget.post.i('comment_count'));
  late int _shares =
      widget.post.i('shares_count', widget.post.i('share_count'));
  bool _likeBusy = false;
  bool _saveBusy = false;
  bool _shareBusy = false;

  @override
  void didUpdateWidget(covariant _ReelActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_likeBusy) return;
    _liked = widget.post['liked'] == true;
    _saved = widget.post['saved'] == true;
    _likes = widget.post.i('likes_count', widget.post.i('like_count'));
    _comments = widget.post.i('comments_count', widget.post.i('comment_count'));
    _shares = widget.post.i('shares_count', widget.post.i('share_count'));
  }

  Future<void> _like() async {
    if (_likeBusy) return;
    final repo = ref.read(customerRepositoryProvider);
    final id = widget.post.s('id');
    if (id.isEmpty) return;
    final was = _liked;
    setState(() {
      _likeBusy = true;
      _liked = !was;
      _likes += was ? -1 : 1;
      if (_likes < 0) _likes = 0;
      widget.post['liked'] = _liked;
      widget.post['likes_count'] = _likes;
    });
    try {
      was ? await repo.unlikeSocialPost(id) : await repo.likeSocialPost(id);
    } catch (error) {
      if (mounted) {
        setState(() {
          _liked = was;
          _likes += was ? 1 : -1;
          widget.post['liked'] = _liked;
          widget.post['likes_count'] = _likes;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update like: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _likeBusy = false);
    }
  }

  Future<void> _save() async {
    if (_saveBusy) return;
    final repo = ref.read(customerRepositoryProvider);
    final id = widget.post.s('id');
    if (id.isEmpty) return;
    final was = _saved;
    setState(() {
      _saveBusy = true;
      _saved = !was;
      widget.post['saved'] = _saved;
    });
    try {
      was ? await repo.unsaveSocialPost(id) : await repo.saveSocialPost(id);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saved = was;
          widget.post['saved'] = was;
        });
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not update saved post: $error')));
      }
    } finally {
      if (mounted) setState(() => _saveBusy = false);
    }
  }

  Future<void> _share() async {
    if (_shareBusy) return;
    final id = widget.post.s('id');
    if (id.isEmpty) return;
    setState(() {
      _shareBusy = true;
      _shares += 1;
      widget.post['shares_count'] = _shares;
    });
    try {
      await ref.read(customerRepositoryProvider).shareSocialPost(id);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Post shared')));
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _shares = _shares > 0 ? _shares - 1 : 0;
          widget.post['shares_count'] = _shares;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not share: $error')));
      }
    } finally {
      if (mounted) setState(() => _shareBusy = false);
    }
  }

  Future<void> _openComments() async {
    final id = widget.post.s('id');
    if (id.isEmpty) return;
    await context.push('/app/social/comments/$id');
    if (!mounted) return;
    try {
      final refreshed =
          await ref.read(customerRepositoryProvider).socialPost(id);
      if (!mounted || refreshed == null) return;
      setState(() {
        _comments = refreshed.i(
            'comments_count', refreshed.i('comment_count', _comments));
        widget.post['comments_count'] = _comments;
      });
    } catch (_) {}
  }

  Widget _btn(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          IconButton(
              onPressed: onTap,
              icon: Icon(icon, color: color ?? Colors.white, size: 30)),
          if (label.isNotEmpty)
            Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _btn(_liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            '$_likes', _like,
            color: _liked ? Colors.red : Colors.white),
        _btn(Icons.mode_comment_outlined, '$_comments', _openComments),
        _btn(Icons.share_outlined, _shares > 0 ? '$_shares' : '', _share),
        _btn(_saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            '', _save),
      ],
    );
  }
}

/// Horizontal story rail shown at the top of the feed. First circle is
/// "Your Story" (opens the composer / your segments), followed by other users'
/// stories with a teal ring when unviewed — mirrors the web story rail.
class _SocialStoryRail extends ConsumerStatefulWidget {
  const _SocialStoryRail({required this.ads, required this.config});

  final List<Map<String, dynamic>> ads;
  final Map<String, dynamic> config;

  @override
  ConsumerState<_SocialStoryRail> createState() => _SocialStoryRailState();
}

class _SocialStoryRailState extends ConsumerState<_SocialStoryRail> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(customerRepositoryProvider).socialStories();
  }

  void _reload() {
    setState(() {
      _future = ref.read(customerRepositoryProvider).socialStories();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(customerAuthStateProvider).valueOrNull;
    final myId = auth?.supabaseUid ?? auth?.id ?? '';
    return SizedBox(
      height: 96,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          final data = snapshot.data ?? const {};
          final mine = (data['mine'] as List?) ?? const [];
          final groups = (data['groups'] as List?) ?? const [];
          final hasMine = mine.isNotEmpty;
          final adEveryN =
              (widget.config['adEveryN'] as int? ?? 5).clamp(1, 100);
          return ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _StoryAvatar(
                label: 'Your Story',
                imageUrl: hasMine
                    ? Map<String, dynamic>.from(mine.first as Map)
                        .s('media_url')
                    : '',
                unviewed: false,
                showAdd: true,
                onTap: () async {
                  if (hasMine) {
                    await context.push('/app/social/stories/$myId');
                  } else {
                    await context.push('/app/social/add-story');
                  }
                  _reload();
                },
                onAdd: () async {
                  await context.push('/app/social/add-story');
                  _reload();
                },
              ),
              if (hasMine && 1 % adEveryN == 0)
                _HybridSocioAdSlot(
                  slotIndex: 0,
                  ads: widget.ads,
                  config: widget.config,
                  compact: true,
                ),
              for (final entry in groups.indexed) ...[
                Builder(builder: (context) {
                  final raw = entry.$2;
                  final g = Map<String, dynamic>.from(raw as Map);
                  final segs = (g['segments'] as List?) ?? const [];
                  final unviewed =
                      segs.any((e) => (e as Map)['viewed'] != true);
                  final cover = segs.isNotEmpty
                      ? Map<String, dynamic>.from(segs.first as Map)
                          .s('media_url')
                      : g.s('avatar');
                  return _StoryAvatar(
                    label: g.s('username', 'Planext user'),
                    imageUrl: cover,
                    unviewed: unviewed,
                    onTap: () async {
                      await context
                          .push('/app/social/stories/${g.s('user_id')}');
                      _reload();
                    },
                  );
                }),
                if ((entry.$1 + 1 + (hasMine ? 1 : 0)) % adEveryN == 0)
                  _HybridSocioAdSlot(
                    slotIndex:
                        (entry.$1 + 1 + (hasMine ? 1 : 0)) ~/ adEveryN - 1,
                    ads: widget.ads,
                    config: widget.config,
                    compact: true,
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _StoryAvatar extends StatelessWidget {
  const _StoryAvatar({
    required this.label,
    required this.imageUrl,
    required this.unviewed,
    required this.onTap,
    this.showAdd = false,
    this.onAdd,
  });

  final String label;
  final String imageUrl;
  final bool unviewed;
  final bool showAdd;
  final VoidCallback? onTap;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: unviewed ? AppColors.primary : AppColors.border,
                      width: 2.5,
                    ),
                  ),
                  child: ClipOval(
                    child: imageUrl.isNotEmpty
                        ? RemoteImage(url: imageUrl, width: 56, height: 56)
                        : Container(
                            width: 56,
                            height: 56,
                            color: AppColors.card,
                            child: const Icon(Icons.person_rounded,
                                color: AppColors.muted),
                          ),
                  ),
                ),
                if (showAdd)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: GestureDetector(
                      onTap: onAdd,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        padding: const EdgeInsets.all(2),
                        child: const Icon(Icons.add,
                            size: 14, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

/// Add Story composer: pick an image/video, optional text overlay, upload and
/// create the story. Mirrors the web CreateStoryModal fields.
class SocialAddStoryPage extends ConsumerStatefulWidget {
  const SocialAddStoryPage({super.key});

  @override
  ConsumerState<SocialAddStoryPage> createState() => _SocialAddStoryPageState();
}

class _SocialAddStoryPageState extends ConsumerState<SocialAddStoryPage> {
  final _caption = TextEditingController();
  XFile? _picked;
  bool _isVideo = false;
  bool _busy = false;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    try {
      final file = await ImagePicker().pickMedia();
      if (file == null) return;
      final bytes = await file.length();
      if (bytes <= 0) throw Exception('The selected file is empty.');
      if (bytes > 50 * 1024 * 1024) {
        throw Exception('Stories must be smaller than 50 MB.');
      }
      final lower = file.path.toLowerCase();
      final mime = (file.mimeType ?? '').toLowerCase();
      if (!mounted) return;
      setState(() {
        _picked = file;
        _isVideo = mime.startsWith('video/') ||
            lower.endsWith('.mp4') ||
            lower.endsWith('.mov') ||
            lower.endsWith('.webm') ||
            lower.endsWith('.m4v') ||
            lower.endsWith('.avi');
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not select media: $e')));
    }
  }

  Future<void> _share() async {
    if (_picked == null || _busy) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(customerRepositoryProvider);
      final uploaded = await repo.uploadSocialMediaFile(
        File(_picked!.path),
        contentType: _picked!.mimeType,
      );
      final url = uploaded.s('url');
      if (url.isEmpty) throw Exception('Upload failed');
      await repo.createSocialStory(
        mediaUrl: url,
        mediaType: uploaded.s('type', _isVideo ? 'video' : 'image'),
        textOverlay: _caption.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Story added')));
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not add story: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(customerAuthStateProvider).valueOrNull;
    if (auth == null) return const LoginRequiredPage();
    return CustomerScaffold(
      title: 'Add Story',
      showBack: true,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GestureDetector(
                  onTap: _busy ? null : _pick,
                  child: AspectRatio(
                    aspectRatio: 9 / 16,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _picked == null
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add_a_photo_rounded,
                                      color: Colors.white70, size: 40),
                                  SizedBox(height: 8),
                                  Text('Tap to add a photo or video',
                                      style: TextStyle(color: Colors.white70)),
                                ],
                              ),
                            )
                          : _isVideo
                              ? const Center(
                                  child: Icon(Icons.videocam_rounded,
                                      color: Colors.white, size: 48))
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(File(_picked!.path),
                                      fit: BoxFit.cover),
                                ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _caption,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.text_fields_rounded),
                    hintText: 'Add a caption (optional)',
                  ),
                ),
                const SizedBox(height: 6),
                const Text('Story expires after 24 hours',
                    style: TextStyle(color: AppColors.muted, fontSize: 12)),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _picked == null || _busy ? null : _share,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send_rounded),
                  label: Text(_busy ? 'Sharing…' : 'Share to Story'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen story viewer: segmented progress bars, tap left/right to
/// navigate, auto-advance, view tracking, and delete for your own story.
class SocialStoryViewerPage extends ConsumerStatefulWidget {
  const SocialStoryViewerPage({required this.userId, super.key});
  final String userId;

  @override
  ConsumerState<SocialStoryViewerPage> createState() =>
      _SocialStoryViewerPageState();
}

class _SocialStoryViewerPageState extends ConsumerState<SocialStoryViewerPage> {
  List<Map<String, dynamic>> _segments = const [];
  bool _isMine = false;
  bool _loading = true;
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(customerRepositoryProvider);
    final auth = ref.read(customerAuthStateProvider).valueOrNull;
    final myId = auth?.supabaseUid ?? auth?.id ?? '';
    final data = await repo.socialStories();
    final mine = ((data['mine'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final groups = (data['groups'] as List?) ?? const [];
    List<Map<String, dynamic>> segs = const [];
    var isMine = false;
    if (widget.userId == myId || widget.userId == 'me') {
      segs = mine;
      isMine = true;
    } else {
      for (final raw in groups) {
        final g = Map<String, dynamic>.from(raw as Map);
        if (g.s('user_id') == widget.userId) {
          segs = ((g['segments'] as List?) ?? const [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          break;
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _segments = segs;
      _isMine = isMine;
      _loading = false;
    });
    if (segs.isNotEmpty) _showSegment(0);
  }

  void _showSegment(int i) {
    _timer?.cancel();
    if (i < 0 || i >= _segments.length) {
      if (mounted) context.pop();
      return;
    }
    setState(() => _index = i);
    final seg = _segments[i];
    if (!_isMine) {
      ref.read(customerRepositoryProvider).viewSocialStory(seg.s('id'));
    }
    // Images auto-advance after 5s; videos advance via their own player length
    // (kept simple here with a longer fallback).
    final isVideo = seg.s('media_type') == 'video';
    _timer =
        Timer(Duration(seconds: isVideo ? 15 : 5), () => _showSegment(i + 1));
  }

  Future<void> _delete() async {
    final seg = _segments[_index];
    try {
      await ref.read(customerRepositoryProvider).deleteSocialStory(seg.s('id'));
      if (mounted) context.pop();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_segments.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black),
        body: const Center(
            child: Text('No stories', style: TextStyle(color: Colors.white))),
      );
    }
    final seg = _segments[_index];
    final isVideo = seg.s('media_type') == 'video';
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Center(
                child: isVideo
                    ? SocialVideo(url: seg.s('media_url'), height: 600)
                    : RemoteImage(url: seg.s('media_url')),
              ),
            ),
            // Tap zones: left = previous, right = next.
            Positioned.fill(
              child: Row(
                children: [
                  Expanded(
                      child: GestureDetector(
                          onTap: () => _showSegment(_index - 1),
                          behavior: HitTestBehavior.translucent)),
                  Expanded(
                      child: GestureDetector(
                          onTap: () => _showSegment(_index + 1),
                          behavior: HitTestBehavior.translucent)),
                ],
              ),
            ),
            // Segmented progress bars.
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  for (var i = 0; i < _segments.length; i++)
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        height: 3,
                        decoration: BoxDecoration(
                          color: i <= _index ? Colors.white : Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              top: 20,
              right: 8,
              child: Row(
                children: [
                  if (_isMine)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: Colors.white),
                      onPressed: _delete,
                    ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                ],
              ),
            ),
            if (_isMine && seg.i('view_count') > 0)
              Positioned(
                bottom: 16,
                left: 16,
                child: Row(
                  children: [
                    const Icon(Icons.remove_red_eye_outlined,
                        color: Colors.white70, size: 18),
                    const SizedBox(width: 4),
                    Text('${seg.i('view_count')}',
                        style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SocialFollowersPage extends ConsumerWidget {
  const SocialFollowersPage(
      {required this.userId, this.following = false, super.key});
  final String userId;
  final bool following;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(customerRepositoryProvider);
    return CustomerScaffold(
      title: following ? 'Following' : 'Followers',
      showBack: true,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: following
            ? repo.socialFollowing(userId)
            : repo.socialFollowers(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snapshot.data ?? [];
          if (rows.isEmpty) {
            return EmptyState(
                icon: Icons.people_rounded,
                title: following ? 'Not following anyone' : 'No followers yet',
                message: 'Connections will appear here.');
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ProfileRow(profile: r),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Saved posts grid (web Profile → Saved tab / SavedPanel).
class SocialSavedPostsPage extends ConsumerWidget {
  const SocialSavedPostsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(customerAuthStateProvider).valueOrNull;
    if (auth == null) return const LoginRequiredPage();
    return CustomerScaffold(
      title: 'Saved',
      showBack: true,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: ref.read(customerRepositoryProvider).socialSavedPosts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snapshot.data ?? [];
          if (rows.isEmpty) {
            return const EmptyState(
                icon: Icons.bookmark_border_rounded,
                title: 'No saved posts',
                message: 'Posts you save will appear here.');
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final p in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SocialPostCard(post: p),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Stateful Follow/Following button used on the profile header.
class _ProfileFollowButton extends ConsumerStatefulWidget {
  const _ProfileFollowButton(
      {required this.userId, required this.initialFollowing});
  final String userId;
  final bool initialFollowing;

  @override
  ConsumerState<_ProfileFollowButton> createState() =>
      _ProfileFollowButtonState();
}

class _ProfileFollowButtonState extends ConsumerState<_ProfileFollowButton> {
  late bool _following = widget.initialFollowing;
  bool _busy = false;

  @override
  void didUpdateWidget(covariant _ProfileFollowButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_busy &&
        (oldWidget.userId != widget.userId ||
            oldWidget.initialFollowing != widget.initialFollowing)) {
      _following = widget.initialFollowing;
    }
  }

  Future<void> _toggle() async {
    if (widget.userId.isEmpty || _busy) return;
    final repo = ref.read(customerRepositoryProvider);
    final was = _following;
    setState(() {
      _following = !was;
      _busy = true;
    });
    try {
      if (was) {
        await repo.unfollowSocialUser(widget.userId);
      } else {
        await repo.followSocialUser(widget.userId);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _following = was);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not update follow: $error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _following
        ? OutlinedButton(
            onPressed: _busy ? null : _toggle, child: const Text('Following'))
        : FilledButton(
            onPressed: _busy ? null : _toggle, child: const Text('Follow'));
  }
}

class SocialEditProfilePage extends ConsumerStatefulWidget {
  const SocialEditProfilePage({super.key});

  @override
  ConsumerState<SocialEditProfilePage> createState() =>
      _SocialEditProfilePageState();
}

class _SocialEditProfilePageState extends ConsumerState<SocialEditProfilePage> {
  final _name = TextEditingController();
  final _bio = TextEditingController();
  XFile? _avatar;
  String _existingAvatar = '';
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final p = await ref.read(customerRepositoryProvider).socialProfile('me');
    if (!mounted) return;
    setState(() {
      _name.text = p?.s('display_name', p.s('userName', p.s('name', ''))) ?? '';
      _bio.text = p?.s('bio') ?? '';
      _existingAvatar =
          p?.s('userAvatar', p.s('avatarUrl', p.s('avatar'))) ?? '';
      _loading = false;
    });
  }

  Future<void> _pickAvatar() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file != null) setState(() => _avatar = file);
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = ref.read(customerRepositoryProvider);
      String? avatarUrl;
      if (_avatar != null) {
        final uploaded = await repo.uploadSocialMediaFile(File(_avatar!.path));
        avatarUrl = uploaded.s('url');
      }
      await repo.updateSocialProfile(
        name: _name.text.trim(),
        bio: _bio.text.trim(),
        avatarUrl: avatarUrl,
      );
      messenger.showSnackBar(const SnackBar(content: Text('Profile updated')));
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text('Could not update: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const CustomerScaffold(
        title: 'Edit Profile',
        showBack: true,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final preview = _avatar != null
        ? null
        : (_existingAvatar.isNotEmpty ? _existingAvatar : '');
    return CustomerScaffold(
      title: 'Edit Profile',
      showBack: true,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _busy ? null : _pickAvatar,
                    child: CircleAvatar(
                      radius: 44,
                      backgroundColor: AppColors.accent,
                      backgroundImage: _avatar != null
                          ? FileImage(File(_avatar!.path))
                          : (preview != null && preview.isNotEmpty
                              ? NetworkImage(preview)
                              : null) as ImageProvider?,
                      child: (_avatar == null &&
                              (preview == null || preview.isEmpty))
                          ? const Icon(Icons.add_a_photo_rounded,
                              color: AppColors.primary)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.person_rounded),
                        labelText: 'Name')),
                const SizedBox(height: 12),
                TextField(
                    controller: _bio,
                    maxLength: 150,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.info_outline_rounded),
                        labelText: 'Bio')),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _busy ? null : _save,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check_rounded),
                  label: Text(_busy ? 'Saving…' : 'Save'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SocialCreatorDashboardPage extends StatelessWidget {
  const SocialCreatorDashboardPage({super.key});

  @override
  Widget build(BuildContext context) => const _SocialPlaceholder(
      title: 'Creator Dashboard',
      icon: Icons.dashboard_rounded,
      message: 'Creator stats, post performance, and monetization tools.');
}

class SocialLivePage extends StatelessWidget {
  const SocialLivePage({super.key});

  @override
  Widget build(BuildContext context) => const _SocialPlaceholder(
      title: 'Live',
      icon: Icons.live_tv_rounded,
      message: 'Go live and interact with followers.');
}

class SocialBroadcastPage extends StatelessWidget {
  const SocialBroadcastPage({super.key});

  @override
  Widget build(BuildContext context) => const _SocialPlaceholder(
      title: 'Broadcast Channels',
      icon: Icons.campaign_rounded,
      message: 'Create and manage broadcast updates.');
}

class SocialShopPage extends StatelessWidget {
  const SocialShopPage({super.key});

  @override
  Widget build(BuildContext context) => const _SocialPlaceholder(
      title: 'Social Shop',
      icon: Icons.shopping_bag_rounded,
      message: 'Tag products and shop from creator posts.');
}

class SocialSettingsPage extends ConsumerStatefulWidget {
  const SocialSettingsPage({super.key});

  @override
  ConsumerState<SocialSettingsPage> createState() => _SocialSettingsPageState();
}

class _SocialSettingsPageState extends ConsumerState<SocialSettingsPage> {
  static const _notifKeys = [
    'likes',
    'comments',
    'follows',
    'messages',
    'reposts',
    'mentions',
    'liveVideos',
    'emailNotifs',
  ];

  Map<String, dynamic> _settings = {};
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await ref.read(customerRepositoryProvider).socialSettings();
    if (!mounted) return;
    setState(() {
      _settings = Map<String, dynamic>.from(s);
      _loading = false;
    });
  }

  bool _boolOf(String key, [bool fallback = false]) =>
      _settings[key] == null ? fallback : _settings[key] == true;

  Map<String, dynamic> get _notifs => _settings['notifications'] is Map
      ? Map<String, dynamic>.from(_settings['notifications'] as Map)
      : <String, dynamic>{};

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(customerRepositoryProvider)
          .updateSocialSettings(_settings);
      messenger.showSnackBar(const SnackBar(content: Text('Settings saved')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not save: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const CustomerScaffold(
        title: 'Social Settings',
        showBack: true,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return CustomerScaffold(
      title: 'Social Settings',
      showBack: true,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsTile(
              'Edit Profile', Icons.person_rounded, '/app/social/edit-profile'),
          _SettingsTile('Saved', Icons.bookmark_rounded, '/app/social/saved'),
          _SettingsTile('Friends', Icons.people_rounded, '/app/social/friends'),
          _SettingsTile('Suggestions', Icons.person_add_alt_rounded,
              '/app/social/suggestions'),
          const SizedBox(height: 8),
          const SectionHeader(title: 'Privacy'),
          AppCard(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Private account'),
                  value: _boolOf('privateAccount'),
                  onChanged: (v) =>
                      setState(() => _settings['privateAccount'] = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show activity status'),
                  value: _boolOf('showActivityStatus', true),
                  onChanged: (v) =>
                      setState(() => _settings['showActivityStatus'] = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Filter offensive comments'),
                  value: _boolOf('filterOffensiveComments'),
                  onChanged: (v) =>
                      setState(() => _settings['filterOffensiveComments'] = v),
                ),
                _allowFromSelect('Who can message you', 'messageAllowFrom'),
                _allowFromSelect('Who can comment', 'commentsAllowFrom'),
              ],
            ),
          ),
          const SectionHeader(title: 'Notifications'),
          AppCard(
            child: Column(
              children: [
                for (final k in _notifKeys)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_notifLabel(k)),
                    value: _notifs[k] == true,
                    onChanged: (v) {
                      final n = _notifs;
                      n[k] = v;
                      setState(() => _settings['notifications'] = n);
                    },
                  ),
              ],
            ),
          ),
          const SectionHeader(title: 'Time management'),
          AppCard(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Daily reminder'),
              value: _boolOf('dailyReminder'),
              onChanged: (v) => setState(() => _settings['dailyReminder'] = v),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_rounded),
            label: Text(_busy ? 'Saving…' : 'Save settings'),
          ),
        ],
      ),
    );
  }

  Widget _allowFromSelect(String label, String key) {
    final value = (_settings[key] ?? 'everyone').toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          DropdownButton<String>(
            value: const ['everyone', 'followers', 'none'].contains(value)
                ? value
                : 'everyone',
            items: const [
              DropdownMenuItem(value: 'everyone', child: Text('Everyone')),
              DropdownMenuItem(value: 'followers', child: Text('Followers')),
              DropdownMenuItem(value: 'none', child: Text('No one')),
            ],
            onChanged: (v) => setState(() => _settings[key] = v ?? 'everyone'),
          ),
        ],
      ),
    );
  }

  String _notifLabel(String key) {
    switch (key) {
      case 'liveVideos':
        return 'Live videos';
      case 'emailNotifs':
        return 'Email notifications';
      default:
        return key[0].toUpperCase() + key.substring(1);
    }
  }
}

class SocialPrivacyPage extends StatelessWidget {
  const SocialPrivacyPage({super.key});

  @override
  Widget build(BuildContext context) => const _SocialPlaceholder(
      title: 'Privacy',
      icon: Icons.privacy_tip_rounded,
      message: 'Manage profile visibility, mentions, tags and blocking.');
}

class SocialSecurityPage extends StatelessWidget {
  const SocialSecurityPage({super.key});

  @override
  Widget build(BuildContext context) => const _SocialPlaceholder(
      title: 'Security',
      icon: Icons.security_rounded,
      message: 'Review login sessions and account safety.');
}

class SocialNotificationSettingsPage extends StatelessWidget {
  const SocialNotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context) => const _SocialPlaceholder(
      title: 'Notification Settings',
      icon: Icons.notifications_active_rounded,
      message: 'Choose which Socio alerts you want to receive.');
}

class SocialHelpCenterPage extends StatelessWidget {
  const SocialHelpCenterPage({super.key});

  @override
  Widget build(BuildContext context) => const _SocialPlaceholder(
      title: 'Help Center',
      icon: Icons.help_center_rounded,
      message: 'Find social safety, reporting and creator help.');
}

class SocialSuggestionsPage extends ConsumerWidget {
  const SocialSuggestionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomerScaffold(
      title: 'Suggestions',
      showBack: true,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: ref.read(customerRepositoryProvider).socialProfiles(),
        builder: (context, snapshot) {
          final rows = snapshot.data ?? [];
          if (rows.isEmpty) {
            return const EmptyState(
                icon: Icons.person_add_alt_rounded,
                title: 'No suggestions',
                message: 'Suggested people will appear here.');
          }
          return ListView(
              padding: const EdgeInsets.all(16),
              children: rows
                  .map((u) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(child: _ProfileRow(profile: u))))
                  .toList());
        },
      ),
    );
  }
}

class SocialFriendsPage extends StatelessWidget {
  const SocialFriendsPage({super.key});

  @override
  Widget build(BuildContext context) => const _SocialPlaceholder(
      title: 'Friends',
      icon: Icons.people_alt_rounded,
      message: 'Your friends and close connections.');
}

class SocialUserPostsPage extends ConsumerWidget {
  const SocialUserPostsPage(
      {required this.userId, required this.postId, super.key});
  final String userId;
  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomerScaffold(
      title: 'User Posts',
      showBack: true,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: ref.read(customerRepositoryProvider).socialUserPosts(userId),
        builder: (context, snapshot) {
          final rows = snapshot.data ?? [];
          if (rows.isEmpty) {
            return const EmptyState(
                icon: Icons.grid_on_rounded,
                title: 'No posts',
                message: 'User posts will appear here.');
          }
          return ListView(
              padding: const EdgeInsets.all(16),
              children: rows
                  .map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SocialPostCard(post: p)))
                  .toList());
        },
      ),
    );
  }
}

class _SocialQuickNav extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Web parity: no Live/Shop/Channels/Dashboard in Socio nav.
    final items = [
      ('Explore', Icons.search_rounded, '/app/social/explore'),
      ('Reels', Icons.movie_rounded, '/app/social/reels'),
      ('Friends', Icons.people_rounded, '/app/social/friends'),
      ('Saved', Icons.bookmark_border_rounded, '/app/social/saved'),
    ];
    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = items[index];
          return AppCard(
            onTap: () => context.push(item.$3),
            child: SizedBox(
                width: 82,
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(item.$2, color: AppColors.primary),
                      const SizedBox(height: 4),
                      Text(item.$1,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 12))
                    ])),
          );
        },
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.profile});
  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) {
    final userId = profile.s('user_id', profile.s('userId', profile.s('id')));
    final following = profile['isFollowing'] == true ||
        profile['following'] == true ||
        profile['followed'] == true;
    return Row(
      children: [
        const CircleAvatar(
            backgroundColor: AppColors.accent,
            child: Icon(Icons.person_rounded, color: AppColors.primary)),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(profile.s('display_name', profile.s('username', 'User')),
                style: const TextStyle(fontWeight: FontWeight.w900)),
            Text('@${profile.s('username')}',
                style: const TextStyle(color: AppColors.muted)),
          ]),
        ),
        if (userId.isNotEmpty)
          _ProfileFollowButton(userId: userId, initialFollowing: following),
      ],
    );
  }
}

class _Count extends StatelessWidget {
  const _Count(this.label, this.value);
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Column(children: [
        Text('$value',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        Text(label,
            style: const TextStyle(color: AppColors.muted, fontSize: 12))
      ]);
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile(this.label, this.icon, this.route);
  final String label;
  final IconData icon;
  final String route;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AppCard(
            onTap: () => context.push(route),
            child: Row(children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w800))),
              const Icon(Icons.chevron_right_rounded)
            ])),
      );
}

class _SocialPlaceholder extends StatelessWidget {
  const _SocialPlaceholder(
      {required this.title, required this.icon, required this.message});
  final String title;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return CustomerScaffold(
      title: title,
      showBack: true,
      child: EmptyState(icon: icon, title: title, message: message),
    );
  }
}
