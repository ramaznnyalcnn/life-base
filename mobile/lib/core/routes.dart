/// Route paths shared by the shell and modules.
///
/// Modules navigate by path only, so they never import one another.
abstract final class AppRoutes {
  static const today = '/today';
  static const wallet = '/wallet';
  static const calendar = '/calendar';
  static const meds = '/meds';
  static const notes = '/notes';
  static const account = '/account';

  /// Full-screen dose alarm: `/alarm/<doseId>`.
  static const alarm = '/alarm';
}
