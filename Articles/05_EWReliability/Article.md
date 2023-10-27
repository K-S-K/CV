# Reliability Analysis System

[Back to the main page](../../README.md)

**Development period:** August 2012 - May 2017.

**Practical application:** To measure software's availability factor in production and the CI cycle[^1].

**Project purpose:** The analysis of the program's complex reliability parameters and status.


**Project description:** 
Initially, we had one point of interest: to measure the availability factor of our software (a cell operator billing system) to be sure it meets the requirements of our customer (cell operator). They asked us to provide an availability factor = 0.99995.
We've researched methodology for measuring a time period we can qualify as a "working interval" and a time period we can call a "not working interval".
The ratio of a calculated sum of the working interval to the whole observation time is the availability factor we need. 

**My part in this project:** 
- Theory research;
- RND (different experiments with collecting and analysis of the measures);
- The project architecture development;
- Creating the initial version of the testing software deployment subsystem;
- Creating two initial traffic models (Voice and SMS);
- Creating a cell commutator emulator (with traffic generator schedulers and response time and content analyzers);
- Creating a state reporting component for the software components that must be measured;
- Creating a scanner component to collect data from the observed applications and a scanner itself to collect the data to the SQL Server;
- Creating the first version of data analysis implementation;
- Creating a desktop software tool to view the reliability information in different representations (table and diagram);
- Creating a desktop tool to control the work of the reliability data collecting system remotely over a cluster (start and stop, selection of a version of measuring software to be working on the node, configuration of data gathering on every node);
- Sharing the work between several members of our team.

**Evolving features of the project we implemented with wonderful people I worked with:** 
- Configurable deployment over the cluster subsystem;
- Many different traffic models for the load testing subsystem;
- Suspendable queue of measures to survive the database server unavailability periods without keeping all measures in memory (sometimes it was extremely necessary); 
- Several additional measuring subsystems like SQLServer availability observation component and MongoDB Health monitoring component, because SQLServer and MongoDB don't naturally provide data we need to observe them;
- Reliability Interval Marking on DB subsystem which is running on SQL Server by the SQL Server Agent and makes ready-to-use intervals of work for every observing software instance;
- Tree-like table interval representation for the UI and the reports;
- Reliability diagram - a scalable graphical representation of the reliability intervals on a common time scale for manual visual analysis of emergency situations evolution process;
- Dangerous situations detector on the database side - a module that finds time periods when applications are overloaded simultaneously (so-called "Pillars") to show them on the Reliability diagram and in the report tables;
- Emailing subsystem which hourly sends reports with reliability diagrams and dangerous situations tables;
- Online Diagram - the visualization of the real-time state of the observing applications.

**Implementation technologies:** .Net Framework, Windows Forms, Performance Counters, MS SQL Server, Windows Services, Application Domains, Desktop Applications.


**Fig.1 The Theory - the meaning of the Reliability Intervals**

![The Duplicator list](Images/Fig_01_Theory.png)


**Fig.2 The Reliability Intervals Table**
![Order Events lists](Images/Fig_02_RITable.png)


**Fig.3 The Reliability Intervals Diagram - Emergency investigation view**
![Order Events lists](Images/Fig_03_RIDiag.png)


**Fig.4 The Reliability Intervals Diagram - Emergency investigation view**
![Order Events lists](Images/Fig_04_RIDiag.png)


**Fig.5 The Reliability Intervals Diagram - Emergency Intervals**
This diagram highlights emergency situations. Red intervals are critical errors. Yellow intervals are emergency situations. Dark green intervals are emergency time intervals. If we receive many fat green intervals it means the system does not supply the load. The same image appears in the UI and the automated hourly report.
![Order Events lists](Images/Fig_05_RIDiag_Pillars.png)


**Fig.6 The Reliability Intervals Diagram - That's how the software update looks like**
![Order Events lists](Images/Fig_06_RIDiag_Update.png)


**Fig.7 The Reliability Online Monitor shows the actual state of every configured application**
![Order Events lists](Images/Fig_07_RIOM.png)





[^1]: The project is in use by a cell operator billing system to predict emergency situations and to analyze the evolution of damages and failures. Also, the project is used by a billing system life cycle to measure and compare the reliability parameters such as MTBF and Availability factor on every release during load testing.
