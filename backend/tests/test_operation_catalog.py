from app.operations.catalog import build_operation_registry
from app.schemas import OperationFieldKind


EXPECTED_KEYS = {
    "finance.category.create",
    "finance.category.update",
    "finance.category.toggle",
    "finance.payment.schedule",
    "finance.payment.complete",
    "finance.payment.update",
    "finance.payment.cancel",
    "wallet.account.save",
    "wallet.account.archive",
    "wallet.transaction.save",
    "wallet.transaction.delete",
    "wallet.transfer.save",
    "wallet.transfer.delete",
    "wallet.statement.mark",
    "wallet.payment.save",
    "wallet.payment.delete",
    "wallet.payment.complete",
    "planning.task.create",
    "planning.task.complete",
    "planning.task.update",
    "planning.task.reopen",
    "planning.task.delete",
    "planning.event.create",
    "planning.event.update",
    "planning.event.complete",
    "planning.event.reopen",
    "planning.event.delete",
    "planning.routine.create",
    "planning.routine.update",
    "planning.routine.toggle",
    "planning.routine.delete",
    "health.medication.create",
    "health.medication.update",
    "health.medication.toggle",
    "health.medication.schedule",
    "health.medication.take",
    "health.medication.snooze",
    "health.medication.undo_take",
}


def test_catalog_exposes_every_supported_class_based_operation():
    definitions = build_operation_registry().definitions()

    assert {definition.key for definition in definitions} == EXPECTED_KEYS
    assert all(definition.version == 1 for definition in definitions)


def test_catalog_is_selection_first_and_money_is_numeric():
    definitions = {item.key: item for item in build_operation_registry().definitions()}

    task_fields = {field.key: field for field in definitions["planning.task.create"].fields}
    assert task_fields["template_id"].kind == OperationFieldKind.CHOICE
    assert task_fields["template_id"].option_source == "activity_templates.task"
    assert task_fields["custom_title"].max_length == 160

    payment_fields = {field.key: field for field in definitions["finance.payment.schedule"].fields}
    assert payment_fields["source_account_id"].kind == OperationFieldKind.CHOICE
    assert payment_fields["amount"].kind == OperationFieldKind.MONEY
