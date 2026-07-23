-- =============================================================================
-- Migration 0001: Create the four core tables
-- =============================================================================
-- Read this top to bottom like a recipe. Each block has a plain-language note
-- above it saying WHAT it makes and WHY.
--
-- The ORDER matters. A table can only point to another table that already
-- exists, so we build them "parents first":
--   1. consecrations   (ceremonies; members point at these)
--   2. members         (the people; point at consecrations)
--   3. payments        (point at members)
--   4. standing_actions(point at members)
-- =============================================================================


-- -----------------------------------------------------------------------------
-- TABLE 1: consecrations
-- The ceremonies where members are consecrated. We build this FIRST because the
-- members table will "point at" a ceremony, and you can't point at something
-- that doesn't exist yet.
--
-- Note on the CHECK on event_name: it only allows the six approved words. Type
-- anything else and the database refuses the row. NULL (blank) still passes --
-- a CHECK only rejects a value that is definitely not on the list.
-- -----------------------------------------------------------------------------
create table consecrations (
    consecration_id   text primary key,               -- e.g. CON-1996-OMC
    consecration_year integer not null,               -- year is ALWAYS known
    event_name        text check (event_name in (
                          'OMC', 'Alpha I', 'Alpha II',
                          'Homecoming Weekend', 'County ceremony', 'Other'
                      )),
    consecration_date date,                            -- exact date often unknown -> allowed blank
    location          text,
    presiding_officer text
);


-- -----------------------------------------------------------------------------
-- TABLE 2: members
-- The people. This is the heart of the system.
--
-- The important line is:  references consecrations (consecration_id)
-- That makes consecration_id a FOREIGN KEY: if you fill it in, it MUST match a
-- real row in consecrations. It is left nullable (blank) on purpose, because
-- some members never attended a ceremony (they joined automatically).
--
-- name_at_nomination is a permanent snapshot: the name on the original
-- nomination, which we never overwrite even if the person later changes it.
-- -----------------------------------------------------------------------------
create table members (
    member_id            text primary key,            -- e.g. AS-00001

    first_name           text,
    last_name            text,
    preferred_name       text,
    name_at_nomination   text,                         -- permanent, never edited

    county_of_nomination text,

    membership_year      integer not null,            -- required: always known
    membership_date      date,                         -- nullable: many old records have no exact date

    membership_basis     text check (membership_basis in (
                             'Consecrated',
                             'Automatic after one year',
                             'Migrated historical'
                         )),

    -- FOREIGN KEY -> consecrations. Blank for members who never had a ceremony.
    consecration_id      text references consecrations (consecration_id),

    email                text,
    phone                text,
    street               text,
    city                 text,
    zip                  text,                         -- text, not a number: keeps leading zeros

    prefers_mail         boolean,

    is_current_4h_volunteer text check (is_current_4h_volunteer in ('Yes', 'No', 'Unknown')),
    life_status             text check (life_status in ('Living', 'Deceased', 'Unknown')),

    created_at           timestamptz default now(),    -- filled automatically when the row is made
    updated_at           timestamptz default now()     -- (simple version: set once. A trigger could
                                                        --  auto-refresh this on every edit -- the fancier way.)
);


-- -----------------------------------------------------------------------------
-- TABLE 3: payments  (an append-only LEDGER)
-- A running list of money received. The idea of a ledger is that you only ever
-- ADD lines -- you never edit or erase history. For now the table is ordinary;
-- in Stage 5 we can use permissions to actually FORBID edits and deletes (the
-- enforced version). Telling you that exists so you know the simple table here
-- is the starting point, not the finished safeguard.
--
-- member_id is a FOREIGN KEY and is NOT NULL: every payment MUST name a real,
-- existing member. This is the rule you'll try to break on purpose below.
-- -----------------------------------------------------------------------------
create table payments (
    payment_id     text primary key,
    member_id      text not null references members (member_id),
    payment_date   date,
    amount         numeric,                            -- money; numeric keeps exact cents
    payment_method text check (payment_method in ('Check', 'Cash', 'PayPal', 'Card', 'Other')),
    recorded_by    text,
    recorded_on    timestamptz default now()
);


-- -----------------------------------------------------------------------------
-- TABLE 4: standing_actions  (also append-only)
-- One line each time something changes a member's standing: a suspension,
-- expulsion, reinstatement, or resignation. Like payments, you add lines rather
-- than editing old ones, so the history stays intact.
--
-- end_date is nullable: a blank end_date on a Suspension means "indefinite."
-- reason is sensitive -- in Stage 5 we lock it down so only officers can read it.
-- -----------------------------------------------------------------------------
create table standing_actions (
    action_id      text primary key,
    member_id      text not null references members (member_id),
    action_type    text check (action_type in ('Suspension', 'Expulsion', 'Reinstatement', 'Resignation')),
    effective_date date,
    end_date       date,                               -- blank = indefinite
    reason         text,                               -- sensitive; restricted in Stage 5
    recorded_by    text,
    recorded_on    timestamptz default now()
);
