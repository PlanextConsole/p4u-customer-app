import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/map_ext.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/customer_scaffold.dart';
import '../../../../core/widgets/remote_image.dart';
import '../../../../core/widgets/social_video.dart';
import '../../../auth/data/auth_repository.dart';
import '../../data/customer_providers.dart';
import 'account_pages.dart';

class SocialFeedPage extends ConsumerWidget {
  const SocialFeedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        future: ref.read(customerRepositoryProvider).socialFeed(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final posts = snapshot.data ?? [];
          return RefreshIndicator(
            onRefresh: () async {},
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SocialQuickNav(),
                const SizedBox(height: 12),
                if (posts.isEmpty)
                  const EmptyState(
                      icon: Icons.groups_rounded,
                      title: 'No posts yet',
                      message: 'Create the first Socio post.')
                else
                  ...posts.map((post) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SocialPostCard(post: post))),
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
  late int _likes;

  @override
  void initState() {
    super.initState();
    final post = widget.post;
    _liked = post['liked'] == true;
    _saved = post['saved'] == true;
    _likes = post.i('likes_count', post.i('like_count'));
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
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            onTap: () =>
                context.push('/app/social/profile/${post.s('user_id')}'),
            leading: const CircleAvatar(
                backgroundColor: AppColors.accent,
                child: Icon(Icons.person_rounded, color: AppColors.primary)),
            title: Text(post.s('username', 'Planext user'),
                style: const TextStyle(fontWeight: FontWeight.w900)),
            subtitle: Text(shortDate(post['created_at'])),
            trailing: IconButton(
                onPressed: () =>
                    context.push('/app/social/post/${post.s('id')}'),
                icon: const Icon(Icons.more_horiz_rounded)),
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
                const SizedBox(height: 10),
                Row(
                  children: [
                    IconButton(
                        onPressed: () => _toggleLike(postId),
                        icon: Icon(
                          _liked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: _liked ? Colors.red : null,
                        )),
                    Text('$_likes'),
                    IconButton(
                        onPressed: () =>
                            context.push('/app/social/comments/$postId'),
                        icon: const Icon(Icons.mode_comment_outlined)),
                    Text(
                        '${post.i('comments_count', post.i('comment_count'))}'),
                    IconButton(
                        onPressed: () => _share(postId),
                        icon: const Icon(Icons.share_outlined)),
                    const Spacer(),
                    IconButton(
                        onPressed: () => _toggleSave(postId),
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

  Future<void> _toggleLike(String postId) async {
    if (postId.isEmpty) return;
    final repo = ref.read(customerRepositoryProvider);
    final wasLiked = _liked;
    setState(() {
      _liked = !wasLiked;
      _likes += wasLiked ? -1 : 1;
      if (_likes < 0) _likes = 0;
    });
    try {
      if (wasLiked) {
        await repo.unlikeSocialPost(postId);
      } else {
        await repo.likeSocialPost(postId);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _liked = wasLiked;
        _likes += wasLiked ? 1 : -1;
        if (_likes < 0) _likes = 0;
      });
    }
  }

  Future<void> _toggleSave(String postId) async {
    if (postId.isEmpty) return;
    final repo = ref.read(customerRepositoryProvider);
    final wasSaved = _saved;
    setState(() => _saved = !wasSaved);
    try {
      if (wasSaved) {
        await repo.unsaveSocialPost(postId);
      } else {
        await repo.saveSocialPost(postId);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _saved = wasSaved);
    }
  }

  Future<void> _share(String postId) async {
    if (postId.isEmpty) return;
    try {
      await ref.read(customerRepositoryProvider).shareSocialPost(postId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post shared')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}

class SocialCreatePostPage extends ConsumerStatefulWidget {
  const SocialCreatePostPage({super.key});

  @override
  ConsumerState<SocialCreatePostPage> createState() =>
      _SocialCreatePostPageState();
}

class _SocialCreatePostPageState extends ConsumerState<SocialCreatePostPage> {
  final _caption = TextEditingController();
  final _image = TextEditingController();

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
              children: [
                TextField(
                    controller: _caption,
                    minLines: 4,
                    maxLines: 8,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.edit_rounded),
                        hintText: 'What do you want to share?')),
                const SizedBox(height: 12),
                TextField(
                    controller: _image,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.image_rounded),
                        hintText: 'Image URL optional')),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () async {
                    await ref
                        .read(customerRepositoryProvider)
                        .createSocialPost(auth.supabaseUid ?? auth.id, {
                      'caption': _caption.text.trim(),
                      'content': _caption.text.trim(),
                      if (_image.text.trim().isNotEmpty)
                        'image_url': _image.text.trim(),
                    });
                    if (context.mounted) context.go('/app/social');
                  },
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Post'),
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
                              onTap: () => context
                                  .go('/app/social/profile/${u.s('user_id')}'),
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
                            profile
                                .s('display_name', auth.name)
                                .characters
                                .first
                                .toUpperCase(),
                            style: const TextStyle(
                                fontSize: 30,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w900))),
                    const SizedBox(height: 10),
                    Text(profile.s('display_name', auth.name),
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 20)),
                    Text(
                        '@${profile.s('username', auth.name.toLowerCase().replaceAll(' ', ''))}',
                        style: const TextStyle(color: AppColors.muted)),
                    const SizedBox(height: 12),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _Count('Posts', profile.i('posts_count')),
                          _Count('Followers', profile.i('followers_count')),
                          _Count('Following', profile.i('following_count')),
                        ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                          child: OutlinedButton(
                              onPressed: () =>
                                  context.push('/app/social/edit-profile'),
                              child: const Text('Edit Profile'))),
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
                future: ref.read(customerRepositoryProvider).socialFeed(),
                builder: (context, posts) {
                  final rows = (posts.data ?? [])
                      .where((p) => p.s('user_id') == target)
                      .toList();
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
    _future = ref.read(customerRepositoryProvider).socialComments(widget.postId);
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
                if (rows.isEmpty) {
                  return const EmptyState(
                      icon: Icons.mode_comment_rounded,
                      title: 'No comments',
                      message: 'Be the first to comment.');
                }
                return ListView(
                    padding: const EdgeInsets.all(16),
                    children: rows
                        .map((c) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: AppCard(
                                child: Text(
                                    c.s('content', c.s('comment', c.s('contentText')))))))
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
                          title: Text(c.s('title', 'Conversation')),
                          subtitle: Text(shortDate(c['updated_at'])))))
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
                                child: Text(m.s(
                                    'content',
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
        _messages = ref
            .read(customerRepositoryProvider)
            .socialMessages(conversationId);
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
                              title: Text(n.s(
                                  'message', n.s('title', n.s('type')))),
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
                    left: 16,
                    right: 16,
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
                        if (post.s('caption', post.s('content')).isNotEmpty) ...[
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

class SocialStoryViewerPage extends StatelessWidget {
  const SocialStoryViewerPage({required this.userId, super.key});
  final String userId;

  @override
  Widget build(BuildContext context) => _SocialPlaceholder(
      title: 'Stories',
      icon: Icons.auto_stories_rounded,
      message: 'Stories for $userId.');
}

class SocialFollowersPage extends StatelessWidget {
  const SocialFollowersPage(
      {required this.userId, this.following = false, super.key});
  final String userId;
  final bool following;

  @override
  Widget build(BuildContext context) => _SocialPlaceholder(
      title: following ? 'Following' : 'Followers',
      icon: Icons.people_rounded,
      message: 'Social connections for $userId.');
}

class SocialEditProfilePage extends StatelessWidget {
  const SocialEditProfilePage({super.key});

  @override
  Widget build(BuildContext context) => const _SocialSettingsForm(
      title: 'Edit Social Profile',
      fields: ['Display name', 'Username', 'Bio']);
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

class SocialSettingsPage extends StatelessWidget {
  const SocialSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomerScaffold(
      title: 'Social Settings',
      showBack: true,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsTile(
              'Edit Profile', Icons.person_rounded, '/app/social/edit-profile'),
          _SettingsTile('Change Password', Icons.lock_rounded,
              '/app/social/change-password'),
          _SettingsTile('Notifications', Icons.notifications_rounded,
              '/app/social/notification-settings'),
          _SettingsTile(
              'Privacy', Icons.privacy_tip_rounded, '/app/social/privacy'),
          _SettingsTile(
              'Security', Icons.security_rounded, '/app/social/security'),
          _SettingsTile('Help Center', Icons.help_rounded, '/app/social/help'),
          _SettingsTile('Friends', Icons.people_rounded, '/app/social/friends'),
          _SettingsTile('Suggestions', Icons.person_add_alt_rounded,
              '/app/social/suggestions'),
        ],
      ),
    );
  }
}

class SocialChangePasswordPage extends StatelessWidget {
  const SocialChangePasswordPage({super.key});

  @override
  Widget build(BuildContext context) => const _SocialSettingsForm(
      title: 'Social Password', fields: ['New password', 'Confirm password']);
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
      message: 'Review login sessions, password settings and account safety.');
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
        future: ref.read(customerRepositoryProvider).socialFeed(),
        builder: (context, snapshot) {
          final rows = (snapshot.data ?? [])
              .where((p) => p.s('user_id') == userId)
              .toList();
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
    final items = [
      ('Explore', Icons.search_rounded, '/app/social/explore'),
      ('Reels', Icons.movie_rounded, '/app/social/reels'),
      ('Live', Icons.live_tv_rounded, '/app/social/live'),
      ('Shop', Icons.shopping_bag_rounded, '/app/social/shop'),
      ('Friends', Icons.people_rounded, '/app/social/friends'),
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

class _ProfileRow extends ConsumerWidget {
  const _ProfileRow({required this.profile});
  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        OutlinedButton(
          onPressed: userId.isEmpty
              ? null
              : () async {
                  final repo = ref.read(customerRepositoryProvider);
                  if (following) {
                    await repo.unfollowSocialUser(userId);
                  } else {
                    await repo.followSocialUser(userId);
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(following
                            ? 'Unfollowed'
                            : 'Following')));
                  }
                },
          child: Text(following ? 'Following' : 'Follow'),
        ),
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

class _SocialSettingsForm extends StatelessWidget {
  const _SocialSettingsForm({required this.title, required this.fields});
  final String title;
  final List<String> fields;

  @override
  Widget build(BuildContext context) {
    return CustomerScaffold(
      title: title,
      showBack: true,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Column(
              children: [
                for (final field in fields) ...[
                  TextField(
                      obscureText: field.toLowerCase().contains('password'),
                      decoration: InputDecoration(hintText: field)),
                  const SizedBox(height: 12),
                ],
                FilledButton(
                    onPressed: () => ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('Saved'))),
                    child: const Text('Save')),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
