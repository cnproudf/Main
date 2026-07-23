-- =============================================================================
-- TEARDOWN: delete everything this sandbox created, so you can start fresh.
-- =============================================================================
-- Paste this whole file into the SQL Editor and Run. It removes the views,
-- the helper function, and all five tables (with their data). Order is
-- reverse of how we built them; "if exists" means it won't complain if
-- something is already gone, and "cascade" sweeps up anything attached.
--
-- After running this, your Table Editor will be empty and you can re-run
-- migrations 0001 -> 0004 to rebuild from scratch.
-- =============================================================================

drop view if exists standing_actions_public;
drop view if exists member_voting_eligibility;

drop function if exists public.is_officer();

drop table if exists standing_actions cascade;
drop table if exists payments        cascade;
drop table if exists officers         cascade;
drop table if exists members          cascade;
drop table if exists consecrations    cascade;
