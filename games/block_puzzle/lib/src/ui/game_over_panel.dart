import 'package:flutter/material.dart';

/// Game-over overlay: a clear dark panel (rounded card, about 90 % opaque, thin light border,
/// soft shadow) so text and buttons never mix with the game background. Order top to bottom:
/// Share icon (top left), title and scores, [buttons] side by side, [extraButton] (optional,
/// a game's extra action, e.g. a refill), [leadButton] (Continue) last. The card is vertically
/// centred. An eye button fades the panel out so the final board is visible; a tap anywhere, or
/// the eye button, brings it back.
class GameOverPanel extends StatefulWidget {
  const GameOverPanel({
    super.key,
    required this.title,
    required this.details,
    required this.buttons,
    this.extraButton,
    this.leadButton,
    this.shareButton,
    this.viewKey,
    this.panelKey,
  });

  final String title;

  /// Score, best, medal... shown under the title.
  final List<Widget> details;

  /// Play again and Home, side by side.
  final List<GameOverButton> buttons;

  /// Optional extra action (a game's own, e.g. Wingy's Dash Refill) on its own row between the
  /// side-by-side buttons and [leadButton].
  final GameOverButton? extraButton;

  /// Optional main action (Continue) shown alone, last, at the bottom of the panel.
  final GameOverButton? leadButton;

  /// Share icon button, shown at the top left of the panel.
  final GameOverButton? shareButton;

  final Key? viewKey;
  final Key? panelKey;

  /// Soft shadow for text on ghost buttons.
  static List<Shadow> get outline => const [
    Shadow(color: Color(0x66000000), blurRadius: 4, offset: Offset(0, 1)),
  ];

  /// Ease-in timeline: 0.3 s hold while the scene dims to about 40 %, then 0.7 s fade and
  /// 24 px slide up (ease-out cubic). Buttons are tappable once it is done. With reduce motion:
  /// a single 0.2 s fade.
  static const Duration easeInDuration = Duration(milliseconds: 1000);
  static const Duration reducedDuration = Duration(milliseconds: 200);
  static const double holdFraction = 0.3;
  static const double slideDistance = 24;

  /// Black scrim opacity at the end of the hold (the scene is left at about 40 %).
  static const double dimOpacity = 0.6;

  /// Solid dark surface at about 90 % opacity.
  static const Color surface = Color(0xE6140B2B);

  @override
  State<GameOverPanel> createState() => _GameOverPanelState();
}

class _GameOverPanelState extends State<GameOverPanel>
    with SingleTickerProviderStateMixin {
  bool _hidden = false;
  late final AnimationController _c = AnimationController(vsync: this);
  bool _started = false;
  bool _reduce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _c.duration = _reduce
        ? GameOverPanel.reducedDuration
        : GameOverPanel.easeInDuration;
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Panel progress 0..1 (fade and slide) at controller value [v].
  double _panelT(double v) {
    if (_reduce) return v;
    final hold = GameOverPanel.holdFraction;
    return Curves.easeOutCubic.transform(
      ((v - hold) / (1 - hold)).clamp(0.0, 1.0),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) => _buildAnimated(context),
  );

  Widget _buildAnimated(BuildContext context) {
    final v = _c.value;
    final settled = _c.isCompleted;
    // The panel exists from the first frame of the fade (after the hold).
    final showCard = _reduce || v >= GameOverPanel.holdFraction;
    final t = _panelT(v);
    final dim = _reduce
        ? 0.0
        : (v / GameOverPanel.holdFraction).clamp(0.0, 1.0) *
              GameOverPanel.dimOpacity;
    final card = Container(
      key: widget.panelKey,
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
      decoration: BoxDecoration(
        color: GameOverPanel.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x66FFFFFF), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x80000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (widget.shareButton != null) widget.shareButton!,
              const Spacer(),
              // Room for the eye button, which sits on top of the faded card.
              const SizedBox(width: 44, height: 44),
            ],
          ),
          ShaderMask(
            shaderCallback: (r) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFF3A0), Color(0xFFFFB300)],
            ).createShader(r),
            child: Text(
              widget.title.toUpperCase(),
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 4),
          DefaultTextStyle.merge(
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: widget.details,
            ),
          ),
          const SizedBox(height: 14),
          // Play again and Home always side by side; the buttons shrink on narrow screens.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.buttons.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Flexible(child: widget.buttons[i]),
              ],
            ],
          ),
          if (widget.extraButton != null) ...[
            const SizedBox(height: 14),
            widget.extraButton!,
          ],
          if (widget.leadButton != null) ...[
            const SizedBox(height: 14),
            widget.leadButton!,
          ],
        ],
      ),
    );
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Dims the frozen scene to about 40 %; lifted while the board is being viewed.
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _hidden ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: ColoredBox(
                  key: const Key('game.over.scrim'),
                  color: Color.fromRGBO(0, 0, 0, dim),
                ),
              ),
            ),
          ),
          // Tap anywhere brings the panel back.
          if (_hidden)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _hidden = false),
              ),
            ),
          Align(
            alignment: Alignment.center,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Stack(
                  children: [
                    if (showCard)
                      IgnorePointer(
                        ignoring: _hidden || !settled,
                        child: Opacity(
                          opacity: t,
                          child: Transform.translate(
                            offset: Offset(
                              0,
                              _reduce
                                  ? 0
                                  : (1 - t) * GameOverPanel.slideDistance,
                            ),
                            child: AnimatedOpacity(
                              opacity: _hidden ? 0 : 1,
                              duration: const Duration(milliseconds: 200),
                              child: card,
                            ),
                          ),
                        ),
                      ),
                    if (showCard)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IgnorePointer(
                          ignoring: !settled,
                          child: Opacity(
                            opacity: t,
                            child: Transform.translate(
                              offset: Offset(
                                0,
                                _reduce
                                    ? 0
                                    : (1 - t) * GameOverPanel.slideDistance,
                              ),
                              child: IconButton(
                                key: widget.viewKey,
                                tooltip: _hidden ? 'Show panel' : 'View board',
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color(0xFF3A2A5C),
                                  foregroundColor: Colors.white,
                                ),
                                icon: Icon(
                                  _hidden
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () =>
                                    setState(() => _hidden = !_hidden),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum GameOverButtonKind { primary, secondary, ghost }

/// Glossy pill button: gold for the main action, purple-pink for secondary, dark glass for ghost.
/// Colours keep at least 4.5:1 contrast between text and button.
class GameOverButton extends StatelessWidget {
  const GameOverButton({
    super.key,
    this.label,
    required this.onPressed,
    this.icon,
    this.semanticLabel,
    this.kind = GameOverButtonKind.secondary,
    this.fontSize = 16,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
  }) : assert(label != null || icon != null);

  /// Null for an icon-only button (then [semanticLabel] names it).
  final String? label;
  final String? semanticLabel;
  final IconData? icon;
  final VoidCallback? onPressed;
  final GameOverButtonKind kind;
  final double fontSize;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final (colors, fg, border) = switch (kind) {
      GameOverButtonKind.primary => (
        const [Color(0xFFFFE259), Color(0xFFFF8F00)],
        const Color(0xFF3B1F00),
        const Color(0xFFFFF3A0),
      ),
      GameOverButtonKind.secondary => (
        const [Color(0xFF6A3AC4), Color(0xFFB0307A)],
        Colors.white,
        const Color(0xFFFFD6F2),
      ),
      GameOverButtonKind.ghost => (
        const [Color(0xFF3A2A5C), Color(0xFF2E2150)],
        Colors.white,
        const Color(0xCCFFFFFF),
      ),
    };
    final enabled = onPressed != null;
    return Semantics(
      label: semanticLabel,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: colors,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: border, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x73000000),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: onPressed,
              child: Padding(
                padding: padding,
                // Shrinks the content on very narrow screens instead of overflowing.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: fontSize + 4, color: fg),
                        if (label != null) const SizedBox(width: 6),
                      ],
                      if (label != null)
                        Text(
                          label!,
                          style: TextStyle(
                            color: fg,
                            fontSize: fontSize,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
