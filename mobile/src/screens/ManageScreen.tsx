import { useCallback, useEffect, useState } from "react";
import { Pressable, ScrollView, StyleSheet, Text, View } from "react-native";

import { createAccount, fetchAccounts, updateAccount } from "../api/accounts";
import type { AccountPayload } from "../api/accounts";
import type { ApiContext } from "../api/client";
import { fetchCardStatements } from "../api/wallet";
import type { Account, AccountType, CardStatementSummary } from "../api/types";
import { Button, Card, Field, Header, LoadingBlock, SegmentedControl, StatusMessage } from "../components/ui";
import type { Palette } from "../components/ui";
import { formatDateOnly, formatMoney, getAccountTypeLabel } from "../utils/format";

type Props = {
  palette: Palette;
  api: ApiContext;
  refreshKey: number;
  onChanged: () => void;
};

type FormState = {
  name: string;
  type: AccountType;
  currency: string;
  balance: string;
  creditLimit: string;
  statementDay: string;
  dueDay: string;
  issuer: string;
  isActive: boolean;
};

const INITIAL_FORM: FormState = {
  name: "",
  type: "bank",
  currency: "TRY",
  balance: "",
  creditLimit: "",
  statementDay: "",
  dueDay: "",
  issuer: "",
  isActive: true
};

function toPayload(form: FormState): AccountPayload {
  return {
    name: form.name.trim(),
    type: form.type,
    currency: form.currency.trim().toUpperCase() || "TRY",
    balance: form.balance || "0",
    credit_limit: form.type === "credit_card" && form.creditLimit ? form.creditLimit : null,
    statement_day: form.type === "credit_card" && form.statementDay ? Number(form.statementDay) : null,
    due_day: form.type === "credit_card" && form.dueDay ? Number(form.dueDay) : null,
    issuer: form.issuer.trim() || null,
    is_active: form.isActive
  };
}

function fromAccount(account: Account): FormState {
  return {
    name: account.name,
    type: account.type,
    currency: account.currency,
    balance: String(account.balance ?? "0"),
    creditLimit: account.credit_limit == null ? "" : String(account.credit_limit),
    statementDay: account.statement_day == null ? "" : String(account.statement_day),
    dueDay: account.due_day == null ? "" : String(account.due_day),
    issuer: account.issuer ?? "",
    isActive: account.is_active
  };
}

function StatementCard({
  palette,
  statement
}: {
  palette: Palette;
  statement: CardStatementSummary;
}) {
  return (
    <Card palette={palette}>
      <View style={styles.rowBetween}>
        <Text style={[styles.itemTitle, { color: palette.text }]}>{statement.account_name}</Text>
        <Text style={[styles.badge, { color: palette.primary }]}>{statement.statement_month ?? "Ekstre yok"}</Text>
      </View>
      <View style={styles.metricsGrid}>
        <View>
          <Text style={[styles.muted, { color: palette.muted }]}>Harcama</Text>
          <Text style={[styles.amount, { color: palette.negative }]}>{formatMoney(statement.statement_amount)}</Text>
        </View>
        <View>
          <Text style={[styles.muted, { color: palette.muted }]}>Odeme</Text>
          <Text style={[styles.amount, { color: palette.positive }]}>{formatMoney(statement.payment_activity)}</Text>
        </View>
      </View>
      <Text style={[styles.muted, { color: palette.muted }]}>
        {formatDateOnly(statement.period_start)} - {formatDateOnly(statement.period_end)} - Son odeme:{" "}
        {formatDateOnly(statement.due_date)}
      </Text>
    </Card>
  );
}

export function ManageScreen({ palette, api, refreshKey, onChanged }: Props) {
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [statements, setStatements] = useState<CardStatementSummary[]>([]);
  const [form, setForm] = useState<FormState>(INITIAL_FORM);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [showForm, setShowForm] = useState(false);
  const [error, setError] = useState("");
  const [message, setMessage] = useState("");

  const load = useCallback(async () => {
    setError("");
    try {
      const [accountPayload, statementPayload] = await Promise.all([
        fetchAccounts(api),
        fetchCardStatements(api)
      ]);
      setAccounts(accountPayload);
      setStatements(statementPayload);
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : "Hesaplar yuklenemedi.");
    } finally {
      setLoading(false);
    }
  }, [api]);

  useEffect(() => {
    setLoading(true);
    void load();
  }, [load, refreshKey]);

  function updateForm<Key extends keyof FormState>(field: Key, value: FormState[Key]) {
    setForm((current) => ({ ...current, [field]: value }));
  }

  function resetForm() {
    setForm(INITIAL_FORM);
    setEditingId(null);
    setShowForm(false);
  }

  async function save() {
    if (!form.name.trim()) {
      setError("Hesap adi zorunlu.");
      return;
    }
    if (form.type === "credit_card" && !form.creditLimit) {
      setError("Kredi karti icin limit zorunlu.");
      return;
    }

    setSaving(true);
    setError("");
    setMessage("");
    try {
      if (editingId) {
        await updateAccount(api, editingId, toPayload(form));
        setMessage("Hesap guncellendi.");
      } else {
        await createAccount(api, toPayload(form));
        setMessage("Hesap eklendi.");
      }
      resetForm();
      await load();
      onChanged();
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : "Hesap kaydedilemedi.");
    } finally {
      setSaving(false);
    }
  }

  async function toggleActive(account: Account) {
    setSaving(true);
    setError("");
    try {
      await updateAccount(api, account.id, { is_active: !account.is_active });
      await load();
      onChanged();
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : "Durum guncellenemedi.");
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
      <Header palette={palette} eyebrow="Yonet" title="Hesap ve kartlar" />
      <Button
        palette={palette}
        label={showForm ? "Formu kapat" : "Yeni hesap veya kart"}
        variant="secondary"
        onPress={() => setShowForm((current) => !current)}
      />
      {loading ? <LoadingBlock palette={palette} /> : null}
      {error ? <StatusMessage palette={palette} message={error} tone="error" /> : null}
      {message ? <StatusMessage palette={palette} message={message} tone="success" /> : null}

      {showForm ? (
        <Card palette={palette}>
          <SegmentedControl
            palette={palette}
            value={form.type}
            onChange={(value) => updateForm("type", value)}
            options={[
              { value: "bank", label: "Banka" },
              { value: "cash", label: "Nakit" },
              { value: "credit_card", label: "Kart" }
            ]}
          />
          <Field palette={palette} label="Ad" value={form.name} onChangeText={(value) => updateForm("name", value)} />
          <Field
            palette={palette}
            label="Para birimi"
            value={form.currency}
            onChangeText={(value) => updateForm("currency", value)}
          />
          <Field
            palette={palette}
            label="Bakiye"
            value={form.balance}
            onChangeText={(value) => updateForm("balance", value)}
            keyboardType="decimal-pad"
          />
          {form.type === "credit_card" ? (
            <>
              <Field
                palette={palette}
                label="Limit"
                value={form.creditLimit}
                onChangeText={(value) => updateForm("creditLimit", value)}
                keyboardType="decimal-pad"
              />
              <Field
                palette={palette}
                label="Ekstre gunu"
                value={form.statementDay}
                onChangeText={(value) => updateForm("statementDay", value)}
                keyboardType="numeric"
              />
              <Field
                palette={palette}
                label="Son odeme gunu"
                value={form.dueDay}
                onChangeText={(value) => updateForm("dueDay", value)}
                keyboardType="numeric"
              />
              <Field
                palette={palette}
                label="Banka/issuer"
                value={form.issuer}
                onChangeText={(value) => updateForm("issuer", value)}
              />
            </>
          ) : null}
          <Button palette={palette} label={saving ? "Kaydediliyor..." : "Kaydet"} onPress={save} disabled={saving} />
          {editingId ? <Button palette={palette} label="Vazgec" variant="ghost" onPress={resetForm} /> : null}
        </Card>
      ) : null}

      <Text style={[styles.sectionTitle, { color: palette.text }]}>Hesaplar</Text>
      {accounts.length ? (
        accounts.map((account) => (
          <Card key={account.id} palette={palette}>
            <View style={styles.rowBetween}>
              <View style={{ flex: 1 }}>
                <Text style={[styles.itemTitle, { color: palette.text }]}>{account.name}</Text>
                <Text style={[styles.muted, { color: palette.muted }]}>
                  {getAccountTypeLabel(account.type)} - {account.is_active ? "Aktif" : "Pasif"}
                </Text>
              </View>
              <Text style={[styles.amount, { color: palette.text }]}>{formatMoney(account.balance)}</Text>
            </View>
            {account.type === "credit_card" ? (
              <Text style={[styles.muted, { color: palette.muted }]}>
                Limit {formatMoney(account.credit_limit)} - Kullanilan {formatMoney(account.used_credit)}
              </Text>
            ) : null}
            <View style={styles.actions}>
              <Button
                palette={palette}
                label="Duzenle"
                variant="secondary"
                onPress={() => {
                  setForm(fromAccount(account));
                  setEditingId(account.id);
                  setShowForm(true);
                }}
              />
              <Button
                palette={palette}
                label={account.is_active ? "Pasif yap" : "Aktif yap"}
                variant="ghost"
                onPress={() => void toggleActive(account)}
                disabled={saving}
              />
            </View>
          </Card>
        ))
      ) : (
        <StatusMessage palette={palette} message="Henuz hesap yok." />
      )}

      <Text style={[styles.sectionTitle, { color: palette.text }]}>Ekstreler</Text>
      {statements.length ? (
        statements.map((statement) => (
          <StatementCard key={statement.account_id} palette={palette} statement={statement} />
        ))
      ) : (
        <StatusMessage palette={palette} message="Kart ekstresi yok." />
      )}
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
    gap: 12
  },
  sectionTitle: {
    fontSize: 21,
    fontWeight: "900",
    marginTop: 4
  },
  itemTitle: {
    fontSize: 17,
    fontWeight: "900"
  },
  muted: {
    fontSize: 13,
    fontWeight: "800"
  },
  badge: {
    fontSize: 12,
    fontWeight: "900",
    textTransform: "uppercase"
  },
  amount: {
    fontSize: 16,
    fontWeight: "900"
  },
  metricsGrid: {
    flexDirection: "row",
    justifyContent: "space-between",
    gap: 16
  },
  actions: {
    flexDirection: "row",
    gap: 10
  }
});
