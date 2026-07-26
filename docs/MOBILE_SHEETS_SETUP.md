# Setting up the mobile app's Google sign-in

The mobile app (`mobile/`) has no backend of its own -- it reads and writes
your Watchlist Google Sheet directly, signed in as *you* (not the service
account the web app's backend uses). This is a one-time, manual setup, same
spirit as `docs/SHEETS_SETUP.md` for the web app's service account: it needs
your own Google Cloud Console session, which Claude Code cannot do on your
behalf.

You're adding **OAuth clients** to the *same* Google Cloud project the web
app's service account already lives in (from `docs/SHEETS_SETUP.md`) -- no
need to create a second project.

## 1. Configure the OAuth consent screen (if not already done)

1. In [console.cloud.google.com](https://console.cloud.google.com/), open the
   same project used for the service account.
2. Go to **APIs & Services → OAuth consent screen**. If this hasn't been set
   up yet, choose **External** (unless you have a Google Workspace org, in
   which case Internal also works) and fill in the required app name/support
   email. You don't need to submit it for verification -- add yourself as a
   **test user** under the consent screen's "Test users" section, and sign-in
   will work indefinitely for that account without any Google review.

## 2. Create an Android OAuth Client ID

This tells Google "this specific Android app is allowed to sign users in."

1. **APIs & Services → Credentials → Create Credentials → OAuth client ID**.
2. Application type: **Android**.
3. Package name: `com.cryptoanalyzer.crypto_watchlist_mobile`
4. SHA-1 certificate fingerprint: get this by running, from the `mobile/`
   folder:
   ```
   cd android
   ./gradlew signingReport
   ```
   Look for the `SHA1:` line under the `debug` variant (that's what a locally
   built APK is signed with, per this project's current setup -- see
   [[project_crypto_watchlist_mobile]]'s note on debug signing). Paste that
   value in.
5. Save. You don't need this Client ID's value anywhere in the app itself --
   just creating it is what authorizes the app to use Google Sign-In at all.

## 3. Create a Web OAuth Client ID

Android's Credential Manager-based sign-in (what the `google_sign_in` plugin
uses now) additionally requires a **Web application** OAuth client, whose ID
*is* used in code -- this app has no Firebase project/`google-services.json`,
which is the other way this requirement is normally satisfied.

1. **Create Credentials → OAuth client ID** again.
2. Application type: **Web application**.
3. Name it anything (e.g. "crypto watchlist mobile - web").
4. No redirect URIs needed. Save.
5. Copy the resulting Client ID (looks like
   `123456789-abc...apps.googleusercontent.com`).

## 4. Configure the app

Open the app, go to **Settings** (or the first-run setup screen):

1. Paste the **Web** Client ID from step 3 into **Web Client ID** and save.
2. Tap **Sign in with Google** and choose the account that already has
   access to your Watchlist Sheet (the same account you used to create it,
   or one it's been shared with as Editor).
3. Paste the **Sheet ID** (from the Sheet's URL:
   `docs.google.com/spreadsheets/d/`**`THIS_PART`**`/edit`) and save.

The app can now read/write the same "Watchlist" tab the web app's sync job
uses, directly -- no backend involved. See [[project_crypto_watchlist_mobile]]
for the full architecture.

## Troubleshooting

- `GoogleSignInExceptionCode.clientConfigurationError` almost always means
  step 2 or 3 is missing, or the SHA-1 in step 2 doesn't match the actual
  signing certificate of the APK you installed.
- If you rebuild the APK with a different signing config later (e.g. a real
  release keystore instead of the debug one), you'll need a *second* Android
  OAuth client for that certificate's SHA-1 -- Android client IDs are tied to
  one specific signing certificate each.
