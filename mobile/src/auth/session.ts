import AsyncStorage from "@react-native-async-storage/async-storage";
import * as SecureStore from "expo-secure-store";

import type { User } from "../api/types";

const TOKEN_KEY = "lifeos-mobile-access-token";
const USER_KEY = "lifeos-mobile-user";

export type AuthSession = {
  accessToken: string;
  user: User;
};

function normalizeSession(accessToken: string | null, rawUser: string | null): AuthSession | null {
  if (!accessToken || !rawUser) {
    return null;
  }

  try {
    const user = JSON.parse(rawUser) as User;
    if (!user?.id || !user.email) {
      return null;
    }
    return { accessToken, user };
  } catch {
    return null;
  }
}

export async function getStoredSession(): Promise<AuthSession | null> {
  const [accessToken, rawUser] = await Promise.all([
    SecureStore.getItemAsync(TOKEN_KEY),
    AsyncStorage.getItem(USER_KEY)
  ]);
  return normalizeSession(accessToken, rawUser);
}

export async function setStoredSession(session: AuthSession): Promise<void> {
  await Promise.all([
    SecureStore.setItemAsync(TOKEN_KEY, session.accessToken),
    AsyncStorage.setItem(USER_KEY, JSON.stringify(session.user))
  ]);
}

export async function clearStoredSession(): Promise<void> {
  await Promise.all([SecureStore.deleteItemAsync(TOKEN_KEY), AsyncStorage.removeItem(USER_KEY)]);
}
