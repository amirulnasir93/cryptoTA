import { useState, type ReactNode } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { getSettings, setCoingeckoApiKey, setSheetId, setWebClientId } from "../appConfig";
import { googleAuth } from "../googleAuth";

export function Settings() {
  const qc = useQueryClient();
  const [settings, setSettings] = useState(getSettings());
  const [signedIn, setSignedIn] = useState(googleAuth.isSignedIn);
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState<string | null>(null);

  function refetchEverything() {
    qc.invalidateQueries();
  }

  async function handleSignIn() {
    if (!settings.webClientId) {
      setStatus("Save the Web Client ID first.");
      return;
    }
    setBusy(true);
    setStatus(null);
    try {
      await googleAuth.signIn(settings.webClientId);
      setSignedIn(true);
      setStatus(`Signed in as ${googleAuth.email ?? "your Google account"}.`);
      refetchEverything();
    } catch (err) {
      setStatus(err instanceof Error ? err.message : "Sign-in failed.");
    } finally {
      setBusy(false);
    }
  }

  function handleSignOut() {
    googleAuth.signOut();
    setSignedIn(false);
    setStatus("Signed out.");
  }

  return (
    <div className="max-w-lg space-y-6">
      <div>
        <h1 className="mb-1 text-lg font-semibold">Settings</h1>
        <p className="text-sm text-neutral-500 dark:text-neutral-400">
          This app uses your Google Sheet as its database directly from this browser -- no backend involved. One-time
          setup: paste the Web Client ID from Google Cloud Console, sign in with the Google account that has access
          to your Watchlist Sheet, then paste the Sheet ID.
        </p>
      </div>

      <Section
        title="Web Client ID"
        hint="The Web application OAuth Client ID (not the Android one) from the same Google Cloud project used for the mobile app -- see docs/MOBILE_SHEETS_SETUP.md. Add this site's origin (and http://localhost:5173 for local dev) to that client's Authorized JavaScript origins."
      >
        <Field
          value={settings.webClientId}
          placeholder="...apps.googleusercontent.com"
          onChange={(v) => setSettings((s) => ({ ...s, webClientId: v }))}
        />
        <SaveButton
          onClick={() => {
            setWebClientId(settings.webClientId);
            setStatus("Web Client ID saved.");
          }}
        >
          Save Web Client ID
        </SaveButton>
      </Section>

      <Section title="Google account">
        {signedIn ? (
          <div className="flex items-center justify-between">
            <span className="text-sm">{googleAuth.email ?? "Signed in"}</span>
            <button onClick={handleSignOut} className="text-sm text-neutral-500 hover:underline dark:text-neutral-400">
              Sign out
            </button>
          </div>
        ) : (
          <button
            onClick={handleSignIn}
            disabled={busy}
            className="rounded-md bg-neutral-900 px-3 py-1.5 text-sm font-medium text-white disabled:opacity-50 dark:bg-neutral-100 dark:text-neutral-900"
          >
            {busy ? "Signing in…" : "Sign in with Google"}
          </button>
        )}
      </Section>

      <Section title="Sheet ID" hint="From the Sheet's URL: docs.google.com/spreadsheets/d/THIS_PART/edit">
        <Field
          value={settings.sheetId}
          onChange={(v) => setSettings((s) => ({ ...s, sheetId: v }))}
        />
        <SaveButton
          onClick={() => {
            setSheetId(settings.sheetId);
            setStatus("Sheet ID saved.");
            refetchEverything();
          }}
        >
          Save Sheet ID
        </SaveButton>
      </Section>

      <Section title="CoinGecko API key (optional)" hint="Raises the free public rate limit. Leave blank to use the keyless tier.">
        <Field
          value={settings.coingeckoApiKey}
          type="password"
          onChange={(v) => setSettings((s) => ({ ...s, coingeckoApiKey: v }))}
        />
        <SaveButton
          onClick={() => {
            setCoingeckoApiKey(settings.coingeckoApiKey);
            setStatus("CoinGecko API key saved.");
          }}
        >
          Save key
        </SaveButton>
      </Section>

      {status && <p className="text-sm text-neutral-500 dark:text-neutral-400">{status}</p>}
    </div>
  );
}

function Section({ title, hint, children }: { title: string; hint?: string; children: ReactNode }) {
  return (
    <section className="space-y-2 rounded-lg border border-neutral-200 bg-white p-4 dark:border-neutral-800 dark:bg-neutral-900">
      <h2 className="text-sm font-semibold text-neutral-700 dark:text-neutral-200">{title}</h2>
      {hint && <p className="text-xs text-neutral-500 dark:text-neutral-400">{hint}</p>}
      <div className="space-y-2">{children}</div>
    </section>
  );
}

function Field({
  value,
  onChange,
  placeholder,
  type = "text",
}: {
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
  type?: string;
}) {
  return (
    <input
      type={type}
      value={value}
      onChange={(e) => onChange(e.target.value)}
      placeholder={placeholder}
      className="w-full rounded-md border border-neutral-200 bg-white px-2 py-1.5 text-sm text-neutral-900 dark:border-neutral-800 dark:bg-neutral-950 dark:text-neutral-100"
    />
  );
}

function SaveButton({ onClick, children }: { onClick: () => void; children: ReactNode }) {
  return (
    <button
      onClick={onClick}
      className="rounded-md border border-neutral-300 px-3 py-1.5 text-sm font-medium text-neutral-900 dark:border-neutral-700 dark:text-neutral-100"
    >
      {children}
    </button>
  );
}
