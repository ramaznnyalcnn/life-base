import 'package:flutter/material.dart';

/// User-selectable colour families. Some are dark-only.
enum LbPalette {
  kum('Kum'),
  adacayi('Adaçayı'),
  okyanus('Okyanus'),
  lavanta('Lavanta'),
  gul('Gül'),
  gece('Gece', darkOnly: true),
  grafit('Grafit', darkOnly: true);

  const LbPalette(this.label, {this.darkOnly = false});
  final String label;
  final bool darkOnly;
}

/// The four modules; each owns a hue used for its nav bubble and accents.
enum LbModule { today, wallet, calendar, meds }

/// Design tokens shared by every module.
///
/// Neumorphic depth comes from [highlight] (light source, top-left) and
/// [shade] (bottom-right) shadows on a surface painted in [base]. Text and
/// icons never rely on those shadows for contrast: they use [onBase]/[muted].
@immutable
class LbTokens extends ThemeExtension<LbTokens> {
  const LbTokens({
    required this.brightness,
    required this.base,
    required this.sunken,
    required this.highlight,
    required this.shade,
    required this.onBase,
    required this.muted,
    required this.accent,
    required this.onAccent,
    required this.income,
    required this.expense,
    required this.danger,
    required this.glass,
    required this.glassBorder,
    required this.modules,
    required this.reduceMotion,
  });

  final Brightness brightness;
  final Color base;
  final Color sunken;
  final Color highlight;
  final Color shade;
  final Color onBase;
  final Color muted;
  final Color accent;
  final Color onAccent;
  final Color income;
  final Color expense;
  final Color danger;
  final Color glass;
  final Color glassBorder;
  final Map<LbModule, Color> modules;
  final bool reduceMotion;

  static const radius = 22.0;
  static const radiusSmall = 14.0;
  static const depth = 6.0;

  /// Calm, decelerating motion used for every transition.
  static const motion = Duration(milliseconds: 320);
  static const motionShort = Duration(milliseconds: 180);
  static const curve = Cubic(0.2, 0, 0, 1);

  Color module(LbModule value) => modules[value]!;

  static LbTokens of(BuildContext context) => Theme.of(context).extension<LbTokens>()!;

  static LbTokens resolve(LbPalette palette, Brightness brightness, {bool reduceMotion = false}) {
    final dark = palette.darkOnly || brightness == Brightness.dark;
    final swatch = dark ? _dark[palette]! : _light[palette]!;
    return LbTokens(
      brightness: dark ? Brightness.dark : Brightness.light,
      base: swatch.base,
      sunken: Color.lerp(swatch.base, swatch.shade, dark ? .45 : .35)!,
      highlight: swatch.highlight,
      shade: swatch.shade,
      onBase: swatch.onBase,
      muted: swatch.muted,
      accent: swatch.accent,
      onAccent: dark ? const Color(0xFF111111) : Colors.white,
      income: dark ? const Color(0xFF7FD3A0) : const Color(0xFF2E7D4F),
      expense: dark ? const Color(0xFFF29A8E) : const Color(0xFFB3412F),
      danger: dark ? const Color(0xFFFF8A80) : const Color(0xFFB3261E),
      glass: swatch.base.withValues(alpha: dark ? .62 : .58),
      glassBorder: Colors.white.withValues(alpha: dark ? .08 : .55),
      modules: dark ? _darkModules : _lightModules,
      reduceMotion: reduceMotion,
    );
  }

  @override
  LbTokens copyWith({bool? reduceMotion}) => LbTokens(
        brightness: brightness,
        base: base,
        sunken: sunken,
        highlight: highlight,
        shade: shade,
        onBase: onBase,
        muted: muted,
        accent: accent,
        onAccent: onAccent,
        income: income,
        expense: expense,
        danger: danger,
        glass: glass,
        glassBorder: glassBorder,
        modules: modules,
        reduceMotion: reduceMotion ?? this.reduceMotion,
      );

  @override
  LbTokens lerp(LbTokens? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return LbTokens(
      brightness: t < .5 ? brightness : other.brightness,
      base: c(base, other.base),
      sunken: c(sunken, other.sunken),
      highlight: c(highlight, other.highlight),
      shade: c(shade, other.shade),
      onBase: c(onBase, other.onBase),
      muted: c(muted, other.muted),
      accent: c(accent, other.accent),
      onAccent: c(onAccent, other.onAccent),
      income: c(income, other.income),
      expense: c(expense, other.expense),
      danger: c(danger, other.danger),
      glass: c(glass, other.glass),
      glassBorder: c(glassBorder, other.glassBorder),
      modules: {for (final m in LbModule.values) m: c(module(m), other.module(m))},
      reduceMotion: t < .5 ? reduceMotion : other.reduceMotion,
    );
  }
}

class _Swatch {
  const _Swatch({
    required this.base,
    required this.highlight,
    required this.shade,
    required this.onBase,
    required this.muted,
    required this.accent,
  });
  final Color base, highlight, shade, onBase, muted, accent;
}

const _light = <LbPalette, _Swatch>{
  LbPalette.kum: _Swatch(
    base: Color(0xFFECE6DC),
    highlight: Color(0xFFFFFFFF),
    shade: Color(0xFFCBC2B3),
    onBase: Color(0xFF2B2620),
    muted: Color(0xFF6B6357),
    accent: Color(0xFFA4572A),
  ),
  LbPalette.adacayi: _Swatch(
    base: Color(0xFFE4EAE5),
    highlight: Color(0xFFFFFFFF),
    shade: Color(0xFFC2CCC4),
    onBase: Color(0xFF1F2A23),
    muted: Color(0xFF5B6A60),
    accent: Color(0xFF3B7356),
  ),
  LbPalette.okyanus: _Swatch(
    base: Color(0xFFE3E9F0),
    highlight: Color(0xFFFFFFFF),
    shade: Color(0xFFC1CAD7),
    onBase: Color(0xFF1C2633),
    muted: Color(0xFF586577),
    accent: Color(0xFF2C67A6),
  ),
  LbPalette.lavanta: _Swatch(
    base: Color(0xFFECE8F3),
    highlight: Color(0xFFFFFFFF),
    shade: Color(0xFFCAC3D8),
    onBase: Color(0xFF241F2E),
    muted: Color(0xFF5F5870),
    accent: Color(0xFF6447B0),
  ),
  LbPalette.gul: _Swatch(
    base: Color(0xFFF3E8E6),
    highlight: Color(0xFFFFFFFF),
    shade: Color(0xFFD6C5C2),
    onBase: Color(0xFF2E2120),
    muted: Color(0xFF6E5A58),
    accent: Color(0xFFA8445C),
  ),
  // Dark-only palettes: their light entries are never used.
  LbPalette.gece: _gece,
  LbPalette.grafit: _grafit,
};

const _dark = <LbPalette, _Swatch>{
  LbPalette.kum: _Swatch(
    base: Color(0xFF2A2622),
    highlight: Color(0xFF37322D),
    shade: Color(0xFF1B1815),
    onBase: Color(0xFFF1EBE2),
    muted: Color(0xFFB3A99B),
    accent: Color(0xFFE3A36F),
  ),
  LbPalette.adacayi: _Swatch(
    base: Color(0xFF222925),
    highlight: Color(0xFF2D3530),
    shade: Color(0xFF151A17),
    onBase: Color(0xFFE6EEE8),
    muted: Color(0xFFA0AEA4),
    accent: Color(0xFF8DCBA6),
  ),
  LbPalette.okyanus: _Swatch(
    base: Color(0xFF1F252D),
    highlight: Color(0xFF29313B),
    shade: Color(0xFF13181E),
    onBase: Color(0xFFE5ECF5),
    muted: Color(0xFF9EABBC),
    accent: Color(0xFF82B4E8),
  ),
  LbPalette.lavanta: _Swatch(
    base: Color(0xFF241F2D),
    highlight: Color(0xFF2F2939),
    shade: Color(0xFF17131E),
    onBase: Color(0xFFECE7F5),
    muted: Color(0xFFA9A1BB),
    accent: Color(0xFFB9A4F5),
  ),
  LbPalette.gul: _Swatch(
    base: Color(0xFF2B2223),
    highlight: Color(0xFF372C2D),
    shade: Color(0xFF1C1617),
    onBase: Color(0xFFF3E6E6),
    muted: Color(0xFFB9A3A4),
    accent: Color(0xFFEE9AAE),
  ),
  LbPalette.gece: _gece,
  LbPalette.grafit: _grafit,
};

const _gece = _Swatch(
  base: Color(0xFF16171B),
  highlight: Color(0xFF22242A),
  shade: Color(0xFF0B0C0E),
  onBase: Color(0xFFECECF1),
  muted: Color(0xFF9C9FAD),
  accent: Color(0xFFA99BFF),
);

const _grafit = _Swatch(
  base: Color(0xFF1C1D1F),
  highlight: Color(0xFF27292C),
  shade: Color(0xFF101112),
  onBase: Color(0xFFEDEDEE),
  muted: Color(0xFFA0A3A8),
  accent: Color(0xFFF2B84B),
);

const _lightModules = <LbModule, Color>{
  LbModule.today: Color(0xFF8A5A00),
  LbModule.wallet: Color(0xFF2E6B4A),
  LbModule.calendar: Color(0xFF2F5E9E),
  LbModule.meds: Color(0xFFA03D5A),
};

const _darkModules = <LbModule, Color>{
  LbModule.today: Color(0xFFF2C46B),
  LbModule.wallet: Color(0xFF86CFA5),
  LbModule.calendar: Color(0xFF8DB7F0),
  LbModule.meds: Color(0xFFF199B3),
};
