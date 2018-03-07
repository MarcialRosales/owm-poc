-- Scenario: Demonstrate we can remove previously added inventory and modify features and network attributes
-- Given that we have run 01-1-bobExtendsExistingPlan.sql
-- Bob changes location of the home
-- Bob replaces connections with a different span, C/W (TRENCH)


-- Open work order
EXECUTE DBMS_WM.GotoWorkspace ('bob-01');

-- Change location of home, add new span and connect it to home, and remove old span
update STRUCTURE set GEOMETRY = '3,3' where ID = 5;
insert into SPAN values (5, '(3,2),(2,1)', 'C/W-1', 5);
update CIVIL_NETWORK set LINK = 5 WHERE ID = 4;
delete SPAN where ID = 4;
commit;

select * from structure_view;
select * from civil_network;

-- Post bob-01 to live
EXECUTE DBMS_WM.GotoWorkspace ('LIVE');
EXECUTE DBMS_WM.MergeWorkspace ('bob-01');
