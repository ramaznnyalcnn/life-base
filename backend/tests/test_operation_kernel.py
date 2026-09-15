from pydantic import BaseModel
import pytest

from app.operations import OperationHandler, OperationRegistry
from app.schemas import OperationDefinition, OperationFieldDefinition, OperationFieldKind


class ExampleInput(BaseModel):
    amount: str


class ExampleOperation(OperationHandler[ExampleInput]):
    key = "finance.expense.record"
    input_model = ExampleInput
    definition = OperationDefinition(
        key=key,
        group="finance",
        label="Harcama",
        version=1,
        fields=[
            OperationFieldDefinition(
                key="amount",
                label="Tutar",
                kind=OperationFieldKind.MONEY,
                required=True,
            )
        ],
    )

    def execute(self, context, payload):
        raise NotImplementedError


def test_registry_returns_handlers_and_sorted_catalog_definitions():
    handler = ExampleOperation()
    registry = OperationRegistry([handler])

    assert registry.get("finance.expense.record") is handler
    assert [definition.key for definition in registry.definitions()] == ["finance.expense.record"]


def test_registry_rejects_duplicate_operation_keys():
    with pytest.raises(ValueError, match="Duplicate operation key: finance.expense.record"):
        OperationRegistry([ExampleOperation(), ExampleOperation()])
