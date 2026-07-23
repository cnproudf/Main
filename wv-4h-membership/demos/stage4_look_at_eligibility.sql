-- =============================================================================
-- DEMO: look at the eligibility view after seeding
-- =============================================================================
-- Run this AFTER migration 0003. It reads the VIEW, which recalculates live from
-- the tables. You did not store any of these answers -- the database worked them
-- out from the members, payments, and standing_actions.
-- =============================================================================

select
    member_id,
    first_name,
    last_name,
    current_membership,
    standing,
    is_life_member,
    voting_eligible,
    eligibility_basis
from member_voting_eligibility
order by member_id;


-- Bonus 1: just the members who MAY vote.
-- select member_id, first_name, last_name, eligibility_basis
-- from member_voting_eligibility
-- where voting_eligible
-- order by member_id;

-- Bonus 2: a headcount -- how many are eligible vs not.
-- select voting_eligible, count(*)
-- from member_voting_eligibility
-- group by voting_eligible;
