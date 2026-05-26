import { useCallback, useEffect, useMemo, useState } from "react";
import { Alert, Pressable, ScrollView, StyleSheet, Text, View } from "react-native";

import type { ApiContext } from "../api/client";
import { deleteEvent, fetchCalendarDashboard, updateEvent } from "../api/events";
import {
  fetchMedicationDashboard,
  markMedicationDoseTaken,
  snoozeMedicationDose,
  updateMedication
} from "../api/medications";
import type { CalendarDashboard, EventItem, Medication, MedicationDashboard, MedicationDoseItem } from "../api/types";
import { Button, Card, Field, Header, LoadingBlock, SegmentedControl, StatusMessage } from "../components/ui";
import type { Palette } from "../components/ui";
import { formatDateTime, getEventStateLabel, parseDateTimeLocalInput, toDateTimeLocal } from "../utils/format";

type Props = {
  palette: Palette;
  api: ApiContext;
  refreshKey: number;
  onChanged: () => void;
  onSyncNotifications: () => Promise<void>;
};

type EditForm = {
  title: string;
  description: string;
  startsAt: string;
  important: "yes" | "no";
  completed: "yes" | "no";
};

type MedicationEditForm = {
  name: string;
  dosage: string;
  instructions: string;
  scheduleMode: "weekdays" | "interval";
  weekdays: number[];
  intervalDays: string;
  doseTimes: string;
  startsOn: string;
  endsOn: string;
  active: "yes" | "no";
};

type EventVisualTone = "important" | "health" | "energy" | "warm" | "calm";

type AgendaDay = {
  key: string;
  date: Date;
  events: EventItem[];
};

const WEEKDAYS = ["Pzt", "Sal", "Car", "Per", "Cum", "Cmt", "Paz"];
const TIME_PATTERN = /^([01]\d|2[0-3]):[0-5]\d$/;

function addDays(value: Date, amount: number): Date {
  const next = new Date(value);
  next.setDate(next.getDate() + amount);
  return next;
}

function toDateKey(value: string | Date): string {
  const date = new Date(value);
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function fromDateKey(value: string): Date {
  const [yearText, monthText, dayText] = value.split("-");
  return new Date(Number(yearText), Number(monthText) - 1, Number(dayText));
}

function formatMonthTitle(value: Date): string {
  return new Intl.DateTimeFormat("tr-TR", {
    month: "long",
    year: "numeric"
  }).format(value);
}

function formatDayHeader(value: Date): string {
  return new Intl.DateTimeFormat("tr-TR", {
    weekday: "long",
    day: "numeric",
    month: "long"
  }).format(value);
}

function formatRelativeLabel(value: Date): string {
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
  }).format(value);
}

function formatTime(value: Date): string {
  return new Intl.DateTimeFormat("tr-TR", {
    hour: "2-digit",
    minute: "2-digit"
  }).format(value);
}

function formatEventTimeLabel(event: EventItem): string {
  if (event.is_all_day) {
    return "Tum gun";
  }

  const startDate = new Date(event.starts_at);
  const endDate = event.ends_at ? new Date(event.ends_at) : new Date(startDate.getTime() + 60 * 60000);
  return `${formatTime(startDate)} - ${formatTime(endDate)}`;
}

function formatEventDateLabel(event: EventItem): string {
  return new Intl.DateTimeFormat("tr-TR", {
    weekday: "short",
    day: "numeric",
    month: "short"
  }).format(new Date(event.starts_at));
}

function buildMonthDays(viewingDate: Date): Date[] {
  const currentMonth = new Date(viewingDate.getFullYear(), viewingDate.getMonth(), 1);
  const startOffset = (currentMonth.getDay() + 6) % 7;
  const gridStart = addDays(currentMonth, -startOffset);
  return Array.from({ length: 35 }, (_, index) => addDays(gridStart, index));
}

function buildAgendaDays(eventsByDay: Map<string, EventItem[]>): AgendaDay[] {
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
}

function toEditForm(event: EventItem): EditForm {
  return {
    title: event.title,
    description: event.description ?? "",
    startsAt: toDateTimeLocal(event.starts_at),
    important: event.is_important ? "yes" : "no",
    completed: event.is_completed ? "yes" : "no"
  };
}

function toMedicationEditForm(medication: Medication): MedicationEditForm {
  return {
    name: medication.name,
    dosage: medication.dosage,
    instructions: medication.instructions ?? "",
    scheduleMode: medication.schedule_mode,
    weekdays: medication.weekdays,
    intervalDays: String(medication.interval_days ?? 2),
    doseTimes: medication.dose_times.join(", "),
    startsOn: medication.starts_on,
    endsOn: medication.ends_on ?? "",
    active: medication.is_active ? "yes" : "no"
  };
}

function parseDoseTimes(value: string): string[] {
  const times = value
    .split(/[,\s]+/)
    .map((part) => part.trim())
    .filter(Boolean);
  const invalid = times.find((part) => !TIME_PATTERN.test(part));

  if (invalid) {
    throw new Error("Saatler HH:MM formatinda olmali.");
  }

  return Array.from(new Set(times)).sort();
}

function getTodayOpenState(): Record<string, boolean> {
  return {
    [toDateKey(new Date())]: true
  };
}

function getDisplayDescription(event: EventItem): string {
  return event.description?.trim() ?? "";
}

function normalizeSearchText(value: string): string {
  return value
    .toLocaleLowerCase("tr-TR")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/\u0131/g, "i")
    .replace(/\u015f/g, "s")
    .replace(/\u011f/g, "g")
    .replace(/\u00e7/g, "c")
    .replace(/\u00f6/g, "o")
    .replace(/\u00fc/g, "u");
}

function getEventVisualTone(event: EventItem): EventVisualTone {
  const text = normalizeSearchText(`${event.title} ${getDisplayDescription(event)}`);

  if (event.is_important) {
    return "important";
  }
  if (text.includes("doktor") || text.includes("dis") || text.includes("randevu")) {
    return "health";
  }
  if (text.includes("spor") || text.includes("kosu") || text.includes("pilates")) {
    return "energy";
  }
  if (text.includes("yemek") || text.includes("aksam")) {
    return "warm";
  }
  return "calm";
}

function getEventMediaGlyph(visualTone: EventVisualTone): string {
  switch (visualTone) {
    case "important":
      return "!";
    case "health":
      return "+";
    case "energy":
      return "SP";
    case "warm":
      return "AK";
    default:
      return "PL";
  }
}

function getToneColors(palette: Palette, visualTone: EventVisualTone) {
  const dark = palette.mode === "dark";

  switch (visualTone) {
    case "important":
      return {
        accent: palette.negative,
        background: dark ? "rgba(239,68,68,0.14)" : "rgba(220,38,38,0.08)",
        border: dark ? "rgba(239,68,68,0.42)" : "rgba(220,38,38,0.28)"
      };
    case "health":
      return {
        accent: palette.positive,
        background: dark ? "rgba(16,185,129,0.14)" : "rgba(5,150,105,0.08)",
        border: dark ? "rgba(16,185,129,0.38)" : "rgba(5,150,105,0.22)"
      };
    case "energy":
      return {
        accent: "#2563eb",
        background: dark ? "rgba(37,99,235,0.16)" : "rgba(37,99,235,0.08)",
        border: dark ? "rgba(96,165,250,0.38)" : "rgba(37,99,235,0.22)"
      };
    case "warm":
      return {
        accent: palette.warning,
        background: dark ? "rgba(245,158,11,0.14)" : "rgba(217,119,6,0.08)",
        border: dark ? "rgba(245,158,11,0.38)" : "rgba(217,119,6,0.24)"
      };
    default:
      return {
        accent: palette.primary,
        background: palette.overlaySoft,
        border: palette.border
      };
  }
}

function formatEventMeta(event: EventItem): string {
  const kind = event.is_recurring ? "Rutin" : "Plan";
  const reminderText = event.reminders.length === 1 ? "1 reminder" : `${event.reminders.length} reminder`;
  return `${kind} / ${reminderText}`;
}

function AgendaEventCard({
  palette,
  event,
  onEdit,
  onComplete,
  onDelete
}: {
  palette: Palette;
  event: EventItem;
  onEdit: () => void;
  onComplete: () => void;
  onDelete: () => void;
}) {
  const visualTone = getEventVisualTone(event);
  const toneColors = getToneColors(palette, visualTone);
  const description = getDisplayDescription(event);

  return (
    <View
      style={[
        styles.agendaEventCard,
        {
          backgroundColor: toneColors.background,
          borderColor: toneColors.border,
          borderLeftColor: toneColors.accent
        }
      ]}
    >
      <View style={styles.eventMediaRow}>
        <View style={[styles.eventGlyph, { backgroundColor: toneColors.accent }]}>
          <Text style={styles.eventGlyphText}>{getEventMediaGlyph(visualTone)}</Text>
        </View>
        <View style={styles.eventMediaText}>
          <Text style={[styles.eventStatus, { color: toneColors.accent }]}>{getEventStateLabel(event)}</Text>
          <Text style={[styles.eventTime, { color: palette.text }]}>
            {formatEventDateLabel(event)} / {formatEventTimeLabel(event)}
          </Text>
        </View>
      </View>

      <View style={styles.eventHeader}>
        <View style={styles.eventTitleWrap}>
          <Text style={[styles.itemTitle, { color: palette.text }]}>{event.title}</Text>
          <Text style={[styles.muted, { color: palette.muted }]}>{formatEventMeta(event)}</Text>
        </View>
        <View style={[styles.eventPill, { borderColor: toneColors.border, backgroundColor: palette.surface }]}>
          <Text style={[styles.eventPillText, { color: toneColors.accent }]}>{getEventStateLabel(event)}</Text>
        </View>
      </View>

      {description ? <Text style={[styles.note, { color: palette.muted }]}>{description}</Text> : null}

      <View style={[styles.eventMetaRow, { borderTopColor: toneColors.border }]}>
        <Text style={[styles.eventMetaText, { color: palette.muted }]}>{formatEventTimeLabel(event)}</Text>
        <Text style={[styles.eventMetaText, { color: palette.muted }]}>{formatEventMeta(event)}</Text>
      </View>

      <View style={styles.actions}>
        <Button palette={palette} label="Duzenle" variant="secondary" onPress={onEdit} />
        <Button
          palette={palette}
          label={event.is_completed ? "Geri al" : "Tamamla"}
          variant="ghost"
          onPress={onComplete}
        />
        <Button palette={palette} label="Sil" variant="danger" onPress={onDelete} />
      </View>
    </View>
  );
}

function AgendaDayPanel({
  palette,
  day,
  open,
  onToggle,
  onEdit,
  onComplete,
  onDelete,
  delay
}: {
  palette: Palette;
  day: AgendaDay;
  open: boolean;
  onToggle: () => void;
  onEdit: (event: EventItem) => void;
  onComplete: (event: EventItem) => void;
  onDelete: (event: EventItem) => void;
  delay: number;
}) {
  return (
    <Card
      palette={palette}
      delay={delay}
      elevated={open}
      style={[
        styles.dayPanel,
        {
          borderColor: open ? palette.primary : palette.border
        }
      ]}
    >
      <Pressable
        onPress={onToggle}
        accessibilityRole="button"
        accessibilityState={{ expanded: open }}
        style={({ pressed }) => [styles.dayPanelHeader, { opacity: pressed ? 0.78 : 1 }]}
      >
        <View style={styles.dayPanelMain}>
          <Text style={[styles.dayPanelEyebrow, { color: palette.primary }]}>{formatRelativeLabel(day.date)}</Text>
          <Text style={[styles.dayPanelTitle, { color: palette.text }]}>{formatDayHeader(day.date)}</Text>
          {!open ? (
            <Text style={[styles.dayPanelTeaser, { color: palette.muted }]}>
              {day.events.length ? `${day.events.length} plan hazir` : "Plan kaydi yok"}
            </Text>
          ) : null}
        </View>
        <View style={styles.dayPanelSummary}>
          <View style={[styles.countPill, { backgroundColor: palette.cardMeta, borderColor: palette.border }]}>
            <Text style={[styles.countText, { color: palette.text }]}>{day.events.length} plan</Text>
          </View>
          <Text style={[styles.panelToggleGlyph, { color: palette.muted }]}>{open ? "-" : "+"}</Text>
        </View>
      </Pressable>

      {open ? (
        <View style={styles.dayPanelContent}>
          {day.events.length ? (
            day.events.map((event) => (
              <AgendaEventCard
                key={event.id}
                palette={palette}
                event={event}
                onEdit={() => onEdit(event)}
                onComplete={() => onComplete(event)}
                onDelete={() => onDelete(event)}
              />
            ))
          ) : (
            <View style={[styles.emptyAgenda, { backgroundColor: palette.overlaySoft, borderColor: palette.border }]}>
              <Text style={[styles.muted, { color: palette.muted }]}>Bu gun icin plan kaydi yok.</Text>
            </View>
          )}
        </View>
      ) : null}
    </Card>
  );
}

function formatDoseStatus(dose: MedicationDoseItem): string {
  if (dose.status === "taken") {
    return "Alindi";
  }
  if (dose.status === "snoozed") {
    return "Ertelendi";
  }
  return "Bekliyor";
}

function formatDoseMeta(dose: MedicationDoseItem): string {
  const scheduled = formatTime(new Date(dose.scheduled_for));
  if (dose.status === "snoozed" && dose.snoozed_until) {
    return `${scheduled} / ${formatTime(new Date(dose.snoozed_until))}`;
  }
  return scheduled;
}

function formatMedicationSchedule(medication: Medication): string {
  const days = medication.schedule_mode === "interval"
    ? `${medication.interval_days} gunde bir, ${medication.starts_on} itibaren`
    : medication.weekdays.map((day) => WEEKDAYS[day]).filter(Boolean).join(", ");
  const times = medication.dose_times.join(", ");
  return `${days} / ${times}`;
}

function MedicationDoseCard({
  palette,
  dose,
  saving,
  onTake,
  onSnooze
}: {
  palette: Palette;
  dose: MedicationDoseItem;
  saving: boolean;
  onTake: () => void;
  onSnooze: () => void;
}) {
  const done = dose.status === "taken";
  const statusColor = done ? palette.positive : dose.status === "snoozed" ? palette.warning : palette.primary;

  return (
    <Card palette={palette} delay={120} style={styles.medicationCard}>
      <View style={styles.eventHeader}>
        <View style={styles.eventTitleWrap}>
          <Text style={[styles.itemTitle, { color: palette.text }]}>{dose.medication_name}</Text>
          <Text style={[styles.muted, { color: palette.muted }]}>{dose.dosage}</Text>
        </View>
        <View style={[styles.eventPill, { borderColor: statusColor, backgroundColor: palette.overlaySoft }]}>
          <Text style={[styles.eventPillText, { color: statusColor }]}>{formatDoseStatus(dose)}</Text>
        </View>
      </View>
      <Text style={[styles.eventTime, { color: palette.text }]}>{formatDoseMeta(dose)}</Text>
      {dose.instructions ? <Text style={[styles.note, { color: palette.muted }]}>{dose.instructions}</Text> : null}
      <View style={styles.actions}>
        <Button palette={palette} label="Aldim" onPress={onTake} disabled={saving || done} />
        <Button palette={palette} label="10 dk ertele" variant="secondary" onPress={onSnooze} disabled={saving || done} />
      </View>
    </Card>
  );
}

function MedicationProgramCard({
  palette,
  medication,
  saving,
  onEdit,
  onDeactivate
}: {
  palette: Palette;
  medication: Medication;
  saving: boolean;
  onEdit: () => void;
  onDeactivate: () => void;
}) {
  return (
    <Card palette={palette} delay={160} style={styles.medicationCard}>
      <View style={styles.eventHeader}>
        <View style={styles.eventTitleWrap}>
          <Text style={[styles.itemTitle, { color: palette.text }]}>{medication.name}</Text>
          <Text style={[styles.muted, { color: palette.muted }]}>{medication.dosage}</Text>
        </View>
        <View
          style={[
            styles.eventPill,
            {
              borderColor: medication.is_active ? palette.positive : palette.border,
              backgroundColor: palette.overlaySoft
            }
          ]}
        >
          <Text style={[styles.eventPillText, { color: medication.is_active ? palette.positive : palette.muted }]}>
            {medication.is_active ? "Aktif" : "Pasif"}
          </Text>
        </View>
      </View>
      <Text style={[styles.muted, { color: palette.muted }]}>{formatMedicationSchedule(medication)}</Text>
      {medication.instructions ? (
        <Text style={[styles.note, { color: palette.muted }]}>{medication.instructions}</Text>
      ) : null}
      {medication.is_active ? (
        <View style={styles.actions}>
          <Button palette={palette} label="Duzenle" variant="secondary" onPress={onEdit} disabled={saving} />
          <Button palette={palette} label="Pasiflestir" variant="ghost" onPress={onDeactivate} disabled={saving} />
        </View>
      ) : null}
    </Card>
  );
}

export function CalendarScreen({ palette, api, refreshKey, onChanged, onSyncNotifications }: Props) {
  const [dashboard, setDashboard] = useState<CalendarDashboard | null>(null);
  const [medicationDashboard, setMedicationDashboard] = useState<MedicationDashboard | null>(null);
  const [viewingDate, setViewingDate] = useState(() => new Date());
  const [selectedDateKey, setSelectedDateKey] = useState(() => toDateKey(new Date()));
  const [openDays, setOpenDays] = useState<Record<string, boolean>>(() => getTodayOpenState());
  const [editing, setEditing] = useState<EventItem | null>(null);
  const [form, setForm] = useState<EditForm | null>(null);
  const [editingMedication, setEditingMedication] = useState<Medication | null>(null);
  const [medicationForm, setMedicationForm] = useState<MedicationEditForm | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    setError("");
    try {
      const [calendarPayload, medicationPayload] = await Promise.all([
        fetchCalendarDashboard(api, true),
        fetchMedicationDashboard(api, 30)
      ]);
      setDashboard(calendarPayload);
      setMedicationDashboard(medicationPayload);
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : "Takvim yuklenemedi.");
    } finally {
      setLoading(false);
    }
  }, [api]);

  useEffect(() => {
    setLoading(true);
    void load();
  }, [load, refreshKey]);

  const events = useMemo(() => {
    if (!dashboard) {
      return [];
    }
    return [...dashboard.upcoming_events, ...dashboard.past_events].sort(
      (a, b) => new Date(a.starts_at).getTime() - new Date(b.starts_at).getTime()
    );
  }, [dashboard]);

  const eventsByDay = useMemo(() => {
    const map = new Map<string, EventItem[]>();
    for (const event of events) {
      const key = toDateKey(event.starts_at);
      const current = map.get(key) ?? [];
      current.push(event);
      map.set(key, current);
    }
    return map;
  }, [events]);

  const monthDays = useMemo(() => buildMonthDays(viewingDate), [viewingDate]);
  const agendaDays = useMemo(() => buildAgendaDays(eventsByDay), [eventsByDay]);
  const activeMedications = useMemo(
    () => medicationDashboard?.medications.filter((medication) => medication.is_active) ?? [],
    [medicationDashboard]
  );

  function updateForm<Key extends keyof EditForm>(field: Key, value: EditForm[Key]) {
    setForm((current) => (current ? { ...current, [field]: value } : current));
  }

  function updateMedicationForm<Key extends keyof MedicationEditForm>(field: Key, value: MedicationEditForm[Key]) {
    setMedicationForm((current) => (current ? { ...current, [field]: value } : current));
  }

  function toggleMedicationWeekday(index: number) {
    setMedicationForm((current) => {
      if (!current) {
        return current;
      }
      const weekdays = current.weekdays.includes(index)
        ? current.weekdays.filter((item) => item !== index)
        : [...current.weekdays, index];
      return { ...current, weekdays };
    });
  }

  function selectMonthDay(day: Date) {
    const key = toDateKey(day);
    setSelectedDateKey(key);
    setViewingDate(new Date(day.getFullYear(), day.getMonth(), 1));

    if (agendaDays.some((agendaDay) => agendaDay.key === key)) {
      setOpenDays((current) => ({
        ...current,
        [key]: true
      }));
    }
  }

  function toggleAgendaDay(dayKey: string) {
    const nextDate = fromDateKey(dayKey);
    setSelectedDateKey(dayKey);
    setViewingDate(new Date(nextDate.getFullYear(), nextDate.getMonth(), 1));
    setOpenDays((current) => ({
      ...current,
      [dayKey]: !current[dayKey]
    }));
  }

  function startEditing(event: EventItem) {
    setEditing(event);
    setForm(toEditForm(event));
  }

  function startEditingMedication(medication: Medication) {
    setEditingMedication(medication);
    setMedicationForm(toMedicationEditForm(medication));
  }

  async function saveEdit() {
    if (!editing || !form) {
      return;
    }
    setSaving(true);
    setError("");
    try {
      await updateEvent(api, editing.id, {
        title: form.title.trim(),
        description: form.description.trim() || null,
        starts_at: parseDateTimeLocalInput(form.startsAt),
        is_important: form.important === "yes",
        is_completed: form.completed === "yes"
      });
      setEditing(null);
      setForm(null);
      await load();
      await onSyncNotifications();
      onChanged();
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : "Etkinlik guncellenemedi.");
    } finally {
      setSaving(false);
    }
  }

  async function saveMedicationEdit() {
    if (!editingMedication || !medicationForm) {
      return;
    }
    const parsedIntervalDays = Number(medicationForm.intervalDays);
    if (
      !medicationForm.name.trim()
      || !medicationForm.dosage.trim()
      || (medicationForm.scheduleMode === "weekdays" && medicationForm.weekdays.length === 0)
      || (medicationForm.scheduleMode === "interval" && (!Number.isInteger(parsedIntervalDays) || parsedIntervalDays < 1))
    ) {
      setError("Ilac adi, doz ve gecerli program bilgisi zorunlu.");
      return;
    }

    setSaving(true);
    setError("");
    try {
      await updateMedication(api, editingMedication.id, {
        name: medicationForm.name.trim(),
        dosage: medicationForm.dosage.trim(),
        instructions: medicationForm.instructions.trim() || null,
        schedule_mode: medicationForm.scheduleMode,
        weekdays: medicationForm.scheduleMode === "weekdays" ? medicationForm.weekdays : [],
        interval_days: medicationForm.scheduleMode === "interval" ? parsedIntervalDays : null,
        dose_times: parseDoseTimes(medicationForm.doseTimes),
        starts_on: medicationForm.startsOn,
        ends_on: medicationForm.endsOn.trim() || null,
        timezone: editingMedication.timezone,
        is_active: medicationForm.active === "yes"
      });
      setEditingMedication(null);
      setMedicationForm(null);
      await load();
      await onSyncNotifications();
      onChanged();
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : "Ilac hatirlaticisi guncellenemedi.");
    } finally {
      setSaving(false);
    }
  }

  async function toggleComplete(event: EventItem) {
    setSaving(true);
    setError("");
    try {
      await updateEvent(api, event.id, { is_completed: !event.is_completed });
      await load();
      await onSyncNotifications();
      onChanged();
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : "Etkinlik guncellenemedi.");
    } finally {
      setSaving(false);
    }
  }

  function confirmDelete(event: EventItem) {
    Alert.alert("Etkinlik silinsin mi?", event.title, [
      { text: "Vazgec", style: "cancel" },
      {
        text: "Sil",
        style: "destructive",
        onPress: () => {
          void (async () => {
            setSaving(true);
            setError("");
            try {
              await deleteEvent(api, event.id);
              await load();
              await onSyncNotifications();
              onChanged();
            } catch (nextError) {
              setError(nextError instanceof Error ? nextError.message : "Etkinlik silinemedi.");
            } finally {
              setSaving(false);
            }
          })();
        }
      }
    ]);
  }

  async function takeMedicationDose(dose: MedicationDoseItem) {
    setSaving(true);
    setError("");
    try {
      await markMedicationDoseTaken(api, dose.medication_id, dose.scheduled_for);
      await load();
      await onSyncNotifications();
      onChanged();
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : "Ilac dozu guncellenemedi.");
    } finally {
      setSaving(false);
    }
  }

  async function snoozeDose(dose: MedicationDoseItem) {
    setSaving(true);
    setError("");
    try {
      await snoozeMedicationDose(api, dose.medication_id, dose.scheduled_for, 10);
      await load();
      await onSyncNotifications();
      onChanged();
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : "Ilac dozu ertelenemedi.");
    } finally {
      setSaving(false);
    }
  }

  function confirmDeactivateMedication(medication: Medication) {
    Alert.alert("Ilac hatirlaticisi pasiflestirilsin mi?", medication.name, [
      { text: "Vazgec", style: "cancel" },
      {
        text: "Pasiflestir",
        style: "destructive",
        onPress: () => {
          void (async () => {
            setSaving(true);
            setError("");
            try {
              await updateMedication(api, medication.id, { is_active: false });
              await load();
              await onSyncNotifications();
              onChanged();
            } catch (nextError) {
              setError(nextError instanceof Error ? nextError.message : "Ilac hatirlaticisi guncellenemedi.");
            } finally {
              setSaving(false);
            }
          })();
        }
      }
    ]);
  }

  return (
    <ScrollView
      style={{ backgroundColor: palette.background }}
      contentContainerStyle={styles.content}
      keyboardShouldPersistTaps="handled"
    >
      <Header palette={palette} eyebrow="Takvim" title="Plan ve rutinler" />
      {loading ? <LoadingBlock palette={palette} /> : null}
      {error ? <StatusMessage palette={palette} message={error} tone="error" /> : null}

      <Card palette={palette} style={styles.monthCard} delay={120} elevated>
        <View style={styles.rowBetween}>
          <Button
            palette={palette}
            label="Onceki"
            variant="ghost"
            onPress={() => setViewingDate((current) => new Date(current.getFullYear(), current.getMonth() - 1, 1))}
          />
          <Text style={[styles.monthTitle, { color: palette.text }]}>{formatMonthTitle(viewingDate)}</Text>
          <Button
            palette={palette}
            label="Sonraki"
            variant="ghost"
            onPress={() => setViewingDate((current) => new Date(current.getFullYear(), current.getMonth() + 1, 1))}
          />
        </View>
        <View style={styles.monthGrid}>
          {monthDays.map((day) => {
            const key = toDateKey(day);
            const inMonth = day.getMonth() === viewingDate.getMonth();
            const dayEvents = eventsByDay.get(key) ?? [];
            const hasEvents = dayEvents.length > 0;
            const hasImportantEvents = dayEvents.some((event) => event.is_important);
            const selected = key === selectedDateKey;
            return (
              <Pressable
                key={key}
                onPress={() => selectMonthDay(day)}
                style={[
                  styles.dayCell,
                  {
                    backgroundColor: selected ? palette.primary : hasEvents ? palette.overlaySoft : "transparent",
                    borderColor: selected
                      ? palette.primary
                      : hasImportantEvents
                        ? palette.negative
                        : hasEvents
                          ? palette.primary
                          : palette.border,
                    opacity: inMonth ? 1 : 0.45
                  }
                ]}
              >
                <Text style={[styles.dayText, { color: selected ? palette.primaryText : palette.text }]}>
                  {day.getDate()}
                </Text>
                {hasEvents ? (
                  <View
                    style={[
                      styles.eventDot,
                      {
                        backgroundColor: selected
                          ? palette.primaryText
                          : hasImportantEvents
                            ? palette.negative
                            : palette.primary
                      }
                    ]}
                  />
                ) : null}
              </Pressable>
            );
          })}
        </View>
      </Card>

      <View style={styles.sectionHeader}>
        <Text style={[styles.sectionTitle, { color: palette.text }]}>Bugunku ilaclar</Text>
        <Text style={[styles.sectionSubtitle, { color: palette.muted }]}>Aldim veya ertele</Text>
      </View>
      {medicationDashboard?.today_doses.length ? (
        medicationDashboard.today_doses.map((dose) => (
          <MedicationDoseCard
            key={`${dose.medication_id}-${dose.scheduled_for}`}
            palette={palette}
            dose={dose}
            saving={saving}
            onTake={() => void takeMedicationDose(dose)}
            onSnooze={() => void snoozeDose(dose)}
          />
        ))
      ) : (
        <StatusMessage palette={palette} message="Bugun icin ilac dozu yok." />
      )}

      <View style={styles.sectionHeader}>
        <Text style={[styles.sectionTitle, { color: palette.text }]}>Ilac programlari</Text>
        <Text style={[styles.sectionSubtitle, { color: palette.muted }]}>Aktif hatirlaticilar</Text>
      </View>
      {activeMedications.length ? (
        activeMedications.slice(0, 6).map((medication) => (
          <MedicationProgramCard
            key={medication.id}
            palette={palette}
            medication={medication}
            saving={saving}
            onEdit={() => startEditingMedication(medication)}
            onDeactivate={() => confirmDeactivateMedication(medication)}
          />
        ))
      ) : (
        <StatusMessage palette={palette} message="Aktif ilac hatirlaticisi yok." />
      )}

      {editingMedication && medicationForm ? (
        <Card palette={palette} delay={100} elevated>
          <Text style={[styles.sectionTitle, { color: palette.text }]}>Ilac programini duzenle</Text>
          <Field
            palette={palette}
            label="Ilac adi"
            value={medicationForm.name}
            onChangeText={(value) => updateMedicationForm("name", value)}
          />
          <Field
            palette={palette}
            label="Doz"
            value={medicationForm.dosage}
            onChangeText={(value) => updateMedicationForm("dosage", value)}
          />
          <Field
            palette={palette}
            label="Talimat"
            value={medicationForm.instructions}
            onChangeText={(value) => updateMedicationForm("instructions", value)}
          />
          <SegmentedControl
            palette={palette}
            value={medicationForm.scheduleMode}
            onChange={(value) => updateMedicationForm("scheduleMode", value)}
            options={[
              { value: "weekdays", label: "Belirli gunler" },
              { value: "interval", label: "Her N gunde" }
            ]}
          />
          {medicationForm.scheduleMode === "weekdays" ? (
            <>
              <Text style={[styles.eventStatus, { color: palette.muted }]}>Gunler</Text>
              <View style={styles.actions}>
                {WEEKDAYS.map((label, index) => {
                  const active = medicationForm.weekdays.includes(index);
                  return (
                    <Pressable
                      key={label}
                      onPress={() => toggleMedicationWeekday(index)}
                      style={({ pressed }) => [
                        styles.dayChip,
                        {
                          backgroundColor: active ? palette.primary : palette.overlaySoft,
                          borderColor: active ? palette.primary : palette.border,
                          transform: [{ scale: pressed ? 0.96 : 1 }]
                        }
                      ]}
                    >
                      <Text style={[styles.dayChipText, { color: active ? palette.primaryText : palette.text }]}>
                        {label}
                      </Text>
                    </Pressable>
                  );
                })}
              </View>
            </>
          ) : (
            <Field
              palette={palette}
              label="Kac gunde bir"
              value={medicationForm.intervalDays}
              onChangeText={(value) => updateMedicationForm("intervalDays", value)}
              keyboardType="numeric"
              placeholder="2"
            />
          )}
          <Field
            palette={palette}
            label="Saatler"
            value={medicationForm.doseTimes}
            onChangeText={(value) => updateMedicationForm("doseTimes", value)}
            placeholder="09:00, 21:00"
          />
          <Field
            palette={palette}
            label="Baslangic tarihi"
            value={medicationForm.startsOn}
            onChangeText={(value) => updateMedicationForm("startsOn", value)}
          />
          <Field
            palette={palette}
            label="Bitis tarihi"
            value={medicationForm.endsOn}
            onChangeText={(value) => updateMedicationForm("endsOn", value)}
            placeholder="Opsiyonel YYYY-MM-DD"
          />
          <SegmentedControl
            palette={palette}
            value={medicationForm.active}
            onChange={(value) => updateMedicationForm("active", value)}
            options={[
              { value: "yes", label: "Aktif" },
              { value: "no", label: "Pasif" }
            ]}
          />
          <View style={styles.actions}>
            <Button palette={palette} label="Kaydet" onPress={saveMedicationEdit} disabled={saving} />
            <Button
              palette={palette}
              label="Vazgec"
              variant="ghost"
              onPress={() => {
                setEditingMedication(null);
                setMedicationForm(null);
              }}
            />
          </View>
        </Card>
      ) : null}

      {editing && form ? (
        <Card palette={palette} delay={100} elevated>
          <Text style={[styles.sectionTitle, { color: palette.text }]}>Etkinligi duzenle</Text>
          <Field palette={palette} label="Baslik" value={form.title} onChangeText={(value) => updateForm("title", value)} />
          <Field
            palette={palette}
            label="Aciklama"
            value={form.description}
            onChangeText={(value) => updateForm("description", value)}
          />
          <Field
            palette={palette}
            label="Tarih saat"
            value={form.startsAt}
            onChangeText={(value) => updateForm("startsAt", value)}
            placeholder="YYYY-MM-DDTHH:MM"
          />
          <SegmentedControl
            palette={palette}
            value={form.important}
            onChange={(value) => updateForm("important", value)}
            options={[
              { value: "no", label: "Normal" },
              { value: "yes", label: "Onemli" }
            ]}
          />
          <SegmentedControl
            palette={palette}
            value={form.completed}
            onChange={(value) => updateForm("completed", value)}
            options={[
              { value: "no", label: "Acik" },
              { value: "yes", label: "Tamam" }
            ]}
          />
          <View style={styles.actions}>
            <Button palette={palette} label="Kaydet" onPress={saveEdit} disabled={saving} />
            <Button
              palette={palette}
              label="Vazgec"
              variant="ghost"
              onPress={() => {
                setEditing(null);
                setForm(null);
              }}
            />
          </View>
        </Card>
      ) : null}

      <View style={styles.sectionHeader}>
        <Text style={[styles.sectionTitle, { color: palette.text }]}>Haftalik program</Text>
        <Text style={[styles.sectionSubtitle, { color: palette.muted }]}>Bugunden itibaren 5 gun</Text>
      </View>
      {agendaDays.map((day, index) => (
        <AgendaDayPanel
          key={day.key}
          palette={palette}
          day={day}
          open={Boolean(openDays[day.key])}
          delay={150 + index * 50}
          onToggle={() => toggleAgendaDay(day.key)}
          onEdit={startEditing}
          onComplete={(event) => void toggleComplete(event)}
          onDelete={confirmDelete}
        />
      ))}

      <Text style={[styles.sectionTitle, { color: palette.text }]}>Bekleyen hatirlaticilar</Text>
      {dashboard?.pending_reminders.length ? (
        dashboard.pending_reminders.slice(0, 6).map((reminder, index) => (
          <Card key={reminder.id} palette={palette} delay={180 + index * 50}>
            <Text style={[styles.itemTitle, { color: palette.text }]}>{reminder.event_title}</Text>
            <Text style={[styles.muted, { color: palette.muted }]}>{formatDateTime(reminder.remind_at)}</Text>
          </Card>
        ))
      ) : (
        <StatusMessage palette={palette} message="Bekleyen hatirlatici yok." />
      )}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  content: {
    paddingHorizontal: 20,
    paddingTop: 18,
    paddingBottom: 124,
    gap: 18
  },
  rowBetween: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    gap: 10
  },
  monthTitle: {
    flex: 1,
    textAlign: "center",
    fontSize: 16,
    fontWeight: "900"
  },
  monthGrid: {
    flexDirection: "row",
    flexWrap: "wrap",
    justifyContent: "space-between",
    rowGap: 10
  },
  monthCard: {
    paddingTop: 28
  },
  dayCell: {
    width: "12.7%",
    aspectRatio: 1,
    borderRadius: 999,
    borderWidth: 1,
    alignItems: "center",
    justifyContent: "center",
    position: "relative"
  },
  dayText: {
    fontSize: 13,
    fontWeight: "900"
  },
  dayChip: {
    minHeight: 38,
    borderRadius: 12,
    borderWidth: 1,
    paddingHorizontal: 12,
    alignItems: "center",
    justifyContent: "center"
  },
  dayChipText: {
    fontSize: 13,
    fontWeight: "900"
  },
  eventDot: {
    position: "absolute",
    bottom: 7,
    width: 4,
    height: 4,
    borderRadius: 999
  },
  sectionHeader: {
    gap: 4,
    marginTop: 2
  },
  sectionTitle: {
    fontSize: 21,
    fontWeight: "900"
  },
  sectionSubtitle: {
    fontSize: 13,
    fontWeight: "800"
  },
  dayPanel: {
    padding: 0,
    gap: 0
  },
  dayPanelHeader: {
    paddingHorizontal: 20,
    paddingVertical: 18,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    gap: 14
  },
  dayPanelMain: {
    flex: 1,
    gap: 4
  },
  dayPanelEyebrow: {
    fontSize: 11,
    fontWeight: "900",
    letterSpacing: 0,
    textTransform: "uppercase"
  },
  dayPanelTitle: {
    fontSize: 18,
    fontWeight: "900"
  },
  dayPanelTeaser: {
    fontSize: 13,
    fontWeight: "700"
  },
  dayPanelSummary: {
    alignItems: "flex-end",
    gap: 8
  },
  countPill: {
    borderWidth: 1,
    borderRadius: 999,
    paddingHorizontal: 10,
    paddingVertical: 6
  },
  countText: {
    fontSize: 12,
    fontWeight: "900"
  },
  panelToggleGlyph: {
    fontSize: 22,
    fontWeight: "900",
    lineHeight: 24
  },
  dayPanelContent: {
    paddingHorizontal: 16,
    paddingBottom: 16,
    gap: 12
  },
  agendaEventCard: {
    borderWidth: 1,
    borderLeftWidth: 4,
    borderRadius: 18,
    padding: 14,
    gap: 12
  },
  medicationCard: {
    gap: 12
  },
  eventMediaRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 12
  },
  eventGlyph: {
    width: 42,
    height: 42,
    borderRadius: 13,
    alignItems: "center",
    justifyContent: "center"
  },
  eventGlyphText: {
    color: "#ffffff",
    fontSize: 14,
    fontWeight: "900"
  },
  eventMediaText: {
    flex: 1,
    gap: 3
  },
  eventStatus: {
    fontSize: 11,
    fontWeight: "900",
    letterSpacing: 0,
    textTransform: "uppercase"
  },
  eventTime: {
    fontSize: 13,
    fontWeight: "800"
  },
  eventHeader: {
    flexDirection: "row",
    alignItems: "flex-start",
    justifyContent: "space-between",
    gap: 10
  },
  eventTitleWrap: {
    flex: 1,
    gap: 4
  },
  eventPill: {
    borderWidth: 1,
    borderRadius: 999,
    paddingHorizontal: 10,
    paddingVertical: 5
  },
  eventPillText: {
    fontSize: 11,
    fontWeight: "900"
  },
  eventMetaRow: {
    paddingTop: 12,
    borderTopWidth: 1,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    gap: 10
  },
  eventMetaText: {
    fontSize: 12,
    fontWeight: "800"
  },
  emptyAgenda: {
    borderWidth: 1,
    borderRadius: 16,
    padding: 14
  },
  itemTitle: {
    fontSize: 17,
    fontWeight: "900"
  },
  muted: {
    fontSize: 13,
    fontWeight: "800"
  },
  note: {
    fontSize: 14,
    lineHeight: 20
  },
  actions: {
    flexDirection: "row",
    gap: 10,
    flexWrap: "wrap"
  }
});
