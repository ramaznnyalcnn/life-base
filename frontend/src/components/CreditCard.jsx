function formatMoney(value) {
  return new Intl.NumberFormat("tr-TR", {
    style: "currency",
    currency: "TRY",
    maximumFractionDigits: 2
  }).format(Number(value ?? 0));
}

function formatPercent(value) {
  if (value == null) {
    return "Yok";
  }

  return `%${(Number(value) * 100).toFixed(0)}`;
}

function buildMaskedNumber(accountId) {
  const suffix = String(1000 + Number(accountId ?? 0)).slice(-4);
  return `5412 88•• •••• ${suffix}`;
}

function getCardTheme(account) {
  const seed = Number(account.id ?? 0) % 3;

  if (seed === 0) {
    return "violet";
  }
  if (seed === 1) {
    return "azure";
  }
  return "sunset";
}

export default function CreditCard({ account, statement, onEdit }) {
  const theme = getCardTheme(account);
  const availableCredit = Number(account.available_credit ?? account.balance ?? 0);
  const usedCredit = Number(account.used_credit ?? 0);
  const statementAmount = Number(statement?.statement_amount ?? 0);
  const limitAmount = Number(account.credit_limit ?? 0);
  const issuerLabel = (account.issuer ?? "Life OS").toUpperCase();

  return (
    <article className={`credit-card credit-card--${theme}`}>
      <div className="credit-card__toolbar">
        <div className="credit-card__toolbar-copy">
          <span className="credit-card__toolbar-label">Secili Kart</span>
          <strong>{account.name}</strong>
        </div>
        <button
          className="credit-card__settings"
          type="button"
          onClick={() => onEdit?.(account)}
        >
          Ayar
        </button>
      </div>

      <div className="credit-card__stack">
        <section className="credit-card__face credit-card__face--front">
          <div className="credit-card__glow" aria-hidden="true" />
          <div className="credit-card__mesh" aria-hidden="true">
            <span />
            <span />
            <span />
          </div>
          <span className="credit-card__face-badge">Kart</span>
          <div className="credit-card__brand-row">
            <div>
              <span className="credit-card__label">Signature Edition</span>
              <strong className="credit-card__front-issuer">{issuerLabel}</strong>
            </div>
            <div className="credit-card__brand-side">
              <span className="credit-card__brand-limit">Lifebase Select</span>
              <div className="credit-card__brand-mark" aria-hidden="true">
                <span />
                <span />
              </div>
            </div>
          </div>
          <div className="credit-card__chip-row">
            <div className="credit-card__chip" />
            <span className="credit-card__issuer">{account.name}</span>
          </div>
          <p className="credit-card__number">{buildMaskedNumber(account.id)}</p>
          <div className="credit-card__footer credit-card__footer--minimal">
            <span className="credit-card__contactless" aria-hidden="true" />
          </div>
        </section>

        <section className="credit-card__face credit-card__face--back">
          <div className="credit-card__back-header">
            <div>
              <span className="credit-card__label">Kart Bilgileri</span>
              <strong className="credit-card__back-title">{account.issuer ?? "Life OS Card"}</strong>
            </div>
            <span className="credit-card__back-code">{buildMaskedNumber(account.id).slice(-4)}</span>
          </div>
          <div className="credit-card__details">
            <div className="credit-card__detail-tile">
              <span className="credit-card__label">Toplam Limit</span>
              <strong>{formatMoney(limitAmount)}</strong>
            </div>
            <div className="credit-card__detail-tile">
              <span className="credit-card__label">Kullanilabilir</span>
              <strong>{formatMoney(availableCredit)}</strong>
            </div>
            <div className="credit-card__detail-tile">
              <span className="credit-card__label">Ekstre</span>
              <strong>{formatMoney(statementAmount)}</strong>
            </div>
            <div className="credit-card__detail-tile">
              <span className="credit-card__label">Kesim</span>
              <strong>{account.statement_day ?? "-"}</strong>
            </div>
          </div>
          <div className="credit-card__detail-footer">
            <span>Kart borcu {formatMoney(usedCredit)}</span>
            <span>Son odeme {account.due_day ?? "-"}</span>
          </div>
        </section>
      </div>
    </article>
  );
}
