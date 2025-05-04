# Automated Trading system

[Back to the main page](../../README.md)

**Development period:** 2011.10-2019.11.

**Practical application:** Research and development[^1].

**Project purpose:** Automated trading research. Testing and tuning of the trading approaches.

**Project description:**
The final project contains these components:

- The SQL Server database with trading history data in ticks;
- The Import tool for filling the database with trading history data from .qsh files;
- The Exchange Emulator;
- The Exchange Connector (connector to SmartCOM connector), which can transparently restore the context after the broken connection is restored;
- The Trading Engine, which can be connected to the Exchange Connector or the Exchange Emulator;
- The set of different Indicators which can be connected to the Trading Engine by configuration;
- The scheduling module with switching the indicator configurations on the schedule base;
- The Desktop Application with the UI that allows to monitor and configure the trading process;
- The quick calculations tool that is used to emulate trade sessions quickly without visualization simultaneously for different configurations on the historical data to do experiments with algorithms and their configurations;
- The reporting module;
- The New UI module on WPF was started to be  implemented, but it was never completed;
- A lot of small tools for different experiments.

**My part in this project:** Requirements collecting, architecture development, software development, experiments, analysis, discussions, etc.

**Implementation technologies:** .Net Framework, Windows Forms, SmartCOM COM Connector, QScalp qsh format import library.

**Fig.1 The Trading Experiment**<br>
![The Duplicator list](Images/Fig_01_Experiment.png)

**Fig.2 The Trading Testing** on the live Exchange connection. Comparing the representation of positions with representation in the official trading tool.<br>
![The Duplicator list](Images/Fig_02_Testing.png)

**Fig.3 The Trading Session Report** with common results information and hourly earn diagram.<br>
![Order Events lists](Images/Fig_03_Report.png)

**Fig.4 The Trading Session WPF UI**, which can show price graphs, clusters, and trends.<br>
![New trading analysis user interface](Images/Fig_04_SquirrelGraph.gif)
(The copy of the video on YouTube: [youtube.com/watch?v=7lW273PTbGI](https://www.youtube.com/watch?v=7lW273PTbGI).

[^1]: It was an incredible journey. My partner is experienced in trading, and I am experienced in software development. During the eight years, we experimented with different trading algorithms and got some success, great excitement, and a lot of experience. After that, our partnership was completed for personal reasons, but we achieved excellent knowledge and awareness of our ability to do such things.
