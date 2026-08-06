import 'package:flutter/material.dart';

/// Les 6 couleurs de la palette "Le Ticket" (nuancier validé) — toutes les
/// autres teintes (surfaces, tracks, dividers) sont dérivées de celles-ci.
class _Palette {
  static const terreCuite = Color(0xFFB85A32);

  /// Terre cuite éclaircie, réservée au mode sombre pour le texte et les
  /// icônes : le terre cuite d'origine ne donne que 4,0:1 sur le fond
  /// sombre, insuffisant hors gros titres. Cette variante monte à 6,7:1.
  /// Les aplats (boutons) gardent le terre cuite d'origine, dont le texte
  /// blanc perdrait en lisibilité sur un fond plus clair.
  static const terreCuiteClaire = Color(0xFFE08355);
  static const vertEpargne = Color(0xFF3F7A5E);
  static const encre = Color(0xFF1C1A17);
  static const grisChaud = Color(0xFF6E675E);
  static const papier = Color(0xFFEFEAE1);
  static const fondSombre = Color(0xFF16150F);
}

/// Palette "Le Ticket + la jauge" — univers visuel inspiré du ticket de
/// caisse, orange/terracotta, chaleureux et rassurant (pas de rouge
/// alarmant, pas de ton "fintech agressive").
///
/// Regroupée ici plutôt que dispatchée dans chaque écran : une seule
/// source pour rebrander l'app en changeant quelques valeurs.
///
/// Exposée comme [ThemeExtension] pour être lue via
/// `Theme.of(context).extension<AppColors>()!` et pour bénéficier du
/// fondu animé entre clair et sombre.
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.primary,
    required this.primaryDark,
    required this.onPrimary,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.track,
    required this.hachure,
    required this.savings,
    required this.savingsSurface,
    required this.divider,
  });

  final Color background;
  final Color surface;

  /// Fond légèrement teinté (encarts, note explicative) — un cran entre
  /// [surface] et [track].
  final Color surfaceAlt;

  /// Terre cuite des aplats : boutons, pastilles, puces sélectionnées.
  /// Toujours associé à [onPrimary].
  final Color primary;
  final Color primaryDark;
  final Color onPrimary;

  /// Terre cuite du texte et des icônes posés sur un fond de l'app.
  /// Identique à [primary] en clair, éclairci en sombre pour garder un
  /// contraste suffisant.
  final Color accent;

  final Color textPrimary;
  final Color textSecondary;

  /// Fond neutre d'une barre de jauge non remplie.
  final Color track;

  /// Couleur des hachures terre cuite (l'écart, jamais du rouge).
  final Color hachure;

  /// Vert épargne du tarif optimisé et de l'économie réalisée.
  final Color savings;

  /// Fond de l'encart "Économie par mois".
  final Color savingsSurface;

  final Color divider;

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? primary,
    Color? primaryDark,
    Color? onPrimary,
    Color? accent,
    Color? textPrimary,
    Color? textSecondary,
    Color? track,
    Color? hachure,
    Color? savings,
    Color? savingsSurface,
    Color? divider,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      primary: primary ?? this.primary,
      primaryDark: primaryDark ?? this.primaryDark,
      onPrimary: onPrimary ?? this.onPrimary,
      accent: accent ?? this.accent,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      track: track ?? this.track,
      hachure: hachure ?? this.hachure,
      savings: savings ?? this.savings,
      savingsSurface: savingsSurface ?? this.savingsSurface,
      divider: divider ?? this.divider,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      track: Color.lerp(track, other.track, t)!,
      hachure: Color.lerp(hachure, other.hachure, t)!,
      savings: Color.lerp(savings, other.savings, t)!,
      savingsSurface: Color.lerp(savingsSurface, other.savingsSurface, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
    );
  }

  static const light = AppColors(
    background: _Palette.papier,
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF5F1E7),
    primary: _Palette.terreCuite,
    primaryDark: Color(0xFF9C4B29),
    onPrimary: Color(0xFFFFFFFF),
    accent: _Palette.terreCuite,
    textPrimary: _Palette.encre,
    textSecondary: _Palette.grisChaud,
    track: Color(0xFFE4DDD0),
    hachure: _Palette.terreCuite,
    savings: _Palette.vertEpargne,
    savingsSurface: Color(0xFFE3EFE8),
    divider: Color(0xFFE8E1D3),
  );

  static const dark = AppColors(
    background: _Palette.fondSombre,
    surface: Color(0xFF221F17),
    surfaceAlt: Color(0xFF2A261C),
    primary: _Palette.terreCuite,
    primaryDark: Color(0xFF9C4B29),
    onPrimary: Color(0xFFFFFFFF),
    accent: _Palette.terreCuiteClaire,
    textPrimary: _Palette.papier,
    textSecondary: Color(0xFF9C9488),
    track: Color(0xFF332E22),
    // Éclaircie aussi : les hachures sur le track sombre tombaient à
    // 2,9:1, sous le seuil de 3:1 des éléments graphiques.
    hachure: _Palette.terreCuiteClaire,
    savings: Color(0xFF57A67D),
    savingsSurface: Color(0xFF1E3327),
    divider: Color(0xFF2E2A20),
  );
}

extension AppColorsContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
