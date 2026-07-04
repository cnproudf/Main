# 💌 The Secret Swiftie Society — Daily Taylor Swift News Digest

A tiny automated job that emails a warm, VIP-toned Taylor Swift news digest to
one very lucky Swiftie every morning at **~7:30 AM Eastern**.

Each morning it searches the web for fresh Taylor Swift news, sorts it into three
sections, and writes **original** one-line blurbs with source links — never copied
article text:

- 📰 **The Headlines** — major news / stories
- 🛍️ **The Merch Drop** — new merch drops or restocks
- 🎶 **The Studio Line** — song, album, or release announcements

It runs on **GitHub Actions** (free) and sends from a dedicated Gmail/Workspace
account. No servers, no daily babysitting.

## How it works

| File | Role |
|------|------|
| `digest.py` | Searches for news (via the Anthropic web-search tool), writes the digest, sends it via the Gmail API. |
| `.github/workflows/daily-digest.yml` | Runs `digest.py` on a daily schedule. |
| `.github/workflows/keep-alive.yml` | Twice-monthly empty commit so GitHub doesn't auto-disable the schedule. |
| `requirements.txt` | Python dependencies (`anthropic`, `google-auth`, `google-api-python-client`). |

The workflow fires at two UTC times that bracket 7 AM Eastern; `digest.py` checks
the real `America/New_York` time and only sends during the 7 AM hour, so it stays
correct through daylight-saving changes.

## One-time setup

### 1. Sender account — Gmail API OAuth
The digest sends from `awwswiftie@chadnproudfoot.com` via the Gmail API. This
replaces App Passwords (which are disabled on this Workspace domain). All in the
browser, signed in **as the sender account**:

1. **Google Cloud Console** (<https://console.cloud.google.com>) → create a project, e.g. "Swiftie Digest".
2. **APIs & Services → Library** → search "Gmail API" → **Enable**.
3. **APIs & Services → OAuth consent screen** → **User type: Internal** → fill in
   app name + support email → Save. *(Internal = no Google verification and the
   refresh token never expires. Requires signing in with the Workspace account.)*
4. **APIs & Services → Credentials → Create credentials → OAuth client ID** →
   **Application type: Web application** → under *Authorized redirect URIs* add
   `https://developers.google.com/oauthplayground` → Create. Copy the **Client ID**
   and **Client secret**.
5. Get a refresh token with the **OAuth 2.0 Playground** (<https://developers.google.com/oauthplayground>):
   - Click the ⚙️ (top-right) → check **Use your own OAuth credentials** → paste the
     Client ID and Client secret.
   - In the left "Input your own scopes" box, enter `https://www.googleapis.com/auth/gmail.send`
     → **Authorize APIs** → sign in as `awwswiftie@chadnproudfoot.com` → Allow.
   - Click **Exchange authorization code for tokens** → copy the **Refresh token**.

### 2. Anthropic API key
1. Go to <https://console.anthropic.com>, sign up, add a small amount of pay-as-you-go credit.
2. **API Keys → Create Key**, copy it.
   > Cost is only a few cents per day (one model call + a handful of web searches).

### 3. Add the secrets to this repo
**Settings → Secrets and variables → Actions → New repository secret:**

| Secret name | Value |
|-------------|-------|
| `GMAIL_CLIENT_ID` | OAuth Client ID from step 1.4 |
| `GMAIL_CLIENT_SECRET` | OAuth Client secret from step 1.4 |
| `GMAIL_REFRESH_TOKEN` | Refresh token from step 1.5 |
| `ANTHROPIC_API_KEY` | the key from step 2 |
| `RECIPIENT_EMAIL` | the recipient's email address |

The sender address lives in the workflow file (`SENDER_EMAIL`), not in secrets.

### 4. Test it
**Actions → Daily Taylor Swift Digest → Run workflow**. A manual run sends right
away, so you can confirm it lands. After that, it runs itself every morning.

## Scheduling notes
- The digest runs on a **single daily cron** and sends whenever that run fires.
- GitHub's free scheduler is **best-effort** — runs can be delayed by anywhere
  from a few minutes to a couple of hours (worst on high-traffic days). So "7:30
  AM" really means "sometime in the morning." The email will still go out; it may
  just be late. For to-the-minute punctuality you'd move the schedule to a
  dedicated scheduler (e.g. Google Cloud Scheduler).

## Changing things later
- **Time / timezone:** edit the `cron` line in `.github/workflows/daily-digest.yml`
  (it's in UTC; 11:34 UTC ≈ 7:34 AM ET in summer).
- **Recipient:** update the `RECIPIENT_EMAIL` secret.
- **Tone or sections:** edit `SYSTEM_PROMPT` / `USER_TEMPLATE` in `digest.py`.
