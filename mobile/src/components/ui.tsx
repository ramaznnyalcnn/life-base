import type { ReactNode } from "react";
import { useEffect, useRef } from "react";
import {
  ActivityIndicator,
  Animated,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
  type StyleProp,
  type ViewStyle
} from "react-native";

import type { ThemeName } from "../settings/settings";

export type Palette = {
  mode: ThemeName;
  background: string;
  surface: string;
  surfaceAlt: string;
  surfaceHover: string;
  cardMeta: string;
  dock: string;
  overlaySoft: string;
  overlayMedium: string;
  overlayStrong: string;
  accentGlow: string;
  text: string;
  muted: string;
  border: string;
  primary: string;
  primaryText: string;
  positive: string;
  negative: string;
  warning: string;
};

export function getPalette(theme: ThemeName): Palette {
  if (theme === "light") {
    return {
      mode: theme,
      background: "#f7f7f9",
      surface: "#ffffff",
      surfaceAlt: "#f3f4f6",
      surfaceHover: "#f9fafb",
      cardMeta: "#f3f4f6",
      dock: "rgba(255,255,255,0.90)",
      overlaySoft: "rgba(0,0,0,0.03)",
      overlayMedium: "rgba(0,0,0,0.06)",
      overlayStrong: "rgba(0,0,0,0.10)",
      accentGlow: "rgba(15,23,42,0.15)",
      text: "#111827",
      muted: "#6b7280",
      border: "rgba(0,0,0,0.08)",
      primary: "#0f172a",
      primaryText: "#ffffff",
      positive: "#059669",
      negative: "#dc2626",
      warning: "#d97706"
    };
  }

  if (theme === "zen") {
    return {
      mode: theme,
      background: "#f3f0eb",
      surface: "#fcfaf8",
      surfaceAlt: "rgba(138,126,114,0.08)",
      surfaceHover: "#ffffff",
      cardMeta: "rgba(138,126,114,0.08)",
      dock: "rgba(252,250,248,0.85)",
      overlaySoft: "rgba(138,126,114,0.04)",
      overlayMedium: "rgba(138,126,114,0.08)",
      overlayStrong: "rgba(138,126,114,0.12)",
      accentGlow: "rgba(234,88,12,0.15)",
      text: "#2c2621",
      muted: "#7d7268",
      border: "rgba(138,126,114,0.15)",
      primary: "#ea580c",
      primaryText: "#ffffff",
      positive: "#14b8a6",
      negative: "#e11d48",
      warning: "#d97706"
    };
  }

  return {
    mode: theme,
    background: "#0a0a0a",
    surface: "#141414",
    surfaceAlt: "rgba(255,255,255,0.06)",
    surfaceHover: "#1e1e1e",
    cardMeta: "rgba(255,255,255,0.06)",
    dock: "rgba(20,20,20,0.70)",
    overlaySoft: "rgba(255,255,255,0.03)",
    overlayMedium: "rgba(255,255,255,0.06)",
    overlayStrong: "rgba(255,255,255,0.10)",
    accentGlow: "rgba(99,91,255,0.22)",
    text: "#ededed",
    muted: "#a1a1aa",
    border: "rgba(255,255,255,0.08)",
    primary: "#635bff",
    primaryText: "#ffffff",
    positive: "#10b981",
    negative: "#ef4444",
    warning: "#f59e0b"
  };
}

type PaletteProp = {
  palette: Palette;
};

export function Screen({
  palette,
  children,
  scroll = true
}: PaletteProp & { children: ReactNode; scroll?: boolean }) {
  if (!scroll) {
    return <View style={[styles.screen, { backgroundColor: palette.background }]}>{children}</View>;
  }

  return (
    <ScrollView
      style={{ backgroundColor: palette.background }}
      contentContainerStyle={styles.screenContent}
      keyboardShouldPersistTaps="handled"
      showsVerticalScrollIndicator={false}
    >
      {children}
    </ScrollView>
  );
}

export function Header({
  palette,
  eyebrow,
  title,
  subtitle
}: PaletteProp & { eyebrow: string; title: string; subtitle?: string }) {
  return (
    <View style={styles.header}>
      <View style={styles.headerMeta}>
        <View style={[styles.brandMark, { backgroundColor: palette.primary }]}>
          <View style={styles.brandMarkRow}>
            <View style={[styles.brandMarkTile, { backgroundColor: palette.primaryText }]} />
            <View style={[styles.brandMarkTile, { backgroundColor: palette.primaryText, opacity: 0.72 }]} />
          </View>
          <View style={styles.brandMarkRow}>
            <View style={[styles.brandMarkTile, { backgroundColor: palette.primaryText, opacity: 0.72 }]} />
            <View style={[styles.brandMarkTile, { backgroundColor: palette.primaryText }]} />
          </View>
        </View>
        <Text style={[styles.eyebrow, { color: palette.primary }]}>{eyebrow}</Text>
      </View>
      <Text style={[styles.title, { color: palette.text }]}>{title}</Text>
      {subtitle ? <Text style={[styles.subtitle, { color: palette.muted }]}>{subtitle}</Text> : null}
    </View>
  );
}

export function Card({
  palette,
  children,
  style,
  delay = 0,
  elevated = false
}: PaletteProp & {
  children: ReactNode;
  style?: StyleProp<ViewStyle>;
  delay?: number;
  elevated?: boolean;
}) {
  const progress = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    Animated.timing(progress, {
      toValue: 1,
      duration: 520,
      delay,
      useNativeDriver: true
    }).start();
  }, [delay, progress]);

  return (
    <Animated.View
      style={[
        styles.card,
        {
          backgroundColor: palette.surface,
          borderColor: palette.border,
          shadowColor: palette.mode === "dark" ? "#000000" : palette.muted,
          shadowOpacity: elevated ? 0.34 : 0.22,
          shadowRadius: elevated ? 28 : 18,
          shadowOffset: { width: 0, height: elevated ? 16 : 8 },
          opacity: progress,
          transform: [
            {
              translateY: progress.interpolate({
                inputRange: [0, 1],
                outputRange: [24, 0]
              })
            },
            {
              scale: progress.interpolate({
                inputRange: [0, 1],
                outputRange: [0.98, 1]
              })
            }
          ]
        },
        style
      ]}
    >
      {children}
    </Animated.View>
  );
}

export function Button({
  palette,
  label,
  onPress,
  variant = "primary",
  disabled = false
}: PaletteProp & {
  label: string;
  onPress: () => void;
  variant?: "primary" | "secondary" | "ghost" | "danger";
  disabled?: boolean;
}) {
  const isPrimary = variant === "primary";
  const isDanger = variant === "danger";
  return (
    <Pressable
      onPress={onPress}
      disabled={disabled}
      style={({ pressed }) => [
        styles.button,
        {
          backgroundColor: isPrimary
            ? palette.primary
            : isDanger
              ? palette.negative
              : variant === "secondary"
                ? palette.overlayMedium
                : "transparent",
          borderColor: variant === "ghost" ? palette.border : palette.overlayStrong,
          opacity: disabled ? 0.5 : 1,
          shadowColor: isPrimary ? palette.primary : "#000000",
          shadowOpacity: isPrimary ? 0.28 : 0,
          shadowRadius: isPrimary ? 18 : 0,
          shadowOffset: { width: 0, height: 8 },
          transform: [{ scale: pressed && !disabled ? 0.96 : 1 }]
        }
      ]}
    >
      <Text
        style={[
          styles.buttonText,
          {
            color: isPrimary || isDanger ? palette.primaryText : palette.text
          }
        ]}
      >
        {label}
      </Text>
    </Pressable>
  );
}

export function Field({
  palette,
  label,
  value,
  onChangeText,
  placeholder,
  keyboardType = "default",
  secureTextEntry = false,
  multiline = false
}: PaletteProp & {
  label: string;
  value: string;
  onChangeText: (value: string) => void;
  placeholder?: string;
  keyboardType?: "default" | "email-address" | "numeric" | "decimal-pad";
  secureTextEntry?: boolean;
  multiline?: boolean;
}) {
  return (
    <View style={styles.field}>
      <Text style={[styles.fieldLabel, { color: palette.muted }]}>{label}</Text>
      <TextInput
        value={value}
        onChangeText={onChangeText}
        placeholder={placeholder}
        placeholderTextColor={palette.muted}
        keyboardType={keyboardType}
        secureTextEntry={secureTextEntry}
        multiline={multiline}
        style={[
          styles.input,
          multiline ? styles.inputMultiline : null,
          {
            backgroundColor: palette.overlaySoft,
            borderColor: palette.border,
            color: palette.text
          }
        ]}
      />
    </View>
  );
}

export function SegmentedControl<T extends string>({
  palette,
  value,
  options,
  onChange
}: PaletteProp & {
  value: T;
  options: Array<{ value: T; label: string }>;
  onChange: (value: T) => void;
}) {
  return (
    <View style={[styles.segmented, { backgroundColor: palette.overlaySoft, borderColor: palette.border }]}>
      {options.map((option) => {
        const active = option.value === value;
        return (
          <Pressable
            key={option.value}
            onPress={() => onChange(option.value)}
            style={({ pressed }) => [
              styles.segment,
              active ? { backgroundColor: palette.overlayStrong } : null,
              { transform: [{ scale: pressed ? 0.97 : 1 }] }
            ]}
          >
            <Text style={[styles.segmentText, { color: active ? palette.text : palette.muted }]}>
              {option.label}
            </Text>
          </Pressable>
        );
      })}
    </View>
  );
}

export function StatusMessage({
  palette,
  message,
  tone = "neutral"
}: PaletteProp & { message: string; tone?: "neutral" | "error" | "success" | "warning" }) {
  const color =
    tone === "error"
      ? palette.negative
      : tone === "success"
        ? palette.positive
        : tone === "warning"
          ? palette.warning
          : palette.muted;

  return (
    <View style={[styles.status, { borderColor: color, backgroundColor: palette.overlaySoft }]}>
      <Text style={[styles.statusText, { color }]}>{message}</Text>
    </View>
  );
}

export function LoadingBlock({ palette, label = "Yukleniyor..." }: PaletteProp & { label?: string }) {
  return (
    <Card palette={palette}>
      <View style={styles.loadingRow}>
        <ActivityIndicator color={palette.primary} />
        <Text style={[styles.subtitle, { color: palette.muted }]}>{label}</Text>
      </View>
    </Card>
  );
}

export function Metric({
  palette,
  label,
  value,
  tone = "neutral"
}: PaletteProp & { label: string; value: string; tone?: "neutral" | "positive" | "negative" }) {
  const color = tone === "positive" ? palette.positive : tone === "negative" ? palette.negative : palette.text;
  return (
    <View style={[styles.metric, { backgroundColor: palette.cardMeta, borderColor: palette.border }]}>
      <Text style={[styles.metricLabel, { color: palette.muted }]}>{label}</Text>
      <Text style={[styles.metricValue, { color }]}>{value}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1
  },
  screenContent: {
    paddingHorizontal: 20,
    paddingTop: 18,
    paddingBottom: 124,
    gap: 18
  },
  header: {
    gap: 7,
    marginBottom: 4
  },
  headerMeta: {
    flexDirection: "row",
    alignItems: "center",
    gap: 8
  },
  brandMark: {
    width: 28,
    height: 28,
    borderRadius: 9,
    padding: 6,
    gap: 3
  },
  brandMarkRow: {
    flex: 1,
    flexDirection: "row",
    gap: 3
  },
  brandMarkTile: {
    flex: 1,
    borderRadius: 2
  },
  eyebrow: {
    fontSize: 12,
    fontWeight: "900",
    letterSpacing: 0,
    textTransform: "uppercase"
  },
  title: {
    fontSize: 34,
    fontWeight: "900",
    letterSpacing: 0
  },
  subtitle: {
    fontSize: 15,
    lineHeight: 22
  },
  card: {
    borderWidth: 1,
    borderRadius: 24,
    padding: 22,
    gap: 14,
    elevation: 6,
    overflow: "hidden"
  },
  button: {
    minHeight: 48,
    borderRadius: 999,
    borderWidth: 1,
    alignItems: "center",
    justifyContent: "center",
    paddingHorizontal: 18,
    paddingVertical: 12
  },
  buttonText: {
    fontSize: 14,
    fontWeight: "800",
    letterSpacing: 0
  },
  field: {
    gap: 8
  },
  fieldLabel: {
    fontSize: 12,
    fontWeight: "900",
    letterSpacing: 0,
    textTransform: "uppercase"
  },
  input: {
    minHeight: 52,
    borderWidth: 1,
    borderRadius: 18,
    paddingHorizontal: 16,
    paddingVertical: 12,
    fontSize: 16
  },
  inputMultiline: {
    minHeight: 112,
    textAlignVertical: "top"
  },
  segmented: {
    flexDirection: "row",
    borderRadius: 16,
    borderWidth: 1,
    padding: 4,
    gap: 4
  },
  segment: {
    flex: 1,
    minHeight: 40,
    borderRadius: 12,
    alignItems: "center",
    justifyContent: "center",
    paddingHorizontal: 8
  },
  segmentText: {
    fontSize: 13,
    fontWeight: "800",
    textAlign: "center"
  },
  status: {
    borderWidth: 1,
    borderRadius: 18,
    padding: 14
  },
  statusText: {
    fontSize: 14,
    fontWeight: "800",
    lineHeight: 20
  },
  loadingRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 10
  },
  metric: {
    flex: 1,
    minWidth: 120,
    borderRadius: 18,
    borderWidth: 1,
    padding: 16,
    gap: 6
  },
  metricLabel: {
    fontSize: 13,
    fontWeight: "800"
  },
  metricValue: {
    fontSize: 20,
    fontWeight: "900"
  }
});
