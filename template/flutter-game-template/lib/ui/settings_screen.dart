import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/audio/audio_service.dart';
import '../core/config/app_config.dart';
import '../core/services.dart';
import '../engine/engine.dart';
import 'more_games_screen.dart';
import 'parent_area_screen.dart';
import 'parent_gate.dart';
import 'progress_screen.dart';
import 'test_ids.dart';
import 'theme/design_scope.dart';
import 'theme_gallery_screen.dart';
import 'widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context);
    final p = s.profile;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: KidColors.barOf(context, KidColors.grape),
        foregroundColor: KidColors.onBarOf(context),
      ),
      body: KidPage(
        child: ListenableBuilder(
          listenable: p,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              KidPanel(
                child: Column(
                  children: [
                    SwitchListTile(
                      key: TestIds.settingsSound,
                      title: const Text('Sound'),
                      subtitle: const Text('Sound effects'),
                      value: p.data.soundOn,
                      onChanged: p.setSound,
                    ),
                    ListTile(
                      title: Text(
                        'Master volume: '
                        '${(p.data.masterVolume * 100).round()}%',
                      ),
                      subtitle: Slider(
                        key: TestIds.settingsVolume,
                        value: p.data.masterVolume,
                        divisions: 20,
                        onChanged: p.setMasterVolume,
                      ),
                    ),
                    ListTile(
                      title: const Text('Music'),
                      trailing: ConstrainedBox(
                        // Bounded, so large text never makes the tile overflow.
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: DropdownButton<String>(
                          isExpanded: true,
                          key: TestIds.settingsAmbience,
                          value: p.data.ambience,
                          items: [
                            for (final t in ambienceTracks)
                              DropdownMenuItem(value: t.$1, child: Text(t.$2)),
                          ],
                          onChanged: (v) {
                            if (v != null) p.setAmbience(v);
                          },
                        ),
                      ),
                    ),
                    SwitchListTile(
                      key: TestIds.settingsVoice,
                      title: const Text('Voice'),
                      value: p.data.voiceOn,
                      onChanged: p.setVoice,
                    ),
                  ],
                ),
              ),
              KidPanel(
                child: ListTile(
                  title: const Text('Hand'),
                  subtitle: const Text('Mirrors the controls'),
                  trailing: SegmentedButton<bool>(
                    key: TestIds.settingsHand,
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: false, label: Text('Right')),
                      ButtonSegment(value: true, label: Text('Left')),
                    ],
                    selected: {p.data.leftHanded},
                    onSelectionChanged: (v) => p.setLeftHanded(v.first),
                  ),
                ),
              ),
              KidPanel(
                child: SwitchListTile(
                  key: TestIds.settingsVibration,
                  title: const Text('Vibration'),
                  value: p.data.vibrationOn,
                  onChanged: p.setVibration,
                ),
              ),
              KidPanel(
                child: Column(
                  children: [
                    SwitchListTile(
                      key: TestIds.settingsReminders,
                      title: const Text('Daily reminder'),
                      subtitle: Text(
                        'A local notification at '
                        '${_clock(p.data.reminderHour, p.data.reminderMinute)}',
                      ),
                      value: p.data.remindersOn,
                      onChanged: (v) async {
                        if (v) {
                          final ok = await s.notifications.requestPermission();
                          if (!ok) return;
                          await _schedule(
                            s,
                            p.data.reminderHour,
                            p.data.reminderMinute,
                          );
                        } else {
                          await s.notifications.cancelAll();
                        }
                        await p.setReminders(v);
                      },
                    ),
                    if (p.data.remindersOn)
                      ListTile(
                        key: TestIds.settingsReminderTime,
                        title: const Text('Reminder time'),
                        trailing: Text(
                          _clock(p.data.reminderHour, p.data.reminderMinute),
                        ),
                        onTap: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(
                              hour: p.data.reminderHour,
                              minute: p.data.reminderMinute,
                            ),
                          );
                          if (t == null) return;
                          await p.setReminderTime(t.hour, t.minute);
                          await s.notifications.cancelAll();
                          await _schedule(s, t.hour, t.minute);
                        },
                      ),
                  ],
                ),
              ),
              KidPanel(
                child: Column(
                  children: [
                    SwitchListTile(
                      key: TestIds.settingsReduceMotion,
                      title: const Text('Reduce motion'),
                      subtitle: const Text('Fewer and shorter animations'),
                      value: p.data.reduceMotion,
                      onChanged: p.setReduceMotion,
                    ),
                    ListTile(
                      title: const Text('Text size'),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SegmentedButton<TextSizeChoice>(
                          showSelectedIcon: false,
                          segments: [
                            for (final t in TextSizeChoice.values)
                              ButtonSegment(
                                value: t,
                                label: Text(
                                  t.label,
                                  key: TestIds.settingsTextSize(t.name),
                                ),
                              ),
                          ],
                          selected: {TextSizeChoice.parse(p.data.textSize)},
                          onSelectionChanged: (v) => p.setTextSize(v.first),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              KidPanel(
                child: SwitchListTile(
                  key: TestIds.settingsTips,
                  title: const Text('Show tips'),
                  subtitle: const Text('Small helpful cards now and then'),
                  value: p.tipsEnabled,
                  onChanged: p.setTipsEnabled,
                ),
              ),
              if (s.config.visibleMoreGames.isNotEmpty)
                KidPanel(
                  child: ListTile(
                    key: TestIds.settingsMoreGames,
                    leading: const Icon(Icons.apps),
                    title: const Text('More games'),
                    onTap: () => openMoreGames(context),
                  ),
                ),
              if (s.share.hasLink)
                KidPanel(
                  child: ListTile(
                    key: TestIds.settingsShareApp,
                    leading: const Icon(Icons.share),
                    title: const Text('Share app'),
                    onTap: () => s.share.shareApp(bestScore: p.data.bestScore),
                  ),
                ),
              if (s.ads.privacyOptionsRequired)
                KidPanel(
                  child: ListTile(
                    key: TestIds.settingsPrivacy,
                    title: const Text('Ad privacy options'),
                    onTap: s.ads.showPrivacyOptions,
                  ),
                ),
              if (s.config.playGames.enabled && !kIsWeb)
                KidPanel(
                  child: ListTile(
                    key: TestIds.settingsPlayGames,
                    title: const Text('Google Play Games'),
                    subtitle: Text(
                      s.identity.isSignedIn
                          ? 'Signed in as ${s.identity.current.displayName}. Progress is saved to your account.'
                          : 'Sign in to keep your score and progress',
                    ),
                    trailing: s.identity.isSignedIn
                        ? const Icon(Icons.check_circle)
                        : null,
                    onTap: s.identity.isSignedIn
                        ? null
                        : () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final ok = await s.connectPlayGames();
                            if (!ok) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Could not sign in. Try again later.',
                                  ),
                                ),
                              );
                            }
                          },
                  ),
                ),
              if (s.config.content.enabled)
                KidPanel(
                  child: ListTile(
                    key: TestIds.settingsSwitchPlayer,
                    leading: const Icon(Icons.switch_account),
                    title: const Text('Switch player'),
                    subtitle: p.activeChild == null
                        ? null
                        : Text('Playing as ${p.activeChild!.nickname}'),
                    onTap: () async {
                      final nav = Navigator.of(context);
                      await p.leaveChild();
                      nav.popUntil((r) => r.isFirst);
                    },
                  ),
                ),
              if (s.config.content.enabled)
                KidPanel(
                  child: s.config.audience == Audience.child
                      ? ListTile(
                          key: TestIds.settingsGrownUps,
                          leading: const Icon(Icons.lock_outline),
                          title: const Text('Grown-ups'),
                          subtitle: const Text(
                            'Weekly progress, reset and purchases',
                          ),
                          onTap: () async {
                            final nav = Navigator.of(context);
                            if (await showParentGate(context, s.parentGate)) {
                              await nav.push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const ParentAreaScreen(),
                                ),
                              );
                            }
                          },
                        )
                      : ListTile(
                          key: TestIds.settingsProgress,
                          leading: const Icon(Icons.bar_chart),
                          title: const Text('Progress'),
                          subtitle: const Text('Your week and each topic'),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ProgressScreen(),
                            ),
                          ),
                        ),
                ),
              if (s.config.privacyUrl.isNotEmpty)
                KidPanel(
                  child: ListTile(
                    key: TestIds.settingsPrivacyPolicy,
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Privacy policy'),
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      if (!await s.links.openUrl(s.config.privacyUrl)) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Could not open the page.'),
                          ),
                        );
                      }
                    },
                  ),
                ),
              KidPanel(
                child: ListTile(
                  key: TestIds.settingsVersion,
                  title: Text(s.config.displayName),
                  subtitle: FutureBuilder<String>(
                    future: s.links.appVersion(),
                    builder: (context, snap) {
                      final v = snap.data ?? '';
                      final build = kReleaseMode
                          ? 'Release build'
                          : 'Debug build (test ads only)';
                      return Text(v.isEmpty ? build : 'Version $v. $build');
                    },
                  ),
                ),
              ),
              // Debug builds only: every shared widget in every mode, for review on a device.
              if (kDebugMode && DesignScope.bundleOf(context) != null)
                KidPanel(
                  child: ListTile(
                    key: TestIds.settingsThemeGallery,
                    title: const Text('Theme gallery (debug)'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ThemeGalleryScreen(
                          design: DesignScope.bundleOf(context)!,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _clock(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

Future<void> _schedule(Services s, int hour, int minute) =>
    s.notifications.scheduleDailyReminder(
      hour: hour,
      minute: minute,
      title: s.config.displayName,
      body: 'Your daily reward is waiting!',
    );
