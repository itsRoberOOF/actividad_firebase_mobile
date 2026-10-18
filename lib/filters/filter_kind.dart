enum FaceFilter {
  sunglasses(
    label: 'Lentes',
    asset: 'assets/filters/sunglasses.png',
    nativeName: 'sunglasses',
    spriteWidth: 1000,
    spriteHeight: 400,
  ),
  mustache(
    label: 'Bigote',
    asset: 'assets/filters/mustache.png',
    nativeName: 'mustache',
    spriteWidth: 600,
    spriteHeight: 220,
  ),
  crown(
    label: 'Corona',
    asset: 'assets/filters/crown.png',
    nativeName: 'crown',
    spriteWidth: 600,
    spriteHeight: 360,
  );

  const FaceFilter({
    required this.label,
    required this.asset,
    required this.nativeName,
    required this.spriteWidth,
    required this.spriteHeight,
  });

  final String label;
  final String asset;

  /// Nombre que entiende el puente Android; debe coincidir con el contrato.
  final String nativeName;

  /// Dimensiones de los PNG de `assets/filters/`, generados por
  /// `tool/generate_filter_assets.dart`.
  final int spriteWidth;
  final int spriteHeight;

  double get spriteAspect => spriteHeight / spriteWidth;
}
