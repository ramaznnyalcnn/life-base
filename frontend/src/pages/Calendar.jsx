import { useEffect, useMemo, useRef, useState } from "react";

import { deleteEvent, fetchCalendarDashboard, updateEvent } from "../api/events";
import { buildMapEmbedUrl, fetchWeatherBundle, reverseGeocode } from "../api/weather";

const INITIAL_EDIT_FORM = {
  title: "",
  description: "",
  starts_at: "",
  is_important: false
};
const INITIAL_LOCATION_STATE = {
  status: "idle",
  placeLabel: "Mevcut Konum",
  current: null,
  forecastByDay: {},
  mapUrl: "",
  message: ""
};

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

function getWeatherMeta(code, isDay = 1) {
  if (code === 0) {
    return {
      icon: isDay ? "sun" : "moon",
      label: isDay ? "Gunesli" : "Acik Gece",
      short: isDay ? "Gunes" : "Acik"
    };
  }
  if ([1, 2, 3].includes(code)) {
    return {
      icon: "cloud",
      label: "Bulutlu",
      short: "Bulut"
    };
  }
  if ([45, 48].includes(code)) {
    return {
      icon: "fog",
      label: "Sisli",
      short: "Sis"
    };
  }
  if ([51, 53, 55, 56, 57, 61, 63, 65, 80, 81, 82].includes(code)) {
    return {
      icon: "rain",
      label: "Yagmurlu",
      short: "Yagmur"
    };
  }
  if ([66, 67, 71, 73, 75, 77, 85, 86].includes(code)) {
    return {
      icon: "snow",
      label: "Kar",
      short: "Kar"
    };
  }
  if ([95, 96, 99].includes(code)) {
    return {
      icon: "storm",
      label: "Firtina",
      short: "Firtina"
    };
  }

  return {
    icon: "cloud",
    label: "Degisken",
    short: "Degisken"
  };
}

function getFallbackWeatherSlot(value) {
  const variants = [
    { code: 0, temp: "21°", highLow: "24° / 16°" },
    { code: 3, temp: "18°", highLow: "20° / 15°" },
    { code: 61, temp: "16°", highLow: "18° / 13°" }
  ];

  const date = new Date(value);
  const variant = variants[(date.getDate() + date.getMonth()) % variants.length];
  const meta = getWeatherMeta(variant.code, 1);

  return {
    ...meta,
    ...variant
  };
}

function getWeatherSnapshot(value, forecastByDay) {
  return forecastByDay[toDateKey(value)] ?? getFallbackWeatherSlot(value);
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

function buildMonthGrid(eventsByDay, forecastByDay) {
  const today = new Date();
  const currentMonth = new Date(today.getFullYear(), today.getMonth(), 1);
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
      inCurrentMonth: date.getMonth() === today.getMonth(),
      isToday: key === toDateKey(today),
      isSelected: false,
      fillState,
      weather: getWeatherSnapshot(date, forecastByDay)
    });
  }

  return gridDays;
}

function getTodayOpenState() {
  return {
    [toDateKey(new Date())]: true
  };
}

function buildForecastByDay(payload) {
  const daily = payload.daily ?? {};
  const times = daily.time ?? [];
  const codes = daily.weather_code ?? [];
  const maxValues = daily.temperature_2m_max ?? [];
  const minValues = daily.temperature_2m_min ?? [];

  return times.reduce((accumulator, key, index) => {
    const code = codes[index] ?? 0;
    const meta = getWeatherMeta(code, 1);
    accumulator[key] = {
      ...meta,
      code,
      temp: `${Math.round(maxValues[index] ?? 0)}°`,
      highLow: `${Math.round(maxValues[index] ?? 0)}° / ${Math.round(minValues[index] ?? 0)}°`
    };
    return accumulator;
  }, {});
}

function buildPlaceLabel(payload, fallbackLabel) {
  const address = payload?.address ?? {};
  return (
    address.city ||
    address.town ||
    address.state ||
    address.county ||
    address.village ||
    fallbackLabel
  );
}

function WeatherIcon({ code, isDay = 1, className = "" }) {
  const { icon } = getWeatherMeta(code, isDay);

  return (
    <svg
      className={["weather-icon", className].filter(Boolean).join(" ")}
      viewBox="0 0 24 24"
      fill="none"
      aria-hidden="true"
    >
      {icon === "sun" ? (
        <>
          <circle cx="12" cy="12" r="4.2" fill="currentColor" />
          <path d="M12 2.5v3M12 18.5v3M21.5 12h-3M5.5 12h-3M18.72 5.28l-2.12 2.12M7.4 16.6l-2.12 2.12M18.72 18.72 16.6 16.6M7.4 7.4 5.28 5.28" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" />
        </>
      ) : null}
      {icon === "moon" ? <path d="M14.7 2.8a8.8 8.8 0 1 0 6.5 14.4 9.6 9.6 0 0 1-6.5-14.4Z" fill="currentColor" /> : null}
      {icon === "cloud" ? (
        <path d="M7 18h9.5a4 4 0 0 0 .3-8 5.8 5.8 0 0 0-11.2 1.7A3.5 3.5 0 0 0 7 18Z" fill="currentColor" />
      ) : null}
      {icon === "fog" ? (
        <>
          <path d="M7 11.5h10a3.4 3.4 0 0 0 .2-6.8 4.9 4.9 0 0 0-9.4 1.5A2.9 2.9 0 0 0 7 11.5Z" fill="currentColor" />
          <path d="M5 15.5h14M7 19h10" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" />
        </>
      ) : null}
      {icon === "rain" ? (
        <>
          <path d="M7 12h9.5a4 4 0 0 0 .3-8 5.8 5.8 0 0 0-11.2 1.7A3.5 3.5 0 0 0 7 12Z" fill="currentColor" />
          <path d="M9 14.5 7.9 18M13 14.5 11.9 19M17 14.5 15.9 18" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" />
        </>
      ) : null}
      {icon === "snow" ? (
        <>
          <path d="M7 11.5h9.5a4 4 0 0 0 .3-8 5.8 5.8 0 0 0-11.2 1.7A3.5 3.5 0 0 0 7 11.5Z" fill="currentColor" />
          <path d="m9.5 14.7 1.4 1.4m0-1.4-1.4 1.4m3.1-1.4 1.4 1.4m0-1.4-1.4 1.4m3.1-1.4 1.4 1.4m0-1.4-1.4 1.4" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round" />
        </>
      ) : null}
      {icon === "storm" ? (
        <>
          <path d="M7 11.5h9.5a4 4 0 0 0 .3-8 5.8 5.8 0 0 0-11.2 1.7A3.5 3.5 0 0 0 7 11.5Z" fill="currentColor" />
          <path d="m12 13-2 4h2.2L11 21l4-5h-2.4l1.3-3Z" fill="currentColor" />
        </>
      ) : null}
    </svg>
  );
}

export default function CalendarPage() {
  const [dashboard, setDashboard] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [editingEventId, setEditingEventId] = useState(null);
  const [editForm, setEditForm] = useState(INITIAL_EDIT_FORM);
  const [openDays, setOpenDays] = useState(() => getTodayOpenState());
  const [selectedDateKey, setSelectedDateKey] = useState(toDateKey(new Date()));
  const [locationState, setLocationState] = useState(INITIAL_LOCATION_STATE);
  const [entryProgress, setEntryProgress] = useState(0);
  const [weekEntryProgress, setWeekEntryProgress] = useState(0);
  const entryRef = useRef(null);
  const weekStageRef = useRef(null);

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

  useEffect(() => {
    let cancelled = false;

    async function resolveWeather(latitude, longitude) {
      const fallbackLabel = `${latitude.toFixed(2)}, ${longitude.toFixed(2)}`;
      const mapUrl = buildMapEmbedUrl(latitude, longitude);

      try {
        const [weatherResult, placeResult] = await Promise.allSettled([
          fetchWeatherBundle(latitude, longitude),
          reverseGeocode(latitude, longitude)
        ]);

        if (cancelled) {
          return;
        }

        if (weatherResult.status !== "fulfilled") {
          setLocationState({
            ...INITIAL_LOCATION_STATE,
            status: "error",
            placeLabel: fallbackLabel,
            mapUrl,
            message: "Hava durumu bilgisi su an alinamadi."
          });
          return;
        }

        const forecastByDay = buildForecastByDay(weatherResult.value);
        const currentMeta = getWeatherMeta(
          weatherResult.value.current?.weather_code ?? 0,
          weatherResult.value.current?.is_day ?? 1
        );

        setLocationState({
          status: "ready",
          placeLabel:
            placeResult.status === "fulfilled"
              ? buildPlaceLabel(placeResult.value, fallbackLabel)
              : fallbackLabel,
          current: {
            ...currentMeta,
            code: weatherResult.value.current?.weather_code ?? 0,
            isDay: weatherResult.value.current?.is_day ?? 1,
            temp: `${Math.round(weatherResult.value.current?.temperature_2m ?? 0)}°`,
            apparentTemp: `${Math.round(weatherResult.value.current?.apparent_temperature ?? 0)}°`,
            wind: `${Math.round(weatherResult.value.current?.wind_speed_10m ?? 0)} km/h`
          },
          forecastByDay,
          mapUrl,
          message: ""
        });
      } catch {
        if (!cancelled) {
          setLocationState({
            ...INITIAL_LOCATION_STATE,
            status: "error",
            message: "Konum servisleri su an yanit vermiyor."
          });
        }
      }
    }

    async function requestLocation() {
      if (!navigator.geolocation) {
        setLocationState({
          ...INITIAL_LOCATION_STATE,
          status: "unsupported",
          message: "Tarayici konum bilgisini desteklemiyor."
        });
        return;
      }

      if (!window.isSecureContext && !["localhost", "127.0.0.1"].includes(window.location.hostname)) {
        setLocationState({
          ...INITIAL_LOCATION_STATE,
          status: "error",
          message: "Konum icin HTTPS veya localhost uzerinden acman gerekiyor."
        });
        return;
      }

      setLocationState((current) => ({
        ...current,
        status: "locating",
        message: ""
      }));

      const attempt = (options) =>
        new Promise((resolve, reject) => {
          navigator.geolocation.getCurrentPosition(resolve, reject, options);
        });

      try {
        const position = await attempt({
          enableHighAccuracy: false,
          timeout: 18000,
          maximumAge: 900000
        }).catch(() =>
          attempt({
            enableHighAccuracy: true,
            timeout: 25000,
            maximumAge: 0
          })
        );

        if (!cancelled) {
          await resolveWeather(position.coords.latitude, position.coords.longitude);
        }
      } catch {
        if (!cancelled) {
          setLocationState({
            ...INITIAL_LOCATION_STATE,
            status: "error",
            message: "Konum alinamadi. Tarayici izinlerini ve baglantiyi kontrol et."
          });
        }
      }
    }

    requestLocation();

    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    function handleEntryScroll() {
      if (!entryRef.current) {
        return;
      }

      const rect = entryRef.current.getBoundingClientRect();
      const viewportHeight = window.innerHeight || 1;
      const total = Math.max(entryRef.current.offsetHeight - viewportHeight, 1);
      const scrolled = Math.min(Math.max(-rect.top, 0), total);
      setEntryProgress(scrolled / total);
    }

    handleEntryScroll();
    window.addEventListener("scroll", handleEntryScroll, { passive: true });
    window.addEventListener("resize", handleEntryScroll);

    return () => {
      window.removeEventListener("scroll", handleEntryScroll);
      window.removeEventListener("resize", handleEntryScroll);
    };
  }, []);

  useEffect(() => {
    function handleWeekStageScroll() {
      if (!weekStageRef.current) {
        return;
      }

      const rect = weekStageRef.current.getBoundingClientRect();
      const viewportHeight = window.innerHeight || 1;
      const visibleRange = Math.min(Math.max(viewportHeight - rect.top, 0), viewportHeight * 0.9);
      const nextProgress = Math.max(0, Math.min(1, visibleRange / (viewportHeight * 0.9)));
      setWeekEntryProgress(nextProgress);
    }

    handleWeekStageScroll();
    window.addEventListener("scroll", handleWeekStageScroll, { passive: true });
    window.addEventListener("resize", handleWeekStageScroll);

    return () => {
      window.removeEventListener("scroll", handleWeekStageScroll);
      window.removeEventListener("resize", handleWeekStageScroll);
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

  const agendaDays = useMemo(() => {
    const today = new Date();
    const offsets = [-1, 0, 1, 2, 3, 4, 5];

    return offsets.map((offset) => {
      const date = addDays(today, offset);
      const key = toDateKey(date);
      return {
        key,
        date,
        weather: getWeatherSnapshot(date, locationState.forecastByDay),
        events: eventsByDay.get(key) ?? []
      };
    });
  }, [eventsByDay, locationState.forecastByDay]);

  const monthGrid = useMemo(
    () =>
      buildMonthGrid(eventsByDay, locationState.forecastByDay).map((day) => ({
        ...day,
        isSelected: day.key === selectedDateKey
      })),
    [eventsByDay, locationState.forecastByDay, selectedDateKey]
  );

  function toggleDay(dayKey) {
    setSelectedDateKey(dayKey);
    setOpenDays((current) => ({
      ...current,
      [dayKey]: !current[dayKey]
    }));
  }

  function openFromCalendar(dayKey) {
    setSelectedDateKey(dayKey);
    setOpenDays((current) => ({
      ...current,
      [dayKey]: true
    }));
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

  function renderLocationPanel() {
    if (locationState.status === "locating" || locationState.status === "idle") {
      return <p className="muted-text">Konum aliniyor, hava durumu guncelleniyor...</p>;
    }

    if (locationState.status === "unsupported") {
      return <p className="muted-text">{locationState.message}</p>;
    }

    if (locationState.status === "error") {
      return (
        <div className="calendar-location-weather">
          <p className="muted-text">{locationState.message}</p>
          <button className="secondary-button" type="button" onClick={() => window.location.reload()}>
            Konumu Tekrar Dene
          </button>
        </div>
      );
    }

    return (
      <div className="calendar-location-weather">
        <div className="calendar-location-weather__header">
          <div className="calendar-location-weather__icon">
            <WeatherIcon code={locationState.current.code} isDay={locationState.current.isDay} className="weather-icon--large" />
          </div>
          <div>
            <p className="status-card__eyebrow">Konum ve Hava</p>
            <h2>{locationState.placeLabel}</h2>
            <p className="muted-text">
              {locationState.current.label} · Hissedilen {locationState.current.apparentTemp}
            </p>
          </div>
        </div>

        <div className="calendar-location-weather__stats">
          <article>
            <span>Sicaklik</span>
            <strong>{locationState.current.temp}</strong>
          </article>
          <article>
            <span>Ruzgar</span>
            <strong>{locationState.current.wind}</strong>
          </article>
          <article>
            <span>{formatRelativeLabel(selectedDay?.date ?? new Date())}</span>
            <strong>{selectedWeather.highLow ?? "-"}</strong>
          </article>
        </div>
      </div>
    );
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

  function renderTodaySpotlight(event) {
    const detail = getDisplayDescription(event);

    return (
      <article className="calendar-entry__spotlight-card" key={`today-${event.id}`}>
        <div className="calendar-entry__spotlight-time">
          <span>{formatEventTimeLabel(event)}</span>
          <strong>
            {event.is_all_day
              ? formatDateWithoutTime(event.starts_at)
              : new Intl.DateTimeFormat("tr-TR", { hour: "2-digit", minute: "2-digit" }).format(new Date(event.starts_at))}
          </strong>
        </div>

        <div className="calendar-entry__spotlight-body">
          <div className="calendar-entry__spotlight-header">
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

  const selectedDay = monthGrid.find((day) => day.key === selectedDateKey) ?? monthGrid.find((day) => day.isToday) ?? monthGrid[0];
  const selectedWeather = selectedDay?.weather ?? getWeatherSnapshot(new Date(), locationState.forecastByDay);
  const selectedEvents = selectedDay?.events ?? [];
  const focusGridIndex = monthGrid.findIndex((day) => day.key === selectedDay?.key);
  const monthGridRows = Math.max(1, Math.ceil(monthGrid.length / 7));
  const focusGridColumn = focusGridIndex >= 0 ? focusGridIndex % 7 : 3;
  const focusGridRow = focusGridIndex >= 0 ? Math.floor(focusGridIndex / 7) : Math.floor(monthGridRows / 2);
  const focusOriginX = ((focusGridColumn + 0.5) / 7) * 100;
  const focusOriginY = ((focusGridRow + 0.5) / monthGridRows) * 100;
  const entryZoomProgress = Math.min(1, entryProgress / 0.92);
  const zoomBlackoutProgress = Math.min(1, Math.max(0, (entryZoomProgress - 0.22) / 0.58));
  const entrySceneStyle = {
    transform: `translateY(${entryZoomProgress * -42}px) scale(${1 - entryZoomProgress * 0.04})`,
    opacity: Math.max(0.05, 1 - entryZoomProgress * 0.95)
  };
  const calendarCameraStyle = {
    transformOrigin: `${focusOriginX}% ${focusOriginY}%`,
    transform: `translateY(${entryZoomProgress * 72}px) scale(${1 + entryZoomProgress * 4.4})`
  };
  const monthGridStyle = {
    transformOrigin: `${focusOriginX}% ${focusOriginY}%`,
    transform: `scale(${1 + entryZoomProgress * 0.12})`
  };
  const monthBlackoutStyle = {
    opacity: Math.min(1, 0.06 + zoomBlackoutProgress * 0.94)
  };
  const weekShellStyle = {
    opacity: Math.min(1, 0.08 + weekEntryProgress * 0.92),
    transform: `translateY(${132 - weekEntryProgress * 132}px) scale(${0.78 + weekEntryProgress * 0.22})`
  };

  return (
    <main className="shell">
      {loading ? (
        <section className="calendar-week-section">
          <article className="calendar-day-panel">Yukleniyor...</article>
        </section>
      ) : null}
      {error ? <p className="error-banner">{error}</p> : null}

      {dashboard ? (
        <>
          <section className="calendar-entry" ref={entryRef}>
            <div className="calendar-entry__sticky">
              <div className="calendar-entry__stage">
                <div className="calendar-entry__scene" style={entrySceneStyle}>
                  <section className="calendar-month-panel">
                    <div className="calendar-month-panel__content">
                      <div className="calendar-entry__zoom-blackout" style={monthBlackoutStyle} aria-hidden="true" />
                      <div className="calendar-month-panel__header">
                        <div>
                          <p className="status-card__eyebrow">Aylik Takvim</p>
                          <h1>{formatMonthTitle(new Date())}</h1>
                          <p className="calendar-month-panel__subhead">{formatDayHeader(selectedDay?.date ?? new Date())}</p>
                        </div>
                        <div className="calendar-month-panel__summary">
                          <span>{dashboard.upcoming_events.length} planli etkinlik</span>
                          <span>{dashboard.pending_reminders.length} aktif reminder</span>
                        </div>
                      </div>

                      <div className="calendar-entry__lead">
                        <span className="calendar-entry__lead-label">Secili Gunun Odagi</span>
                        <strong>{selectedWeather.label ?? "Takvim"} · {selectedWeather.temp ?? "-"}</strong>
                      </div>

                      <div className="calendar-month-panel__weekdays" aria-hidden="true">
                        {["Pzt", "Sal", "Car", "Per", "Cum", "Cmt", "Paz"].map((label) => (
                          <span key={label}>{label}</span>
                        ))}
                      </div>

                      <div className="calendar-month-grid-frame">
                        <div className="calendar-month-grid-camera" style={calendarCameraStyle}>
                          <div className="calendar-month-grid" style={monthGridStyle}>
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
                                <span className="calendar-month-day__weather">
                                  <WeatherIcon code={day.weather.code} className="weather-icon--tiny" />
                                  {day.weather.temp}
                                </span>
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
                    </div>
                    <section className="calendar-entry__today-block">
                      <article className="calendar-entry__today-shell">
                        <div className="calendar-entry__today-header">
                          <div>
                            <p className="status-card__eyebrow">Secili Gunun Yapilacaklari</p>
                            <h2>{formatDayHeader(selectedDay?.date ?? new Date())}</h2>
                          </div>
                          <div className="calendar-entry__today-weather">
                            <WeatherIcon
                              code={selectedWeather.code ?? 0}
                              className="weather-icon--small"
                            />
                            <strong>{selectedWeather.temp ?? "-"}</strong>
                          </div>
                        </div>

                        <div className="calendar-entry__today-kicker">
                          <span>Secili Gunun Programi</span>
                          <strong>{selectedEvents.length} kayit</strong>
                        </div>

                        {selectedEvents.length ? (
                          <div className="calendar-entry__today-list">
                            {selectedEvents.map((event) => renderTodaySpotlight(event))}
                          </div>
                        ) : (
                          <div className="calendar-entry__today-empty">
                            <strong>Secili gun icin plan yok</strong>
                          </div>
                        )}
                      </article>
                    </section>
                  </section>
                </div>
              </div>
            </div>
          </section>

          <section className="calendar-week-shell" ref={weekStageRef} style={weekShellStyle}>
            <section className="calendar-week-section">
              <div className="accounts-panel__header">
                <div>
                  <p className="status-card__eyebrow">1 Haftalik Program</p>
                  <p className="accounts-panel__meta">Dun, bugun ve sonraki 5 gun</p>
                </div>
              </div>

              <div className="calendar-day-stack">
                {agendaDays.map((day) => (
                  <article
                    className={`calendar-day-panel ${openDays[day.key] ? "calendar-day-panel--open" : ""}`}
                    key={day.key}
                  >
                    <button
                      className="calendar-day-panel__header"
                      type="button"
                      onClick={() => toggleDay(day.key)}
                      aria-expanded={Boolean(openDays[day.key])}
                    >
                      <div className="calendar-day-panel__main">
                        <p className="status-card__eyebrow calendar-day-panel__eyebrow">{formatRelativeLabel(day.date)}</p>
                        <h2>{formatDayHeader(day.date)}</h2>
                        {!openDays[day.key] ? (
                          <p className="calendar-day-panel__teaser">
                            {day.events.length ? `${day.events.length} plan hazir` : "Plan kaydi yok"}
                          </p>
                        ) : null}
                      </div>
                      <div className="calendar-day-panel__summary">
                        <div className="calendar-day-panel__weather">
                          <WeatherIcon code={day.weather.code} className="weather-icon--small" />
                          <div className="calendar-day-panel__weather-copy">
                            <span>{day.weather.short}</span>
                            <small>{day.weather.highLow}</small>
                          </div>
                        </div>
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

          <section className="calendar-location-panel">
            <div className="accounts-panel__header">
              <div>
                <p className="status-card__eyebrow">Secili Gunun Havasi</p>
                <p className="accounts-panel__meta">
                  {selectedWeather.label ?? "Durum"} · {selectedWeather.temp ?? "-"}
                </p>
              </div>
            </div>

            <div className="calendar-location-panel__grid">
              {renderLocationPanel()}
              <article className="calendar-location-map">
                <p className="calendar-alert-card__eyebrow">Harita</p>
                {locationState.mapUrl ? (
                  <iframe
                    className="calendar-location-map__frame"
                    src={locationState.mapUrl}
                    loading="lazy"
                    title="Mevcut konum haritasi"
                  />
                ) : (
                  <p className="muted-text">Konum izin verdiginde burada harita acilir.</p>
                )}
              </article>
            </div>
          </section>

        </>
      ) : null}
    </main>
  );
}
