/// The four accents and the neutrals from the approved mock-ups (roadmap, Phase 0). Every text
/// pairing is at least 4.5:1.
library;

import 'package:flutter/widgets.dart' show Brightness, Color;

enum Accent {
  sage('Sage'),
  dustyBlue('Dusty blue'),
  blush('Blush'),
  heather('Heather');

  const Accent(this.label);
  final String label;

  static Accent parse(String? s) => Accent.values.firstWhere((a) => a.name == s, orElse: () => Accent.sage);
}

class AccentColours {
  const AccentColours({required this.accent, required this.onAccent, required this.tint, required this.onTint});
  final Color accent;
  final Color onAccent;
  final Color tint;
  final Color onTint;
}

class Neutrals {
  const Neutrals({
    required this.background,
    required this.surface,
    required this.field,
    required this.text,
    required this.muted,
    required this.border,
  });
  final Color background;
  final Color surface;
  final Color field;
  final Color text;
  final Color muted;
  final Color border;
}

const lightNeutrals = Neutrals(
  background: Color(0xFFF7F6F3),
  surface: Color(0xFFFFFFFF),
  field: Color(0xFFFFFFFF),
  text: Color(0xFF1C1C1A),
  muted: Color(0xFF5E5D58),
  border: Color(0xFFE4E2DD),
);

const darkNeutrals = Neutrals(
  background: Color(0xFF141414),
  surface: Color(0xFF1E1E1E),
  field: Color(0xFF222222),
  text: Color(0xFFEDEDEA),
  muted: Color(0xFFA3A29D),
  border: Color(0xFF2E2E2C),
);

AccentColours accentColours(Accent a, Brightness b) {
  final dark = b == Brightness.dark;
  return switch (a) {
    Accent.sage => dark
        ? const AccentColours(accent: Color(0xFF9DBFA5), onAccent: Color(0xFF13201A), tint: Color(0xFF22302A), onTint: Color(0xFFB8D6BF))
        : const AccentColours(accent: Color(0xFF4F6F58), onAccent: Color(0xFFFFFFFF), tint: Color(0xFFE3ECE5), onTint: Color(0xFF33503C)),
    Accent.dustyBlue => dark
        ? const AccentColours(accent: Color(0xFF9DB5CC), onAccent: Color(0xFF121B24), tint: Color(0xFF1F2A35), onTint: Color(0xFFBCD0E3))
        : const AccentColours(accent: Color(0xFF4E6A85), onAccent: Color(0xFFFFFFFF), tint: Color(0xFFE2E9F0), onTint: Color(0xFF34506A)),
    Accent.blush => dark
        ? const AccentColours(accent: Color(0xFFE0AEB6), onAccent: Color(0xFF2A1519), tint: Color(0xFF3A262A), onTint: Color(0xFFF0C9CF))
        : const AccentColours(accent: Color(0xFF9A5B66), onAccent: Color(0xFFFFFFFF), tint: Color(0xFFF4E4E6), onTint: Color(0xFF7A3F4B)),
    Accent.heather => dark
        ? const AccentColours(accent: Color(0xFFB9A7D0), onAccent: Color(0xFF1E1529), tint: Color(0xFF2C2536), onTint: Color(0xFFD3C6E4))
        : const AccentColours(accent: Color(0xFF6E5A86), onAccent: Color(0xFFFFFFFF), tint: Color(0xFFEAE4F0), onTint: Color(0xFF533F6B)),
  };
}

/// Muted colours for covers drawn when a book has no cover image (like the mock-ups).
const placeholderCovers = <(Color bg, Color fg)>[
  (Color(0xFFA3B18A), Color(0xFF1C2414)),
  (Color(0xFF6D6875), Color(0xFFFFFFFF)),
  (Color(0xFFC9B79C), Color(0xFF2B2318)),
  (Color(0xFF3D5A6C), Color(0xFFFFFFFF)),
  (Color(0xFFE5C1BD), Color(0xFF3A2224)),
  (Color(0xFF8A9BA8), Color(0xFF10181E)),
  (Color(0xFF4A4E69), Color(0xFFFFFFFF)),
  (Color(0xFFB5838D), Color(0xFF2A1519)),
  (Color(0xFFD4A373), Color(0xFF2B1D0E)),
];
