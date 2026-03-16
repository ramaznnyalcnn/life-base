const SESSION_STORAGE_KEY = "lifeos-auth-session";
const SESSION_EVENT_NAME = "lifeos:session-changed";

function emitSessionChange() {
  if (typeof window === "undefined") {
    return;
  }
  window.dispatchEvent(new CustomEvent(SESSION_EVENT_NAME));
}

function normalizeSession(session) {
  if (!session?.accessToken || !session?.user) {
    return null;
  }

  return {
    accessToken: String(session.accessToken),
    user: session.user
  };
}

export function getStoredSession() {
  if (typeof window === "undefined") {
    return null;
  }

  const rawValue = window.localStorage.getItem(SESSION_STORAGE_KEY);
  if (!rawValue) {
    return null;
  }

  try {
    return normalizeSession(JSON.parse(rawValue));
  } catch {
    return null;
  }
}

export function getStoredAccessToken() {
  return getStoredSession()?.accessToken ?? "";
}

export function setStoredSession(session) {
  if (typeof window === "undefined") {
    return;
  }

  const normalized = normalizeSession(session);
  if (!normalized) {
    clearStoredSession();
    return;
  }

  window.localStorage.setItem(SESSION_STORAGE_KEY, JSON.stringify(normalized));
  emitSessionChange();
}

export function clearStoredSession() {
  if (typeof window === "undefined") {
    return;
  }

  window.localStorage.removeItem(SESSION_STORAGE_KEY);
  emitSessionChange();
}

export { SESSION_EVENT_NAME };
