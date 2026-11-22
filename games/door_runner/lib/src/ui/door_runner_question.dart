import 'package:flutter/material.dart';
import 'package:game_core/kit/keys/keys.dart';

import '../door_runner_ids.dart';
import 'door_runner_style.dart';

/// The question under the top strip, in a glowing glass pill. Tapping it opens the dialog.
class DoorRunnerQuestionChip extends StatelessWidget {
  const DoorRunnerQuestionChip({
    super.key,
    required this.question,
    required this.onOpen,
  });
  final String question;

  /// Null: the question is only shown (the race has no question dialog).
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Semantics(
        button: onOpen != null,
        excludeSemantics: true,
        label: onOpen == null
            ? 'Question: $question'
            : 'Question: $question. Open to see the answers.',
        onTap: onOpen,
        child: GestureDetector(
          key: DoorRunnerIds.question,
          behavior: HitTestBehavior.opaque,
          onTap: onOpen,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
            decoration: BoxDecoration(
              color: const Color(0x1FFFFFFF),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: DrColors.lilac.withValues(alpha: 0.75),
                width: 1.5,
              ),
              boxShadow: drGlow(DrColors.lilac, alpha: 0.3, blur: 14),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: DrColors.cyan,
                    boxShadow: drGlow(DrColors.cyan, alpha: 0.6, blur: 10),
                  ),
                  child: const Text(
                    '?',
                    style: TextStyle(
                      color: DrColors.ink,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        question,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          shadows: drTextShadow,
                        ),
                      ),
                      if (onOpen != null)
                        Text(
                          'Tap to see the answers',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The question and its answers on their own, with nothing moving behind. Returns the index of
/// the answer chosen (acts as a zap on that door), or null for "Back to the game".
Future<int?> showDoorRunnerQuestionDialog(
  BuildContext context, {
  required String question,
  required List<String> answers,
  VoidCallback? onSpeak,
}) {
  return showDialog<int>(
    context: context,
    barrierColor: const Color(0xCC0B0626),
    builder: (ctx) => GameKeyboard(
      // 1 to 4 answer, Esc, Space, Enter or B go back to the game, Q reads (B-09: every button has its key).
      onInput: (i) {
        if (i.repeat) return;
        final n = i.action.pickNumber;
        if (n != null) {
          if (n <= answers.length) Navigator.of(ctx).pop(n - 1);
        } else if (i.action == GameAction.question) {
          onSpeak?.call();
        } else if (i.action == GameAction.exit ||
            i.action == GameAction.pause ||
            i.action == GameAction.action) {
          Navigator.of(ctx).pop();
        }
      },
      child: Dialog(
        key: DoorRunnerIds.questionDialog,
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF2B1E7A), Color(0xFF1B1446)],
              ),
              border: Border.all(color: DrColors.lilac, width: 1.5),
              boxShadow: drGlow(DrColors.lilac, alpha: 0.45, blur: 30),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          question,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (onSpeak != null)
                        Tooltip(
                          message: 'Read aloud (Q)',
                          child: TextButton.icon(
                            key: DoorRunnerIds.questionSpeak,
                            onPressed: onSpeak,
                            icon: const Icon(
                              Icons.volume_up,
                              color: DrColors.cyan,
                            ),
                            label: const Text(
                              'Q',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  for (var i = 0; i < answers.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DrButton(
                        key: DoorRunnerIds.answer(i),
                        height: 58,
                        colors: i.isEven
                            ? const [Color(0xFF5AB8FF), Color(0xFF3F7BFF)]
                            : const [Color(0xFFA98BFF), Color(0xFF7A55F0)],
                        onPressed: () => Navigator.of(ctx).pop(i),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0x33FFFFFF),
                              ),
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                answers[i],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  TextButton(
                    key: DoorRunnerIds.questionBack,
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(
                      'Back to the game (Esc / Space / Enter)',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
