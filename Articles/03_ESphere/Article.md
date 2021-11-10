# Electric power billing project

[:point_left: Back to tthe main page](../../README.md)

**Development period:** 2001-2007.

**Practical application:** In Production[^1].

**Project purpose:** Electric power meters can provide data exchange by different hardware and software APIs. 
The server application collects data from the power meters and put data to the SQL Server database. 
SQL Server Agent exrecutes jobs which calculate result data from the primary data regarding measuring thansformer 
parameters and power grid topology history (bypass switches commutation history, measurement transformers replacement history e t.c.).

**Project description:** 
My application provides the pssibility of proper data storing corresponding the place on the power grid where 
measures were collected from. By the other terms my application is the editor for the ctretion of the 
power network model in the database to store data in the right way to process data by jobs and to retrieve 
data for the reporting. My application contains script which can actualize any version of the database to 
the actual version with all necessary data conversions, COM object which provides API and UI controls 
for the data structure editor and for the different applications which work with data: viewers, report 
generators etc.

**Implementation technologies:** MFC SDI Application, ATL COM object for data management level, OLE DB, CHM Help, T-SQL and some subject area knowledge.


![TThe trip graph navigation](Images/Dlg_Bind_Meter_Tree.png)

[^1]: First deployment was in TumenEnergo, about 26 thousands of metering points. Now it is great successful project.
