# Hosting the web app on GitHub Pages (no backend)

Like the mobile app, `packages/frontend` now talks directly to your Watchlist
Google Sheet and to the price APIs from the browser -- no backend, no
`VITE_API_URL`. That means it's just static files, which is all GitHub Pages
can serve, so this is a one-time setup rather than standing up a server
somewhere.

## 1. Enable GitHub Pages (one-time, only the repo owner can do this)

1. On GitHub, open the repo's **Settings → Pages**.
2. Under **Build and deployment → Source**, choose **GitHub Actions**.
3. That's it -- `.github/workflows/deploy.yml` builds `packages/frontend` and
   publishes it on every push to `main`. The first push after enabling this
   will trigger the first deploy; check the **Actions** tab for its progress
   and the resulting URL (`https://amirulnasir93.github.io/cryptoTA/`).

## 2. Reuse the mobile app's Web OAuth Client ID

You already created a **Web application** OAuth client for the mobile app --
see `docs/MOBILE_SHEETS_SETUP.md` step 3. The same Client ID works here; it
just needs the web app's actual origins added to its allow-list (mobile
never needed this, since it isn't a browser):

1. In [console.cloud.google.com](https://console.cloud.google.com/), open
   **APIs & Services → Credentials**, and edit that same Web application
   client.
2. Under **Authorized JavaScript origins**, add:
   - `https://amirulnasir93.github.io` (the deployed site -- note: no path,
     origins don't include `/cryptoTA/`)
   - `http://localhost:5173` (for local dev via `npm run dev`)
3. Save. This can take a few minutes to propagate.

## 3. Configure the app

Open the deployed site, go to **Settings**, and fill in the same three
fields the mobile app asks for:

1. **Web Client ID** -- the same one from step 2.
2. **Sign in with Google** -- the account that already has access to your
   Watchlist Sheet.
3. **Sheet ID** -- from the Sheet's URL:
   `docs.google.com/spreadsheets/d/`**`THIS_PART`**`/edit`.
4. Optionally, a CoinGecko API key to raise the free rate limit.

All three are saved in this browser's `localStorage` only -- nothing is sent
anywhere except Google (for sign-in) and the price APIs (for market data).
Signing in again is needed on each new browser/device, and roughly every hour
once an access token expires (Google Identity Services' token client doesn't
persist a session across page reloads the way native sign-in does).
