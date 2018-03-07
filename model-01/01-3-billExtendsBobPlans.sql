-- Scenario: Demonstrate another user can work on inventory posted but still worked on by other workspaces
--            As long as they dont modify attributes of same features and/or network there should not be any onnection
-- Given that we have run 01-2-bobModifiesItsOwnPlan.sql
-- Bill creates its own work order and connects another home MH2



-- create work order
EXECUTE DBMS_WM.CreateWorkspace ('bill-01');
EXECUTE DBMS_WM.GotoWorkspace ('bill-01');

-- Add another home (MDU-2) and connect it to MH2
insert into STRUCTURE values (6, '3,4', 'MDU-2', 9);
insert into SPAN values (6, '(3,4),(2,1)', 'C/W-1', 5);
insert into CIVIL_NETWORK VALUES (5, 1, 6, 6);
commit;

select * from structure_view;
select * from civil_network;

-- Post bill-01 to live
EXECUTE DBMS_WM.GotoWorkspace ('LIVE');
EXECUTE DBMS_WM.MergeWorkspace ('bill-01');
