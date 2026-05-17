import { useCallback, useEffect, useMemo, useState } from "react";
import { Alert, Pressable, ScrollView, StyleSheet, Text, View } from "react-native";

import { fetchAccounts } from "../api/accounts";
import type { ApiContext } from "../api/client";
import { deleteTransaction, fetchTransactions, updateTransaction } from "../api/transactions";
import type { Account, Transaction, TransactionType } from "../api/types";
import { Button, Card, Field, Header, LoadingBlock, Metric, SegmentedControl, StatusMessage } from "../components/ui";
import type { Palette } from "../components/ui";
import {
  formatDateTime,
  formatMoney,
  getTransactionTypeLabel,
  parseDateTimeLocalInput,
  toDateTimeLocal,
  toNumber
} from "../utils/format";

type Props = {
  palette: Palette;
  api: ApiContext;
  refreshKey: number;
  onChanged: () => void;
};

type FilterType = TransactionType | "";

type EditForm = {
  accountId: string;
  type: TransactionType;
  amount: string;
  categoryName: string;
  description: string;
  note: string;
  occurredAt: string;
};

function accountName(accounts: Account[], accountId: number): string {
  return accounts.find((account) => account.id === accountId)?.name ?? `#${accountId}`;
}

function toEditForm(transaction: Transaction): EditForm {
  return {
    accountId: String(transaction.account_id),
    type: transaction.type,
    amount: String(transaction.amount),
    categoryName: transaction.category_name ?? "",
    description: transaction.description,
    note: transaction.note ?? "",
    occurredAt: toDateTimeLocal(transaction.occurred_at)
  };
}

function TransactionCard({
  palette,
  transaction,
  accountLabel,
  onEdit,
  onDelete
}: {
  palette: Palette;
  transaction: Transaction;
  accountLabel: string;
  onEdit: () => void;
  onDelete: () => void;
}) {
  const isIncome = transaction.type === "income";
  const isPayment = transaction.type === "payment";
  return (
    <Card palette={palette}>
      <View style={styles.rowBetween}>
        <View style={{ flex: 1 }}>
          <Text style={[styles.itemTitle, { color: palette.text }]}>{transaction.description}</Text>
          <Text style={[styles.muted, { color: palette.muted }]}>
            {accountLabel} - {transaction.category_name ?? getTransactionTypeLabel(transaction.type)}
          </Text>
        </View>
        <Text
          style={[
            styles.amount,
            { color: isIncome ? palette.positive : isPayment ? palette.warning : palette.negative }
          ]}
        >
          {isIncome ? "+" : "-"}
          {formatMoney(transaction.amount)}
        </Text>
      </View>
      <Text style={[styles.muted, { color: palette.muted }]}>{formatDateTime(transaction.occurred_at)}</Text>
      {transaction.note ? <Text style={[styles.note, { color: palette.muted }]}>{transaction.note}</Text> : null}
      <View style={styles.actions}>
        <Button palette={palette} label="Duzenle" variant="secondary" onPress={onEdit} />
        <Button palette={palette} label="Sil" variant="danger" onPress={onDelete} />
      </View>
    </Card>
  );
}

export function HistoryScreen({ palette, api, refreshKey, onChanged }: Props) {
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [filterType, setFilterType] = useState<FilterType>("");
  const [filterAccountId, setFilterAccountId] = useState("");
  const [search, setSearch] = useState("");
  const [editing, setEditing] = useState<Transaction | null>(null);
  const [form, setForm] = useState<EditForm | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    setError("");
    try {
      const [accountPayload, transactionPayload] = await Promise.all([
        fetchAccounts(api),
        fetchTransactions(api, {
          accountId: filterAccountId ? Number(filterAccountId) : null,
          type: filterType,
          search
        })
      ]);
      setAccounts(accountPayload);
      setTransactions(transactionPayload);
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : "Gecmis yuklenemedi.");
    } finally {
      setLoading(false);
    }
  }, [api, filterAccountId, filterType, search]);

  useEffect(() => {
    setLoading(true);
    void load();
  }, [load, refreshKey]);

  const totals = useMemo(() => {
    return transactions.reduce(
      (acc, transaction) => {
        const amount = toNumber(transaction.amount);
        if (transaction.type === "income") {
          acc.income += amount;
        } else if (transaction.type === "payment") {
          acc.payments += amount;
        } else {
          acc.expense += amount;
        }
        return acc;
      },
      { income: 0, expense: 0, payments: 0 }
    );
  }, [transactions]);

  function updateForm<Key extends keyof EditForm>(field: Key, value: EditForm[Key]) {
    setForm((current) => (current ? { ...current, [field]: value } : current));
  }

  async function saveEdit() {
    if (!editing || !form) {
      return;
    }
    setSaving(true);
    setError("");
    try {
      await updateTransaction(api, editing.id, {
        account_id: Number(form.accountId),
        type: form.type,
        amount: form.amount,
        category_name: form.categoryName.trim() || null,
        description: form.description.trim(),
        note: form.note.trim() || null,
        occurred_at: parseDateTimeLocalInput(form.occurredAt)
      });
      setEditing(null);
      setForm(null);
      await load();
      onChanged();
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : "Islem guncellenemedi.");
    } finally {
      setSaving(false);
    }
  }

  function confirmDelete(transaction: Transaction) {
    Alert.alert("Islem silinsin mi?", transaction.description, [
      { text: "Vazgec", style: "cancel" },
      {
        text: "Sil",
        style: "destructive",
        onPress: () => {
          void (async () => {
            setSaving(true);
            setError("");
            try {
              await deleteTransaction(api, transaction.id);
              await load();
              onChanged();
            } catch (nextError) {
              setError(nextError instanceof Error ? nextError.message : "Islem silinemedi.");
            } finally {
              setSaving(false);
            }
          })();
        }
      }
    ]);
  }

  return (
    <ScrollView
      style={{ backgroundColor: palette.background }}
      contentContainerStyle={styles.content}
      keyboardShouldPersistTaps="handled"
    >
      <Header palette={palette} eyebrow="Gecmis" title="Islem hareketleri" />
      <Card palette={palette}>
        <View style={styles.metricsRow}>
          <Metric palette={palette} label="Gelir" value={formatMoney(totals.income)} tone="positive" />
          <Metric palette={palette} label="Gider" value={formatMoney(totals.expense)} tone="negative" />
        </View>
        <View style={styles.metricsRow}>
          <Metric palette={palette} label="Odeme" value={formatMoney(totals.payments)} />
          <Metric palette={palette} label="Adet" value={String(transactions.length)} />
        </View>
      </Card>

      <Card palette={palette}>
        <SegmentedControl
          palette={palette}
          value={filterType}
          onChange={setFilterType}
          options={[
            { value: "", label: "Tum" },
            { value: "expense", label: "Gider" },
            { value: "income", label: "Gelir" },
            { value: "payment", label: "Odeme" }
          ]}
        />
        <Field palette={palette} label="Ara" value={search} onChangeText={setSearch} placeholder="Market, maas..." />
        <Text style={[styles.fieldTitle, { color: palette.muted }]}>Hesap</Text>
        <View style={styles.wrapRow}>
          <Pressable
            onPress={() => setFilterAccountId("")}
            style={[
              styles.chip,
              {
                backgroundColor: filterAccountId ? palette.overlaySoft : palette.primary,
                borderColor: filterAccountId ? palette.border : palette.primary
              }
            ]}
          >
            <Text style={[styles.chipText, { color: filterAccountId ? palette.text : palette.primaryText }]}>Tum</Text>
          </Pressable>
          {accounts.map((account) => (
            <Pressable
              key={account.id}
              onPress={() => setFilterAccountId(String(account.id))}
              style={[
                styles.chip,
                {
                  backgroundColor: filterAccountId === String(account.id) ? palette.primary : palette.overlaySoft,
                  borderColor: filterAccountId === String(account.id) ? palette.primary : palette.border
                }
              ]}
            >
              <Text
                style={[
                  styles.chipText,
                  { color: filterAccountId === String(account.id) ? palette.primaryText : palette.text }
                ]}
              >
                {account.name}
              </Text>
            </Pressable>
          ))}
        </View>
        <Button palette={palette} label="Filtreyi uygula" variant="secondary" onPress={() => void load()} />
      </Card>

      {editing && form ? (
        <Card palette={palette}>
          <Text style={[styles.sectionTitle, { color: palette.text }]}>Islemi duzenle</Text>
          <SegmentedControl
            palette={palette}
            value={form.type}
            onChange={(value) => updateForm("type", value)}
            options={[
              { value: "expense", label: "Gider" },
              { value: "income", label: "Gelir" },
              { value: "payment", label: "Odeme" }
            ]}
          />
          <Field
            palette={palette}
            label="Tutar"
            value={form.amount}
            onChangeText={(value) => updateForm("amount", value)}
            keyboardType="decimal-pad"
          />
          <Field
            palette={palette}
            label="Hesap ID"
            value={form.accountId}
            onChangeText={(value) => updateForm("accountId", value)}
            keyboardType="numeric"
          />
          <Field
            palette={palette}
            label="Kategori"
            value={form.categoryName}
            onChangeText={(value) => updateForm("categoryName", value)}
          />
          <Field
            palette={palette}
            label="Aciklama"
            value={form.description}
            onChangeText={(value) => updateForm("description", value)}
          />
          <Field palette={palette} label="Not" value={form.note} onChangeText={(value) => updateForm("note", value)} />
          <Field
            palette={palette}
            label="Tarih saat"
            value={form.occurredAt}
            onChangeText={(value) => updateForm("occurredAt", value)}
            placeholder="YYYY-MM-DDTHH:MM"
          />
          <View style={styles.actions}>
            <Button palette={palette} label="Kaydet" onPress={saveEdit} disabled={saving} />
            <Button
              palette={palette}
              label="Vazgec"
              variant="ghost"
              onPress={() => {
                setEditing(null);
                setForm(null);
              }}
            />
          </View>
        </Card>
      ) : null}

      {loading ? <LoadingBlock palette={palette} /> : null}
      {error ? <StatusMessage palette={palette} message={error} tone="error" /> : null}

      {transactions.length ? (
        transactions.map((transaction) => (
          <TransactionCard
            key={transaction.id}
            palette={palette}
            transaction={transaction}
            accountLabel={accountName(accounts, transaction.account_id)}
            onEdit={() => {
              setEditing(transaction);
              setForm(toEditForm(transaction));
            }}
            onDelete={() => confirmDelete(transaction)}
          />
        ))
      ) : (
        <StatusMessage palette={palette} message="Filtreye uygun islem yok." />
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
    alignItems: "center",
    justifyContent: "space-between",
    gap: 12
  },
  metricsRow: {
    flexDirection: "row",
    gap: 12
  },
  itemTitle: {
    fontSize: 16,
    fontWeight: "900"
  },
  sectionTitle: {
    fontSize: 20,
    fontWeight: "900"
  },
  muted: {
    fontSize: 13,
    fontWeight: "800"
  },
  amount: {
    fontSize: 16,
    fontWeight: "900"
  },
  note: {
    fontSize: 14,
    lineHeight: 20
  },
  actions: {
    flexDirection: "row",
    gap: 10
  },
  wrapRow: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 8
  },
  chip: {
    minHeight: 36,
    borderRadius: 12,
    borderWidth: 1,
    paddingHorizontal: 11,
    alignItems: "center",
    justifyContent: "center"
  },
  chipText: {
    fontSize: 13,
    fontWeight: "800"
  },
  fieldTitle: {
    fontSize: 12,
    fontWeight: "800",
    letterSpacing: 0,
    textTransform: "uppercase"
  }
});
