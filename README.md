# Evaluate Oracle SpaceManager to model GIS Civil Network as a versioned geospatial database

## Logistics

1. Run Oracle12c as a docker container
  `docker run -d -p 8080:8080 -p 1521:1521 sath89/oracle-12c`
2. Check when it is up and running before use it as it takes some time to start
  `docker logs <containerId> -f`
3. Install sqlplus or run sqlplus within the container
   ```
   docker exec -it <containerId> /bin/bash
   sqlplus SYSTEM/oracle
   ```

## Playground

### Testing all sort of scenarios we encounter when we merge/refresh a workspace

Using a very trivial data model, test all the various scenarios we may encounter when we merge/refresh a workspace. For the sake of simplicity, we only use one table but it does not make any difference whether we have 3 tables involved in a conflict.

Table Model consists of just one table called **manhole**. We use just one workspace, **wo-1** in addition to **LIVE**. We merge from **wo-1** to **LIVE**.

Scenarios:
1. [Merge a record (Manhole-1) which has not changed in LIVE](https://github.com/MarcialRosales/owm-poc/blob/master/playground/1-play.sql#L16-L30)
2. [Merge a record (Manhole-1) which has not changed in LIVE but LIVE has new records (manhole-2)](https://github.com/MarcialRosales/owm-poc/blob/master/playground/1-play.sql#L32-L58)
3. [Merge a record (Manhole-1) which has not changed in LIVE but LIVE has deleted records (manhole-2) which the workspace knew about them](https://github.com/MarcialRosales/owm-poc/blob/master/playground/1-play.sql#L59-L84)
4. <span style="color:red">CONFLICT</span>: Merge modified record (manhole-1) which has also changed in LIVE
5. <span style="color:red">CONFLICT</span>: Merge modified record (manhole-1) which has been deleted in LIVE
6. NO CONFLICT: Merge delete record (manhole-1) which has been also deleted in LIVE

These scenarios are modelled [here](playground/1-play.sql):

### Modelling geometry attributes and doing spatial searching

First we model a features's shape using 'SDO_GEOMETRY' oracle type. A shape consists of its actual shape which can be a point, line, polygon, etc; and its coordinate based on a coordinate system. We have decided to use [British National Grid](https://epsg.io/27700) coordinate system for our tests. We have modelled point features (2 points) and line features that join points together (1 line with one intermediate point). We can locate these features in a [map](https://epsg.io/map#srs=27700&x=525470.479100&y=325260.284765&z=16).

Second we have to create the spatial index so that we can do spatial searches.

And finally, we do a search like *Find which features are available around a certain location*.

[geospatial.sql](playground/geospatial.sql)

## Attempt 1

### The data model

![data model](model-01.png)

- There are no predefined table model. In other words, the application does not have any concept of entities (there is no ORM)
- We build table model on demand based on business needs and using an API.
- In a GIS database we have, at least, feature and feature classes tables.
- A feature table contains elements we place in a map. A feature table has at least per row, a geometry attribute with its shape and coordinates and a link to its feature class. e.g. if we have 3 manholes in a map, we have 3 rows on this table, one for each manhole.
- A feature class has one column for each attribute that describes the feature such as manufacturer or serialNumber. And each row defines a particular configuration of one feature class. e.g. if all 3 manholes share the same characteristics, we may have 1 row in the Structure_Catalog table that describes that manhole and all 3 rows in the Structure table references this single row in the Structure_Catalog. This is a normalized database model. Later on we could decide to denormalize it, and duplicate the data in the feature table.
- We need to model Structures and Spans. We could model the two entities as just one. However structures and spans may have different attributes, thus we are going to treat them differently and have different tables for each one.
- For each type of feature we are going to create 3 tables: X, X_Catalog and X_Types. For example:
  - Structure table contains structure features,
  - Structure_Catalog contains the feature classes for structure features,
  - Structure_Types which allows us to classify/group the catalog of structures feature classes into sub-types/categories. For example, there could be many types of spans but we can classify them into aerials, underground, etc. Types will be later on used to model connectivity rules in a geometry network.
- Feature tables are not related between each. Instead, we model that relationship thru a different table that models geometry networks, i.e. from node1 feature to node2 feature using a link feature.  
- We are going to model just one type of network, the civil one, hence we create a table that models just that. Later if we need another network, we create its own table.
- To model our civil network we are going to create a geometry table that has 2 nodes and 1 link column that points to a feature table respectively.
   - Node1 and Node2 columns refers to the STRUCTURE feature table
   - Link column refers to the SPAN feature table
   - CIVIL_NETWORK_ALLOW_RULES allows us to further define which specific types within a feature class can be connected

- We only need to version feature tables and the network table (not the rules). Static data like catalog, types and rules are global.

To install or view the data model, go to `model-01` and open/run `setup.sql`.


### Scenarios

We are going to define a number of scenarios that 2 users -Bob and Bill- will encounter while creating their plans. Each user works on his own work space.

NOTE:
- *feature* and *inventory* are used indistinctly.
- We are not leveraging the civil network geometry rules we defined in `setup.sql`. In other words, we are not going to check which features can be connected. This is not enforced by the database itself but by the application logic that access the database.
- We are not keeping links' geometry consistent when we move the nodes it is joining. For example, says 2 poles are joined via an aerial span. If we change the coordinates of one of the poles, we are not going to adjust the coordinates of the span so that it still links the 2 poles. It is for now outside of the scope of these validation scenarios. The goal is just to validate the versioning scenarios.


0. We start with an inventory of structures and spans created by the `setup.sql` scripts and illustrated below:
  ![initial inventory](inventory-0.png)
1. [01-1-bobExtendsExistingPlan.sql](model-01/01-1-bobExtendsExistingPlan.sql) Bob creates a workspace where he extends the existing inventory. He does not modify any attributes but add new inventory elements. Bob posts his plan so that others can use it.
3. [01-2-bobModifiesItsOwnPlan.sql](model-01/01-2-bobModifiesItsOwnPlan.sql) Bob can remove previously added inventory and modify features and network attributes.
4. [01-3-billExtendsBobPlans.sql](model-01/01-3-billExtendsBobPlans.sql) Bill creates another workspace where he extends Bob's plan. Bill can use any inventory posted by Bob. But Bill cannot use any inventory that Bob has not posted yet. In this scenario, Bill only adds features and network connections. He does not modify attributes of existing features. This means that this scenario will not produce any conflict when Bill posts his changes.
5. [01-4-bobFurtherExtendsPlansWithoutConflictWithBillChanges.sql](model-01/01-4-bobFurtherExtendsPlansWithoutConflictWithBillChanges.sql) Bob continue extending his plan after Bill has already extended. Bob posts his changes without no conflicts because he is not changing inventory, only adding.
6. [01-5-BobDetectsConflictOnAnInventory.sql](model-01/01-5-BobDetectsConflictOnAnInventory.sql) Demonstrate that we can detect conflicts on inventory (i.e. structure and span feature tables). Sequence of events:
  - Bill changes the location of MH2 and posts it
  - Bob changes the location of MH2 too
  - Bob detects the conflict
  - Bob uses Bill changes to resolve the change
7. [01-6-BillRemovesInventoryAddedByBob] Demonstrate that removing inventory does not cause conflicts if we have not modified them. Bill deletes MDU-1 and C/W-1. These 2 inventories were initially added by Bob, but it does not really matter, bill can delete them. Later on, Bob makes changes to other inventory elements and post his changes without any conflicts. When Bob refreshes his workspace, MDU-1 and C/W-1 automatically disappear from his workspace.
