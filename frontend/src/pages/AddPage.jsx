import { useState } from "react";

import { clarifyAI, executeAI } from "../api/ai";
import StatusCard from "../components/StatusCard";

const AI_TEMPLATES = [
  {
    id: "weekly-routine",
    title: "Haftalik Rutin",
    description: "Tekrarlayan spor, ders veya calisma planlari icin.",
    prompt: "Haftada 3 gun pazartesi carsamba cuma spor rutini ekle"
  },
  {
    id: "bill-payment",
    title: "Odeme Hatirlaticisi",
    description: "Kart, fatura veya kira odemesi gibi kayitlar icin.",
    prompt: "Her ayin 28'inde kredi karti odemesi icin hatirlatici ekle"
  },
  {
    id: "income-expense",
    title: "Gelir / Gider",
    description: "Finansal hareketleri AI ile hizli kaydetmek icin.",
    prompt: "Bugun 860 tl market gideri ekle, hesabim enpara"
  },
  {
    id: "appointment",
    title: "Randevu",
    description: "Tek seferlik toplantilar ve randevular icin.",
    prompt: "Yarin saat 14:30 disci randevusu ekle"
  }
];

const INITIAL_OPTIONS = {
  category: "",
  account: "",
  recurrence: "",
  reminder: "",
  important: false
};

function buildContextMessage(baseMessage, options) {
  const extras = [];

  if (options.category.trim()) {
    extras.push(`Kategori tercihi: ${options.category.trim()}`);
  }

  if (options.account.trim()) {
    extras.push(`Hesap veya kart tercihi: ${options.account.trim()}`);
  }

  if (options.recurrence.trim()) {
    extras.push(`Tekrar tercihi: ${options.recurrence.trim()}`);
  }

  if (options.reminder.trim()) {
    extras.push(`Hatirlatma tercihi: ${options.reminder.trim()}`);
  }

  if (options.important) {
    extras.push("Kaydi onemli olarak isaretle.");
  }

  if (!extras.length) {
    return baseMessage;
  }

  return `${baseMessage}\n\nEk tercihler:\n- ${extras.join("\n- ")}`;
}

export default function AddPage() {
  const [message, setMessage] = useState("");
  const [clarification, setClarification] = useState("");
  const [lastMessage, setLastMessage] = useState("");
  const [result, setResult] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [showOptions, setShowOptions] = useState(false);
  const [options, setOptions] = useState(INITIAL_OPTIONS);

  function resetComposer() {
    setMessage("");
    setClarification("");
    setLastMessage("");
    setOptions(INITIAL_OPTIONS);
    setShowOptions(false);
  }

  function updateOption(field, value) {
    setOptions((current) => ({
      ...current,
      [field]: value
    }));
  }

  async function handleExecute(event) {
    event.preventDefault();
    if (!message.trim()) {
      return;
    }

    setLoading(true);
    setError("");

    try {
      const enrichedMessage = buildContextMessage(message.trim(), options);
      const nextResult = await executeAI(enrichedMessage);
      setLastMessage(enrichedMessage);
      setResult(nextResult);
      setClarification("");
    } catch (nextError) {
      setError(nextError.message);
    } finally {
      setLoading(false);
    }
  }

  async function handleClarify(event) {
    event.preventDefault();
    if (!clarification.trim() || !lastMessage) {
      return;
    }

    setLoading(true);
    setError("");

    try {
      const nextResult = await clarifyAI(lastMessage, clarification.trim());
      setResult(nextResult);
      if (nextResult.status === "completed") {
        resetComposer();
      }
    } catch (nextError) {
      setError(nextError.message);
    } finally {
      setLoading(false);
    }
  }

  function applyTemplate(template) {
    setMessage(template.prompt);
    setError("");
  }

  const needsInput = result?.status === "needs_input";
  const activeOptionCount = Object.values(options).filter(Boolean).length;

  return (
    <main className="shell">
      <section className="compose-panel add-ai-panel">
        <div className="add-ai-panel__header">
          <div />
          <button
            className={`ghost-button ${showOptions ? "ghost-button--active" : ""}`}
            type="button"
            onClick={() => setShowOptions((current) => !current)}
          >
            {showOptions ? "Opsiyonlari gizle" : "Opsiyonel alanlar"}
          </button>
        </div>

        <form className="compose-form" onSubmit={handleExecute}>
          <label className="compose-form__label" htmlFor="message">
            Mesaj
          </label>
          <textarea
            id="message"
            className="compose-form__textarea"
            placeholder="Ornek: haftada 3 gun pazartesi carsamba cuma spor rutini ekle"
            rows={5}
            value={message}
            onChange={(event) => setMessage(event.target.value)}
          />

          {showOptions ? (
            <section className="add-ai-options">
              <div className="add-ai-options__header">
                <div>
                  <p className="status-card__eyebrow">Opsiyonel</p>
                  <h3>AI'a ek baglam ver</h3>
                </div>
                {activeOptionCount ? <span className="status-chip">{activeOptionCount} aktif tercih</span> : null}
              </div>

              <div className="add-ai-options__grid">
                <label className="compose-form__label" htmlFor="ai-category">
                  Kategori
                </label>
                <input
                  id="ai-category"
                  className="compose-form__input"
                  placeholder="Ornek: spor, market, abonelik"
                  value={options.category}
                  onChange={(event) => updateOption("category", event.target.value)}
                />

                <label className="compose-form__label" htmlFor="ai-account">
                  Hesap / Kart
                </label>
                <input
                  id="ai-account"
                  className="compose-form__input"
                  placeholder="Ornek: enpara, garanti bonus"
                  value={options.account}
                  onChange={(event) => updateOption("account", event.target.value)}
                />

                <label className="compose-form__label" htmlFor="ai-recurrence">
                  Tekrar tercihi
                </label>
                <input
                  id="ai-recurrence"
                  className="compose-form__input"
                  placeholder="Ornek: her cuma, ayda bir, 3 ay boyunca"
                  value={options.recurrence}
                  onChange={(event) => updateOption("recurrence", event.target.value)}
                />

                <label className="compose-form__label" htmlFor="ai-reminder">
                  Hatirlatma
                </label>
                <input
                  id="ai-reminder"
                  className="compose-form__input"
                  placeholder="Ornek: 1 gun once, 2 saat once"
                  value={options.reminder}
                  onChange={(event) => updateOption("reminder", event.target.value)}
                />
              </div>

              <label className="calendar-planner__checkbox add-ai-options__check">
                <input
                  checked={options.important}
                  type="checkbox"
                  onChange={(event) => updateOption("important", event.target.checked)}
                />
                <span>Onemli olarak isaretle</span>
              </label>
            </section>
          ) : null}

          <div className="add-ai-panel__actions">
            <button className="primary-button" disabled={loading} type="submit">
              {loading ? "Isleniyor..." : "AI ile isle"}
            </button>
            <button
              className="ghost-button"
              type="button"
              onClick={resetComposer}
              disabled={loading && !message.trim()}
            >
              Temizle
            </button>
          </div>
        </form>

        {error ? <p className="error-banner">{error}</p> : null}
        <StatusCard result={result} />

        {needsInput ? (
          <form className="clarify-form" onSubmit={handleClarify}>
            <div className="add-ai-panel__header">
              <div>
                <p className="status-card__eyebrow">AI Sorusu</p>
                <h2>Eksik bilgiyi tamamla</h2>
              </div>
            </div>
            <label className="compose-form__label" htmlFor="clarification">
              Ek bilgi
            </label>
            <input
              id="clarification"
              className="compose-form__input"
              placeholder="Ornek: sali-cumartesi tum gun, enpara, 500 tl"
              value={clarification}
              onChange={(event) => setClarification(event.target.value)}
            />
            <button className="secondary-button" disabled={loading} type="submit">
              {loading ? "Tamamlaniyor..." : "Bilgiyi gonder"}
            </button>
          </form>
        ) : null}
      </section>

      <section className="compose-panel add-template-panel">
        <div className="add-ai-panel__header">
          <div />
        </div>

        <div className="add-template-grid">
          {AI_TEMPLATES.map((template) => (
            <button
              key={template.id}
              className="add-template-card"
              type="button"
              onClick={() => applyTemplate(template)}
            >
              <span className="add-template-card__eyebrow">AI Prompt</span>
              <strong>{template.title}</strong>
              <p>{template.description}</p>
              <span className="add-template-card__prompt">{template.prompt}</span>
            </button>
          ))}
        </div>
      </section>
    </main>
  );
}
