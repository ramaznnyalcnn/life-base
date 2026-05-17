import { useState } from "react";
import { View } from "react-native";

import { login } from "../api/auth";
import type { ApiContext } from "../api/client";
import type { AuthSession } from "../auth/session";
import { Button, Card, Field, Header, Screen, StatusMessage } from "../components/ui";
import type { Palette } from "../components/ui";

type Props = {
  palette: Palette;
  api: ApiContext;
  serverUrl: string;
  onServerUrlChange: (value: string) => Promise<void>;
  onAuthenticated: (session: AuthSession) => Promise<void>;
};

export function LoginScreen({
  palette,
  api,
  serverUrl,
  onServerUrlChange,
  onAuthenticated
}: Props) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [nextServerUrl, setNextServerUrl] = useState(serverUrl);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  async function handleLogin() {
    setLoading(true);
    setError("");
    try {
      await onServerUrlChange(nextServerUrl);
      const response = await login({ ...api, serverUrl: nextServerUrl }, {
        email: email.trim().toLowerCase(),
        password
      });
      await onAuthenticated({
        accessToken: response.access_token,
        user: response.user
      });
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : "Giris yapilamadi.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <Screen palette={palette}>
      <Header
        palette={palette}
        eyebrow="life-base"
        title="Giris yap"
        subtitle="Backend secure modda calisiyor. Token telefonda SecureStore icinde saklanir."
      />
      <Card palette={palette}>
        <Field
          palette={palette}
          label="Server URL"
          value={nextServerUrl}
          onChangeText={setNextServerUrl}
          placeholder="http://lifeos:8000"
        />
        <Field
          palette={palette}
          label="E-posta"
          value={email}
          onChangeText={setEmail}
          keyboardType="email-address"
          placeholder="owner@example.com"
        />
        <Field
          palette={palette}
          label="Sifre"
          value={password}
          onChangeText={setPassword}
          secureTextEntry
          placeholder="********"
        />
        <View style={{ gap: 10 }}>
          <Button
            palette={palette}
            label={loading ? "Giris yapiliyor..." : "Giris yap"}
            onPress={handleLogin}
            disabled={loading || !email.trim() || password.length < 8}
          />
        </View>
      </Card>
      {error ? <StatusMessage palette={palette} message={error} tone="error" /> : null}
    </Screen>
  );
}
