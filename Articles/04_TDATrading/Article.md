# Automated Trading System

[Back to the main page](../../README.md)

**Development period:** 2017–2022.

## What this actually was

This was not a startup. It was a five-year research collaboration between two people — a trading domain expert and a software architect — who wanted to find out whether a specific class of trading hypothesis could be made to work. The answer was: partially, and interestingly.

My partner had spent years trading manually. He had intuitions about price behavior that he could describe but not systematically test. I could build the instrument to test them. The problem was translation: his mental model of markets was not naturally expressible in software terms, and my mental model of software was not naturally grounded in market behavior.

The first thing we built was not code. It was a language — a shared vocabulary to classify, describe, and reason about what we were looking at. Signals, frequencies, sessions, configurations, balance zones. Once we could name things the same way, we could build things together.

## The system as research instrument

The architecture evolved through consequences rather than upfront design.

When we began experimenting with trading at multiple frequencies simultaneously — up to twenty different time resolutions running in parallel — we discovered that the system had no way to reason about risk across all of them at once. A balance control module had to be introduced: something that decided how much capital was available for active work and how much had to stay protected. This was a domain insight forcing an architectural change. The system couldn't be correct without it.

The second major refactoring came from a bug we couldn't explain. Eight hours into a live session, an exception. We couldn't reproduce it in tests. The session state at the moment of failure was unrecoverable. My response was to build extended logging deep enough that every session could be replayed in full — every signal, every decision, every state transition — against the exchange emulator. This made every future bug reproducible by definition. It was significant refactoring, but it changed the nature of what we could investigate.

Alongside the core system, my partner learned SQL Server and T-SQL — enough to run his own data queries, form his own hypotheses from historical data, and bring those hypotheses to me already half-formed. The collaboration shifted from "expert explains, developer implements" to something more like joint research. He tested ideas on data. I turned the surviving ones into code.

## The wave algorithm

We started where methodology requires: with the known approaches. We implemented and tested AMA and EMA-based strategies, got results consistent with what the literature would predict, and established our baseline. This is not the interesting part.

The interesting part was the wave algorithm — a model of price behavior my partner had been thinking about for years before we started. We put most of our effort here: implementing it, building configuration tooling sophisticated enough to tune its many parameters, and running systematic experiments across historical data.

The results were mixed in an instructive way. On most trading days, the system produced capital growth of 2–3%. In the final year, we lost the entire wallet completely three times.

That combination — consistent daily performance and catastrophic periodic failure — is itself a finding. It tells you something specific about what the wave model captures and what it doesn't. The losses were not random noise; they were regime changes the model wasn't built to detect — specifically, periods when the market moved fast enough that our price data was always obsolete by the time we acted on it. The only real solution was colocation: running the software inside the exchange's own data center to eliminate the latency. We never did that. Understanding why the system failed in the way it did is more useful than a system that simply worked.

## Outcome

The partnership ended for personal reasons in early 2022. My partner had funded the project from his own capital, which gave it the freedom that genuine research requires: no external pressure, no timeline, no obligation to ship anything before it was ready. That freedom is part of why the project lasted five years and why the experiments were real.

The WPF interface visible in the screenshots below was a personal side project — my own experiment with WPF capabilities, running in parallel with the production system. Had the collaboration continued, it would have become the new UI.

## What was built

- SQL Server database with tick-resolution trading history
- Import tool for `.qsh` format historical data
- Exchange emulator with full session replay from extended logs
- Exchange connector (SmartCOM) with transparent reconnection and context restoration
- Trading engine connectable to either live exchange or emulator
- Indicator set, configurable by connection to the trading engine
- Scheduling module for switching indicator configurations on a time basis
- Balance control module for capital allocation across concurrent frequencies
- Quick calculation tool: headless multi-configuration backtesting across historical data
- Reporting module
- WPF UI prototype (experimental, not completed)

**Implementation technologies:** .NET Framework, Windows Forms, SmartCOM COM Connector, QScalp qsh format import library

## Some illustrations from the project

**Fig. 1** Trading experiment on live exchange connection with virtual order processing.

![The Trading Experiment](Images/Fig_01_Experiment.png)

**Fig. 2** Trading testing on live exchange with real order processing, compared against the official trading tool.

![The Trading Testing](Images/Fig_02_Testing.png)

**Fig. 3** Trading session report with results summary and hourly earnings diagram.

![The Trading Session Report](Images/Fig_03_Report.png)

**Fig. 4** WPF UI prototype — price graphs, clusters, and trend visualization.

![New trading analysis user interface](Images/Fig_04_SquirrelGraph.gif)

The video on [YouTube](https://www.youtube.com/watch?v=7lW273PTbGI).
