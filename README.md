# 💌 The Swiftie Inner Circle — Daily Taylor Swift News Digest

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
| `digest.py` | Searches for news (via the Anthropic web-search tool), writes the digest, emails it. |
| `.github/workflows/daily-digest.yml` | Runs `digest.py` on a daily schedule. |
| `requirements.txt` | Python dependency (`anthropic`). |

The workflow fires at two UTC times that bracket 7 AM Eastern; `digest.py` checks
the real `America/New_York` time and only sends during the 7 AM hour, so it stays
correct through daylight-saving changes.

## One-time setup

### 1. Sender account — App Password
The digest sends from `awwswiftie@chadnproudfoot.com`.
1. Sign in to that account → **Google Account → Security**.
2. Turn on **2-Step Verification**.
3. Create an **App Password** (Security → App passwords), name it "Swiftie Digest",
   and copy the 16-character code.

### 2. Anthropic API key
1. Go to <https://console.anthropic.com>, sign up, add a small amount of pay-as-you-go credit.
2. **API Keys → Create Key**, copy it.
   > Cost is only a few cents per day (one model call + a handful of web searches).

### 3. Add the three secrets to this repo
**Settings → Secrets and variables → Actions → New repository secret:**

| Secret name | Value |
|-------------|-------|
| `GMAIL_APP_PASSWORD` | the 16-char App Password from step 1 |
| `ANTHROPIC_API_KEY` | the key from step 2 |
| `RECIPIENT_EMAIL` | the recipient's email address |

The sender address lives in the workflow file (`SENDER_EMAIL`), not in secrets.

### 4. Test it
**Actions → Daily Taylor Swift Digest → Run workflow** (leave "Send immediately"
checked). This bypasses the time check and sends right away so you can confirm it
lands. After that, it runs itself every morning.

## Changing things later
- **Time / timezone:** edit the two `cron` lines and `SEND_HOUR` in `digest.py`.
- **Recipient:** update the `RECIPIENT_EMAIL` secret.
- **Tone or sections:** edit `SYSTEM_PROMPT` / `USER_TEMPLATE` in `digest.py`.
