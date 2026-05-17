import { useEffect, useRef, useState } from "react";

import { createAccount, fetchAccounts, updateAccount } from "../api/accounts";
import { fetchCardStatements, fetchWalletSummary } from "../api/wallet";
import CreditCard from "../components/CreditCard";
import "../styles/manage.css";

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
  if (type === "credit_card") return "Kredi Karti";
  if (type === "bank") return "Banka";
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
  const [activeCardIndex, setActiveCardIndex] = useState(0);
  const [showCompose, setShowCompose] = useState(false);
  const [cardDragOffset, setCardDragOffset] = useState(0);
  const dragOffsetRef = useRef(0);
  const swipeStateRef = useRef({
    pointerId: null,
    startX: 0,
    startY: 0,
    isActive: false,
    isHorizontal: false
  });

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
    setShowCompose(true);
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
    // Scroll to form smoothly
    setTimeout(() => {
      window.scrollTo({ top: document.body.scrollHeight, behavior: 'smooth' });
    }, 100);
  }

  function resetForm() {
    setEditingId(null);
    setForm(INITIAL_FORM);
    setShowCompose(false);
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
  const otherAccounts = accounts.filter((account) => account.type !== "credit_card");
  const statementByAccountId = new Map(statements.map((statement) => [statement.account_id, statement]));
  
  const activeCard = creditAccounts[activeCardIndex];
  const activeStatement = activeCard ? statementByAccountId.get(activeCard.id) : null;

  useEffect(() => {
    if (!creditAccounts.length) {
      setActiveCardIndex(0);
      setCardDragOffset(0);
      return;
    }

    if (activeCardIndex > creditAccounts.length - 1) {
      setActiveCardIndex(creditAccounts.length - 1);
    }
  }, [activeCardIndex, creditAccounts.length]);

  function selectCard(index) {
    if (index < 0 || index >= creditAccounts.length) {
      return;
    }

    setActiveCardIndex(index);
  }

  function resetSwipe() {
    dragOffsetRef.current = 0;
    swipeStateRef.current = {
      pointerId: null,
      startX: 0,
      startY: 0,
      isActive: false,
      isHorizontal: false
    };
    setCardDragOffset(0);
  }

  function startSwipeGesture(pointerId, clientX, clientY) {
    if (!Number.isFinite(clientX) || !Number.isFinite(clientY)) {
      return;
    }

    swipeStateRef.current = {
      pointerId,
      startX: clientX,
      startY: clientY,
      isActive: true,
      isHorizontal: false
    };
  }

  function moveSwipeGesture(clientX, clientY, preventDefault) {
    const swipeState = swipeStateRef.current;

    if (!swipeState.isActive || !Number.isFinite(clientX) || !Number.isFinite(clientY)) {
      return;
    }

    const deltaX = clientX - swipeState.startX;
    const deltaY = clientY - swipeState.startY;

    if (!swipeState.isHorizontal) {
      if (Math.abs(deltaX) < 10 && Math.abs(deltaY) < 10) {
        return;
      }

      if (Math.abs(deltaX) <= Math.abs(deltaY)) {
        resetSwipe();
        return;
      }

      swipeStateRef.current = {
        ...swipeState,
        isHorizontal: true
      };
    }

    preventDefault?.();

    const nextOffset = Math.max(-96, Math.min(96, deltaX));
    dragOffsetRef.current = nextOffset;
    setCardDragOffset(nextOffset);
  }

  function completeSwipeGesture() {
    const swipeState = swipeStateRef.current;
    const nextOffset = swipeState.isHorizontal ? dragOffsetRef.current : 0;

    if (nextOffset <= -52) {
      selectCard(activeCardIndex + 1);
    } else if (nextOffset >= 52) {
      selectCard(activeCardIndex - 1);
    }

    resetSwipe();
  }

  function handleCardPointerDown(event) {
    if (creditAccounts.length <= 1) {
      return;
    }

    if (event.pointerType === "mouse" && event.button !== 0) {
      return;
    }

    if (event.target.closest("button, input, select, textarea, a, label")) {
      return;
    }

    startSwipeGesture(event.pointerId, event.clientX, event.clientY);
    event.currentTarget.setPointerCapture?.(event.pointerId);
  }

  function handleCardPointerMove(event) {
    const swipeState = swipeStateRef.current;

    if (!swipeState.isActive || swipeState.pointerId !== event.pointerId) {
      return;
    }

    moveSwipeGesture(event.clientX, event.clientY, () => event.preventDefault());
  }

  function handleCardPointerEnd(event) {
    const swipeState = swipeStateRef.current;

    if (!swipeState.isActive || swipeState.pointerId !== event.pointerId) {
      return;
    }

    event.currentTarget.releasePointerCapture?.(event.pointerId);
    completeSwipeGesture();
  }

  function handleCardPointerCancel(event) {
    event.currentTarget.releasePointerCapture?.(event.pointerId);
    resetSwipe();
  }

  function handleCardTouchStart(event) {
    if (creditAccounts.length <= 1) {
      return;
    }

    if (event.target.closest("button, input, select, textarea, a, label")) {
      return;
    }

    const touch = event.touches[0];

    if (!touch) {
      return;
    }

    startSwipeGesture("touch", touch.clientX, touch.clientY);
  }

  function handleCardTouchMove(event) {
    const touch = event.touches[0];

    if (!touch) {
      return;
    }

    moveSwipeGesture(touch.clientX, touch.clientY, () => event.preventDefault());
  }

  function handleCardTouchEnd() {
    completeSwipeGesture();
  }

  return (
    <main className="shell shell--wallet">
      {/* Wallet Global Header */}
      <div className="manage-glass-header">
        <div className="manage-glass-header__copy">
          <p className="manage-glass-header__eyebrow">Cuzdanim</p>
          <h1 className="manage-glass-header__title">{summary ? formatMoney(summary.net_worth) : "---"}</h1>
        </div>
        <div className="manage-glass-header__actions">
          <button className="manage-fab-button" onClick={() => { setShowCompose(true); setTimeout(() => window.scrollTo({ top: document.body.scrollHeight, behavior: 'smooth' }), 100); }}>
            +
          </button>
        </div>
      </div>

      {loading && !accounts.length ? <section className="wallet-grid"><article className="metric-card">Yukleniyor...</article></section> : null}
      {error ? <p className="error-banner">{error}</p> : null}

      <div className="manage-viewport">
        {/* The Horizontal Carousel */}
        {creditAccounts.length > 0 ? (
          <section className="manage-carousel-stage">
            <div className="manage-focused-card-shell">
              {creditAccounts.length > 1 ? (
                <div className="manage-carousel-nav">
                  <button
                    className="manage-carousel-nav-btn"
                    type="button"
                    onClick={() => selectCard(activeCardIndex - 1)}
                    disabled={activeCardIndex === 0}
                  >
                    Onceki Kart
                  </button>
                  <button
                    className="manage-carousel-nav-btn"
                    type="button"
                    onClick={() => selectCard(activeCardIndex + 1)}
                    disabled={activeCardIndex === creditAccounts.length - 1}
                  >
                    Sonraki Kart
                  </button>
                </div>
              ) : null}

              <div
                className="manage-focused-card"
                data-dragging={cardDragOffset !== 0}
                onPointerDown={handleCardPointerDown}
                onPointerMove={handleCardPointerMove}
                onPointerUp={handleCardPointerEnd}
                onPointerCancel={handleCardPointerCancel}
                onTouchStart={handleCardTouchStart}
                onTouchMove={handleCardTouchMove}
                onTouchEnd={handleCardTouchEnd}
                style={{
                  transform: `translateX(${cardDragOffset}px)`,
                  opacity: 1 - Math.min(0.22, Math.abs(cardDragOffset) / 320)
                }}
              >
                <CreditCard
                  account={activeCard}
                  statement={activeStatement}
                  onEdit={startEditing}
                />
              </div>

              {creditAccounts.length > 1 ? (
                <div className="manage-carousel-dots" aria-label="Kart Secici">
                  {creditAccounts.map((account, idx) => (
                    <button
                      key={account.id}
                      className={`manage-carousel-dot ${idx === activeCardIndex ? "active" : ""}`}
                      type="button"
                      aria-label={`${account.name} kartini sec`}
                      aria-pressed={idx === activeCardIndex}
                      onClick={() => selectCard(idx)}
                    />
                  ))}
                </div>
              ) : null}
            </div>
          </section>
        ) : (
          <section className="manage-carousel-stage">
             <div className="manage-empty-card">
               <strong>Kart Bulunmuyor</strong>
               <span>Sisteme yeni bir kredi karti ekleyerek dijital cuzdaninizi olusturun.</span>
             </div>
          </section>
        )}

        {/* Dynamic Card Insights */}
        {activeCard ? (
          <section className="manage-dynamic-insights">
             <div className="manage-insights-grid">
                <article className="manage-insight-pane">
                  <span className="manage-insight-pane__label">Limit / Ekstre Paneli</span>
                  <div className="manage-insight-pane__bars">
                     <div className="manage-insight-pane__stat">
                       <strong>Borc</strong>
                       <span>{formatMoney(activeCard.used_credit ?? 0)}</span>
                     </div>
                     <div className="manage-insight-pane__stat">
                       <strong>Ekstre</strong>
                       <span>{activeStatement ? formatMoney(activeStatement.statement_amount) : "0,00 ₺"}</span>
                     </div>
                     <div className="manage-insight-pane__stat manage-insight-pane__stat--success">
                       <strong>Kullanilabilir</strong>
                       <span>{formatMoney(activeCard.available_credit ?? activeCard.balance ?? 0)}</span>
                     </div>
                  </div>
                </article>
                <article className="manage-insight-actions">
                  <button className="manage-action-btn" onClick={() => startEditing(activeCard)}>
                    <div className="manage-action-icon" aria-hidden="true">AY</div>
                    <span className="manage-action-label">Ayarlar</span>
                  </button>
                  <button className="manage-action-btn" onClick={() => handleToggleActive(activeCard)}>
                    <div className="manage-action-icon" aria-hidden="true">{activeCard.is_active ? "DN" : "AC"}</div>
                    <span className="manage-action-label">{activeCard.is_active ? "Dondur" : "Ac"}</span>
                  </button>
                </article>
             </div>
          </section>
        ) : null}

        {/* Existing Statements List */}
        <section className="manage-list-section">
           <h3 className="manage-list-title">Aktif Ekstreler</h3>
           <div className="manage-list">
             {activeCard && activeStatement ? (
                  <div className="manage-list-item" key={activeStatement.account_id}>
                    <div className="manage-list-icon manage-list-icon--statement" aria-hidden="true">EK</div>
                    <div className="manage-list-content">
                      <strong className="manage-list-primary">{activeStatement.account_name}</strong>
                      <span className="manage-list-secondary">Donem {formatShortDate(activeStatement.period_start)} - {formatShortDate(activeStatement.period_end)}</span>
                    </div>
                    <div className="manage-list-trailing">
                      <strong className="manage-list-amount">{formatMoney(activeStatement.statement_amount)}</strong>
                      <span className="manage-list-date">{activeStatement.due_date ? `S.O. ${formatShortDate(activeStatement.due_date)}` : "Tarih Yok"}</span>
                    </div>
                  </div>
             ) : (
                <p className="manage-list-empty">
                  {activeCard ? "Bu kart icin acik ekstre bulunmuyor." : "Acik ekstre bulunmuyor."}
                </p>
             )}
           </div>
        </section>
        
        {/* Other Accounts List */}
        <section className="manage-list-section">
           <h3 className="manage-list-title">Diger Hesaplar</h3>
           <div className="manage-list">
             {otherAccounts.length ? (
                otherAccounts.map(account => (
                  <div className="manage-list-item" key={account.id} onClick={() => startEditing(account)}>
                    <div className="manage-list-icon" aria-hidden="true">{account.type === "bank" ? "BK" : "HS"}</div>
                    <div className="manage-list-content">
                      <strong className="manage-list-primary">{account.name}</strong>
                      <span className="manage-list-secondary">{getAccountTypeLabel(account.type)} {account.issuer ? `· ${account.issuer}` : ''}</span>
                    </div>
                    <div className="manage-list-trailing">
                      <strong className="manage-list-amount">{formatMoney(account.balance)}</strong>
                      <span className={`manage-list-date ${!account.is_active ? "inactive" : ""}`}>{account.is_active ? "Aktif" : "Pasif"}</span>
                    </div>
                  </div>
                ))
             ) : (
                <p className="manage-list-empty">Diger hesap bulunmuyor.</p>
             )}
           </div>
        </section>

        {/* Drawer for Expanding Form */}
        {showCompose ? (
          <>
            <div className="manage-drawer-backdrop" onClick={() => setShowCompose(false)}></div>
            <section className="manage-drawer-form">
              <div className="manage-drawer-indicator"></div>
              <div className="manage-drawer-header">
                 <h2>{editingId ? "Hesabi Duzenle" : "Yeni Hesap Ekle"}</h2>
                 <button className="manage-drawer-close" onClick={resetForm}>Bitti</button>
              </div>
              
              <form className="manage-compose-form" onSubmit={handleSubmit}>
                <div className="manage-input-group">
                  <input id="acc-name" className="manage-input" value={form.name} onChange={e => handleChange("name", e.target.value)} required placeholder=" " />
                  <label htmlFor="acc-name" className="manage-floating-label">Hesap Adi</label>
                </div>
                
                <div className="manage-input-group">
                  <select id="acc-type" className="manage-input" value={form.type} onChange={e => handleChange("type", e.target.value)}>
                     <option value="bank">Banka Hesabi</option>
                     <option value="cash">Nakit Kasa</option>
                     <option value="credit_card">Kredi Karti</option>
                  </select>
                  <label htmlFor="acc-type" className="manage-floating-label">Tur</label>
                </div>

                <div className="manage-input-row">
                  <div className="manage-input-group">
                    <input id="acc-bal" className="manage-input" inputMode="decimal" value={form.balance} onChange={e => handleChange("balance", e.target.value)} placeholder=" " />
                    <label htmlFor="acc-bal" className="manage-floating-label">Guncel Bakiye (₺)</label>
                  </div>
                  <div className="manage-input-group">
                    <input id="acc-iss" className="manage-input" value={form.issuer} onChange={e => handleChange("issuer", e.target.value)} placeholder=" " />
                    <label htmlFor="acc-iss" className="manage-floating-label">Kurum (Ops.)</label>
                  </div>
                </div>

                {form.type === "credit_card" ? (
                  <>
                    <div className="manage-input-group mt-1">
                      <input id="acc-lim" className="manage-input" inputMode="decimal" value={form.credit_limit} onChange={e => handleChange("credit_limit", e.target.value)} placeholder=" " />
                      <label htmlFor="acc-lim" className="manage-floating-label">Toplam Limit (₺)</label>
                    </div>
                    <div className="manage-input-row">
                      <div className="manage-input-group">
                        <select id="acc-st" className="manage-input manage-input--select" value={form.statement_day} onChange={e => handleChange("statement_day", e.target.value)}>
                          <option value="">--</option>
                          {Array.from({ length: 31 }, (_, i) => i + 1).map((d) => (
                            <option key={d} value={d}>{d}</option>
                          ))}
                        </select>
                        <label htmlFor="acc-st" className="manage-floating-label manage-floating-label--filled">Kesim Gunu</label>
                      </div>
                      <div className="manage-input-group">
                        <select id="acc-due" className="manage-input manage-input--select" value={form.due_day} onChange={e => handleChange("due_day", e.target.value)}>
                          <option value="">--</option>
                          {Array.from({ length: 31 }, (_, i) => i + 1).map((d) => (
                            <option key={d} value={d}>{d}</option>
                          ))}
                        </select>
                        <label htmlFor="acc-due" className="manage-floating-label manage-floating-label--filled">Son Odeme Gunu</label>
                      </div>
                    </div>
                  </>
                ) : null}

                <button className="manage-submit-btn" disabled={saving} type="submit">
                  {saving ? "Kaydediliyor..." : editingId ? "Degisiklikleri Kaydet" : "Sisteme Ekle"}
                </button>
              </form>
            </section>
          </>
        ) : null}

      </div>
    </main>
  );
}
