/// Word builder rules: build the answer of a `word` item (or each gap of a `cloze` item) from
/// letter tiles. Pure Dart, random is injected.
///
/// The item's listed answers are accepted exactly (compared without case and spaces). Spelling
/// mistakes in content are only a warning, so nothing here "fixes" an answer.
library;

import 'dart:math';

import '../../../content/models.dart';

const String wordBuilderId = 'word_builder';

/// Younger: short words, a wrong letter is greyed out, no timer, no failing. Older: free
/// building and a Check button, a gentle timer. Hard: the older level with extra decoy letters and
/// tighter limits (Champion).
enum WordLevel {
  younger,
  older,
  hard;

  static WordLevel forYear(int year, {bool hard = false}) =>
      year <= 2 ? WordLevel.younger : (hard ? WordLevel.hard : WordLevel.older);

  /// Decoy letters added to the tiles.
  int get decoys => this == WordLevel.hard ? 2 : 0;

  /// Gentle time limit per slot in seconds; null means no timer.
  int? get secondsPerSlot => switch (this) {
    WordLevel.younger => null,
    WordLevel.older => 30,
    WordLevel.hard => 20,
  };

  /// Wrong tries allowed per slot before the round does not pass (null: never fails).
  double? get missesPerSlot => switch (this) {
    WordLevel.younger => null,
    WordLevel.older => 1,
    WordLevel.hard => 0.5,
  };
}

bool wordBuilderPlays(ItemType t) => t == ItemType.word || t == ItemType.cloze;

String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'\s+'), '');

final RegExp _gap = RegExp(r'\{\{(\d+)\}\}');

/// One word to build: its accepted answers, the hint shown and the shuffled tiles.
class WordSlot {
  WordSlot({required this.accepted, required this.hint, required this.tiles});

  /// The answers as the content lists them; the first one is shown after a miss.
  final List<String> accepted;
  final String hint;
  final List<String> tiles;

  String get correct => accepted.first;
}

/// One round on one `word` item (one slot) or one `cloze` item (one slot per gap).
class WordRound {
  WordRound._(this.level, this.slots);

  factory WordRound.fromItem(ContentItem item, WordLevel level, Random random) {
    final j = item.json;
    final slots = <WordSlot>[];
    if (item.type == ItemType.cloze) {
      final text = ((j['text'] ?? j['prompt']) as String);
      final gaps = j['gaps'] as Map;
      final keys = gaps.keys.map((k) => '$k').toList()
        ..sort(
          (a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0),
        );
      for (final k in keys) {
        final accepted = [for (final a in (gaps[k] as List)) '$a'];
        slots.add(
          WordSlot(
            accepted: accepted,
            hint: text,
            tiles: _tiles(accepted.first, null, level, random),
          ),
        );
      }
    } else {
      final answer = j['answer'].toString();
      slots.add(
        WordSlot(
          accepted: [answer],
          hint: j['hint'].toString(),
          tiles: _tiles(answer, j['letters'], level, random),
        ),
      );
    }
    return WordRound._(level, slots);
  }

  static List<String> _tiles(
    String answer,
    Object? letters,
    WordLevel level,
    Random random,
  ) {
    final base = letters is String
        ? letters.split('')
        : (letters is List
              ? [for (final l in letters) '$l']
              : answer.split(''));
    final tiles = [
      for (final t in base)
        if (t.trim().isNotEmpty) t,
    ];
    if (level.decoys > 0) {
      const alphabet = 'abcdefghijklmnopqrstuvwxyz';
      final have = tiles.join().toLowerCase();
      final free = [
        for (final c in alphabet.split(''))
          if (!have.contains(c)) c,
      ]..shuffle(random);
      tiles.addAll(free.take(level.decoys));
    }
    var out = [...tiles]..shuffle(random);
    // Not already spelled out when there is a choice.
    var tries = 0;
    while (out.join() == tiles.join() && _distinct(tiles) > 1 && tries < 10) {
      out = [...tiles]..shuffle(random);
      tries++;
    }
    return out;
  }

  static int _distinct(List<String> l) => l.toSet().length;

  final WordLevel level;
  final List<WordSlot> slots;

  int _slot = 0;
  final List<int> _built = [];
  final Set<int> _greyed = {};
  int _misses = 0;
  final List<String> _solved = [];

  int get slotIndex => _slot;
  int get total => slots.length;
  int get misses => _misses;
  bool get complete => _slot >= slots.length;
  WordSlot? get current => complete ? null : slots[_slot];

  /// What the child has built in the current slot.
  String get built => _built.map((i) => current!.tiles[i]).join();

  List<int> get builtTiles => List.unmodifiable(_built);

  /// What the child spelled in each finished slot.
  List<String> get solved => List.unmodifiable(_solved);

  bool isUsed(int tile) => _built.contains(tile);
  bool isGreyed(int tile) => _greyed.contains(tile);

  /// The hint for the current slot. For a cloze, solved gaps show their word and the rest a blank.
  String? get hintText {
    final c = current;
    if (c == null) return null;
    if (!_gap.hasMatch(c.hint)) return c.hint;
    var n = 0;
    return c.hint.replaceAllMapped(_gap, (m) {
      final i = n++;
      return i < _solved.length ? _solved[i] : '____';
    });
  }

  bool _matches(String text) =>
      current!.accepted.any((a) => _norm(a) == _norm(text));

  bool _isPrefix(String text) =>
      current!.accepted.any((a) => _norm(a).startsWith(_norm(text)));

  /// Taps [tile]. Returns true when it was taken. At the younger level a tile that cannot lead to
  /// an answer is greyed out (and counted as a miss); the round finishes the slot by itself when
  /// the word is complete. At the older levels any tile is taken and [submit] checks the word.
  bool tap(int tile) {
    final c = current;
    if (c == null || tile < 0 || tile >= c.tiles.length) return false;
    if (isUsed(tile) || isGreyed(tile)) return false;
    if (level == WordLevel.younger) {
      if (!_isPrefix(built + c.tiles[tile])) {
        _misses++;
        _greyed.add(tile);
        return false;
      }
      _built.add(tile);
      _greyed.clear();
      if (_matches(built)) _finishSlot();
      return true;
    }
    _built.add(tile);
    return true;
  }

  /// Removes the last tile (older levels, and the younger level when the child wants to start over).
  void undo() {
    if (_built.isNotEmpty) _built.removeLast();
    _greyed.clear();
  }

  void clear() {
    _built.clear();
    _greyed.clear();
  }

  /// Checks the built word. True and the next slot when it is one of the listed answers; else a
  /// miss and the tiles are put back.
  bool submit() {
    if (complete || _built.isEmpty) return false;
    if (_matches(built)) {
      _finishSlot();
      return true;
    }
    _misses++;
    _built.clear();
    return false;
  }

  void _finishSlot() {
    _solved.add(built);
    _built.clear();
    _greyed.clear();
    _slot++;
  }

  int? get timeLimit {
    final s = level.secondsPerSlot;
    return s == null ? null : s * total;
  }

  bool passed({int? elapsedSeconds}) {
    if (!complete) return false;
    final per = level.missesPerSlot;
    if (per != null && _misses > per * total) return false;
    final limit = timeLimit;
    if (limit != null && elapsedSeconds != null && elapsedSeconds > limit) {
      return false;
    }
    return true;
  }
}
