import { useState } from "react";

const SECRET_STORAGE_KEY = "crypto-analyzer:refresh-secret";

// Personal, local-first tool: the refresh/sync shared-secret is entered once
// (on the Settings page) and kept in localStorage rather than wiring up real
// auth for a single user. Any component that needs it reads from here so the
// storage key only lives in one place.
export function useRefreshSecret() {
  const [secret, setSecretState] = useState(() => localStorage.getItem(SECRET_STORAGE_KEY) ?? "");

  function setSecret(value: string) {
    setSecretState(value);
    localStorage.setItem(SECRET_STORAGE_KEY, value);
  }

  return [secret, setSecret] as const;
}
