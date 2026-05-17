import { useState } from "react";
import { View } from "react-native";

import { Button, Card, Field, Header, Screen, StatusMessage } from "../components/ui";
import type { Palette } from "../components/ui";

type Props = {
  palette: Palette;
  serverUrl: string;
  error: string;
  onSave: (serverUrl: string) => Promise<void>;
  onRetry: () => Promise<void>;
};

export function ConnectionScreen({ palette, serverUrl, error, onSave, onRetry }: Props) {
  const [nextServerUrl, setNextServerUrl] = useState(serverUrl);
  const [saving, setSaving] = useState(false);
  const [localError, setLocalError] = useState("");

  async function saveAndRetry() {
    setSaving(true);
    setLocalError("");
    try {
      await onSave(nextServerUrl);
    } catch (nextError) {
      setLocalError(nextError instanceof Error ? nextError.message : "Ayar kaydedilemedi.");
    } finally {
      setSaving(false);
    }
  }

  return (
    <Screen palette={palette}>
      <Header
        palette={palette}
        eyebrow="Baglanti"
        title="Server'a ulasilamadi"
        subtitle="Telefon bu bilgisayardaki LifeBase backend adresine ulasabilmeli."
      />
      <Card palette={palette}>
        <Field
          palette={palette}
          label="Server URL"
          value={nextServerUrl}
          onChangeText={setNextServerUrl}
          placeholder="http://100.105.227.116:8001"
        />
        <View style={{ gap: 10 }}>
          <Button
            palette={palette}
            label={saving ? "Kontrol ediliyor..." : "Kaydet ve dene"}
            onPress={saveAndRetry}
            disabled={saving}
          />
          <Button palette={palette} label="Tekrar dene" variant="secondary" onPress={onRetry} />
        </View>
      </Card>
      {error ? <StatusMessage palette={palette} message={error} tone="error" /> : null}
      {localError ? <StatusMessage palette={palette} message={localError} tone="error" /> : null}
      <StatusMessage
        palette={palette}
        message="Tailscale adresi: http://100.105.227.116:8001. Backend bu bilgisayarda acik kalmali."
      />
    </Screen>
  );
}
