import { apiRequest } from "./client";
import type { ApiContext } from "./client";
import type { CalendarDashboard, EventItem, RecurringEvent } from "./types";

export type EventPayload = {
  title?: string;
  description?: string | null;
  starts_at?: string;
  ends_at?: string | null;
  is_all_day?: boolean;
  is_important?: boolean;
  is_completed?: boolean;
  reminder_offsets_minutes?: number[] | null;
};

export type RecurringEventPayload = {
  title: string;
  description?: string | null;
  weekdays: number[];
  starts_on: string;
  ends_on?: string | null;
  start_time?: string | null;
  end_time?: string | null;
  is_all_day?: boolean;
  is_important?: boolean;
  is_active?: boolean;
  interval_weeks?: number;
};

export function fetchCalendarDashboard(context: ApiContext, includePast = false) {
  const params = new URLSearchParams({ include_past: includePast ? "true" : "false" });
  return apiRequest<CalendarDashboard>(context, `/events/dashboard?${params.toString()}`);
}

export function createEvent(context: ApiContext, payload: EventPayload) {
  return apiRequest<EventItem>(context, "/events", {
    method: "POST",
    body: JSON.stringify(payload)
  });
}

export function updateEvent(context: ApiContext, eventId: number, payload: EventPayload) {
  return apiRequest<EventItem>(context, `/events/${eventId}`, {
    method: "PUT",
    body: JSON.stringify(payload)
  });
}

export function deleteEvent(context: ApiContext, eventId: number) {
  return apiRequest<void>(context, `/events/${eventId}`, {
    method: "DELETE"
  });
}

export function createRecurringEvent(context: ApiContext, payload: RecurringEventPayload) {
  return apiRequest<RecurringEvent>(context, "/recurring-events", {
    method: "POST",
    body: JSON.stringify(payload)
  });
}
