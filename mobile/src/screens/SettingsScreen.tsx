import { useState } from "react";
import { ScrollView, StyleSheet, Text, View } from "react-native";

import type { HealthPayload, User } from "../api/types";
import type { AppSettings, ThemeName } from "../settings/settings";
import { scheduleTestNotification } from "../notifications/reminders";
import { Button, Card, Field, Header, SegmentedControl, StatusMessage } from "../components/ui";
import type { Palette } from "../components/ui";

type Props = {
  palette: Palette;
  settings: AppSettings;
  health: HealthPayload | null;
  currentUser: User | null;
  onSettingsChange: (settings: AppSettings) => Promise<void>;
  onLogout: () => Promise<void>;
  onRetryConnection: () => Promise<void>;
  onSyncNotifications: () => Promise<void>;
};

export function SettingsScreen({
  palette,
  settings,
  health,
  currentUser,
  onSettingsChange,
  onLogout,
  onRetryConnection,
  onSyncNotifications
}: Props) {
  const [serverUrl, setServerUrl] = useState(settings.serverUrl);
  const [theme, setTheme] = useState<ThemeName>(settings.theme);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");

  async function saveSettings() {
    setSaving(true);
    setMessage("");
    setError("");
    try {
      await onSettingsChange({ serverUrl, theme });
      setMessage("Ayarlar kaydedildi.");
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : "Ayar kaydedilemedi.");
    } finally {
      setSaving(false);
    }
  }

  async function testNotification() {
    setSaving(true);
    setMessage("");
    setError("");
    try {
      await scheduleTestNotification();
      setMessage("Test bildirimi 3 saniye icinde gelmeli.");
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : "Bildirim testi basarisiz.");
    } finally {
      setSaving(false);
    }
  }

  async function syncNotifications() {
    setSaving(true);
    setMessage("");
    setError("");
    try {
      await onSyncNotifications();
      setMessage("Hatirlaticilar Android bildirimlerine senkronize edildi.");
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : "Hatirlaticilar senkronize edilemedi.");
    } finally {
      setSaving(false);
    }
  }

  return (
    <ScrollView
      style={{ backgroundColor: palette.background }}
      contentContainerStyle={styles.content}
      keyboardShouldPersistTaps="handled"
    >
      <Header palette={palette} eyebrow="Ayarlar" title="Tercihler" />

      {currentUser ? (
        <Card palette={palette}>
          <Text style={[styles.itemTitle, { color: palette.text }]}>{currentUser.display_name}</Text>
          <Text style={[styles.muted, { color: palette.muted }]}>{currentUser.email}</Text>
          <Button palette={palette} label="Cikis yap" variant="ghost" onPress={onLogout} />
        </Card>
      ) : (
        <StatusMessage palette={palette} message="Single-user modda token olmadan calisiyor." />
      )}

      <Card palette={palette}>
        <Field palette={palette} label="Server URL" value={serverUrl} onChangeText={setServerUrl} />
        <SegmentedControl
          palette={palette}
          value={theme}
          onChange={setTheme}
          options={[
            { value: "dark", label: "Koyu" },
            { value: "light", label: "Acik" },
            { value: "zen", label: "Zen" }
          ]}
        />
        <Button
          palette={palette}
          label={saving ? "Kaydediliyor..." : "Ayarlari kaydet"}
          onPress={saveSettings}
          disabled={saving}
        />
      </Card>

      <Card palette={palette}>
        <Text style={[styles.sectionTitle, { color: palette.text }]}>Bildirimler</Text>
        <View style={styles.actions}>
          <Button palette={palette} label="Test bildirimi" variant="secondary" onPress={testNotification} />
          <Button palette={palette} label="Senkronize et" variant="secondary" onPress={syncNotifications} />
        </View>
        <Text style={[styles.muted, { color: palette.muted }]}>
          Mobil uygulama web push yerine Android local notification kullanir.
        </Text>
      </Card>

      <Card palette={palette}>
        <Text style={[styles.sectionTitle, { color: palette.text }]}>Server</Text>
        <Text style={[styles.muted, { color: palette.muted }]}>Durum: {health?.status ?? "bilinmiyor"}</Text>
        <Text style={[styles.muted, { color: palette.muted }]}>
          Mod: {health?.mode?.single_user === false ? "login gerekli" : "single-user"}
        </Text>
        <Text style={[styles.muted, { color: palette.muted }]}>
          AI: {health?.ai?.configured ? "hazir" : "anahtar yok veya pasif"}
        </Text>
        <Button palette={palette} label="Health tekrar kontrol" variant="ghost" onPress={onRetryConnection} />
      </Card>

      {message ? <StatusMessage palette={palette} message={message} tone="success" /> : null}
      {error ? <StatusMessage palette={palette} message={error} tone="error" /> : null}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  content: {
    paddingHorizontal: 20,
    paddingTop: 18,
    paddingBottom: 124,
    gap: 18
  },
  itemTitle: {
    fontSize: 18,
    fontWeight: "900"
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: "900"
  },
  muted: {
    fontSize: 13,
    fontWeight: "800",
    lineHeight: 20
  },
  actions: {
    gap: 10
  }
});
