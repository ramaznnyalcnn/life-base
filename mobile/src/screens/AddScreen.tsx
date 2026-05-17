import { useCallback, useEffect, useState } from "react";
import { Pressable, ScrollView, StyleSheet, Text, View } from "react-native";

import { fetchAccounts } from "../api/accounts";
import type { ApiContext } from "../api/client";
import { executeAI, clarifyAI } from "../api/ai";
import { createEvent, createRecurringEvent } from "../api/events";
import { createMedication } from "../api/medications";
import { createTransaction } from "../api/transactions";
import type { Account, TransactionType } from "../api/types";
import { Button, Card, Field, Header, SegmentedControl, StatusMessage } from "../components/ui";
import type { Palette } from "../components/ui";
import { nowTimeInput, todayInput, toIsoFromDateTime } from "../utils/format";

type Props = {
  palette: Palette;
  api: ApiContext;
  refreshKey: number;
  onChanged: () => void;
  onSyncNotifications: () => Promise<void>;
};

type TabId = "transaction" | "event" | "routine" | "medication" | "ai";

const EXPENSE_CATEGORIES = ["Market", "Yeme-Icme", "Kahve", "Fatura", "Abonelik", "Ulasim", "Saglik", "Diger"];
const INCOME_CATEGORIES = ["Maas", "Ek Gelir", "Yatirim", "Prim", "Diger Gelir"];
const PAYMENT_CATEGORIES = ["Kredi Karti Odemesi", "Borc Odemesi", "Diger Odeme"];
const WEEKDAYS = ["Pzt", "Sal", "Car", "Per", "Cum", "Cmt", "Paz"];
const TIME_PATTERN = /^([01]\d|2[0-3]):[0-5]\d$/;

function getCategoryList(type: TransactionType): string[] {
  if (type === "income") {
    return INCOME_CATEGORIES;
  }
  if (type === "payment") {
    return PAYMENT_CATEGORIES;
  }
  return EXPENSE_CATEGORIES;
}

function parseDoseTimes(value: string): string[] {
  const times = value
    .split(/[,\s]+/)
    .map((part) => part.trim())
    .filter(Boolean);
  const invalid = times.find((part) => !TIME_PATTERN.test(part));

  if (invalid) {
    throw new Error("Saatler HH:MM formatinda olmali.");
  }

  return Array.from(new Set(times)).sort();
}

function Chip({
  palette,
  label,
  active,
  onPress,
  activeColor
}: {
  palette: Palette;
  label: string;
  active: boolean;
  onPress: () => void;
  activeColor?: string;
}) {
  return (
    <Pressable
      onPress={onPress}
      style={({ pressed }) => [
        styles.chip,
        {
          backgroundColor: active ? activeColor ?? palette.primary : palette.overlaySoft,
          borderColor: active ? activeColor ?? palette.primary : palette.border,
          transform: [{ scale: pressed ? 0.96 : 1 }]
        }
      ]}
    >
      <Text style={[styles.chipText, { color: active ? palette.primaryText : palette.text }]}>{label}</Text>
    </Pressable>
  );
}

function AccountPicker({
  palette,
  accounts,
  value,
  onChange
}: {
  palette: Palette;
  accounts: Account[];
  value: string;
  onChange: (value: string) => void;
}) {
  if (!accounts.length) {
    return <StatusMessage palette={palette} message="Once Yonet ekranindan hesap ekleyin." tone="warning" />;
  }

  return (
    <View style={styles.wrapRow}>
      {accounts.map((account) => (
        <Chip
          key={account.id}
          palette={palette}
          label={account.name}
          active={value === String(account.id)}
          onPress={() => onChange(String(account.id))}
        />
      ))}
    </View>
  );
}

function TransactionForm({
  palette,
  api,
  accounts,
  onSaved
}: {
  palette: Palette;
  api: ApiContext;
  accounts: Account[];
  onSaved: () => void;
}) {
  const [type, setType] = useState<TransactionType>("expense");
  const [amount, setAmount] = useState("");
  const [accountId, setAccountId] = useState("");
  const [categoryName, setCategoryName] = useState("");
  const [date, setDate] = useState(todayInput());
  const [description, setDescription] = useState("");
  const [note, setNote] = useState("");
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");

  async function save() {
    if (!amount || !accountId || !description.trim()) {
      setError("Tutar, hesap ve aciklama zorunlu.");
      return;
    }

    setSaving(true);
    setError("");
    setMessage("");
    try {
      await createTransaction(api, {
        account_id: Number(accountId),
        type,
        amount,
        category_name: categoryName.trim() || null,
        description: description.trim(),
        note: note.trim() || null,
        occurred_at: new Date(date).toISOString()
      });
      setMessage("Islem kaydedildi.");
      setAmount("");
      setCategoryName("");
      setDescription("");
      setNote("");
      onSaved();
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : "Islem kaydedilemedi.");
    } finally {
      setSaving(false);
    }
  }

  return (
    <Card palette={palette} style={styles.formCard} delay={80} elevated>
      <View style={styles.typeRow}>
        <Chip
          palette={palette}
          label="Gider"
          active={type === "expense"}
          activeColor={palette.negative}
          onPress={() => {
            setType("expense");
            setCategoryName("");
          }}
        />
        <Chip
          palette={palette}
          label="Gelir"
          active={type === "income"}
          activeColor={palette.positive}
          onPress={() => {
            setType("income");
            setCategoryName("");
          }}
        />
        <Chip
          palette={palette}
          label="Odeme"
          active={type === "payment"}
          activeColor={palette.primary}
          onPress={() => {
            setType("payment");
            setCategoryName("");
          }}
        />
      </View>
      <Field palette={palette} label="Tutar" value={amount} onChangeText={setAmount} keyboardType="decimal-pad" />
      <Text style={[styles.fieldTitle, { color: palette.muted }]}>Hesap</Text>
      <AccountPicker palette={palette} accounts={accounts} value={accountId} onChange={setAccountId} />
      <Text style={[styles.fieldTitle, { color: palette.muted }]}>Kategori</Text>
      <View style={styles.wrapRow}>
        {getCategoryList(type).map((category) => (
          <Chip
            key={category}
            palette={palette}
            label={category}
            active={categoryName === category}
            onPress={() => setCategoryName(category)}
          />
        ))}
      </View>
      <Field palette={palette} label="Tarih" value={date} onChangeText={setDate} placeholder="YYYY-MM-DD" />
      <Field palette={palette} label="Aciklama" value={description} onChangeText={setDescription} />
      <Field palette={palette} label="Not" value={note} onChangeText={setNote} />
      <Button palette={palette} label={saving ? "Kaydediliyor..." : "Kaydet"} onPress={save} disabled={saving} />
      {message ? <StatusMessage palette={palette} message={message} tone="success" /> : null}
      {error ? <StatusMessage palette={palette} message={error} tone="error" /> : null}
    </Card>
  );
}

function EventForm({
  palette,
  api,
  onSaved,
  onSyncNotifications
}: {
  palette: Palette;
  api: ApiContext;
  onSaved: () => void;
  onSyncNotifications: () => Promise<void>;
}) {
  const [title, setTitle] = useState("");
  const [date, setDate] = useState(todayInput());
  const [time, setTime] = useState(nowTimeInput());
  const [description, setDescription] = useState("");
  const [reminder, setReminder] = useState("");
  const [important, setImportant] = useState(false);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");

  async function save() {
    if (!title.trim()) {
      setError("Baslik zorunlu.");
      return;
    }

    setSaving(true);
    setError("");
    setMessage("");
    try {
      await createEvent(api, {
        title: title.trim(),
        description: description.trim() || null,
        starts_at: toIsoFromDateTime(date, time),
        is_important: important,
        reminder_offsets_minutes: reminder ? [Number(reminder)] : null
      });
      setTitle("");
      setDescription("");
      setReminder("");
      setImportant(false);
      setMessage("Etkinlik kaydedildi.");
      onSaved();
      await onSyncNotifications();
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : "Etkinlik kaydedilemedi.");
    } finally {
      setSaving(false);
    }
  }

  return (
    <Card palette={palette} style={styles.formCard} delay={80} elevated>
      <Field palette={palette} label="Baslik" value={title} onChangeText={setTitle} />
      <Field palette={palette} label="Tarih" value={date} onChangeText={setDate} placeholder="YYYY-MM-DD" />
      <Field palette={palette} label="Saat" value={time} onChangeText={setTime} placeholder="HH:MM" />
      <Field palette={palette} label="Aciklama" value={description} onChangeText={setDescription} />
      <SegmentedControl
        palette={palette}
        value={reminder}
        onChange={setReminder}
        options={[
          { value: "", label: "Yok" },
          { value: "15", label: "15 dk" },
          { value: "60", label: "1 saat" },
          { value: "1440", label: "1 gun" }
        ]}
      />
      <Chip
        palette={palette}
        label="Onemli"
        active={important}
        onPress={() => setImportant((current) => !current)}
      />
      <Button palette={palette} label={saving ? "Kaydediliyor..." : "Kaydet"} onPress={save} disabled={saving} />
      {message ? <StatusMessage palette={palette} message={message} tone="success" /> : null}
      {error ? <StatusMessage palette={palette} message={error} tone="error" /> : null}
    </Card>
  );
}

function RoutineForm({
  palette,
  api,
  onSaved,
  onSyncNotifications
}: {
  palette: Palette;
  api: ApiContext;
  onSaved: () => void;
  onSyncNotifications: () => Promise<void>;
}) {
  const [title, setTitle] = useState("");
  const [weekdays, setWeekdays] = useState<number[]>([]);
  const [startsOn, setStartsOn] = useState(todayInput());
  const [startTime, setStartTime] = useState("");
  const [intervalWeeks, setIntervalWeeks] = useState("1");
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");

  function toggleWeekday(index: number) {
    setWeekdays((current) =>
      current.includes(index) ? current.filter((item) => item !== index) : [...current, index]
    );
  }

  async function save() {
    if (!title.trim() || weekdays.length === 0) {
      setError("Baslik ve en az bir gun zorunlu.");
      return;
    }

    setSaving(true);
    setError("");
    setMessage("");
    try {
      await createRecurringEvent(api, {
        title: title.trim(),
        weekdays,
        starts_on: startsOn,
        start_time: startTime || null,
        interval_weeks: Number(intervalWeeks)
      });
      setTitle("");
      setWeekdays([]);
      setStartTime("");
      setIntervalWeeks("1");
      setMessage("Rutin kaydedildi.");
      onSaved();
      await onSyncNotifications();
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : "Rutin kaydedilemedi.");
    } finally {
      setSaving(false);
    }
  }

  return (
    <Card palette={palette} style={styles.formCard} delay={80} elevated>
      <Field palette={palette} label="Baslik" value={title} onChangeText={setTitle} />
      <Field palette={palette} label="Baslangic tarihi" value={startsOn} onChangeText={setStartsOn} />
      <Field palette={palette} label="Saat" value={startTime} onChangeText={setStartTime} placeholder="HH:MM" />
      <SegmentedControl
        palette={palette}
        value={intervalWeeks}
        onChange={setIntervalWeeks}
        options={[
          { value: "1", label: "Her hafta" },
          { value: "2", label: "2 hafta" },
          { value: "3", label: "3 hafta" },
          { value: "4", label: "4 hafta" }
        ]}
      />
      <Text style={[styles.fieldTitle, { color: palette.muted }]}>Gunler</Text>
      <View style={styles.wrapRow}>
        {WEEKDAYS.map((label, index) => (
          <Chip
            key={label}
            palette={palette}
            label={label}
            active={weekdays.includes(index)}
            onPress={() => toggleWeekday(index)}
          />
        ))}
      </View>
      <Button palette={palette} label={saving ? "Kaydediliyor..." : "Kaydet"} onPress={save} disabled={saving} />
      {message ? <StatusMessage palette={palette} message={message} tone="success" /> : null}
      {error ? <StatusMessage palette={palette} message={error} tone="error" /> : null}
    </Card>
  );
}

function MedicationForm({
  palette,
  api,
  onSaved,
  onSyncNotifications
}: {
  palette: Palette;
  api: ApiContext;
  onSaved: () => void;
  onSyncNotifications: () => Promise<void>;
}) {
  const [name, setName] = useState("");
  const [dosage, setDosage] = useState("");
  const [instructions, setInstructions] = useState("");
  const [weekdays, setWeekdays] = useState<number[]>([0, 1, 2, 3, 4, 5, 6]);
  const [doseTimes, setDoseTimes] = useState("09:00");
  const [startsOn, setStartsOn] = useState(todayInput());
  const [endsOn, setEndsOn] = useState("");
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");

  function toggleWeekday(index: number) {
    setWeekdays((current) =>
      current.includes(index) ? current.filter((item) => item !== index) : [...current, index]
    );
  }

  async function save() {
    if (!name.trim() || !dosage.trim() || weekdays.length === 0) {
      setError("Ilac adi, doz ve en az bir gun zorunlu.");
      return;
    }

    setSaving(true);
    setError("");
    setMessage("");
    try {
      const parsedDoseTimes = parseDoseTimes(doseTimes);
      await createMedication(api, {
        name: name.trim(),
        dosage: dosage.trim(),
        instructions: instructions.trim() || null,
        weekdays,
        dose_times: parsedDoseTimes,
        starts_on: startsOn,
        ends_on: endsOn.trim() || null,
        timezone: "Europe/Istanbul",
        is_active: true
      });
      setName("");
      setDosage("");
      setInstructions("");
      setWeekdays([0, 1, 2, 3, 4, 5, 6]);
      setDoseTimes("09:00");
      setEndsOn("");
      setMessage("Ilac hatirlaticisi kaydedildi.");
      onSaved();
      await onSyncNotifications();
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : "Ilac hatirlaticisi kaydedilemedi.");
    } finally {
      setSaving(false);
    }
  }

  return (
    <Card palette={palette} style={styles.formCard} delay={80} elevated>
      <Field palette={palette} label="Ilac adi" value={name} onChangeText={setName} />
      <Field palette={palette} label="Doz" value={dosage} onChangeText={setDosage} placeholder="5 mg, 1 tablet" />
      <Field
        palette={palette}
        label="Talimat"
        value={instructions}
        onChangeText={setInstructions}
        placeholder="Tok karnina, su ile"
      />
      <Text style={[styles.fieldTitle, { color: palette.muted }]}>Gunler</Text>
      <View style={styles.wrapRow}>
        {WEEKDAYS.map((label, index) => (
          <Chip
            key={label}
            palette={palette}
            label={label}
            active={weekdays.includes(index)}
            onPress={() => toggleWeekday(index)}
          />
        ))}
      </View>
      <Field
        palette={palette}
        label="Saatler"
        value={doseTimes}
        onChangeText={setDoseTimes}
        placeholder="09:00, 21:00"
      />
      <Field palette={palette} label="Baslangic tarihi" value={startsOn} onChangeText={setStartsOn} />
      <Field
        palette={palette}
        label="Bitis tarihi"
        value={endsOn}
        onChangeText={setEndsOn}
        placeholder="Opsiyonel YYYY-MM-DD"
      />
      <Button palette={palette} label={saving ? "Kaydediliyor..." : "Kaydet"} onPress={save} disabled={saving} />
      {message ? <StatusMessage palette={palette} message={message} tone="success" /> : null}
      {error ? <StatusMessage palette={palette} message={error} tone="error" /> : null}
    </Card>
  );
}

function AiCommand({ palette, api, onSaved }: { palette: Palette; api: ApiContext; onSaved: () => void }) {
  const [message, setMessage] = useState("");
  const [clarification, setClarification] = useState("");
  const [originalMessage, setOriginalMessage] = useState("");
  const [reply, setReply] = useState("");
  const [needsInput, setNeedsInput] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  async function run() {
    if (!message.trim()) {
      return;
    }
    setLoading(true);
    setError("");
    try {
      const response = await executeAI(api, message.trim());
      setReply(response.follow_up_question || response.assistant_message);
      setNeedsInput(response.status === "needs_input");
      setOriginalMessage(message.trim());
      if (response.status === "completed") {
        onSaved();
      }
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : "AI komutu calismadi.");
    } finally {
      setLoading(false);
    }
  }

  async function clarify() {
    if (!originalMessage || !clarification.trim()) {
      return;
    }
    setLoading(true);
    setError("");
    try {
      const response = await clarifyAI(api, originalMessage, clarification.trim());
      setReply(response.assistant_message);
      setNeedsInput(response.status === "needs_input");
      if (response.status === "completed") {
        setMessage("");
        setClarification("");
        setOriginalMessage("");
        onSaved();
      }
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : "Aciklama gonderilemedi.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <Card palette={palette} style={styles.formCard} delay={80} elevated>
      <Field
        palette={palette}
        label="Hizli komut"
        value={message}
        onChangeText={setMessage}
        placeholder="350 tl market, yarin 14:30 disci..."
        multiline
      />
      <Button palette={palette} label={loading ? "Calisiyor..." : "Calistir"} onPress={run} disabled={loading} />
      {needsInput ? (
        <>
          <Field
            palette={palette}
            label="Eksik bilgi"
            value={clarification}
            onChangeText={setClarification}
            placeholder="Hesap adi, tutar veya tarih"
          />
          <Button
            palette={palette}
            label="Aciklamayi gonder"
            variant="secondary"
            onPress={clarify}
            disabled={loading}
          />
        </>
      ) : null}
      {reply ? <StatusMessage palette={palette} message={reply} tone={needsInput ? "warning" : "success"} /> : null}
      {error ? <StatusMessage palette={palette} message={error} tone="error" /> : null}
    </Card>
  );
}

export function AddScreen({ palette, api, refreshKey, onChanged, onSyncNotifications }: Props) {
  const [tab, setTab] = useState<TabId>("transaction");
  const [accounts, setAccounts] = useState<Account[]>([]);

  const loadAccounts = useCallback(async () => {
    try {
      setAccounts(await fetchAccounts(api));
    } catch {
      setAccounts([]);
    }
  }, [api]);

  useEffect(() => {
    void loadAccounts();
  }, [loadAccounts, refreshKey]);

  function handleSaved() {
    onChanged();
    void loadAccounts();
  }

  return (
    <ScrollView
      style={{ backgroundColor: palette.background }}
      contentContainerStyle={styles.content}
      keyboardShouldPersistTaps="handled"
    >
      <Header palette={palette} eyebrow="Ekle" title="Ne ekleyelim?" />
      <SegmentedControl
        palette={palette}
        value={tab}
        onChange={setTab}
        options={[
          { value: "transaction", label: "Islem" },
          { value: "event", label: "Etkinlik" },
          { value: "routine", label: "Rutin" },
          { value: "medication", label: "Ilac" },
          { value: "ai", label: "AI" }
        ]}
      />
      {tab === "transaction" ? (
        <TransactionForm palette={palette} api={api} accounts={accounts} onSaved={handleSaved} />
      ) : null}
      {tab === "event" ? (
        <EventForm
          palette={palette}
          api={api}
          onSaved={handleSaved}
          onSyncNotifications={onSyncNotifications}
        />
      ) : null}
      {tab === "routine" ? (
        <RoutineForm
          palette={palette}
          api={api}
          onSaved={handleSaved}
          onSyncNotifications={onSyncNotifications}
        />
      ) : null}
      {tab === "medication" ? (
        <MedicationForm
          palette={palette}
          api={api}
          onSaved={handleSaved}
          onSyncNotifications={onSyncNotifications}
        />
      ) : null}
      {tab === "ai" ? <AiCommand palette={palette} api={api} onSaved={handleSaved} /> : null}
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
  formCard: {
    gap: 16
  },
  wrapRow: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 8
  },
  chip: {
    minHeight: 38,
    borderRadius: 12,
    borderWidth: 1,
    paddingHorizontal: 12,
    alignItems: "center",
    justifyContent: "center"
  },
  chipText: {
    fontSize: 13,
    fontWeight: "900"
  },
  fieldTitle: {
    fontSize: 12,
    fontWeight: "800",
    letterSpacing: 0,
    textTransform: "uppercase"
  },
  typeRow: {
    flexDirection: "row",
    gap: 8
  }
});
