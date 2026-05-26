import { apiRequest } from "./client";

export function fetchMedicationDashboard(days = 30) {
  const search = new URLSearchParams({ days: String(days) });
  return apiRequest(`/medications/dashboard?${search.toString()}`);
}

export function fetchMedicationSchedule(fromDate, toDate) {
  const search = new URLSearchParams({ from_date: fromDate, to_date: toDate });
  return apiRequest(`/medications/schedule?${search.toString()}`);
}

export function createMedication(payload) {
  return apiRequest("/medications", {
    method: "POST",
    body: JSON.stringify(payload)
  });
}

export function updateMedication(medicationId, payload) {
  return apiRequest(`/medications/${medicationId}`, {
    method: "PUT",
    body: JSON.stringify(payload)
  });
}

export function markMedicationDoseTaken(medicationId, scheduledFor) {
  return apiRequest(`/medications/${medicationId}/doses/taken`, {
    method: "POST",
    body: JSON.stringify({ scheduled_for: scheduledFor })
  });
}

export function snoozeMedicationDose(medicationId, scheduledFor, snoozeMinutes = 10) {
  return apiRequest(`/medications/${medicationId}/doses/snooze`, {
    method: "POST",
    body: JSON.stringify({ scheduled_for: scheduledFor, snooze_minutes: snoozeMinutes })
  });
}
