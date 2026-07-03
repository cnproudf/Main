#!/usr/bin/env python3
"""Daily Taylor Swift news digest — The Secret Swiftie Society dispatch.

Runs each morning in GitHub Actions: searches for fresh Taylor Swift news via
the Anthropic web-search tool, writes an *original* VIP-toned digest (headlines,
merch drops, release news), and emails it from the dedicated sender account.

No article text is ever copied — only real headlines, original one-line blurbs,
and links to the source. If a category has nothing genuinely new, the digest
says so with personality rather than inventing anything.
"""

import os
import re
import sys
import json
import base64
from datetime import datetime
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from zoneinfo import ZoneInfo

import anthropic
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build

GMAIL_SEND_SCOPE = "https://www.googleapis.com/auth/gmail.send"

EASTERN = ZoneInfo("America/New_York")
SEND_HOUR = 7  # deliver during the 7 AM Eastern hour, year-round
MODEL = "claude-sonnet-5"

SYSTEM_PROMPT = """\
You are the voice behind "The Secret Swiftie Society" — a daily insider dispatch \
written for one very special reader, a devoted Taylor Swift superfan. Your job \
is to make her feel like a VIP getting the scoop first: warm, playful, a little \
conspiratorial, like a best friend slipping her exclusive intel. Never corporate, \
never a press release. Think group-chat energy, inside jokes, gentle hype, and a \
fun secret-society wink (she's a card-carrying member).

INTEGRITY RULES — these are absolute:
- Only include items you ACTUALLY found through web search in this session, each \
with a real, working source URL taken directly from the search results.
- NEVER invent, guess, or "predict" merch drops, songs, albums, tour dates, or \
announcements. Fabricated hype is the one unforgivable sin here.
- Write every blurb in your OWN words. Never paste or lightly reword sentences \
from an article. Headlines, original summaries, and links only.
- Prefer news from roughly the last 48 hours. On a slow news day, use the \
freshest real items you can find, and if a whole category has nothing new, SAY \
SO with charm (e.g. "Merch racks are quiet today, bestie — but I've got eyes \
everywhere") instead of filling space.
- Keep each blurb to 1-2 sentences.
"""

USER_TEMPLATE = """\
Today is {today}. Put together today's digest for our Swiftie.

Search the web for the most recent Taylor Swift news and organize what you find \
into these three sections (skip a section gracefully if there's truly nothing new):

1. 📰 The Headlines — major Taylor Swift news / stories
2. 🛍️ The Merch Drop — new merchandise drops or restocks
3. 🎶 The Studio Line — song, album, or release announcements

For each item: a one-line headline, then a short ORIGINAL blurb (1-2 sentences, \
your own words), then a source link.

Wrap it with a warm, VIP "you heard it here first" intro and a fun signoff from \
"The Secret Swiftie Society."

Return your answer as ONE JSON object and NOTHING else, with exactly these keys:
{{
  "subject": "a fun, clickable email subject line (include today's date)",
  "html_body": "the full digest as clean HTML — use <h2> section headers with the \
emoji, bold headlines, short blurbs, and <a href> links styled as 'Read the tea →'. \
Keep inline styling simple and mobile-friendly.",
  "text_body": "a plain-text version of the same digest with URLs written out"
}}
"""


def within_send_window(force: bool) -> bool:
    """True only during the 7 AM Eastern hour (or when forced for a test run)."""
    if force:
        return True
    now = datetime.now(EASTERN)
    return now.hour == SEND_HOUR


def require_env(name: str) -> str:
    val = os.environ.get(name)
    if not val:
        sys.exit(f"ERROR: required environment variable {name} is not set.")
    return val


def extract_json(text: str) -> dict:
    """Pull the outermost JSON object out of the model's reply."""
    match = re.search(r"\{.*\}", text, re.DOTALL)
    if not match:
        raise ValueError(f"No JSON object found in model output:\n{text[:1000]}")
    return json.loads(match.group(0))


def generate_digest(client: anthropic.Anthropic, today: str) -> tuple[str, str, str]:
    resp = client.messages.create(
        model=MODEL,
        max_tokens=4000,
        system=SYSTEM_PROMPT,
        tools=[{"type": "web_search_20250305", "name": "web_search", "max_uses": 8}],
        messages=[{"role": "user", "content": USER_TEMPLATE.format(today=today)}],
    )
    text = "\n".join(b.text for b in resp.content if b.type == "text").strip()
    data = extract_json(text)
    for key in ("subject", "html_body", "text_body"):
        if not data.get(key):
            raise ValueError(f"Model output missing '{key}'. Got keys: {list(data)}")
    return data["subject"], data["html_body"], data["text_body"]


def gmail_service():
    """Build an authenticated Gmail API client from OAuth secrets.

    Uses a long-lived refresh token (generated once) to mint a fresh access
    token on every run, so no browser/interaction is needed in CI.
    """
    creds = Credentials(
        token=None,
        refresh_token=require_env("GMAIL_REFRESH_TOKEN"),
        client_id=require_env("GMAIL_CLIENT_ID"),
        client_secret=require_env("GMAIL_CLIENT_SECRET"),
        token_uri="https://oauth2.googleapis.com/token",
        scopes=[GMAIL_SEND_SCOPE],
    )
    creds.refresh(Request())
    return build("gmail", "v1", credentials=creds, cache_discovery=False)


def send_email(service, sender: str, recipient: str,
               subject: str, html_body: str, text_body: str) -> None:
    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = f"The Secret Swiftie Society <{sender}>"
    msg["To"] = recipient
    msg.attach(MIMEText(text_body, "plain", "utf-8"))
    msg.attach(MIMEText(html_body, "html", "utf-8"))

    raw = base64.urlsafe_b64encode(msg.as_bytes()).decode()
    service.users().messages().send(userId="me", body={"raw": raw}).execute()


def main() -> int:
    force = os.environ.get("FORCE_SEND", "").strip().lower() in ("1", "true", "yes")
    now_et = datetime.now(EASTERN)

    if not within_send_window(force):
        print(f"Not the 7 AM Eastern hour (now {now_et:%Y-%m-%d %H:%M %Z}); skipping.")
        return 0

    api_key = require_env("ANTHROPIC_API_KEY")
    sender = require_env("SENDER_EMAIL")
    recipient = require_env("RECIPIENT_EMAIL")

    today = now_et.strftime("%A, %B %-d, %Y")
    print(f"Composing the digest for {today}...")

    client = anthropic.Anthropic(api_key=api_key)
    subject, html_body, text_body = generate_digest(client, today)

    service = gmail_service()  # validates the OAuth secrets before we send
    print(f"Sending '{subject}' -> {recipient}")
    send_email(service, sender, recipient, subject, html_body, text_body)
    print("Digest sent. xoxo")
    return 0


if __name__ == "__main__":
    sys.exit(main())
