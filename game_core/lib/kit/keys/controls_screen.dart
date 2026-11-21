import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game_action.dart';
import 'game_key_map.dart';
import 'game_keyboard.dart';
import 'game_keys_scope.dart';
import 'key_ids.dart';

/// Settings, Controls: every key can be changed. Pick a chip (tap, or Tab to it and press Enter),
/// press the new key, done. Escape cancels. A key another action uses is swapped, never lost.
/// The whole screen works from the keyboard. Containers open it from their Settings page; the keys
/// come from [GameKeysScope] (or [keys]).
class ControlsScreen extends StatefulWidget {
  const ControlsScreen({super.key, this.keys, this.onDone});

  /// The key map to edit (default: the one in [GameKeysScope]).
  final GameKeyMap? keys;

  /// Called by Done (default: pop the route).
  final VoidCallback? onDone;

  @override
  State<ControlsScreen> createState() => _ControlsScreenState();
}

class _ControlsScreenState extends State<ControlsScreen> {
  final Map<KeySlot, FocusNode> _chipNodes = {
    for (final s in KeySlot.all) s: FocusNode(debugLabel: 'chip ${s.id}'),
  };
  final FocusNode _capture = FocusNode(debugLabel: 'controls capture');
  KeySlot? _listening;
  String? _message;

  GameKeyMap get _map => widget.keys ?? GameKeysScope.of(context);

  @override
  void dispose() {
    for (final n in _chipNodes.values) {
      n.dispose();
    }
    _capture.dispose();
    super.dispose();
  }

  void _listen(KeySlot slot) {
    setState(() {
      _listening = slot;
      _message = null;
    });
    _capture.requestFocus();
  }

  void _stopListening(KeySlot slot, {String? message}) {
    setState(() {
      _listening = null;
      _message = message;
    });
    _chipNodes[slot]?.requestFocus();
  }

  KeyEventResult _onCaptureKey(FocusNode node, KeyEvent event) {
    final slot = _listening;
    if (slot == null || event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      _stopListening(slot, message: 'Cancelled. The key is unchanged.');
      return KeyEventResult.handled;
    }
    final before = _map.primaryOf(slot);
    final r = _map.assign(slot, key);
    if (!r.ok) {
      setState(() => _message = r.reason);
      return KeyEventResult.handled;
    }
    final other = r.swappedWith;
    _stopListening(
      slot,
      message: other == null
          ? '${_name(slot)} is now ${keySpokenLabel(key)}.'
          : '${_name(slot)} is now ${keySpokenLabel(key)}. ${_name(other)} took ${keySpokenLabel(before)}.',
    );
    return KeyEventResult.handled;
  }

  String _name(KeySlot s) =>
      s.player == 0 ? s.action.label : '${s.action.label} (player ${s.player})';

  void _reset() {
    _map.reset();
    setState(() {
      _listening = null;
      _message = 'Every key is back to its start.';
    });
  }

  void _done() {
    if (widget.onDone != null) {
      widget.onDone!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final map = _map;
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: map,
      builder: (context, _) {
        final actions = [
          for (final a in GameAction.values)
            if (a != GameAction.exit) a,
        ];
        return Focus(
          focusNode: _capture,
          skipTraversal: true,
          onKeyEvent: _onCaptureKey,
          child: Scaffold(
            key: KeyIds.controlsScreen,
            appBar: AppBar(title: const Text('Controls')),
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      Text(
                        'Pick a key, then press the new one. Two players? Player 2 uses the left side.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      _header(theme),
                      for (final a in actions) _row(a, theme, map),
                      const SizedBox(height: 8),
                      Semantics(
                        liveRegion: true,
                        child: SizedBox(
                          key: KeyIds.message,
                          height: 40,
                          child: Text(
                            _listening != null
                                ? 'Press a key for ${_name(_listening!)}. Esc cancels.${_message == null ? '' : ' $_message'}'
                                : (_message ?? ''),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: _listening != null
                                  ? theme.colorScheme.tertiary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          FilledButton(
                            key: KeyIds.reset,
                            onPressed: map.allDefault ? null : _reset,
                            child: const Text('Reset to defaults'),
                          ),
                          OutlinedButton(
                            key: KeyIds.done,
                            onPressed: _done,
                            child: const Text('Done'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _header(ThemeData theme) {
    final s = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text('Action', style: s)),
          Expanded(flex: 3, child: Text('Player 1', style: s)),
          Expanded(
            flex: 3,
            child: Text(
              'Player 2',
              style: s?.copyWith(color: theme.colorScheme.secondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(GameAction a, ThemeData theme, GameKeyMap map) {
    final shared = a.shared;
    final first = KeySlot(a, shared ? 0 : 1);
    final listening = _listening == first || _listening == KeySlot(a, 2);
    return Container(
      key: KeyIds.row(first),
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: listening
            ? Border.all(color: theme.colorScheme.tertiary, width: 2)
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(a.label, style: theme.textTheme.bodyMedium),
          ),
          Expanded(
            flex: shared ? 6 : 3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _chip(first, map, theme),
            ),
          ),
          if (!shared)
            Expanded(
              flex: 3,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _chip(KeySlot(a, 2), map, theme, second: true),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(
    KeySlot slot,
    GameKeyMap map,
    ThemeData theme, {
    bool second = false,
  }) {
    final listening = _listening == slot;
    final key = map.primaryOf(slot);
    return Semantics(
      button: true,
      label: '${_name(slot)}, key ${keySpokenLabel(key)}',
      hint: 'Press to change',
      excludeSemantics: true,
      child: InkWell(
        key: KeyIds.chip(slot),
        focusNode: _chipNodes[slot],
        borderRadius: BorderRadius.circular(10),
        focusColor: theme.colorScheme.primary.withValues(alpha: 0.25),
        onTap: () => _listen(slot),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: listening
              ? const KeyCap(
                  key: KeyIds.listening,
                  label: 'Press a key...',
                  highlight: true,
                )
              : KeyCap(
                  label: keyLabel(key),
                  accent: second ? theme.colorScheme.secondary : null,
                ),
        ),
      ),
    );
  }
}
