const DEVICE_STORAGE_KEY = "lifeos-device-id";

function generateFallbackId() {
  return `device-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
}

export function getOrCreateDeviceId() {
  const existing = window.localStorage.getItem(DEVICE_STORAGE_KEY);
  if (existing) {
    return existing;
  }

  const nextValue =
    typeof window.crypto?.randomUUID === "function"
      ? window.crypto.randomUUID()
      : generateFallbackId();
  window.localStorage.setItem(DEVICE_STORAGE_KEY, nextValue);
  return nextValue;
}
