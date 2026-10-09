import 'package:flutter_test/flutter_test.dart';
import 'package:lifebase_mobile/core/sync/queue_policy.dart';

void main() {
  test('401 pauses the queue until authentication is repaired', () {
    expect(QueuePolicy.forStatus(401), QueueDecision.pause);
  });

  test('409 requires a user conflict decision', () {
    expect(QueuePolicy.forStatus(409), QueueDecision.resolveConflict);
  });

  test('network and server errors retry while validation errors drop', () {
    expect(QueuePolicy.forStatus(null), QueueDecision.retry);
    expect(QueuePolicy.forStatus(503), QueueDecision.retry);
    expect(QueuePolicy.forStatus(422), QueueDecision.drop);
  });

  test('FIFO batch stops permanently at the first blocked operation', () {
    expect(
      QueuePolicy.contiguousPending(['done', 'pending', 'conflict', 'pending']),
      ['pending'],
    );
    expect(
      QueuePolicy.contiguousPending(['done', 'failed', 'pending']),
      isEmpty,
    );
  });
}
