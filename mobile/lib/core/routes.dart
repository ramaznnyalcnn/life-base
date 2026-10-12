/// Route paths shared by the shell and modules.
///
/// Modules navigate by path only, so they never import one another.
abstract final class AppRoutes {
  static const today = '/today';

  /// A calendar event opened from Bugün, in Bugün's own stack; the
  /// occurrence goes as the route's `extra`.
  static const todayEvent = '/today/event';
  static const wallet = '/wallet';
  static const calendar = '/calendar';

  /// The calendar opened on [day].
  static String calendarOn(DateTime day) =>
      '$calendar?day=${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
  static const meds = '/meds';
  static const notes = '/notes';
  static const account = '/account';

  /// Full-screen dose alarm: `/alarm/<doseId>`.
  static const alarm = '/alarm';
}
