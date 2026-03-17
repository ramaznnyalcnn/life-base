import { useEffect, useState } from "react";

import { createAccount, fetchAccounts, updateAccount } from "../api/accounts";
import { fetchCardStatements, fetchWalletSummary } from "../api/wallet";
import CreditCard from "../components/CreditCard";

function formatMoney(value) {
  return new Intl.NumberFormat("tr-TR", {
    style: "currency",
    currency: "TRY",
    maximumFractionDigits: 2
  }).format(Number(value ?? 0));
}

function formatShortDate(value) {
  return new Intl.DateTimeFormat("tr-TR", {
    day: "2-digit",
    month: "short"
  }).format(new Date(value));
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
  const [statements, setStatements] = useState([]);
  const [form, setForm] = useState(INITIAL_FORM);
  const [editingId, setEditingId] = useState(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  async function loadData() {
    setLoading(true);
    setError("");

    try {
      const [accountsPayload, summaryPayload, statementPayload] = await Promise.all([
        fetchAccounts(),
        fetchWalletSummary(),
        fetchCardStatements()
      ]);
      setAccounts(accountsPayload);
      setSummary(summaryPayload);
      setStatements(statementPayload);
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

  const creditAccounts = accounts.filter((account) => account.type === "credit_card");
  const totalAvailableCredit = creditAccounts.reduce(
    (total, account) => total + Number(account.available_credit ?? account.balance ?? 0),
    0
  );
  const totalCardLimit = creditAccounts.reduce(
    (total, account) => total + Number(account.credit_limit ?? 0),
    0
  );
  const totalCardUsed = creditAccounts.reduce((total, account) => {
    const available = Number(account.available_credit ?? account.balance ?? 0);
    const limit = Number(account.credit_limit ?? 0);
    return total + Number(account.used_credit ?? Math.max(limit - available, 0));
  }, 0);
  const statementTotal = statements.reduce(
    (total, statement) => total + Number(statement.statement_amount ?? 0),
    0
  );
  const monthlyPayments = statements.reduce(
    (total, statement) => total + Number(statement.payment_activity ?? 0),
    0
  );
  const urgentStatement =
    [...statements]
      .filter((statement) => statement.due_date)
      .sort((left, right) => new Date(left.due_date).getTime() - new Date(right.due_date).getTime())[0] ??
    null;
  const statementByAccountId = new Map(statements.map((statement) => [statement.account_id, statement]));

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

      <section className="wallet-asset-stage manage-card-insights">
        <div className="wallet-asset-stage__header">
          <div>
            <p className="status-card__eyebrow">Kart Yonetimi</p>
            <h2>Kart odemeleri ve ekstre durumu</h2>
          </div>
          <span className="manage-section-header__badge">{creditAccounts.length} aktif kart</span>
        </div>

        <div className="wallet-snapshot-grid wallet-snapshot-grid--manage">
          <article className="wallet-snapshot-card">
            <p className="wallet-snapshot-card__label">Kart Odemeleri</p>
            <strong>{formatMoney(monthlyPayments)}</strong>
            <span>Kart odemeleri ana sayfadan alindi ve buraya tasindi.</span>
          </article>
          <article className="wallet-snapshot-card">
            <p className="wallet-snapshot-card__label">Ekstrede</p>
            <strong>{formatMoney(statementTotal)}</strong>
            <span>Acik ekstre tutari toplami.</span>
          </article>
          <article className="wallet-snapshot-card">
            <p className="wallet-snapshot-card__label">Kullanilabilir Limit</p>
            <strong>{formatMoney(totalAvailableCredit)}</strong>
            <span>
              Toplam limit {formatMoney(totalCardLimit)} / Kart borcu {formatMoney(totalCardUsed)}
            </span>
          </article>
          <article className="wallet-snapshot-card">
            <p className="wallet-snapshot-card__label">Yaklasan Odeme</p>
            <strong>{urgentStatement?.account_name ?? "Planlanan odeme yok"}</strong>
            <span>
              {urgentStatement
                ? `${urgentStatement.due_date ? formatShortDate(urgentStatement.due_date) : "-"} tarihinde ${formatMoney(urgentStatement.statement_amount)}`
                : "Aktif ekstre geldikce burada gorunur."}
            </span>
          </article>
        </div>

        <div className="account-list manage-card-insights__list">
          {statements.length ? (
            statements.map((statement) => (
              <article className="account-card manage-account-card" key={statement.account_id}>
                <div className="account-card__header">
                  <div>
                    <div className="manage-account-card__eyebrow-row">
                      <span className="manage-account-card__type">Ekstre</span>
                      <span className="manage-account-card__state manage-account-card__state--active">
                        {statement.due_date ? `Son odeme ${formatShortDate(statement.due_date)}` : "Tarih yok"}
                      </span>
                    </div>
                    <h3>{statement.account_name}</h3>
                    <p>
                      Donem {formatShortDate(statement.period_start)} - {formatShortDate(statement.period_end)}
                    </p>
                  </div>
                  <strong>{formatMoney(statement.statement_amount)}</strong>
                </div>
                <div className="account-card__meta">
                  <span>Odeme {formatMoney(statement.payment_activity)}</span>
                  <span>Reset {formatShortDate(statement.auto_resets_at)}</span>
                  <span>{statement.transaction_count} islem</span>
                </div>
              </article>
            ))
          ) : (
            <article className="wallet-snapshot-card manage-card-insights__empty">
              <p className="wallet-snapshot-card__label">Ekstre yok</p>
              <strong>Aktif kredi karti ekstresi bulunmuyor.</strong>
              <span>Kart ekledikce odeme ve donem bilgileri burada listelenecek.</span>
            </article>
          )}
        </div>
      </section>

      <section className="wallet-asset-stage manage-card-details">
        <div className="wallet-asset-stage__header">
          <div>
            <p className="status-card__eyebrow">Kart Bilgileri</p>
            <h2>Detayli kart gorunumu ve hizli duzenleme</h2>
          </div>
          <span className="manage-section-header__badge">{creditAccounts.length} kart</span>
        </div>

        {creditAccounts.length ? (
          <div className="credit-card-list manage-card-details__list">
            {creditAccounts.map((account) => (
              <CreditCard
                key={account.id}
                account={account}
                statement={statementByAccountId.get(account.id) ?? null}
                onEdit={startEditing}
              />
            ))}
          </div>
        ) : (
          <article className="wallet-snapshot-card manage-card-insights__empty">
            <p className="wallet-snapshot-card__label">Kart yok</p>
            <strong>Detayli kart gorunumu icin once kart ekle.</strong>
            <span>Kart eklediginde limit, ekstre ve odeme bilgileri burada acilacak.</span>
          </article>
        )}
      </section>

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
