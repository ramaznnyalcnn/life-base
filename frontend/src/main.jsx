import React from "react";
import ReactDOM from "react-dom/client";

import App from "./App";
import { registerServiceWorker } from "./pwa";
import "./styles/theme.css";

ReactDOM.createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);

registerServiceWorker().catch(() => {
  // PWA registration failures should not block app startup.
});
