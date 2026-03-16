import { apiRequest } from "./client";

export function fetchCalendarDashboard(includePast = false) {
  const search = new URLSearchParams({
    include_past: includePast ? "true" : "false"
  });

  return apiRequest(`/events/dashboard?${search.toString()}`);
}

export function createEvent(payload) {
  return apiRequest("/events", {
    method: "POST",
    body: JSON.stringify(payload)
  });
}

export function updateEvent(eventId, payload) {
  return apiRequest(`/events/${eventId}`, {
    method: "PUT",
    body: JSON.stringify(payload)
  });
}

export function deleteEvent(eventId) {
  return apiRequest(`/events/${eventId}`, {
    method: "DELETE"
  });
}
