import 'package:flutter/material.dart';
import 'package:flutter_game_template/core/speech/speech_service.dart';
import 'package:flutter_game_template/engine/engine.dart';
import 'package:flutter_game_template/ui/quick_quiz_screen.dart';
import 'package:flutter_game_template/ui/test_ids.dart';
import 'package:flutter_test/flutter_test.dart';

QuizSession _session({String? audio}) {
  final packs = [
    LoadedPack(
      ContentPack({
        'id': 'q',
        'version': 1,
        'lang': 'en-AU',
        'subject': 'maths',
        'year': 3,
        'topic': 't',
        'title': 'q',
        'items': [
          for (var i = 1; i <= 4; i++)
            {
              'id': 'q.$i',
              'seq': i,
              'difficulty': 1,
              'type': 'mcq',
              'explanation': 'Explained $i',
              'prompt': 'Question $i',
              'options': ['Alpha', 'Beta', 'Gamma'],
              'correct': 1,
              'audio': ?audio,
            },
        ],
      }),
    ),
  ];
  return QuizSession(
    items: ReleaseEngine.ordered(packs, 'maths', 3),
    progress: const ChildProgress(),
    packs: packs,
    rewardsConfig: const RewardsConfig(),
    today: 100,
  );
}

Widget _app(QuizSession s, ReadAloud? reader, {bool? autoRead}) => MaterialApp(
  home: QuickQuizScreen(
    session: s,
    mode: MiniGameMode.game,
    onExit: () {},
    reader: reader,
    autoRead: autoRead,
  ),
);

void main() {
  test('questionReadout reads the prompt then the numbered options', () {
    expect(
      questionReadout('What is 2 + 2?', ['3', '4']),
      'What is 2 + 2? Option 1. 3. Option 2. 4.',
    );
  });

  test(
    'recorded audio is used first, text-to-speech is the fallback',
    () async {
      final speech = FakeSpeechService();
      final played = <String>[];
      var clipExists = true;
      final r = ReadAloud(
        speech: speech,
        recorded: (ref) async {
          played.add(ref);
          return clipExists;
        },
      );
      expect(await r.read('Hello', audioRef: 'a.mp3'), isTrue);
      expect(played, ['a.mp3']);
      expect(speech.spoken, isEmpty);
      clipExists = false; // missing file
      await r.read('Hello', audioRef: 'a.mp3');
      expect(speech.spoken, ['Hello']);
      await r.read('No clip for this one'); // no audio ref
      expect(played.length, 2);
      expect(speech.spoken.last, 'No clip for this one');
    },
  );

  test('a failing recorded player falls back to text-to-speech', () async {
    final speech = FakeSpeechService();
    final r = ReadAloud(
      speech: speech,
      recorded: (_) async => throw StateError('boom'),
    );
    expect(await r.read('Hi', audioRef: 'x.mp3'), isTrue);
    expect(speech.spoken, ['Hi']);
  });

  test('nothing is read when no voice is available', () async {
    final r = ReadAloud(speech: FakeSpeechService(available: false));
    expect(await r.read('Hi'), isFalse);
  });

  testWidgets('the speaker button reads the prompt and the options', (t) async {
    final speech = FakeSpeechService();
    await t.pumpWidget(_app(_session(), ReadAloud(speech: speech)));
    expect(speech.spoken, isEmpty); // no automatic reading
    await t.tap(find.byKey(TestIds.quizSpeak));
    await t.pump();
    expect(speech.spoken, [
      'Question 1 Option 1. Alpha. Option 2. Beta. Option 3. Gamma.',
    ]);
  });

  testWidgets('auto_read reads each new question once', (t) async {
    final speech = FakeSpeechService();
    await t.pumpWidget(
      _app(_session(), ReadAloud(speech: speech), autoRead: true),
    );
    await t.pump();
    expect(speech.spoken.length, 1);
    expect(speech.spoken.single, startsWith('Question 1'));
    await t.tap(find.byKey(TestIds.quizOption(1)));
    await t.pump();
    expect(speech.spoken.length, 1); // answering does not read again
    await t.tap(find.byKey(TestIds.quizNext));
    await t.pump();
    await t.pump();
    expect(speech.spoken.length, 2);
    expect(speech.spoken.last, startsWith('Question 2'));
  });

  testWidgets('explanations are read only on request', (t) async {
    final speech = FakeSpeechService();
    await t.pumpWidget(
      _app(_session(), ReadAloud(speech: speech), autoRead: true),
    );
    await t.pump();
    await t.tap(find.byKey(TestIds.quizOption(1)));
    await t.pump();
    expect(speech.spoken.length, 1);
    await t.tap(find.byKey(TestIds.quizSpeakExplanation));
    await t.pump();
    expect(speech.spoken.last, 'Explained 1');
  });

  testWidgets('the recorded clip of an item is played before the voice', (
    t,
  ) async {
    final speech = FakeSpeechService();
    final played = <String>[];
    await t.pumpWidget(
      _app(
        _session(audio: 'q1.mp3'),
        ReadAloud(
          speech: speech,
          recorded: (ref) async {
            played.add(ref);
            return true;
          },
        ),
      ),
    );
    await t.tap(find.byKey(TestIds.quizSpeak));
    await t.pump();
    expect(played, ['q1.mp3']);
    expect(speech.spoken, isEmpty);
  });

  testWidgets('without a reader there is no speaker button', (t) async {
    await t.pumpWidget(_app(_session(), null));
    expect(find.byKey(TestIds.quizSpeak), findsNothing);
  });

  testWidgets('the speaker button has a screen-reader label', (t) async {
    // The tooltip is the screen-reader label of an IconButton.
    await t.pumpWidget(
      _app(_session(), ReadAloud(speech: FakeSpeechService())),
    );
    expect(
      find.byTooltip('Read the question and the answers aloud'),
      findsOneWidget,
    );
  });
}
