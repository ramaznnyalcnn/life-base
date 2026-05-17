import { useCallback, useEffect, useMemo, useState } from "react";
import { Animated, Pressable, StatusBar, StyleSheet, Text, View } from "react-native";
import { SafeAreaProvider, SafeAreaView } from "react-native-safe-area-context";

import { fetchCurrentUser } from "./src/api/auth";
import { fetchBackendHealth } from "./src/api/client";
import type { ApiContext } from "./src/api/client";
import type { HealthPayload } from "./src/api/types";
import {
  clearStoredSession,
  getStoredSession,
  setStoredSession,
  type AuthSession
} from "./src/auth/session";
import { LoadingBlock, Screen, getPalette } from "./src/components/ui";
import { syncReminderNotifications, syncReminderNotificationsIfAllowed } from "./src/notifications/reminders";
import { AddScreen } from "./src/screens/AddScreen";
import { CalendarScreen } from "./src/screens/CalendarScreen";
import { ConnectionScreen } from "./src/screens/ConnectionScreen";
import { HistoryScreen } from "./src/screens/HistoryScreen";
import { LoginScreen } from "./src/screens/LoginScreen";
import { ManageScreen } from "./src/screens/ManageScreen";
import { SettingsScreen } from "./src/screens/SettingsScreen";
import { WalletScreen } from "./src/screens/WalletScreen";
import {
  DEFAULT_SETTINGS,
  getStoredSettings,
  setStoredSettings,
  type AppSettings
} from "./src/settings/settings";

type TabId = "wallet" | "calendar" | "add" | "history" | "manage" | "settings";

const TABS: Array<{ id: TabId; label: string; icon: string }> = [
  { id: "wallet", label: "Cuzdan", icon: "$" },
  { id: "calendar", label: "Takvim", icon: "31" },
  { id: "add", label: "Ekle", icon: "+" },
  { id: "history", label: "Gecmis", icon: "H" },
  { id: "manage", label: "Yonet", icon: "M" },
  { id: "settings", label: "Ayarlar", icon: "*" }
];

function LifeBaseApp() {
  const [settings, setSettings] = useState<AppSettings>(DEFAULT_SETTINGS);
  const [session, setSession] = useState<AuthSession | null>(null);
  const [health, setHealth] = useState<HealthPayload | null>(null);
  const [requiresLogin, setRequiresLogin] = useState(true);
  const [ready, setReady] = useState(false);
  const [booting, setBooting] = useState(false);
  const [connectionError, setConnectionError] = useState("");
  const [activeTab, setActiveTab] = useState<TabId>("wallet");
  const [refreshKey, setRefreshKey] = useState(0);
  const dockProgress = useMemo(() => new Animated.Value(0), []);
  const pageProgress = useMemo(() => new Animated.Value(1), []);

  const palette = useMemo(() => getPalette(settings.theme), [settings.theme]);
  const api = useMemo<ApiContext>(
    () => ({
      serverUrl: settings.serverUrl,
      accessToken: session?.accessToken
    }),
    [session?.accessToken, settings.serverUrl]
  );

  const bootstrap = useCallback(async (overrideSettings?: AppSettings) => {
    setBooting(true);
    try {
      const nextSettings = overrideSettings ?? (await getStoredSettings());
      setSettings(nextSettings);

      const [storedSession, healthPayload] = await Promise.all([
        getStoredSession(),
        fetchBackendHealth(nextSettings.serverUrl)
      ]);
      const secureMode = healthPayload.mode?.single_user === false;
      let nextSession = storedSession;

      if (secureMode && storedSession?.accessToken) {
        try {
          const user = await fetchCurrentUser({
            serverUrl: nextSettings.serverUrl,
            accessToken: storedSession.accessToken
          });
          nextSession = { accessToken: storedSession.accessToken, user };
          await setStoredSession(nextSession);
        } catch {
          await clearStoredSession();
          nextSession = null;
        }
      }

      setHealth(healthPayload);
      setRequiresLogin(secureMode);
      setSession(nextSession);
      setConnectionError("");
    } catch (nextError) {
      setConnectionError(
        nextError instanceof Error ? nextError.message : "Sunucu baglantisi kurulamadi."
      );
    } finally {
      setReady(true);
      setBooting(false);
    }
  }, []);

  useEffect(() => {
    void bootstrap();
  }, [bootstrap]);

  useEffect(() => {
    Animated.timing(dockProgress, {
      toValue: 1,
      duration: 700,
      useNativeDriver: true
    }).start();
  }, [dockProgress]);

  useEffect(() => {
    pageProgress.setValue(0);
    Animated.timing(pageProgress, {
      toValue: 1,
      duration: 260,
      useNativeDriver: true
    }).start();
  }, [activeTab, pageProgress]);

  useEffect(() => {
    if (!ready || connectionError || (requiresLogin && !session?.accessToken)) {
      return;
    }

    void syncReminderNotificationsIfAllowed(api).catch(() => undefined);
  }, [api, connectionError, ready, requiresLogin, session?.accessToken]);

  async function saveSettings(nextSettings: AppSettings) {
    const normalized = await setStoredSettings(nextSettings);
    setSettings(normalized);
  }

  async function saveSettingsAndBootstrap(nextSettings: AppSettings) {
    const normalized = await setStoredSettings(nextSettings);
    setSettings(normalized);
    await bootstrap(normalized);
  }

  async function handleAuthenticated(nextSession: AuthSession) {
    await setStoredSession(nextSession);
    setSession(nextSession);
    setActiveTab("wallet");
    setRefreshKey((current) => current + 1);
    await bootstrap(settings);
  }

  async function handleLogout() {
    await clearStoredSession();
    setSession(null);
    setActiveTab("wallet");
  }

  function markChanged() {
    setRefreshKey((current) => current + 1);
  }

  async function syncNotifications() {
    await syncReminderNotifications(api);
  }

  function renderActiveScreen() {
    switch (activeTab) {
      case "calendar":
        return (
          <CalendarScreen
            palette={palette}
            api={api}
            refreshKey={refreshKey}
            onChanged={markChanged}
            onSyncNotifications={syncNotifications}
          />
        );
      case "add":
        return (
          <AddScreen
            palette={palette}
            api={api}
            refreshKey={refreshKey}
            onChanged={markChanged}
            onSyncNotifications={syncNotifications}
          />
        );
      case "history":
        return (
          <HistoryScreen palette={palette} api={api} refreshKey={refreshKey} onChanged={markChanged} />
        );
      case "manage":
        return (
          <ManageScreen palette={palette} api={api} refreshKey={refreshKey} onChanged={markChanged} />
        );
      case "settings":
        return (
          <SettingsScreen
            palette={palette}
            settings={settings}
            health={health}
            currentUser={session?.user ?? null}
            onSettingsChange={saveSettingsAndBootstrap}
            onLogout={handleLogout}
            onRetryConnection={() => bootstrap(settings)}
            onSyncNotifications={syncNotifications}
          />
        );
      case "wallet":
      default:
        return (
          <WalletScreen
            palette={palette}
            api={api}
            refreshKey={refreshKey}
            onNavigate={(tab) => setActiveTab(tab)}
          />
        );
    }
  }

  if (!ready) {
    return (
      <SafeAreaView style={[styles.safeArea, { backgroundColor: palette.background }]}>
        <StatusBar barStyle={palette.mode === "light" || palette.mode === "zen" ? "dark-content" : "light-content"} />
        <Screen palette={palette}>
          <LoadingBlock palette={palette} label="Hazirlaniyor..." />
        </Screen>
      </SafeAreaView>
    );
  }

  if (connectionError) {
    return (
      <SafeAreaView style={[styles.safeArea, { backgroundColor: palette.background }]}>
        <StatusBar barStyle={palette.mode === "light" || palette.mode === "zen" ? "dark-content" : "light-content"} />
        <ConnectionScreen
          palette={palette}
          serverUrl={settings.serverUrl}
          error={connectionError}
          onSave={(serverUrl) => saveSettingsAndBootstrap({ ...settings, serverUrl })}
          onRetry={() => bootstrap(settings)}
        />
      </SafeAreaView>
    );
  }

  if (requiresLogin && !session?.accessToken) {
    return (
      <SafeAreaView style={[styles.safeArea, { backgroundColor: palette.background }]}>
        <StatusBar barStyle={palette.mode === "light" || palette.mode === "zen" ? "dark-content" : "light-content"} />
        <LoginScreen
          palette={palette}
          api={api}
          serverUrl={settings.serverUrl}
          onServerUrlChange={async (serverUrl) => {
            await saveSettings({ ...settings, serverUrl });
          }}
          onAuthenticated={handleAuthenticated}
        />
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={[styles.safeArea, { backgroundColor: palette.background }]}>
      <StatusBar barStyle={palette.mode === "light" || palette.mode === "zen" ? "dark-content" : "light-content"} />
      <View style={styles.app}>
        <Animated.View
          style={[
            styles.pageSlot,
            {
              opacity: pageProgress,
              transform: [
                {
                  translateY: pageProgress.interpolate({
                    inputRange: [0, 1],
                    outputRange: [14, 0]
                  })
                }
              ]
            }
          ]}
        >
          {renderActiveScreen()}
        </Animated.View>
        {booting ? (
          <View
            style={[
              styles.bootOverlay,
              {
                backgroundColor: palette.dock,
                borderColor: palette.border
              }
            ]}
          >
            <Text style={[styles.bootText, { color: palette.text }]}>Server kontrol ediliyor...</Text>
          </View>
        ) : null}
        <Animated.View
          style={[
            styles.tabBar,
            {
              backgroundColor: palette.dock,
              borderColor: palette.overlayStrong,
              shadowColor: palette.mode === "dark" ? "#000000" : palette.muted,
              transform: [
                {
                  translateY: dockProgress.interpolate({
                    inputRange: [0, 1],
                    outputRange: [100, 0]
                  })
                }
              ],
              opacity: dockProgress
            }
          ]}
        >
          {TABS.map((tab) => {
            const active = tab.id === activeTab;
            return (
              <Pressable
                key={tab.id}
                onPress={() => setActiveTab(tab.id)}
                style={({ pressed }) => [
                  styles.tabButton,
                  active
                    ? { backgroundColor: palette.overlayMedium }
                    : { backgroundColor: "transparent" },
                  { transform: [{ scale: pressed ? 0.88 : 1 }] }
                ]}
              >
                <Text style={[styles.tabIcon, { color: active ? palette.primaryText : palette.text }]}>
                  {tab.icon}
                </Text>
                <Text style={[styles.tabLabel, { color: active ? palette.primaryText : palette.muted }]}>
                  {tab.label}
                </Text>
                {active ? <View style={[styles.activeDot, { backgroundColor: palette.primary }]} /> : null}
              </Pressable>
            );
          })}
        </Animated.View>
      </View>
    </SafeAreaView>
  );
}

export default function App() {
  return (
    <SafeAreaProvider>
      <LifeBaseApp />
    </SafeAreaProvider>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1
  },
  app: {
    flex: 1
  },
  pageSlot: {
    flex: 1
  },
  tabBar: {
    position: "absolute",
    left: 20,
    right: 20,
    bottom: 14,
    minHeight: 70,
    borderWidth: 1,
    borderRadius: 999,
    padding: 7,
    flexDirection: "row",
    gap: 4,
    elevation: 18,
    shadowOpacity: 0.38,
    shadowRadius: 24,
    shadowOffset: { width: 0, height: 16 }
  },
  tabButton: {
    flex: 1,
    borderRadius: 999,
    alignItems: "center",
    justifyContent: "center",
    minWidth: 0,
    gap: 2,
    paddingHorizontal: 3,
    position: "relative"
  },
  tabIcon: {
    fontSize: 15,
    fontWeight: "900"
  },
  tabLabel: {
    fontSize: 9,
    fontWeight: "900"
  },
  activeDot: {
    position: "absolute",
    bottom: 6,
    width: 4,
    height: 4,
    borderRadius: 999
  },
  bootOverlay: {
    position: "absolute",
    top: 10,
    left: 16,
    right: 16,
    borderRadius: 999,
    borderWidth: 1,
    padding: 10,
    alignItems: "center",
    elevation: 12
  },
  bootText: {
    fontSize: 13,
    fontWeight: "800"
  }
});
