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
import base64
import html as html_lib
from datetime import datetime, date
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from zoneinfo import ZoneInfo

import anthropic
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build

GMAIL_SEND_SCOPE = "https://www.googleapis.com/auth/gmail.send"

EASTERN = ZoneInfo("America/New_York")
MODEL = "claude-sonnet-5"
FOUNDED = date(2026, 7, 3)  # the day The Secret Swiftie Society was founded


def dispatch_number(today: date) -> int:
    """A membership-flavored issue number that ticks up one per day, forever."""
    return (today - FOUNDED).days + 1

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
Today is {today}. This is Dispatch No. {dispatch_no:03d} of The Secret Swiftie \
Society. Put together today's digest for our Swiftie.

Somewhere near the top, work in the dispatch number as a fun secret-society \
stamp, e.g. "DISPATCH No. {dispatch_no:03d} · CLEARANCE: EARS ONLY" — treat it \
like the membership badge on a classified briefing.

Search the web for the most recent Taylor Swift news and organize what you find \
into these three sections (skip a section gracefully if there's truly nothing new):

1. 📰 The Headlines — major Taylor Swift news / stories
2. 🛍️ The Merch Drop — new merchandise drops or restocks
3. 🎶 The Studio Line — song, album, or release announcements

For each item: a one-line headline, then a short ORIGINAL blurb (1-2 sentences, \
your own words), then a source link.

Wrap it with a warm, VIP "you heard it here first" intro and a fun signoff from \
"The Secret Swiftie Society."

Format your reply EXACTLY like this, and nothing else:

SUBJECT: <a fun, clickable subject line that includes today's date>
---
<the full digest as clean HTML: an <h2> section header (with its emoji) per \
section, bold headlines, short blurbs, and <a href> source links styled as \
'Read the tea →'. Keep inline styling simple and mobile-friendly.>

Put "SUBJECT:" on the very first line, then a line containing only three dashes \
(---), then the HTML body. Do not use code fences or add anything else.
"""


def require_env(name: str) -> str:
    val = os.environ.get(name)
    if not val:
        sys.exit(f"ERROR: required environment variable {name} is not set.")
    return val


def html_to_text(html_body: str) -> str:
    """Best-effort plain-text alternative derived from the HTML body."""
    text = re.sub(r"(?is)<a[^>]*href=[\"']([^\"']+)[\"'][^>]*>(.*?)</a>",
                  r"\2 (\1)", html_body)
    text = re.sub(r"(?i)<(br|/p|/div|/h[1-6])\s*/?>", "\n", text)
    text = re.sub(r"(?s)<[^>]+>", "", text)
    text = html_lib.unescape(text)
    text = re.sub(r"[ \t]+\n", "\n", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def parse_reply(raw: str) -> tuple[str, str]:
    """Split the model's 'SUBJECT: / --- / HTML' reply into (subject, html_body)."""
    raw = raw.strip()
    if raw.startswith("```"):  # strip stray code fences, just in case
        raw = re.sub(r"^```[a-zA-Z]*\n", "", raw)
        raw = re.sub(r"\n```$", "", raw).strip()
    lines = raw.splitlines()
    idx = next((i for i, line in enumerate(lines) if line.strip() == "---"), None)
    if idx is not None:
        subject_part = "\n".join(lines[:idx])
        html_body = "\n".join(lines[idx + 1:]).strip()
    else:  # no delimiter found — fall back to "first line is the subject"
        subject_part = lines[0] if lines else ""
        html_body = "\n".join(lines[1:]).strip()
    subject = re.sub(r"(?i)^subject:\s*", "", subject_part.strip()).strip()
    if not subject or not html_body:
        raise ValueError(f"Could not parse subject/body from model output:\n{raw[:800]}")
    return subject, html_body


def generate_digest(client: anthropic.Anthropic, today: str,
                    dispatch_no: int) -> tuple[str, str, str]:
    prompt = USER_TEMPLATE.format(today=today, dispatch_no=dispatch_no)
    resp = client.messages.create(
        model=MODEL,
        max_tokens=8000,
        system=SYSTEM_PROMPT,
        tools=[{"type": "web_search_20250305", "name": "web_search", "max_uses": 8}],
        messages=[{"role": "user", "content": prompt}],
    )
    if resp.stop_reason == "max_tokens":
        print("WARNING: model output hit the token limit; sending what we have.")
    text = "\n".join(b.text for b in resp.content if b.type == "text").strip()
    subject, html_body = parse_reply(text)
    text_body = html_to_text(html_body)
    return subject, html_body, text_body


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
    # This runs once per day on a single morning cron. GitHub's scheduler is
    # best-effort and can fire hours late, so we deliberately do NOT gate on the
    # exact hour — whenever the daily run fires, it sends. One cron per day means
    # it still only sends once.
    now_et = datetime.now(EASTERN)

    api_key = require_env("ANTHROPIC_API_KEY")
    sender = require_env("SENDER_EMAIL")
    recipient = require_env("RECIPIENT_EMAIL")

    today = now_et.strftime("%A, %B %-d, %Y")
    dispatch_no = dispatch_number(now_et.date())
    print(f"Composing Dispatch No. {dispatch_no:03d} for {today}...")

    client = anthropic.Anthropic(api_key=api_key)
    subject, html_body, text_body = generate_digest(client, today, dispatch_no)

    service = gmail_service()  # validates the OAuth secrets before we send
    print(f"Sending '{subject}' -> {recipient}")
    send_email(service, sender, recipient, subject, html_body, text_body)
    print("Digest sent. xoxo")
    return 0


if __name__ == "__main__":
    sys.exit(main())
