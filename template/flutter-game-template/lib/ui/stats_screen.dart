import 'package:flutter/material.dart';

import '../core/services.dart';

import 'package:game_core/engine/engine.dart';

import 'kit/ds_bars.dart';
import 'test_ids.dart';
import 'theme/app_theme.dart';
import 'widgets.dart';

/// "1h 5m", "12m 30s", "45s".
String formatDuration(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  if (s >= 3600) return '${s ~/ 3600}h ${(s % 3600) ~/ 60}m';
  if (s >= 60) return '${s ~/ 60}m ${s % 60}s';
  return '${s}s';
}

/// Stats page (M2), opened from the Challenges tab: an overview and one card per game. Device
/// only; nothing is shared or exported.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key, this.registry});

  /// Gives the games their titles; an unknown id shows as is.
  final MiniGameRegistry? registry;

  /// Extra overview lines a hub adds (Ember: daily puzzles solved, best daily streak).
  static List<(String, String)> Function(BuildContext)? extraOverview;

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context);
    final t = ThemeTokens.of(context);
    return Scaffold(
      key: TestIds.statsScreen,
      appBar: AppBar(
        title: const Text(
          'Stats',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: KidColors.barOf(context, KidColors.grape),
        foregroundColor: KidColors.onBarOf(context),
      ),
      body: KidPage(
        child: ListenableBuilder(
          listenable: s.profile,
          builder: (context, _) {
            final book = s.profile.data.gameStats;
            final today = s.profile.today;
            final ids = book.games.entries
                .where((e) => e.value.plays > 0)
                .map((e) => e.key)
                .toList();
            final lines = <(String, String)>[
              ('This week', formatDuration(book.secondsThisWeek(today))),
              ('In total', formatDuration(book.totalSeconds)),
              ('Days played', '${book.daysPlayed}'),
              ...?extraOverview?.call(context),
            ];
            return ListView(
              padding: EdgeInsets.all(t.sp('lg')),
              children: [
                DsCard(
                  id: 'stats.overview',
                  child: Column(
                    key: TestIds.statsOverview,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text('Time played', style: t.styles['title']!),
                      ),
                      SizedBox(height: t.sp('sm')),
                      for (final l in lines)
                        Padding(
                          padding: EdgeInsets.only(bottom: t.sp('xs')),
                          child: Text(
                            '${l.$1}: ${l.$2}',
                            style: t.styles['body']!,
                          ),
                        ),
                    ],
                  ),
                ),
                if (ids.isEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: t.sp('md')),
                    child: Text(
                      'Play a game and your numbers will show here.',
                      key: TestIds.statsEmpty,
                      style: t.styles['body']!,
                    ),
                  ),
                for (final id in ids) ...[
                  SizedBox(height: t.sp('md')),
                  _GameCard(
                    id: id,
                    title: registry?.byId(id)?.title ?? id,
                    e: book.entry(id),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.id, required this.title, required this.e});
  final String id;
  final String title;
  final GameStatsEntry e;

  @override
  Widget build(BuildContext context) {
    final t = ThemeTokens.of(context);
    final avg = e.averageScore;
    final lines = <String>[
      'Plays: ${e.plays}',
      if (e.winRatePercent != null)
        'Wins: ${e.wins} (${e.winRatePercent}% win rate)',
      'Best score: ${e.bestScore}',
      if (avg != null) 'Average of the last ${e.runs.length}: $avg',
      for (final v in (e.fastest.keys.toList()..sort()))
        'Fastest $v: ${formatDuration(e.fastest[v]!)}',
      'Time played: ${formatDuration(e.totalSeconds)}',
    ];
    final trend = trendText(e.runs);
    return DsCard(
      id: 'stats.$id',
      child: Column(
        key: TestIds.statsCard(id),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: t.styles['subheading']!),
          ),
          SizedBox(height: t.sp('xs')),
          for (final l in lines) Text(l, style: t.styles['body']!),
          if (trend != null) ...[
            SizedBox(height: t.sp('sm')),
            Semantics(
              key: TestIds.statsTrend(id),
              label: trend,
              excludeSemantics: true,
              child: SizedBox(
                height: 40,
                width: double.infinity,
                child: CustomPaint(
                  painter: _TrendPainter([
                    for (final r in e.runs) r.score,
                  ], Theme.of(context).colorScheme.primary),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A small line of the last runs' scores, drawn in code.
class _TrendPainter extends CustomPainter {
  _TrendPainter(this.scores, this.color);
  final List<int> scores;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (scores.length < 2) return;
    final lo = scores.reduce((a, b) => a < b ? a : b);
    final hi = scores.reduce((a, b) => a > b ? a : b);
    final span = (hi - lo) == 0 ? 1 : (hi - lo);
    final path = Path();
    for (var i = 0; i < scores.length; i++) {
      final x = size.width * i / (scores.length - 1);
      final y = size.height - size.height * (scores[i] - lo) / span;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.scores != scores || old.color != color;
}
