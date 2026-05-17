import { useCallback, useEffect, useState } from "react";
import { Pressable, RefreshControl, ScrollView, StyleSheet, Text, View } from "react-native";

import { fetchWalletSummary } from "../api/wallet";
import type { ApiContext } from "../api/client";
import type { Account, WalletSummary } from "../api/types";
import { Card, Header, LoadingBlock, Metric, StatusMessage } from "../components/ui";
import type { Palette } from "../components/ui";
import { formatMoney, getAccountTypeLabel } from "../utils/format";

type Props = {
  palette: Palette;
  api: ApiContext;
  refreshKey: number;
  onNavigate: (tab: "manage" | "add") => void;
};

function AccountCard({
  palette,
  account,
  onPress,
  delay
}: {
  palette: Palette;
  account: Account;
  onPress: () => void;
  delay: number;
}) {
  const isCredit = account.type === "credit_card";
  const primaryValue = isCredit ? account.available_credit ?? account.balance : account.balance;
  const secondaryValue = isCredit ? account.used_credit : null;

  return (
    <Pressable
      onPress={onPress}
      style={({ pressed }) => [
        {
          opacity: pressed ? 0.9 : 1,
          transform: [{ scale: pressed ? 0.97 : 1 }, { translateY: pressed ? 2 : 0 }]
        }
      ]}
    >
      <Card palette={palette} style={styles.accountCard} delay={delay} elevated>
        <View style={styles.rowBetween}>
          <View style={[styles.accountChip, { borderColor: palette.border, backgroundColor: palette.overlaySoft }]}>
            <Text style={[styles.accountType, { color: palette.primary }]}>
              {getAccountTypeLabel(account.type)}
            </Text>
          </View>
          <Text style={[styles.accountIssuer, { color: palette.muted }]}>{account.issuer ?? account.currency}</Text>
        </View>
        <Text style={[styles.accountName, { color: palette.text }]}>{account.name}</Text>
        <Text style={[styles.accountAmount, { color: palette.text }]}>{formatMoney(primaryValue)}</Text>
        <View style={[styles.accountFooter, { borderTopColor: palette.border }]}>
          <Text style={[styles.muted, { color: palette.muted }]}>
            {secondaryValue != null ? "Kullanilan" : "Bakiye"}
          </Text>
          <Text style={[styles.muted, { color: palette.muted }]}>
            {secondaryValue != null ? formatMoney(secondaryValue) : account.currency}
          </Text>
        </View>
      </Card>
    </Pressable>
  );
}

export function WalletScreen({ palette, api, refreshKey, onNavigate }: Props) {
  const [summary, setSummary] = useState<WalletSummary | null>(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    setError("");
    try {
      const payload = await fetchWalletSummary(api);
      setSummary(payload);
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : "Cuzdan yuklenemedi.");
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, [api]);

  useEffect(() => {
    setLoading(true);
    void load();
  }, [load, refreshKey]);

  const creditAccounts = summary?.accounts.filter((account) => account.type === "credit_card") ?? [];
  const otherAccounts = summary?.accounts.filter((account) => account.type !== "credit_card") ?? [];

  return (
    <ScrollView
      style={{ backgroundColor: palette.background }}
      contentContainerStyle={styles.content}
      refreshControl={
        <RefreshControl
          refreshing={refreshing}
          tintColor={palette.primary}
          onRefresh={() => {
            setRefreshing(true);
            void load();
          }}
        />
      }
    >
      <Header palette={palette} eyebrow="Cuzdan" title="Finans ozeti" />
      {loading ? <LoadingBlock palette={palette} /> : null}
      {error ? <StatusMessage palette={palette} message={error} tone="error" /> : null}

      {summary ? (
        <>
          <Card palette={palette} style={styles.overviewCard} delay={80} elevated>
            <Text style={[styles.muted, { color: palette.muted }]}>Ana Toplam</Text>
            <Text style={[styles.netWorth, { color: palette.text }]}>{formatMoney(summary.net_worth)}</Text>
            <View style={styles.metricsRow}>
              <Metric
                palette={palette}
                label="Bu ay gelir"
                value={formatMoney(summary.monthly_flow.total_income)}
                tone="positive"
              />
              <Metric
                palette={palette}
                label="Bu ay gider"
                value={formatMoney(summary.monthly_flow.total_expense)}
                tone="negative"
              />
            </View>
            <View style={styles.metricsRow}>
              <Metric palette={palette} label="Hesap" value={String(summary.active_account_count)} />
              <Metric palette={palette} label="Kart" value={String(summary.active_card_count)} />
            </View>
          </Card>

          <View style={styles.sectionHeader}>
            <Text style={[styles.sectionTitle, { color: palette.text }]}>Kartlar</Text>
            <Pressable onPress={() => onNavigate("manage")}>
              <Text style={[styles.link, { color: palette.primary }]}>Yonet</Text>
            </Pressable>
          </View>
          {creditAccounts.length ? (
            creditAccounts.map((account, index) => (
              <AccountCard
                key={account.id}
                palette={palette}
                account={account}
                onPress={() => onNavigate("manage")}
                delay={160 + index * 80}
              />
            ))
          ) : (
            <StatusMessage palette={palette} message="Kart ekleyince burada gorunecek." />
          )}

          <View style={styles.sectionHeader}>
            <Text style={[styles.sectionTitle, { color: palette.text }]}>Hesaplar</Text>
            <Pressable onPress={() => onNavigate("manage")}>
              <Text style={[styles.link, { color: palette.primary }]}>Yonet</Text>
            </Pressable>
          </View>
          {otherAccounts.length ? (
            otherAccounts.map((account, index) => (
              <AccountCard
                key={account.id}
                palette={palette}
                account={account}
                onPress={() => onNavigate("manage")}
                delay={220 + index * 80}
              />
            ))
          ) : (
            <StatusMessage palette={palette} message="Banka veya nakit hesap ekleyince burada gorunecek." />
          )}
        </>
      ) : null}
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
  rowBetween: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    gap: 10
  },
  metricsRow: {
    flexDirection: "row",
    gap: 12
  },
  muted: {
    fontSize: 13,
    fontWeight: "800"
  },
  netWorth: {
    fontSize: 46,
    fontWeight: "900",
    letterSpacing: 0
  },
  overviewCard: {
    gap: 18
  },
  sectionHeader: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    marginTop: 4
  },
  sectionTitle: {
    fontSize: 22,
    fontWeight: "900"
  },
  link: {
    fontSize: 14,
    fontWeight: "900"
  },
  accountCard: {
    minHeight: 168
  },
  accountChip: {
    borderWidth: 1,
    borderRadius: 9,
    paddingHorizontal: 10,
    paddingVertical: 5
  },
  accountType: {
    fontSize: 12,
    fontWeight: "900",
    letterSpacing: 0,
    textTransform: "uppercase"
  },
  accountIssuer: {
    fontSize: 14,
    fontWeight: "800"
  },
  accountName: {
    fontSize: 20,
    fontWeight: "900"
  },
  accountAmount: {
    fontSize: 31,
    fontWeight: "900"
  },
  accountFooter: {
    borderTopWidth: 1,
    paddingTop: 14,
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center"
  }
});
