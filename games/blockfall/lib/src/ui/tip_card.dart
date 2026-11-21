import 'package:flutter/material.dart';

import '../host/services.dart';
import 'test_ids.dart';

/// The content of the home tip dialog: a small tip card with a "Don't show tips again" checkbox and a Close (X) button.
/// Close alone hides this tip for now; with the box ticked it turns tips off everywhere
/// (the same saved profile value as the Settings "Show tips" switch).
class TipCard extends StatefulWidget {
  const TipCard({
    super.key,
    required this.text,
    required this.onClose,
    this.title,
  });

  final String text;

  /// Optional heading, e.g. "Tip of the day".
  final String? title;

  /// Called after the card was closed (and tips turned off if the box was ticked).
  final VoidCallback onClose;

  @override
  State<TipCard> createState() => _TipCardState();
}

class _TipCardState extends State<TipCard> {
  bool _dontShow = false;

  Future<void> _close() async {
    if (_dontShow) {
      await BlockfallServicesScope.of(context).profile.setTipsEnabled(false);
    }
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Material(
        color: const Color(0xF2FFFFFF),
        elevation: 4,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 4, 6),
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: Color(0xFF2B1B4D), fontSize: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6, right: 8),
                      child: Text('\u{1F4A1}', style: TextStyle(fontSize: 18)),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.title != null)
                              Text(
                                widget.title!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            Text(
                              widget.text,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      key: TestIds.tipClose,
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Close',
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: _close,
                    ),
                  ],
                ),
                InkWell(
                  key: TestIds.tipDontShow,
                  onTap: () => setState(() => _dontShow = !_dontShow),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: Checkbox(
                          value: _dontShow,
                          visualDensity: VisualDensity.compact,
                          onChanged: (v) =>
                              setState(() => _dontShow = v ?? false),
                        ),
                      ),
                      const Flexible(
                        child: Text(
                          "Don't show tips again",
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
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
