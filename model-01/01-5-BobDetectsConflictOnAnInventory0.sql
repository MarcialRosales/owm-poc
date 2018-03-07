-- Scenario: Demonstrate that we can detect conflicts on inventory (i.e. structure and span feature tables)
--            Sequence of events:
--              - Bill changes the location of MH2 and posts it
--              - Bob changes the location of MH2 too and post it
--              - Bob posts his changes and detect that there is a conflict
--              - Bob resolves the change by keeping Bill changes instead of his.
--

-- Bill opens work order
EXECUTE DBMS_WM.GotoWorkspace ('bill-01');

update  STRUCTURE set GEOMETRY = '(2,2)' WHERE ID = 1;
commit;

-- Post bill-01 to live
EXECUTE DBMS_WM.MergeWorkspace ('bill-01');

EXECUTE DBMS_WM.GotoWorkspace ('LIVE');
select * from structure_view where id=1;

-- Bob opens work order
EXECUTE DBMS_WM.GotoWorkspace ('bob-01');

update  STRUCTURE set GEOMETRY = '{2,2}' WHERE ID = 1;
commit;

-- Check if there are any conflicts before actuallying merging
EXECUTE DBMS_WM.SetConflictWorkspace('bob-01');
-- There should not be any conflicts
SELECT * FROM ALL_WM_VERSIONED_TABLES WHERE conflict = 'YES';

-- Find out which rows have conflict in the structure table
-- We should get somthing like:
-- BASE is LIVE's version that Bob has
-- bob-01 is the current version of Bob's workspace with all this local changes
-- LIVE is LIVE'S latest version (which has Bill changes)

-- WM_WORKSPACE		     ID GEOMETRY	LABEL		  CLASS_ID WM_DELETED
-- -------------------- ---------- --------------- --------------- ---------- ---
-- BASE			            1 2,2		    MH2			 7 NO
-- LIVE			            1 (2,2)	  	MH2			 7 NO
-- bob-01			          1 {2,2}		  MH2			 7 NO

column WM_WORKSPACE format a20
select * from structure_conf;

-- lets start resolving the conflict
EXECUTE DBMS_WM.BeginResolve('bob-01');

-- resolve conflict on structure MH2 (id=1) using LIVE and commit (we have to commit)
-- parent is live, child is bob-02 and base is what bob had before he made his changes
EXECUTE DBMS_WM.ResolveConflicts('bob-01', 'STRUCTURE',  'ID = 1', 'PARENT');
commit;

-- THERE SHOULD NOT BE ANY conflicts
select * from structure_conf;

-- commit the conflict resolution
EXECUTE DBMS_WM.CommitResolve ('bob-01');
