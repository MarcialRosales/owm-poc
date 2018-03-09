EXECUTE DBMS_WM.GotoWorkspace ('LIVE');
EXECUTE DBMS_WM.CreateWorkspace ('wo-1');

-- Feature Class : Contains structures we individually place in a map
CREATE TABLE MANHOLE (
  ID NUMBER(5) PRIMARY KEY,
  LABEL VARCHAR(15)
);
EXECUTE DBMS_WM.EnableVersioning ('MANHOLE');

-- 0) LIVE HAS manhole
insert into MANHOLE VALUES (1, 'A');
commit;
select * from manhole;

-- 1) Merge a record (Manhole-1) which has not changed in LIVE
/*
LIVE: Manhole-1.label = 'A'
WO:   Manhole-1.label = 'C'

after merge:
LIVE: Manhole-1.label = 'C'
WO: Manhole-1.label = 'C'
*/

EXECUTE DBMS_WM.GotoWorkspace ('wo-1');
UPDATE MANHOLE set LABEL = 'C' WHERE ID = 1;
commit;
EXECUTE DBMS_WM.MergeWorkspace ('wo-1');
select * from manhole;

-- 2) Merge a record (Manhole-1) which has not changed in LIVE but LIVE has new records (manhole-2)
/*
  LIVE: Manhole-1.label = 'A'
        Manhole-2.label = 'X'  (new recorded added)
  WO:   Manhole-1.label = 'D'

  after merge: Base has the new manhole-2 record
  LIVE: Manhole-1.label = 'D'
        Manhole-2.label = 'X'
  WO: Manhole-1.label = 'D'
        Manhole-2.label = 'X'
*/

EXECUTE DBMS_WM.GotoWorkspace ('LIVE');
insert into MANHOLE VALUES (2, 'X');
commit;
select * from manhole;

EXECUTE DBMS_WM.GotoWorkspace ('wo-1');
UPDATE MANHOLE set LABEL = 'C' WHERE ID = 1;
commit;
EXECUTE DBMS_WM.MergeWorkspace ('wo-1'); -- << Merge does not refresh. We have to explicitly refresh it
select * from manhole;
EXECUTE DBMS_WM.RefreshWorkspace ('wo-1');
select * from manhole;


-- 3) Merge a record (Manhole-1) which has not changed in LIVE but LIVE has deleted records (manhole-2) which were in teh base
/*
  LIVE: Manhole-1.label = 'C'
                                <<<<  manhole-2 deleted
  Base: Manhole-1.label = 'C'
        Manhole-2.label = 'X'
  WO:   Manhole-1.label = 'F'

  after merge: base has not manhole-2 record
  LIVE: Manhole-1.label = 'F'
  WO: Manhole-1.label = 'F'
        Manhole-2.label = 'F'
*/

EXECUTE DBMS_WM.GotoWorkspace ('LIVE');
delete MANHOLE where ID = 2;
commit;
select * from manhole;

EXECUTE DBMS_WM.GotoWorkspace ('wo-1');
UPDATE MANHOLE set LABEL = 'F' WHERE ID = 1;
commit;
EXECUTE DBMS_WM.MergeWorkspace ('wo-1');
select * from manhole;
EXECUTE DBMS_WM.RefreshWorkspace ('wo-1'); -- << Merge does not refresh. We have to explicitly refresh it
select * from manhole;


-- 4) CONFLICT: Merge modified record (manhole-1) which has also changed in LIVE
/*
  LIVE: Manhole-1.label = 'G'
  WO:   Manhole-1.label = 'H'  <- conflict: base does not match live
*/

EXECUTE DBMS_WM.GotoWorkspace ('LIVE');
UPDATE MANHOLE set LABEL = 'G' WHERE ID = 1;
commit;
select * from manhole;

EXECUTE DBMS_WM.GotoWorkspace ('wo-1');
UPDATE MANHOLE set LABEL = 'HK' WHERE ID = 1;
commit;
EXECUTE DBMS_WM.MergeWorkspace ('wo-1');

-- THERE SHOULD BE 1 TABLE WITH CONFLICT
SELECT * FROM ALL_WM_VERSIONED_TABLES WHERE conflict = 'YES';

column WM_WORKSPACE format a20

-- THERE SHOULD BE 1 conflict
-- base (a.k.a. base row) is the value of the row at the time of the first update or delete operation in the child workspace.
--    It is not the last refreshed version from LIVE.
-- parent (live) is the value of the row at the LIVE workspace
select * from MANHOLE_conf;

-- lets start resolving the conflict
EXECUTE DBMS_WM.BeginResolve('wo-1');

-- use WO (child) instead of live (parent) or base
EXECUTE DBMS_WM.ResolveConflicts('wo-1', 'MANHOLE',  'ID = 1', 'CHILD');
commit;

-- THERE SHOULD NOT BE ANY conflicts
select * from MANHOLE_conf;

-- commit the conflict resolution but locally. we still have to merge it.
EXECUTE DBMS_WM.CommitResolve ('wo-1');
select * from manhole;

EXECUTE DBMS_WM.GotoWorkspace ('LIVE');
select * from manhole;

EXECUTE DBMS_WM.MergeWorkspace ('wo-1');
select * from manhole;


-- Check save points
select savepoint, workspace, implicit, position, version from ALL_WORKSPACE_SAVEPOINTS where workspace in ('LIVE','wo-1');
-- Check versions
select * from all_version_hview where workspace in ('LIVE','wo-1');

-- 4) CONFLICT: Merge modified record (manhole-1) which has been deleted in LIVE
/*
  LIVE: [ deleted Manhole-1.label]
  WO:   Manhole-1.label = 'HM'  <- conflict: live does not have it
*/
EXECUTE DBMS_WM.GotoWorkspace ('LIVE');
delete manhole where id = 1;
commit;


EXECUTE DBMS_WM.GotoWorkspace ('wo-1');
UPDATE MANHOLE set LABEL = 'HM' WHERE ID = 1;
commit;
EXECUTE DBMS_WM.MergeWorkspace ('wo-1');

-- check conflicts
select * from MANHOLE_conf;
/* Produces this table:

M_WORKSPACE		     ID LABEL		WM_
-------------------- ---------- --------------- ---
LIVE			      1 G		YES
wo-1			      1 HM		NO
BASE			      1 HJ		NO
*/

-- resolve by keeping the record, i.e. using child version.
EXECUTE DBMS_WM.BeginResolve('wo-1');
EXECUTE DBMS_WM.ResolveConflicts('wo-1', 'MANHOLE',  'ID = 1', 'CHILD');
commit;
EXECUTE DBMS_WM.CommitResolve ('wo-1');
EXECUTE DBMS_WM.MergeWorkspace ('wo-1');

-- Go to live and check that it is again there
EXECUTE DBMS_WM.GotoWorkspace ('LIVE');
select * from manhole;

-- 5) NO CONFLICT: Merge delete record (manhole-1) which has been also deleted in LIVE
/*
  LIVE: [ deleted Manhole-1.label]
  WO:   [Manhole-1.label ]  <- conflict: live does not have it
*/

EXECUTE DBMS_WM.GotoWorkspace ('LIVE');
delete manhole where id = 1;
commit;

EXECUTE DBMS_WM.GotoWorkspace ('wo-1');
delete manhole where id = 1;
commit;
EXECUTE DBMS_WM.MergeWorkspace ('wo-1');
