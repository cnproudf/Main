-- =============================================================================
-- DEMO: Row Level Security from BOTH sides
-- =============================================================================
-- Run this AFTER migration 0004.
--
-- IMPORTANT -- how to run it so you SEE each result:
--   The SQL Editor only shows the result of the LAST query in a run. So do NOT
--   run the whole file at once. Instead, highlight ONE lettered block (A, B1,
--   B2, or C) with your mouse and click "Run" -- the editor runs just what you
--   highlighted. Do that for each block and compare.
--
-- Each block wraps itself in "begin ... rollback" and temporarily becomes a
-- different kind of user, then undoes everything. Nothing is actually changed.
-- =============================================================================


-- ============================ BLOCK A =========================================
-- Pretend to be an OFFICER (signed in, and on the officers list).
-- EXPECT: all 7 standing-action rows, INCLUDING the reason text.
-- ------------------------------------------------------------------------------
begin;
    -- become a signed-in user whose id IS the seeded officer id
    select set_config('request.jwt.claims',
                      '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
    set local role authenticated;

    select action_id, member_id, action_type, reason
    from standing_actions
    order by action_id;
rollback;


-- ============================ BLOCK B1 ========================================
-- Pretend to be the PUBLIC (an anonymous visitor, not signed in) reading the
-- LOCKED table directly.
-- EXPECT: ZERO rows. The bouncer turns them away -- reason is safe.
-- ------------------------------------------------------------------------------
begin;
    set local role anon;

    select action_id, member_id, action_type, reason
    from standing_actions
    order by action_id;
rollback;


-- ============================ BLOCK B2 ========================================
-- Same PUBLIC visitor, but reading the public SUMMARY view instead.
-- EXPECT: all 7 rows -- WHO is suspended and until when -- but NO reason column.
-- This is the "fact stays visible to everyone" half.
-- ------------------------------------------------------------------------------
begin;
    set local role anon;

    select action_id, member_id, action_type, effective_date, end_date
    from standing_actions_public
    order by action_id;
rollback;


-- ============================ BLOCK C (bonus) =================================
-- Pretend to be a signed-in user who is NOT an officer (a different id).
-- EXPECT: ZERO rows. Being signed in is not enough -- you must be an officer.
-- ------------------------------------------------------------------------------
begin;
    select set_config('request.jwt.claims',
                      '{"sub":"99999999-9999-9999-9999-999999999999","role":"authenticated"}', true);
    set local role authenticated;

    select action_id, member_id, action_type, reason
    from standing_actions
    order by action_id;
rollback;
