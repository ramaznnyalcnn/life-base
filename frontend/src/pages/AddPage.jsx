import { useEffect, useState } from "react";

import { fetchAccounts } from "../api/accounts";
import { createEvent, createRecurringEvent } from "../api/events";
import { createMedication } from "../api/medications";
import { createTransaction } from "../api/transactions";

const EXPENSE_CATEGORIES = [
  "Market", "Yeme-İçme", "Kahve", "Fatura", "Abonelik",
  "Ulaşım", "Yakıt", "Sağlık", "Eczane", "Kira",
  "Eğlence", "Giyim", "Eğitim", "Elektronik",
  "Kişisel Bakım", "Spor", "Diğer"
];

const INCOME_CATEGORIES = [
  "Maaş", "Ek Gelir", "Serbest Çalışma", "Yatırım", "Prim", "Diğer Gelir"
];

const PAYMENT_CATEGORIES = [
  "Kredi Kartı Ödemesi", "Borç Ödemesi", "Diğer Ödeme"
];

const REMINDER_OPTIONS = [
  { label: "Hatırlatma yok", value: "" },
  { label: "15 dk önce", value: "15" },
  { label: "30 dk önce", value: "30" },
  { label: "1 saat önce", value: "60" },
  { label: "1 gün önce", value: "1440" }
];

const WEEKDAY_LABELS = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"];

const todayStr = () => new Date().toISOString().slice(0, 10);
const nowTimeStr = () => new Date().toTimeString().slice(0, 5);

function getCategoryList(type) {
  if (type === "income") return INCOME_CATEGORIES;
  if (type === "payment") return PAYMENT_CATEGORIES;
  return EXPENSE_CATEGORIES;
}

function SuccessBanner({ message, onDismiss }) {
  return (
    <div className="add-success-banner">
      <span>{message}</span>
      <button type="button" className="ghost-button" onClick={onDismiss}>×</button>
    </div>
  );
}

function FormField({ label, htmlFor, children }) {
  return (
    <div className="add-field">
      <label className="compose-form__label" htmlFor={htmlFor}>{label}</label>
      {children}
    </div>
  );
}

function TransactionForm({ accounts }) {
  const [type, setType] = useState("expense");
  const [form, setForm] = useState({
    amount: "", account_id: "", category_name: "",
    occurred_at: todayStr(), description: "", note: ""
  });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");

  function update(field, value) {
    setForm((prev) => ({ ...prev, [field]: value }));
  }

  function handleTypeChange(nextType) {
    setType(nextType);
    setForm((prev) => ({ ...prev, category_name: "" }));
  }

  async function handleSubmit(e) {
    e.preventDefault();
    if (!form.amount || !form.account_id || !form.description.trim()) return;
    setLoading(true);
    setError("");
    try {
      await createTransaction({
        account_id: Number(form.account_id),
        type,
        amount: form.amount,
        category_name: form.category_name || null,
        description: form.description.trim(),
        note: form.note.trim() || null,
        occurred_at: new Date(form.occurred_at).toISOString()
      });
      setSuccess("İşlem kaydedildi.");
      setForm({ amount: "", account_id: "", category_name: "", occurred_at: todayStr(), description: "", note: "" });
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  const categories = getCategoryList(type);
  const typeLabels = { expense: "Gider", income: "Gelir", payment: "Ödeme" };

  return (
    <form className="add-form" onSubmit={handleSubmit}>
      {success ? <SuccessBanner message={success} onDismiss={() => setSuccess("")} /> : null}

      <div className="add-type-row">
        {["expense", "income", "payment"].map((t) => (
          <button
            key={t}
            type="button"
            className={`add-type-chip ${type === t ? "add-type-chip--active add-type-chip--" + t : ""}`}
            onClick={() => handleTypeChange(t)}
          >
            {typeLabels[t]}
          </button>
        ))}
      </div>

      <div className="add-form-grid">
        <FormField label="Tutar (₺)" htmlFor="tx-amount">
          <input
            id="tx-amount"
            className="compose-form__input"
            type="number"
            min="0.01"
            step="0.01"
            inputMode="decimal"
            placeholder="0,00"
            value={form.amount}
            onChange={(e) => update("amount", e.target.value)}
            required
          />
        </FormField>

        <FormField label="Tarih" htmlFor="tx-date">
          <input
            id="tx-date"
            className="compose-form__input"
            type="date"
            value={form.occurred_at}
            onChange={(e) => update("occurred_at", e.target.value)}
            required
          />
        </FormField>

        <FormField label="Hesap" htmlFor="tx-account">
          <select
            id="tx-account"
            className="compose-form__input compose-form__select"
            value={form.account_id}
            onChange={(e) => update("account_id", e.target.value)}
            required
          >
            <option value="">Hesap seç...</option>
            {accounts.map((acc) => (
              <option key={acc.id} value={acc.id}>{acc.name}</option>
            ))}
          </select>
        </FormField>

        <FormField label="Kategori" htmlFor="tx-category">
          <select
            id="tx-category"
            className="compose-form__input compose-form__select"
            value={form.category_name}
            onChange={(e) => update("category_name", e.target.value)}
          >
            <option value="">Seçiniz...</option>
            {categories.map((cat) => (
              <option key={cat} value={cat}>{cat}</option>
            ))}
          </select>
        </FormField>

        <FormField label="Açıklama" htmlFor="tx-desc">
          <input
            id="tx-desc"
            className="compose-form__input"
            type="text"
            placeholder="Kısa açıklama"
            value={form.description}
            onChange={(e) => update("description", e.target.value)}
            required
          />
        </FormField>

        <FormField label="Not (isteğe bağlı)" htmlFor="tx-note">
          <input
            id="tx-note"
            className="compose-form__input"
            type="text"
            placeholder="Ek bilgi"
            value={form.note}
            onChange={(e) => update("note", e.target.value)}
          />
        </FormField>
      </div>

      {error ? <p className="error-banner">{error}</p> : null}

      <div className="add-form-actions">
        <button className="primary-button" type="submit" disabled={loading}>
          {loading ? "Kaydediliyor..." : "Kaydet"}
        </button>
        <button className="ghost-button" type="button"
          onClick={() => { setForm({ amount: "", account_id: "", category_name: "", occurred_at: todayStr(), description: "", note: "" }); setError(""); setSuccess(""); }}>
          Temizle
        </button>
      </div>
    </form>
  );
}

function EventForm() {
  const [form, setForm] = useState({
    title: "", date: todayStr(), time: nowTimeStr(), reminder: "", is_important: false
  });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");

  function update(field, value) {
    setForm((prev) => ({ ...prev, [field]: value }));
  }

  async function handleSubmit(e) {
    e.preventDefault();
    if (!form.title.trim()) return;
    setLoading(true);
    setError("");
    try {
      await createEvent({
        title: form.title.trim(),
        starts_at: new Date(`${form.date}T${form.time || "09:00"}`).toISOString(),
        is_important: form.is_important,
        reminder_offsets_minutes: form.reminder ? [Number(form.reminder)] : null
      });
      setSuccess("Etkinlik eklendi.");
      setForm({ title: "", date: todayStr(), time: nowTimeStr(), reminder: "", is_important: false });
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <form className="add-form" onSubmit={handleSubmit}>
      {success ? <SuccessBanner message={success} onDismiss={() => setSuccess("")} /> : null}

      <div className="add-form-grid">
        <FormField label="Başlık" htmlFor="ev-title">
          <input
            id="ev-title"
            className="compose-form__input"
            type="text"
            placeholder="Etkinlik adı"
            value={form.title}
            onChange={(e) => update("title", e.target.value)}
            required
          />
        </FormField>

        <FormField label="Tarih" htmlFor="ev-date">
          <input
            id="ev-date"
            className="compose-form__input"
            type="date"
            value={form.date}
            onChange={(e) => update("date", e.target.value)}
            required
          />
        </FormField>

        <FormField label="Saat" htmlFor="ev-time">
          <input
            id="ev-time"
            className="compose-form__input"
            type="time"
            value={form.time}
            onChange={(e) => update("time", e.target.value)}
          />
        </FormField>

        <FormField label="Hatırlatma" htmlFor="ev-reminder">
          <select
            id="ev-reminder"
            className="compose-form__input compose-form__select"
            value={form.reminder}
            onChange={(e) => update("reminder", e.target.value)}
          >
            {REMINDER_OPTIONS.map((opt) => (
              <option key={opt.value} value={opt.value}>{opt.label}</option>
            ))}
          </select>
        </FormField>
      </div>

      <label className="add-checkbox-row">
        <input
          type="checkbox"
          checked={form.is_important}
          onChange={(e) => update("is_important", e.target.checked)}
        />
        <span>Önemli olarak işaretle</span>
      </label>

      {error ? <p className="error-banner">{error}</p> : null}

      <div className="add-form-actions">
        <button className="primary-button" type="submit" disabled={loading}>
          {loading ? "Kaydediliyor..." : "Kaydet"}
        </button>
        <button className="ghost-button" type="button"
          onClick={() => { setForm({ title: "", date: todayStr(), time: nowTimeStr(), reminder: "", is_important: false }); setError(""); setSuccess(""); }}>
          Temizle
        </button>
      </div>
    </form>
  );
}

function RoutineForm() {
  const [form, setForm] = useState({
    title: "", weekdays: [], interval_weeks: 1, starts_on: todayStr(), start_time: ""
  });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");

  function update(field, value) {
    setForm((prev) => ({ ...prev, [field]: value }));
  }

  function toggleWeekday(day) {
    setForm((prev) => {
      const next = prev.weekdays.includes(day)
        ? prev.weekdays.filter((d) => d !== day)
        : [...prev.weekdays, day];
      return { ...prev, weekdays: next };
    });
  }

  async function handleSubmit(e) {
    e.preventDefault();
    if (!form.title.trim() || form.weekdays.length === 0) return;
    setLoading(true);
    setError("");
    try {
      await createRecurringEvent({
        title: form.title.trim(),
        weekdays: form.weekdays,
        interval_weeks: Number(form.interval_weeks),
        starts_on: form.starts_on,
        start_time: form.start_time || null
      });
      setSuccess("Rutin oluşturuldu.");
      setForm({ title: "", weekdays: [], interval_weeks: 1, starts_on: todayStr(), start_time: "" });
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <form className="add-form" onSubmit={handleSubmit}>
      {success ? <SuccessBanner message={success} onDismiss={() => setSuccess("")} /> : null}

      <div className="add-form-grid">
        <FormField label="Başlık" htmlFor="rt-title">
          <input
            id="rt-title"
            className="compose-form__input"
            type="text"
            placeholder="Rutin adı (örn. Spor)"
            value={form.title}
            onChange={(e) => update("title", e.target.value)}
            required
          />
        </FormField>

        <FormField label="Başlangıç Tarihi" htmlFor="rt-start">
          <input
            id="rt-start"
            className="compose-form__input"
            type="date"
            value={form.starts_on}
            onChange={(e) => update("starts_on", e.target.value)}
            required
          />
        </FormField>

        <FormField label="Saat (isteğe bağlı)" htmlFor="rt-time">
          <input
            id="rt-time"
            className="compose-form__input"
            type="time"
            value={form.start_time}
            onChange={(e) => update("start_time", e.target.value)}
          />
        </FormField>

        <FormField label="Her kaç haftada bir?" htmlFor="rt-interval">
          <select
            id="rt-interval"
            className="compose-form__input compose-form__select"
            value={form.interval_weeks}
            onChange={(e) => update("interval_weeks", e.target.value)}
          >
            {[1, 2, 3, 4].map((n) => (
              <option key={n} value={n}>{n === 1 ? "Her hafta" : `${n} haftada bir`}</option>
            ))}
          </select>
        </FormField>
      </div>

      <div className="add-field">
        <p className="compose-form__label">Hangi günler?</p>
        <div className="add-weekday-picker">
          {WEEKDAY_LABELS.map((label, i) => (
            <button
              key={i}
              type="button"
              className={`add-weekday-btn ${form.weekdays.includes(i) ? "add-weekday-btn--active" : ""}`}
              onClick={() => toggleWeekday(i)}
            >
              {label}
            </button>
          ))}
        </div>
      </div>

      {error ? <p className="error-banner">{error}</p> : null}

      <div className="add-form-actions">
        <button className="primary-button" type="submit" disabled={loading || form.weekdays.length === 0}>
          {loading ? "Kaydediliyor..." : "Kaydet"}
        </button>
        <button className="ghost-button" type="button"
          onClick={() => { setForm({ title: "", weekdays: [], interval_weeks: 1, starts_on: todayStr(), start_time: "" }); setError(""); setSuccess(""); }}>
          Temizle
        </button>
      </div>
    </form>
  );
}

function MedicationForm() {
  const [form, setForm] = useState({
    name: "", dosage: "", instructions: "", schedule_mode: "weekdays", weekdays: [0, 1, 2, 3, 4, 5, 6],
    interval_days: "2", dose_times: "09:00", starts_on: todayStr(), ends_on: ""
  });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");

  function update(field, value) {
    setForm((prev) => ({ ...prev, [field]: value }));
  }

  function toggleWeekday(day) {
    setForm((prev) => ({
      ...prev,
      weekdays: prev.weekdays.includes(day) ? prev.weekdays.filter((item) => item !== day) : [...prev.weekdays, day]
    }));
  }

  async function handleSubmit(event) {
    event.preventDefault();
    const doseTimes = form.dose_times.split(/[,\s]+/).map((item) => item.trim()).filter(Boolean);
    const intervalDays = Number(form.interval_days);
    if (!form.name.trim() || !form.dosage.trim() || !doseTimes.length) return;
    if (form.schedule_mode === "weekdays" && !form.weekdays.length) return;
    if (form.schedule_mode === "interval" && (!Number.isInteger(intervalDays) || intervalDays < 1)) return;
    setLoading(true);
    setError("");
    try {
      await createMedication({
        name: form.name.trim(),
        dosage: form.dosage.trim(),
        instructions: form.instructions.trim() || null,
        schedule_mode: form.schedule_mode,
        weekdays: form.schedule_mode === "weekdays" ? form.weekdays : [],
        interval_days: form.schedule_mode === "interval" ? intervalDays : null,
        dose_times: doseTimes,
        starts_on: form.starts_on,
        ends_on: form.ends_on || null,
        timezone: "Europe/Istanbul",
        is_active: true
      });
      setSuccess("İlaç hatırlatıcısı kaydedildi.");
      setForm({
        name: "", dosage: "", instructions: "", schedule_mode: "weekdays", weekdays: [0, 1, 2, 3, 4, 5, 6],
        interval_days: "2", dose_times: "09:00", starts_on: todayStr(), ends_on: ""
      });
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <form className="add-form" onSubmit={handleSubmit}>
      {success ? <SuccessBanner message={success} onDismiss={() => setSuccess("")} /> : null}
      <div className="add-form-grid">
        <FormField label="İlaç adı" htmlFor="med-name"><input id="med-name" className="compose-form__input" value={form.name} onChange={(e) => update("name", e.target.value)} required /></FormField>
        <FormField label="Doz" htmlFor="med-dosage"><input id="med-dosage" className="compose-form__input" value={form.dosage} onChange={(e) => update("dosage", e.target.value)} required /></FormField>
        <FormField label="Talimat" htmlFor="med-instructions"><input id="med-instructions" className="compose-form__input" value={form.instructions} onChange={(e) => update("instructions", e.target.value)} /></FormField>
        <FormField label="Saatler" htmlFor="med-times"><input id="med-times" className="compose-form__input" value={form.dose_times} onChange={(e) => update("dose_times", e.target.value)} required /></FormField>
        <FormField label="Başlangıç tarihi" htmlFor="med-start"><input id="med-start" className="compose-form__input" type="date" value={form.starts_on} onChange={(e) => update("starts_on", e.target.value)} required /></FormField>
        <FormField label="Bitiş tarihi" htmlFor="med-end"><input id="med-end" className="compose-form__input" type="date" value={form.ends_on} onChange={(e) => update("ends_on", e.target.value)} /></FormField>
        <FormField label="Program tipi" htmlFor="med-mode">
          <select id="med-mode" className="compose-form__input compose-form__select" value={form.schedule_mode} onChange={(e) => update("schedule_mode", e.target.value)}>
            <option value="weekdays">Belirli günler</option>
            <option value="interval">Her N günde bir</option>
          </select>
        </FormField>
        {form.schedule_mode === "interval" ? (
          <FormField label="Kaç günde bir?" htmlFor="med-interval"><input id="med-interval" className="compose-form__input" type="number" min="1" value={form.interval_days} onChange={(e) => update("interval_days", e.target.value)} required /></FormField>
        ) : null}
      </div>
      {form.schedule_mode === "weekdays" ? (
        <div className="add-field"><p className="compose-form__label">Hangi günler?</p><div className="add-weekday-picker">
          {WEEKDAY_LABELS.map((label, index) => <button key={label} type="button" className={`add-weekday-btn ${form.weekdays.includes(index) ? "add-weekday-btn--active" : ""}`} onClick={() => toggleWeekday(index)}>{label}</button>)}
        </div></div>
      ) : null}
      {error ? <p className="error-banner">{error}</p> : null}
      <div className="add-form-actions"><button className="primary-button" type="submit" disabled={loading}>{loading ? "Kaydediliyor..." : "Kaydet"}</button></div>
    </form>
  );
}

const TABS = [
  { id: "transaction", label: "İşlem", icon: "₺" },
  { id: "event", label: "Etkinlik", icon: "◎" },
  { id: "routine", label: "Rutin", icon: "↻" }
  ,{ id: "medication", label: "İlaç", icon: "+" }
];

export default function AddPage() {
  const [activeTab, setActiveTab] = useState("transaction");
  const [accounts, setAccounts] = useState([]);

  useEffect(() => {
    fetchAccounts().then(setAccounts).catch(() => {});
  }, []);

  return (
    <main className="shell shell--add">
      <section className="add-hero-panel">
        <div className="add-page-header">
          <p className="status-card__eyebrow">Ekle</p>
          <h1 className="add-page-title">Ne ekleyelim?</h1>
        </div>

        <div className="add-tab-bar">
          {TABS.map((tab) => (
            <button
              key={tab.id}
              type="button"
              className={`add-tab-btn ${activeTab === tab.id ? "add-tab-btn--active" : ""}`}
              onClick={() => setActiveTab(tab.id)}
            >
              <span className="add-tab-icon">{tab.icon}</span>
              {tab.label}
            </button>
          ))}
        </div>

        {activeTab === "transaction" && <TransactionForm accounts={accounts} />}
        {activeTab === "event" && <EventForm />}
        {activeTab === "routine" && <RoutineForm />}
        {activeTab === "medication" && <MedicationForm />}
      </section>
    </main>
  );
}
