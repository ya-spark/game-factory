import 'package:flutter/material.dart';

import '../core/services.dart';
import '../engine/engine.dart';
import 'test_ids.dart';

/// The how-to-play dialog (R1a): rules and tips from [GameRulesCatalogue], scrollable at large
/// text, one big "Got it" button. Does nothing for a game without an entry.
Future<void> showGameRules(BuildContext context, String gameId) {
  final rules = GameRulesCatalogue.forGame(gameId);
  if (rules == null) return Future<void>.value();
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return AlertDialog(
        key: TestIds.rulesDialog,
        title: Semantics(
          header: true,
          child: Text('How to play ${rules.title}'),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                container: true,
                label: 'Rules',
                child: Column(
                  key: TestIds.rulesFor(gameId),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final r in rules.rules)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(r),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Semantics(
                header: true,
                child: Text('Tips', style: theme.textTheme.titleSmall),
              ),
              const SizedBox(height: 4),
              for (final t in rules.tips)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $t'),
                ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            key: TestIds.rulesGotIt,
            style: FilledButton.styleFrom(minimumSize: const Size(120, 56)),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      );
    },
  );
}

/// Wraps a minigame screen with a thin top bar holding the Rules button (above the game, so it
/// never covers the game's own controls). The first time [childId] opens [gameId] the dialog
/// opens by itself and closing it marks the game seen for that child (and for every id in
/// [alsoMark], used by two-player Tug of war). With no child nothing is stored. The Rules
/// button always reopens the dialog and never changes the flag. Reading rules earns nothing.
class RulesGate extends StatefulWidget {
  const RulesGate({
    super.key,
    required this.gameId,
    required this.child,
    this.childId,
    this.alsoMark = const [],
  });
  final String gameId;
  final String? childId;
  final List<String> alsoMark;
  final Widget child;

  @override
  State<RulesGate> createState() => _RulesGateState();
}

class _RulesGateState extends State<RulesGate> {
  @override
  void initState() {
    super.initState();
    if (GameRulesCatalogue.forGame(widget.gameId) == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _auto());
  }

  Future<void> _auto() async {
    if (!mounted) return;
    final services = context
        .dependOnInheritedWidgetOfExactType<ServicesScope>()
        ?.services;
    final id = widget.childId;
    Set<String>? seen;
    if (services != null && id != null) {
      for (final c in services.profile.children) {
        if (c.id == id) seen = c.rulesSeen;
      }
    }
    if (!RulesFirstPlay.shouldAutoShow(seen, widget.gameId)) {
      // The first player already saw it: the other players count as having seen it too.
      if (services != null && widget.alsoMark.isNotEmpty) {
        await services.profile.markRulesSeen(widget.alsoMark, widget.gameId);
      }
      return;
    }
    await showGameRules(context, widget.gameId);
    if (services != null && id != null && seen != null) {
      await services.profile.markRulesSeen([
        id,
        ...widget.alsoMark,
      ], widget.gameId);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (GameRulesCatalogue.forGame(widget.gameId) == null) return widget.child;
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.centerRight,
              child: Semantics(
                button: true,
                label: 'Rules: how to play',
                excludeSemantics: true,
                child: TextButton.icon(
                  key: TestIds.rulesButton,
                  style: TextButton.styleFrom(minimumSize: const Size(96, 48)),
                  onPressed: () => showGameRules(context, widget.gameId),
                  icon: const Icon(Icons.help_outline),
                  label: const Text('Rules'),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}
