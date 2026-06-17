function renderStatusTitle(status) {
  switch (status) {
    case "completed":
      return "Islem tamamlandi";
    case "needs_input":
      return "Ek bilgi gerekli";
    case "unsupported":
      return "Arayuzden gosterilecek";
    default:
      return "Durum";
  }
}

export default function StatusCard({ result }) {
  if (!result) {
    return null;
  }

  return (
    <section className={`status-card status-card--${result.status}`}>
      <p className="status-card__eyebrow">{renderStatusTitle(result.status)}</p>
      <h2 className="status-card__message">{result.assistant_message}</h2>
      {result.follow_up_question ? (
        <p className="status-card__question">{result.follow_up_question}</p>
      ) : null}
      {result.missing_fields?.length ? (
        <div className="status-card__chips">
          {result.missing_fields.map((field) => (
            <span className="status-chip" key={field}>
              {field}
            </span>
          ))}
        </div>
      ) : null}
      <div className="status-card__meta">
        {result.transaction_id ? <span>Transaction #{result.transaction_id}</span> : null}
        {result.event_id ? <span>Event #{result.event_id}</span> : null}
        {result.recurring_event_id ? <span>Rutin #{result.recurring_event_id}</span> : null}
      </div>
    </section>
  );
}
