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

## Attempt 1

### The data model

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

To install the data model, go to `model-01` and run `setup.sql`.


### Scenarios to validate versioning a Civil Network database

We are going to define a number of scenarios that 2 users -Bob and Bill- will encounter while creating their plans. Each user works on his own work space.

NOTE:
- *feature* and *inventory* are synonyms.
- We are not leveraging the civil network geometry rules we defined in `setup.sql`.
- We are not keeping span geometry consistent when we move the nodes they are linked to. For example, says 2 poles are linked via an aerial span. If we change the coordinates of one of the poles, we are not going to adjust the coordinates of the span so that it still links the 2 poles. It is for now outside of the scope of these validation scenarios. The goal is just to validate the versioning scenarios.


Scenarios:
0. We start with an inventory of structures and spans created by the `setup.sql` scripts and illustrated below:
  ![initial inventory](inventory-0.png)
1. [01-1-bobExtendsExistingPlan.sql](model-01/01-1-bobExtendsExistingPlan.sql) Bob creates a workspace where he extends the existing inventory. He does not modify any attributes but add new inventory elements. Bob posts his plan so that others can use it.
3. [01-2-bobModifiesItsOwnPlan.sql](model-01/01-2-bobModifiesItsOwnPlan.sql) Demonstrate Bob can remove previously added inventory and modify features and network attributes.
4. [01-3-billExtendsBobPlans.sql](model-01/01-3-billExtendsBobPlans.sql) Demonstrate Bill can work in parallel with Bob. Bill can use any inventory posted by Bob. But Bill cannot use any inventory that Bob has not posted yet. Bill will only add features and network connections. He will not modify attributes of existing features. This means that this scenario will not produce any conflict.
5. [01-4-bobFurtherExtendsPlansWithoutConflictWithBillChanges.sql](model-01/01-4-bobFurtherExtendsPlansWithoutConflictWithBillChanges.sql) Demonstrate that there are no conflicts when we simply add features. **I think this scenario is not necessary as we have already tested it**
6. [01-5-BobDetectsConflictOnAnInventory.sql](model-01/01-5-BobDetectsConflictOnAnInventory.sql) Demonstrate that we can detect conflicts on inventory (i.e. structure and span feature tables). Sequence of events:
  - Bill changes the location of MH2 and posts it
  - Bob changes the location of MH2 too
  - Bob detects that there is a conflict if he tried to post his changes
  - Bob resolves the change by keeping Bill changes instead of his.
