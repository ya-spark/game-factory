import 'package:flutter/material.dart';

import '../core/services.dart';
import 'test_ids.dart';
import 'widgets.dart';

/// Opens the tip of the day as a dialog (once per day, from the home page).
Future<void> showTipDialog(BuildContext context, {required String text}) {
  return showDialog<void>(
    context: context,
    builder: (_) => TipDialog(text: text),
  );
}

/// Tip of the day with a "Don't show tips again" checkbox and a Close button. With the box
/// ticked, Close turns tips off (the same saved profile value as the Settings "Show tips" switch).
class TipDialog extends StatefulWidget {
  const TipDialog({super.key, required this.text});

  final String text;

  @override
  State<TipDialog> createState() => _TipDialogState();
}

class _TipDialogState extends State<TipDialog> {
  bool _dontShow = false;

  Future<void> _close() async {
    final nav = Navigator.of(context);
    if (_dontShow) {
      await ServicesScope.of(context).profile.setTipsEnabled(false);
    }
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: TestIds.tipHome,
      backgroundColor: KidColors.cardOf(context),
      title: Text(
        '\u{1F4A1} Tip of the day',
        style: TextStyle(
          color: KidColors.inkOf(context),
          fontWeight: FontWeight.w900,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.text,
            style: TextStyle(
              color: KidColors.inkOf(context),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            key: TestIds.tipDontShow,
            onTap: () => setState(() => _dontShow = !_dontShow),
            child: Row(
              children: [
                Checkbox(
                  value: _dontShow,
                  onChanged: (v) => setState(() => _dontShow = v ?? false),
                ),
                Flexible(
                  child: Text(
                    "Don't show tips again",
                    style: TextStyle(
                      color: KidColors.inkOf(context),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: TestIds.tipClose,
          onPressed: _close,
          child: const Text('Close'),
        ),
      ],
    );
  }
}
