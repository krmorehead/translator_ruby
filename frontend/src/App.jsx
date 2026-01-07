import { useEffect } from "react";
import UnifiedIDE from "./components/UnifiedIDE";
import "./App.css";

function App() {
  const path = window.location.pathname;

  // Apply theme on mount (dark mode is default)
  useEffect(() => {
    const theme = localStorage.getItem('theme') || 'dark';
    if (theme === 'auto') {
      const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
      document.documentElement.setAttribute('data-theme', prefersDark ? 'dark' : 'light');
    } else {
      document.documentElement.setAttribute('data-theme', theme);
    }
  }, []);

  // Single unified IDE interface for all routes
  return <UnifiedIDE />;
}

export default App;

