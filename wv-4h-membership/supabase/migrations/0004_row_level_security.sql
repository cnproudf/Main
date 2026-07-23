-- =============================================================================
-- Migration 0004: Row Level Security -- protect the sensitive "reason" text
-- =============================================================================
-- GOAL:
--   * The REASON for a standing action is officer-only.
--   * The FACT that someone is suspended stays visible to everyone.
--
-- HOW (in three moves):
--   1. Define who counts as an "officer" (a small list + a helper function).
--   2. Put a bouncer (RLS) on standing_actions: only officers may read it.
--   3. Publish a public "summary sheet" view with every column EXCEPT reason.
--
-- Your existing member_voting_eligibility view keeps working for everyone,
-- because it reads on the owner's behalf and only ever exposes safe columns
-- (it never selects "reason").
-- =============================================================================


-- -----------------------------------------------------------------------------
-- MOVE 1a: the officers list.
-- In Supabase, every signed-in person has a unique id (a "uuid"). This table
-- simply lists which ids are officers. We seed ONE invented officer id so we
-- can demonstrate both sides. (In real life you'd add real signed-up users.)
-- -----------------------------------------------------------------------------
create table officers (
    user_id uuid primary key,
    note    text
);

insert into officers (user_id, note) values
    ('11111111-1111-1111-1111-111111111111', 'Invented sample officer for the RLS demo');

-- Lock the officers list itself: turning RLS on with NO read policy means no
-- ordinary visitor can even see who the officers are. The helper below can
-- still read it because it runs with elevated trust (security definer).
alter table officers enable row level security;


-- -----------------------------------------------------------------------------
-- MOVE 1b: the helper function is_officer().
-- auth.uid() is a built-in Supabase function that returns the id of whoever is
-- making the current request (blank if nobody is signed in). This function
-- answers one yes/no question: "is that id on the officers list?"
--
-- "security definer" lets it check the locked officers table on your behalf;
-- "stable" and the fixed search_path are just safety/among-good-practice knobs.
-- -----------------------------------------------------------------------------
create or replace function public.is_officer()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1 from officers where user_id = auth.uid()
    );
$$;


-- -----------------------------------------------------------------------------
-- MOVE 2: put the bouncer on standing_actions.
-- "enable row level security" turns the bouncer ON. By default, once on, NOBODY
-- can read the table until a policy says otherwise. Then we add ONE policy: a
-- signed-in officer may read rows. Everyone else -> zero rows.
--
-- We deliberately add NO insert/update/delete policy, so no ordinary user can
-- change history through the app either -- reinforcing the append-only ledger
-- idea. (The seed rows were loaded by the admin connection, which is exempt.)
-- -----------------------------------------------------------------------------
alter table standing_actions enable row level security;

create policy "Officers can read standing actions"
    on standing_actions
    for select
    to authenticated              -- only applies to signed-in users...
    using ( public.is_officer() ); -- ...and only if they are an officer.


-- -----------------------------------------------------------------------------
-- MOVE 3: the public "summary sheet".
-- This view lists every column of standing_actions EXCEPT reason, so anyone can
-- see WHO is suspended and until when -- just not WHY. A view reads with its
-- owner's trust, so it can see the rows even though the table is locked; but it
-- only ever hands back the safe columns. We grant read access to everyone.
-- -----------------------------------------------------------------------------
create view standing_actions_public as
select
    action_id,
    member_id,
    action_type,
    effective_date,
    end_date,
    recorded_by,
    recorded_on
    -- reason is intentionally NOT here
from standing_actions;

grant select on standing_actions_public to anon, authenticated;
