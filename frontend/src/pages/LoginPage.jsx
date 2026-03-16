import { useState } from "react";

import { login } from "../api/auth";
import { setStoredSession } from "../auth/session";

const INITIAL_FORM = {
  email: "",
  password: ""
};

export default function LoginPage({ onAuthenticated, bootError = "" }) {
  const [form, setForm] = useState(INITIAL_FORM);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  function handleChange(field, value) {
    setForm((current) => ({
      ...current,
      [field]: value
    }));
  }

  async function handleSubmit(event) {
    event.preventDefault();
    setLoading(true);
    setError("");

    try {
      const session = await login({
        email: form.email.trim().toLowerCase(),
        password: form.password
      });
      setStoredSession({
        accessToken: session.access_token,
        user: session.user
      });
      onAuthenticated?.(session.user);
    } catch (nextError) {
      setError(nextError.message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <main className="shell shell--auth">
      <section className="compose-panel auth-panel">
        <div className="manage-section-header">
          <div>
            <p className="status-card__eyebrow">Life Base</p>
            <h1>Giris yap</h1>
          </div>
          <span className="manage-section-header__badge">Cok kullanicili erisim</span>
        </div>

        <form className="compose-form" onSubmit={handleSubmit}>
          <label className="compose-form__label" htmlFor="login-email">
            E-posta
          </label>
          <input
            id="login-email"
            className="compose-form__input"
            type="email"
            autoComplete="username"
            value={form.email}
            onChange={(event) => handleChange("email", event.target.value)}
          />

          <label className="compose-form__label" htmlFor="login-password">
            Sifre
          </label>
          <input
            id="login-password"
            className="compose-form__input"
            type="password"
            autoComplete="current-password"
            value={form.password}
            onChange={(event) => handleChange("password", event.target.value)}
          />

          <button className="primary-button" disabled={loading} type="submit">
            {loading ? "Giris yapiliyor..." : "Giris yap"}
          </button>
        </form>

        {bootError ? <p className="error-banner">{bootError}</p> : null}
        {error ? <p className="error-banner">{error}</p> : null}
      </section>
    </main>
  );
}
