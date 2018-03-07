-- How this model works:

- There is no predefined set of tables up front
- We need a type of feature to model structures , so we create 3 tables:
  - Structure which contains the actual features we place in the  map that we select from a catalog of features
  - Structure_Catalog which contains the catalog of Structures available
  - Structure_Types which allows us to classify/group the catalog of structures into sub-types/categories
- We decided that structures and spans are quite different things and hence we model with 2 separate feature class:
  We have them STRUCTURE, STRUCTURE_CATALOG AND STRUCTURE_TYPES tables
  And SPAN, SPAN_CATALOG, SPAN_TYPES tables
- These features are not related between each but we need to relate them to create a geometry network
  We create a geometry network (we dont use Oracle specifics) with 2 tables per network.
  We need to create a civil network that links structure and spans
   - CIVIL_NETWORK that links 2 nodes: Nodes are STRUCTURE feature class and Link is SPAN feature class
   - CIVIL_NETWORK_ALLOW_RULES allows us to further define which specific types within a feature class can be connected

- Only the actual feature tables and the network table (not the rules) are versioned
- The rest of the tables are modified globally, like any RDBMS table.
- The view (a.k.a. DataSet) called Civil_catalog combines the feature class tables of structure, span


-- We use types to model validation rules used later on to define connectivity rules without
-- having to create a brand new class in the catalog
CREATE TABLE STRUCTURE_TYPES (
  TYPE_ID NUMBER(5) PRIMARY KEY,
  DESCRIPTION VARCHAR(15)
);
--
CREATE TABLE STRUCTURE_CATALOG (  -- FEATURE CLASS SPAN CONTAINS ALL SORT OF TYPE OF SPAN
  CLASS_ID NUMBER(5) PRIMARY KEY,
  NAME VARCHAR2(50),
  TYPE_ID NUMBER(5) NOT NULL CONSTRAINT FK_STRUCTURE_CATALOG_TYPE_ID REFERENCES STRUCTURE_TYPES(TYPE_ID)
);

-- Feature Class : Contains structures we individually place in a map
CREATE TABLE STRUCTURE (
  ID NUMBER(5) PRIMARY KEY,
  GEOMETRY VARCHAR2(15), -- REPLACE WITH MDSYS.SDO_GEOMETRY
  LABEL VARCHAR(15), -- IS THIS REALLY NECESSARY. IT ALLOWS US TO DISPLAY A NAME IN THE MAP
  CLASS_ID NUMBER(15) NOT NULL
    CONSTRAINT FK_STRUCTURE_CLASS_ID REFERENCES STRUCTURE_CATALOG(CLASS_ID)
);




-- Feature Class : Contains span we individually place in a map
CREATE TABLE SPAN_TYPES (
  TYPE_ID NUMBER(5) PRIMARY KEY,
  DESCRIPTION VARCHAR(15)
);
CREATE TABLE SPAN_CATALOG (  -- FEATURE CLASS SPAN CONTAINS ALL SORT OF TYPE OF SPAN
  CLASS_ID NUMBER(5) PRIMARY KEY,
  NAME VARCHAR(15),
  TYPE_ID NUMBER(5) NOT NULL
   CONSTRAINT FK_SPAN_CATALOG_TYPE_ID  REFERENCES SPAN_TYPES(TYPE_ID)
);

CREATE TABLE SPAN (
  ID NUMBER(5)   PRIMARY KEY,
  GEOMETRY VARCHAR2(15), -- REPLACE WITH MDSYS.SDO_GEOMETRY
  LABEL VARCHAR(15), -- IS THIS REALLY NECESSARY. IT ALLOWS US TO DISPLAY A NAME IN THE MAP
  CLASS_ID NUMBER(15) NOT NULL
     CONSTRAINT FK_SPAN_CLASS_ID REFERENCES SPAN_CATALOG(CLASS_ID)
);




-- Civil network
CREATE TABLE CIVIL_NETWORK (
  ID NUMBER(5) PRIMARY KEY,
  NODE1 NUMBER(5) NOT NULL
    CONSTRAINT FK_CIVIL_NETWORK_NODE1 REFERENCES STRUCTURE(ID),
  NODE2 NUMBER(5) NOT NULL
    CONSTRAINT FK_CIVIL_NETWORK_NODE2 REFERENCES STRUCTURE(ID),
  LINK NUMBER(5) NOT NULL
    CONSTRAINT FK_CIVIL_NETWORK_LINK  REFERENCES SPAN(ID)
);

CREATE TABLE CIVIL_NETWORK_ALLOW_RULES (
  ID NUMBER(5) PRIMARY KEY ,
  NODE_TYPE NUMBER(5) NOT NULL
    CONSTRAINT FK_NODE_TYPE  REFERENCES STRUCTURE_TYPES(TYPE_ID),
  LINK_TYPE NUMBER(5) NOT NULL
    CONSTRAINT FK_LINK_TYPE REFERENCES SPAN_TYPES(TYPE_ID)
);


CREATE OR REPLACE VIEW STRUCTURE_VIEW AS
SELECT S.ID, S.GEOMETRY, S.LABEL, S.CLASS_ID, C.NAME, C.TYPE_ID, T.DESCRIPTION
FROM STRUCTURE S, STRUCTURE_CATALOG C, STRUCTURE_TYPES T
where S.CLASS_ID = C.CLASS_ID AND C.TYPE_ID = T.TYPE_ID;

CREATE OR REPLACE VIEW SPAN_VIEW AS
FROM SPAN S, span_CATALOG C, Span_TYPES T
where S.CLASS_ID = C.CLASS_ID and C.TYPE_ID = T.TYPE_ID;

CREATE OR REPLACE VIEW CIVIL_CATALOG AS
SELECT 'STRUCTURE' AS FEATURE_CLASS, C.CLASS_ID, C.NAME, C.TYPE_ID, T.DESCRIPTION FROM STRUCTURE_CATALOG C, STRUCTURE_TYPES T
  where C.TYPE_ID = T.TYPE_ID
UNION
SELECT 'SPAN' AS FEATURE_CLASS, C.CLASS_ID, C.NAME, C.TYPE_ID, T.DESCRIPTION FROM span_CATALOG C, Span_TYPES T
  where C.TYPE_ID = T.TYPE_ID;


--- SAMPLE Data

-- Build catalog
-- STRUCTURE_TYPES  CLASS_ID NUMBER(5), NAME VARCHAR(15), TYPE_ID NUMBER(5),

insert into STRUCTURE_TYPES values (1, 'DUCT TEE');
insert into STRUCTURE_TYPES values (2, 'ALL IN ONE');
insert into STRUCTURE_TYPES values (3, 'DSLAM');
insert into STRUCTURE_TYPES values (4, 'REDUCER');
insert into STRUCTURE_TYPES values (5, 'MONOPOLE');
insert into STRUCTURE_TYPES values (6, 'MANHOLE');
insert into STRUCTURE_TYPES values (7, 'MDU');

-- STRUCTURE_CATALOG    CLASS_ID NUMBER(5), NAME VARCHAR(15), TYPE_ID NUMBER(5),
insert into STRUCTURE_CATALOG values (1, 'FTTP DT/RED 54/56', 1);
insert into STRUCTURE_CATALOG values (2, 'ECI RESLEEVE', 2);
insert into STRUCTURE_CATALOG values (3, 'CCC NO 6 FTTC', 3);
insert into STRUCTURE_CATALOG values (4, 'DUCT CONN 56/102', 4);
insert into STRUCTURE_CATALOG values (5, 'MONOPOLE 18.5M', 5);
insert into STRUCTURE_CATALOG values (6, 'MONOPOLE 12M', 5);
insert into STRUCTURE_CATALOG values (7, 'NS MH', 6);
insert into STRUCTURE_CATALOG values (8, 'OLO MH', 6);
insert into STRUCTURE_CATALOG values (9, 'FTTP MDU', 7);

insert into SPAN_TYPES values (1, 'AERIAL');
insert into SPAN_TYPES values (2, 'CONDUIT');
insert into SPAN_TYPES values (3, 'TRENCH');

insert into SPAN_CATALOG values (1, 'A/C', 1);
insert into SPAN_CATALOG values (2, 'DW', 1);
insert into SPAN_CATALOG values (3, 'RADIO', 1);
insert into SPAN_CATALOG values (4, 'D104', 2);
insert into SPAN_CATALOG values (5, 'C/W', 3);

-- STRUCTURE    ID NUMBER(5), GEOMETRY SDO_GEOMETRY, LABEL VARCHAR(15),
--              CLASS_ID NUMBER(5), NAME VARCHAR(15), TYPE_ID NUMBER(5),

-- INSERT MH1 STRUCTURE
insert into STRUCTURE values (1, '2,2', 'MH2', 7);
-- INSERT MH2 STRUCTURE
insert into STRUCTURE values (2, '1,3', 'MH1', 8);
-- CONNECT MH1 - MH2 USING a C/W trench span
insert into SPAN values (1, '2,2-1,3', 'UG1', 5);
insert into CIVIL_NETWORK VALUES (1, 1, 2, 1);

-- INSERT POLE1 structure
insert into STRUCTURE values (3, '1,1', 'P1', 5);
-- CONNECT POLE1 - MH2 USING a D104 Conduit span
insert into SPAN values (2, '2,1-2,2', 'UG2', 4);
insert into CIVIL_NETWORK VALUES (2, 2, 3, 2);

-- INSERT POLE2 STRUCTURE
insert into STRUCTURE values (4, '2,1', 'P2', 6);
-- CONNECT POLE2 - POLE1 using A/C aerial span
insert into SPAN values (3, '1,1-2,1', 'OH3', 1);
insert into CIVIL_NETWORK VALUES (3, 3, 4, 3);


SELECT * from STRUCTURE_VIEW;
SELECT * from SPAN_VIEW;


-- MAKE INVENTORY VERSIONED: STRUCTURE AND SPAN AND CIVIL_NETWORK
-- A child table in a referential integrity relationship is allowed to be version-enabled without the parent table being version-enabled.
-- parent table is span_catalog and client table is span
EXECUTE DBMS_WM.EnableVersioning ('STRUCTURE,SPAN,CIVIL_NETWORK');
