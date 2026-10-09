import 'package:flutter_test/flutter_test.dart';
import 'package:lifebase_mobile/core/models/operation.dart';

void main() {
  test('operation envelope keeps UUID and structured values', () {
    final operation = OperationEnvelope(
      requestId: '9c3626bd-f676-49ea-a65e-85ca31adb0ed',
      operationKey: 'finance.expense.record',
      values: const {'account_id': 3, 'amount': '42.50'},
    );

    expect(operation.toApiJson(), {
      'request_id': operation.requestId,
      'operation_key': operation.operationKey,
      'account_id': 3,
      'amount': '42.50',
    });
  });
}
