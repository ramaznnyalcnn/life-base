import { useEffect, useState } from "react";

import { createAccount, updateAccount } from "../api/accounts";
import { fetchCardStatements, fetchWalletSummary } from "../api/wallet";
import CreditCard from "../components/CreditCard";

function formatMoney(value) {
  return new Intl.NumberFormat("tr-TR", {
    style: "currency",
    currency: "TRY",
    maximumFractionDigits: 2
  }).format(Number(value ?? 0));
}

function sumMoney(...values) {
  return values.reduce((total, value) => total + Number(value ?? 0), 0);
}

function getAccountChip(type) {
  if (type === "bank") {
    return { icon: "BK", tone: "bill", label: "Banka" };
  }
  if (type === "cash") {
    return { icon: "NK", tone: "income", label: "Nakit" };
  }
  return { icon: "KK", tone: "payment", label: "Kart" };
}

function formatDayValue(value) {
  return value ? `${value}. gun` : "-";
}

function formatPercentValue(value) {
  return `%${Math.round(Number(value ?? 0) * 100)}`;
}

const INITIAL_CARD_FORM = {
  name: "",
  issuer: "",
  balance: "0",
  credit_limit: "",
  statement_day: "",
  due_day: "",
  is_active: true
};

const INITIAL_SECTIONS = {
  flow: false,
  cards: false,
  accounts: false
};

export default function WalletPage({ onNavigate }) {
  const [summary, setSummary] = useState(null);
  const [statements, setStatements] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [cardFormOpen, setCardFormOpen] = useState(false);
  const [savingCard, setSavingCard] = useState(false);
  const [editingCardId, setEditingCardId] = useState(null);
  const [cardForm, setCardForm] = useState(INITIAL_CARD_FORM);
  const [sections, setSections] = useState(INITIAL_SECTIONS);
  const [selectedCardId, setSelectedCardId] = useState(null);
  const [flippedAssetId, setFlippedAssetId] = useState(null);

  function formatShortDate(value) {
    return new Intl.DateTimeFormat("tr-TR", {
      day: "2-digit",
      month: "short"
    }).format(new Date(value));
  }

  async function loadData() {
    setLoading(true);
    setError("");

    try {
      const [summaryPayload, statementPayload] = await Promise.all([
        fetchWalletSummary(),
        fetchCardStatements()
      ]);
      setSummary(summaryPayload);
      setStatements(statementPayload);
    } catch (nextError) {
      setError(nextError.message);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    let cancelled = false;

    async function load() {
      try {
        const [summaryPayload, statementPayload] = await Promise.all([
          fetchWalletSummary(),
          fetchCardStatements()
        ]);
        if (!cancelled) {
          setSummary(summaryPayload);
          setStatements(statementPayload);
          const firstCard = summaryPayload.accounts.find((account) => account.type === "credit_card");
          setSelectedCardId((current) => current ?? firstCard?.id ?? null);
        }
      } catch (nextError) {
        if (!cancelled) {
          setError(nextError.message);
        }
      } finally {
        if (!cancelled) {
          setLoading(false);
        }
      }
    }

    load();

    return () => {
      cancelled = true;
    };
  }, []);

  const creditAccounts = summary?.accounts.filter((account) => account.type === "credit_card") ?? [];
  const totalCardLimit = creditAccounts.reduce(
    (total, account) => total + Number(account.credit_limit ?? 0),
    0
  );
  const totalAvailableCredit = creditAccounts.reduce(
    (total, account) => total + Number(account.available_credit ?? account.balance ?? 0),
    0
  );
  const totalCardUsed = creditAccounts.reduce(
    (total, account) => total + Number(account.used_credit ?? 0),
    0
  );
  const otherAccounts = summary?.accounts.filter((account) => account.type !== "credit_card") ?? [];
  const stageItems = creditAccounts.length ? creditAccounts : otherAccounts;
  const stageKind = creditAccounts.length ? "cards" : "accounts";
  const monthlyExpense = Number(summary?.monthly_flow.total_expense ?? 0);
  const monthlyPayments = Number(summary?.monthly_flow.total_payments ?? 0);
  const latestStatement = statements[0] ?? null;
  const strongestAccount = otherAccounts[0] ?? null;
  const urgentStatement = statements.find((statement) => statement.due_date) ?? latestStatement;
  const selectedCard = creditAccounts.find((account) => account.id === selectedCardId) ?? creditAccounts[0] ?? null;
  const selectedStatement = selectedCard
    ? statements.find((statement) => statement.account_id === selectedCard.id) ?? null
    : null;
  const selectedCardAvailable = Number(selectedCard?.available_credit ?? selectedCard?.balance ?? 0);
  const selectedCardUsed = Number(selectedCard?.used_credit ?? 0);
  const selectedCardLimit = Number(selectedCard?.credit_limit ?? 0);
  const selectedCardUsage = selectedCardLimit ? (selectedCardUsed / selectedCardLimit) * 100 : 0;

  useEffect(() => {
    if (!creditAccounts.length) {
      setSelectedCardId(null);
      return;
    }

    if (!creditAccounts.some((account) => account.id === selectedCardId)) {
      setSelectedCardId(creditAccounts[0].id);
    }
  }, [creditAccounts, selectedCardId]);

  useEffect(() => {
    if (!stageItems.length) {
      setFlippedAssetId(null);
      return;
    }

    if (!stageItems.some((item) => item.id === flippedAssetId)) {
      setFlippedAssetId(null);
    }
  }, [flippedAssetId, stageItems]);

  function toggleSection(sectionKey) {
    setSections((current) => ({
      ...current,
      [sectionKey]: !current[sectionKey]
    }));
  }

  function openCreateCardForm() {
    setEditingCardId(null);
    setCardForm(INITIAL_CARD_FORM);
    setCardFormOpen(true);
    setSections((current) => ({
      ...current,
      cards: true
    }));
  }

  function openEditCardForm(account) {
    setEditingCardId(account.id);
    setCardForm({
      name: account.name,
      issuer: account.issuer ?? "",
      balance: String(account.balance ?? "0"),
      credit_limit: String(account.credit_limit ?? ""),
      statement_day: String(account.statement_day ?? ""),
      due_day: String(account.due_day ?? ""),
      is_active: account.is_active ?? true
    });
    setCardFormOpen(true);
    setSections((current) => ({
      ...current,
      cards: true
    }));
  }

  function closeCardForm() {
    setCardFormOpen(false);
    setEditingCardId(null);
    setCardForm(INITIAL_CARD_FORM);
  }

  async function handleCardSubmit(event) {
    event.preventDefault();
    setSavingCard(true);
    setError("");

    try {
      const payload = {
        name: cardForm.name.trim(),
        type: "credit_card",
        currency: "TRY",
        balance: cardForm.balance || "0",
        credit_limit: cardForm.credit_limit || "0",
        statement_day: Number(cardForm.statement_day || 0),
        due_day: Number(cardForm.due_day || 0),
        issuer: cardForm.issuer.trim() || null,
        is_active: cardForm.is_active
      };

      if (editingCardId) {
        await updateAccount(editingCardId, payload);
      } else {
        await createAccount(payload);
      }

      closeCardForm();
      await loadData();
    } catch (nextError) {
      setError(nextError.message);
    } finally {
      setSavingCard(false);
    }
  }

  function handleAssetFlip(account) {
    setFlippedAssetId((current) => (current === account.id ? null : account.id));
    if (account.type === "credit_card") {
      setSelectedCardId(account.id);
    }
  }

  return (
    <main className="shell shell--wallet">
      {loading ? <section className="wallet-grid"><article className="metric-card">Yukleniyor...</article></section> : null}
      {error ? <p className="error-banner">{error}</p> : null}

      {summary ? (
        <>
          <section className="wallet-asset-stage">
            <div className="wallet-asset-stage__header">
              <div>
                <p className="status-card__eyebrow">{stageKind === "cards" ? "Kartlar" : "Hesaplar"}</p>
                <h2>{stageKind === "cards" ? "Aktif kartlarini hizli gor" : "Aktif hesaplarini hizli gor"}</h2>
              </div>
              <button
                className="secondary-button"
                type="button"
                onClick={stageKind === "cards" ? openCreateCardForm : () => onNavigate?.("manage")}
              >
                {stageKind === "cards" ? "Kart Ekle" : "Hesap Yonet"}
              </button>
            </div>

            <div className="wallet-asset-stage__grid">
              {stageItems.length ? (
                stageItems.map((account) => {
                  const chip = getAccountChip(account.type);
                  const statement = statements.find((item) => item.account_id === account.id) ?? null;
                  const isFlipped = flippedAssetId === account.id;
                  const availableValue =
                    account.type === "credit_card"
                      ? formatMoney(Number(account.available_credit ?? account.balance ?? 0))
                      : formatMoney(account.balance);

                  return (
                    <button
                      key={account.id}
                      className={[
                        "wallet-flip-card",
                        isFlipped ? "wallet-flip-card--flipped" : "",
                        selectedCard?.id === account.id ? "wallet-flip-card--selected" : ""
                      ].filter(Boolean).join(" ")}
                      type="button"
                      onClick={() => handleAssetFlip(account)}
                    >
                      <div className="wallet-flip-card__inner">
                        <div className="wallet-flip-card__face wallet-flip-card__face--front">
                          <div className="wallet-flip-card__topline">
                            <span className="wallet-flip-card__chip">{chip.label}</span>
                            <span className="wallet-flip-card__issuer">{account.issuer ?? "Life Base"}</span>
                          </div>
                          <strong>{account.name}</strong>
                          <span className="wallet-flip-card__amount">{availableValue}</span>
                          <div className="wallet-flip-card__footer">
                            <span>{account.type === "credit_card" ? "Kullanilabilir" : "Bakiye"}</span>
                            <span>{account.type === "credit_card" ? formatMoney(account.credit_limit ?? 0) : chip.icon}</span>
                          </div>
                        </div>

                        <div className="wallet-flip-card__face wallet-flip-card__face--back">
                          <div className="wallet-flip-card__topline">
                            <span className="wallet-flip-card__chip">{chip.icon}</span>
                            <span>{account.is_active === false ? "Pasif" : "Aktif"}</span>
                          </div>
                          <strong>{account.name}</strong>
                          {account.type === "credit_card" ? (
                            <>
                              <span className="wallet-flip-card__amount">{formatMoney(account.used_credit ?? 0)}</span>
                              <div className="wallet-flip-card__footer wallet-flip-card__footer--detail">
                                <span>Kesim {formatDayValue(account.statement_day)}</span>
                                <span>
                                  {statement?.due_date ? `Odeme ${formatShortDate(statement.due_date)}` : `Son odeme ${formatDayValue(account.due_day)}`}
                                </span>
                              </div>
                            </>
                          ) : (
                            <>
                              <span className="wallet-flip-card__amount">{formatMoney(account.balance)}</span>
                              <div className="wallet-flip-card__footer wallet-flip-card__footer--detail">
                                <span>{chip.label}</span>
                                <span>{account.currency ?? "TRY"}</span>
                              </div>
                            </>
                          )}
                        </div>
                      </div>
                    </button>
                  );
                })
              ) : (
                <article className="wallet-snapshot-card">
                  <p className="wallet-snapshot-card__label">Hazir alan yok</p>
                  <strong>Kart veya hesap eklenmedi</strong>
                  <span>Ilk finans alanini yonetim ekranindan ekleyebilirsin.</span>
                </article>
              )}
            </div>
          </section>

          <section className="wallet-overview-panel">
            <div className="wallet-overview-panel__header">
              <div>
                <p className="status-card__eyebrow">Ana Toplam</p>
                <h1 className="wallet-overview-panel__value">{formatMoney(summary.net_worth)}</h1>
              </div>
            </div>
            <div className="wallet-overview-panel__meta">
              <article>
                <span>Bu Ay Gelen</span>
                <strong>{formatMoney(summary.monthly_flow.total_income)}</strong>
              </article>
              <article>
                <span>Bu Ay Giden</span>
                <strong>{formatMoney(monthlyExpense)}</strong>
              </article>
              <article>
                <span>Kullanilabilir Limit</span>
                <strong>{formatMoney(totalAvailableCredit)}</strong>
              </article>
            </div>
          </section>

          <section className="wallet-snapshot-grid">
            <article className="wallet-snapshot-card">
              <p className="wallet-snapshot-card__label">Akim Ozeti</p>
              <strong>{formatMoney(summary.monthly_flow.net_flow)}</strong>
              <span>
                Gelen {formatMoney(summary.monthly_flow.total_income)} / Gider {formatMoney(monthlyExpense)}
              </span>
            </article>
            <article className="wallet-snapshot-card">
              <p className="wallet-snapshot-card__label">Kart Odemeleri</p>
              <strong>{formatMoney(monthlyPayments)}</strong>
              <span>Kredi kartina yapilan odemeler giderden ayri izlenir.</span>
            </article>
            <article className="wallet-snapshot-card">
              <p className="wallet-snapshot-card__label">Siradaki Kart</p>
              <strong>{creditAccounts[0]?.name ?? "Kart yok"}</strong>
              <span>
                {latestStatement
                  ? `Son odeme ${latestStatement.due_date ? formatShortDate(latestStatement.due_date) : "-"}`
                  : "Aktif ekstre bekleniyor"}
              </span>
            </article>
            <article className="wallet-snapshot-card">
              <p className="wallet-snapshot-card__label">Hesap Ozeti</p>
              <strong>{strongestAccount?.name ?? "Hesap yok"}</strong>
              <span>
                {strongestAccount
                  ? `${formatMoney(strongestAccount.balance)} bakiye`
                  : "Banka veya nakit hesap eklenmedi"}
              </span>
            </article>
          </section>

          <section className="wallet-alert-strip" aria-label="Kisa durum ozeti">
            <article className="wallet-alert-card wallet-alert-card--primary">
              <p className="wallet-alert-card__eyebrow">Yaklasan Odeme</p>
              <strong>{urgentStatement?.account_name ?? "Planlanan odeme yok"}</strong>
              <span>
                {urgentStatement
                  ? `${urgentStatement.due_date ? formatShortDate(urgentStatement.due_date) : "-"} tarihinde ${formatMoney(urgentStatement.statement_amount)}`
                  : "Kart ekstresi geldikce burada gorunur."}
              </span>
            </article>
            <article className="wallet-alert-card">
              <p className="wallet-alert-card__eyebrow">Bu Hafta</p>
              <strong>{creditAccounts.length ? `${creditAccounts.length} kart aktif` : "Kart eklenmedi"}</strong>
              <span>
                {creditAccounts.length
                  ? `${formatMoney(totalAvailableCredit)} kullanilabilir limit seni bekliyor.`
                  : "Kart ekleyince limit ve ekstre ozeti burada gorunur."}
              </span>
            </article>
            <article className="wallet-alert-card">
              <p className="wallet-alert-card__eyebrow">Dikkat</p>
              <strong>{monthlyExpense > Number(summary.monthly_flow.total_income ?? 0) ? "Gider yukseliyor" : "Akis dengede"}</strong>
              <span>
                {monthlyExpense > Number(summary.monthly_flow.total_income ?? 0)
                  ? "Bu ay cikislar gelirden fazla. Detay icin gelir gider bolumunu ac."
                  : monthlyPayments > 0
                    ? `Kart odemeleri ${formatMoney(monthlyPayments)} ama bunlar gider hesabina dahil edilmiyor.`
                    : "Gelir gider dengesi su an kontrol altinda gorunuyor."}
              </span>
            </article>
          </section>

          <section className="wallet-fold-list">
            <article className={`wallet-fold ${sections.flow ? "wallet-fold--open" : ""}`}>
              <button
                className="wallet-fold__header"
                type="button"
                onClick={() => toggleSection("flow")}
                aria-expanded={sections.flow}
              >
                <div>
                  <p className="status-card__eyebrow">Gelir Gider</p>
                  <h2>Aylik ozet ve nakit akis detayi</h2>
                  <p className="wallet-fold__teaser">
                    Net akis {formatMoney(summary.monthly_flow.net_flow)}. Acinca gercek gider ve kart odemelerini ayri gorebilirsin.
                  </p>
                </div>
                <div className="wallet-fold__summary">
                  <strong>{formatMoney(summary.monthly_flow.net_flow)}</strong>
                  <span>{sections.flow ? "Kapat" : "Detay Goster"}</span>
                </div>
              </button>
              {sections.flow ? (
                <div className="wallet-fold__content">
                  <div className="wallet-detail-grid">
                    <article className="wallet-detail-card">
                      <span>Bu Ay Gelen</span>
                      <strong>{formatMoney(summary.monthly_flow.total_income)}</strong>
                    </article>
                    <article className="wallet-detail-card">
                      <span>Bu Ay Giden</span>
                      <strong>{formatMoney(monthlyExpense)}</strong>
                    </article>
                    <article className="wallet-detail-card">
                      <span>Kart Odemeleri</span>
                      <strong>{formatMoney(monthlyPayments)}</strong>
                    </article>
                    <article className="wallet-detail-card">
                      <span>Net Akis</span>
                      <strong>{formatMoney(summary.monthly_flow.net_flow)}</strong>
                    </article>
                    <article className="wallet-detail-card">
                      <span>Gecen Ay Net</span>
                      <strong>{formatMoney(summary.previous_month_net)}</strong>
                    </article>
                  </div>
                  <div className="wallet-fold__actions">
                    <button className="secondary-button" type="button" onClick={() => onNavigate?.("history")}>
                      Analiz Sayfasina Git
                    </button>
                  </div>
                </div>
              ) : null}
            </article>

            <article className={`wallet-fold ${sections.cards ? "wallet-fold--open" : ""}`}>
              <button
                className="wallet-fold__header"
                type="button"
                onClick={() => toggleSection("cards")}
                aria-expanded={sections.cards}
              >
                <div>
                  <p className="status-card__eyebrow">Kartlar</p>
                  <h2>Kredi kartlari ve ekstreler</h2>
                  <p className="wallet-fold__teaser">
                    {creditAccounts.length
                      ? `${creditAccounts[0].name} ve diger kartlar burada bekliyor.`
                      : "Kart ekledikce burada ozet gosterilecek."}
                  </p>
                </div>
                <div className="wallet-fold__summary">
                  <strong>{summary.active_card_count} aktif kart</strong>
                  <span>{sections.cards ? "Kapat" : "Detay Goster"}</span>
                </div>
              </button>
              {sections.cards ? (
                <div className="wallet-fold__content">
                  <section className="wallet-card-shell">
                    <div className="wallet-card-shell__header">
                      <div>
                        <p className="status-card__eyebrow">Kartlar</p>
                        <h3>Kart ve hesap ozeti</h3>
                      </div>
                      <div className="wallet-card-shell__actions">
                        <button className="secondary-button" type="button" onClick={openCreateCardForm}>
                          Kart Ekle
                        </button>
                      </div>
                    </div>

                    <div className="wallet-card-stat-rail">
                      <article className="wallet-card-stat-rail__item">
                        <span>Kullanilabilir</span>
                        <strong>{formatMoney(totalAvailableCredit)}</strong>
                      </article>
                      <article className="wallet-card-stat-rail__item">
                        <span>Ekstrede</span>
                        <strong>
                          {formatMoney(
                            statements.reduce(
                              (total, statement) => total + Number(statement.statement_amount ?? 0),
                              0
                            )
                          )}
                        </strong>
                      </article>
                      <article className="wallet-card-stat-rail__item">
                        <span>Toplam borc</span>
                        <strong>{formatMoney(totalCardUsed)}</strong>
                      </article>
                      <article className="wallet-card-stat-rail__item">
                        <span>Doluluk</span>
                        <strong>
                          {totalCardLimit ? `${Math.round((totalCardUsed / totalCardLimit) * 100)}%` : "%0"}
                        </strong>
                      </article>
                    </div>
                  </section>

                  {selectedCard ? (
                    <section className="wallet-card-stage">
                      <div className="wallet-card-stage__hero">
                        <div className="wallet-card-stage__card-column">
                          <section className="wallet-card-stage__spotlight">
                            <div>
                              <p className="status-card__eyebrow">Secili Kart</p>
                              <h3>{selectedCard.name}</h3>
                              <p>
                                {selectedCard.issuer ?? "Kredi karti"} gorunumu solda sabit, tum detaylar sagda.
                              </p>
                            </div>
                            <span className="wallet-card-stage__spotlight-chip">
                              {selectedStatement?.due_date
                                ? `Odeme ${formatShortDate(selectedStatement.due_date)}`
                                : "Odeme tarihi bekleniyor"}
                            </span>
                          </section>

                          <CreditCard
                            account={selectedCard}
                            onEdit={openEditCardForm}
                            statement={selectedStatement}
                          />
                        </div>

                        <aside className="wallet-card-detail-panel">
                          <div className="wallet-card-detail-panel__header">
                            <div>
                              <h3>{selectedCard.name}</h3>
                            </div>
                            <span className="wallet-card-detail-panel__badge">
                              {selectedStatement?.due_date ? `Son odeme ${formatShortDate(selectedStatement.due_date)}` : "Ekstre bekleniyor"}
                            </span>
                          </div>

                          <article className="wallet-card-detail-panel__hero-metric">
                            <div>
                              <span>Net durum</span>
                              <strong>{formatMoney(selectedCardAvailable)}</strong>
                            </div>
                            <div className="wallet-card-detail-panel__hero-meta">
                              <span>Limit {formatMoney(selectedCardLimit)}</span>
                              <span>Borc {formatMoney(selectedCardUsed)}</span>
                              <span>{selectedCardLimit ? `${Math.round(selectedCardUsage)}% dolu` : "%0 dolu"}</span>
                            </div>
                          </article>

                          <div className="wallet-card-detail-panel__metrics">
                            <article className="wallet-card-detail-panel__metric">
                              <span>Kullanilabilir limit</span>
                              <strong>{formatMoney(selectedCardAvailable)}</strong>
                            </article>
                            <article className="wallet-card-detail-panel__metric">
                              <span>Kart borcu</span>
                              <strong>{formatMoney(selectedCardUsed)}</strong>
                            </article>
                            <article className="wallet-card-detail-panel__metric">
                              <span>Doluluk</span>
                              <strong>{selectedCardLimit ? `${Math.round(selectedCardUsage)}%` : "%0"}</strong>
                            </article>
                            <article className="wallet-card-detail-panel__metric">
                              <span>Ekstre</span>
                              <strong>{formatMoney(selectedStatement?.statement_amount ?? 0)}</strong>
                            </article>
                          </div>

                          <div className="wallet-card-detail-panel__track">
                            <div className="wallet-card-detail-panel__track-bar">
                              <span style={{ width: `${Math.min(selectedCardUsage, 100)}%` }} />
                            </div>
                            <div className="wallet-card-detail-panel__track-meta">
                              <span>Limit {formatMoney(selectedCardLimit)}</span>
                              <span>{formatPercentValue(selectedCard?.utilization_ratio)}</span>
                            </div>
                          </div>

                          <div className="wallet-card-detail-panel__notes">
                            <article>
                              <span>Kesim</span>
                              <strong>{formatDayValue(selectedCard.statement_day)}</strong>
                            </article>
                            <article>
                              <span>Son odeme</span>
                              <strong>{formatDayValue(selectedCard.due_day)}</strong>
                            </article>
                            <article>
                              <span>Bu donem</span>
                              <strong>{selectedStatement ? `${selectedStatement.transaction_count} islem` : "Hareket yok"}</strong>
                            </article>
                          </div>

                          <div className="wallet-card-detail-panel__actions">
                            <button className="secondary-button" type="button" onClick={() => openEditCardForm(selectedCard)}>
                              Kart Ayarlari
                            </button>
                            <button className="ghost-button" type="button" onClick={() => onNavigate?.("history")}>
                              Kart Analizi
                            </button>
                          </div>
                        </aside>
                      </div>

                      <div className="wallet-card-stack" aria-label="Kart secici">
                        {creditAccounts.map((account) => {
                          const accountStatement = statements.find((statement) => statement.account_id === account.id);
                          const usage = Number(account.credit_limit ?? 0)
                            ? (Number(account.used_credit ?? 0) / Number(account.credit_limit ?? 0)) * 100
                            : 0;

                          return (
                            <button
                              key={account.id}
                              className={[
                                "wallet-card-stack__button",
                                selectedCard?.id === account.id ? "wallet-card-stack__button--active" : ""
                              ].filter(Boolean).join(" ")}
                              type="button"
                              onClick={() => setSelectedCardId(account.id)}
                            >
                              <span className="wallet-card-stack__issuer">{account.issuer ?? "Life OS Card"}</span>
                              <strong>{account.name}</strong>
                              <span className="wallet-card-stack__meta">
                                {formatMoney(Number(account.available_credit ?? account.balance ?? 0))}
                              </span>
                              <span className="wallet-card-stack__footer">
                                <span>{accountStatement?.due_date ? formatShortDate(accountStatement.due_date) : "Tarih yok"}</span>
                                <span>{Math.round(usage)}%</span>
                              </span>
                            </button>
                          );
                        })}
                      </div>
                    </section>
                  ) : (
                    <p className="muted-text">Gosterilecek kart yok.</p>
                  )}
                  <div className="wallet-card-ledger">
                    <div className="wallet-card-ledger__header">
                      <div>
                        <p className="status-card__eyebrow">Ekstreler</p>
                        <h3>Donem bazli kart hareketleri</h3>
                      </div>
                    </div>
                  </div>
                  <div className="account-list">
                    {statements.length ? (
                      statements.map((statement) => (
                        <article className="account-card" key={statement.account_id}>
                          <div className="account-card__header">
                            <div>
                              <h3>{statement.account_name}</h3>
                              <p>
                                Donem {formatShortDate(statement.period_start)} - {formatShortDate(statement.period_end)}
                              </p>
                            </div>
                            <strong>{formatMoney(statement.statement_amount)}</strong>
                          </div>
                          <div className="account-card__meta">
                            <span className="category-chip category-chip--payment">
                              <span className="category-chip__icon" aria-hidden="true">OD</span>
                              <span>Odeme {formatMoney(statement.payment_activity)}</span>
                            </span>
                            <span className="category-chip category-chip--bill">
                              <span className="category-chip__icon" aria-hidden="true">SO</span>
                              <span>Son Odeme {statement.due_date ? formatShortDate(statement.due_date) : "-"}</span>
                            </span>
                            <span className="category-chip category-chip--transport">
                              <span className="category-chip__icon" aria-hidden="true">RS</span>
                              <span>Reset {formatShortDate(statement.auto_resets_at)}</span>
                            </span>
                            <span className="category-chip category-chip--neutral">
                              <span className="category-chip__icon" aria-hidden="true">IS</span>
                              <span>{statement.transaction_count} islem</span>
                            </span>
                          </div>
                        </article>
                      ))
                    ) : (
                      <p className="muted-text">Aktif kredi karti ekstresi yok.</p>
                    )}
                  </div>
                  {cardFormOpen ? (
                    <form className="compose-form card-settings-panel" onSubmit={handleCardSubmit}>
                      <p className="status-card__eyebrow">
                        {editingCardId ? "Kart Ayarlari" : "Yeni Kart"}
                      </p>
                      <label className="compose-form__label" htmlFor="card-name">
                        Kart Adi
                      </label>
                      <input
                        id="card-name"
                        className="compose-form__input"
                        value={cardForm.name}
                        onChange={(event) =>
                          setCardForm((current) => ({
                            ...current,
                            name: event.target.value
                          }))
                        }
                      />
                      <label className="compose-form__label" htmlFor="card-issuer">
                        Kurum
                      </label>
                      <input
                        id="card-issuer"
                        className="compose-form__input"
                        value={cardForm.issuer}
                        onChange={(event) =>
                          setCardForm((current) => ({
                            ...current,
                            issuer: event.target.value
                          }))
                        }
                      />
                      <label className="compose-form__label" htmlFor="card-limit">
                        Toplam Limit
                      </label>
                      <input
                        id="card-limit"
                        className="compose-form__input"
                        inputMode="decimal"
                        value={cardForm.credit_limit}
                        onChange={(event) =>
                          setCardForm((current) => ({
                            ...current,
                            credit_limit: event.target.value
                          }))
                        }
                      />
                      <label className="compose-form__label" htmlFor="card-balance">
                        Kalan Limit
                      </label>
                      <input
                        id="card-balance"
                        className="compose-form__input"
                        inputMode="decimal"
                        value={cardForm.balance}
                        onChange={(event) =>
                          setCardForm((current) => ({
                            ...current,
                            balance: event.target.value
                          }))
                        }
                      />
                      <label className="compose-form__label" htmlFor="card-statement">
                        Kesim Gunu
                      </label>
                      <input
                        id="card-statement"
                        className="compose-form__input"
                        inputMode="numeric"
                        value={cardForm.statement_day}
                        onChange={(event) =>
                          setCardForm((current) => ({
                            ...current,
                            statement_day: event.target.value
                          }))
                        }
                      />
                      <label className="compose-form__label" htmlFor="card-due">
                        Son Odeme Gunu
                      </label>
                      <input
                        id="card-due"
                        className="compose-form__input"
                        inputMode="numeric"
                        value={cardForm.due_day}
                        onChange={(event) =>
                          setCardForm((current) => ({
                            ...current,
                            due_day: event.target.value
                          }))
                        }
                      />
                      <label className="compose-form__label" htmlFor="card-active">
                        Durum
                      </label>
                      <select
                        id="card-active"
                        className="compose-form__input"
                        value={cardForm.is_active ? "active" : "inactive"}
                        onChange={(event) =>
                          setCardForm((current) => ({
                            ...current,
                            is_active: event.target.value === "active"
                          }))
                        }
                      >
                        <option value="active">Aktif</option>
                        <option value="inactive">Pasif</option>
                      </select>
                      <div className="event-actions">
                        <button className="primary-button" disabled={savingCard} type="submit">
                          {savingCard ? "Kaydediliyor..." : editingCardId ? "Guncelle" : "Kart Ekle"}
                        </button>
                        <button className="ghost-button" type="button" onClick={closeCardForm}>
                          Vazgec
                        </button>
                      </div>
                    </form>
                  ) : null}
                  <div className="wallet-fold__actions">
                    <button className="secondary-button" type="button" onClick={() => onNavigate?.("manage")}>
                      Hesap Yonetimine Git
                    </button>
                    <button className="ghost-button" type="button" onClick={() => onNavigate?.("history")}>
                      Analiz Sayfasina Git
                    </button>
                  </div>
                </div>
              ) : null}
            </article>

            <article className={`wallet-fold ${sections.accounts ? "wallet-fold--open" : ""}`}>
              <button
                className="wallet-fold__header"
                type="button"
                onClick={() => toggleSection("accounts")}
                aria-expanded={sections.accounts}
              >
                <div>
                  <p className="status-card__eyebrow">Diger Hesaplar</p>
                  <h2>Banka ve nakit hesap ozeti</h2>
                  <p className="wallet-fold__teaser">
                    {otherAccounts.length
                      ? `${otherAccounts[0].name} dahil ${otherAccounts.length} hesap ozetleniyor.`
                      : "Hesap ekledikce burada kisa ozet gosterilecek."}
                  </p>
                </div>
                <div className="wallet-fold__summary">
                  <strong>{summary.active_account_count - summary.active_card_count} aktif hesap</strong>
                  <span>{sections.accounts ? "Kapat" : "Detay Goster"}</span>
                </div>
              </button>
              {sections.accounts ? (
                <div className="wallet-fold__content">
                  <div className="account-list">
                    {otherAccounts.map((account) => {
                      const chip = getAccountChip(account.type);

                      return (
                        <article className="account-card" key={account.id}>
                          <div className="account-card__header">
                            <div>
                              <h3>{account.name}</h3>
                              <p>{account.type === "bank" ? "Banka" : "Nakit"}</p>
                            </div>
                            <strong>{formatMoney(account.balance)}</strong>
                          </div>
                          <div className="account-card__meta">
                            <span className={`category-chip category-chip--${chip.tone}`}>
                              <span className="category-chip__icon" aria-hidden="true">{chip.icon}</span>
                              <span>{chip.label}</span>
                            </span>
                            <span>{account.issuer ?? "Kisisel hesap"}</span>
                            <span>{account.currency}</span>
                          </div>
                        </article>
                      );
                    })}
                    {!otherAccounts.length ? (
                      <p className="muted-text">Diger hesap yok.</p>
                    ) : null}
                  </div>
                  <div className="wallet-fold__actions">
                    <button className="secondary-button" type="button" onClick={() => onNavigate?.("manage")}>
                      Hesap Yonetimine Git
                    </button>
                    <button className="ghost-button" type="button" onClick={() => onNavigate?.("history")}>
                      Analiz Sayfasina Git
                    </button>
                  </div>
                </div>
              ) : null}
            </article>
          </section>
        </>
      ) : null}
    </main>
  );
}
