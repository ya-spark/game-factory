import 'kit/ds_art.dart';

import 'package:flutter/material.dart';

import '../core/profile/child_profile.dart';
import '../core/services.dart';
import 'parent_area_screen.dart';
import 'parent_gate.dart';
import 'test_ids.dart';

/// Shown on every launch of a learning game: who is playing? Up to four children, each a
/// made-up nickname and a built-in avatar. The parent area is behind the gate.
class ProfilePickerScreen extends StatelessWidget {
  const ProfilePickerScreen({super.key, required this.home});

  /// Built once a child is chosen.
  final WidgetBuilder home;

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context);
    return ListenableBuilder(
      listenable: s.profile,
      builder: (context, _) {
        final active = s.profile.activeChild;
        if (active != null && active.year != null) return home(context);
        if (active != null) {
          return _NewChildScreen(existing: active);
        }
        final kids = s.profile.children;
        if (kids.isEmpty) return const _NewChildScreen();
        return Scaffold(
          appBar: AppBar(title: const Text('Who is playing?')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final c in kids)
                Card(
                  child: ListTile(
                    key: TestIds.pickerChild(c.id),
                    leading: DsAvatarArt(c.avatar, size: 36),
                    title: Text(c.nickname),
                    onTap: () => s.profile.selectChild(c.id),
                  ),
                ),
              if (s.profile.canAddChild)
                OutlinedButton.icon(
                  key: TestIds.pickerAdd,
                  icon: const Icon(Icons.add),
                  label: const Text('Add a player'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const _NewChildScreen(canCancel: true),
                    ),
                  ),
                ),
              TextButton.icon(
                key: TestIds.pickerParent,
                icon: const Icon(Icons.lock_outline),
                label: const Text('Grown-ups'),
                onPressed: () async {
                  if (await showParentGate(context, s.parentGate) &&
                      context.mounted) {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ParentAreaScreen(),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Built-in avatar icons (no photos).
IconData avatarIcon(String id) => switch (id) {
  'owl' => Icons.nightlight_round,
  'bear' => Icons.pets,
  'cat' => Icons.emoji_nature,
  'frog' => Icons.park,
  'panda' => Icons.cruelty_free,
  'rabbit' => Icons.spa,
  'penguin' => Icons.ac_unit,
  _ => Icons.star,
};

/// New child (nickname, avatar, year level), or the year of an existing child who has none yet.
class _NewChildScreen extends StatefulWidget {
  const _NewChildScreen({this.existing, this.canCancel = false});
  final ChildProfile? existing;
  final bool canCancel;

  @override
  State<_NewChildScreen> createState() => _NewChildScreenState();
}

class _NewChildScreenState extends State<_NewChildScreen> {
  final _name = TextEditingController();
  String _avatar = avatarIds.first;
  int? _year;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = ServicesScope.of(context);
    final year = _year;
    if (year == null) return;
    final nav = Navigator.of(context);
    final existing = widget.existing;
    if (existing != null) {
      await s.profile.setChildYear(existing.id, year);
    } else {
      final c = await s.profile.addChild(
        _name.text,
        avatar: _avatar,
        year: year,
      );
      if (c == null) return;
      s.profile.selectChild(c.id);
    }
    if (widget.canCancel && nav.canPop()) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    final ready =
        _year != null && (existing != null || _name.text.trim().isNotEmpty);
    return Scaffold(
      appBar: AppBar(
        title: Text(existing == null ? 'New player' : 'Pick your year'),
        automaticallyImplyLeading: widget.canCancel,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (existing == null) ...[
            TextField(
              key: TestIds.pickerNickname,
              controller: _name,
              maxLength: maxNicknameLength,
              decoration: const InputDecoration(
                labelText: 'Nickname',
                helperText: 'Make one up. Please do not use your real name.',
              ),
              onChanged: (_) => setState(() {}),
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final a in avatarIds)
                  ChoiceChip(
                    key: TestIds.pickerAvatar(a),
                    avatar: DsAvatarArt(a, size: 24),
                    label: Text(a),
                    selected: _avatar == a,
                    onSelected: (_) => setState(() => _avatar = a),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          const Text('Year level'),
          Wrap(
            spacing: 8,
            children: [
              for (var y = 0; y <= 10; y++)
                ChoiceChip(
                  key: TestIds.pickerYear(y),
                  label: Text(y == 0 ? 'Foundation' : 'Year $y'),
                  selected: _year == y,
                  onSelected: (_) => setState(() => _year = y),
                ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: TestIds.pickerSave,
            onPressed: ready ? _save : null,
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }
}
