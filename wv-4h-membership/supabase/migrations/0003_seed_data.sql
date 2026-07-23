-- =============================================================================
-- Migration 0003: Seed data -- 15 invented members that exercise every branch
-- =============================================================================
-- ALL data here is fictional. No real members.
--
-- Insert order (parents first, like before):
--   1. consecrations   2. members   3. payments   4. standing_actions
--
-- Each member below has a one-line note saying which branch of the eligibility
-- logic they are meant to prove, and the verdict you should expect.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1) CONSECRATIONS -- the ceremonies members will point at.
-- (Members who never attended a ceremony simply leave consecration_id blank.)
-- -----------------------------------------------------------------------------
insert into consecrations (consecration_id, consecration_year, event_name, consecration_date, location, presiding_officer) values
    ('CON-1996-OMC',    1996, 'OMC',                null,         'Jacksons Mill',  'Sample Officer A'),
    ('CON-2015-ALPHA1', 2015, 'Alpha I',            '2015-06-13', 'Jacksons Mill',  'Sample Officer B'),
    ('CON-2017-ALPHA2', 2017, 'Alpha II',           '2017-06-10', 'Jacksons Mill',  'Sample Officer B'),
    ('CON-2019-ALPHA2', 2019, 'Alpha II',           null,         'Jacksons Mill',  'Sample Officer C'),
    ('CON-2020-OMC',    2020, 'OMC',                '2020-10-03', 'Jacksons Mill',  'Sample Officer C'),
    ('CON-2021-HC',     2021, 'Homecoming Weekend', '2021-09-25', 'Jacksons Mill',  'Sample Officer D'),
    ('CON-2024-OMC',    2024, 'OMC',                '2024-10-05', 'Jacksons Mill',  'Sample Officer D'),
    ('CON-2025-HC',     2025, 'Homecoming Weekend', '2025-09-20', 'Jacksons Mill',  'Sample Officer E'),
    ('CON-2026-OMC',    2026, 'OMC',                '2026-05-02', 'Jacksons Mill',  'Sample Officer E');


-- -----------------------------------------------------------------------------
-- 2) MEMBERS
-- Columns not listed (phone, street, updated_at, etc.) fall back to blank/now().
-- -----------------------------------------------------------------------------
insert into members
    (member_id, first_name, last_name, preferred_name, name_at_nomination, county_of_nomination,
     membership_year, membership_date, membership_basis, consecration_id,
     email, city, zip, prefers_mail, is_current_4h_volunteer, life_status)
values
    -- AS-00001: 1974 historical, NO exact date, never paid.
    --   Proves basis-first: 'Migrated historical' wins before any date check. -> Life member (historical record)
    ('AS-00001', 'Mary',   'Ashby',    null,    'Mary Ashby',           'Monongalia', 1974, null,         'Migrated historical',        null,
     null,                      'Morgantown',   '26505', true,  'No',      'Living'),

    -- AS-00002: 2019, NO exact date, never paid (consecrated, so NOT historical).
    --   Proves test #3: blank date BUT year < 2025. -> Life member (joined 2019...)
    ('AS-00002', 'James',  'Barker',   'Jim',   'James Barker',         'Kanawha',    2019, null,         'Consecrated',                'CON-2019-ALPHA2',
     'jim.sample@example.com',  'Charleston',   '25301', false, 'Yes',     'Living'),

    -- AS-00003: 2026, after the cutoff, never paid. -> NOT eligible (owes dues)
    ('AS-00003', 'Nora',   'Casto',    null,    'Nora Casto',           'Cabell',     2026, '2026-06-01', 'Consecrated',                'CON-2026-OMC',
     'nora.sample@example.com', 'Huntington',   '25701', false, 'Yes',     'Living'),

    -- AS-00004: 2026, after cutoff, paid $30 + $20 = $50 total.
    --   Proves test #4: dues SUMMED reach $50. -> Life member (paid $50.00 in dues)
    ('AS-00004', 'Owen',   'Dillon',   null,    'Owen Dillon',          'Wood',       2026, '2026-05-01', 'Consecrated',                'CON-2026-OMC',
     null,                      'Parkersburg',  '26101', false, 'Unknown', 'Living'),

    -- AS-00005: Automatic member who NEVER attended a ceremony (consecration blank).
    --   Proves test #2: exact date before cutoff. -> Life member (joined before cutoff)
    ('AS-00005', 'Priya',  'Evans',    null,    'Priya Evans',          'Berkeley',   2022, '2022-08-15', 'Automatic after one year',   null,
     null,                      'Martinsburg',  '25401', true,  'Unknown', 'Living'),

    -- AS-00006: Paid $75 BUT suspended through 2030. -> NOT eligible (suspended)
    ('AS-00006', 'Roy',    'Franklin', null,    'Roy Franklin',         'Raleigh',    2024, '2024-03-01', 'Consecrated',                'CON-2024-OMC',
     null,                      'Beckley',      '25801', false, 'No',      'Living'),

    -- AS-00007: Suspension EXPIRED in 2023 -> back to good standing. -> Life member
    ('AS-00007', 'Sara',   'Grimm',    null,    'Sara Grimm',           'Harrison',   2021, '2021-09-01', 'Consecrated',                'CON-2021-HC',
     null,                      'Clarksburg',   '26301', false, 'Yes',     'Living'),

    -- AS-00008: EXPELLED, had paid $100. -> NOT eligible (former member; dues irrelevant)
    ('AS-00008', 'Tom',    'Hardy',    null,    'Tom Hardy',            'Mercer',     2020, '2020-05-01', 'Consecrated',                'CON-2020-OMC',
     null,                      'Princeton',    '24740', false, 'No',      'Living'),

    -- AS-00009: Paid only $25 (partial). -> NOT eligible (paid $25 of $50)
    ('AS-00009', 'Uma',    'Iverson',  null,    'Uma Iverson',          'Jefferson',  2026, '2026-04-01', 'Consecrated',                'CON-2026-OMC',
     null,                      'Charles Town', '25414', false, 'Yes',     'Living'),

    -- AS-00010: RESIGNED in 2023. -> NOT eligible (former member; resigned)
    ('AS-00010', 'Vince',  'Jarvis',   null,    'Vince Jarvis',         'Marion',     2015, '2015-06-01', 'Consecrated',                'CON-2015-ALPHA1',
     null,                      'Fairmont',     '26554', false, 'Unknown', 'Unknown'),

    -- AS-00011: Suspended long ago, then REINSTATED (latest action wins). -> Life member
    ('AS-00011', 'Wanda',  'Keller',   null,    'Wanda Keller',         'Preston',    2017, '2017-10-01', 'Consecrated',                'CON-2017-ALPHA2',
     null,                      'Kingwood',     '26537', true,  'Yes',     'Living'),

    -- AS-00012: Historical (life member) but under an INDEFINITE suspension. -> NOT eligible (suspended indefinitely)
    ('AS-00012', 'Xavier', 'Lowe',     null,    'Xavier Lowe',          'Ohio',       1998, null,         'Migrated historical',        null,
     null,                      'Wheeling',     '26003', true,  'No',      'Living'),

    -- AS-00013: Historical, but its only exact date is 2026-01-15 (AFTER the cutoff!).
    --   The KEY ordering demo: basis-first still makes them a life member even though
    --   the present date would fail test #2. -> Life member (historical record)
    ('AS-00013', 'Yara',   'Mercer',   null,    'Yara Mercer',          'Greenbrier', 2026, '2026-01-15', 'Migrated historical',        null,
     null,                      'Lewisburg',    '24901', true,  'Unknown', 'Living'),

    -- AS-00014: Joined EXACTLY on the 2025-09-20 cutoff -> included (test #2 is "on or before"). -> Life member
    ('AS-00014', 'Zane',   'Nolan',    null,    'Zane Nolan',           'Putnam',     2025, '2025-09-20', 'Consecrated',                'CON-2025-HC',
     null,                      'Hurricane',    '25526', false, 'Yes',     'Living'),

    -- AS-00015: Joined 2025-09-21, ONE DAY after the cutoff, no dues. -> NOT eligible (owes dues)
    ('AS-00015', 'Beth',   'Osborne',  null,    'Beth Osborne',         'Wayne',      2025, '2025-09-21', 'Consecrated',                'CON-2025-HC',
     null,                      'Wayne',        '25570', false, 'Yes',     'Living');


-- -----------------------------------------------------------------------------
-- 3) PAYMENTS (the ledger). Only four members have paid anything.
--   AS-00004 has TWO lines that SUM to $50 -- that is what tips them to life member.
-- -----------------------------------------------------------------------------
insert into payments (payment_id, member_id, payment_date, amount, payment_method, recorded_by) values
    ('PAY-0001', 'AS-00004', '2026-05-05', 30, 'PayPal', 'seed'),
    ('PAY-0002', 'AS-00004', '2026-06-10', 20, 'PayPal', 'seed'),
    ('PAY-0003', 'AS-00006', '2024-04-01', 75, 'Check',  'seed'),
    ('PAY-0004', 'AS-00008', '2020-06-01', 100,'Check',  'seed'),
    ('PAY-0005', 'AS-00009', '2026-04-15', 25, 'Cash',   'seed');


-- -----------------------------------------------------------------------------
-- 4) STANDING_ACTIONS (append-only history). The "reason" text is sensitive and
--    invented; in Stage 5 we lock it down so only officers can read it.
--    Note AS-00011 has TWO rows -- the later Reinstatement is the "latest action".
-- -----------------------------------------------------------------------------
insert into standing_actions (action_id, member_id, action_type, effective_date, end_date, reason, recorded_by) values
    -- AS-00006: suspension still in force (ends 2030) -> currently suspended
    ('SA-0001', 'AS-00006', 'Suspension',    '2026-01-01', '2030-06-01', 'Sample reason: pending review of event conduct', 'seed'),
    -- AS-00007: suspension already ended (2023) -> good standing now
    ('SA-0002', 'AS-00007', 'Suspension',    '2022-01-01', '2023-01-01', 'Sample reason: late dues, since resolved',       'seed'),
    -- AS-00008: expulsion -> former member
    ('SA-0003', 'AS-00008', 'Expulsion',     '2024-06-01', null,         'Sample reason: bylaws violation (invented)',      'seed'),
    -- AS-00010: resignation -> former member
    ('SA-0004', 'AS-00010', 'Resignation',   '2023-03-01', null,         'Sample reason: relocated out of state',           'seed'),
    -- AS-00011: suspended, THEN reinstated -> latest action is the reinstatement
    ('SA-0005', 'AS-00011', 'Suspension',    '2020-01-01', '2021-01-01', 'Sample reason: administrative hold',              'seed'),
    ('SA-0006', 'AS-00011', 'Reinstatement', '2021-06-01', null,         'Sample reason: hold cleared',                     'seed'),
    -- AS-00012: indefinite suspension (no end date) -> suspended indefinitely
    ('SA-0007', 'AS-00012', 'Suspension',    '2025-05-01', null,         'Sample reason: contact lost, standing under review','seed');
