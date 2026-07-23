# WV 4-H All Stars — Membership Learning Sandbox

A throwaway, free-tier project for learning how **Supabase** (a cloud database)
and a **web page** fit together. Everything here uses **invented sample data** —
no real member information. Optimized for understanding, not for production use.

---

## What was built, in plain language

A small membership database that can answer one hard question automatically:
**"Is this member eligible to vote?"** — and explain its answer in a plain
sentence. On top of it sits a bare-bones web page that lists the members and
their eligibility.

The important idea throughout: **the database calculates eligibility; nobody
types it in.** Change a payment or add a suspension, and every answer updates
itself the next time you look.

---

## The pieces

### The database (five tables)
- **consecrations** — the ceremonies (OMC, Alpha I, etc.).
- **members** — the people. The heart of the system.
- **payments** — an append-only ledger of dues received.
- **standing_actions** — an append-only history of suspensions, expulsions,
  resignations, and reinstatements.
- **officers** — the short list of who may read sensitive information.

### The calculated view
- **member_voting_eligibility** — a saved query that behaves like a table but
  stores no data. For each member it works out `current_membership`, `standing`,
  `is_life_member`, `voting_eligible`, and a plain-language `eligibility_basis`.
  This is where the interesting logic lives.

### The protection (Row Level Security)
- The **reason** for a standing action is officer-only. A bouncer (RLS) locks
  the whole `standing_actions` table to officers, and a public summary view,
  **standing_actions_public**, re-publishes every column *except* the reason,
  so the *fact* of a suspension stays visible to everyone.

### The web page
- A minimal **Next.js** app (in `web/`) that reads the eligibility view with
  your public key and shows the members, a Yes/No vote verdict, the plain-language
  reason, and a search box.

---

## What each file does

```
wv-4h-membership/
├── README.md                          <- this file
├── .env.local.example                 <- template showing where Supabase values come from
│
├── supabase/
│   ├── migrations/                    <- the database recipe, run in order 0001 -> 0004
│   │   ├── 0001_create_tables.sql     <- makes the four core tables + foreign keys + checks
│   │   ├── 0002_eligibility_view.sql  <- the voting-eligibility view (the core logic)
│   │   ├── 0003_seed_data.sql         <- 15 invented members that exercise every branch
│   │   └── 0004_row_level_security.sql<- locks the sensitive "reason" to officers
│   └── teardown.sql                   <- deletes everything so you can start over
│
├── demos/                             <- optional scripts to SEE things happen
│   ├── stage2_try_to_break_foreign_key.sql  <- a payment that the database refuses
│   ├── stage4_look_at_eligibility.sql       <- read the eligibility view
│   └── stage5_rls_both_sides.sql            <- see the reason hidden vs. visible
│
└── web/                               <- the minimal web page
    ├── package.json                   <- lists the tools the page needs
    ├── .env.local.example             <- template for the web app's own copy of the keys
    ├── lib/supabaseClient.js          <- PIECE 1: opens the line to Supabase
    └── app/
        ├── layout.js                  <- the page's outer shell
        └── page.js                    <- PIECES 2 & 3: the query and the on-screen table
```

Files that are deliberately **never committed** (they hold your keys or are huge):
`.env.local`, `web/.env.local`, `web/node_modules/`, `web/.next/`.

---

## How to build it from scratch

1. In the Supabase dashboard, open **SQL Editor** and run, in order:
   `0001` → `0002` → `0003` → `0004` (copy each file, paste, Run).
2. Optionally run the files in `demos/` to watch the concepts in action.
3. To run the web page on **your own computer** (see note below about the cloud
   sandbox):
   - Install **Node.js** (from nodejs.org) if you don't have it.
   - Copy `web/.env.local.example` to `web/.env.local` and paste your Project URL
     and public key in.
   - In a terminal: `cd web`, then `npm install`, then `npm run dev`.
   - Open **http://localhost:3000** in your browser.

> Note: this repository's cloud environment blocks outbound calls to Supabase by
> network policy, so the page must be run on your own machine (or in an
> environment whose network policy allows `*.supabase.co`).

---

## How to tear it all down and start over

- **Just the data/tables:** run `supabase/teardown.sql` in the SQL Editor. Then
  re-run `0001`–`0004` to rebuild.
- **The whole thing:** delete the `wv-4h-membership/` folder from the repository,
  and (optionally) delete the Supabase project from the dashboard
  (Settings → General → Delete project). Because it's free-tier with invented
  data, there's nothing to preserve.

---

## Free-tier notes

- Everything here is tiny — well under the free 500 MB limit.
- No paid features are used.
- All data is invented; no real member information is stored.
