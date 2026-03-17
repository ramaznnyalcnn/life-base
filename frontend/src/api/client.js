import { getOrCreateDeviceId } from "../device";
import { clearStoredSession, getStoredAccessToken } from "../auth/session";

const API_BASE_URL =
  import.meta.env.VITE_API_BASE_URL ?? "/api/v1";

function formatErrorDetail(detail) {
  if (typeof detail === "string" && detail.trim()) {
    return detail;
  }

  if (Array.isArray(detail)) {
    const firstMessage = detail
      .map((item) => {
        if (typeof item === "string") {
          return item;
        }
        if (item && typeof item === "object") {
          if (typeof item.msg === "string" && item.msg.trim()) {
            return item.msg;
          }
          if (typeof item.message === "string" && item.message.trim()) {
            return item.message;
          }
        }
        return "";
      })
      .find(Boolean);

    if (firstMessage) {
      return firstMessage;
    }
  }

  if (detail && typeof detail === "object") {
    if (typeof detail.msg === "string" && detail.msg.trim()) {
      return detail.msg;
    }
    if (typeof detail.message === "string" && detail.message.trim()) {
      return detail.message;
    }
  }

  return "";
}

export async function apiRequest(path, options = {}) {
  const accessToken = getStoredAccessToken();
  let response;
  try {
    response = await fetch(`${API_BASE_URL}${path}`, {
      headers: {
        "Content-Type": "application/json",
        "X-Device-Id": getOrCreateDeviceId(),
        ...(accessToken ? { Authorization: `Bearer ${accessToken}` } : {}),
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
    if (response.status === 401 && accessToken) {
      clearStoredSession();
    }
    const detail = formatErrorDetail(payload?.detail);
    const message =
      detail ||
      (response.status >= 500
        ? "Sunucu hatasi olustu. Backend logunu ve migration durumunu kontrol edin."
        : "Beklenmeyen bir hata olustu.");
    throw new Error(message);
  }

  return payload;
}

export { API_BASE_URL };
