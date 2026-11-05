import 'package:flutter/material.dart';

import 'test_ids.dart';

/// Game-over overlay: a rounded dark panel (about 90 % opaque, thin light border, soft shadow)
/// so text and buttons never mix with the game background. Top to bottom: Share (top left),
/// title, details, Play again + Home side by side, Continue last (large, gold).
/// The eye button fades the panel out (0.2 s) to show the final board; a tap anywhere, or the
/// eye button again, brings it back.
///
/// Entrance (1 s, ease-in): 0.3 s hold while the scene dims, then 0.7 s fade with a 24 px
/// slide-up. Buttons are tappable once the panel has settled. With reduce motion the whole
/// entrance is a single 0.2 s fade.
class GameOverPanel extends StatefulWidget {
  const GameOverPanel({
    super.key,
    required this.title,
    required this.details,
    required this.share,
    required this.again,
    required this.home,
    this.cont,
  });

  final String title;

  /// Score, best, continues left... shown under the title.
  final List<Widget> details;
  final GameOverButton share;
  final GameOverButton again;
  final GameOverButton home;

  /// The second chance (ad or coins); null when none is left.
  final GameOverButton? cont;

  /// Panel fill: dark surface at 90 % opacity.
  static const Color surface = Color(0xE61E1535);

  /// White text with a dark outline: readable over any background.
  static List<Shadow> get outline => const [
    Shadow(color: Color(0xE6000000), blurRadius: 0, offset: Offset(-1.5, -1.5)),
    Shadow(color: Color(0xE6000000), blurRadius: 0, offset: Offset(1.5, -1.5)),
    Shadow(color: Color(0xE6000000), blurRadius: 0, offset: Offset(-1.5, 1.5)),
    Shadow(color: Color(0xE6000000), blurRadius: 0, offset: Offset(1.5, 1.5)),
    Shadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 3)),
  ];

  @override
  State<GameOverPanel> createState() => _GameOverPanelState();
}

class _GameOverPanelState extends State<GameOverPanel>
    with SingleTickerProviderStateMixin {
  bool _hidden = false;
  late final AnimationController _intro = AnimationController(vsync: this);
  bool _started = false;

  /// Hold before the panel appears, and the panel's own fade/slide (total 1 s).
  static const _holdMs = 300;
  static const _panelMs = 700;
  static const _reducedMs = 200;
  static const _slide = 24.0;
  static const _dim = 0.4;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Reduce motion: a single 0.2 s fade, no hold and no slide.
    final reduce = MediaQuery.disableAnimationsOf(context);
    _intro.duration = Duration(
      milliseconds: reduce ? _reducedMs : _holdMs + _panelMs,
    );
    _intro.forward();
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  bool get _reduce => _intro.duration!.inMilliseconds == _reducedMs;

  /// 0..1 progress of the panel fade (after the hold).
  double get _panelT {
    if (_reduce) return _intro.value;
    final t = (_intro.value * (_holdMs + _panelMs) - _holdMs) / _panelMs;
    return t.clamp(0.0, 1.0);
  }

  /// 0..1 progress of the scene dimming (during the hold).
  double get _dimT => _reduce
      ? _intro.value
      : (_intro.value * (_holdMs + _panelMs) / _holdMs).clamp(0.0, 1.0);

  void _toggle() => setState(() => _hidden = !_hidden);

  @override
  Widget build(BuildContext context) {
    final w = widget;
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Scene dims to about 40 % while the end of the run sinks in.
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _intro,
              builder: (context, _) => AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _hidden ? 0 : 1,
                child: ColoredBox(color: Color.fromRGBO(0, 0, 0, _dim * _dimT)),
              ),
            ),
          ),
          // While the panel is hidden, a tap anywhere brings it back.
          if (_hidden)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggle,
              child: const SizedBox.expand(),
            ),
          Align(
            alignment: Alignment.topCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Stack(
                    children: [
                      AnimatedBuilder(
                        animation: _intro,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: _hidden ? 0 : 1,
                          child: _card(w),
                        ),
                        // Buttons are tappable only once the panel has settled.
                        builder: (context, child) => IgnorePointer(
                          ignoring: _hidden || !_intro.isCompleted,
                          child: Opacity(
                            opacity: _panelT,
                            child: Transform.translate(
                              offset: Offset(
                                0,
                                _reduce
                                    ? 0
                                    : _slide *
                                          (1 -
                                              Curves.easeOutCubic.transform(
                                                _panelT,
                                              )),
                              ),
                              child: child,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          key: TestIds.gameOverView,
                          tooltip: _hidden ? 'Show panel' : 'View board',
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0x66000000),
                          ),
                          icon: Icon(
                            _hidden ? Icons.visibility_off : Icons.visibility,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            if (_intro.isCompleted) _toggle();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(GameOverPanel w) {
    return Container(
      key: TestIds.gameOverPanel,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: GameOverPanel.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x55FFFFFF), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x80000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(alignment: Alignment.centerLeft, child: w.share),
          ShaderMask(
            shaderCallback: (r) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFF3A0), Color(0xFFFFB300)],
            ).createShader(r),
            child: Text(
              w.title.toUpperCase(),
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
            child: Column(mainAxisSize: MainAxisSize.min, children: w.details),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(child: w.again),
              const SizedBox(width: 10),
              Flexible(child: w.home),
            ],
          ),
          if (w.cont != null) ...[const SizedBox(height: 12), w.cont!],
        ],
      ),
    );
  }
}

enum GameOverButtonKind { primary, secondary, ghost }

/// [large] is the focus action (font 22, padding 28x16); [compact] is the secondary
/// action (font 15, padding 18x9); [regular] is the default pill.
enum GameOverButtonSize { large, regular, compact }

/// Glossy pill button: gold for the main action, purple-pink for secondary, glass for ghost.
/// Label colours keep at least 4.5:1 against their fill and the dark panel.
class GameOverButton extends StatelessWidget {
  const GameOverButton({
    super.key,
    this.label,
    required this.onPressed,
    this.icon,
    this.semanticLabel,
    this.kind = GameOverButtonKind.secondary,
    this.size = GameOverButtonSize.regular,
  }) : assert(label != null || icon != null);

  /// Null for an icon-only button (then [semanticLabel] names it).
  final String? label;
  final String? semanticLabel;
  final IconData? icon;
  final VoidCallback? onPressed;
  final GameOverButtonKind kind;
  final GameOverButtonSize size;

  @override
  Widget build(BuildContext context) {
    final (colors, fg, border) = switch (kind) {
      GameOverButtonKind.primary => (
        const [Color(0xFFFFE259), Color(0xFFFF8F00)],
        const Color(0xFF3B1F00),
        const Color(0xFFFFF3A0),
      ),
      GameOverButtonKind.secondary => (
        const [Color(0xFF7B3FD6), Color(0xFFB02F78)],
        Colors.white,
        const Color(0xFFFFD6F2),
      ),
      GameOverButtonKind.ghost => (
        const [Color(0x40FFFFFF), Color(0x26FFFFFF)],
        Colors.white,
        const Color(0xCCFFFFFF),
      ),
    };
    final (fontSize, padding) = switch (size) {
      GameOverButtonSize.large => (
        22.0,
        const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      ),
      GameOverButtonSize.regular => (
        16.0,
        const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
      ),
      GameOverButtonSize.compact => (
        15.0,
        const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: fontSize + 4, color: fg),
                      if (label != null) const SizedBox(width: 6),
                    ],
                    // Scales down only if the label cannot fit the screen width.
                    if (label != null)
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            label!,
                            style: TextStyle(
                              color: fg,
                              fontSize: fontSize,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
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
}
