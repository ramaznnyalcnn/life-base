import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tokens.dart';

@immutable
class Appearance {
  const Appearance({
    this.palette = LbPalette.kum,
    this.mode = ThemeMode.system,
    this.reduceMotion = false,
  });

  final LbPalette palette;
  final ThemeMode mode;
  final bool reduceMotion;

  Appearance copyWith({LbPalette? palette, ThemeMode? mode, bool? reduceMotion}) => Appearance(
        palette: palette ?? this.palette,
        mode: mode ?? this.mode,
        reduceMotion: reduceMotion ?? this.reduceMotion,
      );

  @override
  bool operator ==(Object other) =>
      other is Appearance &&
      other.palette == palette &&
      other.mode == mode &&
      other.reduceMotion == reduceMotion;

  @override
  int get hashCode => Object.hash(palette, mode, reduceMotion);
}

/// Saved appearance read in `main()` before the first frame, so the app never
/// flashes the default theme. Tests may leave it at the default.
final initialAppearanceProvider = Provider<Appearance>((ref) => const Appearance());

final appearanceProvider =
    NotifierProvider<AppearanceController, Appearance>(AppearanceController.new);

/// Persists theme choices so they survive restarts.
class AppearanceController extends Notifier<Appearance> {
  static const _paletteKey = 'appearance.palette';
  static const _modeKey = 'appearance.mode';
  static const _motionKey = 'appearance.reduce_motion';

  static Future<Appearance> load() async {
    final prefs = await SharedPreferences.getInstance();
    return Appearance(
      palette: LbPalette.values.asNameMap()[prefs.getString(_paletteKey)] ?? LbPalette.kum,
      mode: ThemeMode.values.asNameMap()[prefs.getString(_modeKey)] ?? ThemeMode.system,
      reduceMotion: prefs.getBool(_motionKey) ?? false,
    );
  }

  @override
  Appearance build() => ref.read(initialAppearanceProvider);

  Future<void> setPalette(LbPalette value) async {
    state = state.copyWith(palette: value);
    await (await SharedPreferences.getInstance()).setString(_paletteKey, value.name);
  }

  Future<void> setMode(ThemeMode value) async {
    state = state.copyWith(mode: value);
    await (await SharedPreferences.getInstance()).setString(_modeKey, value.name);
  }

  Future<void> setReduceMotion(bool value) async {
    state = state.copyWith(reduceMotion: value);
    await (await SharedPreferences.getInstance()).setBool(_motionKey, value);
  }
}
