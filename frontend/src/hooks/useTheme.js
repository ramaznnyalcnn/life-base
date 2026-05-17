import { useState, useEffect } from 'react';

export function useTheme() {
  const [theme, setThemeState] = useState(() => {
    return localStorage.getItem('app-theme') || 'dark';
  });

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme);
    localStorage.setItem('app-theme', theme);
  }, [theme]);

  return [theme, setThemeState];
}
