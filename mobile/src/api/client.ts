import AsyncStorage from "@react-native-async-storage/async-storage";

import { getApiBaseUrl, getHealthUrl } from "../settings/settings";
import type { HealthPayload } from "./types";

const DEVICE_ID_KEY = "lifeos-mobile-device-id";

export type ApiContext = {
  serverUrl: string;
  accessToken?: string;
};

type ApiRequestOptions = RequestInit & {
  skipJsonContentType?: boolean;
};

function normalizeErrorDetail(detail: unknown): string {
  if (typeof detail === "string" && detail.trim()) {
    return detail;
  }

  if (Array.isArray(detail)) {
    for (const item of detail) {
      if (typeof item === "string" && item.trim()) {
        return item;
      }
      if (item && typeof item === "object") {
        const record = item as Record<string, unknown>;
        if (typeof record.msg === "string" && record.msg.trim()) {
          return record.msg;
        }
        if (typeof record.message === "string" && record.message.trim()) {
          return record.message;
        }
      }
    }
  }

  if (detail && typeof detail === "object") {
    const record = detail as Record<string, unknown>;
    if (typeof record.msg === "string" && record.msg.trim()) {
      return record.msg;
    }
    if (typeof record.message === "string" && record.message.trim()) {
      return record.message;
    }
  }

  return "";
}

function makeDeviceId(): string {
  return `rn-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 12)}`;
}

export async function getOrCreateDeviceId(): Promise<string> {
  const existing = await AsyncStorage.getItem(DEVICE_ID_KEY);
  if (existing) {
    return existing;
  }
  const next = makeDeviceId();
  await AsyncStorage.setItem(DEVICE_ID_KEY, next);
  return next;
}

export async function apiRequest<T>(
  context: ApiContext,
  path: string,
  options: ApiRequestOptions = {}
): Promise<T> {
  const deviceId = await getOrCreateDeviceId();
  const headers = new Headers(options.headers);

  if (!options.skipJsonContentType && !headers.has("Content-Type")) {
    headers.set("Content-Type", "application/json");
  }
  headers.set("X-Device-Id", deviceId);
  if (context.accessToken) {
    headers.set("Authorization", `Bearer ${context.accessToken}`);
  }

  let response: Response;
  try {
    response = await fetch(`${getApiBaseUrl(context.serverUrl)}${path}`, {
      ...options,
      headers
    });
  } catch {
    throw new Error("API'ye ulasilamadi. Tailscale ve server adresini kontrol edin.");
  }

  const text = await response.text();
  let payload: unknown = null;
  try {
    payload = text ? JSON.parse(text) : null;
  } catch {
    payload = null;
  }

  if (!response.ok) {
    const detail =
      payload && typeof payload === "object" && "detail" in payload
        ? (payload as { detail?: unknown }).detail
        : undefined;
    const message =
      normalizeErrorDetail(detail) ||
      (response.status >= 500
        ? "Sunucu hatasi olustu. Backend loglarini ve migration durumunu kontrol edin."
        : "Beklenmeyen bir hata olustu.");
    throw new Error(message);
  }

  return payload as T;
}

export async function fetchBackendHealth(serverUrl: string): Promise<HealthPayload> {
  let response: Response;
  try {
    response = await fetch(getHealthUrl(serverUrl));
  } catch {
    throw new Error("Sunucuya ulasilamadi. Tailscale baglantisini ve adresi kontrol edin.");
  }

  if (!response.ok) {
    throw new Error("Sunucu durumu kontrol edilemedi.");
  }

  return response.json() as Promise<HealthPayload>;
}
