-- Scenario: Demonstrate that there are no conflicts when we simply add elements
--            In this case, Bob is going to add another home (third one) without conflicting with
--            changes that Bill has done in the meantime on inventory that he previously added
-- Given that we have run 01-3-billExtendsBobPlans.sql
-- Bob adds another home MDU-3 and connects again to MH2

-- create work order
EXECUTE DBMS_WM.GotoWorkspace ('bob-01');

-- Add another home (MDU-3) and connect it to MH2
insert into STRUCTURE values (7, '3,5', 'MDU-2', 9);
insert into SPAN values (7, '(3,5),(2,1)', 'C/W-1', 5);
insert into CIVIL_NETWORK VALUES (6, 1, 7, 7);
commit;

select * from structure_view;
select * from civil_network;

-- Check if there are any conflicts
DBMS_WM.SetConflictWorkspace('bob-01');
-- There should not be any conflicts
SELECT * FROM ALL_WM_VERSIONED_TABLES WHERE conflict = 'YES';

-- Post bill-01 to live
EXECUTE DBMS_WM.GotoWorkspace ('LIVE');
EXECUTE DBMS_WM.MergeWorkspace ('bob-01');
