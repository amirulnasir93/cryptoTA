# Setting up Google Sheets two-way sync

This is a one-time, manual setup — none of it can be done by Claude Code, since
it requires you to sign in to your own Google account and click through
Google's own consent UI. Once done, the app handles everything else
automatically.

You're setting up a **service account**, not OAuth login. That means: no
consent screen to configure, no app review, no "sign in with Google" flow for
you to click through each session — you create a robot identity once, share
your Sheet with its email address the same way you'd share it with a person,
and the backend authenticates as that robot from then on using a downloaded
key file.

## 1. Create a Google Cloud project

1. Go to [console.cloud.google.com](https://console.cloud.google.com/) and
   create a new project (or reuse one you already have).
2. In the search bar, find **"Google Sheets API"** and click **Enable**.
3. If prompted **"What data will you be accessing?"**, choose **Application
   data** (not "User data"). That's the branch that leads to creating a
   service account instead of an OAuth consent screen — "User data" would set
   up a sign-in flow, which this app doesn't use.

## 2. Create a service account

1. In the same project, go to **IAM & Admin → Service Accounts → Create
   Service Account**.
2. Give it any name (e.g. `crypto-watchlist-sync`). No special roles/permissions
   are needed at the project level — access is granted per-Sheet in step 4.
3. Click into the created service account → **Keys** tab → **Add Key → Create
   new key → JSON**. This downloads a `.json` file — treat it like a password.

## 3. Install the key

Move the downloaded file to:

```
packages/backend/secrets/service-account.json
```

This path is gitignored already (`packages/backend/secrets/*.json`) — it will
never be committed.

## 4. Create the Sheet and share it

1. Create a new Google Sheet (any name).
2. Open the downloaded JSON key file and copy the `client_email` value — it
   looks like `something@your-project.iam.gserviceaccount.com`.
3. In the Sheet, click **Share** and add that email address as **Editor**,
   exactly as you'd share it with a colleague.
4. Copy the Sheet's ID out of its URL:
   `https://docs.google.com/spreadsheets/d/`**`THIS_PART_IS_THE_ID`**`/edit`.

## 5. Configure the backend

In `packages/backend/.env`:

```
GOOGLE_SERVICE_ACCOUNT_FILE="./secrets/service-account.json"
GOOGLE_SHEET_ID="<the ID you copied>"
```

Restart the backend. On the first sync, the app creates a **"Watchlist"** tab
in that Sheet with the right header row automatically — you don't need to set
up the columns by hand.

## What the sync does

- Runs on a schedule (`SHEET_SYNC_CRON` in `.env`, default every 5 minutes)
  and on demand via the "Sync with Sheets" button on the Watchlist page.
- **Two-way**: editing a row in the Sheet updates the token in the app, and
  editing a token in the app (labels, notes, cluster, etc.) writes back to the
  Sheet.
- **New rows** typed directly into the Sheet create a new watchlist token
  (run through the same ticker-collision check as adding one in the app).
- **Deleting a row** in the Sheet archives that token in the app — it never
  hard-deletes, so its price history is preserved.
- If the same field is edited on both sides between syncs (a true conflict),
  **the Sheet's edit wins**, and the overwritten app-side value is recorded
  in a conflict log (visible via `GET /sync/conflicts`) rather than silently
  dropped.

## Troubleshooting

- `/sync/sheets/run` returning `"skipped": "GOOGLE_SHEET_ID / service-account.json not configured yet"`
  means one of steps 3–5 isn't done yet, or the backend needs a restart after
  editing `.env`.
- A `403`/permission error from the sync job almost always means the Sheet
  wasn't actually shared with the service account's `client_email` — reread
  step 4.
