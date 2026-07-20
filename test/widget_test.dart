import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:p4u_customer_app/src/features/customer/data/customer_providers.dart';
import 'package:p4u_customer_app/src/features/customer/data/customer_repository.dart';
import 'package:p4u_customer_app/src/features/customer/presentation/pages/social_pages.dart';

class _FakeSocialRepository extends CustomerRepository {
  _FakeSocialRepository({this.failLike = false});

  final bool failLike;
  int likeCalls = 0;

  @override
  Future<void> likeSocialPost(String postId) async {
    likeCalls++;
    if (failLike) throw Exception('like failed');
  }
}

Widget _postCard(_FakeSocialRepository repository) {
  return ProviderScope(
    overrides: [customerRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      home: Scaffold(
        body: SocialPostCard(
          post: <String, dynamic>{
            'id': 'post-1',
            'user_id': 'author-1',
            'username': 'Creator',
            'caption': 'Hello',
            'liked': false,
            'saved': false,
            'likes_count': 2,
            'comments_count': 1,
            'shares_count': 0,
          },
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('Socio like reflects immediately and calls the API once',
      (tester) async {
    final repository = _FakeSocialRepository();
    await tester.pumpWidget(_postCard(repository));

    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pump();

    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(repository.likeCalls, 1);
  });

  testWidgets('Socio like rolls back when the API fails', (tester) async {
    final repository = _FakeSocialRepository(failLike: true);
    await tester.pumpWidget(_postCard(repository));

    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.textContaining('Could not update like'), findsOneWidget);
  });
}
