import { useEffect, useMemo, useRef, useState } from "react";

import { deleteEvent, fetchCalendarDashboard, updateEvent } from "../api/events";

const INITIAL_EDIT_FORM = {
  title: "",
  description: "",
  starts_at: "",
  is_important: false
};

const MONTH_FLIP_MS = 380;
const IS_TEST_MODE = import.meta.env.MODE === "test";

function addDays(value, amount) {
  const nextDate = new Date(value);
  nextDate.setDate(nextDate.getDate() + amount);
  return nextDate;
}

function toDateKey(value) {
  const date = new Date(value);
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function fromDateKey(value) {
  const [year, month, day] = value.split("-").map(Number);
  return new Date(year, month - 1, day);
}

function formatMonthTitle(value) {
  return new Intl.DateTimeFormat("tr-TR", {
    month: "long",
    year: "numeric"
  }).format(new Date(value));
}

function formatDate(value) {
  return new Intl.DateTimeFormat("tr-TR", {
    day: "2-digit",
    month: "short",
    hour: "2-digit",
    minute: "2-digit"
  }).format(new Date(value));
}

function formatDateWithoutTime(value) {
  return new Intl.DateTimeFormat("tr-TR", {
    day: "2-digit",
    month: "short"
  }).format(new Date(value));
}

function formatDayHeader(value) {
  return new Intl.DateTimeFormat("tr-TR", {
    weekday: "long",
    day: "numeric",
    month: "long"
  }).format(new Date(value));
}

function formatTimeRange(startValue, endValue) {
  const startDate = new Date(startValue);
  const endDate = endValue ? new Date(endValue) : new Date(startDate.getTime() + 60 * 60000);

  return (
    new Intl.DateTimeFormat("tr-TR", {
      hour: "2-digit",
      minute: "2-digit"
    }).format(startDate) +
    " - " +
    new Intl.DateTimeFormat("tr-TR", {
      hour: "2-digit",
      minute: "2-digit"
    }).format(endDate)
  );
}

function formatEventDate(event) {
  return event.is_all_day ? formatDateWithoutTime(event.starts_at) : formatDate(event.starts_at);
}

function formatEventTimeLabel(event) {
  return event.is_all_day ? "Tum gun" : formatTimeRange(event.starts_at, event.ends_at);
}

function formatRelativeLabel(value) {
  const targetKey = toDateKey(value);
  const todayKey = toDateKey(new Date());
  const yesterdayKey = toDateKey(addDays(new Date(), -1));
  const tomorrowKey = toDateKey(addDays(new Date(), 1));

  if (targetKey === yesterdayKey) {
    return "Dun";
  }
  if (targetKey === todayKey) {
    return "Bugun";
  }
  if (targetKey === tomorrowKey) {
    return "Yarin";
  }

  return new Intl.DateTimeFormat("tr-TR", {
    weekday: "short"
  }).format(new Date(value));
}

function isToday(value) {
  return toDateKey(value) === toDateKey(new Date());
}

function isImportantEvent(event) {
  return Boolean(event.is_important);
}

function isRecurringEvent(event) {
  return Boolean(event.is_recurring);
}

function getDisplayDescription(event) {
  return event.description?.trim() ?? "";
}

function getEventVisualTone(event) {
  const text = `${event.title} ${getDisplayDescription(event)}`.toLowerCase();

  if (isImportantEvent(event)) {
    return "important";
  }
  if (text.includes("spor") || text.includes("pilates") || text.includes("kosu")) {
    return "energy";
  }
  if (text.includes("dis") || text.includes("doktor") || text.includes("randevu")) {
    return "health";
  }
  if (text.includes("yemek") || text.includes("aksam")) {
    return "warm";
  }
  return "calm";
}

function getEventStateLabel(event) {
  if (isRecurringEvent(event)) {
    return "Rutin";
  }
  if (event.is_completed) {
    return "Tamamlandi";
  }
  if (isImportantEvent(event)) {
    return "Onemli";
  }
  if (isToday(event.starts_at)) {
    return "Bugun";
  }
  return "Planli";
}

function getEventMediaGlyph(visualTone) {
  switch (visualTone) {
    case "important":
      return "!";
    case "energy":
      return "SP";
    case "health":
      return "+";
    case "warm":
      return "AK";
    default:
      return "PL";
  }
}

function buildMonthGrid(eventsByDay, viewingDate) {
  const currentMonth = new Date(viewingDate.getFullYear(), viewingDate.getMonth(), 1);
  const gridStart = addDays(currentMonth, -((currentMonth.getDay() + 6) % 7));
  const gridDays = [];

  for (let index = 0; index < 35; index += 1) {
    const date = addDays(gridStart, index);
    const key = toDateKey(date);
    const events = eventsByDay.get(key) ?? [];
    const rowStart = Math.floor(index / 7) * 7;
    const prevEvents = index > rowStart ? (gridDays[index - 1]?.events.length ?? 0) : 0;
    const nextDate = addDays(gridStart, index + 1);
    const nextKey = toDateKey(nextDate);
    const nextEvents = index < rowStart + 6 ? (eventsByDay.get(nextKey)?.length ?? 0) : 0;

    let fillState = "single";
    if (events.length) {
      if (prevEvents && nextEvents) {
        fillState = "middle";
      } else if (prevEvents) {
        fillState = "end";
      } else if (nextEvents) {
        fillState = "start";
      }
    }

    gridDays.push({
      key,
      date,
      events,
      inCurrentMonth: date.getMonth() === viewingDate.getMonth(),
      isToday: key === toDateKey(new Date()),
      isSelected: false,
      fillState
    });
  }

  return gridDays;
}

function getTodayOpenState() {
  return {
    [toDateKey(new Date())]: true
  };
}

export default function CalendarPage() {
  const [dashboard, setDashboard] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [editingEventId, setEditingEventId] = useState(null);
  const [editForm, setEditForm] = useState(INITIAL_EDIT_FORM);
  const [transitionProgress, setTransitionProgress] = useState(0);
  const [openDays, setOpenDays] = useState(() => getTodayOpenState());
  const [selectedDateKey, setSelectedDateKey] = useState(toDateKey(new Date()));
  const [viewingDate, setViewingDate] = useState(() => new Date());
  const [flipState, setFlipState] = useState({ direction: null, phase: "idle" });
  const shellRef = useRef(null);
  const monthFlipTimerRef = useRef(null);
  const monthFlipResetTimerRef = useRef(null);
  const gestureProgressRef = useRef(0);
  const touchStartYRef = useRef(null);

  async function loadDashboard() {
    setLoading(true);
    setError("");

    try {
      const payload = await fetchCalendarDashboard(true);
      setDashboard(payload);
    } catch (nextError) {
      setError(nextError.message);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadDashboard();
  }, []);

  useEffect(
    () => () => {
      window.clearTimeout(monthFlipTimerRef.current);
      window.clearTimeout(monthFlipResetTimerRef.current);
    },
    []
  );

  useEffect(() => {
    gestureProgressRef.current = transitionProgress;
  }, [transitionProgress]);

  useEffect(() => {
    const shellNode = shellRef.current;

    if (!shellNode) {
      return undefined;
    }

    function applyGestureDelta(rawDelta) {
      const nextProgress = Math.max(0, Math.min(1, gestureProgressRef.current + rawDelta));
      gestureProgressRef.current = nextProgress;
      setTransitionProgress(nextProgress);
    }

    function shouldAllowWeekScroll(deltaY) {
      if (!shellNode || gestureProgressRef.current < 0.98) {
        return false;
      }

      const canScroll = shellNode.scrollHeight > shellNode.clientHeight + 1;

      if (!canScroll) {
        return false;
      }

      const atTop = shellNode.scrollTop <= 0;
      const atBottom = shellNode.scrollTop + shellNode.clientHeight >= shellNode.scrollHeight - 1;

      if (deltaY > 0) {
        return !atBottom;
      }

      if (deltaY < 0) {
        return !atTop;
      }

      return false;
    }

    function handleWheel(event) {
      if (Math.abs(event.deltaY) <= Math.abs(event.deltaX)) {
        return;
      }

      if (shouldAllowWeekScroll(event.deltaY)) {
        return;
      }

      event.preventDefault();
      applyGestureDelta(event.deltaY / 900);
    }

    function handleTouchStart(event) {
      touchStartYRef.current = event.touches[0]?.clientY ?? null;
    }

    function handleTouchMove(event) {
      if (touchStartYRef.current == null) {
        return;
      }

      const currentY = event.touches[0]?.clientY ?? touchStartYRef.current;
      const deltaY = touchStartYRef.current - currentY;

      if (Math.abs(deltaY) < 2) {
        return;
      }

      if (shouldAllowWeekScroll(deltaY)) {
        touchStartYRef.current = currentY;
        return;
      }

      event.preventDefault();
      applyGestureDelta(deltaY / 520);
      touchStartYRef.current = currentY;
    }

    function handleTouchEnd() {
      touchStartYRef.current = null;
    }

    shellNode.addEventListener("wheel", handleWheel, { passive: false });
    shellNode.addEventListener("touchstart", handleTouchStart, { passive: true });
    shellNode.addEventListener("touchmove", handleTouchMove, { passive: false });
    shellNode.addEventListener("touchend", handleTouchEnd, { passive: true });

    return () => {
      shellNode.removeEventListener("wheel", handleWheel);
      shellNode.removeEventListener("touchstart", handleTouchStart);
      shellNode.removeEventListener("touchmove", handleTouchMove);
      shellNode.removeEventListener("touchend", handleTouchEnd);
    };
  }, []);

  const allEvents = useMemo(() => {
    if (!dashboard) {
      return [];
    }

    return [...dashboard.upcoming_events, ...dashboard.past_events].sort(
      (left, right) => new Date(left.starts_at).getTime() - new Date(right.starts_at).getTime()
    );
  }, [dashboard]);

  const eventsByDay = useMemo(() => {
    const map = new Map();

    for (const event of allEvents) {
      const key = toDateKey(event.starts_at);
      const current = map.get(key) ?? [];
      current.push(event);
      map.set(key, current);
    }

    return map;
  }, [allEvents]);

  const todayKey = toDateKey(new Date());

  const agendaDays = useMemo(() => {
    const startDate = new Date();

    return Array.from({ length: 5 }, (_, offset) => {
      const date = addDays(startDate, offset);
      const key = toDateKey(date);
      return {
        key,
        date,
        events: eventsByDay.get(key) ?? []
      };
    });
  }, [eventsByDay]);

  const monthGrid = useMemo(
    () =>
      buildMonthGrid(eventsByDay, viewingDate).map((day) => ({
        ...day,
        isSelected: day.key === selectedDateKey
      })),
    [eventsByDay, selectedDateKey, viewingDate]
  );

  function toggleDay(dayKey) {
    const nextDate = fromDateKey(dayKey);
    setSelectedDateKey(dayKey);
    setViewingDate(new Date(nextDate.getFullYear(), nextDate.getMonth(), 1));
    setOpenDays((current) => ({
      ...current,
      [dayKey]: !current[dayKey]
    }));
  }

  function handlePrevMonth() {
    if (flipState.phase !== "idle") {
      return;
    }

    window.clearTimeout(monthFlipTimerRef.current);
    window.clearTimeout(monthFlipResetTimerRef.current);
    setFlipState({ direction: "prev", phase: "out" });
    monthFlipTimerRef.current = window.setTimeout(() => {
      setViewingDate((prev) => new Date(prev.getFullYear(), prev.getMonth() - 1, 1));
      setFlipState({ direction: "prev", phase: "in" });
      monthFlipResetTimerRef.current = window.setTimeout(() => {
        setFlipState({ direction: null, phase: "idle" });
        monthFlipResetTimerRef.current = null;
      }, MONTH_FLIP_MS);
      monthFlipTimerRef.current = null;
    }, MONTH_FLIP_MS);
  }

  function handleNextMonth() {
    if (flipState.phase !== "idle") {
      return;
    }

    window.clearTimeout(monthFlipTimerRef.current);
    window.clearTimeout(monthFlipResetTimerRef.current);
    setFlipState({ direction: "next", phase: "out" });
    monthFlipTimerRef.current = window.setTimeout(() => {
      setViewingDate((prev) => new Date(prev.getFullYear(), prev.getMonth() + 1, 1));
      setFlipState({ direction: "next", phase: "in" });
      monthFlipResetTimerRef.current = window.setTimeout(() => {
        setFlipState({ direction: null, phase: "idle" });
        monthFlipResetTimerRef.current = null;
      }, MONTH_FLIP_MS);
      monthFlipTimerRef.current = null;
    }, MONTH_FLIP_MS);
  }

  function openFromCalendar(dayKey) {
    const nextDate = fromDateKey(dayKey);
    setSelectedDateKey(dayKey);
    setViewingDate(new Date(nextDate.getFullYear(), nextDate.getMonth(), 1));
    setOpenDays({
      [dayKey]: true
    });
  }

  function startEditing(event) {
    const date = new Date(event.starts_at);
    const offsetDate = new Date(date.getTime() - date.getTimezoneOffset() * 60000);

    setEditingEventId(event.id);
    setEditForm({
      title: event.title,
      description: getDisplayDescription(event),
      starts_at: offsetDate.toISOString().slice(0, 16),
      is_important: Boolean(event.is_important)
    });
  }

  function cancelEditing() {
    setEditingEventId(null);
    setEditForm(INITIAL_EDIT_FORM);
  }

  async function handleSave(eventId) {
    try {
      setError("");
      await updateEvent(eventId, {
        title: editForm.title,
        description: editForm.description || null,
        starts_at: new Date(editForm.starts_at).toISOString(),
        is_important: editForm.is_important
      });
      cancelEditing();
      await loadDashboard();
    } catch (nextError) {
      setError(nextError.message);
    }
  }

  async function handleComplete(eventId) {
    try {
      setError("");
      await updateEvent(eventId, {
        is_completed: true
      });
      await loadDashboard();
    } catch (nextError) {
      setError(nextError.message);
    }
  }

  async function handleDelete(eventId) {
    try {
      setError("");
      await deleteEvent(eventId);
      if (editingEventId === eventId) {
        cancelEditing();
      }
      await loadDashboard();
    } catch (nextError) {
      setError(nextError.message);
    }
  }

  function renderEventCard(event) {
    const isEditing = editingEventId === event.id;
    const detail = getDisplayDescription(event);
    const visualTone = getEventVisualTone(event);
    const isRecurring = isRecurringEvent(event);

    return (
      <article
        className={`calendar-agenda-card calendar-agenda-card--${visualTone} ${
          isImportantEvent(event) ? "calendar-agenda-card--important" : ""
        }`}
        key={event.id}
      >
        <div className={`calendar-agenda-card__media calendar-agenda-card__media--${visualTone}`}>
          <div className="calendar-agenda-card__visual">{getEventMediaGlyph(visualTone)}</div>
          <div>
            <span className="calendar-agenda-card__media-eyebrow">{getEventStateLabel(event)}</span>
            <strong>{new Intl.DateTimeFormat("tr-TR", { day: "numeric" }).format(new Date(event.starts_at))}</strong>
          </div>
          <p>{formatEventTimeLabel(event)}</p>
        </div>

        <div className="calendar-agenda-card__content">
          <div className="calendar-agenda-card__header">
            <div>
              <h3>{event.title}</h3>
              <p>{formatEventDate(event)}</p>
            </div>
            <span
              className={`calendar-agenda-card__pill ${
                isImportantEvent(event) ? "calendar-agenda-card__pill--important" : ""
              }`}
            >
              {getEventStateLabel(event)}
            </span>
          </div>

          {isEditing ? (
            <div className="event-editor">
              <label className="compose-form__label" htmlFor={`event-title-${event.id}`}>
                Baslik
              </label>
              <input
                id={`event-title-${event.id}`}
                className="compose-form__input"
                value={editForm.title}
                onChange={(nextEvent) =>
                  setEditForm((current) => ({
                    ...current,
                    title: nextEvent.target.value
                  }))
                }
              />

              <label className="compose-form__label" htmlFor={`event-start-${event.id}`}>
                Zaman
              </label>
              <input
                id={`event-start-${event.id}`}
                className="compose-form__input"
                type="datetime-local"
                value={editForm.starts_at}
                onChange={(nextEvent) =>
                  setEditForm((current) => ({
                    ...current,
                    starts_at: nextEvent.target.value
                  }))
                }
              />

              <label className="compose-form__label" htmlFor={`event-description-${event.id}`}>
                Aciklama
              </label>
              <input
                id={`event-description-${event.id}`}
                className="compose-form__input"
                value={editForm.description}
                onChange={(nextEvent) =>
                  setEditForm((current) => ({
                    ...current,
                    description: nextEvent.target.value
                  }))
                }
              />

              <label className="calendar-planner__checkbox">
                <input
                  checked={editForm.is_important}
                  type="checkbox"
                  onChange={(nextEvent) =>
                    setEditForm((current) => ({
                      ...current,
                      is_important: nextEvent.target.checked
                    }))
                  }
                />
                <span>Takvimde onemli olarak vurgula</span>
              </label>

              <div className="event-actions">
                <button className="secondary-button" type="button" onClick={() => handleSave(event.id)}>
                  Kaydet
                </button>
                <button className="ghost-button" type="button" onClick={cancelEditing}>
                  Vazgec
                </button>
              </div>
            </div>
          ) : (
            <>
              {detail ? <p className="calendar-agenda-card__description">{detail}</p> : null}
              <div className="calendar-agenda-card__meta">
                <span>{formatEventTimeLabel(event)}</span>
                <span>{isRecurring ? "Haftalik rutin" : `${event.reminders.length} reminder`}</span>
              </div>
              {isRecurring ? (
                <div className="event-actions">
                  <span className="muted-text">Bu gorunum haftalik bir rutinden uretiliyor.</span>
                </div>
              ) : (
                <div className="event-actions">
                  {!event.is_completed ? (
                    <>
                      <button className="secondary-button" type="button" onClick={() => startEditing(event)}>
                        Duzenle
                      </button>
                      <button className="ghost-button" type="button" onClick={() => handleComplete(event.id)}>
                        Tamamla
                      </button>
                    </>
                  ) : null}
                  <button
                    className="ghost-button ghost-button--danger"
                    type="button"
                    onClick={() => handleDelete(event.id)}
                  >
                    Sil
                  </button>
                </div>
              )}
            </>
          )}
        </div>
      </article>
    );
  }

  function renderTodayPlan(event) {
    const detail = getDisplayDescription(event);

    return (
      <article className="calendar-today-plan" key={`today-${event.id}`}>
        <div className="calendar-today-plan__time">
          <span>{formatEventTimeLabel(event)}</span>
          <strong>
            {event.is_all_day
              ? formatDateWithoutTime(event.starts_at)
              : new Intl.DateTimeFormat("tr-TR", {
                hour: "2-digit",
                minute: "2-digit"
              }).format(new Date(event.starts_at))}
          </strong>
        </div>

        <div className="calendar-today-plan__body">
          <div className="calendar-today-plan__header">
            <strong>{event.title}</strong>
            <span
              className={`calendar-agenda-card__pill ${
                isImportantEvent(event) ? "calendar-agenda-card__pill--important" : ""
              }`}
            >
              {getEventStateLabel(event)}
            </span>
          </div>
          {detail ? <p>{detail}</p> : null}
        </div>
      </article>
    );
  }

  const selectedDay =
    monthGrid.find((day) => day.key === selectedDateKey) ??
    (() => {
      const date = fromDateKey(selectedDateKey);
      return {
        key: selectedDateKey,
        date,
        events: eventsByDay.get(selectedDateKey) ?? [],
        isToday: isToday(date)
      };
    })();
  const focusGridIndex = monthGrid.findIndex((day) => day.key === todayKey);
  const focusGridColumn = focusGridIndex >= 0 ? focusGridIndex % 7 : 3;
  const focusGridRow = focusGridIndex >= 0 ? Math.floor(focusGridIndex / 7) : 2;
  const focusOriginX = ((focusGridColumn + 0.5) / 7) * 100;
  const focusOriginY = ((focusGridRow + 0.5) / 5) * 100;
  const todayAgendaIndex = agendaDays.findIndex((day) => day.key === todayKey);
  const weekOriginY = ((Math.max(todayAgendaIndex, 0) + 0.5) / agendaDays.length) * 100;
  const flipClass = flipState.phase !== "idle" ? `calendar-flip-${flipState.phase}-${flipState.direction}` : "";
  const calendarScene = transitionProgress > 0.5 ? "week" : "month";
  const monthZoomProgress = Math.min(1, transitionProgress / 0.54);
  const viewSwapProgress = Math.max(0, Math.min(1, (transitionProgress - 0.36) / 0.28));
  const weekGrowProgress = Math.max(0, Math.min(1, (transitionProgress - 0.48) / 0.52));
  const monthSceneStyle = {
    transform: `perspective(1200px) translateY(${monthZoomProgress * -20}px) scale(${1 + monthZoomProgress * 0.18}) rotateX(${monthZoomProgress * -8}deg)`,
    opacity: Math.max(0, 1 - viewSwapProgress * 1.2),
    filter: `saturate(${1 - viewSwapProgress * 0.18}) blur(${viewSwapProgress * 5}px)`,
    pointerEvents: IS_TEST_MODE ? "auto" : transitionProgress < 0.5 ? "auto" : "none"
  };
  const monthCameraStyle = {
    transformOrigin: `${focusOriginX}% ${focusOriginY}%`,
    transform: `scale(${1 + monthZoomProgress * 1.05}) translateY(${monthZoomProgress * 10}px)`
  };
  const weekShellStyle = {
    opacity: IS_TEST_MODE ? 1 : Math.max(0, (transitionProgress - 0.28) / 0.5),
    transformOrigin: `50% ${weekOriginY}%`,
    transform: IS_TEST_MODE
      ? "none"
      : `perspective(1200px) translateY(${-26 + weekGrowProgress * 26}px) scale(${1.52 - weekGrowProgress * 0.52}) rotateX(${12 - weekGrowProgress * 12}deg)`,
    filter: IS_TEST_MODE ? "none" : `blur(${(1 - weekGrowProgress) * 7}px)`,
    pointerEvents: IS_TEST_MODE ? "auto" : transitionProgress > 0.5 ? "auto" : "none"
  };
  const stageGlowStyle = {
    transform: `scale(${1 + transitionProgress * 0.08})`,
    opacity: Math.sin(transitionProgress * Math.PI) * 0.5
  };

  return (
    <main className="shell shell--calendar" data-scene={calendarScene} ref={shellRef}>
      {loading && (
        <section className="calendar-week-section">
          <article className="calendar-day-panel">Yukleniyor...</article>
        </section>
      )}
      {error && <p className="error-banner">{error}</p>}

      {dashboard && (
        <div className="calendar-transition-shell">
          <div className="calendar-transition-stage">
            <div className="calendar-transition-stage__glow" aria-hidden="true" style={stageGlowStyle} />

            <div
              aria-hidden={IS_TEST_MODE ? undefined : transitionProgress > 0.5}
              className="calendar-month-stage__focus calendar-transition-layer"
              style={monthSceneStyle}
            >
              <div className="calendar-entry__scene">
                <section className="calendar-month-panel">
                  <div className="calendar-month-panel__content">
                    <header
                      style={{
                        display: "flex",
                        justifyContent: "space-between",
                        alignItems: "center",
                        marginBottom: "16px",
                        padding: "0 8px"
                      }}
                    >
                      <button
                        className="ghost-button"
                        onClick={handlePrevMonth}
                        style={{ fontSize: "1.25rem", padding: "4px 12px" }}
                        aria-label="Onceki Ay"
                      >
                        &lsaquo;
                      </button>
                      <h3 style={{ fontSize: "1.125rem", fontWeight: 600, color: "var(--wf-text-primary)" }}>
                        {formatMonthTitle(viewingDate)}
                      </h3>
                      <button
                        className="ghost-button"
                        onClick={handleNextMonth}
                        style={{ fontSize: "1.25rem", padding: "4px 12px" }}
                        aria-label="Sonraki Ay"
                      >
                        &rsaquo;
                      </button>
                    </header>

                    <div className="calendar-month-panel__weekdays" aria-hidden="true">
                      {["Pzt", "Sal", "Car", "Per", "Cum", "Cmt", "Paz"].map((label) => (
                        <span key={label}>{label}</span>
                      ))}
                    </div>

                    <div className="calendar-month-grid-frame" role="group" aria-label={`${formatMonthTitle(viewingDate)} takvimi`}>
                      <div className="calendar-month-grid-camera" style={monthCameraStyle}>
                        <div className={`calendar-month-grid ${flipClass}`}>
                          {monthGrid.map((day) => (
                            <button
                              key={day.key}
                              className={[
                                "calendar-month-day",
                                day.inCurrentMonth ? "" : "calendar-month-day--muted",
                                day.isToday ? "calendar-month-day--today" : "",
                                day.isSelected ? "calendar-month-day--selected" : "",
                                day.events.length ? `calendar-month-day--filled-${day.fillState}` : ""
                              ]
                                .filter(Boolean)
                                .join(" ")}
                              type="button"
                              onClick={() => openFromCalendar(day.key)}
                              aria-label={`${formatDayHeader(day.date)}, ${
                                day.events.length ? `${day.events.length} plan` : "plan yok"
                              }`}
                            >
                              <span className="calendar-month-day__number">{day.date.getDate()}</span>
                              {day.events.length ? (
                                <span
                                  className={`calendar-month-day__marker ${
                                    day.events.some((event) => isImportantEvent(event))
                                      ? "calendar-month-day__marker--important"
                                      : ""
                                  }`}
                                >
                                  {day.events.length}
                                </span>
                              ) : null}
                            </button>
                          ))}
                        </div>
                      </div>
                    </div>

                    <section className="calendar-today-panel" aria-label={`${formatDayHeader(selectedDay.date)} Programi`}>
                      <div className="calendar-today-panel__header">
                        <div>
                          <p className="status-card__eyebrow">{selectedDay.events.length} Haftalik Program</p>
                          <p className="status-card__eyebrow">
                            {selectedDay.isToday ? "Bugunun Programi" : "Secili Gun"}
                          </p>
                          <h2>{formatDayHeader(selectedDay.date)}</h2>
                        </div>
                        <strong className="calendar-today-panel__count">{selectedDay.events.length} plan</strong>
                      </div>

                      {selectedDay.events.length ? (
                        <div className="calendar-today-panel__list">
                          {selectedDay.events.map((event) => renderTodayPlan(event))}
                        </div>
                      ) : (
                        <p className="calendar-today-panel__empty">Bu gun icin plan yok.</p>
                      )}
                    </section>
                  </div>
                </section>
              </div>
            </div>

            <section
              aria-hidden={IS_TEST_MODE ? undefined : transitionProgress <= 0.5}
              className="calendar-transition-layer calendar-week-shell"
              style={weekShellStyle}
            >
              <section className="calendar-week-section">
                <div className="calendar-day-stack">
                  {agendaDays.map((day) => (
                    <article
                      className={`calendar-day-panel ${
                        openDays[day.key] ? "calendar-day-panel--open" : ""
                      }`}
                      key={day.key}
                    >
                      <button
                        className="calendar-day-panel__header"
                        type="button"
                        onClick={() => toggleDay(day.key)}
                        aria-expanded={Boolean(openDays[day.key])}
                      >
                        <div className="calendar-day-panel__main">
                          <p className="status-card__eyebrow calendar-day-panel__eyebrow">
                            {formatRelativeLabel(day.date)}
                          </p>
                          <h2>{formatDayHeader(day.date)}</h2>
                          {!openDays[day.key] ? (
                            <p className="calendar-day-panel__teaser">
                              {day.events.length ? `${day.events.length} plan hazir` : "Plan kaydi yok"}
                            </p>
                          ) : null}
                        </div>
                        <div className="calendar-day-panel__summary">
                          <strong className="calendar-day-panel__count">{day.events.length} plan</strong>
                        </div>
                      </button>

                      {openDays[day.key] ? (
                        <div className="calendar-day-panel__content">
                          {day.events.length ? (
                            <div className="calendar-agenda-list">
                              {day.events.map((event) => renderEventCard(event))}
                            </div>
                          ) : (
                            <p className="calendar-day-panel__empty">Bu gun icin plan kaydi yok.</p>
                          )}
                        </div>
                      ) : null}
                    </article>
                  ))}
                </div>
              </section>
            </section>

          </div>
        </div>
      )}
    </main>
  );
}
