enum FieldKind { choice, money, date, datetime, time, duration, boolean, shortText }

class OperationField {
  const OperationField({
    required this.key,
    required this.label,
    required this.kind,
    required this.required,
    this.optionSource,
    this.minValue,
    this.maxValue,
    this.maxLength,
    this.multiple = false,
    this.visibleWhen,
  });

  final String key;
  final String label;
  final FieldKind kind;
  final bool required;
  final String? optionSource;
  final int? minValue;
  final int? maxValue;
  final int? maxLength;
  final bool multiple;
  final Map<String, Object?>? visibleWhen;

  factory OperationField.fromJson(Map<String, Object?> json) => OperationField(
        key: json['key']! as String,
        label: json['label']! as String,
        kind: FieldKind.values.byName(
          (json['kind']! as String).replaceAll('short_text', 'shortText'),
        ),
        required: json['required'] as bool? ?? true,
        optionSource: json['option_source'] as String?,
        minValue: json['min_value'] as int?,
        maxValue: json['max_value'] as int?,
        maxLength: json['max_length'] as int?,
        multiple: json['multiple'] as bool? ?? false,
        visibleWhen: json['visible_when'] == null
            ? null
            : Map<String, Object?>.from(json['visible_when']! as Map),
      );
}

class OperationDefinition {
  const OperationDefinition({
    required this.key,
    required this.group,
    required this.label,
    required this.fields,
  });

  final String key;
  final String group;
  final String label;
  final List<OperationField> fields;

  factory OperationDefinition.fromJson(Map<String, Object?> json) =>
      OperationDefinition(
        key: json['key']! as String,
        group: json['group']! as String,
        label: json['label']! as String,
        fields: (json['fields'] as List? ?? const [])
            .cast<Map>()
            .map((field) => OperationField.fromJson(
                  Map<String, Object?>.from(field),
                ))
            .toList(),
      );
}

class ChoiceOption {
  const ChoiceOption({required this.value, required this.label, this.enabled = true, this.metadata = const {}});

  final Object value;
  final String label;
  final bool enabled;
  final Map<String, Object?> metadata;

  factory ChoiceOption.fromJson(Map<String, Object?> json) => ChoiceOption(
        value: json['value']!,
        label: json['label']! as String,
        enabled: json['enabled'] as bool? ?? true,
        metadata: Map<String, Object?>.from(json['metadata'] as Map? ?? const {}),
      );
}

class OperationContextData {
  const OperationContextData({required this.version, required this.sources});

  final int version;
  final Map<String, List<ChoiceOption>> sources;

  factory OperationContextData.fromJson(Map<String, Object?> json) {
    final raw = Map<String, Object?>.from(json['sources']! as Map);
    return OperationContextData(
      version: json['agenda_version'] as int? ?? 0,
      sources: raw.map((key, value) => MapEntry(
            key,
            (value as List)
                .cast<Map>()
                .map((item) => ChoiceOption.fromJson(
                      Map<String, Object?>.from(item),
                    ))
                .toList(),
          )),
    );
  }
}
