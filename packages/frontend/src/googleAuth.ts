// Browser-side Google sign-in via Google Identity Services' token client
// (loaded through a <script> tag in index.html, not an npm package -- see
// the minimal ambient typing below, scoped to exactly what this file uses).
// This needs only a Web OAuth Client ID -- no separate Android-style client
// the way the mobile app's Credential Manager flow does.

interface GoogleTokenResponse {
  access_token: string;
  expires_in: number;
  error?: string;
}

interface GoogleTokenClient {
  requestAccessToken(overrideConfig?: { prompt?: string }): void;
}

interface GoogleAccountsOauth2 {
  initTokenClient(config: {
    client_id: string;
    scope: string;
    callback: (response: GoogleTokenResponse) => void;
  }): GoogleTokenClient;
  revoke(accessToken: string, callback?: () => void): void;
}

declare global {
  interface Window {
    google?: { accounts: { oauth2: GoogleAccountsOauth2 } };
  }
}

// spreadsheets for Sheets API access, email/profile just so the Settings
// screen can show "Signed in as ...".
const SCOPES = "https://www.googleapis.com/auth/spreadsheets email profile";

class GoogleAuthService {
  private tokenClient: GoogleTokenClient | null = null;
  private clientId: string | null = null;
  private currentToken: { accessToken: string; expiresAt: number } | null = null;
  private pending: { resolve: (token: string) => void; reject: (err: Error) => void } | null = null;
  private cachedEmail: string | null = null;

  private ensureClient(clientId: string): GoogleTokenClient {
    if (this.tokenClient && this.clientId === clientId) return this.tokenClient;
    if (!window.google?.accounts?.oauth2) {
      throw new Error(
        "Google Identity Services hasn't loaded yet -- check your connection and reload the page."
      );
    }
    this.clientId = clientId;
    this.tokenClient = window.google.accounts.oauth2.initTokenClient({
      client_id: clientId,
      scope: SCOPES,
      callback: (response) => {
        const pending = this.pending;
        this.pending = null;
        if (!pending) return;
        if (response.error) {
          pending.reject(new Error(`Google sign-in failed: ${response.error}`));
          return;
        }
        this.currentToken = {
          accessToken: response.access_token,
          expiresAt: Date.now() + response.expires_in * 1000,
        };
        pending.resolve(response.access_token);
      },
    });
    return this.tokenClient;
  }

  get isSignedIn(): boolean {
    return this.currentToken != null && this.currentToken.expiresAt > Date.now();
  }

  get email(): string | null {
    return this.cachedEmail;
  }

  signOut(): void {
    if (this.currentToken && window.google?.accounts?.oauth2) {
      window.google.accounts.oauth2.revoke(this.currentToken.accessToken);
    }
    this.currentToken = null;
    this.cachedEmail = null;
  }

  /** Interactive sign-in, prompting the user via Google's account picker. */
  async signIn(clientId: string): Promise<void> {
    const client = this.ensureClient(clientId);
    await new Promise<string>((resolve, reject) => {
      this.pending = { resolve, reject };
      client.requestAccessToken({});
    });
    await this.fetchEmail();
  }

  /** Returns a currently-valid access token, re-prompting only if expired. */
  async getAccessToken(clientId: string): Promise<string> {
    if (this.currentToken && this.currentToken.expiresAt > Date.now() + 30_000) {
      return this.currentToken.accessToken;
    }
    const client = this.ensureClient(clientId);
    return new Promise((resolve, reject) => {
      this.pending = { resolve, reject };
      client.requestAccessToken({});
    });
  }

  private async fetchEmail(): Promise<void> {
    if (!this.currentToken) return;
    try {
      const res = await fetch("https://www.googleapis.com/oauth2/v3/userinfo", {
        headers: { Authorization: `Bearer ${this.currentToken.accessToken}` },
      });
      if (res.ok) {
        const data = (await res.json()) as { email?: string };
        this.cachedEmail = data.email ?? null;
      }
    } catch {
      // Purely cosmetic (the "Signed in as ..." label) -- not worth failing
      // sign-in over if this one extra call doesn't succeed.
    }
  }
}

export const googleAuth = new GoogleAuthService();
