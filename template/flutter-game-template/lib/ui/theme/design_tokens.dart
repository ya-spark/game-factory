import 'dart:convert';
import 'dart:math' as math;

/// Design tokens, parsed from the committed `design/` JSON (bundled at `assets/design/`).
/// Pure Dart (no Flutter imports): colours are 0xAARRGGBB ints so this is testable on the VM.
///
/// Source of truth: `design/tokens.json` (shared) and `design/<app_id>/tokens.json` (per app).
/// Loaded from the bundled assets at start-up (no network); see `design_loader.dart`.

/// The look modes of an app: Game and Study (Scout, Ranger, Champion) or one Default (Mind).
enum DesignMode {
  game,
  study,
  defaultMode;

  String get key => this == DesignMode.defaultMode ? 'default' : name;

  static DesignMode fromKey(String k) => DesignMode.values.firstWhere(
    (m) => m.key == k,
    orElse: () => throw FormatException('unknown design mode "$k"'),
  );
}

/// Interface levels for Scout and Ranger (`levels` in the app tokens).
enum InterfaceLevel {
  younger,
  older;

  /// Younger = Foundation to Year 2, older = Years 3 to 6.
  static InterfaceLevel forYear(int year) =>
      year <= 2 ? InterfaceLevel.younger : InterfaceLevel.older;
}

class LevelTokens {
  const LevelTokens({
    required this.textScale,
    required this.minTouch,
    required this.timers,
    required this.voiceFirst,
  });
  final double textScale;
  final double minTouch;

  /// `false`, `'gentle'` or `true` in the file; kept as the raw value.
  final Object timers;
  final bool voiceFirst;
}

class TypeStyleToken {
  const TypeStyleToken(this.size, this.weight);
  final double size;
  final int weight;
}

class SharedTokens {
  const SharedTokens({
    required this.spacing,
    required this.type,
    required this.size,
    required this.fastMs,
    required this.normalMs,
    required this.slowMs,
    required this.minContrast,
  });

  factory SharedTokens.fromJson(String source) {
    final j = jsonDecode(source) as Map<String, dynamic>;
    final type = <String, TypeStyleToken>{};
    (j['type'] as Map<String, dynamic>).forEach((k, v) {
      if (v is Map<String, dynamic>) {
        type[k] = TypeStyleToken(
          (v['size'] as num).toDouble(),
          (v['weight'] as num).toInt(),
        );
      }
    });
    final motion = j['motion'] as Map<String, dynamic>;
    return SharedTokens(
      spacing: {
        for (final e in (j['spacing'] as Map<String, dynamic>).entries)
          e.key: (e.value as num).toDouble(),
      },
      type: type,
      size: {
        for (final e in (j['size'] as Map<String, dynamic>).entries)
          e.key: (e.value as num).toDouble(),
      },
      fastMs: (motion['fast_ms'] as num).toInt(),
      normalMs: (motion['normal_ms'] as num).toInt(),
      slowMs: (motion['slow_ms'] as num).toInt(),
      minContrast: ((j['a11y'] as Map<String, dynamic>)['min_contrast'] as num)
          .toDouble(),
    );
  }

  final Map<String, double> spacing;
  final Map<String, TypeStyleToken> type;
  final Map<String, double> size;
  final int fastMs;
  final int normalMs;
  final int slowMs;
  final double minContrast;
}

class ModeTokens {
  const ModeTokens({
    required this.colors,
    required this.buttonRadius,
    required this.cardRadius,
  });
  final Map<String, int> colors;
  final double buttonRadius;
  final double cardRadius;

  int color(String name) =>
      colors[name] ?? (throw ArgumentError('no colour token "$name"'));
}

class AppTokens {
  const AppTokens({
    required this.appId,
    required this.name,
    required this.fontFamily,
    required this.fontFiles,
    required this.modes,
    required this.levels,
  });

  factory AppTokens.fromJson(String source) {
    final j = jsonDecode(source) as Map<String, dynamic>;
    final font = j['font'] as Map<String, dynamic>;
    final modes = <DesignMode, ModeTokens>{};
    (j['modes'] as Map<String, dynamic>).forEach((k, v) {
      final m = v as Map<String, dynamic>;
      final radius = m['radius'] as Map<String, dynamic>;
      modes[DesignMode.fromKey(k)] = ModeTokens(
        colors: {
          for (final e in (m['color'] as Map<String, dynamic>).entries)
            e.key: parseHex(e.value as String),
        },
        buttonRadius: (radius['button'] as num).toDouble(),
        cardRadius: (radius['card'] as num).toDouble(),
      );
    });
    final levels = <InterfaceLevel, LevelTokens>{};
    (j['levels'] as Map<String, dynamic>?)?.forEach((k, v) {
      final l = v as Map<String, dynamic>;
      levels[InterfaceLevel.values.firstWhere(
        (e) => e.name == k,
      )] = LevelTokens(
        textScale: (l['text_scale'] as num).toDouble(),
        minTouch: (l['min_touch'] as num).toDouble(),
        timers: l['timers'] ?? false,
        voiceFirst: (l['voice_first'] as bool?) ?? false,
      );
    });
    return AppTokens(
      appId: j['app_id'] as String,
      name: j['name'] as String,
      fontFamily: font['family'] as String,
      fontFiles: (font['files'] as List).cast<String>(),
      modes: modes,
      levels: levels,
    );
  }

  final String appId;
  final String name;
  final String fontFamily;
  final List<String> fontFiles;
  final Map<DesignMode, ModeTokens> modes;
  final Map<InterfaceLevel, LevelTokens> levels;

  /// True for Nunito, which ships as one variable file.
  bool get variableFont => fontFiles.length == 1;

  /// The mode to use when the app has no such mode (Mind apps have only `default`).
  DesignMode resolveMode(DesignMode wanted) =>
      modes.containsKey(wanted) ? wanted : modes.keys.first;
}

/// `#RRGGBB` to 0xFFRRGGBB.
int parseHex(String hex) {
  final m = RegExp(r'^#([0-9A-Fa-f]{6})$').firstMatch(hex);
  if (m == null) throw FormatException('bad colour "$hex"');
  return 0xFF000000 | int.parse(m.group(1)!, radix: 16);
}

double _lin(int channel) {
  final c = channel / 255;
  return c <= 0.03928
      ? c / 12.92
      : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}

double relativeLuminance(int argb) =>
    0.2126 * _lin((argb >> 16) & 0xFF) +
    0.7152 * _lin((argb >> 8) & 0xFF) +
    0.0722 * _lin(argb & 0xFF);

/// WCAG contrast ratio, 1 to 21.
double contrastRatio(int a, int b) {
  final la = relativeLuminance(a);
  final lb = relativeLuminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Every text or button colour pair that must reach [SharedTokens.minContrast].
const List<(String, String)> contrastPairs = [
  ('text', 'bg'),
  ('text', 'surface'),
  ('text', 'surface-alt'),
  ('text-muted', 'bg'),
  ('text-muted', 'surface'),
  ('text-muted', 'surface-alt'),
  ('on-primary', 'primary'),
  ('on-accent', 'accent'),
  ('on-coin', 'coin'),
];
