from datetime import datetime, timezone
from typing import Literal
from uuid import UUID

from pydantic import BaseModel
import pytest
from sqlalchemy import func, select

from app.models import AgendaRevision, OperationExecution, Task
from app.operations import HandlerResult, OperationContext, OperationHandler, OperationRegistry
from app.operations.executor import OperationConflictError, OperationExecutor
from app.schemas import EntityRef, OperationDefinition
from app.services.auth import ensure_default_user


class TaskInput(BaseModel):
    request_id: UUID
    operation_key: Literal["planning.task.create"] = "planning.task.create"
    title: str


class TaskOperation(OperationHandler[TaskInput]):
    key = "planning.task.create"
    input_model = TaskInput
    definition = OperationDefinition(key=key, group="planning", label="Gorev", version=1)

    def execute(self, context: OperationContext, payload: TaskInput) -> HandlerResult:
        task = Task(
            user_id=context.user_id,
            device_id=context.device_id,
            title=payload.title,
            due_on=context.now.date(),
        )
        context.session.add(task)
        context.session.flush()
        return HandlerResult(entities=[EntityRef(kind="task", id=task.id)], affects_agenda=True)


class FailingTaskOperation(TaskOperation):
    def execute(self, context: OperationContext, payload: TaskInput) -> HandlerResult:
        super().execute(context, payload)
        raise ValueError("operation failed")


def test_executor_is_idempotent_and_increments_agenda_once(db_session):
    owner = ensure_default_user(db_session)
    executor = OperationExecutor(OperationRegistry([TaskOperation()]))
    payload = TaskInput(
        request_id="d28b2bbf-128f-4d46-bde8-987db4f190bc",
        title="Market",
    )

    first = executor.execute(
        db_session,
        payload,
        user_id=owner.id,
        device_id="android-1",
        now=datetime(2026, 9, 15, 9, 0, tzinfo=timezone.utc),
    )
    second = executor.execute(
        db_session,
        payload,
        user_id=owner.id,
        device_id="android-1",
        now=datetime(2026, 9, 15, 9, 1, tzinfo=timezone.utc),
    )

    assert first.replayed is False
    assert second.replayed is True
    assert first.entities == second.entities
    assert first.agenda_version == second.agenda_version == 1
    assert db_session.scalar(select(func.count(Task.id))) == 1
    assert db_session.scalar(select(func.count(OperationExecution.id))) == 1
    assert db_session.get(AgendaRevision, owner.id).version == 1


def test_executor_rejects_request_id_reuse_with_changed_payload(db_session):
    owner = ensure_default_user(db_session)
    executor = OperationExecutor(OperationRegistry([TaskOperation()]))
    request_id = "7f1f091b-11ee-4c80-9354-772b534ac968"
    executor.execute(db_session, TaskInput(request_id=request_id, title="Market"), user_id=owner.id)

    with pytest.raises(OperationConflictError, match="request_id"):
        executor.execute(db_session, TaskInput(request_id=request_id, title="Spor"), user_id=owner.id)

    assert db_session.scalar(select(func.count(Task.id))) == 1


def test_executor_rolls_back_domain_changes_and_journal_together(db_session):
    owner = ensure_default_user(db_session)
    executor = OperationExecutor(OperationRegistry([FailingTaskOperation()]))

    with pytest.raises(ValueError, match="operation failed"):
        executor.execute(
            db_session,
            TaskInput(request_id="ae629dfa-af00-439e-9086-57cbff31d093", title="Market"),
            user_id=owner.id,
        )

    assert db_session.scalar(select(func.count(Task.id))) == 0
    assert db_session.scalar(select(func.count(OperationExecution.id))) == 0
    assert db_session.get(AgendaRevision, owner.id) is None
