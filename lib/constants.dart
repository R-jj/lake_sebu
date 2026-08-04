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

const List<Map<String, Object>> kCategories = [
  {'label': 'All', 'icon': Icons.restaurant},
  {'label': 'Burgers', 'icon': Icons.lunch_dining},
  {'label': 'Pizza', 'icon': Icons.local_pizza},
  {'label': 'Sushi', 'icon': Icons.set_meal},
  {'label': 'Pasta', 'icon': Icons.ramen_dining},
  {'label': 'Tacos', 'icon': Icons.tapas},
];

const List<Map<String, Object>> kFeatured = [
  {
    'id': 1,
    'name': 'Double Smash Burger',
    'restaurant': 'The Patty Lab',
    'price': 149.0,
    'rating': 4.9,
    'time': '18–25 min',
    'img':
        'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400&h=320&fit=crop&auto=format',
    'tag': 'Best Seller',
    'tagColor': 0xFFFF4D1C,
  },
  {
    'id': 2,
    'name': 'Neapolitan Margherita',
    'restaurant': 'Forno Vivo',
    'price': 185.0,
    'rating': 4.8,
    'time': '22–32 min',
    'img':
        'https://images.unsplash.com/photo-1566843972142-a7fcb70de55a?w=400&h=320&fit=crop&auto=format',
    'tag': 'Popular',
    'tagColor': 0xFFF5C842,
  },
];

const List<Map<String, Object>> kNearby = [
  {
    'id': 1,
    'name': 'The Patty Lab',
    'cuisine': 'American · Burgers',
    'rating': 4.9,
    'time': '18 min',
    'fee': 'Free',
    'img':
        'https://images.unsplash.com/photo-1572802419224-296b0aeee0d9?w=120&h=120&fit=crop&auto=format',
  },
  {
    'id': 2,
    'name': 'Forno Vivo',
    'cuisine': 'Italian · Pizza',
    'rating': 4.8,
    'time': '24 min',
    'fee': '₱79.00',
    'img':
        'https://images.unsplash.com/photo-1715494534168-2ce3196e6d67?w=120&h=120&fit=crop&auto=format',
  },
  {
    'id': 3,
    'name': 'Umami House',
    'cuisine': 'Japanese · Sushi',
    'rating': 4.7,
    'time': '28 min',
    'fee': '₱49.00',
    'img':
        'https://images.unsplash.com/photo-1676037150294-837ff0c29599?w=120&h=120&fit=crop&auto=format',
  },
  {
    'id': 4,
    'name': 'Trattoria Roma',
    'cuisine': 'Italian · Pasta',
    'rating': 4.6,
    'time': '32 min',
    'fee': 'Free',
    'img':
        'https://images.unsplash.com/photo-1516100882582-96c3a05fe590?w=120&h=120&fit=crop&auto=format',
  },
];

const List<Map<String, Object>> kSearchSuggestions = [
  {'label': 'Burgers', 'icon': Icons.lunch_dining},
  {'label': 'Pizza', 'icon': Icons.local_pizza},
  {'label': 'Sushi', 'icon': Icons.set_meal},
  {'label': 'Tacos', 'icon': Icons.tapas},
  {'label': 'Desserts', 'icon': Icons.icecream},
  {'label': 'Salads', 'icon': Icons.eco},
];

const List<Map<String, Object>> kAllItems = [
  {
    'id': 1,
    'name': 'Double Smash Burger',
    'restaurant': 'The Patty Lab',
    'price': 149.0,
    'rating': 4.9,
    'img':
        'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=120&h=120&fit=crop&auto=format',
  },
  {
    'id': 2,
    'name': 'Neapolitan Margherita',
    'restaurant': 'Forno Vivo',
    'price': 185.0,
    'rating': 4.8,
    'img':
        'https://images.unsplash.com/photo-1566843972142-a7fcb70de55a?w=120&h=120&fit=crop&auto=format',
  },
  {
    'id': 3,
    'name': 'Chirashi Don Bowl',
    'restaurant': 'Umami House',
    'price': 220.0,
    'rating': 4.7,
    'img':
        'https://images.unsplash.com/photo-1676037150294-837ff0c29599?w=120&h=120&fit=crop&auto=format',
  },
  {
    'id': 4,
    'name': 'Cacio e Pepe',
    'restaurant': 'Trattoria Roma',
    'price': 168.0,
    'rating': 4.6,
    'img':
        'https://images.unsplash.com/photo-1516100882582-96c3a05fe590?w=120&h=120&fit=crop&auto=format',
  },
];

const List<Map<String, Object>> kOrders = [
  {
    'id': '#SW-4821',
    'restaurant': 'The Patty Lab',
    'items': ['Double Smash Burger ×1', 'Cola ×2'],
    'total': 218.0,
    'status': 'Delivered',
    'date': 'Jul 28, 2026',
    'img':
        'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=120&h=120&fit=crop&auto=format',
  },
  {
    'id': '#SW-4790',
    'restaurant': 'Forno Vivo',
    'items': ['Neapolitan Margherita ×1'],
    'total': 185.0,
    'status': 'Delivered',
    'date': 'Jul 22, 2026',
    'img':
        'https://images.unsplash.com/photo-1566843972142-a7fcb70de55a?w=120&h=120&fit=crop&auto=format',
  },
  {
    'id': '#SW-4763',
    'restaurant': 'Umami House',
    'items': ['Chirashi Don ×2', 'Miso Soup ×2'],
    'total': 510.0,
    'status': 'Cancelled',
    'date': 'Jul 15, 2026',
    'img':
        'https://images.unsplash.com/photo-1676037150294-837ff0c29599?w=120&h=120&fit=crop&auto=format',
  },
  {
    'id': '#SW-4701',
    'restaurant': 'Trattoria Roma',
    'items': ['Cacio e Pepe ×1', 'Tiramisu ×1'],
    'total': 243.0,
    'status': 'Delivered',
    'date': 'Jul 3, 2026',
    'img':
        'https://images.unsplash.com/photo-1516100882582-96c3a05fe590?w=120&h=120&fit=crop&auto=format',
  },
];
