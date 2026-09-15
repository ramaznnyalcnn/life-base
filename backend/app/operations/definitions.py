"""Helpers for concise operation catalog definitions."""

from app.schemas import OperationDefinition, OperationFieldDefinition, OperationFieldKind


def field(
    key: str,
    label: str,
    kind: OperationFieldKind,
    *,
    required: bool = True,
    source: str | None = None,
    max_length: int | None = None,
    min_value: int | None = None,
    max_value: int | None = None,
) -> OperationFieldDefinition:
    return OperationFieldDefinition(
        key=key,
        label=label,
        kind=kind,
        required=required,
        option_source=source,
        max_length=max_length,
        min_value=min_value,
        max_value=max_value,
    )


def definition(key: str, group: str, label: str, fields: list[OperationFieldDefinition]) -> OperationDefinition:
    return OperationDefinition(key=key, group=group, label=label, version=1, fields=fields)
