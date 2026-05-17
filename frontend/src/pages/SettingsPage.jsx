import NotificationControl from "../components/NotificationControl";
import { useTheme } from "../hooks/useTheme";

export default function SettingsPage({ currentUser, onLogout }) {
  const [theme, setTheme] = useTheme();

  return (
    <main className="shell">
      <section className="settings-panel">
        <div className="accounts-panel__header">
          <p className="status-card__eyebrow">Ayarlar</p>
          <h1 className="wallet-overview-panel__value" style={{ fontSize: '2rem', marginBottom: '24px' }}>Tercihler</h1>
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

        <section className="wallet-asset-stage">
          <div className="wallet-asset-stage__header">
            <div>
              <p className="status-card__eyebrow">Tema</p>
              <h2 style={{ fontSize: '1.25rem', fontWeight: 600 }}>Görünümü Seç</h2>
            </div>
          </div>
          <div style={{ display: 'flex', gap: '12px', marginBottom: '32px' }}>
            <button 
              className={`wallet-flip-card ${theme === 'dark' ? 'theme-active' : ''}`}
              onClick={() => setTheme('dark')}
              style={{ flex: 1, padding: '16px', textAlign: 'center', opacity: theme === 'dark' ? 1 : 0.6, border: theme === 'dark' ? '1px solid var(--wf-accent)' : '' }}
            >
              <span style={{ fontSize: '1.5rem', display: 'block', marginBottom: '8px' }}>🌙</span>
              <strong style={{ fontSize: '0.875rem', display: 'block', color: '#8ba4ff' }}>Uzay Siyahi</strong>
            </button>
            <button 
              className={`wallet-flip-card ${theme === 'light' ? 'theme-active' : ''}`}
              onClick={() => setTheme('light')}
              style={{ flex: 1, padding: '16px', textAlign: 'center', opacity: theme === 'light' ? 1 : 0.6, border: theme === 'light' ? '1px solid var(--wf-accent)' : '' }}
            >
              <span style={{ fontSize: '1.5rem', display: 'block', marginBottom: '8px' }}>☀️</span>
              <strong style={{ fontSize: '0.875rem', display: 'block', color: '#d38a1f' }}>Gunes Beyazi</strong>
            </button>
            <button 
              className={`wallet-flip-card ${theme === 'zen' ? 'theme-active' : ''}`}
              onClick={() => setTheme('zen')}
              style={{ flex: 1, padding: '16px', textAlign: 'center', opacity: theme === 'zen' ? 1 : 0.6, border: theme === 'zen' ? '1px solid var(--wf-accent)' : '' }}
            >
              <span style={{ fontSize: '1.5rem', display: 'block', marginBottom: '8px' }}>🍃</span>
              <strong style={{ fontSize: '0.875rem', display: 'block', color: '#6b8f64' }}>Zen Kum</strong>
            </button>
          </div>
        </section>

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
