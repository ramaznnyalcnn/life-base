import { useEffect, useState } from "react";

import { createAccount, fetchAccounts, updateAccount } from "../api/accounts";
import { fetchWalletSummary } from "../api/wallet";

function formatMoney(value) {
  return new Intl.NumberFormat("tr-TR", {
    style: "currency",
    currency: "TRY",
    maximumFractionDigits: 2
  }).format(Number(value ?? 0));
}

const INITIAL_FORM = {
  name: "",
  type: "bank",
  currency: "TRY",
  balance: "",
  credit_limit: "",
  statement_day: "",
  due_day: "",
  issuer: "",
  is_active: true
};

function normalizePayload(form) {
  return {
    name: form.name.trim(),
    type: form.type,
    currency: form.currency,
    balance: form.balance || "0",
    credit_limit: form.type === "credit_card" && form.credit_limit ? form.credit_limit : null,
    statement_day: form.type === "credit_card" && form.statement_day ? Number(form.statement_day) : null,
    due_day: form.type === "credit_card" && form.due_day ? Number(form.due_day) : null,
    issuer: form.issuer.trim() || null,
    is_active: form.is_active
  };
}

function getAccountTypeLabel(type) {
  if (type === "credit_card") {
    return "Kredi Karti";
  }
  if (type === "bank") {
    return "Banka";
  }
  return "Nakit";
}

export default function ManagePage() {
  const [accounts, setAccounts] = useState([]);
  const [summary, setSummary] = useState(null);
  const [form, setForm] = useState(INITIAL_FORM);
  const [editingId, setEditingId] = useState(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  async function loadData() {
    setLoading(true);
    setError("");

    try {
      const [accountsPayload, summaryPayload] = await Promise.all([
        fetchAccounts(),
        fetchWalletSummary()
      ]);
      setAccounts(accountsPayload);
      setSummary(summaryPayload);
    } catch (nextError) {
      setError(nextError.message);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadData();
  }, []);

  function handleChange(field, value) {
    setForm((current) => ({
      ...current,
      [field]: value
    }));
  }

  function startEditing(account) {
    setEditingId(account.id);
    setForm({
      name: account.name,
      type: account.type,
      currency: account.currency,
      balance: String(account.balance ?? "0"),
      credit_limit: account.credit_limit ? String(account.credit_limit) : "",
      statement_day: account.statement_day ? String(account.statement_day) : "",
      due_day: account.due_day ? String(account.due_day) : "",
      issuer: account.issuer ?? "",
      is_active: account.is_active
    });
  }

  function resetForm() {
    setEditingId(null);
    setForm(INITIAL_FORM);
  }

  async function handleSubmit(event) {
    event.preventDefault();
    setSaving(true);
    setError("");

    try {
      const payload = normalizePayload(form);
      if (editingId) {
        await updateAccount(editingId, payload);
      } else {
        await createAccount(payload);
      }
      resetForm();
      await loadData();
    } catch (nextError) {
      setError(nextError.message);
    } finally {
      setSaving(false);
    }
  }

  async function handleToggleActive(account) {
    setSaving(true);
    setError("");

    try {
      await updateAccount(account.id, {
        is_active: !account.is_active
      });
      await loadData();
    } catch (nextError) {
      setError(nextError.message);
    } finally {
      setSaving(false);
    }
  }

  return (
    <main className="shell">
      <section className="hero-panel manage-hero-panel">
        <div className="hero-panel__copy">
          <p className="hero-panel__eyebrow">Yonetim</p>
          <h1>Hesap ve kart yonetimi</h1>
          <p className="hero-panel__text">
            Hesap ekle, kart ayarlarini duzenle ve aktif durumunu buradan yonet.
          </p>
        </div>
      </section>

      {loading ? <section className="wallet-grid"><article className="metric-card">Yukleniyor...</article></section> : null}
      {error ? <p className="error-banner">{error}</p> : null}

      {summary ? (
        <section className="wallet-grid manage-summary-grid">
          <article className="metric-card">
            <p className="metric-card__label">Likit Para</p>
            <p className="metric-card__value">{formatMoney(summary.liquid_balance)}</p>
          </article>
          <article className="metric-card metric-card--warning">
            <p className="metric-card__label">Kart Borcu</p>
            <p className="metric-card__value">{formatMoney(summary.total_card_used)}</p>
          </article>
          <article className="metric-card metric-card--accent manage-summary-grid__wide">
            <p className="metric-card__label">Net Durum</p>
            <p className="metric-card__value">{formatMoney(summary.net_worth)}</p>
          </article>
        </section>
      ) : null}

      <section className="manage-layout">
        <section className="compose-panel manage-compose-panel">
          <div className="manage-section-header">
            <div>
              <p className="status-card__eyebrow">{editingId ? "Duzenleme" : "Yeni Hesap"}</p>
              <h2>{editingId ? "Secili hesabi guncelle" : "Yeni hesap veya kart ekle"}</h2>
            </div>
            <span className="manage-section-header__badge">
              {form.type === "credit_card" ? "Kart formu" : "Hesap formu"}
            </span>
          </div>
          <form className="compose-form" onSubmit={handleSubmit}>
            <div className="manage-form-grid">
              <div className="manage-form-field">
                <label className="compose-form__label" htmlFor="account-name">
                  Ad
                </label>
                <input
                  id="account-name"
                  className="compose-form__input"
                  value={form.name}
                  onChange={(event) => handleChange("name", event.target.value)}
                />
              </div>

              <div className="manage-form-field">
                <label className="compose-form__label" htmlFor="account-type">
                  Tur
                </label>
                <select
                  id="account-type"
                  className="compose-form__input"
                  value={form.type}
                  onChange={(event) => handleChange("type", event.target.value)}
                >
                  <option value="bank">Banka</option>
                  <option value="cash">Nakit</option>
                  <option value="credit_card">Kredi Karti</option>
                </select>
              </div>

              <div className="manage-form-field">
                <label className="compose-form__label" htmlFor="account-balance">
                  Bakiye
                </label>
                <input
                  id="account-balance"
                  className="compose-form__input"
                  inputMode="decimal"
                  value={form.balance}
                  onChange={(event) => handleChange("balance", event.target.value)}
                />
              </div>

              <div className="manage-form-field">
                <label className="compose-form__label" htmlFor="account-issuer">
                  Kurum
                </label>
                <input
                  id="account-issuer"
                  className="compose-form__input"
                  value={form.issuer}
                  onChange={(event) => handleChange("issuer", event.target.value)}
                />
              </div>
            </div>

            {form.type === "credit_card" ? (
              <div className="manage-form-grid manage-form-grid--credit">
                <div className="manage-form-field">
                  <label className="compose-form__label" htmlFor="account-limit">
                    Toplam Limit
                  </label>
                  <input
                    id="account-limit"
                    className="compose-form__input"
                    inputMode="decimal"
                    value={form.credit_limit}
                    onChange={(event) => handleChange("credit_limit", event.target.value)}
                  />
                </div>

                <div className="manage-form-field">
                  <label className="compose-form__label" htmlFor="account-statement">
                    Kesim Gunu
                  </label>
                  <input
                    id="account-statement"
                    className="compose-form__input"
                    inputMode="numeric"
                    value={form.statement_day}
                    onChange={(event) => handleChange("statement_day", event.target.value)}
                  />
                </div>

                <div className="manage-form-field">
                  <label className="compose-form__label" htmlFor="account-due">
                    Son Odeme Gunu
                  </label>
                  <input
                    id="account-due"
                    className="compose-form__input"
                    inputMode="numeric"
                    value={form.due_day}
                    onChange={(event) => handleChange("due_day", event.target.value)}
                  />
                </div>
              </div>
            ) : null}

            <div className="event-actions">
              <button className="primary-button" disabled={saving} type="submit">
                {saving ? "Kaydediliyor..." : editingId ? "Guncelle" : "Hesap Ekle"}
              </button>
              <button className="ghost-button" type="button" onClick={resetForm}>
                Temizle
              </button>
            </div>
          </form>
        </section>

        <section className="accounts-panel manage-accounts-panel">
          <div className="accounts-panel__header">
            <div>
              <p className="status-card__eyebrow">Hesaplar ve Kartlar</p>
              <h2 className="manage-accounts-panel__title">Tum varliklar tek akista</h2>
            </div>
            <p className="accounts-panel__meta">{accounts.length} kayit</p>
          </div>
          <div className="account-list">
            {accounts.map((account) => (
              <article className="account-card manage-account-card" key={account.id}>
                <div className="account-card__header">
                  <div>
                    <div className="manage-account-card__eyebrow-row">
                      <span className="manage-account-card__type">{getAccountTypeLabel(account.type)}</span>
                      <span className={`manage-account-card__state ${account.is_active ? "manage-account-card__state--active" : ""}`}>
                        {account.is_active ? "Aktif" : "Pasif"}
                      </span>
                    </div>
                    <h3>{account.name}</h3>
                    <p>{account.issuer ?? "Kisisel hesap"}</p>
                  </div>
                  <strong>{formatMoney(account.balance)}</strong>
                </div>
                <div className="account-card__meta">
                  <span>{account.currency}</span>
                  {account.type === "credit_card" ? (
                    <>
                      <span>Limit {formatMoney(account.credit_limit)}</span>
                      <span>Kesim {account.statement_day ?? "-"}</span>
                      <span>Son Odeme {account.due_day ?? "-"}</span>
                    </>
                  ) : null}
                </div>
                <div className="event-actions">
                  <button className="secondary-button" type="button" onClick={() => startEditing(account)}>
                    Duzenle
                  </button>
                  <button className="ghost-button" type="button" onClick={() => handleToggleActive(account)}>
                    {account.is_active ? "Pasife Al" : "Aktif Et"}
                  </button>
                </div>
              </article>
            ))}
            {!accounts.length ? <p className="hero-panel__text">Hesap bulunmuyor.</p> : null}
          </div>
        </section>
      </section>
    </main>
  );
}
