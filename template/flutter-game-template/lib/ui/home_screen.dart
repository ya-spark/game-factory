import 'package:flutter/material.dart';

import '../core/services.dart';
import 'challenges_screen.dart';
import 'daily_reward_screen.dart';
import 'game_screen.dart';
import 'settings_screen.dart';
import 'shop_screen.dart';
import 'test_ids.dart';
import 'widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ServicesScope.of(context).profile.onAppOpened();
    }
  }

  void _open(Widget screen) =>
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context);
    final profile = s.profile;
    return Scaffold(
      body: Container(
        decoration: KidColors.background,
        child: SafeArea(
          child: ListenableBuilder(
            listenable: profile,
            builder: (context, _) {
              final claimable = profile.challenges.any((c) => c.claimable);
              return Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 14,
                    children: [
                      const PopIn(
                        child: Text('🧩 ⭐ 🎈', style: TextStyle(fontSize: 44)),
                      ),
                      Text(
                        s.config.displayName,
                        style: Theme.of(context).textTheme.displayMedium
                            ?.copyWith(
                              color: KidColors.ink,
                              fontWeight: FontWeight.w900,
                              shadows: const [
                                Shadow(
                                  color: Colors.white,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                        textAlign: TextAlign.center,
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          KeyedSubtree(
                            key: TestIds.homeCoins,
                            child: StatChip(
                              icon: Icons.monetization_on,
                              label: '${profile.data.coins}',
                              color: Colors.amber,
                            ),
                          ),
                          KeyedSubtree(
                            key: TestIds.homeBestScore,
                            child: StatChip(
                              icon: Icons.emoji_events,
                              label: 'Best ${profile.data.bestScore}',
                            ),
                          ),
                          if (s.config.retention.streaks)
                            KeyedSubtree(
                              key: TestIds.homeStreak,
                              child: StatChip(
                                icon: Icons.local_fire_department,
                                label: '${profile.displayStreak}',
                                color: Colors.deepOrange,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      MenuButton(
                        key: TestIds.homePlay,
                        label: 'Play!',
                        icon: Icons.play_circle_fill,
                        primary: true,
                        onPressed: () => _open(const GameScreen()),
                      ),
                      if (s.config.retention.dailyReward)
                        MenuButton(
                          key: TestIds.homeDailyReward,
                          label: 'Daily reward',
                          icon: Icons.card_giftcard,
                          colors: const [Color(0xFFFF8FB1), KidColors.coral],
                          badge: profile.dailyRewardAvailable,
                          onPressed: () => _open(const DailyRewardScreen()),
                        ),
                      if (s.config.retention.dailyChallenges ||
                          s.config.retention.achievements)
                        MenuButton(
                          key: TestIds.homeChallenges,
                          label: 'Challenges',
                          icon: Icons.flag_circle,
                          colors: const [Color(0xFFB79CFF), KidColors.grape],
                          badge: claimable,
                          onPressed: () => _open(const ChallengesScreen()),
                        ),
                      MenuButton(
                        key: TestIds.homeShop,
                        label: 'Shop',
                        icon: Icons.shopping_basket,
                        colors: const [Color(0xFF6BEBB0), Color(0xFF1FB57A)],
                        onPressed: () => _open(const ShopScreen()),
                      ),
                      MenuButton(
                        key: TestIds.homeSettings,
                        label: 'Settings',
                        icon: Icons.settings,
                        colors: const [Color(0xFFB0BEC5), Color(0xFF78909C)],
                        onPressed: () => _open(const SettingsScreen()),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
