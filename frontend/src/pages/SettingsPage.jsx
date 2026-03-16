import NotificationControl from "../components/NotificationControl";

export default function SettingsPage({ currentUser, onLogout }) {
  return (
    <main className="shell">
      <section className="settings-panel">
        <div className="accounts-panel__header">
          <p className="status-card__eyebrow">Ayarlar</p>
        </div>
        {currentUser ? (
          <section className="settings-panel__identity">
            <div>
              <strong>{currentUser.display_name}</strong>
              <p>{currentUser.email}</p>
            </div>
            <button className="ghost-button" type="button" onClick={onLogout}>
              Cikis yap
            </button>
          </section>
        ) : null}
        <NotificationControl />
        {currentUser?.is_admin ? (
          <section className="settings-users-panel">
            <div className="manage-section-header">
              <div>
                <p className="status-card__eyebrow">Kullanicilar</p>
                <h2>Yeni kullanici sadece terminalden eklenir</h2>
              </div>
              <span className="manage-section-header__badge">CLI gerekli</span>
            </div>
            <article className="wallet-snapshot-card">
              <p className="wallet-snapshot-card__label">Terminal komutu</p>
              <strong>
                <code>cd backend && ../.venv/bin/python -m app.cli.create_user --email kisi@example.com --name "Kisi" --password "cok-guclu-sifre"</code>
              </strong>
              <span>UI uzerinden kullanici acma kapatildi. Yeni hesap ancak terminal komutuyla olusur.</span>
            </article>
          </section>
        ) : null}
      </section>
    </main>
  );
}
