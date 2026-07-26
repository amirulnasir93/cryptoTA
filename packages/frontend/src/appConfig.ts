// Local, browser-only settings this app needs before it can do anything: the
// Google Sheet ID it treats as its database and the Web OAuth Client ID for
// Google sign-in. Mirrors mobile/lib/app_config.dart's SharedPreferences-
// backed settings, using localStorage instead -- same two fields, same
// "no sane default to guess" reasoning.
import { googleAuth } from "./googleAuth";
import { Repository } from "./repository";
import { SheetsClient } from "./sheetsClient";

const SHEET_ID_KEY = "crypto-analyzer:sheet-id";
const WEB_CLIENT_ID_KEY = "crypto-analyzer:web-client-id";
const COINGECKO_API_KEY_KEY = "crypto-analyzer:coingecko-api-key";

export interface AppSettings {
  sheetId: string;
  webClientId: string;
  coingeckoApiKey: string;
}

export function getSettings(): AppSettings {
  return {
    sheetId: localStorage.getItem(SHEET_ID_KEY) ?? "",
    webClientId: localStorage.getItem(WEB_CLIENT_ID_KEY) ?? "",
    coingeckoApiKey: localStorage.getItem(COINGECKO_API_KEY_KEY) ?? "",
  };
}

export function setSheetId(value: string): void {
  localStorage.setItem(SHEET_ID_KEY, value.trim());
}
export function setWebClientId(value: string): void {
  localStorage.setItem(WEB_CLIENT_ID_KEY, value.trim());
}
export function setCoingeckoApiKey(value: string): void {
  localStorage.setItem(COINGECKO_API_KEY_KEY, value.trim());
}

export function isConfigured(settings: AppSettings = getSettings()): boolean {
  return settings.sheetId.trim() !== "" && settings.webClientId.trim() !== "";
}

/** Configured AND signed in -- the two preconditions every data fetch needs.
 * Checked eagerly by page components (not just left to a failed fetch)
 * because Google Identity Services' token popup only works from a direct
 * user gesture (the Settings page's own "Sign in" button click) -- an
 * automatic background query firing before that click would just get its
 * popup silently blocked. */
export function isReady(): boolean {
  return isConfigured() && googleAuth.isSignedIn;
}

// Rebuilt whenever the Sheet ID / Web Client ID / CoinGecko key changes --
// these are cheap objects with no persistent connections to tear down, so a
// plain module-level cache keyed by the settings that matter is simpler than
// a live-updating singleton with subscribers.
let cached: { key: string; repository: Repository } | null = null;

export function getRepository(): Repository | null {
  const settings = getSettings();
  if (!isConfigured(settings)) return null;
  const key = `${settings.sheetId}::${settings.webClientId}::${settings.coingeckoApiKey}`;
  if (cached && cached.key === key) return cached.repository;
  const sheets = new SheetsClient(settings.sheetId, settings.webClientId);
  const repository = new Repository(sheets, settings.coingeckoApiKey || undefined);
  cached = { key, repository };
  return repository;
}

export function requireRepository(): Repository {
  const repository = getRepository();
  if (!repository) {
    throw new Error("Not configured yet -- set your Sheet ID and Web Client ID on the Settings page first.");
  }
  return repository;
}
