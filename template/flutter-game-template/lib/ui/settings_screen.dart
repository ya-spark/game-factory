import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/audio/audio_service.dart';
import '../core/services.dart';
import 'test_ids.dart';
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
        backgroundColor: KidColors.grape,
        foregroundColor: Colors.white,
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
                      subtitle: const Text('Master mute'),
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
                      title: const Text('Background sound'),
                      trailing: DropdownButton<String>(
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
                child: SwitchListTile(
                  key: TestIds.settingsReminders,
                  title: const Text('Daily reminder'),
                  subtitle: const Text('A local notification at 19:00'),
                  value: p.data.remindersOn,
                  onChanged: (v) async {
                    if (v) {
                      final ok = await s.notifications.requestPermission();
                      if (!ok) return;
                      await s.notifications.scheduleDailyReminder(
                        hour: 19,
                        minute: 0,
                        title: s.config.displayName,
                        body: 'Your daily reward is waiting!',
                      );
                    } else {
                      await s.notifications.cancelAll();
                    }
                    await p.setReminders(v);
                  },
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
              if (s.config.playGames.enabled)
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
              KidPanel(
                child: ListTile(
                  title: Text(s.config.displayName),
                  subtitle: Text(
                    kReleaseMode
                        ? 'Release build'
                        : 'Debug build (test ads only)',
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
