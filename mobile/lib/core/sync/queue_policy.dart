enum QueueDecision { retry, pause, resolveConflict, drop }

abstract final class QueuePolicy {
  static QueueDecision forStatus(int? statusCode) {
    if (statusCode == null || statusCode >= 500) return QueueDecision.retry;
    if (statusCode == 401) return QueueDecision.pause;
    if (statusCode == 409) return QueueDecision.resolveConflict;
    return QueueDecision.drop;
  }

  static List<String> contiguousPending(Iterable<String> states) {
    final outstanding = states.where((state) => state != 'done');
    return outstanding.takeWhile((state) => state == 'pending').toList();
  }
}
