import { apiRequest } from "./client";

const HEALTH_URL = import.meta.env.VITE_HEALTH_URL ?? "/health";

export function login(payload) {
  return apiRequest("/auth/login", {
    method: "POST",
    body: JSON.stringify(payload)
  });
}

export function fetchCurrentUser() {
  return apiRequest("/auth/me");
}

export async function fetchBackendHealth() {
  const response = await fetch(HEALTH_URL);
  if (!response.ok) {
    throw new Error("Sunucu durumu kontrol edilemedi.");
  }
  return response.json();
}
