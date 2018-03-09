
CREATE TABLE POINT_FEATURE (
  ID NUMBER(5) PRIMARY KEY,
  LABEL VARCHAR(15),
  SHAPE SDO_GEOMETRY
);
CREATE TABLE LINE_FEATURE (
  ID NUMBER(5) PRIMARY KEY,
  LABEL VARCHAR(15),
  SHAPE SDO_GEOMETRY
);

/* Use SRID 27700

select COORD_REF_SYS_NAME, COORD_REF_SYS_KIND, COORD_SYS_ID from SDO_COORD_REF_SYS where SRID = 27700;

COORD_REF_SYS_NAME								 COORD_REF_SYS_KIND	  COORD_SYS_ID
-------------------------------------------------------------------------------- ------------------------ ------------
OSGB 1936 / British National Grid						 PROJECTED			  4400

select COORD_SYS_NAME, COORD_SYS_TYPE from SDO_COORD_SYS where COORD_SYS_ID = 4400;

COORD_SYS_NAME																									       COORD_SYS_TYPE
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- ------------------------
Cartesian 2D CS.  Axes: easting, northing (E,N). Orientations: east, north.  UoM: m.																       Cartesian

We can use this url to locate coordinates in a map using the above coordinate system:

https://epsg.io/map#srs=27700&x=525470.479100&y=325260.284765&z=16

*/


INSERT INTO POINT_FEATURE VALUES (1, 'MH-1',
  SDO_GEOMETRY(
      2001,  -- two-dimensional POINT
      27700, -- British National Grid (SDO_SRID)
      NULL,
      SDO_ELEM_INFO_ARRAY(1,1,1), -- 1st element is point-type
      SDO_ORDINATE_ARRAY(525560.353688, 325300.933210)
    )
);
INSERT INTO POINT_FEATURE VALUES (2, 'MH-2',
  SDO_GEOMETRY(
      2001,
      27700,
      NULL,
      SDO_ELEM_INFO_ARRAY(1,1,1), -- 1st element is point-type
      SDO_ORDINATE_ARRAY(525413.591288, 325268.257522)
    )
);

INSERT INTO LINE_FEATURE VALUES (1, 'UH-1',
  SDO_GEOMETRY(
      2002,  -- two-dimensional LINE
      27700,
      NULL,
      SDO_ELEM_INFO_ARRAY(1,2,1), --start with 1<sup>st</sup> Coordinate
                                  -- line string whose vertices are connected with straight line
      SDO_ORDINATE_ARRAY(525560.353688, 325300.933210,
                        525470.479100, 325260.284765,
                        525413.591288, 325268.257522)
    )
);

/*

Projected Bounds of SRID 27700:
-84667.14 11795.97
608366.68 1230247.30
TOLERANCE: 1 (METER)

-- Update the USER_SDO_GEOM_METADATA view. This is required
-- before the spatial index can be created. Do this only once for each
-- layer (that is, table-column combination; here: POINT_FEATURE and SHAPE).
*/

INSERT INTO user_sdo_geom_metadata
    (TABLE_NAME,
     COLUMN_NAME,
     DIMINFO,
     SRID)
  VALUES (
  'POINT_FEATURE',
  'SHAPE',
  SDO_DIM_ARRAY(
    SDO_DIM_ELEMENT('X', -84667.14, 11795.97, 1),
    SDO_DIM_ELEMENT('Y', 608366.68, 1230247.30, 1)
     ),
  27700   -- SRID
);

-------------------------------------------------------------------
-- CREATE THE SPATIAL INDEX --
-------------------------------------------------------------------
CREATE INDEX POINT_FEATURE_SPATIAL_IDX
   ON POINT_FEATURE(SHAPE)
   INDEXTYPE IS MDSYS.SPATIAL_INDEX;

------------------------------------------------------------------
-- PERFORM SOME SPATIAL QUERIES --
-------------------------------------------------------------------
-- Find the (10) closest point to a given location. It returns the 2 boxes: MH-2
select p.LABEL from POINT_FEATURE p where
  SDO_NN(p.SHAPE,
    SDO_GEOMETRY(
        2001,  -- two-dimensional POINT
        27700,
        NULL,
        SDO_ELEM_INFO_ARRAY(1,1,1),
        SDO_ORDINATE_ARRAY(525470.479100, 325260.284765)
      ), 'sdo_batch_size=10') = 'TRUE';

-- Find the (10) closest point to a given location within a range of 70 meters : It returns only MH-2
select p.LABEL from POINT_FEATURE p where
  SDO_NN(p.SHAPE,
    SDO_GEOMETRY(
        2001,  -- two-dimensional POINT
        27700,
        NULL,
        SDO_ELEM_INFO_ARRAY(1,1,1),
        SDO_ORDINATE_ARRAY(525470.479100, 325260.284765)
      ), 'sdo_batch_size=10 distance=70 unit=METER') = 'TRUE';
