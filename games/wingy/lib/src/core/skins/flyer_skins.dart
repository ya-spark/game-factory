/// Cosmetic flyer skins. Pure data: the hitbox and physics never depend on them, and
/// `lib/game/rules/` does not know about skins. Colours are ARGB ints (no Flutter import).
class FlyerSkin {
  const FlyerSkin({
    required this.id,
    required this.name,
    required this.price,
    required this.wing,
    required this.wingEdge,
    required this.body,
    required this.glow,
    required this.glowCore,
    required this.trail,
    this.wingLength = 22,
    this.hindWing = false,
    this.sparkle = false,
    this.antennae = false,
  });

  final String id;
  final String name;

  /// Coins; 0 for the free default.
  final int price;
  final int wing;
  final int wingEdge;
  final int body;

  /// Soft glow around the abdomen, its bright core, and the dash trail colour.
  final int glow;
  final int glowCore;
  final int trail;

  /// Wing reach in logical units (shape only; the hitbox is unchanged).
  final double wingLength;

  /// A smaller second wing pair below the main one (butterfly, dragonfly).
  final bool hindWing;

  /// Star-shaped sparkle instead of a plain glow (Star Sprite).
  final bool sparkle;
  final bool antennae;
}

abstract final class FlyerSkins {
  static const String defaultId = 'moth';

  static const moth = FlyerSkin(
    id: 'moth',
    name: 'Moth',
    price: 0,
    wing: 0xCCEBD9FF,
    wingEdge: 0xFFB896FF,
    body: 0xFF6B4E9B,
    glow: 0x88FFD36B,
    glowCore: 0xFFFFE9A8,
    trail: 0xFFFFE066,
  );
  static const butterfly = FlyerSkin(
    id: 'butterfly',
    name: 'Butterfly',
    price: 300,
    wing: 0xDDFF9BC8,
    wingEdge: 0xFFD6247A,
    body: 0xFF4A2B5E,
    glow: 0x66FF8AB8,
    glowCore: 0xFFFFD0E4,
    trail: 0xFFFF8AB8,
    wingLength: 26,
    hindWing: true,
    antennae: true,
  );
  static const firefly = FlyerSkin(
    id: 'firefly',
    name: 'Firefly',
    price: 500,
    wing: 0xAAD8E8C0,
    wingEdge: 0xFF8FB36A,
    body: 0xFF3C4A2E,
    glow: 0xCCC6FF3D,
    glowCore: 0xFFF4FFA0,
    trail: 0xFFC6FF3D,
    wingLength: 19,
  );
  static const dragonfly = FlyerSkin(
    id: 'dragonfly',
    name: 'Dragonfly',
    price: 800,
    wing: 0x9985F0FF,
    wingEdge: 0xFF1FA8C9,
    body: 0xFF127C96,
    glow: 0x7743E0FF,
    glowCore: 0xFFC9F8FF,
    trail: 0xFF43E0FF,
    wingLength: 30,
    hindWing: true,
  );
  static const starSprite = FlyerSkin(
    id: 'star_sprite',
    name: 'Star Sprite',
    price: 1200,
    wing: 0xCCFFF2A8,
    wingEdge: 0xFFFFC233,
    body: 0xFFFFB400,
    glow: 0xAAFFE066,
    glowCore: 0xFFFFFFFF,
    trail: 0xFFFFD84D,
    wingLength: 24,
    sparkle: true,
  );

  static const List<FlyerSkin> all = [
    moth,
    butterfly,
    firefly,
    dragonfly,
    starSprite,
  ];

  static FlyerSkin? byId(String id) {
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// The skin for [id], or the Moth when unknown.
  static FlyerSkin of(String id) => byId(id) ?? moth;
}
