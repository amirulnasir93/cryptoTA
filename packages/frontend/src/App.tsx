import { Route, Routes } from "react-router-dom";
import { Layout } from "./components/Layout";
import { Dashboard } from "./pages/Dashboard";
import { Watchlist } from "./pages/Watchlist";
import { TokenDetail } from "./pages/TokenDetail";
import { Labels } from "./pages/Labels";
import { Settings } from "./pages/Settings";

export default function App() {
  return (
    <Routes>
      <Route element={<Layout />}>
        <Route path="/" element={<Dashboard />} />
        <Route path="/watchlist" element={<Watchlist />} />
        <Route path="/tokens/:id" element={<TokenDetail />} />
        <Route path="/labels" element={<Labels />} />
        <Route path="/settings" element={<Settings />} />
      </Route>
    </Routes>
  );
}
