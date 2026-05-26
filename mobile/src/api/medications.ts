import { apiRequest } from "./client";
import type { ApiContext } from "./client";
import type { Medication, MedicationDashboard, MedicationDoseItem } from "./types";

export type MedicationPayload = {
  name?: string;
  dosage?: string;
  instructions?: string | null;
  schedule_mode?: "weekdays" | "interval";
  weekdays?: number[];
  interval_days?: number | null;
  dose_times?: string[];
  starts_on?: string;
  ends_on?: string | null;
  timezone?: string;
  is_active?: boolean;
};

export function fetchMedications(context: ApiContext) {
  return apiRequest<Medication[]>(context, "/medications");
}

export function fetchMedicationDashboard(context: ApiContext, days = 30) {
  const params = new URLSearchParams({ days: String(days) });
  return apiRequest<MedicationDashboard>(context, `/medications/dashboard?${params.toString()}`);
}

export function fetchMedicationNotificationSchedule(context: ApiContext, days = 30, limit = 128) {
  const params = new URLSearchParams({ days: String(days), limit: String(limit) });
  return apiRequest<MedicationDoseItem[]>(context, `/medications/notification-schedule?${params.toString()}`);
}

export function createMedication(context: ApiContext, payload: MedicationPayload) {
  return apiRequest<Medication>(context, "/medications", {
    method: "POST",
    body: JSON.stringify(payload)
  });
}

export function updateMedication(context: ApiContext, medicationId: number, payload: MedicationPayload) {
  return apiRequest<Medication>(context, `/medications/${medicationId}`, {
    method: "PUT",
    body: JSON.stringify(payload)
  });
}

export function deleteMedication(context: ApiContext, medicationId: number) {
  return apiRequest<void>(context, `/medications/${medicationId}`, {
    method: "DELETE"
  });
}

export function markMedicationDoseTaken(context: ApiContext, medicationId: number, scheduledFor: string) {
  return apiRequest<MedicationDoseItem>(context, `/medications/${medicationId}/doses/taken`, {
    method: "POST",
    body: JSON.stringify({ scheduled_for: scheduledFor })
  });
}

export function snoozeMedicationDose(
  context: ApiContext,
  medicationId: number,
  scheduledFor: string,
  snoozeMinutes = 10
) {
  return apiRequest<MedicationDoseItem>(context, `/medications/${medicationId}/doses/snooze`, {
    method: "POST",
    body: JSON.stringify({ scheduled_for: scheduledFor, snooze_minutes: snoozeMinutes })
  });
}
