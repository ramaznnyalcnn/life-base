import { useEffect, useState } from "react";

import { fetchWalletSummary } from "../api/wallet";

function formatMoney(value) {
  return new Intl.NumberFormat("tr-TR", {
    style: "currency",
    currency: "TRY",
    maximumFractionDigits: 2
  }).format(Number(value ?? 0));
}

function getAccountChip(type) {
  if (type === "bank") {
    return { icon: "BK", label: "Banka" };
  }
  if (type === "cash") {
    return { icon: "NK", label: "Nakit" };
  }
  return { icon: "KK", label: "Kart" };
}

function renderAssetCard(account) {
  const chip = getAccountChip(account.type);
  const availableValue =
    account.type === "credit_card"
      ? formatMoney(Number(account.available_credit ?? account.balance ?? 0))
      : formatMoney(account.balance);

  return (
    <article key={account.id} className="wallet-flip-card wallet-flip-card--static">
      <div className="wallet-flip-card__inner">
        <div className="wallet-flip-card__face wallet-flip-card__face--front">
          <div className="wallet-flip-card__topline">
            <span className="wallet-flip-card__chip">{chip.label}</span>
            <span className="wallet-flip-card__issuer">{account.issuer ?? "Life Base"}</span>
          </div>
          <strong>{account.name}</strong>
          <span className="wallet-flip-card__amount">{availableValue}</span>
          <div className="wallet-flip-card__footer">
            <span>{account.type === "credit_card" ? "Hizli gorunum" : "Bakiye"}</span>
            <span>{account.type === "credit_card" ? "Detay Yonet'te" : account.currency ?? chip.icon}</span>
          </div>
        </div>
      </div>
    </article>
  );
}

function WalletAssetSection({
  eyebrow,
  title,
  actionLabel,
  items,
  emptyTitle,
  emptyText,
  onManage
}) {
  return (
    <section className="wallet-asset-stage">
      <div className="wallet-asset-stage__header">
        <div>
          <p className="status-card__eyebrow">{eyebrow}</p>
          <h2>{title}</h2>
        </div>
        <button className="secondary-button" type="button" onClick={onManage}>
          {actionLabel}
        </button>
      </div>

      <div className="wallet-asset-stage__grid">
        {items.length ? (
          items.map((account) => renderAssetCard(account))
        ) : (
          <article className="wallet-snapshot-card">
            <p className="wallet-snapshot-card__label">{emptyTitle}</p>
            <strong>{emptyText}</strong>
          </article>
        )}
      </div>
    </section>
  );
}

export default function WalletPage({ onNavigate }) {
  const [summary, setSummary] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    let cancelled = false;

    async function load() {
      try {
        const summaryPayload = await fetchWalletSummary();

        if (!cancelled) {
          setSummary(summaryPayload);
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

  const creditAccounts = summary?.accounts?.filter((account) => account.type === "credit_card") ?? [];
  const otherAccounts = summary?.accounts?.filter((account) => account.type !== "credit_card") ?? [];
  const monthlyIncome = Number(summary?.monthly_flow?.total_income ?? 0);
  const monthlyExpense = Number(summary?.monthly_flow?.total_expense ?? 0);

  return (
    <main className="shell shell--wallet">
      {loading ? <section className="wallet-grid"><article className="metric-card">Yukleniyor...</article></section> : null}
      {error ? <p className="error-banner">{error}</p> : null}

      {summary ? (
        <>
          <section className="wallet-overview-panel">
            <div className="wallet-overview-panel__header">
              <div>
                <p className="status-card__eyebrow">Ana Toplam</p>
                <h1 className="wallet-overview-panel__value">{formatMoney(summary.net_worth)}</h1>
              </div>
            </div>
            <div className="wallet-overview-panel__meta wallet-overview-panel__meta--duo">
              <article>
                <span>Gelir</span>
                <strong>{formatMoney(monthlyIncome)}</strong>
              </article>
              <article>
                <span>Gider</span>
                <strong>{formatMoney(monthlyExpense)}</strong>
              </article>
            </div>
          </section>

          <WalletAssetSection
            eyebrow="Kartlar"
            title="Kartlarini izle"
            actionLabel="Kart Yonet"
            items={creditAccounts}
            emptyTitle="Kart yok"
            emptyText="Kart ekleyince burada gorunecek."
            onManage={() => onNavigate?.("manage")}
          />

          <WalletAssetSection
            eyebrow="Hesaplar"
            title="Hesaplarini izle"
            actionLabel="Hesap Yonet"
            items={otherAccounts}
            emptyTitle="Hesap yok"
            emptyText="Banka veya nakit hesap ekleyince burada gorunecek."
            onManage={() => onNavigate?.("manage")}
          />
        </>
      ) : null}
    </main>
  );
}
