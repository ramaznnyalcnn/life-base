import NotificationControl from "../components/NotificationControl";

export default function SettingsPage() {
  return (
    <main className="shell">
      <section className="settings-panel">
        <div className="accounts-panel__header">
          <p className="status-card__eyebrow">Ayarlar</p>
        </div>
        <NotificationControl />
      </section>
    </main>
  );
}
