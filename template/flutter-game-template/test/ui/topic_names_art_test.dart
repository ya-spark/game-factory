import 'package:flutter/material.dart';
import 'package:flutter_game_template/core/profile/child_profile.dart';
import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_game_template/ui/game_registry.dart';
import 'package:flutter_game_template/ui/kit/ds_art.dart';
import 'package:flutter_game_template/ui/tabs/tab_data.dart';
import 'package:flutter_test/flutter_test.dart';

LoadedPack _pack(String topic, String title, {String? product}) => LoadedPack(
  ContentPack({
    'id': 'p_$topic${product ?? ''}',
    'version': 1,
    'lang': 'en-AU',
    'subject': 'english',
    'year': 3,
    'topic': topic,
    'title': title,
    'product_id': ?product,
    'items': <Object>[],
  }),
);

void main() {
  group('topic display names', () {
    test('uses the pack title, preferring the base pack', () {
      final packs = [
        _pack('spelling_rules', 'Extra spelling', product: 'x'),
        _pack('spelling_rules', 'Spelling rules'),
      ];
      expect(
        topicDisplayName(packs, 'english', 3, 'spelling_rules'),
        'Spelling rules',
      );
    });

    test('falls back to a tidied id', () {
      expect(
        topicDisplayName(const [], 'english', 3, 'adjectives_adverbs'),
        'Adjectives adverbs',
      );
      expect(tidyTopicId('patterns'), 'Patterns');
    });

    testWidgets('a raw id is never shown when the pack has a name', (
      tester,
    ) async {
      final packs = [_pack('adjectives_adverbs', 'Adjectives and adverbs')];
      await tester.pumpWidget(
        MaterialApp(
          home: Text(
            topicDisplayName(packs, 'english', 3, 'adjectives_adverbs'),
          ),
        ),
      );
      expect(find.text('Adjectives and adverbs'), findsOneWidget);
      expect(find.textContaining('_'), findsNothing);
    });
  });

  group('art', () {
    test('every registered game has its own art', () {
      for (final e in appGames.entries) {
        expect(gameArt.containsKey(e.game.id), isTrue, reason: e.game.id);
      }
    });

    test('every avatar has its own shape', () {
      for (final a in avatarIds) {
        expect(avatarArt.containsKey(a), isTrue, reason: a);
      }
    });

    test('tiles of different games are not the same picture', () {
      expect(gameArt.values.toSet().length, gameArt.length);
      expect(avatarArt.values.toSet().length, avatarArt.length);
    });

    testWidgets('art builds at 150 percent text without overflow', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await tester.pumpWidget(
        MaterialApp(
          home: SingleChildScrollView(
            child: Wrap(
              children: [
                for (final id in gameArt.keys) DsGameArt(id, size: 48),
                for (final id in avatarArt.keys) DsAvatarArt(id, size: 48),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
