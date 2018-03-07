-- Scenario:
-- Add an structure for a home ('FTTP MDU' of type MDU)
-- Connect home to MH2 with a span ('C/W' of type CONDUIT)


-- Create work order
EXECUTE DBMS_WM.CreateWorkspace ('bob-01');
-- Open work order 
EXECUTE DBMS_WM.GotoWorkspace ('bob-01');

-- Add home and connect it
insert into STRUCTURE values (5, '3,2', 'MDU-1', 9);
insert into SPAN values (4, '(3,2),(2,1)', 'UG3', 4);
insert into CIVIL_NETWORK VALUES (4, 2, 5, 4);
commit;

-- Post bob-01 to live
EXECUTE DBMS_WM.GotoWorkspace ('LIVE');
EXECUTE DBMS_WM.MergeWorkspace ('bob-01');
