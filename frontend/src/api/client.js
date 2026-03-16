import { getOrCreateDeviceId } from "../device";

const API_BASE_URL =
  import.meta.env.VITE_API_BASE_URL ?? "/api/v1";

export async function apiRequest(path, options = {}) {
  let response;
  try {
    response = await fetch(`${API_BASE_URL}${path}`, {
      headers: {
        "Content-Type": "application/json",
        "X-Device-Id": getOrCreateDeviceId(),
        ...(options.headers ?? {})
      },
      ...options
    });
  } catch {
    throw new Error(
      "API'ye ulasilamadi. Backend calisiyorsa veritabani migrationlarini guncelleyin."
    );
  }

  let payload = null;
  try {
    payload = await response.json();
  } catch {
    payload = null;
  }

  if (!response.ok) {
    const detail =
      payload?.detail ??
      (response.status >= 500
        ? "Sunucu hatasi olustu. Backend logunu ve migration durumunu kontrol edin."
        : "Beklenmeyen bir hata olustu.");
    throw new Error(detail);
  }

  return payload;
}

export { API_BASE_URL };
