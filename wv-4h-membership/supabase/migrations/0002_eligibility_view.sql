-- =============================================================================
-- Migration 0002: The voting-eligibility VIEW
-- =============================================================================
-- A VIEW is a saved query that acts like a read-only table but stores no data.
-- It RE-CALCULATES every time you look at it, straight from the real tables.
-- So eligibility is never typed in by hand and never goes stale.
--
-- We build it in layers using WITH (...) blocks, called CTEs. A CTE is just a
-- named, temporary result you can refer to below -- like defining a helper tab
-- before writing the final formula. There are two helpers, then the final
-- calculation on top.
-- =============================================================================

create view member_voting_eligibility as

with

-- HELPER 1: each member's SINGLE most-recent standing action.
-- A member may have several actions over the years (suspended, then reinstated,
-- etc.). "DISTINCT ON (member_id)" keeps just the first row per member AFTER we
-- sort, and we sort newest-first, so we get each member's latest action only.
latest_action as (
    select distinct on (member_id)
           member_id,
           action_type,
           end_date
    from standing_actions
    order by member_id, effective_date desc nulls last, recorded_on desc
),

-- HELPER 2: total dues each member has ever paid.
-- SUM adds up all their payment lines. Members with no payments simply won't
-- appear here; we handle that with COALESCE (see "total_paid" below), which
-- means "if this is blank, use 0 instead."
paid as (
    select member_id, sum(amount) as total_paid
    from payments
    group by member_id
),

-- MIDDLE LAYER: attach the two helpers to every member and compute the three
-- building-block answers (current_membership, standing, is_life_member). We do
-- this in a separate layer so the final layer can simply combine them without
-- repeating all the logic.
computed as (
    select
        m.member_id,
        m.first_name,
        m.last_name,
        m.preferred_name,
        m.county_of_nomination,
        m.membership_year,
        m.membership_date,
        m.membership_basis,
        coalesce(pd.total_paid, 0)      as total_paid,
        la.action_type                  as latest_action_type,
        la.end_date                     as latest_end_date,

        ----------------------------------------------------------------------
        -- RULE 1 -- current_membership
        -- 'Former member' only if the LATEST action was an Expulsion or a
        -- Resignation. A suspension or reinstatement still leaves them a Member.
        -- No standing actions at all -> latest_action_type is blank -> Member.
        ----------------------------------------------------------------------
        case
            when la.action_type in ('Expulsion', 'Resignation') then 'Former member'
            else 'Member'
        end as current_membership,

        ----------------------------------------------------------------------
        -- RULE 2 -- standing
        -- 'Suspended' only if the LATEST action is a Suspension that is still in
        -- force: its end_date is blank (indefinite) OR on/after today. A
        -- suspension whose end_date has already passed = back to Good standing.
        -- Former members get 'Not applicable' (standing doesn't apply to them).
        ----------------------------------------------------------------------
        case
            when la.action_type in ('Expulsion', 'Resignation') then 'Not applicable'
            when la.action_type = 'Suspension'
                 and (la.end_date is null or la.end_date >= current_date)
                then 'Suspended'
            else 'Good standing'
        end as standing,

        ----------------------------------------------------------------------
        -- RULE 3 -- is_life_member  *** ORDER MATTERS -- read the note up top ***
        -- Tested top to bottom. The FIRST test that is true wins:
        --   1) Migrated historical  -> life member, no date is ever checked
        --   2) exact date on/before the 2025-09-20 cutoff
        --   3) NO exact date, but membership YEAR is before 2025
        --   4) has paid at least $50 in dues
        -- Because #1 comes first, a blank date on an old historical member can
        -- never wrongly drop them out. A blank date in test #2 yields "unknown",
        -- which is not true, so CASE just falls through to the next test.
        ----------------------------------------------------------------------
        case
            when m.membership_basis = 'Migrated historical'                              then true
            when m.membership_date is not null and m.membership_date <= date '2025-09-20' then true
            when m.membership_date is null and m.membership_year < 2025                   then true
            when coalesce(pd.total_paid, 0) >= 50                                         then true
            else false
        end as is_life_member

    from members m
    left join latest_action la on la.member_id = m.member_id   -- LEFT JOIN = keep every member,
    left join paid          pd on pd.member_id = m.member_id   -- even those with no action/payment
)

-- FINAL LAYER: combine the three building blocks into the verdict and a
-- plain-language sentence. Everything here just READS the columns computed above.
select
    member_id,
    first_name,
    last_name,
    preferred_name,
    county_of_nomination,
    membership_year,
    membership_date,
    membership_basis,
    total_paid,
    current_membership,
    standing,
    is_life_member,

    ----------------------------------------------------------------------
    -- RULE 4 -- voting_eligible: ALL THREE must hold. is_life_member is
    -- already true/false, so we just "and" the three conditions together.
    ----------------------------------------------------------------------
    (current_membership = 'Member'
     and standing = 'Good standing'
     and is_life_member) as voting_eligible,

    ----------------------------------------------------------------------
    -- RULE 5 -- eligibility_basis: ONE plain sentence explaining the verdict.
    -- Tested in priority order so the sentence names the single deciding fact:
    --   former  ->  suspended  ->  (which life-member test passed)  ->  owes dues
    -- The life-member branch mirrors Rule 3's order, so the sentence always
    -- matches the exact reason they qualified.
    ----------------------------------------------------------------------
    case
        -- disqualified: left the society
        when current_membership = 'Former member'
            then 'Not eligible: former member ('
                 || case latest_action_type
                        when 'Expulsion'   then 'expelled'
                        when 'Resignation' then 'resigned'
                        else lower(latest_action_type)
                    end
                 || ')'

        -- disqualified: currently suspended
        when standing = 'Suspended' and latest_end_date is null
            then 'Not eligible: suspended indefinitely'
        when standing = 'Suspended'
            then 'Not eligible: suspended through ' || to_char(latest_end_date, 'YYYY-MM-DD')

        -- eligible: name which life-member test passed (same order as Rule 3)
        when is_life_member and membership_basis = 'Migrated historical'
            then 'Life member (historical record)'
        when is_life_member and membership_date is not null and membership_date <= date '2025-09-20'
            then 'Life member (joined on or before the 2025-09-20 cutoff)'
        when is_life_member and membership_date is null and membership_year < 2025
            then 'Life member (joined ' || membership_year || ', before the 2025 cutoff)'
        when is_life_member and total_paid >= 50
            then 'Life member (paid $' || to_char(total_paid, 'FM999990.00') || ' in dues)'

        -- not disqualified, but not yet a life member -> still owes dues
        else 'Not eligible: not yet a life member (paid $'
             || to_char(total_paid, 'FM999990.00') || ' of $50)'
    end as eligibility_basis

from computed
order by member_id;


-- -----------------------------------------------------------------------------
-- Let the web app (which connects with the PUBLIC key) read this view.
-- "anon" = a visitor who is not signed in; "authenticated" = a signed-in user.
-- Reading this view is safe for everyone: it exposes WHETHER someone is
-- suspended, but never the sensitive "reason" text from standing_actions.
-- -----------------------------------------------------------------------------
grant select on member_voting_eligibility to anon, authenticated;
