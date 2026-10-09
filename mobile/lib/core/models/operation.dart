import 'dart:convert';

class OperationEnvelope {
  const OperationEnvelope({
    required this.requestId,
    required this.operationKey,
    required this.values,
  });

  final String requestId;
  final String operationKey;
  final Map<String, Object?> values;

  Map<String, Object?> toApiJson() => <String, Object?>{
        'request_id': requestId,
        'operation_key': operationKey,
        ...values,
      };

  String encode() => jsonEncode(toApiJson());

  factory OperationEnvelope.decode(String source) {
    final json = jsonDecode(source) as Map<String, Object?>;
    final values = Map<String, Object?>.from(json)
      ..remove('request_id')
      ..remove('operation_key');
    return OperationEnvelope(
      requestId: json['request_id']! as String,
      operationKey: json['operation_key']! as String,
      values: values,
    );
  }
}
