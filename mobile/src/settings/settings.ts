import AsyncStorage from "@react-native-async-storage/async-storage";

const SETTINGS_KEY = "lifeos-mobile-settings";
const DEFAULT_SERVER_URL = "http://100.105.227.116:8001";
const LEGACY_SERVER_URLS = new Set(["http://192.168.1.12:8001"]);

export type ThemeName = "dark" | "light" | "zen";

export type AppSettings = {
  serverUrl: string;
  theme: ThemeName;
};

export const DEFAULT_SETTINGS: AppSettings = {
  serverUrl: DEFAULT_SERVER_URL,
  theme: "dark"
};

function normalizeServerUrl(value: string): string {
  const trimmed = value.trim().replace(/\/+$/, "");
  if (LEGACY_SERVER_URLS.has(trimmed)) {
    return DEFAULT_SERVER_URL;
  }
  return trimmed || DEFAULT_SETTINGS.serverUrl;
}

export async function getStoredSettings(): Promise<AppSettings> {
  const rawValue = await AsyncStorage.getItem(SETTINGS_KEY);
  if (!rawValue) {
    return DEFAULT_SETTINGS;
  }

  try {
    const parsed = JSON.parse(rawValue) as Partial<AppSettings>;
    return {
      serverUrl: normalizeServerUrl(parsed.serverUrl ?? DEFAULT_SETTINGS.serverUrl),
      theme:
        parsed.theme === "light" || parsed.theme === "zen" || parsed.theme === "dark"
          ? parsed.theme
          : DEFAULT_SETTINGS.theme
    };
  } catch {
    return DEFAULT_SETTINGS;
  }
}

export async function setStoredSettings(settings: AppSettings): Promise<AppSettings> {
  const normalized = {
    serverUrl: normalizeServerUrl(settings.serverUrl),
    theme: settings.theme
  };
  await AsyncStorage.setItem(SETTINGS_KEY, JSON.stringify(normalized));
  return normalized;
}

export function getApiBaseUrl(serverUrl: string): string {
  return `${normalizeServerUrl(serverUrl)}/api/v1`;
}

export function getHealthUrl(serverUrl: string): string {
  return `${normalizeServerUrl(serverUrl)}/health`;
}
