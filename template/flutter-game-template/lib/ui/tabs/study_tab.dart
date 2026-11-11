import 'package:flutter/material.dart';

import '../../core/profile/child_profile.dart';
import '../../core/services.dart';
import '../test_ids.dart';
import '../theme/app_theme.dart';

/// Study mode placeholder until issue 2B2: a simple "Learn" page that lists the topics.
/// The Progress and Revise tabs show the same page for now.
class StudyTab extends StatelessWidget {
  const StudyTab({super.key, required this.child, required this.page});
  final ChildProfile child;
  final String page;

  @override
  Widget build(BuildContext context) {
    final t = ThemeTokens.of(context);
    final learning = ServicesScope.of(context).learning;
    return Column(
      key: TestIds.learnTab,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(t.sp('lg')),
          child: Semantics(
            header: true,
            child: Text('Learn', style: t.styles['title']!),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<String>>(
            future: learning == null
                ? Future.value(const <String>[])
                : learning
                      .openItems(child.id)
                      .then(
                        (items) =>
                            {for (final p in items) p.topic}.toList()..sort(),
                      ),
            builder: (context, snap) {
              final topics = snap.data ?? const <String>[];
              if (topics.isEmpty) {
                return Padding(
                  padding: EdgeInsets.all(t.sp('lg')),
                  child: Text(
                    'Topics will show here.',
                    style: t.styles['body']!,
                  ),
                );
              }
              return ListView(
                padding: EdgeInsets.symmetric(horizontal: t.sp('lg')),
                children: [
                  for (final topic in topics)
                    ListTile(title: Text(topic, style: t.styles['body']!)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
