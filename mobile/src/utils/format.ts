import type { AccountType, EventItem, TransactionType } from "../api/types";

export function toNumber(value: string | number | null | undefined): number {
  const parsed = Number(value ?? 0);
  return Number.isFinite(parsed) ? parsed : 0;
}

export function formatMoney(value: string | number | null | undefined): string {
  return new Intl.NumberFormat("tr-TR", {
    style: "currency",
    currency: "TRY",
    maximumFractionDigits: 2
  }).format(toNumber(value));
}

export function formatDateTime(value: string | Date | null | undefined): string {
  if (!value) {
    return "-";
  }
  return new Intl.DateTimeFormat("tr-TR", {
    day: "2-digit",
    month: "short",
    hour: "2-digit",
    minute: "2-digit"
  }).format(new Date(value));
}

export function formatDateOnly(value: string | Date | null | undefined): string {
  if (!value) {
    return "-";
  }
  return new Intl.DateTimeFormat("tr-TR", {
    day: "2-digit",
    month: "short",
    year: "numeric"
  }).format(new Date(value));
}

export function todayInput(): string {
  return new Date().toISOString().slice(0, 10);
}

export function nowTimeInput(): string {
  return new Date().toTimeString().slice(0, 5);
}

export function toIsoFromDateTime(dateValue: string, timeValue = "09:00"): string {
  return new Date(`${dateValue}T${timeValue || "09:00"}`).toISOString();
}

export function toDateTimeLocal(value: string): string {
  const date = new Date(value);
  const offsetDate = new Date(date.getTime() - date.getTimezoneOffset() * 60000);
  return offsetDate.toISOString().slice(0, 16);
}

export function getTransactionTypeLabel(type: TransactionType): string {
  if (type === "income") {
    return "Gelir";
  }
  if (type === "payment") {
    return "Odeme";
  }
  return "Gider";
}

export function getAccountTypeLabel(type: AccountType): string {
  if (type === "credit_card") {
    return "Kredi Karti";
  }
  if (type === "cash") {
    return "Nakit";
  }
  return "Banka";
}

export function getEventStateLabel(event: EventItem): string {
  if (event.is_recurring) {
    return "Rutin";
  }
  if (event.is_completed) {
    return "Tamamlandi";
  }
  if (event.is_important) {
    return "Onemli";
  }
  return "Planli";
}

export function parseDateTimeLocalInput(value: string): string {
  return new Date(value).toISOString();
}
