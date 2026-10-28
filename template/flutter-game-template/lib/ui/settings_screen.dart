import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/services.dart';
import 'test_ids.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context);
    final p = s.profile;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: p,
        builder: (context, _) => ListView(
          children: [
            SwitchListTile(
              key: TestIds.settingsSound,
              title: const Text('Sound'),
              value: p.data.soundOn,
              onChanged: p.setSound,
            ),
            SwitchListTile(
              key: TestIds.settingsVibration,
              title: const Text('Vibration'),
              value: p.data.vibrationOn,
              onChanged: p.setVibration,
            ),
            SwitchListTile(
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
            if (s.ads.privacyOptionsRequired)
              ListTile(
                key: TestIds.settingsPrivacy,
                title: const Text('Ad privacy options'),
                onTap: s.ads.showPrivacyOptions,
              ),
            ListTile(
              key: TestIds.settingsPlayGames,
              title: const Text('Google Play Games'),
              subtitle: Text(
                s.identity.isStub
                    ? 'Not connected yet (playing as ${s.identity.current.displayName})'
                    : s.identity.current.displayName,
              ),
            ),
            ListTile(
              title: Text(s.config.displayName),
              subtitle: Text(
                kReleaseMode ? 'Release build' : 'Debug build (test ads only)',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
