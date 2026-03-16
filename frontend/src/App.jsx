import { useEffect, useRef, useState } from "react";

import { fetchBackendHealth, fetchCurrentUser } from "./api/auth";
import { clearStoredSession, getStoredSession, SESSION_EVENT_NAME, setStoredSession } from "./auth/session";
import AddPage from "./pages/AddPage";
import CalendarPage from "./pages/Calendar";
import HistoryPage from "./pages/HistoryPage";
import LoginPage from "./pages/LoginPage";
import ManagePage from "./pages/ManagePage";
import SettingsPage from "./pages/SettingsPage";
import WalletPage from "./pages/Wallet";
import { enablePushNotifications } from "./notifications";

const NAV_ITEMS = [
  { id: "wallet", label: "Cuzdan", badge: "💳", page: WalletPage },
  { id: "calendar", label: "Takvim", badge: "🗓", page: CalendarPage },
  { id: "add", label: "Ekle", badge: "✚", page: AddPage },
  { id: "history", label: "Gecmis", badge: "🧾", page: HistoryPage },
  { id: "manage", label: "Yonet", badge: "◌", page: ManagePage },
  { id: "settings", label: "Ayarlar", badge: "⚙", page: SettingsPage }
];

export default function App() {
  const [activeTab, setActiveTab] = useState("wallet");
  const [session, setSession] = useState(() => getStoredSession());
  const [authReady, setAuthReady] = useState(false);
  const [requiresLogin, setRequiresLogin] = useState(true);
  const [bootError, setBootError] = useState("");
  const [isDockSliding, setIsDockSliding] = useState(false);
  const holdTimerRef = useRef(null);
  const pointerIdRef = useRef(null);
  const suppressClickRef = useRef(false);
  const slideStartedRef = useRef(false);

  useEffect(() => {
    let cancelled = false;

    async function bootstrap() {
      try {
        const health = await fetchBackendHealth();
        if (cancelled) {
          return;
        }

        const secureMode = !health?.mode?.single_user;
        setRequiresLogin(secureMode);
        setBootError("");

        const storedSession = getStoredSession();
        if (!secureMode || !storedSession?.accessToken) {
          setAuthReady(true);
          return;
        }

        const currentUser = await fetchCurrentUser();
        if (cancelled) {
          return;
        }

        const nextSession = {
          accessToken: storedSession.accessToken,
          user: currentUser
        };
        setStoredSession(nextSession);
        setSession(nextSession);
        setAuthReady(true);
      } catch (nextError) {
        if (!cancelled) {
          setBootError(nextError.message);
          setAuthReady(true);
        }
      }
    }

    bootstrap();

    function handleSessionChange() {
      if (!cancelled) {
        setSession(getStoredSession());
      }
    }

    window.addEventListener(SESSION_EVENT_NAME, handleSessionChange);

    return () => {
      cancelled = true;
      window.removeEventListener(SESSION_EVENT_NAME, handleSessionChange);
    };
  }, []);

  useEffect(() => {
    if ((requiresLogin && !session?.accessToken) || !authReady) {
      return;
    }

    enablePushNotifications().catch(() => null);
  }, [authReady, requiresLogin, session?.accessToken]);

  useEffect(() => () => {
    if (holdTimerRef.current !== null) {
      window.clearTimeout(holdTimerRef.current);
    }
  }, []);

  function clearHoldTimer() {
    if (holdTimerRef.current !== null) {
      window.clearTimeout(holdTimerRef.current);
      holdTimerRef.current = null;
    }
  }

  function releaseClickSuppression() {
    window.setTimeout(() => {
      suppressClickRef.current = false;
    }, 0);
  }

  function finishDockGesture() {
    clearHoldTimer();
    pointerIdRef.current = null;

    if (slideStartedRef.current) {
      suppressClickRef.current = true;
      releaseClickSuppression();
    }

    slideStartedRef.current = false;
    setIsDockSliding(false);
  }

  function handleTabPointerDown(tabId, event) {
    if (event.button !== undefined && event.button !== 0) {
      return;
    }

    clearHoldTimer();
    pointerIdRef.current = event.pointerId;
    slideStartedRef.current = false;

    holdTimerRef.current = window.setTimeout(() => {
      suppressClickRef.current = true;
      slideStartedRef.current = true;
      setIsDockSliding(true);
      setActiveTab(tabId);
    }, 180);
  }

  function handleDockPointerMove(event) {
    if (!isDockSliding || pointerIdRef.current !== event.pointerId) {
      return;
    }

    const targetButton = document
      .elementFromPoint(event.clientX, event.clientY)
      ?.closest("[data-tab-id]");
    const targetId = targetButton?.getAttribute("data-tab-id");

    if (!targetId || targetId === activeTab) {
      return;
    }

    setActiveTab(targetId);
  }

  function handleTabClick(tabId) {
    if (isDockSliding || suppressClickRef.current) {
      return;
    }

    setActiveTab(tabId);
  }

  const activeItem = NAV_ITEMS.find((item) => item.id === activeTab) ?? NAV_ITEMS[0];
  const ActivePage = activeItem.page;
  const currentUser = session?.user ?? null;

  if (!authReady) {
    return (
      <main className="shell shell--auth">
        <section className="compose-panel auth-panel">
          <p className="status-card__eyebrow">Life Base</p>
          <h1>Hazirlaniyor...</h1>
        </section>
      </main>
    );
  }

  if (requiresLogin && !session?.accessToken) {
    return (
      <LoginPage
        bootError={bootError}
        onAuthenticated={(nextUser) => {
          setSession((current) => (current ? { ...current, user: nextUser } : getStoredSession()));
          setBootError("");
        }}
      />
    );
  }

  return (
    <div className="app-frame">
      <div className="app-content">
        <div className="app-content__page">
          <ActivePage
            onNavigate={setActiveTab}
            currentUser={currentUser}
            onLogout={() => {
              clearStoredSession();
              setSession(null);
              setActiveTab("wallet");
            }}
          />
        </div>
      </div>

      <div className="bottom-nav-wrap">
        <nav
          className={`bottom-nav ${isDockSliding ? "bottom-nav--sliding" : ""}`}
          aria-label="Ana gezinme"
          onPointerMove={handleDockPointerMove}
          onPointerUp={finishDockGesture}
          onPointerCancel={finishDockGesture}
          onPointerLeave={finishDockGesture}
        >
          {NAV_ITEMS.map((item) => (
            <button
              key={item.id}
              className={[
                "bottom-nav__item",
                activeTab === item.id ? "bottom-nav__item--active" : "",
                isDockSliding && activeTab === item.id ? "bottom-nav__item--sliding" : ""
              ].filter(Boolean).join(" ")}
              type="button"
              data-tab-id={item.id}
              aria-label={item.label}
              aria-pressed={activeTab === item.id}
              onPointerDown={(event) => handleTabPointerDown(item.id, event)}
              onClick={() => handleTabClick(item.id)}
            >
              <span className="bottom-nav__icon" aria-hidden="true">
                {item.badge}
              </span>
            </button>
          ))}
        </nav>
      </div>
    </div>
  );
}
