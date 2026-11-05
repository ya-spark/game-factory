import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/purchase/parent_gate_guard.dart';
import 'test_ids.dart';

/// Asks a grown-up (a multiplication) before a real-money purchase. Returns true when answered
/// correctly. Three wrong answers in a row close the dialog and lock purchases for 60 s.
Future<bool> showParentGate(BuildContext context, ParentGateGuard guard) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => _ParentGateDialog(guard: guard),
  );
  return ok ?? false;
}

class _ParentGateDialog extends StatefulWidget {
  const _ParentGateDialog({required this.guard});
  final ParentGateGuard guard;

  @override
  State<_ParentGateDialog> createState() => _ParentGateDialogState();
}

class _ParentGateDialogState extends State<_ParentGateDialog> {
  final _controller = TextEditingController();
  bool _wrong = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final result = widget.guard.submit(_controller.text);
    switch (result) {
      case GateAnswer.correct:
        Navigator.pop(context, true);
      case GateAnswer.locked:
        Navigator.pop(context, false);
      case GateAnswer.wrong:
        setState(() {
          _wrong = true;
          _controller.clear();
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.guard;
    final locked = g.isLocked;
    return AlertDialog(
      key: TestIds.gateDialog,
      title: const Text('Ask a grown-up'),
      content: locked
          ? Text(
              'Purchases are paused. Try again in ${g.lockSecondsLeft} seconds.',
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('A grown-up needs to answer this to continue.'),
                const SizedBox(height: 12),
                Text(
                  '${g.question} = ?',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (_wrong)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('Not quite. Here is a new one.'),
                  ),
                TextField(
                  key: TestIds.gateAnswer,
                  controller: _controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  onSubmitted: (_) => _submit(),
                ),
              ],
            ),
      actions: [
        TextButton(
          key: TestIds.gateCancel,
          onPressed: () => Navigator.pop(context, false),
          child: Text(locked ? 'Close' : 'Cancel'),
        ),
        if (!locked)
          FilledButton(
            key: TestIds.gateSubmit,
            onPressed: _submit,
            child: const Text('OK'),
          ),
      ],
    );
  }
}
