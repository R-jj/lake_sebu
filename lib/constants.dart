import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Colors ────────────────────────────────────────────────────────────────────

const kBrand = Color(0xFFFF4D1C);
const kBrandDark = Color(0xFFD93A0F);
const kCanvas = Color(0xFF0F0D0C);
const kSurface = Color(0xFF1A1714);
const kSurface2 = Color(0xFF231F1C);
const kBorder = Color(0xFF3D3830);
const kInk = Color(0xFFF5F0EA);
const kMuted = Color(0xFF9E9690);
const kGold = Color(0xFFF5C842);
const kGreen = Color(0xFF4CAF82);
const kRed = Color(0xFFEF4444);

/// System fonts that contain the peso sign (₱, U+20B1) — used as glyph
/// fallbacks because Figtree/Fraunces lack that character.
const List<String> kPesoFallbackFonts = ['Roboto', 'Segoe UI', 'Noto Sans', 'sans-serif'];

/// Display font — Fraunces, loaded at runtime by google_fonts.
final TextStyle kSerif = GoogleFonts.fraunces()
    .copyWith(fontFamilyFallback: kPesoFallbackFonts);

/// App-wide text theme (Figtree body font) with glyph fallbacks so the
/// peso sign renders correctly on every platform.
TextTheme appTextTheme() {
  final theme = GoogleFonts.figtreeTextTheme();
  TextStyle? fb(TextStyle? style) =>
      style?.copyWith(fontFamilyFallback: kPesoFallbackFonts);
  return TextTheme(
    displayLarge: fb(theme.displayLarge),
    displayMedium: fb(theme.displayMedium),
    displaySmall: fb(theme.displaySmall),
    headlineLarge: fb(theme.headlineLarge),
    headlineMedium: fb(theme.headlineMedium),
    headlineSmall: fb(theme.headlineSmall),
    titleLarge: fb(theme.titleLarge),
    titleMedium: fb(theme.titleMedium),
    titleSmall: fb(theme.titleSmall),
    bodyLarge: fb(theme.bodyLarge),
    bodyMedium: fb(theme.bodyMedium),
    bodySmall: fb(theme.bodySmall),
    labelLarge: fb(theme.labelLarge),
    labelMedium: fb(theme.labelMedium),
    labelSmall: fb(theme.labelSmall),
  );
}

// ── Formatting ────────────────────────────────────────────────────────────────

/// Formats an amount as Philippine Pesos, e.g. `formatPeso(299)` → `₱299.00`.
String formatPeso(num? amount) => '₱${(amount ?? 0).toStringAsFixed(2)}';

// ── Data ──────────────────────────────────────────────────────────────────────

// Category icon lookup — used by home_page.dart and all_categories_page.dart
// to map a category label coming from Firestore to a Material icon.
// Add entries here as new Firestore categories are introduced.
const Map<String, IconData> kCategoryIcons = {
  'All':         Icons.restaurant,
  'Burgers':     Icons.lunch_dining,
  'Pizza':       Icons.local_pizza,
  'Sushi':       Icons.set_meal,
  'Pasta':       Icons.ramen_dining,
  'Tacos':       Icons.tapas,
  'Salads':      Icons.eco,
  'Desserts':    Icons.icecream,
  'Drinks':      Icons.local_cafe,
  'Breakfast':   Icons.egg_alt,
  'Sandwiches':  Icons.lunch_dining,
  'Noodles':     Icons.ramen_dining,
  'Chicken':     Icons.set_meal,
  'Seafood':     Icons.set_meal,
  'Vegan':       Icons.eco,
  'BBQ':         Icons.outdoor_grill,
  'Indian':      Icons.restaurant,
  'Mains':       Icons.dinner_dining,
};

// Category color lookup — used by all_categories_page.dart tiles.
const Map<String, int> kCategoryColors = {
  'All':         0xFFFF4D1C,
  'Burgers':     0xFFFF6B35,
  'Pizza':       0xFFE63946,
  'Sushi':       0xFF2D6A4F,
  'Pasta':       0xFFF4A261,
  'Tacos':       0xFFE9C46A,
  'Salads':      0xFF52B788,
  'Desserts':    0xFFC77DFF,
  'Drinks':      0xFF4CC9F0,
  'Breakfast':   0xFFF3722C,
  'Sandwiches':  0xFF90BE6D,
  'Noodles':     0xFFF8961E,
  'Chicken':     0xFFFF4D1C,
  'Seafood':     0xFF277DA1,
  'Vegan':       0xFF4CAF82,
  'BBQ':         0xFFBC4749,
  'Indian':      0xFFF9844A,
  'Mains':       0xFF4CC9F0,
};

// Category emoji lookup — used by all_categories_page.dart tiles.
const Map<String, String> kCategoryEmojis = {
  'All':         '🍽️',
  'Burgers':     '🍔',
  'Pizza':       '🍕',
  'Sushi':       '🍣',
  'Pasta':       '🍝',
  'Tacos':       '🌮',
  'Salads':      '🥗',
  'Desserts':    '🍰',
  'Drinks':      '🧃',
  'Breakfast':   '🍳',
  'Sandwiches':  '🥪',
  'Noodles':     '🍜',
  'Chicken':     '🍗',
  'Seafood':     '🦞',
  'Vegan':       '🌱',
  'BBQ':         '🍖',
  'Indian':      '🍛',
  'Mains':       '🥘',
};

