-- =============================================================================
-- DEMO: watch the database refuse a bad payment
-- =============================================================================
-- Run this AFTER migration 0001 has created the tables, and BEFORE (or after)
-- seeding -- it works either way, because it names a member that does not exist.
--
-- We try to record a $10 payment for member 'AS-99999'. No such member has been
-- created, so the FOREIGN KEY rule on payments.member_id has nothing real to
-- point at. The database will REJECT the insert instead of quietly saving a
-- payment attached to a ghost.
--
-- Expected result: an ERROR, not a success. Something like:
--   insert or update on table "payments" violates foreign key constraint
--   Key (member_id)=(AS-99999) is not present in table "members".
--
-- That error IS the lesson: the rule held. In a spreadsheet you could type a
-- made-up member id into a "payments" tab and nothing would stop you. Here the
-- database guarantees every payment belongs to a real member.
-- =============================================================================

insert into payments (payment_id, member_id, payment_date, amount, payment_method, recorded_by)
values ('PAY-BAD-001', 'AS-99999', '2026-07-01', 10, 'Cash', 'demo');
